#!/usr/bin/env python3
"""Exercise native H1/H2 to dedicated H1 proxy traffic in a built release."""
import argparse
import http.client
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import queue
import socket
import subprocess
import tempfile
import threading
import time

from h2.config import H2Configuration
from h2.connection import H2Connection
from h2.events import ConnectionTerminated, DataReceived, ResponseReceived, StreamEnded, StreamReset

ROOT = Path(__file__).resolve().parents[1]
PAYLOAD = b"standalone-gateway-upload\x00" * 1024
PATHS = ("/release-h1?escaped=%2F", "/release-h2?escaped=%2F")


def response_body(path):
    return path.encode() + b"\n" + PAYLOAD


class Upstream(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def setup(self):
        super().setup()
        self.connection.settimeout(5)

    def do_POST(self):
        try:
            assert self.request_version == "HTTP/1.1", self.request_version
            assert self.path in PATHS, self.path
            assert self.headers.get("X-Release-Smoke") == "gateway"
            assert self.headers.get("Transfer-Encoding") is None
            assert int(self.headers["Content-Length"]) == len(PAYLOAD)
            assert self.rfile.read(len(PAYLOAD)) == PAYLOAD
            body = response_body(self.path)
            self.send_response(201)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("X-Release-Peer", "dedicated-h1")
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(body)
            self.wfile.flush()
            self.server.results.put(self.path)
        except BaseException as error:
            self.server.results.put(error)
            raise
        finally:
            self.close_connection = True

    def log_message(self, *_):
        pass


def wait_for_readiness(process, ready, output):
    deadline = time.monotonic() + 20
    while process.poll() is None and time.monotonic() < deadline:
        try:
            data = json.loads(ready.read_text())
            assert data["version"] == 1
            assert len(data["services"]) == 2
            addresses = {}
            for service in data["services"]:
                assert service["transport"] == "tcp"
                assert service["address"] == "127.0.0.1" and service["port"] > 0
                addresses[service["id"]] = (service["address"], service["port"])
            assert set(addresses) == {"gateway-h1", "gateway-h2"}
            assert len(set(addresses.values())) == 2
            return addresses
        except (FileNotFoundError, json.JSONDecodeError):
            time.sleep(0.01)
    output.seek(0)
    raise AssertionError("gateway release readiness failed:\n" + output.read())


def h1_exchange(address):
    client = http.client.HTTPConnection(*address, timeout=5)
    try:
        client.request("POST", PATHS[0], PAYLOAD, {"X-Release-Smoke": "gateway"})
        response = client.getresponse()
        assert response.status == 201, response.status
        assert response.getheader("X-Release-Peer") == "dedicated-h1"
        assert response.read(len(response_body(PATHS[0])) + 1) == response_body(PATHS[0])
    finally:
        client.close()


def h2_exchange(address):
    connection = H2Connection(config=H2Configuration(client_side=True, header_encoding="utf-8"))
    connection.initiate_connection()
    connection.send_headers(1, [
        (":method", "POST"), (":scheme", "http"),
        (":authority", f"{address[0]}:{address[1]}"), (":path", PATHS[1]),
        ("content-length", str(len(PAYLOAD))), ("x-release-smoke", "gateway"),
    ])
    for start in range(0, len(PAYLOAD), connection.max_outbound_frame_size):
        chunk = PAYLOAD[start:start + connection.max_outbound_frame_size]
        connection.send_data(1, chunk, end_stream=start + len(chunk) == len(PAYLOAD))
    headers, body = None, bytearray()
    deadline = time.monotonic() + 10
    with socket.create_connection(address, timeout=5) as client:
        client.sendall(connection.data_to_send())
        while True:
            remaining = deadline - time.monotonic()
            assert remaining > 0, "H2 response deadline"
            client.settimeout(remaining)
            data = client.recv(65536)
            assert data, "H2 connection closed before END_STREAM"
            ended = False
            for event in connection.receive_data(data):
                assert not isinstance(event, (StreamReset, ConnectionTerminated)), event
                if isinstance(event, ResponseReceived):
                    assert event.stream_id == 1
                    headers = dict(event.headers)
                elif isinstance(event, DataReceived):
                    assert event.stream_id == 1
                    body.extend(event.data)
                    assert len(body) <= len(response_body(PATHS[1])), "excess H2 response body"
                    connection.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
                elif isinstance(event, StreamEnded):
                    assert event.stream_id == 1
                    ended = True
            pending = connection.data_to_send()
            if pending:
                client.sendall(pending)
            if ended:
                assert headers is not None and headers.get(":status") == "201", headers
                assert headers.get("x-release-peer") == "dedicated-h1", headers
                assert bytes(body) == response_body(PATHS[1])
                connection.close_connection()
                client.sendall(connection.data_to_send())
                return


def assert_reusable(address):
    try:
        socket.create_connection(address, timeout=0.3).close()
    except ConnectionRefusedError:
        pass
    else:
        raise AssertionError(f"listener leaked after shutdown: {address}")
    with socket.socket() as replacement:
        replacement.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        replacement.bind(address)
        replacement.listen(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", type=Path, default=ROOT / "_build/prod/rel/gaoxy/bin/gaoxy")
    release = parser.parse_args().release.resolve()
    assert release.is_file() and os.access(release, os.X_OK), f"missing release executable: {release}"
    upstream = HTTPServer(("127.0.0.1", 0), Upstream)
    upstream.results = queue.Queue()
    peer = threading.Thread(target=upstream.serve_forever, kwargs={"poll_interval": 0.05})
    peer.start()
    try:
        with tempfile.TemporaryDirectory(prefix="gaoxy-gateway-release-") as directory:
            fixture = Path(directory)
            config, ready = fixture / "config.json", fixture / "ready.json"
            services = [{
                "id": identity, "transport": "tcp", "handler": "http",
                "ip": "127.0.0.1", "port": 0,
                "protocols": [protocol], "h2c": h2c,
                "limits": {"max_bytes": 536870912, "max_active": 128},
                "routes": {"version": 1, "routes": [{"target": {
                    "type": "reverse_proxy",
                    "upstream": f"http://127.0.0.1:{upstream.server_port}",
                }}]},
            } for identity, protocol, h2c in (
                ("gateway-h1", "http1", "disabled"),
                ("gateway-h2", "http2", "prior_knowledge"),
            )]
            config.write_text(json.dumps({"version": 1, "services": services}))
            environment = dict(os.environ, GAOXY_CONFIG=str(config), GAOXY_READY_FILE=str(ready),
                               ERL_CRASH_DUMP=str(fixture / "erl_crash.dump"))
            with (fixture / "release.log").open("w+") as output:
                process = subprocess.Popen([str(release), "start"], env=environment, stdout=output, stderr=output)
                try:
                    addresses = wait_for_readiness(process, ready, output)
                    h1_exchange(addresses["gateway-h1"])
                    h2_exchange(addresses["gateway-h2"])
                    assert [upstream.results.get(timeout=5) for _ in PATHS] == list(PATHS)
                    assert upstream.results.empty(), "unexpected upstream request"
                    process.terminate()
                    assert process.wait(timeout=10) == 0, "release did not stop cleanly"
                    for address in addresses.values():
                        assert_reusable(address)
                except BaseException:
                    output.seek(0)
                    print("Gateway release diagnostic:\n" + output.read(), flush=True)
                    raise
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.wait(timeout=5)
    finally:
        upstream.shutdown()
        upstream.server_close()
        peer.join(timeout=6)
        assert not peer.is_alive(), "upstream thread did not stop"
        assert_reusable(upstream.server_address)
    print("PASS standalone gateway release readiness, native H1/H2 POST uploads and responses "
          "through dedicated H1 upstream, SIGTERM exit0 and gateway/upstream port reuse; 2 exchanges")


if __name__ == "__main__":
    main()
