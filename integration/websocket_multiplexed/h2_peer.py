"""Ordinary independent RFC 8441 peer using public h2 and wsproto APIs."""
import socket
import ssl
import time

from h2.config import H2Configuration
from h2.connection import H2Connection
from h2.events import (ConnectionTerminated, DataReceived, ResponseReceived,
                       StreamEnded, StreamReset)
from wsproto.connection import Connection, ConnectionType
from wsproto.events import BytesMessage, CloseConnection, Ping, Pong, TextMessage

REQUIRED_CASES = (
    "negotiation", "setting-8", "200-open-handshake", "two-websocket-streams",
    "http-sibling", "text", "binary", "split-data", "coalesced-data",
    "ping-pong", "selected-subprotocol", "server-push-while-idle",
    "post-original-request-deadline", "normal-close", "http-after-close",
)


def validate_results(results):
    names = [row["name"] for row in results]
    assert names and len(names) == len(set(names)), "zero or duplicate executed cases"
    assert set(names) == set(REQUIRED_CASES), ("missing/unexpected cases", names)
    assert all(row["status"] == "PASS" for row in results), results


class WebSocketChannel:
    def __init__(self, label):
        self.label = label
        self.ws = Connection(ConnectionType.CLIENT)
        self.messages = []
        self.controls = []
        self.parts = []

    def feed(self, data):
        # Empty DATA can carry END_STREAM after the WS Close handshake. It is
        # transport state, not input for wsproto's already closed connection.
        if not data:
            return
        self.ws.receive_data(data)
        for event in self.ws.events():
            if isinstance(event, (TextMessage, BytesMessage)):
                self.parts.append(event.data)
                if event.message_finished:
                    kind, empty = ("text", "") if isinstance(event, TextMessage) else ("binary", b"")
                    self.messages.append((kind, empty.join(self.parts)))
                    self.parts.clear()
            else:
                self.controls.append(event)


class H2Peer:
    def __init__(self, protocol, port, certificate=None):
        self.protocol, self.port, self.certificate = protocol, port, certificate
        self.h2 = H2Connection(config=H2Configuration(client_side=True))
        self.h2.initiate_connection()
        self.socket = None
        self.channels, self.headers, self.bodies = {}, {}, {}
        self.ended, self.head_ended = set(), set()
        self.started = time.monotonic()
        self.deadline = self.started + 5

    def connect(self):
        raw = socket.create_connection(("127.0.0.1", self.port), timeout=3)
        if self.protocol == "h2":
            context = ssl.create_default_context(cafile=str(self.certificate))
            context.set_alpn_protocols(["h2"])
            try:
                self.socket = context.wrap_socket(raw, server_hostname="localhost")
            except BaseException:
                raw.close()
                raise
            assert self.socket.selected_alpn_protocol() == "h2"
        else:
            self.socket = raw
        self.flush()

    def flush(self):
        data = self.h2.data_to_send()
        if data:
            self.socket.sendall(data)

    def feed(self, data):
        for event in self.h2.receive_data(data):
            assert not isinstance(event, (StreamReset, ConnectionTerminated)), repr(event)
            if isinstance(event, ResponseReceived):
                self.headers[event.stream_id] = event.headers
                if event.stream_ended is not None:
                    self.head_ended.add(event.stream_id)
            elif isinstance(event, DataReceived):
                if event.stream_id in self.channels:
                    self.channels[event.stream_id].feed(event.data)
                else:
                    self.bodies.setdefault(event.stream_id, bytearray()).extend(event.data)
                self.h2.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
            elif isinstance(event, StreamEnded):
                self.ended.add(event.stream_id)

    def wait(self, condition):
        while not condition():
            remaining = self.deadline - time.monotonic()
            assert remaining > 0, "five-second ordinary case deadline"
            self.socket.settimeout(min(3, remaining))
            data = self.socket.recv(65536)
            assert data, "connection closed before expected ordinary result"
            self.feed(data)
            self.flush()

    def open_websocket(self, label, flush=True):
        stream = self.h2.get_next_available_stream_id()
        self.channels[stream] = WebSocketChannel(label)
        scheme = b"https" if self.protocol == "h2" else b"http"
        self.h2.send_headers(stream, [
            (b":method", b"CONNECT"), (b":scheme", scheme),
            (b":authority", f"localhost:{self.port}".encode()),
            (b":path", f"/websocket?label={label}".encode()),
            (b":protocol", b"websocket"), (b"sec-websocket-version", b"13"),
            (b"sec-websocket-protocol", b"m5.echo"),
        ], end_stream=False)
        if flush:
            self.flush()
        return stream

    def send(self, stream, event):
        self.h2.send_data(stream, self.channels[stream].ws.send(event), end_stream=False)
        self.flush()

    def message(self, stream, kind, expected):
        wanted = (kind, expected)
        messages = self.channels[stream].messages
        self.wait(lambda: wanted in messages)
        messages.remove(wanted)

    def http(self, path):
        stream = self.h2.get_next_available_stream_id()
        scheme = b"https" if self.protocol == "h2" else b"http"
        self.h2.send_headers(stream, [
            (b":method", b"GET"), (b":scheme", scheme),
            (b":authority", f"localhost:{self.port}".encode()),
            (b":path", path.encode()),
        ], end_stream=True)
        self.flush()
        self.wait(lambda: stream in self.ended)
        assert (b":status", b"200") in self.headers[stream]
        assert bytes(self.bodies[stream]) == path.encode()
        return stream

    def close_websocket(self, stream):
        self.send(stream, CloseConnection(code=1000, reason="done"))
        self.wait(lambda: any(isinstance(e, CloseConnection) for e in self.channels[stream].controls)
                  and stream in self.ended)
        close, = [e for e in self.channels[stream].controls if isinstance(e, CloseConnection)]
        assert close.code == 1000, close
        self.h2.end_stream(stream)
        self.flush()


def run(protocol, port, certificate=None, results=None):
    peer = H2Peer(protocol, port, certificate)
    results = [] if results is None else results

    def passed(name, **detail):
        results.append({"name": name, "status": "PASS", "elapsed_ms": round((time.monotonic()-peer.started)*1000), **detail})

    try:
        peer.connect()
        passed("negotiation", negotiated="h2" if protocol == "h2" else "h2c-prior-knowledge",
               certificate_verified=protocol == "h2")
        peer.wait(lambda: peer.h2.remote_settings.enable_connect_protocol == 1)
        passed("setting-8", value=1)
        first, second = peer.open_websocket("one"), peer.open_websocket("two")
        opened = time.monotonic()
        peer.wait(lambda: first in peer.headers and second in peer.headers)
        forbidden = {b"connection", b"upgrade", b"content-length", b"transfer-encoding", b"sec-websocket-accept"}
        for stream in (first, second):
            assert (b":status", b"200") in peer.headers[stream]
            assert not forbidden.intersection(key for key, _ in peer.headers[stream])
            assert stream not in peer.head_ended and stream not in peer.ended
        passed("200-open-handshake", streams=[first, second])
        passed("two-websocket-streams", streams=[first, second], connection_count=1)
        for stream, label in ((first, "one"), (second, "two")):
            peer.message(stream, "text", f"push:{label}")
        passed("server-push-while-idle", streams=[first, second], client_websocket_frames_sent=0)
        sibling = peer.http("/sibling")
        passed("http-sibling", stream=sibling, websocket_streams=[first, second])
        for stream, label in ((first, "one"), (second, "two")):
            peer.send(stream, TextMessage(data="hello"))
            peer.message(stream, "text", f"{label}:hello")
        passed("text", streams=[first, second])
        peer.send(first, BytesMessage(data=b"\x00\xffbinary"))
        peer.message(first, "binary", b"one:\x00\xffbinary")
        passed("binary", stream=first)
        frame = peer.channels[first].ws.send(TextMessage(data="split"))
        for piece in (frame[:1], frame[1:4], frame[4:]):
            peer.h2.send_data(first, piece, end_stream=False)
        peer.flush()
        peer.message(first, "text", "one:split")
        passed("split-data", data_frames=3)
        channel = peer.channels[second]
        frame = channel.ws.send(TextMessage(data="coalesced-a")) + channel.ws.send(TextMessage(data="coalesced-b"))
        peer.h2.send_data(second, frame, end_stream=False)
        peer.flush()
        peer.message(second, "text", "two:coalesced-a")
        peer.message(second, "text", "two:coalesced-b")
        passed("coalesced-data", websocket_frames=2, data_frames=1)
        peer.send(first, Ping(payload=b"ping"))
        peer.wait(lambda: any(isinstance(e, Pong) and e.payload == b"ping" for e in peer.channels[first].controls))
        passed("ping-pong", stream=first)
        for stream in (first, second):
            assert (b"sec-websocket-protocol", b"m5.echo") in peer.headers[stream]
        passed("selected-subprotocol", selected="m5.echo")
        time.sleep(max(0, opened + 1.2 - time.monotonic()))
        peer.send(first, TextMessage(data="after-deadline"))
        peer.message(first, "text", "one:after-deadline")
        peer.send(second, Ping(payload=b"after-deadline"))
        peer.wait(lambda: any(isinstance(e, Pong) and e.payload == b"after-deadline" for e in peer.channels[second].controls))
        passed("post-original-request-deadline", request_timeout_ms=1000, websocket_lifetime_ms=10000,
               elapsed_after_open_ms=round((time.monotonic()-opened)*1000), total_deadline_ms=5000)
        peer.close_websocket(first)
        peer.close_websocket(second)
        passed("normal-close", code=1000, ended_streams=[first, second])
        passed("http-after-close", stream=peer.http("/after-close"))
        validate_results(results)
        return results
    finally:
        if peer.socket is not None:
            peer.socket.close()
