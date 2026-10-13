#!/usr/bin/env python3
"""Independent native H1/hyper-h2/aioquic downstream to H3-origin matrix."""
import argparse
import asyncio
from contextlib import AsyncExitStack, asynccontextmanager
import gzip
import hashlib
import json
import ssl
import sys
import time

import pylsqpack
import h2.config
import h2.connection
import h2.events
import h2.settings
from aioquic.asyncio import connect
from aioquic.asyncio.protocol import QuicConnectionProtocol
from aioquic.buffer import Buffer, BufferReadError
from aioquic.h3.connection import H3Connection
from aioquic.h3.events import DataReceived, HeadersReceived
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.events import ConnectionTerminated, ProtocolNegotiated, StreamDataReceived, StreamReset

CASES = (
    "get", "head", "bodyless_204", "bodyless_304", "progressive_upload",
    "progressive_download", "tiny_window_1mib", "duplicate_fields", "raw_compression",
    "escaped_path", "empty_query", "redirect_no_replay", "trailers_zero", "trailers_data",
    "early_final", "downstream_cancel", "upstream_reset", "opening_timeout", "total_timeout",
    "wrong_ca", "wrong_hostname", "interleaved_authorities",
)
TRAILERS = [(b"x-check", b"one"), (b"x-check", b"two")]
FAILURES = {"early_final", "downstream_cancel", "upstream_reset", "opening_timeout",
            "total_timeout", "wrong_ca", "wrong_hostname"}


def emit(event, **fields):
    print("GAOXY_UPSTREAM_MATRIX_PEER " + json.dumps(dict(event=event, **fields)), flush=True)


async def control(command, **fields):
    emit("barrier", command=command, **fields)
    line = await asyncio.to_thread(sys.stdin.readline)
    assert line, "matrix coordinator control EOF"
    result = json.loads(line)
    assert result["status"] == "ok", result
    return result["value"]


def state():
    return dict(headers=[], body=bytearray(), ended=False, reset=None, closed=False)


class BodylessResponseDecoder:
    """Bounded independent HEAD/304 framing and static/literal QPACK decoder."""
    max_bytes = 65_536

    def __init__(self, stream_id, response):
        self.stream_id, self.response = stream_id, response
        self.carry = b""
        self.decoder = pylsqpack.Decoder(0, 0)
        response["bodyless_wire"] = dict(decoder="raw_static_qpack", fin_count=0,
                                         data_frames=0, data_bytes=0)

    def feed(self, data, fin=False):
        assert not self.response["ended"], "bodyless bytes after FIN"
        assert len(self.carry) + len(data) <= self.max_bytes, "bodyless frame/carry limit"
        self.carry += data
        while self.carry:
            buffer = Buffer(data=self.carry)
            try:
                kind, size = buffer.pull_uint_var(), buffer.pull_uint_var()
            except BufferReadError:
                break
            assert size <= self.max_bytes, "bodyless frame/carry limit"
            assert kind != 0, "bodyless DATA"
            assert kind not in (2, 3, 4, 5, 7, 13, 14), "unexpected response frame"
            offset = buffer.tell()
            if len(self.carry) - offset < size:
                break
            payload = self.carry[offset:offset + size]
            self.carry = self.carry[offset + size:]
            if kind == 1:
                assert not self.response["headers"], "repeated HEADERS"
                assert payload[:2] == b"\x00\x00", "unexpected dynamic QPACK"
                instructions, headers = self.decoder.feed_header(self.stream_id, payload)
                assert not instructions, "unexpected dynamic QPACK"
                self.response["headers"].append(headers)
        if fin:
            assert not self.carry, "partial frame at FIN"
            assert self.response["headers"], "missing HEADERS at FIN"
            self.response["bodyless_wire"]["fin_count"] += 1
            self.response["ended"] = True


class Responses:
    def __init__(self):
        self.responses, self.changed = {}, asyncio.Event()

    async def until(self, sid, predicate):
        while not predicate(self.responses[sid]):
            self.changed.clear()
            await self.changed.wait()
        return self.responses[sid]

    async def done(self, sid):
        try:
            return await self.until(sid, lambda r: r["ended"] or r["reset"] is not None or r["closed"])
        except asyncio.CancelledError:
            print("GAOXY_RESPONSE_DEADLINE " + json.dumps(diagnostic(self.responses[sid])), flush=True)
            raise


class H1(Responses):
    def __init__(self, reader, writer):
        super().__init__()
        self.reader, self.writer = reader, writer
        self.tasks, self.chunked, self.methods = [], {}, {}

    async def request(self, method, path, fields, fin=True, chunked=False):
        sid = len(self.responses)
        self.responses[sid] = state()
        self.chunked[sid], self.methods[sid] = chunked, method
        head = [(b"host", b"localhost")] + fields
        if chunked:
            head.append((b"transfer-encoding", b"chunked"))
        self.writer.write(method + b" " + path + b" HTTP/1.1\r\n" +
                          b"".join(k + b": " + v + b"\r\n" for k, v in head) + b"\r\n")
        await self.writer.drain()
        self.tasks.append(asyncio.create_task(self.read_response(sid)))
        if fin and chunked:
            await self.finish(sid)
        return sid

    async def data(self, sid, body):
        if self.chunked[sid]:
            self.writer.write(f"{len(body):x}\r\n".encode() + body + b"\r\n")
        else:
            self.writer.write(body)
        await self.writer.drain()

    async def finish(self, sid, trailers=()):
        if self.chunked[sid]:
            self.writer.write(b"0\r\n" + b"".join(k + b": " + v + b"\r\n" for k, v in trailers) + b"\r\n")
            await self.writer.drain()
        else:
            assert not trailers

    async def read_response(self, sid):
        response = self.responses[sid]
        try:
            raw = await self.reader.readuntil(b"\r\n\r\n")
            lines = raw[:-4].split(b"\r\n")
            code = int(lines[0].split(b" ")[1])
            fields = [(k.lower(), v.strip()) for k, v in (line.split(b":", 1) for line in lines[1:])]
            response["headers"].append([(b":status", str(code).encode())] + fields)
            self.changed.set()
            if self.methods[sid] == b"HEAD" or code in (204, 304):
                wire = dict(eof=False, post_header_octets=0,
                            post_header_sha256=hashlib.sha256(b"").hexdigest(), prefix_hex="")
                response["bodyless_wire"] = wire
                digest = hashlib.sha256()
                while data := await self.reader.read(1021):
                    wire["post_header_octets"] += len(data)
                    digest.update(data)
                    wire["post_header_sha256"] = digest.hexdigest()
                    if not wire["prefix_hex"]:
                        wire["prefix_hex"] = data[:64].hex()
                wire["eof"] = True
                response["ended"] = True
            elif (b"transfer-encoding", b"chunked") in fields:
                while True:
                    line = await self.reader.readline()
                    if not line or (not line.endswith(b"\r\n") and self.reader.at_eof()):
                        raise asyncio.IncompleteReadError(line, None)
                    size = int(line.split(b";", 1)[0].strip(), 16)
                    if size == 0:
                        trailers = []
                        while True:
                            line = await self.reader.readline()
                            if not line or (not line.endswith(b"\r\n") and self.reader.at_eof()):
                                raise asyncio.IncompleteReadError(line, None)
                            if line == b"\r\n":
                                break
                            k, v = line[:-2].split(b":", 1)
                            trailers.append((k.lower(), v.strip()))
                        if trailers:
                            response["headers"].append(trailers)
                        response["ended"] = True
                        break
                    response["body"].extend(await self.reader.readexactly(size))
                    assert await self.reader.readexactly(2) == b"\r\n"
                    self.changed.set()
            else:
                lengths = [int(v) for k, v in fields if k == b"content-length"]
                if lengths:
                    response["body"].extend(await self.reader.readexactly(lengths[0]))
                    response["ended"] = True
                else:
                    # A close-delimited success requires the actual clean EOF.
                    while data := await self.reader.read(1021):
                        response["body"].extend(data)
                        self.changed.set()
                    response["ended"] = True
        except (asyncio.IncompleteReadError, ConnectionResetError, BrokenPipeError):
            response["closed"] = True
        finally:
            self.changed.set()

    async def cancel(self, sid):
        self.writer.transport.abort()

    async def close(self):
        self.writer.close()
        try:
            await self.writer.wait_closed()
        except (ConnectionResetError, BrokenPipeError):
            pass
        for task in self.tasks:
            if not task.done():
                task.cancel()
        await asyncio.gather(*self.tasks, return_exceptions=True)


class H2(Responses):
    def __init__(self, reader, writer):
        super().__init__()
        self.reader, self.writer = reader, writer
        self.http = h2.connection.H2Connection(config=h2.config.H2Configuration(client_side=True))
        self.http.initiate_connection()
        self.http.update_settings({h2.settings.SettingCodes.INITIAL_WINDOW_SIZE: 2048})
        self.writer.write(self.http.data_to_send())
        self.pump = asyncio.create_task(self.read_responses())

    async def request(self, method, path, fields, fin=True, chunked=False):
        sid = self.http.get_next_available_stream_id()
        self.responses[sid] = state()
        self.http.send_headers(sid, [(b":method", method), (b":scheme", b"https"),
            (b":authority", b"localhost"), (b":path", path)] + fields, end_stream=fin)
        self.writer.write(self.http.data_to_send())
        await self.writer.drain()
        return sid

    async def data(self, sid, body):
        offset = 0
        while offset < len(body):
            response = self.responses[sid]
            assert response["reset"] is None and not response["closed"], {
                "phase": "h2_upload", "accepted_chunk_bytes": offset,
                "chunk_bytes": len(body), "window": self.http.local_flow_control_window(sid),
                "response": diagnostic(response)}
            size = min(len(body) - offset, self.http.local_flow_control_window(sid),
                       self.http.max_outbound_frame_size)
            if size <= 0:
                self.changed.clear()
                await self.changed.wait()
                continue
            self.http.send_data(sid, body[offset:offset + size])
            offset += size
            self.writer.write(self.http.data_to_send())
            await self.writer.drain()

    async def finish(self, sid, trailers=()):
        if trailers:
            self.http.send_headers(sid, list(trailers), end_stream=True)
        else:
            self.http.end_stream(sid)
        self.writer.write(self.http.data_to_send())
        await self.writer.drain()

    async def read_responses(self):
        try:
            while data := await self.reader.read(16_384):
                for event in self.http.receive_data(data):
                    if isinstance(event, (h2.events.ResponseReceived, h2.events.TrailersReceived)):
                        self.responses[event.stream_id]["headers"].append(event.headers)
                    elif isinstance(event, h2.events.DataReceived):
                        self.responses[event.stream_id]["body"].extend(event.data)
                        self.http.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
                    elif isinstance(event, h2.events.StreamEnded):
                        self.responses[event.stream_id]["ended"] = True
                    elif isinstance(event, h2.events.StreamReset):
                        self.responses[event.stream_id]["reset"] = int(event.error_code)
                    elif isinstance(event, h2.events.ConnectionTerminated):
                        termination = dict(error_code=int(event.error_code),
                                           last_stream_id=event.last_stream_id,
                                           additional_data_hex=(event.additional_data or b"")[:64].hex())
                        print("GAOXY_H2_TERMINAL " + json.dumps(termination), flush=True)
                        for response in self.responses.values():
                            response["closed"] = True
                            response["termination"] = termination
                self.writer.write(self.http.data_to_send())
                await self.writer.drain()
                self.changed.set()
        except (ConnectionResetError, BrokenPipeError):
            pass
        finally:
            for response in self.responses.values():
                if not response["ended"]:
                    response["closed"] = True
            self.changed.set()

    async def cancel(self, sid):
        self.http.reset_stream(sid, error_code=0x8)
        self.writer.write(self.http.data_to_send())
        await self.writer.drain()

    async def close(self):
        self.writer.close()
        try:
            await self.writer.wait_closed()
        except (ConnectionResetError, BrokenPipeError):
            pass
        if not self.pump.done():
            self.pump.cancel()
        await asyncio.gather(self.pump, return_exceptions=True)


class H3(QuicConnectionProtocol, Responses):
    def __init__(self, *args, **kwargs):
        QuicConnectionProtocol.__init__(self, *args, **kwargs)
        Responses.__init__(self)
        self.http = H3Connection(self._quic)
        self.negotiated = None
        self.bodyless_decoders = {}

    def quic_event_received(self, event):
        if isinstance(event, StreamDataReceived) and event.stream_id in self.bodyless_decoders:
            self.bodyless_decoders[event.stream_id].feed(event.data, fin=event.end_stream)
            self.changed.set()
            return
        if isinstance(event, ProtocolNegotiated):
            self.negotiated = event.alpn_protocol
        elif isinstance(event, StreamReset):
            self.responses[event.stream_id]["reset"] = event.error_code
        elif isinstance(event, ConnectionTerminated):
            termination = dict(error_code=event.error_code, reason=event.reason_phrase[:1024])
            print("GAOXY_H3_TERMINAL " + json.dumps(termination), flush=True)
            for response in self.responses.values():
                if not response["ended"]:
                    response["closed"] = True
                    response["termination"] = termination
        for current in self.http.handle_event(event):
            if isinstance(current, HeadersReceived):
                self.responses[current.stream_id]["headers"].append(current.headers)
            elif isinstance(current, DataReceived):
                response = self.responses[current.stream_id]
                response["body"].extend(current.data)
                observed = response.setdefault("data_observation", dict(events=0, first_ms=None, last_ms=None))
                elapsed = round((time.monotonic() - response["started"]) * 1000, 3)
                observed["events"] += 1
                if observed["first_ms"] is None:
                    observed["first_ms"] = elapsed
                observed["last_ms"] = elapsed
            if isinstance(current, (HeadersReceived, DataReceived)) and current.stream_ended:
                self.responses[current.stream_id]["ended"] = True
        self.changed.set()

    async def request(self, method, path, fields, fin=True, chunked=False):
        sid = self._quic.get_next_available_stream_id()
        self.responses[sid] = state()
        self.responses[sid]["started"] = time.monotonic()
        # aioquic 1.2.0's generic validator compares metadata Content-Length
        # with DATA size at FIN without knowing HEAD/304 bodyless semantics.
        if method == b"HEAD" or (b"x-matrix-case", b"bodyless_304") in fields:
            self.bodyless_decoders[sid] = BodylessResponseDecoder(sid, self.responses[sid])
        self.http.send_headers(sid, [(b":method", method), (b":scheme", b"https"),
            (b":authority", b"localhost"), (b":path", path)] + fields, end_stream=fin)
        self.transmit()
        return sid

    async def data(self, sid, body):
        self.http.send_data(sid, body, end_stream=False)
        self.transmit()

    async def finish(self, sid, trailers=()):
        if trailers:
            self.http.send_headers(sid, list(trailers), end_stream=True)
        else:
            self.http.send_data(sid, b"", end_stream=True)
        self.transmit()

    async def cancel(self, sid):
        self._quic.reset_stream(sid, 0x10C)
        self._quic.stop_stream(sid, 0x10C)
        self.transmit()


@asynccontextmanager
async def opened(args, protocol, sibling=False):
    port = args.ports[protocol + ("_sibling" if sibling else "")]
    if protocol == "h3":
        configuration = QuicConfiguration(is_client=True, alpn_protocols=["h3"],
            max_data=4096, max_stream_data=2048, idle_timeout=15)
        configuration.server_name = "localhost"
        configuration.load_verify_locations(args.ca)
        async with connect("127.0.0.1", port, configuration=configuration,
                           create_protocol=H3) as peer:
            assert peer.negotiated == "h3", peer.negotiated
            yield peer
    else:
        context = ssl.create_default_context(cafile=args.ca)
        context.set_alpn_protocols(["h2" if protocol == "h2" else "http/1.1"])
        reader, writer = await asyncio.open_connection("127.0.0.1", port,
                                                       ssl=context, server_hostname="localhost")
        assert writer.get_extra_info("ssl_object").selected_alpn_protocol() == ("h2" if protocol == "h2" else "http/1.1")
        peer = (H1 if protocol == "h1" else H2)(reader, writer)
        try:
            yield peer
        finally:
            await peer.close()


def fields(identity, case, extras=()):
    return [(b"x-matrix-id", identity.encode()), (b"x-matrix-case", case.encode())] + list(extras)


def check_response(response, body=b"matrix-ok", status=200, trailers=True):
    assert response["ended"] and response["reset"] is None, diagnostic(response)
    assert response["headers"][0].count((b":status", str(status).encode())) == 1, diagnostic(response)
    assert bytes(response["body"]) == body, diagnostic(response)
    if trailers:
        assert len(response["headers"]) == 2 and response["headers"][-1] == TRAILERS, diagnostic(response)
    else:
        assert len(response["headers"]) == 1, diagnostic(response)


def diagnostic(response):
    return {"headers": repr(response["headers"]), "bytes": len(response["body"]),
            "sha256": hashlib.sha256(response["body"]).hexdigest(),
            "ended": response["ended"], "reset": response["reset"], "closed": response["closed"],
            "termination": response.get("termination"),
            "data_observation": response.get("data_observation"),
            "bodyless_wire": response.get("bodyless_wire")}


async def wire(identity, predicate):
    while True:
        snapshot = await control("origin_snapshot")
        requests = [request for request in snapshot if request["id"] == identity]
        assert len(requests) <= 1, ("request replay", identity, requests)
        if requests and predicate(requests[0]):
            return requests[0]
        await asyncio.sleep(0.005)


async def start(peer, identity, case, method=b"GET", path=None, fin=True, extras=(), chunked=False):
    return await peer.request(method, path or f"/matrix/a/{case}".encode(),
                              fields(identity, case, extras), fin=fin, chunked=chunked)


async def row(args, protocol, case):
    identity = protocol + "-" + case
    body, method, path, trailers, origin = b"", b"GET", f"/matrix/a/{case}".encode(), [], "a"
    observed = bodyless_wire = None
    response_decoder = None
    if case == "head":
        method = b"HEAD"
    elif case in ("progressive_upload", "tiny_window_1mib", "trailers_zero", "trailers_data", "early_final"):
        method = b"POST"
    if case == "escaped_path":
        path = b"/matrix/a/a%2Fb?q=%2F&x=1"
    elif case == "empty_query":
        path = b"/matrix/a/query?"
    elif case == "wrong_ca":
        path = b"/matrix/wrong-ca/negative"
    elif case == "wrong_hostname":
        path = b"/matrix/wrong-host/negative"
    elif case == "opening_timeout":
        path = b"/matrix/opening/stalled"
    elif case == "total_timeout":
        path = b"/matrix/total/stalled"
    expected = []
    started = time.monotonic()
    # Every request keeps one absolute five-second peer deadline. Cleanup has
    # the original separate one-second Service headroom; it never restarts D.
    async with asyncio.timeout_at(started + 5):
        async with AsyncExitStack() as stack, opened(args, protocol) as peer:
            survivors = []
            if case in FAILURES:
                same = peer if protocol != "h1" else await stack.enter_async_context(opened(args, protocol))
                other = await stack.enter_async_context(opened(args, protocol, sibling=True))
                for current, suffix in ((same, "same"), (other, "listener")):
                    request_id = identity + "-" + suffix
                    stream = await start(current, request_id, "progressive_download", path=b"/matrix/a/survival")
                    await current.until(stream, lambda r: len(r["body"]) >= 9)
                    assert bytes(current.responses[stream]["body"]) == b"progress-" and not current.responses[stream]["ended"]
                    request = await wire(request_id, lambda r: r["request_fin"])
                    assert not request["response_fin"], request
                    survivors.append((current, stream, request_id))
            if case == "interleaved_authorities":
                second = await stack.enter_async_context(opened(args, protocol))
                first = await start(peer, identity + "-a", "progressive_download")
                other = await start(second, identity + "-b", "progressive_download",
                                    path=b"/matrix/b/interleaved")
                for current, sid, request_id, authority, target in (
                    (peer, first, identity + "-a", "a", "/matrix/a/progressive_download"),
                    (second, other, identity + "-b", "b", "/matrix/b/interleaved")):
                    await current.until(sid, lambda r: len(r["body"]) >= 9)
                    assert bytes(current.responses[sid]["body"]) == b"progress-" and not current.responses[sid]["ended"]
                    request = await wire(request_id, lambda r: r["request_fin"])
                    assert not request["response_fin"], request
                    await control("matrix_finish_download", id=request_id)
                    check_response(await current.done(sid), b"progress-" + b"response" * 8192)
                    expected.append(dict(id=request_id, case="progressive_download", method="GET",
                        path=target, origin=authority, bytes=0, body_sha256=hashlib.sha256(b"").hexdigest(),
                        trailers=[], fin_count=1))
            else:
                extras = []
                if protocol == "h1" and case in ("head", "bodyless_204", "bodyless_304"):
                    extras.append((b"connection", b"close"))
                if case == "duplicate_fields":
                    extras = [(b"x-trace", b"first"), (b"x-trace", b"second")]
                if case.startswith("trailers_"):
                    extras = [(b"trailer", b"x-check")]
                    trailers = [list(field) for field in (("x-check", "one"), ("x-check", "two"))]
                    body = b"abc" if case == "trailers_data" else b""
                if case == "progressive_upload":
                    body = b"abcdef"
                elif case == "tiny_window_1mib":
                    body = b"x" * 1048576
                elif case == "early_final":
                    extras = [(b"content-length", b"1048576")]
                streaming = method == b"POST"
                chunked = streaming and case != "early_final"
                sid = await start(peer, identity, case, method, path, not streaming, extras, chunked)
                if streaming and case != "early_final":
                    if case == "progressive_upload":
                        await peer.data(sid, body[:3])
                        observed = await wire(identity, lambda r: r["data_bytes"] >= 3)
                        assert observed["data_bytes"] == 3 and not observed["request_fin"], observed
                        assert not peer.responses[sid]["headers"], diagnostic(peer.responses[sid])
                        await peer.data(sid, body[3:])
                    else:
                        upload_started = time.monotonic()
                        for offset in range(0, len(body), 16_384):
                            await peer.data(sid, body[offset:offset + 16_384])
                        if protocol == "h1" and case == "tiny_window_1mib":
                            print("GAOXY_UPLOAD_DIAGNOSTIC " + json.dumps(dict(
                                id=identity, bytes=len(body),
                                elapsed_ms=round((time.monotonic() - upload_started) * 1000, 3))),
                                file=sys.stderr, flush=True)
                    await peer.finish(sid, TRAILERS if trailers else ())
                if case == "progressive_download":
                    await peer.until(sid, lambda r: len(r["body"]) >= 9)
                    assert bytes(peer.responses[sid]["body"]) == b"progress-" and not peer.responses[sid]["ended"]
                    observed = await wire(identity, lambda r: r["request_fin"])
                    assert not observed["response_fin"], observed
                    await control("matrix_finish_download", id=identity)
                    check_response(await peer.done(sid), b"progress-" + b"response" * 8192)
                elif case == "downstream_cancel":
                    await peer.until(sid, lambda r: len(r["body"]) >= 9)
                    assert not peer.responses[sid]["ended"]
                    await peer.cancel(sid)
                    await control("cancel_observed", id=identity)
                elif case == "total_timeout":
                    response = await peer.done(sid)
                    assert response["headers"][0].count((b":status", b"200")) == 1, diagnostic(response)
                    assert bytes(response["body"]) == b"progress-" and not response["ended"], diagnostic(response)
                    if protocol == "h1":
                        assert response["closed"], diagnostic(response)
                    else:
                        assert response["reset"] == (0x8 if protocol == "h2" else 0x10C), diagnostic(response)
                    await control("cancel_observed", id=identity)
                elif case == "upstream_reset":
                    check_response(await peer.done(sid), b"", 502, trailers=False)
                elif case == "opening_timeout":
                    check_response(await peer.done(sid), b"", 504, trailers=False)
                    await control("cancel_observed", id=identity)
                elif case in ("wrong_ca", "wrong_hostname"):
                    check_response(await peer.done(sid), b"", 502, trailers=False)
                elif case == "early_final":
                    check_response(await peer.done(sid), b"", 413, trailers=False)
                    await control("cancel_observed", id=identity)
                else:
                    response = await peer.done(sid)
                    response_body, status, has_trailers = b"matrix-ok", 200, True
                    if case in ("head", "bodyless_204", "bodyless_304"):
                        response_body, has_trailers = b"", False
                        status = {"bodyless_204": 204, "bodyless_304": 304}.get(case, 200)
                        lengths = [v for k, v in response["headers"][0] if k == b"content-length"]
                        assert lengths == ([] if case == "bodyless_204" else [b"7"]), diagnostic(response)
                        response_decoder = {"h1": "native_http1", "h2": "hyper_h2",
                                            "h3": "aioquic_standard"}[protocol]
                        if protocol == "h1":
                            bodyless_wire = response.get("bodyless_wire")
                            assert bodyless_wire and bodyless_wire["eof"] and bodyless_wire["post_header_octets"] == 0, diagnostic(response)
                            assert bodyless_wire["post_header_sha256"] == hashlib.sha256(b"").hexdigest(), diagnostic(response)
                        elif protocol == "h3" and case in ("head", "bodyless_304"):
                            bodyless_wire = response["bodyless_wire"]
                            response_decoder = bodyless_wire["decoder"]
                            assert bodyless_wire == dict(decoder="raw_static_qpack", fin_count=1,
                                                         data_frames=0, data_bytes=0), diagnostic(response)
                    elif case in ("progressive_upload", "tiny_window_1mib"):
                        response_body = body
                    elif case == "raw_compression":
                        response_body = gzip.compress(b"raw-compressed-response" * 32, mtime=0)
                        assert (b"content-encoding", b"gzip") in response["headers"][0], diagnostic(response)
                    elif case == "redirect_no_replay":
                        response_body, status = b"redirect", 302
                        assert (b"location", b"/matrix/a/must-not-follow") in response["headers"][0]
                    check_response(response, response_body, status, has_trailers)
                    assert [v for k, v in response["headers"][0] if k == b"x-repeat"] == [b"one", b"two"]
                    assert [v for k, v in response["headers"][0] if k == b"set-cookie"] == [b"first=1", b"second=2"]
                expected.append(dict(id=identity, case=case, method=method.decode(), path=path.decode(),
                    origin=origin, bytes=len(body), body_sha256=hashlib.sha256(body).hexdigest(),
                    trailers=trailers, fin_count=0 if case == "early_final" else 1,
                    admitted=case not in ("wrong_ca", "wrong_hostname")))
                if case in FAILURES:
                    for current, stream, request_id in survivors:
                        assert not current.responses[stream]["ended"] and current.responses[stream]["reset"] is None
                        await control("matrix_finish_download", id=request_id)
                        check_response(await current.done(stream), b"progress-" + b"response" * 8192)
                        expected.append(dict(id=request_id, case="progressive_download", method="GET",
                            path="/matrix/a/survival", origin="a", bytes=0,
                            body_sha256=hashlib.sha256(b"").hexdigest(), trailers=[], fin_count=1))
            await control("requests_completed", protocol=protocol, case=case, expected=expected)
    validation = await control("row_complete", protocol=protocol, case=case, expected=expected,
                               elapsed_ms=round((time.monotonic() - started) * 1000),
                               progressive_observation=observed, bodyless_wire=bodyless_wire)
    emit("check", name=protocol + "_" + case, status="PASS", kind="network",
         requests=expected, validation=validation, bodyless_wire=bodyless_wire,
         response_decoder=response_decoder)


async def run(args):
    for protocol in ("h1", "h2", "h3"):
        for case in CASES:
            await row(args, protocol, case)
    emit("done", checks=3 * len(CASES))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ports", required=True, type=json.loads)
    parser.add_argument("--ca", required=True)
    arguments = parser.parse_args()
    asyncio.run(run(arguments))
