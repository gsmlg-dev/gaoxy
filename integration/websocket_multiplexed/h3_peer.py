"""Ordinary independent RFC 9220 peer using public aioquic and wsproto APIs."""
import asyncio
import ssl
import time

from aioquic.asyncio import connect
from aioquic.asyncio.protocol import QuicConnectionProtocol
from aioquic.h3.connection import H3Connection, Setting
from aioquic.h3.events import DataReceived, HeadersReceived
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.events import (
    ConnectionTerminated, ProtocolNegotiated, StopSendingReceived, StreamReset,
)
from wsproto.events import BytesMessage, CloseConnection, Ping, Pong, TextMessage

from h2_peer import REQUIRED_CASES, WebSocketChannel, validate_results


def client_configuration(certificate):
    assert certificate is not None, "H3 peer requires a verified local CA certificate"
    configuration = QuicConfiguration(
        is_client=True, alpn_protocols=["h3"], server_name="localhost",
        verify_mode=ssl.CERT_REQUIRED, idle_timeout=5,
    )
    configuration.load_verify_locations(cafile=str(certificate))
    return configuration


class H3PeerProtocol(QuicConnectionProtocol):
    def __init__(self, quic, stream_handler=None, *, port):
        super().__init__(quic, stream_handler=stream_handler)
        # The protocol factory receives this public QuicConnection argument.
        # Retain it directly instead of reaching into the base protocol's state.
        self.quic = quic
        self.http = H3Connection(quic)
        self.port = port
        self.channels, self.headers, self.bodies = {}, {}, {}
        self.ended, self.head_ended = set(), set()
        self.changed = asyncio.Event()
        self.negotiated, self.error = None, None
        self.started = time.monotonic()
        self.deadline = self.started + 5

    def quic_event_received(self, event):
        try:
            if isinstance(event, ProtocolNegotiated):
                self.negotiated = event.alpn_protocol
            elif isinstance(event, (ConnectionTerminated, StreamReset, StopSendingReceived)):
                self.error = AssertionError(f"unexpected QUIC event: {event!r}")
            for current in self.http.handle_event(event):
                self.handle_http_event(current)
        except Exception as error:
            self.error = error
        finally:
            self.changed.set()

    def handle_http_event(self, event):
        if isinstance(event, HeadersReceived):
            self.headers[event.stream_id] = event.headers
            if event.stream_ended:
                self.head_ended.add(event.stream_id)
        elif isinstance(event, DataReceived):
            if event.stream_id in self.channels:
                self.channels[event.stream_id].feed(event.data)
            else:
                self.bodies.setdefault(event.stream_id, bytearray()).extend(event.data)
        if isinstance(event, (HeadersReceived, DataReceived)) and event.stream_ended:
            self.ended.add(event.stream_id)

    async def wait(self, condition):
        while True:
            if self.error is not None:
                raise self.error
            if condition():
                return
            remaining = self.deadline - time.monotonic()
            assert remaining > 0, "five-second ordinary case deadline"
            self.changed.clear()
            await asyncio.wait_for(self.changed.wait(), timeout=remaining)

    def open_websocket(self, label, flush=True):
        stream = self.quic.get_next_available_stream_id()
        self.channels[stream] = WebSocketChannel(label)
        self.http.send_headers(stream, [
            (b":method", b"CONNECT"), (b":scheme", b"https"),
            (b":authority", f"localhost:{self.port}".encode()),
            (b":path", f"/websocket?label={label}".encode()),
            (b":protocol", b"websocket"), (b"sec-websocket-version", b"13"),
            (b"sec-websocket-protocol", b"m5.echo"),
        ], end_stream=False)
        if flush:
            self.transmit()
        return stream

    def send(self, stream, event):
        self.http.send_data(stream, self.channels[stream].ws.send(event), end_stream=False)
        self.transmit()

    async def message(self, stream, kind, expected):
        wanted = (kind, expected)
        messages = self.channels[stream].messages
        await self.wait(lambda: wanted in messages)
        messages.remove(wanted)

    async def request(self, path):
        stream = self.quic.get_next_available_stream_id()
        self.http.send_headers(stream, [
            (b":method", b"GET"), (b":scheme", b"https"),
            (b":authority", f"localhost:{self.port}".encode()),
            (b":path", path.encode()),
        ], end_stream=True)
        self.transmit()
        await self.wait(lambda: stream in self.ended)
        assert (b":status", b"200") in self.headers[stream]
        assert bytes(self.bodies[stream]) == path.encode()
        return stream

    async def close_websocket(self, stream):
        self.send(stream, CloseConnection(code=1000, reason="done"))
        await self.wait(
            lambda: any(isinstance(event, CloseConnection) for event in self.channels[stream].controls)
            and stream in self.ended
        )
        close, = [event for event in self.channels[stream].controls if isinstance(event, CloseConnection)]
        assert close.code == 1000, close
        self.http.send_data(stream, b"", end_stream=True)
        self.transmit()


async def ordinary(peer, results):
    def passed(name, **detail):
        results.append({
            "name": name, "status": "PASS",
            "elapsed_ms": round((time.monotonic() - peer.started) * 1000), **detail,
        })

    assert peer.negotiated == "h3", peer.negotiated
    passed("negotiation", negotiated="h3", certificate_verified=True)
    await peer.wait(lambda: peer.http.received_settings is not None)
    assert peer.http.received_settings.get(Setting.ENABLE_CONNECT_PROTOCOL) == 1
    passed("setting-8", value=1)
    first, second = peer.open_websocket("one"), peer.open_websocket("two")
    opened = time.monotonic()
    await peer.wait(lambda: first in peer.headers and second in peer.headers)
    forbidden = {b"connection", b"upgrade", b"content-length", b"transfer-encoding", b"sec-websocket-accept"}
    for stream in (first, second):
        assert (b":status", b"200") in peer.headers[stream]
        assert not forbidden.intersection(key for key, _ in peer.headers[stream])
        assert stream not in peer.head_ended and stream not in peer.ended
    passed("200-open-handshake", streams=[first, second])
    passed("two-websocket-streams", streams=[first, second], connection_count=1)
    for stream, label in ((first, "one"), (second, "two")):
        await peer.message(stream, "text", f"push:{label}")
    passed("server-push-while-idle", streams=[first, second], client_websocket_frames_sent=0)
    passed("http-sibling", stream=await peer.request("/sibling"), websocket_streams=[first, second])
    for stream, label in ((first, "one"), (second, "two")):
        peer.send(stream, TextMessage(data="hello"))
        await peer.message(stream, "text", f"{label}:hello")
    passed("text", streams=[first, second])
    peer.send(first, BytesMessage(data=b"\x00\xffbinary"))
    await peer.message(first, "binary", b"one:\x00\xffbinary")
    passed("binary", stream=first)
    frame = peer.channels[first].ws.send(TextMessage(data="split"))
    for piece in (frame[:1], frame[1:4], frame[4:]):
        peer.http.send_data(first, piece, end_stream=False)
    peer.transmit()
    await peer.message(first, "text", "one:split")
    passed("split-data", data_frames=3)
    channel = peer.channels[second]
    frame = channel.ws.send(TextMessage(data="coalesced-a")) + channel.ws.send(TextMessage(data="coalesced-b"))
    peer.http.send_data(second, frame, end_stream=False)
    peer.transmit()
    await peer.message(second, "text", "two:coalesced-a")
    await peer.message(second, "text", "two:coalesced-b")
    passed("coalesced-data", websocket_frames=2, data_frames=1)
    peer.send(first, Ping(payload=b"ping"))
    await peer.wait(lambda: any(isinstance(event, Pong) and event.payload == b"ping"
                                for event in peer.channels[first].controls))
    passed("ping-pong", stream=first)
    for stream in (first, second):
        assert (b"sec-websocket-protocol", b"m5.echo") in peer.headers[stream]
    passed("selected-subprotocol", selected="m5.echo")
    await asyncio.sleep(max(0, opened + 1.2 - time.monotonic()))
    peer.send(first, TextMessage(data="after-deadline"))
    await peer.message(first, "text", "one:after-deadline")
    peer.send(second, Ping(payload=b"after-deadline"))
    await peer.wait(lambda: any(isinstance(event, Pong) and event.payload == b"after-deadline"
                                for event in peer.channels[second].controls))
    passed("post-original-request-deadline", request_timeout_ms=1000, websocket_lifetime_ms=10000,
           elapsed_after_open_ms=round((time.monotonic() - opened) * 1000), total_deadline_ms=5000)
    await peer.close_websocket(first)
    await peer.close_websocket(second)
    passed("normal-close", code=1000, ended_streams=[first, second], fin=True)
    passed("http-after-close", stream=await peer.request("/after-close"))
    validate_results(results)


async def run_async(protocol, port, certificate=None, results=None):
    assert protocol == "h3", protocol
    results = [] if results is None else results
    configuration = client_configuration(certificate)
    async with asyncio.timeout(5):
        async with connect(
            "127.0.0.1", port, configuration=configuration,
            create_protocol=lambda quic, **options: H3PeerProtocol(quic, port=port, **options),
        ) as peer:
            await ordinary(peer, results)
    return results


def run(protocol, port, certificate=None, results=None):
    """Synchronous runner entry point matching the H2 fixture runner contract."""
    return asyncio.run(run_async(protocol, port, certificate, results))
