#!/usr/bin/env python3
"""Independent aioquic downstream-to-dedicated-H1 matrix cases."""
import argparse
import asyncio
import base64
import json
from urllib.parse import quote

from peer import opened


def emit(name, **details):
    print("GAOXY_HTTP3_MATRIX " + json.dumps(dict(name=name, result="PASS", **details)), flush=True)


async def origin_control(args, path="/__control/snapshot"):
    async with asyncio.timeout(10):
        reader, writer = await asyncio.open_connection("127.0.0.1", args.origin_port)
        try:
            writer.write(f"GET {path} HTTP/1.1\r\nHost: control\r\nConnection: close\r\n\r\n".encode())
            await writer.drain()
            head = await reader.readuntil(b"\r\n\r\n")
            assert head.startswith(b"HTTP/1.1 200 "), head
            return json.loads(await reader.read())
        finally:
            writer.close()
            await writer.wait_closed()


async def receipt_until(args, identity, predicate):
    async with asyncio.timeout(10):
        while True:
            snapshot = await origin_control(args)
            matching = [r for r in snapshot["requests"] if r["id"] == identity]
            assert len(matching) <= 1, (identity, "request replay", matching)
            if matching and predicate(matching[0]):
                return matching[0]
            await asyncio.sleep(0.01)


def extras(identity, more=()):
    return [(b"x-matrix-id", identity.encode())] + list(more)


async def result(peer, sid):
    await peer.until(lambda: sid in peer.ended or sid in peer.resets)
    assert sid not in peer.resets, (sid, peer.resets)
    assert peer.headers[sid][0].count((b":status", b"200")) == 1, peer.headers[sid]
    assert peer.headers[sid][-1] == [(b"x-origin", b"first"), (b"x-origin", b"second")], peer.headers[sid]
    return json.loads(peer.data[sid])


def check_report(report, identity, target, body=b"", trailers=()):
    assert report["id"] == identity and report["method"] in ("GET", "POST"), report
    assert report["target"] == target, report
    assert base64.b64decode(report["body"]) == body, report
    assert report["bytes"] == len(body) and report["complete"] is True, report
    assert report["trailers"] == [list(field) for field in trailers], report


async def run(args):
    async with opened(args) as peer:
        for identity, path in [("escaped", b"/proxy/a%2Fb?q=%2F&x=1"),
                               ("empty-query", b"/proxy/query?")]:
            sid = peer.request(path=path, extra=extras(identity))
            report = await result(peer, sid)
            check_report(report, identity, path.decode())
            emit("proxy_" + identity, target=report["target"], response_trailers=report["trailers"])

        identity = "wire-identity"
        sid = peer.request(path=b"/proxy/identity", extra=extras(identity, [
            (b"te", b"trailers"), (b"forwarded", b"for=spoofed"),
            (b"x-forwarded-for", b"spoofed"), (b"x-forwarded-host", b"spoofed"),
            (b"x-forwarded-proto", b"spoofed"), (b"x-forwarded-client-cert", b"spoofed"),
            (b"x-real-ip", b"spoofed"), (b"x-trace", b"first"), (b"x-trace", b"second")]))
        report = await result(peer, sid)
        headers = report["headers"]
        assert [v for k, v in headers if k == "host"] == [f"127.0.0.1:{args.origin_port}"], headers
        assert [v for k, v in headers if k == "x-forwarded-for"] == ["127.0.0.1"], headers
        assert [v for k, v in headers if k == "x-forwarded-host"] == ["localhost"], headers
        assert [v for k, v in headers if k == "x-forwarded-proto"] == ["https"], headers
        assert [v for k, v in headers if k == "x-trace"] == ["first", "second"], headers
        assert not any(k in ("te", "forwarded", "x-real-ip", "x-forwarded-client-cert") or
                       "spoofed" in v for k, v in headers), headers
        emit("proxy_fixed_host_forwarding_identity_hop_filter", origin_headers=headers)

        for length in (0, 3):
            identity = f"fixed-trailers-{length}"
            body = b"abc" if length else b""
            sid = peer.request(b"POST", b"/proxy/trailers", extras(identity, [
                (b"content-length", str(length).encode()), (b"trailer", b"x-trace")]), fin=False)
            if body:
                peer.http.send_data(sid, body, end_stream=False)
            peer.http.send_headers(sid, [(b"x-trace", b"first"), (b"x-trace", b"second")], end_stream=True)
            peer.transmit()
            report = await result(peer, sid)
            check_report(report, identity, "/proxy/trailers", body,
                         [("x-trace", "first"), ("x-trace", "second")])
            assert [v for k, v in report["headers"] if k == "transfer-encoding"] == ["chunked"], report
            assert not any(k == "content-length" for k, _ in report["headers"]), report
            emit("proxy_" + identity, request_bytes=length, upstream_framing="chunked",
                 request_trailers=report["trailers"], response_trailers=["first", "second"])

        identity, payload = "stream-upload", b"proxy-progress-" * 16384
        sid = peer.request(b"POST", b"/proxy/stream", extras(identity, [
            (b"content-length", str(len(payload)).encode())]), fin=False)
        peer.http.send_data(sid, payload[:17], end_stream=False)
        peer.transmit()
        observed = await receipt_until(args, identity, lambda r: r["bytes"] >= 17)
        assert observed["bytes"] == 17 and observed["complete"] is False, observed
        assert sid not in peer.ended and sid not in peer.headers, peer.headers.get(sid)
        for offset in range(17, len(payload), 1021):
            peer.http.send_data(sid, payload[offset:offset + 1021],
                                end_stream=offset + 1021 >= len(payload))
        peer.transmit()
        report = await result(peer, sid)
        check_report(report, identity, "/proxy/stream", payload)
        emit("proxy_progressive_upload_before_request_fin", bytes=len(payload),
             before_fin_origin_bytes=17, origin_chunk_count=len(report["chunks"]))

        identity = "stream-download"
        sid = peer.request(path=b"/proxy/download", extra=extras(identity))
        await peer.until(lambda: len(peer.data.get(sid, b"")) >= 15)
        assert peer.data[sid] == b"download-first-" and sid not in peer.ended, peer.data[sid]
        assert (b"x-origin-hop", b"secret") not in peer.headers[sid][0], peer.headers[sid]
        assert [v for k, v in peer.headers[sid][0] if k == b"set-cookie"] == [b"first=1", b"second=2"]
        await origin_control(args, "/__control/release?id=" + quote(identity))
        body = b"download-first-" + b"download-rest-" * 4096
        await peer.response(sid, body)
        assert peer.headers[sid][-1] == [(b"x-origin", b"first"), (b"x-origin", b"second")]
        emit("proxy_progressive_download_before_origin_fin", bytes=len(body), before_fin_bytes=15,
             response_trailers=["first", "second"], response_hop_dropped=True)

        before = len((await origin_control(args))["requests"])
        sid = peer.request(b"POST", b"/proxy/forbidden", extras("forbidden", [
            (b"content-length", b"0"), (b"trailer", b"authorization")]))
        await peer.response(sid, b"", b"400")
        after = (await origin_control(args))["requests"]
        assert len(after) == before and not any(r["id"] == "forbidden" for r in after), after
        emit("proxy_forbidden_authentication_trailer_before_upstream", status=400, upstream_requests=0)

        identity = "early-response"
        sid = peer.request(b"POST", b"/proxy/early", extras(identity, [(b"content-length", b"1000000")]), fin=False)
        await peer.response(sid, b"", b"413")
        receipt = await receipt_until(args, identity, lambda r: r["closed"])
        assert receipt["bytes"] == 0 and receipt["cancelled"] is True and receipt["complete"] is False, receipt
        await result(peer, peer.request(path=b"/proxy/early-sibling", extra=extras("early-sibling")))
        emit("proxy_early_final_stops_open_upload", status=413, request_fin_sent=False,
             origin_cancelled=True, same_connection_sibling=True)

        identity = "reset-response"
        sid = peer.request(path=b"/proxy/cancel", extra=extras(identity))
        await peer.until(lambda: sid in peer.headers)
        peer._quic.reset_stream(sid, 0x10C)
        peer._quic.stop_stream(sid, 0x10C)
        peer.transmit()
        receipt = await receipt_until(args, identity, lambda r: r["closed"])
        assert receipt["cancelled"] is True, receipt
        siblings = [peer.request(path=b"/proxy/reset-sibling", extra=extras(f"reset-sibling-{i}")) for i in range(2)]
        await asyncio.gather(*(result(peer, stream) for stream in siblings))
        emit("proxy_reset_cancels_origin_keeps_connection_siblings", origin_cancelled=True, siblings=2)

    async with opened(args, port=args.sibling_port) as sibling:
        report = await result(sibling, sibling.request(path=b"/proxy/listener-sibling", extra=extras("listener-sibling")))
        check_report(report, "listener-sibling", "/proxy/listener-sibling")
        emit("proxy_separate_listener_sibling", separate_listener=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", required=True, type=int)
    parser.add_argument("--sibling-port", required=True, type=int)
    parser.add_argument("--origin-port", required=True, type=int)
    parser.add_argument("--ca", required=True)
    args = parser.parse_args()
    args.mode = "matrix"
    asyncio.run(run(args))
