#!/usr/bin/env python3
"""Independent standalone H3/H1 static, streaming and generation observations."""
import argparse
import asyncio
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
            await barrier("invalid-reload")
            await asyncio.gather(peer.response(peer.request(path=b"/"), b"new"), legacy(args))
            emit("standalone_invalid_reload_preserves_current_generation", body="new")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("port", "h1-port", "origin-port"):
        parser.add_argument("--" + name, required=True, type=int)
    parser.add_argument("--ca", required=True)
    args = parser.parse_args()
    args.mode = "standalone"
    asyncio.run(run(args))
