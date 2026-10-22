#!/usr/bin/env python3
"""Independent HTTP/TLS/WebSocket clients, reload and shutdown gate."""
import json
import os
from pathlib import Path
import re
import socket
import ssl
import signal
import subprocess
import time

import h11
import httpx
from websockets.sync.client import connect
from websockets.exceptions import ConnectionClosed

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "examples/phoenix_native"
EVIDENCE = Path(os.environ.get("GAOXY_PHOENIX_EVIDENCE", str(ROOT / ".audit/phoenix-clients"))).resolve()
EVIDENCE.mkdir(parents=True, exist_ok=True)
CERTS = EVIDENCE / "certs"
subprocess.run(["bash", str(ROOT / "scripts/generate-fixtures.sh"), str(CERTS)], check=True, timeout=30)
env = dict(os.environ, MIX_ENV="dev", ELIXIR_ERL_OPTIONS="+S 2:2", PHOENIX_NATIVE_PORT="0",
           PHOENIX_NATIVE_HTTPS_PORT="0", PHOENIX_NATIVE_RELOAD="1",
           PHOENIX_NATIVE_CERTFILE=str(CERTS / "cert.pem"),
           PHOENIX_NATIVE_KEYFILE=str(CERTS / "key.pem"))
ready = '''{:ok, {_, http}} = PhoenixNative.Endpoint.server_info(:http)
{:ok, {_, https}} = PhoenixNative.Endpoint.server_info(:https)
IO.puts("GAOXY_FIXTURE_PORTS=" <> Jason.encode!(%{http: http, https: https}))'''
log_path = EVIDENCE / "server.log"
log = log_path.open("w")
server = subprocess.Popen(["mix", "run", "--no-halt", "-e", ready], cwd=FIXTURE,
                          env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
checks = []
controller = FIXTURE / "lib/phoenix_native/page_controller.ex"
original = controller.read_bytes()


def passed(name, **details):
    checks.append(dict(check=name, status="PASS", **details))
    print(json.dumps(checks[-1]), flush=True)


try:
    deadline = time.monotonic() + 120
    while True:
        match = re.search(r"GAOXY_FIXTURE_PORTS=(\{[^\n]+\})", log_path.read_text())
        if match:
            ports = json.loads(match.group(1))
            break
        if server.poll() is not None or time.monotonic() >= deadline:
            raise RuntimeError("fixture startup failed: " + log_path.read_text()[-6000:])
        time.sleep(0.05)
    base = f"http://127.0.0.1:{ports['http']}"
    tls_base = f"https://127.0.0.1:{ports['https']}"

    # h11 independently parses the server's wire response and message boundary.
    client = h11.Connection(h11.CLIENT)
    with socket.create_connection(("127.0.0.1", ports["http"]), timeout=3) as wire:
        wire.sendall(client.send(h11.Request(method="GET", target="/", headers=[("Host", "localhost"), ("Connection", "close")])))
        wire.sendall(client.send(h11.EndOfMessage()))
        body = bytearray()
        status = None
        while True:
            event = client.next_event()
            if event is h11.NEED_DATA:
                client.receive_data(wire.recv(65536))
            elif isinstance(event, h11.Response):
                status = event.status_code
            elif isinstance(event, h11.Data):
                body.extend(event.data)
            elif isinstance(event, h11.EndOfMessage):
                break
        assert status == 200 and b"Gaoxy Phoenix native" in body
    passed("independent_h11_page", protocol="HTTP/1.1", status_code=status)

    with httpx.Client(timeout=5, trust_env=False) as independent:
        response = independent.get(base + "/")
        assert response.status_code == 200 and response.http_version == "HTTP/1.1"
        assert "Gaoxy Phoenix native" in response.text
        expected_body = response.content
        expected_type = response.headers["content-type"]
    passed("independent_httpx_page", protocol=response.http_version, status_code=response.status_code)
    curled = subprocess.run(["curl", "--noproxy", "*", "--http1.1", "--fail", "--silent",
                             "--show-error", "--max-time", "5", "--dump-header", "-", base + "/"],
                            capture_output=True, timeout=8, check=True)
    curl_headers, curl_body = curled.stdout.split(b"\r\n\r\n", 1)
    assert curl_headers.startswith(b"HTTP/1.1 200 "), curl_headers
    assert curl_body == expected_body, curl_body
    assert b"content-type: " + expected_type.encode() in curl_headers.lower(), curl_headers
    passed("independent_curl_page", protocol="HTTP/1.1", status_code=200)

    trust = ssl.create_default_context(cafile=str(CERTS / "ca.pem"))
    response = httpx.get(tls_base + "/", verify=trust, timeout=5, trust_env=False)
    assert response.status_code == 200 and "Gaoxy Phoenix native" in response.text
    try:
        with socket.create_connection(("127.0.0.1", ports["https"]), timeout=3) as raw:
            trust.wrap_socket(raw, server_hostname="wrong.invalid")
    except ssl.SSLCertVerificationError:
        pass
    else:
        raise AssertionError("wrong TLS hostname was accepted")
    passed("verified_https_and_hostname_rejection", protocol=response.http_version)

    h2_enabled = env.get("PHOENIX_NATIVE_H2") == "1"
    if h2_enabled:
        with httpx.Client(http2=True, verify=trust, timeout=5, trust_env=False) as independent:
            response = independent.get(tls_base + "/")
            assert response.http_version == "HTTP/2" and response.status_code == 200
            assert "Gaoxy Phoenix native" in response.text
        passed("independent_verified_h2_phoenix", protocol=response.http_version, status_code=response.status_code)

    ws_url = f"ws://127.0.0.1:{ports['http']}/socket/websocket?vsn=2.0.0"
    with connect(ws_url, origin=base, compression=None, open_timeout=5) as peer:
        peer.send(json.dumps(["1", "1", "room:test", "phx_join", {}]))
        reply = json.loads(peer.recv(timeout=5))
        assert reply[3] == "phx_reply" and reply[4]["status"] == "ok"
        payload = json.dumps(["1", "2", "room:test", "ping", {"native": True}])
        peer.send([payload[:8], payload[8:]])
        assert json.loads(peer.recv(timeout=5))[4]["response"] == {"native": True}
        pong = peer.ping(b"independent")
        assert pong.wait(3)
    passed("independent_websocket_channel_fragmentation_ping_close")

    with httpx.Client(timeout=5, trust_env=False) as independent:
        response = independent.get(base + "/static/hello.txt")
        assert response.status_code == 200 and response.text.strip() == "Gaoxy native static file"
        passed("independent_static", protocol=response.http_version)
        with independent.stream("GET", base + "/events") as response:
            assert response.status_code == 200
            assert response.headers["content-type"].startswith("text/event-stream")
            assert response.headers["cache-control"] == "no-cache"
            assert list(response.iter_lines()) == ["event: ready", "data: native", ""]
            passed("independent_sse", protocol=response.http_version)

        previous_time = controller.stat().st_mtime
        controller.write_bytes(original.replace(b"Gaoxy Phoenix native", b"Gaoxy Phoenix reload verified"))
        os.utime(controller, (time.time(), max(time.time(), previous_time + 2)))
        response = independent.get(base + "/")
        assert response.status_code == 200 and "Gaoxy Phoenix reload verified" in response.text
        controller.write_bytes(original)
        os.utime(controller, (time.time(), max(time.time(), previous_time + 4)))
        response = independent.get(base + "/")
        assert response.status_code == 200 and "Gaoxy Phoenix native" in response.text
        passed("development_code_reload_and_restore", protocol=response.http_version)

    with connect(ws_url, origin=base, compression=None, open_timeout=5) as peer:
        peer.send(json.dumps(["1", "1", "room:shutdown", "phx_join", {}]))
        assert json.loads(peer.recv(timeout=5))[4]["status"] == "ok"
        os.killpg(server.pid, signal.SIGTERM)
        try:
            peer.recv(timeout=8)
        except ConnectionClosed as closed:
            assert closed.rcvd is not None and closed.rcvd.code in (1001, 1012), repr(closed)
            close_code = closed.rcvd.code
        else:
            raise AssertionError("shutdown did not close peer")
    server.wait(timeout=8)
    assert server.returncode == 0, server.returncode
    for port in ports.values():
        with socket.socket() as probe:
            probe.settimeout(1)
            assert probe.connect_ex(("127.0.0.1", port)) != 0
    passed("graceful_shutdown_and_listener_cleanup", close_code=close_code, process_exit=server.returncode)
finally:
    if controller.read_bytes() != original:
        controller.write_bytes(original)
    if server.poll() is None:
        os.killpg(server.pid, signal.SIGTERM)
        try:
            server.wait(timeout=8)
        except subprocess.TimeoutExpired:
            os.killpg(server.pid, signal.SIGKILL)
            server.wait(timeout=3)
    log.close()
    (EVIDENCE / "results.json").write_text(json.dumps(checks, indent=2) + "\n")
