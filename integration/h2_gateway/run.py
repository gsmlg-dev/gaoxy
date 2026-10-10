#!/usr/bin/env python3
"""Bounded local H2 echo/proxy load using an independent h2 client and H1 origin."""

import argparse
import datetime
import hashlib
import http.server
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import queue
import select
import socket
import subprocess
import sys
import threading
import time

import h2.config
import h2.connection
import h2.events
import h2.exceptions

ROOT = Path(__file__).resolve().parents[2]
PAYLOAD = bytes(range(256)) * 512
PREFIX = "GAOXY_H2_FIXTURE "
BOUNDS = {
    "rss_growth_bytes": 512 * 1024 * 1024,
    "process_growth": 512,
    "mailbox_messages": 2048,
    "admission_active": 128,
    "admission_bytes": 536870912,
    "teardown_seconds": 15,
}
PROFILE = {
    "connection_count": 1,
    "concurrent_streams": 32,
    "body_bytes": len(PAYLOAD),
    "request_timeout_seconds": 30,
    "write_timeout_seconds": 5,
    "read_pacing_seconds": 0.005,
    "slow_credit_seconds": 0.2,
    "reload_interval_seconds": 2,
}


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


class Origin(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def setup(self):
        super().setup()
        with self.server.condition:
            self.server.connections.add(self.connection)

    def finish(self):
        try:
            super().finish()
        finally:
            self.connection.close()
            with self.server.condition:
                self.server.connections.discard(self.connection)
                self.server.condition.notify_all()

    def log_message(self, *_args):
        pass

    def do_POST(self):
        self.connection.settimeout(10)
        try:
            if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
                body = bytearray()
                while True:
                    line = self.rfile.readline(128)
                    size = int(line.strip().split(b";", 1)[0], 16)
                    if size == 0:
                        while True:
                            trailer = self.rfile.readline(8192)
                            if trailer == b"\r\n":
                                break
                            if not trailer:
                                raise AssertionError("origin truncated trailer terminator")
                        break
                    if len(body) + size > len(PAYLOAD):
                        raise AssertionError("origin upload exceeded payload bound")
                    part = self.rfile.read(size)
                    if len(part) != size or self.rfile.read(2) != b"\r\n":
                        raise AssertionError("origin truncated chunked upload")
                    body.extend(part)
            else:
                length = int(self.headers["Content-Length"])
                if length != len(PAYLOAD):
                    raise AssertionError(f"origin unexpected content length {length}")
                body = self.rfile.read(length)
            if body != PAYLOAD:
                raise AssertionError("origin upload payload mismatch")
            with self.server.condition:
                self.server.completed_uploads += 1
            self.send_response(200)
            self.send_header("Content-Length", str(len(PAYLOAD)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(PAYLOAD)
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            with self.server.condition:
                self.server.aborted_writes += 1
        except Exception as error:
            with self.server.condition:
                self.server.failures.append(repr(error))
            self.close_connection = True


class Gateway:
    def __init__(self, origin_port):
        self.lines = queue.Queue()
        self.output = []
        env = dict(os.environ)
        env.pop("GAOXY_CONFIG", None)
        env.update(GAOXY_H2_ORIGIN_PORT=str(origin_port), ERL_FLAGS="+S 2:2")
        self.process = subprocess.Popen(
            ["mix", "run", "--no-compile", "integration/h2_gateway/fixture.exs"],
            cwd=ROOT, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, bufsize=1,
        )

        def collect():
            for line in self.process.stdout:
                self.output.append(line)
                if line.startswith(PREFIX):
                    self.lines.put(json.loads(line[len(PREFIX):]))
            self.lines.put({"event": "process_exit"})

        self.reader = threading.Thread(target=collect, daemon=True)
        self.reader.start()
        self.ready = self.receive("ready", 30)

    def receive(self, expected, timeout):
        event = self.lines.get(timeout=timeout)
        if event.get("event") != expected:
            raise AssertionError(f"expected fixture {expected}, received {event}")
        return event

    def command(self, name, timeout=5):
        self.process.stdin.write(json.dumps({"command": name}) + "\n")
        self.process.stdin.flush()
        return self.receive({"sample": "sample", "reload": "reload", "stop": "stopped", "exit": "exiting"}[name], timeout)

    def abort(self):
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=5)
        self.reader.join(timeout=2)


def rss(pid):
    for line in Path(f"/proc/{pid}/status").read_text().splitlines():
        if line.startswith("VmRSS:"):
            return int(line.split()[1]) * 1024
    raise AssertionError("Linux gateway RSS not available")


def socket_descriptors(pid):
    result = []
    for entry in Path(f"/proc/{pid}/fd").iterdir():
        try:
            target = entry.readlink().as_posix()
        except FileNotFoundError:
            continue
        if target.startswith("socket:"):
            result.append(target)
    return sorted(result)


def listener_descriptor(pid, port):
    descriptors = socket_descriptors(pid)
    address = f"0100007F:{port:04X}"
    matches = []
    for line in Path(f"/proc/{pid}/net/tcp").read_text().splitlines()[1:]:
        fields = line.split()
        descriptor = f"socket:[{fields[9]}]"
        if fields[1] == address and fields[3] == "0A" and descriptor in descriptors:
            matches.append(descriptor)
    if len(matches) != 1:
        raise AssertionError(f"expected one owned loopback listener, found {matches}")
    return matches[0]


def source_identity():
    patterns = ["apps/gaoxy/lib/**/*.ex", "apps/gaoxy_http/lib/**/*.ex",
                "apps/gaoxy_proxy/lib/**/*.ex", "apps/gaoxy_server/lib/**/*.ex",
                "apps/*/mix.exs", "integration/h2_gateway/*"]
    files = set()
    for pattern in patterns:
        files.update(path for path in ROOT.glob(pattern) if path.is_file())
    files.add(ROOT / "mix.lock")
    files.add(ROOT / "mix.exs")
    hashes = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
              for path in sorted(files)}
    return {
        "baseline": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "branch": subprocess.check_output(["git", "branch", "--show-current"], cwd=ROOT, text=True).strip(),
        "sha256": hashes,
    }


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int((len(ordered) - 1) * fraction))]


def sample(gateway, report, started):
    item = gateway.command("sample")
    item.update(elapsed_seconds=time.monotonic() - started, rss_bytes=rss(gateway.ready["pid"]))
    report["samples"].append(item)
    baseline = report["baseline"]
    if item["rss_bytes"] > baseline["rss_bytes"] + BOUNDS["rss_growth_bytes"]:
        raise AssertionError("gateway RSS bound exceeded")
    if item["process_count"] > baseline["process_count"] + BOUNDS["process_growth"]:
        raise AssertionError("gateway process-count bound exceeded")
    if any(row["size"] > BOUNDS["mailbox_messages"] for row in item["mailboxes"]):
        raise AssertionError("sampled owned-process mailbox bound exceeded")
    admission = item["admission"]
    if admission["active"] > BOUNDS["admission_active"] or admission["retained_bytes"] > BOUNDS["admission_bytes"]:
        raise AssertionError("gateway admission bound exceeded")
    if admission.get("cleanup_failed"):
        raise AssertionError("gateway reported failed cleanup")


def load(gateway, duration, report):
    connection = h2.connection.H2Connection(config=h2.config.H2Configuration(client_side=True, header_encoding="utf-8"))
    client = socket.create_connection(("127.0.0.1", gateway.ready["port"]), timeout=5)
    client.setblocking(False)
    connection.initiate_connection()
    outgoing = bytearray(connection.data_to_send())
    active = {}
    latencies = []
    response_generations = set()
    serial = 0
    pending_credits = {}
    next_read = 0
    started = time.monotonic()
    end = started + duration
    deadline = end + 30
    next_sample = started
    next_reload = started + PROFILE["reload_interval_seconds"]
    offer_end = None
    report["load_started_utc"] = utc()

    def offer_batch():
        nonlocal serial
        for _ in range(PROFILE["concurrent_streams"]):
            serial += 1
            stream_id = connection.get_next_available_stream_id()
            kind = "local" if serial % 2 else "proxy"
            connection.send_headers(stream_id, [
                (":method", "POST"), (":scheme", "http"), (":authority", "localhost"),
                (":path", f"/{kind}"), ("content-length", str(len(PAYLOAD))),
            ], end_stream=False)
            active[stream_id] = {"kind": kind, "upload": 0, "received": bytearray(), "started": time.monotonic(),
                                 "status": None, "reset": serial % 17 == 0, "slow": serial % 8 == 0}
            report["offered"] += 1
        report["max_opened_concurrent"] = max(report["max_opened_concurrent"], len(active))

    try:
        while time.monotonic() < end or active or outgoing:
            now = time.monotonic()
            if now >= end and offer_end is None:
                offer_end = now
            if now >= deadline:
                raise TimeoutError("load drain deadline exceeded")
            if not active and now < end:
                offer_batch()
            if now >= next_sample:
                sample(gateway, report, started)
                next_sample = now + 1
            if now >= next_reload and now < end:
                event = gateway.command("reload")
                if event["port"] != gateway.ready["port"]:
                    raise AssertionError("route reload changed listener port")
                report["reloads"] += 1
                next_reload = now + PROFILE["reload_interval_seconds"]

            for stream_id, (credit, release_at) in list(pending_credits.items()):
                if now >= release_at:
                    connection.acknowledge_received_data(credit, stream_id)
                    del pending_credits[stream_id]
            if len(outgoing) < 262144:
                for stream_id, state in list(active.items()):
                    remaining = len(PAYLOAD) - state["upload"]
                    if remaining:
                        amount = min(remaining, connection.local_flow_control_window(stream_id), connection.max_outbound_frame_size)
                        if amount > 0:
                            offset = state["upload"]
                            connection.send_data(stream_id, PAYLOAD[offset:offset + amount], end_stream=amount == remaining)
                            state["upload"] += amount
            outgoing.extend(connection.data_to_send())
            if len(outgoing) > 1048576:
                raise AssertionError("client outgoing buffer bound exceeded")
            readable, writable, _ = select.select([client] if now >= next_read else [], [client] if outgoing else [], [], 0.01)
            if writable:
                sent = client.send(outgoing[:65536])
                del outgoing[:sent]
            if readable:
                data = client.recv(65536)
                if not data:
                    raise AssertionError("gateway closed sustained-load connection")
                next_read = time.monotonic() + PROFILE["read_pacing_seconds"]
                events = connection.receive_data(data)
                for event in events:
                    if isinstance(event, h2.events.ResponseReceived):
                        state = active[event.stream_id]
                        fields = dict(event.headers)
                        state["status"] = fields.get(":status")
                        if state["kind"] == "local":
                            response_generations.add(fields["x-fixture-generation"])
                    elif isinstance(event, h2.events.DataReceived):
                        state = active.get(event.stream_id)
                        if state is None:
                            connection.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
                            continue
                        state["received"].extend(event.data)
                        if len(state["received"]) > len(PAYLOAD) or state["received"] != PAYLOAD[:len(state["received"])]:
                            raise AssertionError(f"stream {event.stream_id} response payload mismatch")
                        hold = PROFILE["slow_credit_seconds"] if state["slow"] else 0.05
                        credit, release_at = pending_credits.get(event.stream_id, (0, time.monotonic() + hold))
                        pending_credits[event.stream_id] = (credit + event.flow_controlled_length, release_at)
                        if state["slow"]:
                            report["slow_credit_events"] += 1
                        if state["reset"] and state["upload"] == len(PAYLOAD) and event.data:
                            credit, _ = pending_credits.pop(event.stream_id)
                            connection.acknowledge_received_data(credit, event.stream_id)
                            try:
                                connection.reset_stream(event.stream_id, error_code=8)
                            except h2.exceptions.StreamClosedError:
                                # The same receive call can already contain END_STREAM.
                                state["reset"] = False
                            else:
                                report["expected_resets"] += 1
                                del active[event.stream_id]
                    elif isinstance(event, h2.events.StreamEnded):
                        state = active.pop(event.stream_id, None)
                        if state is None:
                            continue
                        if state["status"] != "200" or state["received"] != PAYLOAD or state["upload"] != len(PAYLOAD):
                            raise AssertionError(f"stream {event.stream_id} incomplete/wrong response")
                        if event.stream_id in pending_credits:
                            credit, _ = pending_credits.pop(event.stream_id)
                            connection.acknowledge_received_data(credit, event.stream_id)
                        report["completed"] += 1
                        report[f"completed_{state['kind']}"] += 1
                        latencies.append(time.monotonic() - state["started"])
                    elif isinstance(event, h2.events.StreamReset):
                        raise AssertionError(f"unexpected server reset {event.stream_id}: {event.error_code}")
                    elif isinstance(event, h2.events.ConnectionTerminated):
                        raise AssertionError(f"unexpected GOAWAY: {event.error_code}")
            for state in active.values():
                if time.monotonic() - state["started"] > PROFILE["request_timeout_seconds"]:
                    raise TimeoutError("client stream lifetime exceeded")

        report["actual_offered_interval_seconds"] = (offer_end or time.monotonic()) - started
        report["actual_load_and_drain_seconds"] = time.monotonic() - started
        report["load_ended_utc"] = utc()
        report["completed_per_second"] = report["completed"] / report["actual_load_and_drain_seconds"]
        report["latency_seconds"] = {"p50": percentile(latencies, 0.50), "p95": percentile(latencies, 0.95), "p99": percentile(latencies, 0.99)}
        report["response_generations"] = sorted(response_generations, key=int)
        if report["offered"] != report["completed"] + report["expected_resets"]:
            raise AssertionError("offered/completed/reset conservation failed")
        if not all(report[key] > 0 for key in ["completed_local", "completed_proxy", "expected_resets", "slow_credit_events"]):
            raise AssertionError("required load paths were not exercised")
        if report["reloads"] < 2 or len(response_generations) < 2 or report["max_opened_concurrent"] != 32:
            raise AssertionError("generation/concurrency coverage incomplete")
    finally:
        client.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--duration", type=float, default=600)
    parser.add_argument("--smoke", action="store_true", help="label a short run UNQUALIFIED")
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    if args.duration < 5 or (args.duration < 600 and not args.smoke):
        parser.error("duration must be >=600; an explicit --smoke permits >=5 seconds")
    args.evidence.mkdir(parents=True, exist_ok=True)
    report = {"status": "NOT RUN", "qualified_duration": args.duration >= 600 and not args.smoke,
              "bounds": BOUNDS, "profile": PROFILE, "requested_duration_seconds": args.duration,
              "started_utc": utc(), "source": source_identity(), "samples": [], "errors": [],
              "offered": 0, "completed": 0, "completed_local": 0, "completed_proxy": 0,
              "expected_resets": 0, "unexpected_errors": 0, "slow_credit_events": 0,
              "reloads": 0, "max_opened_concurrent": 0,
              "environment": {"python": sys.version, "platform": platform.platform(),
                              "dependencies": {name: importlib.metadata.version(name) for name in ["h2", "hpack", "hyperframe"]}}}
    gateway = None
    origin = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Origin)
    origin.daemon_threads = True
    origin.completed_uploads = 0
    origin.aborted_writes = 0
    origin.failures = []
    origin.condition = threading.Condition()
    origin.connections = set()
    origin_thread = threading.Thread(target=origin.serve_forever, daemon=True)
    origin_thread.start()
    exit_code = 1
    try:
        gateway = Gateway(origin.server_port)
        report["environment"].update(otp=gateway.ready["otp"], elixir=gateway.ready["elixir"])
        report["baseline"] = {"rss_bytes": rss(gateway.ready["pid"]), "process_count": gateway.ready["process_count"], "socket_descriptors": socket_descriptors(gateway.ready["pid"])}
        report["baseline"]["listener_descriptor"] = listener_descriptor(gateway.ready["pid"], gateway.ready["port"])
        load(gateway, args.duration, report)
        report["teardown"] = gateway.command("stop", 15)
        teardown = report["teardown"]
        if not (teardown["runtime_down"] and teardown["rebind"] and teardown["live_captured"] == 0 and teardown["captured"] == teardown["down"] and teardown["http_tasks"] == 0):
            raise AssertionError("gateway finite teardown proof failed")
        if teardown["admission"] != {"active": 0, "retained_bytes": 0, "cleanup_pending": 0}:
            raise AssertionError("gateway reservations remain")
        report["final_socket_descriptors"] = socket_descriptors(gateway.ready["pid"])
        expected_descriptors = [descriptor for descriptor in report["baseline"]["socket_descriptors"]
                                if descriptor != report["baseline"]["listener_descriptor"]]
        if report["final_socket_descriptors"] != expected_descriptors:
            raise AssertionError("gateway client/listener sockets remain after stop")
        gateway.command("exit")
        report["gateway_exit"] = gateway.process.wait(timeout=5)
        if report["gateway_exit"] != 0:
            raise AssertionError("gateway process exited unsuccessfully")
        if source_identity() != report["source"]:
            raise AssertionError("candidate source changed during execution")
        if origin.failures:
            raise AssertionError(f"origin failures: {origin.failures}")
        report["status"] = "PASS" if report["qualified_duration"] else "UNQUALIFIED"
        exit_code = 0
    except Exception as error:
        report["status"] = "FAIL"
        report["errors"].append(repr(error))
        report["unexpected_errors"] += 1
    finally:
        if gateway is not None:
            gateway.abort()
            (args.evidence / "gateway.log").write_text("".join(gateway.output))
        origin.shutdown()
        origin.server_close()
        origin_thread.join(timeout=5)
        with origin.condition:
            clients_closed = origin.condition.wait_for(lambda: not origin.connections, timeout=5)
            report["origin"] = {"completed_uploads": origin.completed_uploads, "aborted_writes": origin.aborted_writes, "failures": origin.failures, "listener_closed": origin.fileno() == -1, "clients_closed": clients_closed}
        if not clients_closed or origin_thread.is_alive() or origin.failures:
            report["status"] = "FAIL"
            report["errors"].append("origin teardown or payload validation failed")
            report["unexpected_errors"] += 1
            exit_code = 1
        report["ended_utc"] = utc()
        report["exit_code"] = exit_code
        (args.evidence / "result.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({key: report[key] for key in ["status", "offered", "completed", "expected_resets", "unexpected_errors", "errors", "exit_code"]}))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
