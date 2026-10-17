#!/usr/bin/env python3
"""Finite managed-H1 matrix; ExUnit and standalone share these exact oracles."""

import argparse
import base64
import gzip
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import select
import signal
import socket
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[2]
CLIENT = ROOT / "apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py"
PYTHON = "/tmp/gaoxy-m3-h2-soak-venv/bin/python"
ROWS = [(m, d, u) for m in ("fixed", "group") for d in ("h1", "h2") for u in ("tcp", "tls")]
FAMILIES = ("temporal_and_declared_trailers", "representation_and_reuse")
CASES = ["/".join((*row, family)) for row in ROWS for family in FAMILIES]
assert len(CASES) == len(set(CASES)) == 16
BINARY = bytes((0, 255, 1, 2, 254, 0))
TRACE = [["x-trace", "one"], ["x-trace", "two"]]
RESPONSE_TRACE = [["x-trace", "first"], ["x-trace", "last"]]


def check(value, message):
    if not value:
        raise AssertionError(message)


def encoded(data):
    return base64.b64encode(data).decode("ascii")


def byte_receipt(data):
    return dict(body64=encoded(data), body_bytes=len(data), body_sha256=hashlib.sha256(data).hexdigest())


def exact_bytes(receipt, data):
    for key, expected in byte_receipt(data).items():
        check(receipt.get(key) == expected, f"{key}: {receipt.get(key)!r} != {expected!r}")


def values(fields, name):
    return [value for key, value in fields if key.lower() == name]


class Lines:
    """A bounded line reader that keeps bytes already read beyond a delimiter."""

    def __init__(self, stream):
        self.stream = stream
        self.carry = b""

    def read(self, deadline):
        while b"\n" not in self.carry:
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not select.select([self.stream], [], [], max(0, remaining))[0]:
                raise TimeoutError("JSON receipt deadline")
            chunk = os.read(self.stream.fileno(), 65536)
            if not chunk:
                raise EOFError("JSON peer exited before receipt")
            self.carry += chunk
            check(len(self.carry) <= 2097152, "JSON receipt bound")
        line, self.carry = self.carry.split(b"\n", 1)
        value = json.loads(line)
        check(isinstance(value, dict), "receipt must be an object")
        return value


class Host:
    def __init__(self, attached=False, clients=None):
        self.attached = attached
        self.clients = clients if clients is not None else []
        self.process = None
        self.active = False
        self.finished = False
        if attached:
            self.input, self.output = sys.stdin.buffer, sys.stdout.buffer
        else:
            self.process = subprocess.Popen(
                ["mix", "run", "--no-compile", "--no-start", "integration/upstream_transport/fixture.exs"],
                cwd=ROOT, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=sys.stderr.buffer)
            self.input, self.output = self.process.stdout, self.process.stdin
        self.lines = Lines(self.input)
        if not attached:
            try:
                check(self.lines.read(time.monotonic() + 10) == {"event": "fixture_ready"}, "fixture boot identity")
            except Exception:
                self.abort()
                raise

    def call(self, command, timeout=5):
        expires = time.monotonic() + timeout
        check(timeout > 0, "fixture operation deadline")
        self.output.write(json.dumps(command, separators=(",", ":")).encode() + b"\n")
        self.output.flush()
        value = self.lines.read(expires)
        check(value.get("event") != "failure", f"fixture failure: {value}")
        return value

    def start(self, row):
        check(not self.active, "fixture already active")
        # Track ownership before startup: a partially started adapter is cleaned
        # by its own after clause if its process must be stopped.
        self.active = True
        ready = self.call(dict(op="start", row=row), timeout=10)
        check(ready.get("event") == "ready" and ready.get("row") == row, "wrong ready row")
        return ready

    def event(self, timeout=5, **selector):
        return self.call(dict(op="event", match=selector), timeout=timeout)

    def stop(self, timeout=10):
        check(self.active, "fixture stop without start")
        result = self.call(dict(op="stop"), timeout=timeout)
        self.active = False
        check(result.get("event") == "joined" and result.get("forced") == 0 and result.get("live") == 0,
              f"fixture did not normally join: {result}")
        return result

    def finish(self):
        check(not self.active, "cannot finish live fixture")
        if not self.attached:
            receipt = self.call(dict(op="finish"), timeout=10)
            check(receipt == dict(event="finished", live=0, forced=0), "missing finished receipt")
            check(self.process.wait(timeout=10) == 0, "fixture exit failure")
        self.finished = True

    def abort(self, expires=None):
        """Owned-only forced cleanup; callers always retain a failing verdict."""
        expires = expires if expires is not None else time.monotonic() + 10
        if self.process is not None and self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=min(5, max(0, expires - time.monotonic())))
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=max(0, expires - time.monotonic()))


class Client:
    def __init__(self, case, method, target, fields=(), controlled=False, observe=False):
        self.process = None
        self.case, self.queued, self.joined, self.seen = case, [], False, set()
        case.host.clients.append(self)
        case.clients.append(self)
        args = [PYTHON, str(CLIENT), "--client", "--events", "--downstream", case.row["downstream"],
                "--port", str(case.ready["port"]), "--method", method, "--target", target,
                "--headers-json", json.dumps(list(fields), separators=(",", ":"))]
        if controlled:
            args.append("--controlled")
        if observe:
            args += ["--observe-prefix-bytes", "3"]
        # A pending overall alarm must not interrupt the Popen-to-registry handoff.
        blocked = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGALRM})
        try:
            self.process = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=sys.stderr.buffer)
        finally:
            signal.pthread_sigmask(signal.SIG_SETMASK, blocked)
        self.lines = Lines(self.process.stdout)

    def upload(self, body, ended=True, trailers=()):
        self.process.stdin.write(json.dumps(dict(op="upload", body64=encoded(body), ended=ended,
                                                trailers=list(trailers))).encode() + b"\n")
        self.process.stdin.flush()

    def event(self, name):
        for index, value in enumerate(self.queued):
            if value.get("event") == name:
                return self.queued.pop(index)
        deadline = min(self.case.deadline, time.monotonic() + 5)
        while True:
            value = self.lines.read(deadline)
            check(value.get("event") != "client_failure", f"independent client failed: {value}")
            check(value.get("event") in ("client_head", "client_prefix", "client_response"), "unknown client receipt identity")
            check(value["event"] not in self.seen, "duplicate client receipt: " + value["event"])
            self.seen.add(value["event"])
            if value.get("event") == name:
                self.case.receipts.append(dict(source="downstream", receipt=value))
                return value
            check(value.get("event") != "client_response", f"client completed before {name}")
            self.queued.append(value)

    def response(self, status, body, trailers=()):
        receipt = self.event("client_response")
        check(receipt.get("status") == status and receipt.get("complete") is True, "incomplete/wrong response")
        check(receipt.get("termination") == "complete" and receipt.get("socket_closed") is True,
              "downstream termination identity")
        check(receipt.get("upload_helper_joined") is True, "upload helper did not join")
        check(receipt.get("trailers") == list(trailers), "ordered response trailers")
        exact_bytes(receipt, body)
        check(self.process.wait(timeout=min(5, max(.001, self.case.deadline - time.monotonic()))) == 0,
              "independent client nonzero exit")
        check(not (self.lines.carry + self.process.stdout.read()).strip(), "unexpected duplicate client receipt")
        self.process.stdin.close()
        self.process.stdout.close()
        self.joined = True
        return receipt

    def abort(self, expires):
        if self.process is None:
            return
        try:
            if self.process.poll() is None:
                self.process.terminate()
            try:
                self.process.wait(timeout=min(5, max(0, expires - time.monotonic())))
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=max(0, expires - time.monotonic()))
        finally:
            # Closing one pipe must not prevent closing the other.
            try:
                self.process.stdin.close()
            finally:
                self.process.stdout.close()


def cleanup_clients(clients, expires):
    failures = []
    for client in clients:
        if client.process is not None and not client.joined:
            failures.append("forced client cleanup")
            try:
                client.abort(expires)
            except BaseException as error:
                failures.append("client cleanup: " + repr(error))
    return failures


class FramingProbe:
    """Only the three bodyless framing checks, preserving all leftover bytes."""

    def __init__(self, case):
        self.case, self.carry = case, b""
        self.socket = socket.create_connection(("127.0.0.1", case.ready["port"]), timeout=5)

    def request(self, method, target):
        self.socket.sendall(f"{method} {target} HTTP/1.1\r\nHost: downstream.test\r\nContent-Length: 0\r\n\r\n".encode())

    def read(self, count=None, delimiter=None):
        while (len(self.carry) < count if count is not None else delimiter not in self.carry):
            remaining = min(5, self.case.deadline - time.monotonic())
            check(remaining > 0, "framing probe case deadline")
            self.socket.settimeout(remaining)
            chunk = self.socket.recv(65536)
            check(bool(chunk), "persistent downstream socket closed")
            self.carry += chunk
            check(len(self.carry) <= 1048576, "framing probe bound")
        count = count if count is not None else self.carry.index(delimiter) + len(delimiter)
        result, self.carry = self.carry[:count], self.carry[count:]
        return result

    def response(self, method, status, body):
        raw = self.read(delimiter=b"\r\n\r\n")
        lines = raw[:-4].decode("latin1").split("\r\n")
        check(lines[0].startswith(f"HTTP/1.1 {status} "), f"persistent framing leaked bytes: {lines[0]!r}")
        fields = [[name.lower(), value.lstrip()] for name, value in (line.split(":", 1) for line in lines[1:])]
        received, trailers = b"", []
        if method != "HEAD" and status not in (204, 205, 304):
            if values(fields, "transfer-encoding") == ["chunked"]:
                while True:
                    count = int(self.read(delimiter=b"\r\n")[:-2].split(b";", 1)[0], 16)
                    if count == 0:
                        check(self.read(delimiter=b"\r\n") == b"\r\n", "unexpected persistent trailer")
                        break
                    received += self.read(count=count)
                    check(self.read(count=2) == b"\r\n", "persistent chunk delimiter")
            else:
                lengths = values(fields, "content-length")
                check(len(lengths) == 1, "persistent fixed response missing length")
                received = self.read(count=int(lengths[0]))
        check(received == body and trailers == [], "persistent response body")
        receipt = dict(source="persistent_downstream", method=method, status=status,
                       headers=fields, carry_bytes=len(self.carry), **byte_receipt(received))
        self.case.receipts.append(receipt)
        return receipt

    def close(self):
        check(not self.carry, "leftover framing bytes after healthy response")
        self.socket.close()


class Case:
    def __init__(self, host, case_id):
        check(case_id in CASES, "unknown case identity")
        mount, downstream, upstream, self.family = case_id.split("/")
        self.case_id, self.host = case_id, host
        self.row = dict(mount=mount, downstream=downstream, upstream=upstream)
        self.clients, self.receipts, self.requests = [], [], []
        self.connection = None
        self.ready = host.start(self.row)
        self.deadline = time.monotonic() + 20
        # Actual native listener handshake; this socket sends no HTTP request
        # and therefore cannot manufacture an upstream accepted-connection ID.
        with socket.create_connection(("127.0.0.1", self.ready["port"]), timeout=5):
            pass
        if mount == "group":
            health = host.event(timeout=self.remaining(), event="request", role="health", method="HEAD", target="/health")
            self.connection = health["connection"]
            self.receipts.append(dict(source="health", receipt=health))

    def remaining(self):
        remaining = self.deadline - time.monotonic()
        check(remaining > 0, "case exceeded 20 seconds")
        return min(5, remaining)

    def call(self, command):
        return self.host.call(command, timeout=self.remaining())

    def event(self, name, request=None, **selector):
        if request:
            selector.update(connection=request["connection"], request=request["request"])
        value = self.host.event(timeout=self.remaining(), event=name, **selector)
        self.receipts.append(dict(source="upstream", receipt=value))
        return value

    def request(self, method, target):
        check(time.monotonic() < self.deadline, "case deadline")
        request = self.event("request", role="application", method=method, target=target)
        if self.connection is None:
            self.connection = request["connection"]
        check(request["connection"] == self.connection, "application changed accepted upstream connection")
        check(request["request"] not in [r["request"] for r in self.requests], "duplicate upstream request ID")
        if self.requests:
            check(request["request"] == self.requests[-1]["request"] + 1, "upstream request ID gap")
        self.requests.append(request)
        return request

    def upload_end(self, request, body, trailers=()):
        value = self.event("upload_end", request)
        exact_bytes(value, body)
        check(value.get("trailers") == list(trailers), "ordered upstream trailers")
        return value

    def send(self, request, data, ended=True):
        value = self.call(dict(op="upstream", connection=request["connection"], request=request["request"],
                                    action="send", body64=encoded(data), ended=ended))
        check(value.get("event") == "command" and value.get("action") == "send" and
              value.get("connection") == request["connection"] and value.get("request") == request["request"],
              "wrong upstream command identity")
        exact_bytes(value, data)
        self.receipts.append(dict(source="command", receipt=value))

    def clean(self, persistent=False):
        result = self.call(dict(op="request_clean" if persistent else "clean"))
        check(result.get("completion_joined") is True, "original completion not joined")
        check(result["transport"]["request_tokens"] == 0 and result["transport"]["helpers"] == 0, "transport retained request")
        if not persistent:
            check(result["service"] == dict(active=0, cleanup_pending=0, retained_bytes=0, cleanup_failed=None), "service retained request")
        self.receipts.append(dict(source="accounting", receipt=result))

    def fixed_response(self, request, body=b"", status=200, fields=()):
        fields = list(fields)
        if not values(fields, "content-length") and status != 204:
            fields.append(["content-length", str(len(body))])
        raw = f"HTTP/1.1 {status} Matrix\r\n".encode()
        raw += b"".join(f"{name}: {value}\r\n".encode("latin1") for name, value in fields) + b"\r\n" + body
        self.send(request, raw)

    def temporal(self):
        client = Client(self, "POST", "/temporal", [["content-length", "6"], *TRACE], controlled=True, observe=True)
        client.upload(BINARY[:3], ended=False)
        request = self.request("POST", "/temporal")
        check(values(request["headers"], "x-trace") == ["one", "two"], "ordered duplicate request headers")
        check(values(request["headers"], "content-length") == ["6"], "fixed upload length")
        prefix = self.event("upload_prefix", request)
        exact_bytes(prefix, BINARY[:3])
        check(prefix.get("complete") is False, "upload prefix was complete")
        original = self.call(dict(op="pending"))
        check(original.get("pending") is True, "upload completion not pending")
        self.receipts.append(dict(source="upload_hold", receipt=original))
        release = self.call(dict(op="upstream", connection=request["connection"], request=request["request"], action="continue_upload"))
        check(release.get("event") == "command" and release.get("connection") == request["connection"] and
              release.get("request") == request["request"] and release.get("action") == "continue_upload", "upload release identity")
        self.receipts.append(dict(source="command", receipt=release))
        client.upload(BINARY[3:], ended=True)
        self.upload_end(request, BINARY)
        self.send(request, b"HTTP/1.1 200 OK\r\nContent-Length: 6\r\nX-Trace: first\r\nX-Trace: last\r\n\r\n" + BINARY[:3], ended=False)
        receipt = client.event("client_prefix")
        exact_bytes(receipt, BINARY[:3])
        check(receipt.get("complete") is False, "downstream prefix was complete before suffix release")
        held = self.call(dict(op="pending"))
        check(held.get("pending") is True and held.get("identity") == original.get("identity"), "original binding changed between holds")
        self.receipts.append(dict(source="response_hold", receipt=held))
        self.send(request, BINARY[3:])
        response = client.response(200, BINARY)
        check(values(response["headers"], "x-trace") == ["first", "last"], "ordered duplicate response fields")
        check(response.get("upload_bytes") == 6 and response.get("upload_eof") is True, "controlled fixed upload receipt")
        self.clean()

        fields = [["trailer", "x-trace"], *TRACE]
        if self.row["downstream"] == "h1":
            fields.append(["transfer-encoding", "chunked"])
        client = Client(self, "DELETE", "/trailers", fields, controlled=True)
        client.upload(BINARY, trailers=TRACE)
        request = self.request("DELETE", "/trailers")
        check(values(request["headers"], "x-trace") == ["one", "two"], "trailer exchange duplicate request fields")
        check(values(request["headers"], "trailer") == ["x-trace"], "declared upstream trailer")
        check(values(request["headers"], "transfer-encoding") == ["chunked"], "actual chunk-framed upstream upload")
        self.upload_end(request, BINARY, TRACE)
        self.send(request, b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nTrailer: X-Trace\r\nX-Trace: first\r\nX-Trace: last\r\n\r\n6\r\n" + BINARY + b"\r\n0\r\nX-Trace: first\r\nX-Trace: last\r\n\r\n")
        response = client.response(200, BINARY, RESPONSE_TRACE)
        check(values(response["headers"], "x-trace") == ["first", "last"], "trailer response duplicate fields")
        check(values(response["headers"], "trailer") == ["x-trace"], "declared downstream trailer")
        check(response.get("upload_bytes") == 6 and response.get("upload_eof") is True, "controlled trailer upload receipt")
        self.clean()

    def representations(self):
        for target, upload, body, fields in [
            ("/empty", b"", b"", []),
            ("/fixed", BINARY, BINARY, []),
            ("/gzip", b"", gzip.compress(BINARY, mtime=0), [["content-encoding", "gzip"], ["set-cookie", "one=1"], ["set-cookie", "two=2"]]),
        ]:
            client = Client(self, "POST", target, [["content-length", str(len(upload))]], controlled=True)
            client.upload(upload)
            request = self.request("POST", target)
            check(values(request["headers"], "content-length") == [str(len(upload))], "explicit request Content-Length")
            self.upload_end(request, upload)
            self.fixed_response(request, body, fields=fields)
            response = client.response(200, body)
            if target == "/gzip":
                check(values(response["headers"], "content-encoding") == ["gzip"], "gzip representation header")
                check(values(response["headers"], "set-cookie") == ["one=1", "two=2"], "ordered Set-Cookie")
            self.receipts.append(dict(source="expected_representation", target=target, **byte_receipt(body)))
            self.clean()

        # HEAD and 304 advertise a legal nonzero representation length while
        # carrying no entity bytes. 205 uses explicit Content-Length: 0.
        for method, target, status, fields in [
            ("HEAD", "/head", 200, [["content-length", "6"]]),
            ("GET", "/204", 204, []),
            ("GET", "/205", 205, [["content-length", "0"]]),
            ("GET", "/304", 304, [["content-length", "6"]]),
            ("GET", "/healthy", 200, []),
        ]:
            client = Client(self, method, target, [["content-length", "0"]])
            request = self.request(method, target)
            self.upload_end(request, b"")
            body = b"healthy" if target == "/healthy" else b""
            self.fixed_response(request, body, status=status, fields=fields)
            response = client.response(status, body)
            if method == "HEAD" or status == 304:
                check(values(response["headers"], "content-length") == ["6"], "legal representation Content-Length")
            self.clean()

        if self.row["downstream"] == "h1":
            probe = FramingProbe(self)
            try:
                for method, target, status, fields, body in [
                    ("HEAD", "/persistent-head", 200, [["content-length", "6"]], b""),
                    ("GET", "/persistent-204", 204, [], b""),
                    ("GET", "/persistent-healthy", 200, [], b"healthy"),
                ]:
                    probe.request(method, target)
                    request = self.request(method, target)
                    self.upload_end(request, b"")
                    self.fixed_response(request, body, status=status, fields=fields)
                    probe.response(method, status, body)
                    self.clean(persistent=True)
                probe.close()
                self.clean()
            finally:
                probe.socket.close()

    def run(self):
        if self.family == "temporal_and_declared_trailers":
            self.temporal()
        else:
            self.representations()
        check(time.monotonic() <= self.deadline, "case exceeded 20 seconds")
        accepted = self.event("accepted", connection=self.connection)
        check(accepted.get("wire") == self.row["upstream"] + "-h1", "wrong upstream wire")
        if self.row["upstream"] == "tls":
            check(accepted.get("sni") == "localhost" and accepted.get("alpn") is None, "TLS-H1 peer identity")
        check(time.monotonic() <= self.deadline, "case exceeded 20 seconds")
        joined = self.host.stop()
        check(joined.get("accepted") == 1, "replacement upstream accept")
        check(all(client.joined for client in self.clients), "client process not normally joined")
        return dict(event="case_result", case=self.case_id, row=self.row, status="PASS",
                    application_requests=len(self.requests), accepted_connection=self.connection,
                    receipts=self.receipts, joined=joined, clients_joined=len(self.clients))

def source_identity():
    sources = [Path(__file__), CLIENT, ROOT / "integration/upstream_transport/fixture.exs",
               ROOT / "apps/gaoxy_proxy/test/support/managed_h1_matrix_fixture.exs",
               ROOT / "apps/gaoxy_proxy/test/upstream_transport_h1_matrix_test.exs"]
    return dict(python=sys.executable, packages={p: importlib.metadata.version(p) for p in ("h2", "hpack", "hyperframe")},
                revision=os.environ.get("GAOXY_SOURCE_REVISION", "unprovided; use retained source hashes"),
                sources={str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources})


def overall_alarm(*_):
    raise TimeoutError("finite overall deadline")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--attached", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--case", choices=CASES)
    args = parser.parse_args()
    check(not args.attached or args.case is not None, "attached mode requires exact case identity")
    registry = [args.case] if args.case else CASES
    if args.attached:
        if os.getpgrp() != os.getpid():
            os.setpgid(0, 0)
        print(json.dumps(dict(event="driver_ready", pid=os.getpid(), group=os.getpgrp())), flush=True)
    signal.signal(signal.SIGALRM, overall_alarm)
    signal.setitimer(signal.ITIMER_REAL, 340)
    host, clients, results, cleanup = None, [], [], []
    overall = time.monotonic() + 340
    try:
        identity = source_identity()
        host = Host(args.attached, clients)
        for case_id in registry:
            check(time.monotonic() < overall, "finite overall deadline")
            case = None
            try:
                case = Case(host, case_id)
                result = case.run()
            except Exception as error:
                result = dict(event="case_result", case=case_id, status="FAIL", reason=repr(error),
                              receipts=case.receipts if case is not None else [])
            result["identity"] = identity
            check(case_id not in [r["case"] for r in results], "duplicate executed case")
            results.append(result)
            if result["status"] != "PASS":
                break
        if not host.active:
            host.finish()
    except Exception as error:
        if not results:
            raise
        results[-1].update(status="FAIL", matrix_failure=repr(error))
    finally:
        # Cleanup has its own absolute shutdown budget. The overall alarm must
        # not interrupt the sweep and strand the remaining owned clients.
        signal.setitimer(signal.ITIMER_REAL, 0)
        expires = time.monotonic() + 10
        cleanup.extend(cleanup_clients(clients, expires))
        if host is not None and not host.finished:
            if host.active:
                try:
                    host.stop(timeout=max(0, expires - time.monotonic()))
                except BaseException as error:
                    cleanup.append("fixture cleanup: " + repr(error))
            try:
                host.abort(expires)
            except BaseException as error:
                cleanup.append("fixture process cleanup: " + repr(error))
        if args.attached:
            print(json.dumps(dict(event="driver_joined", case=args.case,
                                  owned=sum(client.process is not None for client in clients),
                                  joined=sum(client.joined for client in clients),
                                  live=sum(client.process is not None and client.process.returncode is None
                                           for client in clients),
                                  forced=sum(client.process is not None and not client.joined
                                             for client in clients), errors=cleanup)), flush=True)
        if cleanup and results:
            results[-1].update(status="FAIL", cleanup=cleanup)
        for result in results:
            print(json.dumps(result, separators=(",", ":")), flush=True)
    failed = sum(result["status"] != "PASS" for result in results)
    missing = [case_id for case_id in registry if case_id not in [r["case"] for r in results]]
    if not args.attached:
        print(json.dumps(dict(event="matrix_finished", executed=len(results), failed=failed,
                              expected=len(registry), missing=missing, finished=host.finished,
                              cleanup=cleanup, identity=identity)), flush=True)
    return 1 if failed or missing or cleanup or not host.finished else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(json.dumps(dict(event="matrix_failure", reason=repr(error))), flush=True)
        raise SystemExit(1)
