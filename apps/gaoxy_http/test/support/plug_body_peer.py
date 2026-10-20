"""Ordinary independent H2/H3 Plug parser regressions; no specialist workloads."""
import asyncio
import socket
import sys
from types import SimpleNamespace


def rows():
    for content_type, body in [
        (b"application/json", b'{"value":"' + b"x" * 20000 + b'"}'),
        (b"application/x-www-form-urlencoded", b"value=" + b"x" * 20000),
    ]:
        yield b"/parse", content_type, body, b"200", b"20000"
    yield b"/parser-limit", b"application/json", b'{"value":"' + b"x" * 20000 + b'"}', b"413", b""


def h2_run(port):
    import h2.config
    import h2.connection
    import h2.events
    conn = h2.connection.H2Connection(config=h2.config.H2Configuration(client_side=True))
    with socket.create_connection(("127.0.0.1", port), timeout=5) as sock:
        conn.initiate_connection()
        sock.sendall(conn.data_to_send())
        for path, content_type, body, status, expected in rows():
            sid = conn.get_next_available_stream_id()
            conn.send_headers(sid, [(b":method", b"POST"), (b":scheme", b"http"),
                (b":authority", b"localhost"), (b":path", path),
                (b"content-type", content_type), (b"content-length", str(len(body)).encode())])
            for offset in range(0, len(body), 16384):
                conn.send_data(sid, body[offset:offset + 16384], end_stream=offset + 16384 >= len(body))
            sock.sendall(conn.data_to_send())
            headers, response, ended = [], b"", False
            while not ended:
                wire = sock.recv(65536)
                assert wire, "H2 closed before parser response"
                for event in conn.receive_data(wire):
                    assert not isinstance(event, (h2.events.StreamReset, h2.events.ConnectionTerminated)), event
                    if getattr(event, "stream_id", None) == sid:
                        if isinstance(event, h2.events.ResponseReceived):
                            headers = event.headers
                        elif isinstance(event, h2.events.DataReceived):
                            response += event.data
                            conn.acknowledge_received_data(event.flow_controlled_length, sid)
                        elif isinstance(event, h2.events.StreamEnded):
                            ended = True
                pending = conn.data_to_send()
                if pending:
                    sock.sendall(pending)
            assert dict(headers)[b":status"] == status, (headers, response)
            assert response == expected, (path, response)
            print(f"PASS H2 Plug parser {content_type.decode()} {path.decode()}", flush=True)


async def h3_run(port, ca):
    sys.path.insert(0, "integration/http3")
    from peer import opened
    args = SimpleNamespace(mode="plug-body", port=port, ca=ca)
    async with opened(args) as client:
        for path, content_type, body, status, expected in rows():
            sid = client.request(b"POST", path, [(b"content-type", content_type),
                (b"content-length", str(len(body)).encode())], fin=False)
            client.http.send_data(sid, body, end_stream=True)
            client.transmit()
            await client.response(sid, expected, status)
            print(f"PASS H3 Plug parser {content_type.decode()} {path.decode()}", flush=True)
        assert not client.resets and not client.stops
        await asyncio.wait_for(client.ping(), 5)


if sys.argv[1] == "h2":
    h2_run(int(sys.argv[2]))
else:
    asyncio.run(h3_run(int(sys.argv[2]), sys.argv[3]))
