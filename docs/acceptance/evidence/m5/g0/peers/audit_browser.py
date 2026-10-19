"""Launch/configuration audit; no WebSocket transport claim."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

out = Path(__file__).parent
args = ["--enable-quic", "--enable-features=EnableWebsocketsOverHttp3"]
with sync_playwright() as playwright:
    browser = playwright.chromium.launch(
        executable_path="/run/current-system/sw/bin/chromium", headless=True,
        args=args, timeout=20000,
    )
    try:
        page = browser.new_page()
        page.goto("about:blank")
        cdp = page.context.new_cdp_session(page)
        version = cdp.send("Browser.getVersion")
        command = cdp.send("Browser.getBrowserCommandLine")
        record = {
            "scope": "headless launch and feature command line only",
            "executable": "/run/current-system/sw/bin/chromium",
            "version": version, "requested_args": args, "actual_command": command,
            "page": page.url, "exit": 0,
            "h2_websocket_transport": "NOT RUN",
            "h3_websocket_transport": "NOT RUN",
            "note": "accepted --enable-features names do not establish feature support or negotiation",
        }
        (out / "browser-audit.json").write_text(json.dumps(record, indent=2) + "\n")
        print(json.dumps(record, indent=2))
    finally:
        browser.close()
