"""Independent finite H1/H2 Plug response and synchronized SSE regressions."""
import json
import socket
import sys
import time

PROTOCOL, MODE, PORT = sys.argv[1], sys.argv[2], int(sys.argv[3])
DEADLINE = time.monotonic() + 10
FIRST = b"event: endpoint\ndata: /mcp\n\n"
SECOND = b'event: message\ndata: {"method":"notifications/ready"}\n\n'
POST_BODY = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                        "params": {"name": "day::now"}}).encode()
POST_EVENT = b'event: message\ndata: {"id":1,"result":"ok"}\n\n: complete\n\n'
HOP = {b"connection", b"keep-alive", b"proxy-connection", b"transfer-encoding",
       b"upgrade", b"te", b"x-one", b"x-two", b"x-three"}


def remaining():
    wait = DEADLINE - time.monotonic()
    assert wait > 0, "finite peer deadline expired"
    return wait


def check_headers(headers):
    assert [(k, v) for k, v in headers if k == b"set-cookie"] == [
        (b"set-cookie", b"a=1"), (b"set-cookie", b"b=2")], headers
    assert (b"x-ordinary", b"preserved") in headers, headers
    if PROTOCOL == "h2":
        assert not HOP.intersection(k for k, _ in headers), headers
    else:
        assert (b"connection", b"keep-alive, X-One") in headers, headers
        assert (b"x-one", b"hop-one") in headers, headers
        assert (b"x-two", b"hop-two") in headers, headers
        assert (b"x-three", b"hop-three") in headers, headers


class H1:
    def __init__(self):
        self.sock = socket.create_connection(("127.0.0.1", PORT), timeout=remaining())
        self.buffer = b""

    def close(self):
        self.sock.close()

    def request(self, method, path, body=b""):
        self.sock.sendall(method + b" " + path + b" HTTP/1.1\r\nHost: localhost\r\n"
                          b"Content-Type: application/json\r\nContent-Length: " +
                          str(len(body)).encode() + b"\r\n\r\n" + body)

    def take(self, count):
        while len(self.buffer) < count:
            self.sock.settimeout(remaining())
            chunk = self.sock.recv(65536)
            assert chunk, "H1 closed before response completed"
            self.buffer += chunk
            assert len(self.buffer) <= 131072, "finite fixture buffer exceeded"
        result, self.buffer = self.buffer[:count], self.buffer[count:]
        return result

    def line(self):
        while b"\r\n" not in self.buffer:
            self.sock.settimeout(remaining())
            chunk = self.sock.recv(65536)
            assert chunk, "H1 closed before response head completed"
            self.buffer += chunk
            assert len(self.buffer) <= 131072, "finite fixture head exceeded"
        result, self.buffer = self.buffer.split(b"\r\n", 1)
        return result

    def head(self):
        status = int(self.line().split()[1])
        headers = []
        while line := self.line():
            name, value = line.split(b":", 1)
            headers.append((name.lower(), value.strip()))
        return status, headers

    def chunk(self):
        count = int(self.line(), 16)
        assert count <= 65536, "unexpected fixture chunk size"
        if count == 0:
            assert self.line() == b"", "unexpected trailers"
            return None
        body = self.take(count)
        assert self.take(2) == b"\r\n"
        return body

    def response(self):
        informational = []
        status, headers = self.head()
        while status < 200:
            informational.append((status, headers))
            status, headers = self.head()
        if (b"transfer-encoding", b"chunked") in headers:
            body = b""
            while (chunk := self.chunk()) is not None:
                body += chunk
                assert len(body) <= 65536
        else:
            body = self.take(int(dict(headers)[b"content-length"]))
        return status, headers, body, informational


class H2:
    def __init__(self):
        import h2.config
        import h2.connection
        import h2.events
        self.events = h2.events
        self.conn = h2.connection.H2Connection(config=h2.config.H2Configuration(
            client_side=True, normalize_inbound_headers=False, validate_inbound_headers=True))
        self.sock = socket.create_connection(("127.0.0.1", PORT), timeout=remaining())
        self.responses = {}
        self.conn.initiate_connection()
        self.flush()

    def close(self):
        self.sock.close()

    def flush(self):
        if pending := self.conn.data_to_send():
            self.sock.sendall(pending)

    def request(self, method, path, body=b""):
        sid = self.conn.get_next_available_stream_id()
        self.responses[sid] = {"headers": [], "body": b"", "informational": [], "ended": False}
        self.conn.send_headers(sid, [(b":method", method), (b":scheme", b"http"),
            (b":authority", b"localhost"), (b":path", path),
            (b"content-type", b"application/json"), (b"content-length", str(len(body)).encode())],
            end_stream=not body)
        if body:
            self.conn.send_data(sid, body, end_stream=True)
        self.flush()
        return sid

    def wait(self, condition):
        while not condition():
            self.sock.settimeout(remaining())
            wire = self.sock.recv(65536)
            assert wire, "H2 closed before response completed"
            for event in self.conn.receive_data(wire):
                assert not isinstance(event, (self.events.StreamReset, self.events.ConnectionTerminated)), event
                sid = getattr(event, "stream_id", None)
                if sid not in self.responses:
                    continue
                response = self.responses[sid]
                if isinstance(event, self.events.InformationalResponseReceived):
                    response["informational"].append((int(dict(event.headers)[b":status"]), event.headers))
                elif isinstance(event, self.events.ResponseReceived):
                    response["headers"] = event.headers
                elif isinstance(event, self.events.DataReceived):
                    response["body"] += event.data
                    assert len(response["body"]) <= 65536
                    self.conn.acknowledge_received_data(event.flow_controlled_length, sid)
                elif isinstance(event, self.events.StreamEnded):
                    response["ended"] = True
            self.flush()

    def response(self, sid):
        self.wait(lambda: self.responses[sid]["ended"])
        response = self.responses[sid]
        return (int(dict(response["headers"])[b":status"]), response["headers"],
                response["body"], response["informational"])


client = H1() if PROTOCOL == "h1" else H2()
try:
    if MODE == "operations":
        for method, path, body, expected in [
            (b"POST", b"/mcp", POST_BODY, POST_EVENT),
            (b"GET", b"/buffered", b"", b"buffered-ok"),
            (b"GET", b"/file", b"", b"2345"),
            (b"GET", b"/inform", b"", b"after-103"),
        ]:
            sid = client.request(method, path, body)
            status, headers, response, informational = client.response() if PROTOCOL == "h1" else client.response(sid)
            assert status == 200 and response == expected, (path, status, headers, response)
            check_headers(headers)
            if path == b"/inform":
                assert len(informational) == 1 and informational[0][0] == 103, informational
                check_headers(informational[0][1])
                assert (b"link", b"</asset>; rel=preload") in informational[0][1]
            else:
                assert informational == []
    else:
        sid = client.request(b"GET", b"/notifications")
        if PROTOCOL == "h1":
            status, headers = client.head()
            assert status == 200, (status, headers)
            check_headers(headers)
            assert client.chunk() == FIRST
            release = H1()
            try:
                release.request(b"GET", b"/release")
                status, _, response, _ = release.response()
                assert status == 200 and response == b"release-ok"
            finally:
                release.close()
            assert client.chunk() == SECOND
            assert client.chunk() is None
        else:
            client.wait(lambda: len(client.responses[sid]["body"]) >= len(FIRST) or client.responses[sid]["ended"])
            held = client.responses[sid]
            assert int(dict(held["headers"])[b":status"]) == 200, held
            check_headers(held["headers"])
            assert held["body"] == FIRST and not held["ended"], held
            sibling = client.request(b"GET", b"/release")
            status, _, response, _ = client.response(sibling)
            assert status == 200 and response == b"release-ok"
            status, _, response, _ = client.response(sid)
            assert status == 200 and response == FIRST + SECOND
    sid = client.request(b"GET", b"/ok")
    status, _, response, _ = client.response() if PROTOCOL == "h1" else client.response(sid)
    assert status == 200 and response == b"followup-ok"
    print(f"PASS {PROTOCOL} Plug response {MODE}", flush=True)
finally:
    client.close()
