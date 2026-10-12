#!/usr/bin/env python3
"""Independent aioquic/pylsqpack HTTP/3 peer with exact error scope checks."""
import argparse
import asyncio
from contextlib import asynccontextmanager
import json
import sys
import time

import pylsqpack
from aioquic.asyncio import connect
from aioquic.asyncio.protocol import QuicConnectionProtocol
from aioquic.buffer import Buffer, BufferReadError, encode_uint_var
from aioquic.h3.connection import H3Connection, encode_frame, encode_settings
from aioquic.h3.events import DataReceived, HeadersReceived
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.logger import QuicLogger
from aioquic.quic.events import (
    ConnectionTerminated, ProtocolNegotiated, StopSendingReceived,
    StreamDataReceived, StreamReset,
)

FIELDS = [(b":method", b"GET"), (b":scheme", b"https"),
          (b":authority", b"localhost"), (b":path", b"/ok")]


def fields(method=b"GET", path=b"/ok", extra=()):
    return [(b":method", method), (b":scheme", b"https"),
            (b":authority", b"localhost"), (b":path", path)] + list(extra)


def head(sid, values):
    encoder = pylsqpack.Encoder()
    instructions, block = encoder.encode(sid, values)
    assert instructions == b"", "raw profile must never emit dynamic instructions"
    return encode_frame(1, block)


def emit(name, **details):
    print("GAOXY_HTTP3_PEER " + json.dumps(dict(name=name, result="PASS", **details)), flush=True)


class Peer(QuicConnectionProtocol):
    def __init__(self, *args, standard=True, **kwargs):
        super().__init__(*args, **kwargs)
        self.http = H3Connection(self._quic) if standard else None
        self.decoder = pylsqpack.Decoder(0, 0)
        self.buffers, self.headers, self.data = {}, {}, {}
        self.ended, self.resets, self.stops = set(), {}, {}
        self.negotiated, self.terminated = None, None
        self.changed = asyncio.Event()
        self.control, self.encoder_stream, self.decoder_stream = None, None, None

    def quic_event_received(self, event):
        if isinstance(event, ProtocolNegotiated):
            self.negotiated = event.alpn_protocol
        elif isinstance(event, StreamReset):
            self.resets[event.stream_id] = event.error_code
        elif isinstance(event, StopSendingReceived):
            self.stops[event.stream_id] = event.error_code
        elif isinstance(event, ConnectionTerminated):
            self.terminated = event.error_code
        if self.http:
            for current in self.http.handle_event(event):
                if isinstance(current, HeadersReceived):
                    self.headers.setdefault(current.stream_id, []).append(current.headers)
                elif isinstance(current, DataReceived):
                    self.data[current.stream_id] = self.data.get(current.stream_id, b"") + current.data
                if isinstance(current, (HeadersReceived, DataReceived)) and current.stream_ended:
                    self.ended.add(current.stream_id)
        elif isinstance(event, StreamDataReceived) and event.stream_id % 4 == 0:
            sid = event.stream_id
            self.buffers[sid] = self.buffers.get(sid, b"") + event.data
            self._frames(sid)
            if event.end_stream:
                assert self.buffers[sid] == b"", "response FIN truncated a frame"
                self.ended.add(sid)
        self.changed.set()

    def _frames(self, sid):
        while self.buffers[sid]:
            buffer = Buffer(data=self.buffers[sid])
            try:
                kind, length = buffer.pull_uint_var(), buffer.pull_uint_var()
            except BufferReadError:
                return
            prefix = buffer.tell()
            if len(self.buffers[sid]) < prefix + length:
                return
            payload = self.buffers[sid][prefix:prefix + length]
            self.buffers[sid] = self.buffers[sid][prefix + length:]
            if kind == 1:
                instructions, values = self.decoder.feed_header(sid, payload)
                assert instructions == b"", "server encoded an unexpected dynamic reference"
                self.headers.setdefault(sid, []).append(values)
            elif kind == 0:
                self.data[sid] = self.data.get(sid, b"") + payload

    async def until(self, predicate, allow_close=False):
        async with asyncio.timeout(10):
            while not predicate():
                if not allow_close:
                    assert self.terminated is None, f"unexpected connection close {self.terminated:#x}"
                self.changed.clear()
                await self.changed.wait()

    def raw(self, sid, payload, fin=False):
        self._quic.send_stream_data(sid, payload, end_stream=fin)
        self.transmit()

    def uni(self, prefix, fin=False):
        sid = self._quic.get_next_available_stream_id(is_unidirectional=True)
        self.raw(sid, prefix, fin)
        return sid

    def setup(self):
        self.control = self.uni(b"\x00" + encode_frame(4, encode_settings({1: 0, 7: 0})))
        self.encoder_stream = self.uni(b"\x02\x20")
        self.decoder_stream = self.uni(b"\x03")

    def request(self, method=b"GET", path=b"/ok", extra=(), fin=True):
        sid = self._quic.get_next_available_stream_id()
        values = fields(method, path, extra)
        if self.http:
            self.http.send_headers(sid, values, end_stream=fin)
            self.transmit()
        else:
            self.raw(sid, head(sid, values), fin)
        return sid

    async def response(self, sid, body=b"ok", status=b"200"):
        def observed():
            return {"stream": sid, "response_bytes": len(self.data.get(sid, b"")),
                    "expected_bytes": len(body), "reset": self.resets.get(sid),
                    "stop": self.stops.get(sid), "connection_close": self.terminated,
                    "response_headers": repr(self.headers.get(sid))}
        try:
            await self.until(lambda: sid in self.ended or sid in self.resets)
        except TimeoutError as error:
            raise AssertionError(f"response deadline: {observed()}") from error
        assert sid not in self.resets, observed()
        assert self.headers[sid][0].count((b":status", status)) == 1, self.headers[sid]
        assert self.data.get(sid, b"") == body, (sid, len(self.data.get(sid, b"")), len(body))


@asynccontextmanager
async def opened(args, port=None, standard=True):
    config = QuicConfiguration(is_client=True, alpn_protocols=["h3"], max_data=4096,
                               max_stream_data=2048, idle_timeout=15)
    if args.mode == "diagnostic":
        config.quic_logger = QuicLogger()
    config.server_name = "localhost"
    config.load_verify_locations(args.ca)
    async with connect("127.0.0.1", port or args.port, configuration=config,
                       create_protocol=lambda *a, **kw: Peer(*a, standard=standard, **kw)) as peer:
        assert peer.negotiated == "h3", peer.negotiated
        peer.qlog = config.quic_logger
        yield peer


async def ordinary(args):
    async with opened(args) as peer:
        await peer.until(lambda: peer.http.received_settings is not None)
        assert peer.http.received_settings[1] == peer.http.received_settings[7] == 0
        emit("control_static_qpack", settings=peer.http.received_settings, alpn=peer.negotiated)
        await peer.response(peer.request())
        emit("get")
        first, second = peer.request(), peer.request()
        await asyncio.gather(peer.response(first), peer.response(second))
        emit("concurrent_requests", requests=2)
        payload = b"fragmented-h3-body-" * 16_384
        sid = peer.request(b"POST", b"/echo", [(b"content-length", str(len(payload)).encode())], fin=False)
        peer.http.send_data(sid, payload[:17], end_stream=False)
        peer.transmit()
        await peer.until(lambda: len(peer.data.get(sid, b"")) >= 17)
        for offset in range(17, len(payload), 1021):
            peer.http.send_data(sid, payload[offset:offset + 1021],
                                end_stream=offset + 1021 >= len(payload))
        peer.transmit()
        await peer.response(sid, payload)
        emit("fragmented_streaming_post_tiny_windows", bytes=len(payload),
             initial_stream_window=2048, initial_connection_window=4096,
             response_progress_before_upload_fin=True)
        sid = peer.request(b"POST", b"/echo", fin=False)
        peer.http.send_data(sid, b"trailers-body", end_stream=False)
        peer.http.send_headers(sid, [(b"x-checksum", b"fixture")], end_stream=True)
        peer.transmit()
        await peer.response(sid, b"trailers-body")
        assert peer.headers[sid][-1] == [(b"x-checksum", b"fixture")], peer.headers[sid]
        emit("request_trailers")
    async with opened(args, standard=False) as peer:
        peer.setup()
        # aioquic1.2.0's H3Connection does not track HEAD's bodyless semantics
        # when checking Content-Length. Independently decode the legal wire.
        sid = peer.request(b"HEAD")
        await peer.response(sid, body=b"")
        lengths = [value for name, value in peer.headers[sid][0] if name == b"content-length"]
        assert lengths in ([], [b"2"]), lengths
        emit("head_bodyless", data_bytes=0, content_length=[value.decode("ascii") for value in lengths])
    async with opened(args, standard=False) as peer:
        peer.setup()
        sid = peer._quic.get_next_available_stream_id()
        values = [(b":method", b"CONNECT"), (b":authority", b"localhost:443"),
                  (b"host", b"localhost:443")]
        peer.raw(sid, head(sid, values), True)
        await peer.response(sid, body=b"", status=b"501")
        await peer.response(peer.request())
        emit("ordinary_connect_501", status=501, sibling_completed=True)
    async with opened(args, standard=False) as peer:
        await peer.response(peer.request())
        peer.setup()
        await peer.response(peer.request())
        emit("request_before_peer_settings", response_before_peer_control_created=True,
             sibling_completed=True)
    async with opened(args, standard=False) as peer:
        peer.setup()
        # RFC9204 static indexes17(GET),23(https), literal-name-reference0(authority).
        # RFC7541 C.4 independent Huffman vector for www.example.com.
        block = bytes.fromhex("0000d1d7508cf1e3c2e5f23a6ba0ab90f4ff")
        _, path = pylsqpack.Encoder().encode(0, [(b":path", b"/ok")])
        peer.raw(0, encode_frame(1, block + path[2:]), True)
        await peer.response(0)
        emit("known_static_huffman_vector")
    async with opened(args, standard=False) as peer:
        peer.setup()
        peer.uni(encode_uint_var(0x21) + b"ignored", True)
        peer.raw(peer.decoder_stream, b"\x40")  # Legal zero-capacity Stream Cancellation.
        sid = peer._quic.get_next_available_stream_id()
        payload = b"x" * 65_537
        peer.raw(sid, encode_frame(0x21, payload) + head(sid, FIELDS), True)
        await peer.response(sid)
        emit("unknown_uni_large_extension_legal_cancellation", discarded_bytes=len(payload))


async def malformed(args):
    async with opened(args) as survivor:
        await survivor.response(survivor.request())

        async def case(name, action, code, scope="connection", setup=True, deadline_seconds=None, require_stop=False):
            async with opened(args, standard=False) as peer:
                if setup:
                    peer.setup()
                    await peer.response(peer.request())
                    await asyncio.wait_for(peer.ping(), 5)
                sid = action(peer)
                started = time.monotonic()
                if scope == "connection":
                    async with asyncio.timeout(deadline_seconds):
                        await peer.until(lambda: peer.terminated is not None, allow_close=True)
                    assert peer.terminated == code, (name, peer.terminated, code)
                    error_elapsed = time.monotonic() - started
                    await survivor.response(survivor.request())
                else:
                    try:
                        await peer.until(lambda: sid in peer.resets and (not require_stop or sid in peer.stops))
                    except TimeoutError as error:
                        observation = dict(name=name, stream=sid, resets=peer.resets,
                            stops=peer.stops, connection_close=peer.terminated,
                            response_data_bytes=len(peer.data.get(sid, b"")))
                        print("GAOXY_HTTP3_DIAGNOSTIC " + json.dumps(observation), flush=True)
                        raise AssertionError(f"stream error deadline: {observation}") from error
                    assert peer.resets[sid] == code, (name, peer.resets, peer.stops)
                    if require_stop:
                        assert peer.stops[sid] == code, (name, peer.resets, peer.stops)
                    else:
                        # FIN plus received RESET can retire aioquic's stream before
                        # a later wire STOP becomes an application callback. The
                        # unchanged-server diagnostic independently decoded both.
                        assert peer.stops.get(sid) in (None, code), (name, peer.stops)
                    error_elapsed = time.monotonic() - started
                    at_reset = peer.data.get(sid, b"")
                    await peer.response(peer.request())
                    assert peer.terminated is None, "stream error closed its connection"
                    assert peer.data.get(sid, b"") == at_reset, "late response DATA after stream error"
                emit(name, scope=scope, code=code, sibling_completed=True,
                     error_elapsed_ms=round(error_elapsed * 1000),
                     error_deadline_ms=None if deadline_seconds is None else deadline_seconds * 1000,
                     reset_code=peer.resets.get(sid) if scope == "stream" else None,
                     stop_code=peer.stops.get(sid) if scope == "stream" else None,
                     stop_callback_required=require_stop if scope == "stream" else None,
                     late_data_bytes=0 if scope == "stream" else None)

        def request_bytes(payload, fin=True):
            def send(peer):
                sid = peer._quic.get_next_available_stream_id()
                peer.raw(sid, payload, fin)
                return sid
            return send

        await case("data_before_headers", request_bytes(encode_frame(0, b"x")), 0x105)
        await case("control_frame_on_request", request_bytes(encode_frame(4, b"")), 0x105)
        await case("duplicate_settings", lambda p: p.raw(p.control, encode_frame(4, b"")), 0x105)
        await case("settings_first", lambda p: p.uni(b"\x00" + encode_frame(0x21, b"")), 0x10A, setup=False)
        await case("invalid_settings", lambda p: p.uni(b"\x00" + encode_frame(4, b"\x02\x00")), 0x109, setup=False)
        for kind in (0, 2, 3):
            await case(f"duplicate_critical_{kind}", lambda p, k=kind: p.uni(bytes([k])), 0x103)
            await case(f"critical_fin_{kind}", lambda p, k=kind: p.raw(
                [p.control, p.encoder_stream, p.decoder_stream][[0, 2, 3].index(k)], b"", True), 0x104)

            def reset(peer, k=kind):
                sid = [peer.control, peer.encoder_stream, peer.decoder_stream][[0, 2, 3].index(k)]
                peer._quic.reset_stream(sid, 0x10C)
                peer.transmit()
            await case(f"critical_reset_{kind}", reset, 0x104)
        await case("client_push_stream", lambda p: p.uni(b"\x01\x00"), 0x103)
        await case("qpack_encoder_capacity", lambda p: p.raw(p.encoder_stream, b"\x21"), 0x201)
        await case("qpack_decoder_invalid_ack", lambda p: p.raw(p.decoder_stream, b"\x80"), 0x202)
        await case("incomplete_extension_discard_deadline", lambda p: p.raw(p.control,
                   encode_uint_var(0x21) + encode_uint_var(1_000_000_000)), 0x107,
                   deadline_seconds=6)
        await case("qpack_dynamic_reference", request_bytes(encode_frame(1, b"\x01\x00")), 0x200)
        await case("qpack_invalid_huffman", request_bytes(encode_frame(1, b"\x00\x00\x50\x81\xff")), 0x200)
        await case("duplicate_pseudo", request_bytes(head(0, FIELDS + [(b":method", b"GET")])), 0x10E, "stream")
        missing = [(k, v) for k, v in FIELDS if k != b":authority"]
        await case("missing_authority", request_bytes(head(0, missing)), 0x10E, "stream")
        await case("body_length_underflow", request_bytes(head(0, fields(b"POST", b"/echo", [(b"content-length", b"3")])) +
                   encode_frame(0, b"ab")), 0x10E, "stream")
        await case("body_length_overflow", request_bytes(head(0, fields(b"POST", b"/echo", [(b"content-length", b"1")])) +
                   encode_frame(0, b"ab")), 0x10E, "stream")
        await case("compressed_header_limit", request_bytes(b"\x01" + encode_uint_var(32_769)), 0x107, "stream")
        await case("decoded_field_limit", request_bytes(head(0, FIELDS + [(b"x", b"y")] * 101)), 0x107, "stream")
        # Errors visible before request FIN retain both directional callbacks.
        # The FIN cases above retain exact RESET, connection scope and siblings;
        # underflow requires FIN and has no corresponding open-direction case.
        for name, payload, code in [
            ("duplicate_pseudo_open_direction", head(0, FIELDS + [(b":method", b"GET")]), 0x10E),
            ("missing_authority_open_direction", head(0, missing), 0x10E),
            ("body_length_overflow_open_direction", head(0, fields(b"POST", b"/echo",
                [(b"content-length", b"1")])) + encode_frame(0, b"ab"), 0x10E),
            ("compressed_header_limit_open_direction", b"\x01" + encode_uint_var(32_769), 0x107),
            ("decoded_field_limit_open_direction", head(0, FIELDS + [(b"x", b"y")] * 101), 0x107),
        ]:
            await case(name, request_bytes(payload, fin=False), code, "stream", require_stop=True)
        trailers = head(0, fields(b"POST", b"/echo")) + head(0, [(b"x", b"y")])
        await case("data_after_trailers", request_bytes(trailers + encode_frame(0, b"x")), 0x105)


async def diagnostic(args):
    """Observe the old exact RESET+STOP callback contract without server changes."""
    for fin in (True, False):
        async with opened(args, standard=False) as peer:
            peer.setup()
            await peer.response(peer.request())
            await asyncio.wait_for(peer.ping(), 5)
            sid = peer._quic.get_next_available_stream_id()
            before = peer.data.get(sid, b"")
            peer.raw(sid, head(sid, FIELDS + [(b":method", b"GET")]), fin)
            pair_observed = True
            started = time.monotonic()
            try:
                await peer.until(lambda: sid in peer.resets and sid in peer.stops)
            except TimeoutError:
                pair_observed = False
            snapshot = dict(stream=sid, fin=fin, pair_callback_observed=pair_observed,
                resets=peer.resets, stops=peer.stops, connection_close=peer.terminated,
                response_data_bytes=len(peer.data.get(sid, b"")),
                elapsed_ms=round((time.monotonic() - started) * 1000))
            assert peer.resets.get(sid) == 0x10E, snapshot
            if not fin:
                assert peer.stops.get(sid) == 0x10E and pair_observed, snapshot
            await peer.response(peer.request())
            assert peer.terminated is None, snapshot
            assert peer.data.get(sid, b"") == before == b"", snapshot
            qlog = peer.qlog.to_dict()
            frames = [frame for trace in qlog["traces"] for event in trace["events"]
                      if event["name"] == "transport:packet_received"
                      for frame in event["data"].get("frames", [])
                      if frame.get("stream_id") == sid and
                      frame.get("frame_type") in ("reset_stream", "stop_sending")]
            snapshot["received_wire_frames"] = frames
            print("GAOXY_HTTP3_DIAGNOSTIC " + json.dumps(snapshot), flush=True)
            print("GAOXY_HTTP3_QLOG " + json.dumps(qlog), flush=True)
            assert any(frame["frame_type"] == "reset_stream" and
                       frame["error_code"] == 0x10E for frame in frames), snapshot
            assert any(frame["frame_type"] == "stop_sending" and
                       frame["error_code"] == 0x10E for frame in frames), snapshot
            emit("duplicate_pseudo_fin_observation" if fin else "duplicate_pseudo_open_observation",
                 **snapshot, sibling_completed=True, late_data_bytes=0)


async def cancellation(args):
    async with opened(args) as peer:
        sid = peer.request(b"POST", b"/echo", fin=False)
        await peer.response(peer.request())  # Active sibling barrier before cancellation.
        before = peer.data.get(sid, b"")
        peer._quic.reset_stream(sid, 0x10C)
        peer._quic.stop_stream(sid, 0x10C)
        peer.transmit()
        await peer.until(lambda: sid in peer.resets)
        assert peer.resets[sid] == 0x10C, peer.resets
        await peer.response(peer.request())
        assert peer.data.get(sid, b"") == before == b"", "late response DATA after request cancellation"
        emit("request_reset_stop_isolation", code=0x10C, sibling_completed=True, late_data_bytes=0)


async def shared(args):
    """Production Plug facade, independently decoded by aioquic/pylsqpack."""
    async with opened(args) as peer:
        try:
            await peer.response(peer.request())
        except Exception as error:
            print("GAOXY_HTTP3_PEER " + json.dumps(dict(name="shared_get", result="FAIL",
                  error=f"{type(error).__name__}: {error}")), flush=True)
            raise
        emit("shared_get", production_plug=True)
        await peer.until(lambda: peer.http.received_settings is not None)
        assert peer.http.received_settings[1] == peer.http.received_settings[7] == 0
        emit("shared_static_qpack", settings=peer.http.received_settings)
        await peer.response(peer.request(path=b"/metadata"), b"https:HTTP/3:localhost:443")
        emit("shared_plug_metadata", scheme="https", protocol="HTTP/3", authority="localhost:443")
        first, second = peer.request(), peer.request()
        await asyncio.gather(peer.response(first), peer.response(second))
        emit("shared_simultaneous_requests", requests=2)

        crashed = peer.request(path=b"/crash", fin=False)
        await peer.until(lambda: crashed in peer.resets and crashed in peer.stops)
        assert peer.resets[crashed] == peer.stops[crashed] == 0x102
        assert peer.data.get(crashed, b"") == b"", "crashed worker emitted response DATA"
        assert peer.terminated is None, peer.terminated
        async with opened(args, port=args.sibling_port) as sibling:
            await asyncio.gather(peer.response(peer.request()), sibling.response(sibling.request()))
        assert peer.data.get(crashed, b"") == b"", "late DATA after worker crash cancellation"
        assert peer.terminated is None, peer.terminated
        emit("shared_worker_crash_request_isolation", reset=0x102, stop=0x102,
             response_data_bytes=0, same_connection_sibling_completed=True,
             sibling_listener_completed=True)

        payload = b"shared-fragmented-body-" * 13_000
        sid = peer.request(b"POST", b"/echo", [(b"content-length", str(len(payload)).encode())], fin=False)
        peer.http.send_data(sid, payload[:17], end_stream=False)
        peer.transmit()
        await peer.until(lambda: len(peer.data.get(sid, b"")) >= 17)
        for offset in range(17, len(payload), 1021):
            peer.http.send_data(sid, payload[offset:offset + 1021],
                                end_stream=offset + 1021 >= len(payload))
        peer.transmit()
        await peer.response(sid, payload)
        emit("shared_streaming_post_response", bytes=len(payload), response_progress_before_upload_fin=True,
             initial_stream_window=2048, initial_connection_window=4096)

        sid = peer.request(b"POST", b"/echo", fin=False)
        trailers = [(b"x-first", b"one"), (b"x-second", b"two"), (b"x-first", b"three")]
        peer.http.send_data(sid, b"ordered-trailers", end_stream=False)
        peer.http.send_headers(sid, trailers, end_stream=True)
        peer.transmit()
        await peer.response(sid, b"ordered-trailers")
        assert peer.headers[sid][-1] == trailers, peer.headers[sid]
        emit("shared_ordered_request_response_trailers", fields=[[k.decode(), v.decode()] for k, v in trailers])

        sid = peer.request(b"POST", b"/zero-trailers", [(b"content-length", b"0")], fin=False)
        peer.http.send_headers(sid, trailers, end_stream=True)
        peer.transmit()
        await peer.response(sid, b"")
        assert peer.headers[sid][-1] == trailers, peer.headers[sid]
        complete = [v for k, v in peer.headers[sid][0] if k == b"x-initial-body-complete"]
        assert complete in ([b"true"], [b"false"]), complete
        emit("shared_zero_data_ordered_trailers", data_bytes=0,
             initial_body_complete=complete[0].decode(),
             fields=[[k.decode(), v.decode()] for k, v in trailers])
        await peer.response(peer.request(path=b"/fixed"), b"fixed-stream")
        emit("shared_fixed_streaming_response", content_length=12)
        file_bytes = b"0123456789abcdef" * 65_536
        sid = peer.request(path=b"/file")
        await peer.response(sid, file_bytes[11:11 + 8193], b"206")
        assert (b"content-length", b"8193") in peer.headers[sid][0], peer.headers[sid]
        emit("shared_file_range", offset=11, bytes=8193, status=206)

        sid = peer.request(b"POST", b"/early", [(b"content-length", b"1000000")], fin=False)
        peer.http.send_data(sid, b"unread-prefix", end_stream=False)
        peer.transmit()
        await peer.response(sid, b"early")
        await peer.response(peer.request())
        assert peer.terminated is None
        emit("shared_early_response_unread_body", unread_prefix_bytes=13, request_fin=False,
             sibling_completed=True)

    # aioquic1.2 treats a final HEADERS after100/103 as trailers and its generic
    # Content-Length checker omits HEAD/bodyless rules. Decode these legal wire
    # responses independently; retain exact statuses, body, trailers and FIN.
    async with opened(args, standard=False) as peer:
        peer.setup()
        sid = peer.request(path=b"/inform")
        await peer.until(lambda: sid in peer.ended or sid in peer.resets)
        assert sid not in peer.resets, peer.resets
        assert [dict(h)[b":status"] for h in peer.headers[sid]] == [b"103", b"200"], peer.headers[sid]
        assert (b"link", b"</fixture>; rel=preload") in peer.headers[sid][0], peer.headers[sid]
        assert peer.data.get(sid) == b"informed", peer.data
        emit("shared_informational_before_final", statuses=[103, 200])

        sid = peer.request(b"POST", b"/continue", [(b"expect", b"100-continue"),
                           (b"content-length", b"15")], fin=False)
        await peer.until(lambda: sid in peer.headers or sid in peer.resets)
        assert sid not in peer.resets and dict(peer.headers[sid][0])[b":status"] == b"100", peer.headers
        peer.raw(sid, encode_frame(0, b"continued-input"), fin=True)
        await peer.until(lambda: sid in peer.ended or sid in peer.resets)
        assert sid not in peer.resets, peer.resets
        assert [dict(h)[b":status"] for h in peer.headers[sid]] == [b"100", b"200"], peer.headers[sid]
        assert peer.data.get(sid) == b"continued-input", peer.data
        emit("shared_expect_continue_before_body", statuses=[100, 200], continue_count=1)

        sid = peer.request(b"HEAD")
        await peer.response(sid, b"")
        assert (b"content-length", b"2") in peer.headers[sid][0], peer.headers[sid]
        emit("shared_head_bodyless", data_bytes=0, content_length=2)
        for status in (204, 205, 304):
            sid = peer.request(path=f"/empty-{status}".encode())
            await peer.response(sid, b"", str(status).encode())
            lengths = [v for k, v in peer.headers[sid][0] if k == b"content-length"]
            expected = {204: [], 205: [b"0"], 304: [b"17"]}[status]
            assert lengths == expected, (status, lengths)
            emit(f"shared_bodyless_{status}", data_bytes=0,
                 content_length=[v.decode() for v in lengths])

    async with opened(args) as peer, opened(args, port=args.sibling_port) as sibling:
        large, small = peer.request(path=b"/large"), peer.request()
        await asyncio.gather(peer.response(large, file_bytes), peer.response(small),
                             sibling.response(sibling.request()))
        emit("shared_tiny_window_file_progress", bytes=len(file_bytes),
             initial_stream_window=2048, initial_connection_window=4096,
             same_connection_sibling_completed=True, sibling_listener_completed=True)


async def busy(args):
    async with opened(args, port=args.busy_port) as stalled, opened(args, port=args.sibling_port) as sibling:
        started = time.monotonic()
        async with asyncio.timeout_at(started + 2.5):
            sid = stalled.request(path=b"/busy")
            print('GAOXY_HTTP3_PEER {"event":"busy_ready"}', flush=True)
            command = await asyncio.to_thread(sys.stdin.readline)
            assert command == "cleaned\n", command
            assert stalled.data.get(sid, b"") == b"", "busy Plug emitted response DATA"
            # Abrupt owner death proves local cleanup; explicit stop separately
            # verifies its supported wire close. Exercise siblings by original D.
            async with opened(args, port=args.busy_port) as another:
                await asyncio.gather(another.response(another.request()), sibling.response(sibling.request()))
            assert stalled.data.get(sid, b"") == b"", "late DATA after busy owner cleanup"
        elapsed_ms = round((time.monotonic() - started) * 1000)
        assert elapsed_ms <= 2500, ("busy original D + cleanup headroom exceeded", elapsed_ms)
        emit("shared_busy_owner_kill_network_isolation", elapsed_ms=elapsed_ms,
             request_deadline_ms=1500, cleanup_headroom_ms=1000,
             another_connection_completed=True, sibling_listener_completed=True, response_data_bytes=0,
             wire_connection_close_observed=stalled.terminated is not None)


async def shutdown(args):
    async with opened(args) as main_peer, opened(args, port=args.sibling_port) as sibling:
        await main_peer.response(main_peer.request())
        await sibling.response(sibling.request())
        main_peer.request(b"POST", b"/echo", fin=False)
        print('GAOXY_HTTP3_PEER {"event":"shutdown_ready"}', flush=True)
        command = await asyncio.wait_for(asyncio.to_thread(sys.stdin.readline), 8)
        assert command == "removed\n", command
        await main_peer.until(lambda: main_peer.terminated is not None, allow_close=True)
        assert main_peer.terminated == 0, main_peer.terminated
        await sibling.response(sibling.request())
        emit("listener_shutdown_sibling_isolation", close_code=0, established_sibling_completed=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", required=True, type=int)
    parser.add_argument("--sibling-port", required=True, type=int)
    parser.add_argument("--busy-port", type=int)
    parser.add_argument("--ca", required=True)
    parser.add_argument("--mode", choices=["ordinary", "malformed", "cancellation", "shutdown", "diagnostic", "shared", "busy"], required=True)
    args = parser.parse_args()
    try:
        asyncio.run(globals()[args.mode](args))
    except Exception as error:
        if args.mode == "shared":
            print("GAOXY_HTTP3_PEER " + json.dumps(dict(name="shared_peer_runtime", result="FAIL",
                  error=f"{type(error).__name__}: {error}")), flush=True)
        raise


if __name__ == "__main__":
    main()
