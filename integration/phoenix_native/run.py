#!/usr/bin/env python3
"""Real Chromium, independent HTTP/TLS/WebSocket, reload and shutdown gate."""
import json
import os
from pathlib import Path
import re
import shutil
import socket
import ssl
import subprocess
import time

import h11
import httpx
from playwright.sync_api import sync_playwright, expect
from websockets.sync.client import connect
from websockets.exceptions import ConnectionClosed

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "examples/phoenix_native"
EVIDENCE = ROOT / ".audit/m2-browser"
EVIDENCE.mkdir(parents=True, exist_ok=True)
CERTS = EVIDENCE / "certs"
subprocess.run(["bash", str(ROOT / "scripts/generate-fixtures.sh"), str(CERTS)], check=True)
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
                          env=env, stdout=log, stderr=subprocess.STDOUT)
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
    passed("independent_h11_page")

    trust = ssl.create_default_context(cafile=str(CERTS / "ca.pem"))
    response = httpx.get(tls_base + "/", verify=trust, timeout=5)
    assert response.status_code == 200 and "Gaoxy Phoenix native" in response.text
    try:
        with socket.create_connection(("127.0.0.1", ports["https"]), timeout=3) as raw:
            trust.wrap_socket(raw, server_hostname="wrong.invalid")
    except ssl.SSLCertVerificationError:
        pass
    else:
        raise AssertionError("wrong TLS hostname was accepted")
    passed("verified_https_and_hostname_rejection")

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

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=shutil.which("chromium"), headless=True)
        page = browser.new_page()
        errors = []
        sockets = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("websocket", lambda ws: sockets.append(ws.url))
        page.goto(base + "/", wait_until="networkidle")
        expect(page.locator("#page")).to_have_text("Gaoxy Phoenix native")
        passed("browser_page")
        assert page.request.get(base + "/static/hello.txt").text().strip() == "Gaoxy native static file"
        passed("browser_static")

        page.goto(base + "/live-counter", wait_until="networkidle")
        expect(page.locator("#count")).to_have_text("0")
        page.locator("#increment").click()
        expect(page.locator("#count")).to_have_text("1")
        assert any("/live/websocket" in url for url in sockets)
        passed("browser_liveview_click")
        page.locator("input[type=file]").set_input_files({"name": "native.txt", "mimeType": "text/plain", "buffer": b"native upload proof"})
        page.get_by_role("button", name="Upload", exact=True).click()
        expect(page.locator("#uploaded")).to_have_text("native.txt:19", timeout=15000)
        passed("browser_liveview_upload")

        channel = page.evaluate('''() => new Promise((resolve, reject) => {
          const socket = new Phoenix.Socket('/socket'); socket.connect();
          const channel = socket.channel('room:browser');
          channel.join().receive('ok', () => channel.push('ping', {browser: true})
            .receive('ok', reply => { socket.disconnect(); resolve(reply); })
            .receive('error', reject)).receive('error', reject);
          setTimeout(() => reject('channel timeout'), 5000);
        })''')
        assert channel == {"browser": True}
        passed("browser_channel")
        event = page.evaluate('''() => new Promise((resolve, reject) => {
          const events = new EventSource('/events');
          events.addEventListener('ready', event => { events.close(); resolve(event.data); });
          events.onerror = () => { events.close(); reject('SSE failed'); };
          setTimeout(() => { events.close(); reject('SSE timeout'); }, 5000);
        })''')
        assert event == "native"
        passed("browser_sse")

        page.evaluate("() => new Promise(resolve => liveSocket.disconnect(() => {liveSocket.connect(); resolve();}))")
        page.wait_for_function("document.querySelector('[data-phx-main]').classList.contains('phx-connected')")
        expect(page.locator("#count")).to_have_text("0")
        page.locator("#increment").click()
        expect(page.locator("#count")).to_have_text("1")
        passed("browser_liveview_reconnect")
        page.screenshot(path=str(EVIDENCE / "liveview.png"), full_page=False)

        previous_time = controller.stat().st_mtime
        controller.write_bytes(original.replace(b"Gaoxy Phoenix native", b"Gaoxy Phoenix reload verified"))
        os.utime(controller, (time.time(), max(time.time(), previous_time + 2)))
        response = page.request.get(base + "/")
        assert response.status == 200 and "Gaoxy Phoenix reload verified" in response.text()
        controller.write_bytes(original)
        os.utime(controller, (time.time(), max(time.time(), previous_time + 4)))
        assert "Gaoxy Phoenix native" in page.request.get(base + "/").text()
        passed("development_code_reload_and_restore")
        assert not errors, errors
        passed("browser_no_page_errors", websockets=len(sockets))
        browser.close()

    with connect(ws_url, origin=base, compression=None, open_timeout=5) as peer:
        peer.send(json.dumps(["1", "1", "room:shutdown", "phx_join", {}]))
        assert json.loads(peer.recv(timeout=5))[4]["status"] == "ok"
        server.terminate()
        try:
            peer.recv(timeout=8)
        except ConnectionClosed as closed:
            assert closed.rcvd is not None and closed.rcvd.code in (1001, 1012), repr(closed)
            close_code = closed.rcvd.code
        else:
            raise AssertionError("shutdown did not close peer")
    server.wait(timeout=8)
    for port in ports.values():
        with socket.socket() as probe:
            probe.settimeout(1)
            assert probe.connect_ex(("127.0.0.1", port)) != 0
    passed("graceful_shutdown_and_listener_cleanup", close_code=close_code, process_exit=server.returncode)
finally:
    if controller.read_bytes() != original:
        controller.write_bytes(original)
    if server.poll() is None:
        server.terminate()
        try:
            server.wait(timeout=8)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait(timeout=3)
    log.close()
    (EVIDENCE / "results.json").write_text(json.dumps(checks, indent=2) + "\n")
