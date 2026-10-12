#!/usr/bin/env python3
"""Prove a real Phoenix document and static response negotiated HTTP/3."""
import argparse
import base64
import hashlib
import importlib.metadata
import json
from pathlib import Path
import shutil
import subprocess

from playwright.sync_api import sync_playwright


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--cert", type=Path, required=True)
    parser.add_argument("--marker", required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    executable = shutil.which("chromium")
    assert executable, "Chromium executable unavailable"
    version = subprocess.check_output([executable, "--version"], text=True).strip()
    playwright_version = importlib.metadata.version("playwright")
    assert playwright_version == "1.56.0", playwright_version
    public_key = subprocess.check_output([
        "openssl", "x509", "-in", str(args.cert), "-pubkey", "-noout"
    ])
    spki = subprocess.check_output(["openssl", "pkey", "-pubin", "-outform", "DER"], input=public_key)
    pin = base64.b64encode(hashlib.sha256(spki).digest()).decode()
    base = f"https://localhost:{args.port}"
    launch_args = [
        "--enable-quic",
        "--host-resolver-rules=MAP localhost 127.0.0.1",
        f"--origin-to-force-quic-on=localhost:{args.port}",
        f"--ignore-certificate-errors-spki-list={pin}",
        f"--log-net-log={args.evidence / 'chromium-netlog.json'}",
    ]
    observed, errors, sockets, document = [], [], [], {}
    args.evidence.mkdir(parents=True, exist_ok=True)

    def emit(name, **details):
        print("GAOXY_HTTP3_BROWSER " + json.dumps(
            dict(name=name, result="PASS", marker=args.marker, **details)), flush=True)

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=executable, headless=True, args=launch_args)
        try:
            context = browser.new_context(extra_http_headers={"x-gaoxy-m4-browser": args.marker})
            page = context.new_page()
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.on("websocket", lambda socket: sockets.append(socket.url))
            session = context.new_cdp_session(page)
            session.send("Network.enable")

            def received(event):
                response = event["response"]
                if response["url"].startswith(base + "/"):
                    observed.append({key: response.get(key) for key in ("url", "status", "protocol")})

            session.on("Network.responseReceived", received)
            response = page.goto(base + "/", wait_until="networkidle", timeout=15_000)
            assert response and response.status == 200, response
            document.update(title=page.title(), body=response.text())
            # PageController.index serves this fragment directly via html/2.
            expected = ('<h1 id="page">Gaoxy Phoenix native</h1>'
                        '<a href="/live-counter">Live counter</a>'
                        '<p><a href="/static/hello.txt">Static file</a></p>')
            assert document == dict(title="", body=expected), document
            assert page.locator("#page").inner_text() == "Gaoxy Phoenix native"
            assert any(item == dict(url=base + "/", status=200, protocol="h3") for item in observed), observed
            assert not errors, errors
            assert not sockets, sockets
            page.screenshot(path=str(args.evidence / "phoenix-h3.png"), full_page=True)
            emit("browser_h3_phoenix_document", url=base + "/", protocol="h3",
                 chromium=version, playwright=playwright_version, trust="process-local fixture SPKI",
                 origin_mapping=f"localhost:{args.port}", resolver="localhost=127.0.0.1", websockets=0)

            static = page.evaluate("async () => { const r = await fetch('/static/hello.txt'); "
                                   "return {status:r.status, text:await r.text()}; }")
            assert static == dict(status=200, text="Gaoxy native static file\n"), static
            assert any(item == dict(url=base + "/static/hello.txt", status=200, protocol="h3")
                       for item in observed), observed
            assert not errors, errors
            emit("browser_h3_phoenix_static", url=base + "/static/hello.txt", protocol="h3",
                 bytes=len(static["text"].encode()))
            context.close()
        finally:
            browser.close()
            (args.evidence / "browser-observed.json").write_text(json.dumps({
                "responses": observed, "page_errors": errors, "websockets": sockets,
                "chromium": version, "playwright": playwright_version,
                "marker": args.marker, "launch_args": launch_args,
                "document": document,
            }, indent=2) + "\n")


if __name__ == "__main__":
    main()
