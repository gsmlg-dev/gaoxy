#!/usr/bin/env python3
"""Exercise the runnable example with an independent stdlib HTTP origin/client."""

import gzip
import http.client
import http.server
import json
import os
from pathlib import Path
import queue
import socket
import subprocess
import tempfile
import threading
import time


ROOT = Path(__file__).resolve().parents[2]
RESULTS = []
NEXT_EVENT = threading.Event()
PAYLOAD = bytes(range(256)) * 1024
COMPRESSED = gzip.compress(b"raw compressed origin bytes", mtime=0)


class Origin(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_args):
        pass

    def do_GET(self):
        if self.path == "/events":
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()
            self.wfile.write(b"9\r\ndata: 1\n\n\r\n")
            self.wfile.flush()
            if not NEXT_EVENT.wait(10):
                raise TimeoutError("client did not observe first SSE event")
            self.wfile.write(b"9\r\ndata: 2\n\n\r\n0\r\n\r\n")
            self.wfile.flush()
        elif self.path == "/redirect":
            self.send_response(302)
            self.send_header("Location", "http://127.0.0.1:1/do-not-follow")
            self.send_header("Content-Length", "0")
            self.end_headers()
        else:
            body = COMPRESSED
            self.send_response(200)
            self.send_header("Content-Encoding", "gzip")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Set-Cookie", "one=1")
            self.send_header("Set-Cookie", "two=2")
            self.end_headers()
            self.wfile.write(body)
            self.wfile.flush()

    def do_POST(self):
        length = int(self.headers["Content-Length"])
        if length != len(PAYLOAD):
            raise AssertionError(f"unexpected upload length: {length}")
        body = self.rfile.read(length)
        if body != PAYLOAD:
            raise AssertionError("upload body changed")
        self.send_response(200)
        self.send_header("Content-Length", str(length))
        self.end_headers()
        self.wfile.write(body)
        self.wfile.flush()


def check(name, fn):
    fn()
    RESULTS.append({"check": name, "status": "PASS"})


def main():
    origin = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Origin)
    origin.daemon_threads = True
    origin_thread = threading.Thread(target=origin.serve_forever, daemon=True)
    origin_thread.start()
    lines = queue.Queue()
    output = []
    gateway = None

    try:
        env = dict(os.environ)
        env.update(
            GAOXY_UPSTREAM=f"http://127.0.0.1:{origin.server_port}",
            GAOXY_PORT="0",
            ELIXIR_ERL_OPTIONS="+S 2:2",
        )
        gateway = subprocess.Popen(
            ["mix", "run", "--no-compile", "examples/reverse_proxy/run.exs"],
            cwd=ROOT,
            env=env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )

        def collect():
            for line in gateway.stdout:
                output.append(line)
                lines.put(line)

        reader = threading.Thread(target=collect, daemon=True)
        reader.start()
        deadline = time.monotonic() + 30
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("gateway readiness deadline")
            line = lines.get(timeout=remaining)
            if line.startswith("GAOXY_PROXY_READY "):
                ready = json.loads(line.removeprefix("GAOXY_PROXY_READY "))
                break

        def connect():
            return http.client.HTTPConnection(ready["address"], ready["port"], timeout=10)

        def local():
            client = connect()
            try:
                client.request("GET", "/local")
                response = client.getresponse()
                assert response.status == 200 and response.read() == b"served locally\n"
            finally:
                client.close()

        def compressed():
            client = connect()
            try:
                client.request("GET", "/gzip")
                response = client.getresponse()
                assert response.status == 200
                assert response.getheader("Content-Encoding") == "gzip"
                assert response.headers.get_all("Set-Cookie") == ["one=1", "two=2"]
                assert response.read() == COMPRESSED
            finally:
                client.close()

        def upload():
            client = connect()
            try:
                client.request("POST", "/echo", body=PAYLOAD)
                response = client.getresponse()
                assert response.status == 200 and response.read() == PAYLOAD
            finally:
                client.close()

        def sse():
            client = connect()
            try:
                client.request("GET", "/events")
                response = client.getresponse()
                assert response.status == 200
                assert response.read(9) == b"data: 1\n\n"
                NEXT_EVENT.set()
                assert response.read() == b"data: 2\n\n"
            finally:
                client.close()

        def redirect():
            client = connect()
            try:
                client.request("GET", "/redirect")
                response = client.getresponse()
                assert response.status == 302
                assert response.getheader("Location") == "http://127.0.0.1:1/do-not-follow"
                assert response.read() == b""
            finally:
                client.close()

        check("local_plug_route", local)
        check("remote_raw_gzip_and_duplicate_cookies", compressed)
        check("streamed_upload_and_download", upload)
        check("sse_before_origin_eof", sse)
        check("manual_redirect", redirect)
        gateway.stdin.write("stop\n")
        gateway.stdin.flush()
        assert gateway.wait(timeout=10) == 0
        reader.join(timeout=2)

        def shutdown():
            with socket.socket() as probe:
                probe.settimeout(1)
                assert probe.connect_ex((ready["address"], ready["port"])) != 0

        check("drain_exit_and_listener_cleanup", shutdown)
    finally:
        NEXT_EVENT.set()
        if gateway is not None and gateway.poll() is None:
            gateway.terminate()
            try:
                gateway.wait(timeout=5)
            except subprocess.TimeoutExpired:
                gateway.kill()
                gateway.wait(timeout=5)
        origin.shutdown()
        origin.server_close()
        origin_thread.join(timeout=2)
        configured = os.environ.get("GAOXY_PROXY_EVIDENCE")
        audit = Path(configured) if configured else Path(tempfile.mkdtemp(prefix="gaoxy-proxy-"))
        audit.mkdir(parents=True, exist_ok=True)
        (audit / "example-server.log").write_text("".join(output))
        (audit / "example-results.json").write_text(json.dumps(RESULTS, indent=2) + "\n")
        print(json.dumps({"results": RESULTS, "evidence": str(audit)}, indent=2))


if __name__ == "__main__":
    main()
