#!/usr/bin/env python3
"""Run only the ordinary native multiplexed WebSocket profiles selected here."""
import argparse
import base64
import datetime
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import queue
import re
import signal
import ssl
import subprocess
import sys
import threading
import time
import traceback

from h2_peer import REQUIRED_CASES, run, validate_results

ROOT = Path(__file__).resolve().parents[2]
PREFIX = "GAOXY_M5_FIXTURE "


def capture(command):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=15)
    assert result.returncode == 0, (command, result.stderr)
    return result.stdout


def source_receipt(release=None, source_identity=None):
    if release is not None:
        identity_bytes = source_identity.read_bytes()
        identity = json.loads(identity_bytes)
        assert re.fullmatch(r"[0-9a-f]{40}", identity["source_sha"])
        for field in ("source_archive_sha256", "root_lock_sha256"):
            assert re.fullmatch(r"[0-9a-f]{64}", identity[field]), field
        version = capture([str(release), "version"]).strip()
        assert version == f"gaoxy {identity['version']}", version
        return {
            "mode": "packaged_release", "identity": identity,
            "source_identity_sha256": hashlib.sha256(identity_bytes).hexdigest(),
            "release": {"path": str(release), "version": version,
                        "sha256": hashlib.sha256(release.read_bytes()).hexdigest()},
        }
    paths = sorted(ROOT.glob("apps/*/lib/**/*.ex"))
    paths += sorted((ROOT / "integration/websocket_multiplexed").glob("*"))
    paths += [ROOT / "mix.lock", ROOT / "flake.lock", ROOT / "examples/phoenix_native/mix.lock"]
    return {
        "head": capture(["git", "rev-parse", "HEAD"]).strip(),
        "branch": capture(["git", "branch", "--show-current"]).strip(),
        "status": capture(["git", "status", "--porcelain"]),
        "diff_sha256": hashlib.sha256(capture(["git", "diff", "--binary", "HEAD"]).encode()).hexdigest(),
        "files_sha256": {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                         for path in paths if path.is_file()},
    }


class Fixture:
    def __init__(self, protocol, evidence, certificate, key, release=None):
        self.events, self.all_events = queue.Queue(), []
        self.log = (evidence / "fixture.log").open("w")
        self.command = ["unbuffer", "-p", "mix", "run", "--no-compile", "integration/websocket_multiplexed/fixture.exs"]
        if release is not None:
            fixture = base64.b64encode(str(ROOT / "integration/websocket_multiplexed/fixture.exs").encode()).decode()
            expression = ('{:ok, _} = Application.ensure_all_started(:gaoxy_http3); '
                          f'Code.require_file(Base.decode64!("{fixture}"))')
            self.command = [str(release), "eval", expression]
        environment = dict(os.environ, MIX_ENV="test", ERL_FLAGS="+S 2:2",
                           GAOXY_M5_PROTOCOL=protocol, GAOXY_M5_CERT=str(certificate), GAOXY_M5_KEY=str(key))
        self.process = subprocess.Popen(self.command, cwd=ROOT, env=environment, stdin=subprocess.PIPE,
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
            assert remaining > 0, ("fixture event deadline", name, self.process.poll())
            event = self.events.get(timeout=remaining)
            if event["event"] == name:
                return event

    def control(self, command, event, timeout=3):
        self.process.stdin.write(command + "\n")
        self.process.stdin.flush()
        return self.event(event, timeout)

    def released(self):
        deadline = time.monotonic() + 3
        while True:
            status = self.control("sample", "sample")
            if (status["active"] == status["retained_bytes"] == status["cleanup_pending"] == 0
                    and status["cleanup_failed"] is None):
                return status
            assert time.monotonic() < deadline, status
            time.sleep(0.01)

    def stop(self):
        stopped = None
        try:
            if self.process.poll() is None:
                stopped = self.control("stop", "stopped", timeout=12)
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


def validate_server_receipts(events, protocol="h2"):
    opens = [event for event in events if event["event"] == "websocket-open"]
    assert len(opens) == 2, opens
    assert len({event["connection"] for event in opens}) == 1, opens
    assert len({event["stream"] for event in opens}) == 2, opens
    for event in opens:
        assert event["method"] == "CONNECT" and event["protocol"] == "websocket", event
        assert event["version"] == ("HTTP/3" if protocol == "h3" else "HTTP/2"), event
        assert event["requested_websocket_deadline"] == event["accepted_websocket_deadline"], event
        assert event["accepted_websocket_deadline"] > event["original_deadline"], event
    siblings = [event for event in events if event["event"] == "http-request"]
    assert {event["path"] for event in siblings} == {"/sibling", "/after-close"}, siblings
    assert all(event["connection"] == opens[0]["connection"] for event in siblings), siblings
    terminated = [event for event in events if event["event"] == "websocket-terminated"]
    assert {event["label"] for event in terminated} == {"one", "two"}, terminated
    assert len(terminated) == 2, terminated
    lifetime = [event for event in events if event["event"] == "post-deadline-message"]
    assert len(lifetime) == 1, lifetime
    opened = next(event for event in opens if event["stream"] == lifetime[0]["stream"])
    assert lifetime[0]["original_deadline"] == opened["original_deadline"], lifetime
    assert opened["original_deadline"] < lifetime[0]["observed_at"] < opened["accepted_websocket_deadline"], lifetime
    return {"websocket_opens": opens, "http_siblings": siblings, "terminated": terminated,
            "post_deadline_message": lifetime[0]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--protocol", choices=["h2", "h2c", "h3"], required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--release", type=Path)
    parser.add_argument("--source-identity", type=Path)
    args = parser.parse_args()
    if (args.release is None) != (args.source_identity is None):
        parser.error("--release and --source-identity must be supplied together")
    if args.release is not None:
        args.release = args.release.resolve()
        args.source_identity = args.source_identity.resolve()
        if not args.release.is_file() or not os.access(args.release, os.X_OK):
            parser.error("--release must name an executable release bin/gaoxy")
        if not args.source_identity.is_file():
            parser.error("--source-identity must name the qualified source identity JSON")
    evidence = args.evidence.resolve() / f"run-{time.time_ns()}"
    evidence.mkdir(parents=True)
    report = {
        "status": "FAIL", "protocol": args.protocol, "required_cases": list(REQUIRED_CASES),
        "cases": [], "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "runner_command": [sys.executable, *sys.argv], "source": source_receipt(args.release, args.source_identity),
        "environment": {"python": sys.version, "executable": sys.executable, "openssl": ssl.OPENSSL_VERSION,
                        "MIX_ENV": "test", "ERL_FLAGS": "+S 2:2"},
        "peer_versions": {name: importlib.metadata.version(name) for name in
                          ["h2", "hpack", "hyperframe", "aioquic", "wsproto", "playwright"]},
        "scope": "ordinary protocol/multiplexing/Close only; no specialist fault or load cases",
    }
    fixture = None
    try:
        certificate, key = evidence / "cert.pem", evidence / "key.pem"
        command = ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "2",
                   "-keyout", str(key), "-out", str(certificate), "-subj", "/CN=localhost",
                   "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1",
                   "-addext", "basicConstraints=critical,CA:TRUE"]
        generated = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=15)
        (evidence / "certificate-generation.log").write_text(generated.stdout + generated.stderr)
        report["certificate_command"] = command
        assert generated.returncode == 0, generated.stderr
        fixture = Fixture(args.protocol, evidence, certificate, key, args.release)
        report["fixture_command"] = fixture.command
        ready = fixture.event("ready", timeout=30)
        assert ready["protocol"] == args.protocol, ready
        report["fixture_ready"] = ready
        peer_run = run
        if args.protocol == "h3":
            from h3_peer import run as peer_run
        peer_run(args.protocol, ready["port"], certificate, results=report["cases"])
        report["admission_released"] = fixture.released()
        report["server_receipts"] = validate_server_receipts(fixture.all_events, args.protocol)
        validate_results(report["cases"])
        report["status"] = "PASS"
    except Exception as error:
        report["error"] = repr(error)
        report["traceback"] = traceback.format_exc()
    finally:
        if fixture is not None:
            try:
                report["shutdown"] = fixture.stop()
            except Exception as error:
                report["status"] = "FAIL"
                report["shutdown_error"] = repr(error)
            (evidence / "fixture-events.json").write_text(json.dumps(fixture.all_events, indent=2) + "\n")
        if args.release is not None:
            key.unlink(missing_ok=True)
            report["ephemeral_key_removed"] = True
        executed = {row["name"] for row in report["cases"]}
        report["executed"] = len(executed)
        report["not_run"] = sorted(set(REQUIRED_CASES) - executed)
        report["case_results"] = [
            next((row for row in report["cases"] if row["name"] == name),
                 {"name": name, "status": "NOT RUN", "reason": "suite did not complete this case"})
            for name in REQUIRED_CASES
        ]
        report["exit"] = 0 if report["status"] == "PASS" else 1
        (evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({"status": report["status"], "executed": report["executed"],
                          "required": len(REQUIRED_CASES), "evidence": str(evidence),
                          "error": report.get("error"), "shutdown_error": report.get("shutdown_error")}))
    return report["exit"]


if __name__ == "__main__":
    raise SystemExit(main())
