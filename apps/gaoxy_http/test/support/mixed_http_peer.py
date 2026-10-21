"""Explicit H1 and independent Python h2 clients, open together on one TCP port."""
import json
import socket
import sys
import time

import h2.config
import h2.connection
import h2.events


port = int(sys.argv[1])
static_body = sys.argv[2] if len(sys.argv) > 2 else None
h1_socket = socket.create_connection(("127.0.0.1", port), timeout=3)
h2_socket = socket.create_connection(("127.0.0.1", port), timeout=3)
h1_file = h1_socket.makefile("rb")
client = h2.connection.H2Connection(
    config=h2.config.H2Configuration(client_side=True, header_encoding="utf-8")
)


def expected(path, body=b""):
    return static_body.encode() if static_body is not None else path.encode() + b":" + body


def h1_response(path, body=b""):
    status = h1_file.readline(8192)
    assert status == b"HTTP/1.1 200 OK\r\n", repr(status)
    headers = {}
    for _ in range(100):
        line = h1_file.readline(8192)
        if line == b"\r\n":
            break
        name, value = line.decode().split(":", 1)
        headers[name.lower()] = value.strip()
    else:
        raise AssertionError("unbounded H1 headers")
    assert "transfer-encoding" not in headers
    assert h1_file.read(int(headers["content-length"])) == expected(path, body)
    if static_body is None:
        assert headers["x-native-version"] == "HTTP/1.1"


def h2_request(stream, path, body=b""):
    client.send_headers(
        stream,
        [
            (":method", "POST" if body else "GET"),
            (":scheme", "http"),
            (":authority", "localhost"),
            (":path", path),
            ("content-length", str(len(body))),
        ],
        end_stream=not body,
    )
    if body:
        client.send_data(stream, body, end_stream=True)


def h2_response(stream, path, body=b""):
    response = b""
    headers = []
    deadline = time.monotonic() + 4
    while time.monotonic() < deadline:
        h2_socket.settimeout(max(0.01, deadline - time.monotonic()))
        data = h2_socket.recv(65536)
        assert data, "H2 connection closed"
        ended = False
        for event in client.receive_data(data):
            if isinstance(event, h2.events.ResponseReceived):
                assert event.stream_id == stream
                headers.extend(event.headers)
            elif isinstance(event, h2.events.DataReceived):
                assert event.stream_id == stream
                response += event.data
                client.acknowledge_received_data(event.flow_controlled_length, stream)
            elif isinstance(event, h2.events.StreamEnded):
                assert event.stream_id == stream
                ended = True
            elif isinstance(event, (h2.events.StreamReset, h2.events.ConnectionTerminated)):
                raise AssertionError(repr(event))
        pending = client.data_to_send()
        if pending:
            h2_socket.sendall(pending)
        if ended:
            assert (":status", "200") in headers
            assert response == expected(path, body), repr(response)
            if static_body is None:
                assert ("x-native-version", "HTTP/2") in headers
            return
    raise AssertionError("H2 response deadline")


try:
    # The first delivery contains preface + SETTINGS + HEADERS + DATA.
    client.initiate_connection()
    h2_body = b"h2-body" if static_body is None else b""
    h2_request(1, "/h2-first", h2_body)
    first = client.data_to_send()
    assert first.startswith(b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
    h2_socket.sendall(first)
    # The deciding H1 delivery contains headers, body and a pipelined request.
    h1_body = b"h1-body" if static_body is None else b""
    first_h1 = (
        b"POST /h1-first HTTP/1.1\r\nHost: localhost\r\nContent-Length: 7\r\n\r\nh1-body"
        if static_body is None
        else b"GET /h1-first HTTP/1.1\r\nHost: localhost\r\n\r\n"
    )
    h1_socket.sendall(first_h1 + b"GET /h1-pipeline HTTP/1.1\r\nHost: localhost\r\n\r\n")
    h1_response("/h1-first", h1_body)
    h1_response("/h1-pipeline")
    h2_response(1, "/h2-first", h2_body)
    # Both original sockets remain open and each serves additional work.
    h2_request(3, "/h2-second")
    h2_socket.sendall(client.data_to_send())
    h1_socket.sendall(b"GET /h1-second HTTP/1.1\r\nHost: localhost\r\n\r\n")
    h1_response("/h1-second")
    h2_response(3, "/h2-second")
    print(json.dumps({"status": "PASS", "port": port, "h1_requests": 3, "h2_streams": 2,
                      "protocols": ["HTTP/1.1", "HTTP/2"], "simultaneous": True}))
finally:
    h1_file.close()
    h1_socket.close()
    h2_socket.close()
