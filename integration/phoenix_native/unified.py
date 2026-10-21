#!/usr/bin/env python3
"""Real Endpoint-owned H1/H2/H3, native WebSockets and reload composition."""
import asyncio
import base64
import hashlib
import json
import os
from pathlib import Path
import queue
import re
import shutil
import signal
import subprocess
import sys
import threading
import time
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "apps/gaoxy_http/test/support"))
sys.path.insert(0, str(ROOT / "integration/http3"))
from listener_set_peer import h1, h2
from peer import opened
from playwright.sync_api import sync_playwright, expect


async def h3_page(port, ca):
    async with opened(SimpleNamespace(port=port, ca=ca, mode="startup")) as client:
        sid = client.request(path=b"/")
        await client.until(lambda: sid in client.ended or sid in client.resets)
        assert sid not in client.resets, client.resets
        assert dict(client.headers[sid][0])[b":status"] == b"200"
        assert b"Gaoxy Phoenix native" in client.data[sid]
        assert client.negotiated == "h3"


def main():
    evidence = Path(os.environ.get("GAOXY_PHOENIX_EVIDENCE", ROOT / ".audit/unified-phoenix")).resolve()
    evidence.mkdir(parents=True, exist_ok=True)
    certs = evidence / "certs"
    subprocess.run(["bash", str(ROOT / "scripts/generate-fixtures.sh"), str(certs)], check=True, capture_output=True)
    env = dict(os.environ, MIX_ENV="dev", ELIXIR_ERL_OPTIONS="+S 4:4", PHOENIX_NATIVE_H3="1",
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

    report = {"status": "FAIL", "command": command, "baseline": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()}
    try:
        ready = event("ready", 60)
        assert ready["endpoint_server"] and ready["code_reloader"], ready
        ports = ready["ports"]
        ca = str(certs / "ca.pem")
        for request, version in [(h1, "HTTP/1.1"), (h2, "HTTP/2")]:
            for path, body in [("/", b"Gaoxy Phoenix native"), ("/static/hello.txt", b"Gaoxy native static file"), ("/events", b"native")]:
                headers, actual = request(ports["https"], ca, path)
                assert body in actual, (version, path, actual)
                assert [v for k, v in headers if k == b"alt-svc"] == [f'h3=":{ports["http3"]}"; ma=60'.encode()], headers
            passed("independent_endpoint_" + version, paths=["/", "/static/hello.txt", "/events"])
        asyncio.run(h3_page(ports["http3"], ca))
        passed("independent_endpoint_HTTP/3")

        public = subprocess.check_output(["openssl", "x509", "-in", str(certs / "cert.pem"), "-pubkey", "-noout"])
        spki = subprocess.check_output(["openssl", "pkey", "-pubin", "-outform", "DER"], input=public)
        pin = base64.b64encode(hashlib.sha256(spki).digest()).decode()
        with sync_playwright() as playwright:
            for protocol, port, version in [("h2", ports["https"], "HTTP/2"), ("h3", ports["http3"], "HTTP/3")]:
                args = ["--ignore-certificate-errors-spki-list=" + pin]
                args += (["--enable-quic", "--enable-features=EnableWebsocketsOverHttp3", "--host-resolver-rules=MAP localhost 127.0.0.1", f"--origin-to-force-quic-on=localhost:{port}"] if protocol == "h3" else ["--disable-quic"])
                browser = playwright.chromium.launch(executable_path=shutil.which("chromium"), headless=True, args=args)
                try:
                    context = browser.new_context()
                    page = context.new_page()
                    page.set_default_timeout(8000)
                    errors, responses = [], []
                    page.on("pageerror", lambda error: errors.append(str(error)))
                    cdp = page.context.new_cdp_session(page)
                    cdp.on("Network.responseReceived", lambda row: responses.append(row["response"]))
                    cdp.send("Network.enable")
                    marker = '''(() => {const Native = WebSocket; window.WebSocket = class extends Native {constructor(url, protocols) { const marked = new URL(url, location.href); marked.searchParams.set('unified', 'MODE'); super(marked.toString(), ...(protocols === undefined ? [] : [protocols])); } };})();'''.replace("MODE", protocol)
                    page.add_init_script(marker)
                    base = f"https://localhost:{port}"
                    page.goto(base + "/live-counter", wait_until="networkidle", timeout=20000)
                    expect(page.locator("[data-phx-main].phx-connected")).to_be_visible()
                    page.locator("#increment").click()
                    expect(page.locator("#count")).to_have_text("1")
                    assert any(r["url"] == base + "/live-counter" and r["protocol"] == protocol for r in responses), responses
                    # Give each path its own freshly negotiated browser session.
                    # Chromium may otherwise select an H1 fallback for a second
                    # WebSocket despite an existing successful H2 CONNECT.
                    context.close()
                    context = browser.new_context()
                    page = context.new_page()
                    page.set_default_timeout(8000)
                    page.on("pageerror", lambda error: errors.append(str(error)))
                    page.add_init_script(marker)
                    page.goto(base + "/", wait_until="networkidle", timeout=20000)
                    page.add_script_tag(url=base + "/vendor/phoenix/phoenix.min.js")
                    reply = page.evaluate('''() => new Promise((resolve,reject) => {const socket = new Phoenix.Socket('/socket');socket.connect(); const channel=socket.channel('room:unified'); channel.join().receive('ok',()=>channel.push('ping',{unified:true}).receive('ok',reply=>{socket.disconnect();resolve(reply)})).receive('error',reject);setTimeout(()=>reject('channel deadline'),5000)})''')
                    assert reply == {"unified": True}, reply
                    deadline = time.monotonic() + 5
                    while True:
                        sockets = [r for r in receipts if r["event"] == "websocket" and f"unified={protocol}" in r["marker"]]
                        if {r["path"] for r in sockets} >= {"/socket/websocket", "/live/websocket"}:
                            break
                        assert time.monotonic() < deadline, sockets
                        time.sleep(0.02)
                    assert all(r["version"] == version and r["protocol"] == "websocket" and r["state"] == "upgraded" for r in sockets), sockets
                    passed("browser_endpoint_" + protocol, sockets=sockets)
                    stamp = controller.stat().st_mtime
                    controller.write_bytes(original.replace(b"Gaoxy Phoenix native", b"Gaoxy unified reload verified"))
                    os.utime(controller, (time.time(), max(time.time(), stamp + 2)))
                    page.goto(base + "/", wait_until="networkidle")
                    expect(page.locator("#page")).to_have_text("Gaoxy unified reload verified")
                    controller.write_bytes(original)
                    os.utime(controller, (time.time(), max(time.time(), stamp + 4)))
                    page.goto(base + "/", wait_until="networkidle")
                    expect(page.locator("#page")).to_have_text("Gaoxy Phoenix native")
                    assert not errors, errors
                    passed("code_reload_and_restore_" + protocol)
                    page.screenshot(path=str(evidence / (protocol + ".png")))
                finally:
                    browser.close()
        server.stdin.write("stop\n")
        server.stdin.flush()
        event("stopped", 12)
        assert server.wait(timeout=5) == 0
        passed("endpoint_shutdown")
        assert controller.read_bytes() == original
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
        report.update(checks=checks, receipts=receipts, process_exit=server.returncode, source_restored=controller.read_bytes() == original)
        (evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({k: report[k] for k in ["status", "checks", "process_exit", "source_restored"]} | {"error": report.get("error")}))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
