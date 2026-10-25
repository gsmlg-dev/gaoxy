#!/usr/bin/env python3
"""Real Endpoint-owned H1/H2/H3, native WebSockets and reload composition."""
import asyncio
import json
import importlib.metadata
import os
from pathlib import Path
import queue
import signal
import subprocess
import sys
import threading
import time

from wsproto.events import TextMessage

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "apps/gaoxy_http/test/support"))
sys.path.insert(0, str(ROOT / "integration/http3"))
from listener_set_peer import h1, h2
from quinn_peer import prepare as prepare_h3_peer, request as quinn_request
from quic_go_peer import prepare as prepare_h3_channel_peer, channel as quic_go_channel
sys.path.insert(0, str(ROOT / "integration/websocket_multiplexed"))
from h2_peer import H2Peer, WebSocketChannel


PATHS = [("/", b"Gaoxy Phoenix native"),
         ("/static/hello.txt", b"Gaoxy native static file"),
         ("/events", b"event: ready\ndata: native\n\n")]


async def h3_request(port, ca, path, body, binary, evidence):
    request_evidence = evidence / "h3-peer" / f"request-{time.monotonic_ns()}"
    request_evidence.mkdir(parents=True)
    receipt = await asyncio.to_thread(quinn_request, binary, port, ca, path=path,
                                      timeout=5, evidence_dir=request_evidence)
    assert receipt["alpn"] == "h3", receipt
    assert len(receipt["responses"]) == 1, receipt
    response = receipt["responses"][0]
    assert response["path"] == path and response["ended"], response
    assert response["connection_id"] == receipt["connection_id"], receipt
    assert dict(response["headers"][0])[":status"] == "200", response
    actual = bytes(response["body"])
    assert body in actual, (path, actual)
    return dict(protocol=receipt["alpn"], status_code=200, path=path,
                evidence=str(request_evidence))


def channel_headers(port, protocol):
    return [(b":method", b"CONNECT"), (b":scheme", b"https"),
            (b":authority", f"localhost:{port}".encode()),
            (b":path", f"/socket/websocket?vsn=2.0.0&unified={protocol}".encode()),
            (b":protocol", b"websocket"), (b"sec-websocket-version", b"13"),
            (b"origin", f"https://localhost:{port}".encode())]


CHANNEL_MESSAGES = [
    ["1", "1", "room:unified", "phx_join", {}],
    ["1", "2", "room:unified", "ping", {"unified": True}],
]


def channel_reply(channel, message):
    assert len(channel.messages) == 1, channel.messages
    kind, payload = channel.messages.pop(0)
    reply = json.loads(payload)
    assert kind == "text" and reply[:4] == ["1", message[1], "room:unified", "phx_reply"], reply
    assert reply[4] == {"status": "ok", "response": message[4]}, reply


def h2_channel(port, ca):
    peer = H2Peer("h2", port, ca)
    try:
        peer.connect()
        peer.wait(lambda: peer.h2.remote_settings.enable_connect_protocol == 1)
        stream = peer.h2.get_next_available_stream_id()
        peer.channels[stream] = WebSocketChannel("phoenix")
        peer.h2.send_headers(stream, channel_headers(port, "h2"), end_stream=False)
        peer.flush()
        peer.wait(lambda: stream in peer.headers)
        assert (b":status", b"200") in peer.headers[stream], peer.headers
        for message in CHANNEL_MESSAGES:
            peer.send(stream, TextMessage(data=json.dumps(message)))
            peer.wait(lambda: bool(peer.channels[stream].messages))
            channel_reply(peer.channels[stream], message)
        peer.close_websocket(stream)
        return dict(protocol=peer.socket.selected_alpn_protocol(), stream=stream, close_code=1000)
    finally:
        if peer.socket is not None:
            peer.socket.close()


async def h3_channel(port, ca, binary, evidence):
    channel_evidence = evidence / "h3-channel-peer"
    receipt = await asyncio.to_thread(quic_go_channel, binary, port, ca, CHANNEL_MESSAGES,
                                      timeout=15, evidence_dir=channel_evidence)
    assert receipt["alpn"] == "h3", receipt
    assert receipt["enable_extended_connect"] is True, receipt
    assert receipt["status"] == 200, receipt
    assert len(receipt["messages"]) == len(CHANNEL_MESSAGES), receipt
    channel = WebSocketChannel("phoenix")
    for message, received in zip(CHANNEL_MESSAGES, receipt["messages"], strict=True):
        channel.messages = [received]
        channel_reply(channel, message)
    assert receipt["close_code"] == 1000, receipt
    return dict(protocol=receipt["alpn"], stream=receipt["stream"], close_code=receipt["close_code"],
                evidence=str(channel_evidence))


def main():
    evidence = Path(os.environ.get("GAOXY_PHOENIX_EVIDENCE", ROOT / ".audit/unified-phoenix")).resolve()
    evidence.mkdir(parents=True, exist_ok=True)
    h3_binary, h3_build = prepare_h3_peer(evidence / "h3-peer")
    h3_channel_binary, h3_channel_build = prepare_h3_channel_peer(evidence / "h3-channel-peer")
    certs = evidence / "certs"
    subprocess.run(["bash", str(ROOT / "scripts/generate-fixtures.sh"), str(certs)], check=True, capture_output=True, timeout=30)
    env = dict(os.environ, MIX_ENV="dev", ELIXIR_ERL_OPTIONS="+S 2:2", PHOENIX_NATIVE_H3="1",
               PHOENIX_NATIVE_H2="1", PHOENIX_NATIVE_PORT="0", PHOENIX_NATIVE_HTTPS_PORT="0",
               PHOENIX_NATIVE_HTTP3_PORT="0", PHOENIX_NATIVE_RELOAD="1",
               PHOENIX_NATIVE_CERTFILE=str(certs / "cert.pem"), PHOENIX_NATIVE_KEYFILE=str(certs / "key.pem"))
    events, receipts, checks = queue.Queue(), [], []
    controller = ROOT / "examples/phoenix_native/lib/phoenix_native/page_controller.ex"
    original = controller.read_bytes()
    log = (evidence / "server.log").open("w")
    command = ["mix", "run", "--no-start", "--no-compile", str(Path(__file__).with_name("unified_fixture.exs"))]
    server = subprocess.Popen(command, cwd=ROOT / "examples/phoenix_native", env=env,
                              stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, bufsize=1, start_new_session=True)

    def reader():
        for line in server.stdout:
            log.write(line)
            log.flush()
            if "GAOXY_UNIFIED_PHOENIX " in line:
                row = json.loads(line.split("GAOXY_UNIFIED_PHOENIX ", 1)[1])
                receipts.append(row)
                events.put(row)

    thread = threading.Thread(target=reader, daemon=True)
    thread.start()

    def event(name, timeout=30):
        deadline = time.monotonic() + timeout
        while True:
            row = events.get(timeout=max(0.001, deadline - time.monotonic()))
            if row["event"] == name:
                return row
            assert time.monotonic() < deadline, name

    def passed(name, **details):
        checks.append(dict(check=name, status="PASS", **details))

    report = {"status": "FAIL", "command": command, "native_h3_peer": h3_build,
              "native_h3_channel_peer": h3_channel_build,
              "baseline": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "environment": {"python": sys.version, "ELIXIR_ERL_OPTIONS": env["ELIXIR_ERL_OPTIONS"],
                              "dependencies": {name: importlib.metadata.version(name) for name in
                                               ["h2", "hpack", "hyperframe", "aioquic", "wsproto"]}}}
    try:
        ready = event("ready", 60)
        assert ready["endpoint_server"] and ready["code_reloader"], ready
        ports = ready["ports"]
        ca = str(certs / "ca.pem")
        for request, version in [(h1, "HTTP/1.1"), (h2, "HTTP/2")]:
            for path, body in PATHS:
                headers, actual = request(ports["https"], ca, path)
                assert body in actual, (version, path, actual)
                assert [v for k, v in headers if k == b"alt-svc"] == [f'h3=":{ports["http3"]}"; ma=60'.encode()], headers
            passed("independent_endpoint_" + version, protocol=version, paths=[path for path, _ in PATHS])
        h3_results = [asyncio.run(h3_request(ports["http3"], ca, path, body, h3_binary, evidence))
                      for path, body in PATHS]
        passed("independent_endpoint_HTTP/3", requests=h3_results)
        for protocol, port in [("h2", ports["https"]), ("h3", ports["http3"])]:
            client = h2_channel(port, ca) if protocol == "h2" else asyncio.run(
                h3_channel(port, ca, h3_channel_binary, evidence))
            deadline = time.monotonic() + 5
            while True:
                sockets = [r for r in receipts if r["event"] == "websocket" and f"unified={protocol}" in r["marker"]]
                if sockets:
                    break
                assert time.monotonic() < deadline, sockets
                time.sleep(0.02)
            assert len(sockets) == 1, sockets
            assert sockets[0]["path"] == "/socket/websocket" and sockets[0]["version"] == ("HTTP/2" if protocol == "h2" else "HTTP/3"), sockets
            assert sockets[0]["protocol"] == "websocket" and sockets[0]["state"] == "upgraded", sockets
            passed("independent_channel_" + protocol, client=client, sockets=sockets)
            stamp = controller.stat().st_mtime
            changed = b"Gaoxy unified reload verified"
            controller.write_bytes(original.replace(b"Gaoxy Phoenix native", changed))
            os.utime(controller, (time.time(), max(time.time(), stamp + 2)))
            if protocol == "h2":
                _, body = h2(port, ca, "/")
                assert changed in body, body
            else:
                asyncio.run(h3_request(port, ca, "/", changed, h3_binary, evidence))
            controller.write_bytes(original)
            os.utime(controller, (time.time(), max(time.time(), stamp + 4)))
            if protocol == "h2":
                _, body = h2(port, ca, "/")
                assert b"Gaoxy Phoenix native" in body, body
            else:
                asyncio.run(h3_request(port, ca, "/", b"Gaoxy Phoenix native", h3_binary, evidence))
            passed("code_reload_and_restore_" + protocol, protocol=client["protocol"])
        server.stdin.write("stop\n")
        server.stdin.flush()
        event("stopped", 12)
        assert server.wait(timeout=5) == 0
        passed("endpoint_shutdown")
        assert controller.read_bytes() == original
        expected = {"independent_endpoint_HTTP/1.1", "independent_endpoint_HTTP/2", "independent_endpoint_HTTP/3",
                    "independent_channel_h2", "independent_channel_h3", "code_reload_and_restore_h2",
                    "code_reload_and_restore_h3", "endpoint_shutdown"}
        assert len(checks) == len(expected) and {row["check"] for row in checks} == expected, checks
        report["status"] = "PASS"
    except Exception as error:
        import traceback
        report.update(error=repr(error), traceback=traceback.format_exc())
    finally:
        if controller.read_bytes() != original:
            controller.write_bytes(original)
        if server.poll() is None:
            try:
                server.stdin.write("stop\n")
                server.stdin.flush()
                server.wait(timeout=8)
            except (subprocess.TimeoutExpired, BrokenPipeError):
                os.killpg(server.pid, signal.SIGKILL)
                server.wait(timeout=3)
        thread.join(timeout=2)
        log.close()
        if thread.is_alive() or server.returncode != 0 or controller.read_bytes() != original:
            report["status"] = "FAIL"
        report.update(checks=checks, receipts=receipts, process_exit=server.returncode, source_restored=controller.read_bytes() == original)
        (evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({k: report[k] for k in ["status", "checks", "process_exit", "source_restored"]} | {"error": report.get("error")}))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
