"""Finite independent TLS H1/H2 and QUIC H3 listener-composition checks."""
import asyncio
import json
from pathlib import Path
import socket
import ssl
import sys
from types import SimpleNamespace

import h2.connection
import h2.events


def h1(port, ca, path):
    context = ssl.create_default_context(cafile=ca)
    context.set_alpn_protocols(["http/1.1"])
    with socket.create_connection(("127.0.0.1", port), timeout=5) as raw:
        with context.wrap_socket(raw, server_hostname="localhost") as client:
            assert client.selected_alpn_protocol() == "http/1.1"
            client.sendall(f"GET {path} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n".encode())
            data = b""
            while True:
                piece = client.recv(65536)
                if not piece:
                    break
                data += piece
    head, body = data.split(b"\r\n\r\n", 1)
    assert head.startswith(b"HTTP/1.1 200"), data
    return [(name.lower(), value.strip()) for name, value in
            (line.split(b":", 1) for line in head.split(b"\r\n")[1:])], body


def h2(port, ca, path):
    import h2.connection
    import h2.events
    context = ssl.create_default_context(cafile=ca)
    context.set_alpn_protocols(["h2"])
    connection = h2.connection.H2Connection()
    body, headers = b"", []
    with socket.create_connection(("127.0.0.1", port), timeout=5) as raw:
        with context.wrap_socket(raw, server_hostname="localhost") as client:
            assert client.selected_alpn_protocol() == "h2"
            connection.initiate_connection()
            connection.send_headers(1, [(":method", "GET"), (":scheme", "https"),
                                       (":authority", "localhost"), (":path", path)], end_stream=True)
            client.sendall(connection.data_to_send())
            while True:
                data = client.recv(65536)
                assert data, "premature H2 close"
                ended = False
                for event in connection.receive_data(data):
                    if isinstance(event, h2.events.ResponseReceived):
                        headers = event.headers
                    elif isinstance(event, h2.events.DataReceived):
                        body += event.data
                        connection.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
                    elif isinstance(event, h2.events.StreamEnded):
                        ended = True
                client.sendall(connection.data_to_send())
                if ended:
                    assert (b":status", b"200") in headers, headers
                    return headers, body


async def h3(port, ca):
    sys.path.insert(0, str(Path.cwd() / "integration/http3"))
    from peer import opened
    async with opened(SimpleNamespace(port=port, ca=ca, mode="startup")) as client:
        sid = client.request(path=b"/normal")
        await client.response(sid, body=b"HTTP/3")
        assert client.negotiated == "h3"
        return client.negotiated


def main():
    tls_port, h3_port, ca = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    for path in ["/normal", "/stream", "/file"]:
        for request, version in [(h1, b"HTTP/1.1"), (h2, b"HTTP/2")]:
            headers, body = request(tls_port, ca, path)
            values = [value for name, value in headers if name == b"alt-svc"]
            assert values == [f'h3=":{h3_port}"; ma=60'.encode()], (path, version, headers)
            if path == "/normal":
                assert body == version, (path, body)
            elif path == "/file":
                assert body == b"listener-file", body
            else:
                assert b"listener-stream" in body, body
    assert asyncio.run(h3(h3_port, ca)) == "h3"
    print(json.dumps({"result": "PASS", "versions": ["HTTP/1.1", "HTTP/2", "HTTP/3"],
                      "discovery_paths": ["normal", "stream", "file"], "udp_port": h3_port}))


if __name__ == "__main__":
    main()
