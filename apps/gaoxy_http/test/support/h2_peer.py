"""Independent h2/hpack/hyperframe wire peer; finite deadlines and verified TLS."""
import socket
import ssl
import sys
import time
import h2.connection
import h2.config
import h2.events

port = int(sys.argv[1])
mode = sys.argv[2]
sock = socket.create_connection(("127.0.0.1", port), timeout=3)
if mode == "tls":
    context = ssl.create_default_context(cafile=sys.argv[3])
    context.set_alpn_protocols(["h2"])
    sock = context.wrap_socket(sock, server_hostname="localhost")
    assert sock.selected_alpn_protocol() == "h2"
    assert sock.version() in ("TLSv1.2", "TLSv1.3")
sock.settimeout(3)
conn = h2.connection.H2Connection(config=h2.config.H2Configuration(client_side=True, header_encoding="utf-8"))
conn.initiate_connection()
sock.sendall(conn.data_to_send())
scheme = "https" if mode == "tls" else "http"
def headers(path, method="GET"):
    return [(":method", method), (":scheme", scheme), (":authority", "localhost"), (":path", path), ("x-dynamic", "repeated-huffman-value")]
body = b"0123456789" * 9000
conn.send_headers(1, headers("/echo", "POST") + [("content-length", str(len(body)))], end_stream=False)
conn.send_headers(3, headers("/independent"), end_stream=True)
conn.send_headers(5, headers("/stream"), end_stream=True)
conn.send_headers(7, headers("/head", "HEAD"), end_stream=True)
sock.sendall(conn.data_to_send())
result = {i: {"body": b"", "headers": [], "trailers": []} for i in (1, 3, 5, 7)}
finished = set()
uploaded = 0
deadline = time.monotonic() + 8
while len(finished) < 4:
    assert time.monotonic() < deadline, "independent peer deadline"
    while uploaded < len(body):
        count = min(conn.local_flow_control_window(1), conn.max_outbound_frame_size, len(body) - uploaded)
        if count <= 0:
            break
        conn.send_data(1, body[uploaded:uploaded + count], end_stream=uploaded + count == len(body))
        uploaded += count
    pending = conn.data_to_send()
    if pending:
        sock.sendall(pending)
    data = sock.recv(65536)
    assert data, "unexpected connection closure"
    for event in conn.receive_data(data):
        if isinstance(event, h2.events.ResponseReceived):
            result[event.stream_id]["headers"].extend(event.headers)
        elif isinstance(event, h2.events.TrailersReceived):
            result[event.stream_id]["trailers"].extend(event.headers)
        elif isinstance(event, h2.events.DataReceived):
            result[event.stream_id]["body"] += event.data
            conn.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
        elif isinstance(event, h2.events.StreamEnded):
            finished.add(event.stream_id)
        elif isinstance(event, (h2.events.StreamReset, h2.events.ConnectionTerminated)):
            raise AssertionError(repr(event))
assert result[1]["body"] == body
assert result[3]["body"] == b"/independent"
assert result[5]["body"] == b"onetwo"
assert result[5]["trailers"] == [("x-check", "value")]
assert result[7]["body"] == b""
assert ("content-length", "5") in result[7]["headers"]
for value in result.values():
    assert (":status", "200") in value["headers"]
    assert not any(name in ("connection", "transfer-encoding") for name, _ in value["headers"])
conn.close_connection()
sock.sendall(conn.data_to_send())
sock.close()
print("PASS independent Python h2", mode, "Huffman/dynamic headers, 90KB flow-controlled upload/response, concurrent streams, HEAD, trailers")
