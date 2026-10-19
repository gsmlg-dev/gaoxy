#!/usr/bin/env python3
"""Real Phoenix browser flows with WebSocket-specific native transport receipts."""
import argparse
import base64
import datetime
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import queue
import shutil
import signal
import subprocess
import sys
import threading
import time
import traceback
import uuid

ROOT = Path(__file__).resolve().parents[2]
PHOENIX = ROOT / "examples/phoenix_native"
PREFIX = "GAOXY_M5_BROWSER "
REQUIRED_CASES = (
    "browser-page", "liveview-mount", "liveview-click", "liveview-upload",
    "channels-join", "channels-ping", "channels-pubsub-push", "websocket-transport",
    "origin-policy-rejection", "normal-websocket-close", "admission-release", "fixture-shutdown",
)


class TransportMismatch(AssertionError):
    pass


def validate_cases(cases):
    names = [row["name"] for row in cases]
    assert names and len(names) == len(set(names)), "zero or duplicate browser cases"
    assert set(names) == set(REQUIRED_CASES), ("missing browser cases", names)
    assert all(row["status"] == "PASS" for row in cases), cases


def chromium_arguments(protocol, port, pin):
    arguments = ["--ignore-certificate-errors-spki-list=" + pin]
    if protocol == "h3":
        arguments += ["--enable-quic", "--enable-features=EnableWebsocketsOverHttp3",
                      "--host-resolver-rules=MAP localhost 127.0.0.1",
                      f"--origin-to-force-quic-on=localhost:{port}"]
    else:
        arguments += ["--disable-quic"]
        if protocol == "http1":
            arguments += ["--disable-http2"]
    return arguments


def marker_script(run_marker):
    return """(() => {
      const NativeWebSocket = window.WebSocket;
      const runMarker = RUN_MARKER;
      window.__m5Sockets = [];
      const pageMarker = Math.random().toString(36).slice(2);
      let sequence = 0;
      window.WebSocket = class extends NativeWebSocket {
        constructor(url, protocols) {
          const marked = new URL(url, window.location.href);
          const marker = runMarker + '-' + pageMarker + '-' + (++sequence);
          marked.searchParams.set('m5_ws', marker);
          if (protocols === undefined) { super(marked.toString()); }
          else { super(marked.toString(), protocols); }
          const row = {marker, url: marked.toString(), path: marked.pathname,
                       opened: false, closed: false, closeCode: null, error: false, socket: this};
          window.__m5Sockets.push(row);
          this.addEventListener('open', () => { row.opened = true; });
          this.addEventListener('error', () => { row.error = true; });
          this.addEventListener('close', event => {
            row.closed = true; row.closeCode = event.code; row.clean = event.wasClean;
          });
        }
      };
    })();""".replace("RUN_MARKER", json.dumps(run_marker))


def correlate_websockets(protocol, clients, events):
    opened = [row for row in clients if row["opened"]]
    assert opened, "no successful browser WebSocket"
    assert {row["path"] for row in opened} >= {"/socket/websocket", "/live/websocket"}, opened
    assert len({row["marker"] for row in opened}) == len(opened), opened
    version = {"http1": "HTTP/1.1", "h2": "HTTP/2", "h3": "HTTP/3"}[protocol]
    correlated = []
    for client in opened:
        matches = [row for row in events if row["event"] == "websocket-upgrade"
                   and row.get("marker") == client["marker"]]
        assert len(matches) == 1, ("missing/duplicate native WebSocket receipt", client, matches)
        native, = matches
        if native["version"] != version:
            raise TransportMismatch(f"requested {version}, observed {native['version']} for {client['url']}")
        if protocol in ("h2", "h3"):
            assert native["method"] == "CONNECT" and native["protocol"] == "websocket", native
            assert isinstance(native["stream"], int), native
        else:
            assert native["method"] == "GET" and native["protocol"] is None, native
        assert native["connection"] and native["stream"] is not None, native
        correlated.append({"client": client, "native": native})
    return correlated



def validate_origin_rejection(client, events):
    assert client.get("marker") and not client["opened"] and client["error"], client
    matches = [row for row in events if row.get("marker") == client["marker"]
               and row["event"] in ("websocket-upgrade", "websocket-refusal", "websocket-error")]
    assert len(matches) == 1, ("missing/duplicate Origin refusal receipt", client, matches)
    native, = matches
    assert native["event"] == "websocket-refusal" and native["status"] == 403, native
    assert native["origin"] == ["null"], native
    return native


def native_upgrade_errors(events, expected_origin_markers):
    return [row for row in events if row["event"] in ("websocket-refusal", "websocket-error")
            and not (row["event"] == "websocket-refusal" and row.get("status") == 403
                     and row.get("origin") == ["null"]
                     and row.get("marker") in expected_origin_markers)]


def failure_status(report):
    if (report.get("transport_mismatch") and report.get("native_peer_qualified")
            and not report.get("native_upgrade_errors")):
        return "BLOCKED_ENV"
    return "FAIL"


def native_peer_qualification(path, protocol):
    if path is None:
        return None
    report = json.loads(path.read_text())
    cases = report.get("cases", [])
    assert report["status"] == "PASS" and report["protocol"] == protocol, "native peer report is not a passing selected profile"
    assert report.get("executed", 0) >= 15 and cases and all(row["status"] == "PASS" for row in cases), report
    return {"path": str(path.resolve()), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "protocol": protocol, "source": report.get("source"), "executed": report["executed"]}


def command_output(command, **options):
    return subprocess.check_output(command, timeout=15, **options)


class BrowserFixture:
    def __init__(self, protocol, evidence, certificate, key):
        self.events, self.all_events = queue.Queue(), []
        self.log = (evidence / "fixture.log").open("w")
        self.command = ["unbuffer", "-p", "mix", "run", "--no-start", "--no-compile",
                        str(ROOT / "integration/websocket_multiplexed/browser_fixture.exs")]
        environment = dict(os.environ, MIX_ENV="dev", ERL_FLAGS="+S 2:2", PHOENIX_NATIVE_M5="1",
                           PHOENIX_NATIVE_H3="1",
                           GAOXY_M5_BROWSER_PROTOCOL=protocol, GAOXY_M5_CERT=str(certificate), GAOXY_M5_KEY=str(key))
        self.process = subprocess.Popen(self.command, cwd=PHOENIX, env=environment, stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                        text=True, bufsize=1, start_new_session=True)

        def read_output():
            for line in self.process.stdout:
                self.log.write(line)
                self.log.flush()
                marker = line.find(PREFIX)
                if marker >= 0:
                    try:
                        event = json.loads(line[marker + len(PREFIX):])
                    except json.JSONDecodeError:
                        continue
                    self.all_events.append(event)
                    self.events.put(event)

        self.reader = threading.Thread(target=read_output, daemon=True)
        self.reader.start()

    def event(self, name, timeout):
        deadline = time.monotonic() + timeout
        while True:
            remaining = deadline - time.monotonic()
            assert remaining > 0, ("browser fixture event deadline", name, self.process.poll())
            event = self.events.get(timeout=remaining)
            if event["event"] == name:
                return event

    def control(self, command, name, timeout=5):
        self.process.stdin.write(json.dumps(command) + "\n")
        self.process.stdin.flush()
        return self.event(name, timeout)

    def released(self):
        deadline = time.monotonic() + 5
        while True:
            sample = self.control({"command": "sample"}, "sample")
            if all(row["active"] == row["retained_bytes"] == row["cleanup_pending"] == 0
                   and row["cleanup_failed"] is None for row in sample["admission"]):
                assert sample["admission"], sample
                return sample
            assert time.monotonic() < deadline, sample
            time.sleep(0.02)

    def stop(self):
        stopped = None
        try:
            if self.process.poll() is None:
                stopped = self.control({"command": "stop"}, "stopped", timeout=12)
            code = self.process.wait(timeout=3)
            assert code == 0 and stopped and stopped["runtime_down"], (code, stopped)
            return {"exit": code, **stopped}
        finally:
            if self.process.poll() is None:
                os.killpg(self.process.pid, signal.SIGTERM)
                try:
                    self.process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    os.killpg(self.process.pid, signal.SIGKILL)
                    self.process.wait(timeout=3)
            self.reader.join(timeout=2)
            self.log.close()


def socket_records(page):
    return page.evaluate("() => window.__m5Sockets.map(({socket, ...row}) => row)")


def disconnect_websockets(page):
    page.evaluate("""() => Promise.race([
      Promise.all([
        window.__m5Channel ? new Promise(resolve => window.__m5Channel.socket.disconnect(resolve, 1000, 'M5 normal Close')) : Promise.resolve(),
        window.liveSocket ? new Promise(resolve => window.liveSocket.getSocket().disconnect(() => window.liveSocket.disconnect(resolve), 1000, 'M5 normal Close')) : Promise.resolve()
      ]),
      new Promise((_, reject) => setTimeout(() => reject('normal WebSocket disconnect deadline'), 5000))
    ])""")



def origin_policy_rejection(page, fixture, port):
    # A local parent preserves the browser's local address-space context, while
    # allow-scripts without allow-same-origin gives the child an opaque Origin.
    page.evaluate("""() => {
      const frame = document.createElement('iframe');
      frame.id = 'm5-origin-policy';
      frame.setAttribute('sandbox', 'allow-scripts');
      frame.srcdoc = '<!doctype html><title>M5 opaque Origin</title>';
      document.body.append(frame);
    }""")
    element = page.wait_for_selector("#m5-origin-policy")
    frame = element.content_frame()
    assert frame is not None, "opaque-origin iframe missing"
    try:
        frame.wait_for_function("() => Array.isArray(window.__m5Sockets)")
        origin = frame.evaluate("location.origin")
        assert origin == "null", origin
        # A normal HTTP fetch establishes the selected transport in the opaque
        # frame's connection partition before Chromium attempts its WebSocket.
        warmup = frame.evaluate("""url => Promise.race([
          fetch(url, {mode: 'no-cors', credentials: 'omit', cache: 'no-store'})
            .then(response => ({type: response.type, status: response.status})),
          new Promise((_, reject) => setTimeout(() => reject('Origin warmup deadline'), 5000))
        ])""", f"https://localhost:{port}/")
        outcome = frame.evaluate("""url => new Promise((resolve, reject) => {
          const socket = new WebSocket(url);
          socket.addEventListener('open', () => resolve('open'));
          socket.addEventListener('error', () => resolve('error'));
          setTimeout(() => reject('Origin policy WebSocket deadline'), 5000);
        })""", f"wss://localhost:{port}/socket/websocket?vsn=2.0.0")
        clients = socket_records(frame)
        assert outcome == "error" and len(clients) == 1, (outcome, clients)
        client, = clients
        deadline = time.monotonic() + 5
        while not any(row.get("marker") == client["marker"] for row in fixture.all_events):
            assert time.monotonic() < deadline, ("Origin refusal native receipt deadline", client)
            time.sleep(0.02)
        native = validate_origin_rejection(client, fixture.all_events)
        return {"page_origin": origin, "sandbox": "allow-scripts", "warmup": warmup,
                "client": client, "native": native}
    finally:
        element.evaluate("element => element.remove()")


def execute_browser(args, fixture, ready, evidence, certificate, report, passed):
    from playwright.sync_api import sync_playwright, expect

    public_key = command_output(["openssl", "x509", "-in", str(certificate), "-pubkey", "-noout"])
    spki = command_output(["openssl", "pkey", "-pubin", "-outform", "DER"], input=public_key)
    pin = base64.b64encode(hashlib.sha256(spki).digest()).decode()
    report["chromium_args"] = chromium_arguments(args.protocol, ready["port"], pin)
    report["chromium_args"].append("--log-net-log=" + str(evidence / "netlog.json"))
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=args.chromium, headless=True,
                                             args=report["chromium_args"], timeout=20000)
        context = browser.new_context()
        context.add_init_script(marker_script(report["run_marker"]))
        page = context.new_page()
        page.set_default_timeout(8000)
        report["page_errors"], report["console"], report["browser_websocket_urls"] = [], [], []
        page.on("pageerror", lambda error: report["page_errors"].append(str(error)))
        page.on("console", lambda message: report["console"].append({"type": message.type, "text": message.text}))
        page.on("websocket", lambda ws: report["browser_websocket_urls"].append(ws.url))
        cdp = context.new_cdp_session(page)
        report["browser_version"] = cdp.send("Browser.getVersion")
        report["browser_command"] = cdp.send("Browser.getBrowserCommandLine")
        report["http_responses"] = []
        cdp.on("Network.responseReceived", lambda event: report["http_responses"].append({
            "url": event["response"]["url"], "protocol": event["response"]["protocol"],
            "status": event["response"]["status"],
        }))
        cdp.send("Network.enable")
        try:
            base = f"https://localhost:{ready['port']}"
            startup = page.goto(base + "/", wait_until="networkidle", timeout=15000)
            assert startup is not None and startup.status == 200, "startup HTTPS navigation failed"
            report["startup_navigation"] = {"url": startup.url, "status": startup.status}
            page.goto(base + "/live-counter", wait_until="networkidle", timeout=15000)
            expect(page.get_by_role("heading", name="Live counter")).to_be_visible()
            passed("browser-page")
            page.wait_for_function("document.querySelector('[data-phx-main]').classList.contains('phx-connected')")
            expect(page.locator("#count")).to_have_text("0")
            passed("liveview-mount")
            page.locator("#increment").click()
            expect(page.locator("#count")).to_have_text("1")
            passed("liveview-click")
            payload = b"M5 native upload proof"
            page.locator("input[type=file]").set_input_files({
                "name": "m5-native.txt", "mimeType": "text/plain", "buffer": payload,
            })
            page.get_by_role("button", name="Upload", exact=True).click()
            expect(page.locator("#uploaded")).to_have_text(f"m5-native.txt:{len(payload)}")
            passed("liveview-upload", bytes=len(payload))
            topic = "room:m5-" + report["run_marker"]
            page.evaluate("""topic => new Promise((resolve, reject) => {
              const socket = new Phoenix.Socket('/socket');
              const channel = socket.channel(topic);
              window.__m5Channel = {socket, channel, pushes: []};
              channel.on('m5_push', payload => window.__m5Channel.pushes.push(payload));
              socket.connect();
              channel.join().receive('ok', resolve).receive('error', reject).receive('timeout', reject);
              setTimeout(() => reject('channel join timeout'), 5000);
            })""", topic)
            passed("channels-join", topic=topic)
            reply = page.evaluate("""marker => new Promise((resolve, reject) => {
              window.__m5Channel.channel.push('ping', {marker})
                .receive('ok', resolve).receive('error', reject).receive('timeout', reject);
              setTimeout(() => reject('channel ping timeout'), 5000);
            })""", report["run_marker"])
            assert reply == {"marker": report["run_marker"]}, reply
            passed("channels-ping")
            report["broadcast"] = fixture.control({"command": "broadcast", "topic": topic,
                                                   "marker": report["run_marker"]}, "broadcast")
            page.wait_for_function("marker => window.__m5Channel.pushes.some(row => row.marker === marker)",
                                   arg=report["run_marker"])
            passed("channels-pubsub-push")
            assert not report["page_errors"], report["page_errors"]
            if args.protocol == "h3":
                report["h3_websockets_before_policy_fallback"] = correlate_websockets(
                    args.protocol, socket_records(page), fixture.all_events)
                report["policy_fallback"] = fixture.control(
                    {"command": "enable-policy-fallback"}, "policy-fallback-ready")
            report["origin_rejection"] = origin_policy_rejection(page, fixture, ready["port"])
            report["expected_origin_markers"] = [report["origin_rejection"]["client"]["marker"]]
            passed("origin-policy-rejection", status_code=403,
                   actual_protocol=report["origin_rejection"]["native"]["version"])
            report["client_websockets"] = socket_records(page)
            report["correlated_websockets"] = correlate_websockets(args.protocol, report["client_websockets"], fixture.all_events)
            passed("websocket-transport", count=len(report["correlated_websockets"]), actual_protocol=args.protocol)
            disconnect_websockets(page)
            page.wait_for_function("() => window.__m5Sockets.filter(row => row.opened).every(row => row.closed)")
            closed = socket_records(page)
            assert all(row["closeCode"] == 1000 and row.get("clean") for row in closed if row["opened"]), closed
            report["closed_websockets"] = closed
            passed("normal-websocket-close", count=len(closed), code=1000)
            page.screenshot(path=str(evidence / "liveview.png"), full_page=True)
        finally:
            try:
                if "closed_websockets" not in report:
                    try:
                        disconnect_websockets(page)
                        report["cleanup_disconnect_requested"] = True
                    except Exception as error:
                        report["cleanup_disconnect_error"] = repr(error)
                report["client_websockets_final"] = socket_records(page)
                page.screenshot(path=str(evidence / "final.png"), full_page=True, timeout=5000)
                (evidence / "page.html").write_text(page.content())
            finally:
                context.close()
                browser.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--protocol", choices=["h2", "h3", "http1"], required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--native-peer-report", type=Path)
    parser.add_argument("--chromium", default=shutil.which("chromium"))
    args = parser.parse_args()
    evidence = args.evidence.resolve() / f"run-{time.time_ns()}"
    evidence.mkdir(parents=True)
    paths = sorted(ROOT.glob("apps/*/lib/**/*.ex")) + sorted(PHOENIX.glob("lib/**/*.ex"))
    paths += list((ROOT / "integration/websocket_multiplexed").glob("*"))
    paths += sorted((ROOT / "vendor/websock_adapter").glob("lib/**/*.ex"))
    paths += [ROOT / "vendor/websock_adapter/SOURCE.json", ROOT / "vendor/websock_adapter/gaoxy.patch",
              PHOENIX / "config/config.exs", PHOENIX / "priv/static/app.js"]
    paths += [ROOT / "mix.lock", PHOENIX / "mix.lock", ROOT / "flake.lock"]
    report = {
        "status": "FAIL", "protocol": args.protocol, "run_marker": uuid.uuid4().hex, "cases": [],
        "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "command": [sys.executable, *sys.argv], "chromium_executable": args.chromium,
        "source": {"head": command_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip(),
                   "status": command_output(["git", "status", "--porcelain"], cwd=ROOT).decode(),
                   "diff_sha256": hashlib.sha256(command_output(["git", "diff", "--binary", "HEAD"], cwd=ROOT)).hexdigest(),
                   "files_sha256": {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                                    for path in paths if path.is_file()}},
        "environment": {"python": sys.version, "MIX_ENV": "dev", "ERL_FLAGS": "+S 2:2",
                        "PHOENIX_NATIVE_M5": "1", "PHOENIX_NATIVE_H3": "1"},
        "peer_versions": {name: importlib.metadata.version(name) for name in ["playwright", "h2", "aioquic", "wsproto"]},
    }

    def passed(name, **detail):
        report["cases"].append({"name": name, "status": "PASS", **detail})

    fixture = None
    try:
        report["native_peer"] = native_peer_qualification(args.native_peer_report, args.protocol)
        report["native_peer_qualified"] = report["native_peer"] is not None
        certificate, key = evidence / "cert.pem", evidence / "key.pem"
        command = ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "2",
                   "-keyout", str(key), "-out", str(certificate), "-subj", "/CN=localhost",
                   "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1",
                   "-addext", "basicConstraints=critical,CA:TRUE"]
        generated = subprocess.run(command, text=True, capture_output=True, timeout=15)
        report["certificate_command"] = command
        (evidence / "certificate-generation.log").write_text(generated.stdout + generated.stderr)
        assert generated.returncode == 0, generated.stderr
        fixture = BrowserFixture(args.protocol, evidence, certificate, key)
        report["fixture_command"] = fixture.command
        report["fixture_cwd"] = str(PHOENIX)
        ready = fixture.event("ready", timeout=30)
        report["fixture_ready"] = ready
        assert ready["protocol"] == args.protocol, ready
        execute_browser(args, fixture, ready, evidence, certificate, report, passed)
        report["admission_released"] = fixture.released()
        passed("admission-release")
        report["shutdown"] = fixture.stop()
        passed("fixture-shutdown")
        validate_cases(report["cases"])
        report["status"] = "PASS"
    except Exception as error:
        report["error"], report["traceback"] = repr(error), traceback.format_exc()
        report["transport_mismatch"] = isinstance(error, TransportMismatch)
        report["native_upgrade_errors"] = native_upgrade_errors(
            fixture.all_events if fixture else [], report.get("expected_origin_markers", []))
        report["status"] = failure_status(report)
    finally:
        if fixture is not None:
            if "shutdown" not in report:
                try:
                    report["shutdown"] = fixture.stop()
                except Exception as error:
                    report["shutdown_error"] = repr(error)
                    report["status"] = "FAIL"
            (evidence / "fixture-events.json").write_text(json.dumps(fixture.all_events, indent=2) + "\n")
        executed = {row["name"] for row in report["cases"]}
        report["executed"], report["required"] = len(executed), len(REQUIRED_CASES)
        report["case_results"] = [next((row for row in report["cases"] if row["name"] == name),
                                      {"name": name, "status": "NOT RUN"}) for name in REQUIRED_CASES]
        report["exit"] = 0 if report["status"] == "PASS" else 1
        (evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({"status": report["status"], "executed": report["executed"],
                          "required": report["required"], "evidence": str(evidence), "error": report.get("error")}))
    return report["exit"]


if __name__ == "__main__":
    raise SystemExit(main())
