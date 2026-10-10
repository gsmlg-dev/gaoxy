#!/usr/bin/env python3
"""Selected RFC 9113 wire/error-scope gates against an owned loopback fixture."""
import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import queue
import socket
import struct
import subprocess
import threading
import time

from hpack import Decoder, Encoder

ROOT = Path(__file__).resolve().parents[2]
PREFACE = b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"


def frame(kind, flags=0, stream=0, payload=b""):
    return len(payload).to_bytes(3, "big") + bytes((kind, flags)) + struct.pack("!I", stream) + payload


def number(value):
    return struct.pack("!I", value)


def source_hashes():
    paths = sorted(ROOT.glob("apps/*/lib/**/*.*")) + sorted(ROOT.glob("integration/h2_rfc/*")) + sorted(ROOT.glob("apps/*/mix.exs")) + [ROOT / "mix.lock", ROOT / "mix.exs"]
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths if path.is_file()}


class Wire:
    def __init__(self, port, initial=frame(4)):
        self.socket = socket.create_connection(("127.0.0.1", port), timeout=3)
        self.socket.settimeout(3)
        self.encoder = Encoder()
        self.encoder.header_table_size = 0
        self.decoder = Decoder()
        self.socket.sendall(PREFACE + initial)
        if initial == frame(4):
            settings, acknowledgement = False, False
            while not (settings and acknowledgement):
                kind, flags, stream, _ = self.receive()
                assert kind == 4 and stream == 0, (kind, flags, stream)
                if flags & 1:
                    acknowledgement = True
                else:
                    settings = True
                    self.send(frame(4, 1))

    def close(self):
        self.socket.close()

    def send(self, *frames):
        self.socket.sendall(b"".join(frames))

    def exact(self, length):
        result = bytearray()
        while len(result) < length:
            data = self.socket.recv(length - len(result))
            assert data, "connection closed before complete frame"
            result.extend(data)
        return bytes(result)

    def receive(self):
        header = self.exact(9)
        kind, flags = header[3:5]
        stream = int.from_bytes(header[5:], "big") & 0x7fffffff
        payload = self.exact(int.from_bytes(header[:3], "big"))
        return kind, flags, stream, payload

    def headers(self, stream, path="/sibling", ended=True, extra=()):
        fields = [(":method", "GET"), (":scheme", "http"), (":authority", "localhost"), (":path", path)]
        return frame(1, 4 | int(ended), stream, self.encoder.encode(fields + list(extra)))

    def error(self, scope, code, stream=0):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            kind, _, current, payload = self.receive()
            if kind in (3, 7):
                assert kind == scope and current == stream, (kind, current, payload.hex())
                actual = int.from_bytes(payload[4:8] if kind == 7 else payload, "big")
                assert actual == code, (actual, code)
                return
        raise AssertionError("error frame deadline")

    def response(self, stream):
        body, headers, block = bytearray(), [], bytearray()
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            kind, flags, current, payload = self.receive()
            assert kind not in (3, 7), (kind, current, payload.hex())
            if kind == 4 and not flags & 1:
                self.send(frame(4, 1))
            if current != stream:
                continue
            if kind in (1, 9):
                block.extend(payload)
                if flags & 4:
                    headers.extend(self.decoder.decode(bytes(block)))
                    block.clear()
            elif kind == 0:
                body.extend(payload)
            if kind in (0, 1) and flags & 1:
                assert (":status", "200") in headers and bytes(body) == b"/sibling", (headers, bytes(body))
                return
        raise AssertionError("exact sibling response deadline")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    args.evidence.mkdir(parents=True, exist_ok=True)
    hashes = source_hashes()
    report = {"status": "FAIL", "scope": "selected RFC 9113 h2c cases, not complete conformance", "source_sha256": hashes,
              "hpack": importlib.metadata.version("hpack"), "checks": []}
    lines = queue.Queue()
    log = (args.evidence / "gateway.log").open("w")
    command = ["mix", "run", "--no-compile", "integration/h2_rfc/fixture.exs"]
    gateway = subprocess.Popen(command, cwd=ROOT, env=dict(os.environ, MIX_ENV="test", ERL_FLAGS="+S 2:2"),
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)

    def read_output():
        for line in gateway.stdout:
            log.write(line)
            log.flush()
            if line.startswith("GAOXY_H2_RFC "):
                lines.put(json.loads(line.removeprefix("GAOXY_H2_RFC ")))

    reader = threading.Thread(target=read_output, daemon=True)
    reader.start()

    def control(value):
        gateway.stdin.write(value + "\n")
        gateway.stdin.flush()
        return lines.get(timeout=7)

    def zero():
        deadline = time.monotonic() + 3
        while True:
            state = control("sample")
            if state["active"] == state["retained_bytes"] == state["cleanup_pending"] == 0 and state["cleanup_failed"] is None:
                return state
            assert time.monotonic() < deadline, state

    try:
        ready = lines.get(timeout=30)
        assert ready["event"] == "ready", ready
        report.update(runtime=ready, command=command)
        port = ready["port"]

        def check(name, fn, initial=frame(4)):
            wire = Wire(port, initial)
            try:
                fn(wire)
            finally:
                wire.close()
            result = {"name": name, "status": "PASS", "cleanup": zero()}
            report["checks"].append(result)
            print(json.dumps(result), flush=True)

        # Each tuple fixes RFC error scope/code before observing the candidate.
        connections = [
            ("settings_stream", frame(4, stream=1), 1),
            ("settings_ack_payload", frame(4, 1, payload=b"x"), 6),
            ("settings_tuple_length", frame(4, payload=b"x"), 6),
            ("settings_push_value", frame(4, payload=struct.pack("!HI", 2, 2)), 1),
            ("settings_initial_window", frame(4, payload=struct.pack("!HI", 4, 0x80000000)), 3),
            ("settings_frame_size", frame(4, payload=struct.pack("!HI", 5, 16383)), 1),
            ("ping_stream", frame(6, stream=1, payload=b"12345678"), 1),
            ("ping_length", frame(6, payload=b"1234567"), 6),
            ("rst_zero_stream", frame(3, payload=number(8)), 1),
            ("rst_idle_stream", frame(3, stream=1, payload=number(8)), 1),
            ("rst_length", frame(3, stream=1, payload=b"x"), 6),
            ("priority_zero_stream", frame(2, payload=number(0) + b"\x00"), 1),
            ("goaway_stream", frame(7, stream=1, payload=number(0) + number(0)), 1),
            ("goaway_length", frame(7, payload=b"x"), 6),
            ("window_zero_connection", frame(8, payload=number(0)), 1),
            ("window_idle_stream", frame(8, stream=1, payload=number(1)), 1),
            ("window_zero_idle_stream", frame(8, stream=1, payload=number(0)), 1),
            ("window_length", frame(8, payload=b"x"), 6),
            ("window_connection_overflow", frame(8, payload=number(0x7fffffff)), 3),
            ("data_zero_stream", frame(0), 1),
            ("data_idle_stream", frame(0, stream=1), 1),
            ("headers_zero_stream", frame(1, 5, payload=b"\x82"), 1),
            ("headers_even_stream", frame(1, 5, 2, b"\x82"), 1),
            ("headers_invalid_padding", frame(1, 13, 1, b"\xff"), 1),
            ("headers_priority_length", frame(1, 37, 1, b"x"), 6),
            ("continuation_without_headers", frame(9, 4, 1), 1),
            ("continuation_interleaving", frame(1, 0, 1, b"\x82") + frame(6, payload=b"12345678"), 1),
            ("continuation_wrong_stream", frame(1, 0, 1, b"\x82") + frame(9, 4, 3), 1),
            ("hpack_invalid_index", frame(1, 5, 1, b"\x80"), 9),
            ("oversized_frame_header", (16385).to_bytes(3, "big") + b"\x00\x00" + number(1), 6),
        ]
        for name, payload, code in connections:
            check(name, lambda wire, payload=payload, code=code: (wire.send(payload), wire.error(7, code)))
        check("first_frame_must_settings", lambda wire: wire.error(7, 1), frame(6, payload=b"12345678"))
        check("first_settings_cannot_ack", lambda wire: wire.error(7, 1), frame(4, 1))

        def stream_error(wire, bad, code):
            wire.send(wire.headers(1, "/hold", ended=False), bad)
            wire.error(3, code, 1)
            wire.send(wire.headers(3))
            wire.response(3)

        for name, payload, code in [
            ("window_zero_stream_sibling", frame(8, stream=1, payload=number(0)), 1),
            ("window_stream_overflow_sibling", frame(8, stream=1, payload=number(0x7fffffff)), 3),
            ("priority_self_dependency_sibling", frame(2, stream=1, payload=number(1) + b"\x00"), 1),
            ("priority_length_sibling", frame(2, stream=1, payload=b"x"), 6),
        ]:
            check(name, lambda wire, payload=payload, code=code: stream_error(wire, payload, code))

        def bad_fields(wire, extra):
            wire.send(wire.headers(1, extra=extra))
            wire.error(3, 1, 1)
            wire.send(wire.headers(3))
            wire.response(3)

        for name, extra in [("duplicate_pseudo_sibling", [(":method", "GET")]),
                            ("connection_header_sibling", [("connection", "close")]),
                            ("uppercase_field_sibling", [("X-Bad", "value")])]:
            check(name, lambda wire, extra=extra: bad_fields(wire, extra))

        def ignored_extensions(wire):
            wire.send(frame(4, payload=struct.pack("!HI", 65535, 42)), frame(255, stream=19, payload=b"opaque"), wire.headers(1))
            wire.response(1)

        check("unknown_setting_and_frame_ignored", ignored_extensions)
        report["teardown"] = control("stop")
        assert report["teardown"] == {"event": "stopped", "runtime_down": True, "port_rebound": True}
        assert gateway.wait(timeout=7) == 0
        assert source_hashes() == hashes, "production source changed during gate"
        report.update(status="PASS", executed=len(report["checks"]), exit=0)
    except BaseException as error:
        report.update(error=repr(error), executed=len(report["checks"]), exit=1)
        raise
    finally:
        if gateway.poll() is None:
            gateway.terminate()
            try:
                gateway.wait(timeout=5)
            except subprocess.TimeoutExpired:
                gateway.kill()
                gateway.wait(timeout=5)
        reader.join(timeout=2)
        log.close()
        (args.evidence / "results.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
