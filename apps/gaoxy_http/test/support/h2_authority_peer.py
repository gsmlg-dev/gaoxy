"""Independent ordinary malformed-authority stream isolation regression."""
import socket
import sys
import time

import h2.config
import h2.connection
import h2.events


port = int(sys.argv[1])
config = h2.config.H2Configuration(
    client_side=True,
    header_encoding="utf-8",
    # Deliberately transmit the malformed request rather than reject it locally.
    validate_outbound_headers=False,
)
conn = h2.connection.H2Connection(config=config)
responses = {}
finished = set()
resets = {}
pings = set()
deadline = time.monotonic() + 8


def fields(path):
    return [
        (":method", "GET"),
        (":scheme", "http"),
        (":authority", "localhost"),
        (":path", path),
    ]


with socket.create_connection(("127.0.0.1", port), timeout=3) as sock:
    def flush():
        data = conn.data_to_send()
        if data:
            sock.sendall(data)

    def receive_until(predicate):
        while not predicate():
            remaining = deadline - time.monotonic()
            assert remaining > 0, "authority peer deadline"
            sock.settimeout(min(3, remaining))
            data = sock.recv(65536)
            assert data, "unexpected connection closure"
            for event in conn.receive_data(data):
                if isinstance(event, h2.events.ResponseReceived):
                    responses.setdefault(event.stream_id, {"headers": [], "body": b""})[
                        "headers"
                    ].extend(event.headers)
                elif isinstance(event, h2.events.DataReceived):
                    responses[event.stream_id]["body"] += event.data
                    conn.acknowledge_received_data(
                        event.flow_controlled_length, event.stream_id
                    )
                elif isinstance(event, h2.events.StreamEnded):
                    finished.add(event.stream_id)
                elif isinstance(event, h2.events.StreamReset):
                    assert event.stream_id == 3, repr(event)
                    resets[event.stream_id] = int(event.error_code)
                elif isinstance(event, h2.events.ConnectionTerminated):
                    raise AssertionError(repr(event))
                elif isinstance(event, h2.events.PingAckReceived):
                    pings.add(event.ping_data)
            flush()

    conn.initiate_connection()
    # Keep stream 1 open while stream 3's malformed header block is processed.
    sibling = [(":method", "POST")] + fields("/sibling")[1:]
    conn.send_headers(1, sibling + [("content-length", "7")], end_stream=False)
    conn.send_headers(
        3,
        [(name, value) for name, value in fields("/malformed") if name != ":authority"],
        end_stream=True,
    )
    flush()
    receive_until(lambda: 3 in resets)
    assert resets[3] == 1, resets  # RFC 9113 PROTOCOL_ERROR
    assert 3 not in responses and 3 not in finished, (responses, finished)
    assert 1 not in finished, "sibling completed before its request body"

    conn.send_data(1, b"sibling", end_stream=True)
    flush()
    receive_until(lambda: 1 in finished)
    assert (":status", "200") in responses[1]["headers"], responses
    assert responses[1]["body"] == b"sibling", responses

    # Reuse the same connection after both streams have settled.
    conn.ping(b"authlive")
    conn.send_headers(5, fields("/after"), end_stream=True)
    flush()
    receive_until(lambda: 5 in finished and b"authlive" in pings)
    assert (":status", "200") in responses[5]["headers"], responses
    assert responses[5]["body"] == b"/after", responses
    assert resets == {3: 1}, resets
    conn.close_connection()
    flush()

print("PASS independent H2 authority: PROTOCOL_ERROR reset, active sibling, PING, third request")
