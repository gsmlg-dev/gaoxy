"""Independent HTTP peers preserve HEAD metadata and ordinary GET framing."""
import asyncio
import socket
import sys
from types import SimpleNamespace


def rows():
    for method in (b"HEAD", b"GET"):
        for path, status, declared, body in (
            (b"/declared", b"200", b"12345", b""),
            (b"/declared-body", b"200", b"12345", b"body"),
            (b"/inferred", b"200", b"4", b"body"),
            (b"/empty", b"200", b"0", b""),
            (b"/zero", b"200", b"0", b""),
            (b"/204", b"204", None, b"body"),
            (b"/205", b"205", b"0", b"body"),
            (b"/304", b"304", b"12345", b"body"),
        ):
            length = declared
            if method == b"GET" and status == b"200":
                length = str(len(body)).encode()
            expected = b"" if method == b"HEAD" or status != b"200" else body
            yield method, path, status, length, expected


def check(protocol, row, headers, body):
    method, path, status, length, expected = row
    lengths = [value for name, value in headers if name == b"content-length"]
    assert lengths == ([] if length is None else [length]), (protocol, row, headers)
    assert body == expected, (protocol, row, body)
    print(f"PASS {protocol} {method.decode()} {path.decode()} metadata and body", flush=True)


def h1_run(port):
    for row in rows():
        method, path, status, _, _ = row
        with socket.create_connection(("127.0.0.1", port), timeout=5) as sock:
            sock.sendall(method + b" " + path +
                         b" HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
            wire = b""
            while chunk := sock.recv(65536):
                wire += chunk
        head, body = wire.split(b"\r\n\r\n", 1)
        status_line, *fields = head.split(b"\r\n")
        assert status_line.split()[1] == status, wire
        headers = [(name.lower(), value.strip()) for name, value in
                   (field.split(b":", 1) for field in fields)]
        check("H1", row, headers, body)


def h2_run(port):
    import h2.config
    import h2.connection
    import h2.events
    conn = h2.connection.H2Connection(config=h2.config.H2Configuration(client_side=True))
    with socket.create_connection(("127.0.0.1", port), timeout=5) as sock:
        conn.initiate_connection()
        sock.sendall(conn.data_to_send())
        for row in rows():
            method, path, status, _, _ = row
            sid = conn.get_next_available_stream_id()
            conn.send_headers(sid, [(b":method", method), (b":scheme", b"http"),
                (b":authority", b"localhost"), (b":path", path)], end_stream=True)
            sock.sendall(conn.data_to_send())
            headers, body, ended = [], b"", False
            while not ended:
                wire = sock.recv(65536)
                assert wire, "H2 closed before response completed"
                for event in conn.receive_data(wire):
                    assert not isinstance(event, (h2.events.StreamReset, h2.events.ConnectionTerminated)), event
                    if getattr(event, "stream_id", None) == sid:
                        if isinstance(event, h2.events.ResponseReceived):
                            headers = event.headers
                        elif isinstance(event, h2.events.DataReceived):
                            body += event.data
                            conn.acknowledge_received_data(event.flow_controlled_length, sid)
                        elif isinstance(event, h2.events.StreamEnded):
                            ended = True
                pending = conn.data_to_send()
                if pending:
                    sock.sendall(pending)
            assert dict(headers)[b":status"] == status, headers
            check("H2", row, headers, body)


async def h3_run(port, ca):
    sys.path.insert(0, "integration/http3")
    from peer import opened
    args = SimpleNamespace(mode="head-content-length", port=port, ca=ca)
    # The pinned aioquic H3 parser does not model HEAD's Content-Length exception.
    # Its independent raw QUIC/QPACK peer checks exact DATA and FIN instead.
    async with opened(args, standard=False) as client:
        client.setup()
        for row in rows():
            method, path, status, _, expected = row
            sid = client.request(method, path)
            await client.response(sid, expected, status)
            check("H3", row, client.headers[sid][0], client.data.get(sid, b""))
        assert not client.resets and not client.stops
        await asyncio.wait_for(client.ping(), 5)


if sys.argv[1] == "h1":
    h1_run(int(sys.argv[2]))
elif sys.argv[1] == "h2":
    h2_run(int(sys.argv[2]))
else:
    asyncio.run(h3_run(int(sys.argv[2]), sys.argv[3]))
