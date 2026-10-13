#!/usr/bin/env python3
"""Qualify native H3 and fixed H3 origins using an actual standalone release."""
import argparse
import asyncio
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import queue
import socket
import subprocess
import sys
import tempfile
import threading
import time

from aioquic.asyncio import QuicConnectionProtocol, connect
from aioquic.h3.connection import H3Connection
from aioquic.h3.events import DataReceived, HeadersReceived
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.events import ConnectionTerminated, ProtocolNegotiated, StreamReset

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "integration/http3/upstream"))
from run import credentials

TRAILERS = [(b"x-check", b"one"), (b"x-check", b"two")]


class Peer(QuicConnectionProtocol):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.http = H3Connection(self._quic)
        self.responses = {}
        self.alpn = None
        self.failure = None

    def quic_event_received(self, event):
        if isinstance(event, ProtocolNegotiated):
            self.alpn = event.alpn_protocol
        elif isinstance(event, (ConnectionTerminated, StreamReset)):
            self.failure = repr(event)
        for item in self.http.handle_event(event):
            if isinstance(item, (HeadersReceived, DataReceived)):
                response = self.responses.setdefault(item.stream_id,
                    {"headers": [], "body": bytearray(), "ended": False})
                if isinstance(item, HeadersReceived):
                    response["headers"].append(item.headers)
                else:
                    response["body"].extend(item.data)
                    assert len(response["body"]) <= 262_144, "packaged H3 smoke response exceeded allowance"
                response["ended"] = item.stream_ended

    async def request(self, port, path, trailers=False):
        stream = self._quic.get_next_available_stream_id()
        fields = [(b":method", b"POST" if trailers else b"GET"),
                  (b":scheme", b"https"),
                  (b":authority", f"localhost:{port}".encode()),
                  (b":path", path.encode())]
        if trailers:
            fields += [(b"content-length", b"0"), (b"trailer", b"x-check")]
        self.http.send_headers(stream, fields, end_stream=not trailers)
        if trailers:
            self.http.send_headers(stream, TRAILERS, end_stream=True)
        self.transmit()
        async with asyncio.timeout(5):
            while not self.responses.get(stream, {}).get("ended"):
                assert self.failure is None, self.failure
                await asyncio.sleep(0.002)
        response = self.responses[stream]
        assert self.alpn == "h3", self.alpn
        assert response["headers"][0].count((b":status", b"200")) == 1, response
        return response


def h1(port, remaining):
    with socket.create_connection(("127.0.0.1", port), timeout=5) as client:
        client.sendall(b"POST /echo-three-declared HTTP/1.1\r\nHost: edge.test\r\n"
            b"Transfer-Encoding: chunked\r\nTrailer: x-check\r\nConnection: close\r\n\r\n"
            b"3\r\nabc\r\n0\r\nx-check: one\r\nx-check: two\r\n\r\n")
        wire = bytearray()
        while True:
            client.settimeout(remaining(5))
            chunk = client.recv(65_536)
            if not chunk:
                break
            wire.extend(chunk)
            assert len(wire) <= 262_144, "packaged H1 smoke response exceeded allowance"
    head, body = bytes(wire).split(b"\r\n\r\n", 1)
    assert head.startswith(b"HTTP/1.1 200 "), head
    assert b"transfer-encoding: chunked" in head.lower(), head
    data = bytearray()
    while True:
        line, body = body.split(b"\r\n", 1)
        length = int(line, 16)
        if length == 0:
            assert body == b"x-check: one\r\nx-check: two\r\n\r\n", body
            break
        data.extend(body[:length])
        assert body[length:length + 2] == b"\r\n", body
        body = body[length + 2:]
    assert bytes(data) == b"echo-finished", data


async def h3(port, ca):
    config = QuicConfiguration(is_client=True, alpn_protocols=["h3"], server_name="localhost")
    config.load_verify_locations(cafile=str(ca))
    async with connect("127.0.0.1", port, configuration=config,
                       create_protocol=Peer) as peer:
        static = await peer.request(port, "/")
        assert bytes(static["body"]) == b"release-h3", static
        proxied = await peer.request(port, "/echo-zero-declared", trailers=True)
        assert bytes(proxied["body"]) == b"echo-finished", proxied
        assert proxied["headers"][-1] == TRAILERS, proxied["headers"]


async def bounded_h3(port, ca, timeout):
    async with asyncio.timeout(timeout):
        await h3(port, ca)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", type=Path,
                        default=ROOT / "_build/prod/rel/gaoxy/bin/gaoxy")
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    args.evidence.mkdir(parents=True, exist_ok=True)
    assert importlib.metadata.version("aioquic") == "1.2.0"
    report = {"status": "FAIL", "checks": [], "release": str(args.release.resolve()),
              "aioquic": "1.2.0", "commands": [], "child_exits": {}}
    children, logs, origin_ports, listener_ports = {}, [], [], {}
    events = queue.Queue()
    deadline = time.monotonic() + 90

    def remaining(maximum):
        value = min(maximum, deadline - time.monotonic())
        assert value > 0, "packaged H3 smoke deadline expired"
        return value

    def control(child, command):
        child.stdin.write(json.dumps({"command": command}) + "\n")
        child.stdin.flush()

    def event(name):
        while True:
            item = events.get(timeout=remaining(5))
            if item["event"] == name:
                return item

    try:
        with tempfile.TemporaryDirectory(prefix="gaoxy-packaged-h3-") as temporary:
            directory = Path(temporary)
            with (args.evidence / "certificates.log").open("w") as output:
                for name in ("a", "b"):
                    credentials(directory / name, output, remaining)
            command = [sys.executable, str(ROOT / "integration/http3/upstream/origin.py"),
                       "--cert-a", str(directory / "a"), "--cert-b", str(directory / "b")]
            origin = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, text=True, bufsize=1)
            children["origin"] = origin
            report["commands"].append(command)
            log = (args.evidence / "origin.log").open("w")
            logs.append(log)

            def read():
                for line in origin.stdout:
                    log.write(line)
                    log.flush()
                    if line.startswith("GAOXY_UPSTREAM_ORIGIN "):
                        events.put(json.loads(line.split(" ", 1)[1]))

            reader = threading.Thread(target=read, daemon=True)
            reader.start()
            origin_ports = event("ready")["ports"]
            routes = {"version": 1, "routes": [
                {"path": "/echo-three-declared", "target": {"type": "reverse_proxy",
                 "upstream": f"https://localhost:{origin_ports[0]}",
                 "upstream_protocol": "http3", "cacertfile": str(directory / "a/ca.pem")}},
                {"path": "/echo-zero-declared", "target": {"type": "reverse_proxy",
                 "upstream": f"https://localhost:{origin_ports[1]}",
                 "upstream_protocol": "http3", "cacertfile": str(directory / "b/ca.pem")}},
                {"target": {"type": "static", "body": "release-h3"}}]}
            config = {"version": 1, "services": [
                {"id": "h1", "handler": "http", "transport": "tcp", "port": 0,
                 "ip": "127.0.0.1", "limits": {"max_bytes": 16_777_216}, "routes": routes},
                {"id": "h3", "handler": "http3", "transport": "quic", "port": 0,
                 "ip": "127.0.0.1", "protocols": ["http3"],
                 "limits": {"max_bytes": 134_217_728}, "routes": routes,
                 "tls": {"certfile": str(directory / "a/cert.pem"),
                         "keyfile": str(directory / "a/key.pem")}}]}
            config_path, ready = directory / "config.json", directory / "ready.json"
            config_path.write_text(json.dumps(config))
            output = (args.evidence / "release.log").open("w")
            logs.append(output)
            command = [str(args.release.resolve()), "start"]
            release = subprocess.Popen(command, env=dict(os.environ,
                GAOXY_CONFIG=str(config_path), GAOXY_READY_FILE=str(ready)),
                stdout=output, stderr=subprocess.STDOUT)
            children["release"] = release
            report["commands"].append(command)
            until = time.monotonic() + remaining(20)
            while True:
                assert release.poll() is None, "packaged release exited during startup"
                assert time.monotonic() < until, "packaged ready-file deadline expired"
                try:
                    data = json.loads(ready.read_text())
                    break
                except (FileNotFoundError, json.JSONDecodeError):
                    time.sleep(0.01)
            listener_ports = {row["id"]: row["port"] for row in data["services"]}
            assert set(listener_ports) == {"h1", "h3"} and all(listener_ports.values()), data
            h1(listener_ports["h1"], remaining)
            report["checks"].append({"name": "packaged_h1_to_h3_data_trailers", "status": "PASS"})
            asyncio.run(bounded_h3(listener_ports["h3"], directory / "a/ca.pem", remaining(15)))
            report["checks"] += [{"name": "packaged_h3_listener", "status": "PASS"},
                                 {"name": "packaged_h3_to_h3_zero_trailers", "status": "PASS"}]
            control(origin, "snapshot")
            requests = event("snapshot")["requests"]
            assert len(requests) == 2, requests
            for path, body, identity, port in [
                    ("/echo-three-declared", b"abc", "a", origin_ports[0]),
                    ("/echo-zero-declared", b"", "b", origin_ports[1])]:
                matches = [row for row in requests if row["path"] == path]
                assert len(matches) == 1, matches
                row = matches[0]
                assert row["origin"] == identity and row["request_fin"] and row["fin_count"] == 1, row
                assert row["data_bytes"] == len(body), row
                assert row["data_sha256"] == hashlib.sha256(body).hexdigest(), row
                assert row["trailer_blocks"] == 1 and row["trailers"] == [["x-check", "one"], ["x-check", "two"]], row
                assert [v for k, v in row["headers"] if k == ":method"] == ["POST"], row
                assert [v for k, v in row["headers"] if k == ":authority"] == [f"localhost:{port}"], row
                assert row["certificate_sha256"] == hashlib.sha256((directory / identity / "cert.pem").read_bytes()).hexdigest(), row
            report["origin_requests"] = requests
            release.terminate()
            report["child_exits"]["release"] = release.wait(timeout=remaining(8))
            control(origin, "stop")
            report["child_exits"]["origin"] = origin.wait(timeout=remaining(5))
            reader.join(timeout=remaining(2))
            assert not reader.is_alive() and all(code == 0 for code in report["child_exits"].values()), report
            for port in [*origin_ports, listener_ports["h3"]]:
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as replacement:
                    replacement.bind(("127.0.0.1", port))
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as replacement:
                replacement.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                replacement.bind(("127.0.0.1", listener_ports["h1"]))
            report["ports_rebound"] = True
            assert len(report["checks"]) == 3
            report["status"] = "PASS"
    except BaseException as error:
        report["error"] = repr(error)
        raise
    finally:
        for name, child in children.items():
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait(timeout=5)
            report["child_exits"][name] = child.returncode
        for log in logs:
            log.close()
        (args.evidence / "result.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "checks": len(report["checks"])}))


if __name__ == "__main__":
    main()
