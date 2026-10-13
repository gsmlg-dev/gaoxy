#!/usr/bin/env python3
"""Independent standalone H3/H1 static, streaming and generation observations."""
import argparse
import asyncio
import hashlib
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from peer import opened
from proxy_peer import extras, result, check_report, receipt_until, origin_control


def emit(name, **details):
    print("GAOXY_STANDALONE_PEER " + json.dumps(dict(
        event="check", name=name, result="PASS", **details)), flush=True)


async def legacy(args):
    reader, writer = await asyncio.open_connection("127.0.0.1", args.h1_port)
    try:
        writer.write(b"GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
        await writer.drain()
        response = await reader.read()
        assert response.startswith(b"HTTP/1.1 200 ") and response.endswith(b"\r\n\r\nlegacy"), response
    finally:
        writer.close()
        await writer.wait_closed()


async def barrier(command):
    print("GAOXY_STANDALONE_PEER " + json.dumps(dict(event="barrier", command=command)), flush=True)
    line = await asyncio.to_thread(sys.stdin.readline)
    assert line == "continue\n", line


async def h3_origin(args, command="snapshot"):
    print("GAOXY_STANDALONE_PEER " + json.dumps(dict(
        event="origin_control", command=command)), flush=True)
    line = await asyncio.to_thread(sys.stdin.readline)
    receipt = json.loads(line)
    assert receipt["event"] == ("snapshot" if command == "snapshot" else "response_fin"), receipt
    return receipt


async def h3_receipt(args, path, predicate):
    async with asyncio.timeout(5):
        while True:
            snapshot = await h3_origin(args)
            matching = [r for r in snapshot["requests"] if r["path"] == path]
            assert len(matching) <= 1, matching
            if matching and predicate(matching[0]):
                return matching[0]
            await asyncio.sleep(0.005)


def check_h3_receipt(receipt, path, payload, authority, trailers):
    assert receipt["path"] == path, receipt
    fields = receipt["headers"]
    for field in ((":method", "POST"), (":scheme", "https"),
                  (":authority", authority), (":path", path)):
        assert fields.count(list(field)) == 1, receipt
    assert receipt["data_bytes"] == len(payload), receipt
    assert receipt["data_sha256"] == hashlib.sha256(payload).hexdigest(), receipt
    assert receipt["trailers"] == trailers and receipt["trailer_blocks"] == 1, receipt
    assert receipt["request_fin"] and receipt["fin_count"] == 1, receipt


async def run(args):
    async with asyncio.timeout(70):
        async with opened(args) as peer:
            await peer.response(peer.request(path=b"/"), b"old")
            await legacy(args)
            emit("standalone_h3_static_and_legacy_h1", protocols=["h3", "HTTP/1.1"])

            payload = b"standalone-upload-" * 4096
            sid = peer.request(b"POST", b"/proxy/upload", extras("standalone-upload", [
                (b"content-length", str(len(payload)).encode())]), fin=False)
            peer.http.send_data(sid, payload[:17], end_stream=False)
            peer.transmit()
            observed = await receipt_until(args, "standalone-upload", lambda r: r["bytes"] == 17)
            assert not observed["complete"]
            peer.http.send_data(sid, payload[17:], end_stream=True)
            peer.transmit()
            report = await result(peer, sid)
            check_report(report, "standalone-upload", "/proxy/upload", payload)
            emit("standalone_h3_proxy_progressive_upload", bytes=len(payload), before_fin_bytes=17)

            request_trailers = [(b"x-upload", b"one"), (b"x-upload", b"two")]
            for path, body, authority in (
                ("/echo-standalone-upload", payload, args.h3_origin_authority_a),
                ("/echo-standalone-zero", b"", args.h3_origin_authority_b),
            ):
                sid = peer.request(b"POST", path.encode(), [
                    (b"content-length", str(len(body)).encode()),
                    (b"trailer", b"x-upload")], fin=False)
                if body:
                    peer.http.send_data(sid, body[:17], end_stream=False)
                    peer.transmit()
                    observed = await h3_receipt(args, path, lambda r: r["data_bytes"] == 17)
                    assert not observed["request_fin"] and observed["fin_count"] == 0, observed
                    peer.http.send_data(sid, body[17:], end_stream=False)
                peer.http.send_headers(sid, request_trailers, end_stream=True)
                peer.transmit()
                await peer.response(sid, b"echo-finished")
                assert peer.headers[sid][-1] == [(b"x-check", b"one"), (b"x-check", b"two")], peer.headers[sid]
                observed = await h3_receipt(args, path, lambda r: r["request_fin"])
                check_h3_receipt(observed, path, body, authority,
                                 [["x-upload", "one"], ["x-upload", "two"]])
                emit("standalone_h3_origin_" + ("progressive_upload" if body else "zero_data_trailers"),
                     bytes=len(body), before_fin_bytes=17 if body else 0, receipt=observed,
                     response_trailers=["one", "two"])

            invalid = peer.request(b"POST", b"/proxy/forbidden", extras("standalone-forbidden", [
                (b"content-length", b"0"), (b"trailer", b"authorization")]))
            sibling = peer.request(path=b"/sibling")
            await asyncio.gather(peer.response(invalid, b"", b"400"),
                                 peer.response(sibling, b"old"), legacy(args))
            snapshot = await origin_control(args)
            assert not any(r["id"] == "standalone-forbidden" for r in snapshot["requests"]), snapshot
            emit("standalone_proxy_failure_isolates_h3_and_h1_siblings", status=400, upstream_requests=0)

            sid = peer.request(path=b"/proxy/download", extra=extras("standalone-old-generation"))
            await peer.until(lambda: len(peer.data.get(sid, b"")) >= 15)
            assert peer.data[sid] == b"download-first-" and sid not in peer.ended, peer.data
            h3_sid = peer.request(path=b"/ordinary")
            await peer.until(lambda: len(peer.data.get(h3_sid, b"")) >= 9)
            assert peer.data[h3_sid] == b"ordinary-" and h3_sid not in peer.ended, peer.data
            await barrier("reload")
            await peer.response(peer.request(path=b"/proxy/download"), b"new")
            await peer.response(peer.request(path=b"/"), b"new")
            await legacy(args)
            await origin_control(args, "/__control/release?id=standalone-old-generation")
            body = b"download-first-" + b"download-rest-" * 4096
            await peer.response(sid, body)
            assert peer.headers[sid][-1] == [(b"x-origin", b"first"), (b"x-origin", b"second")]
            emit("standalone_reload_keeps_listener_and_inflight_generation", old_bytes=len(body),
                 before_origin_fin_bytes=15, new_body="new", response_trailers=["first", "second"])
            finished = await h3_origin(args, "finish_ordinary")
            assert finished["path"] == "/ordinary" and finished["origin"] == "a", finished
            await peer.response(h3_sid, b"ordinary-response")
            assert peer.headers[h3_sid][-1] == [(b"x-check", b"one"), (b"x-check", b"two")]
            emit("standalone_h3_origin_inflight_generation", old_bytes=17,
                 before_origin_fin_bytes=9, new_body="new", response_trailers=["one", "two"])
            await barrier("invalid-reload")
            await asyncio.gather(peer.response(peer.request(path=b"/"), b"new"), legacy(args))
            emit("standalone_invalid_reload_preserves_current_generation", body="new")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("port", "h1-port", "origin-port"):
        parser.add_argument("--" + name, required=True, type=int)
    parser.add_argument("--ca", required=True)
    parser.add_argument("--h3-origin-authority-a", required=True)
    parser.add_argument("--h3-origin-authority-b", required=True)
    args = parser.parse_args()
    args.mode = "standalone"
    asyncio.run(run(args))
