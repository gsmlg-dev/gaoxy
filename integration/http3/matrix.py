#!/usr/bin/env python3
"""Execute the source-bound H3 proxy and real Phoenix/Chromium matrix."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import queue
import signal
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
PROXY_CASES = {
    "proxy_escaped", "proxy_empty-query",
    "proxy_fixed_host_forwarding_identity_hop_filter",
    "proxy_fixed-trailers-0", "proxy_fixed-trailers-3",
    "proxy_progressive_upload_before_request_fin",
    "proxy_progressive_download_before_origin_fin",
    "proxy_forbidden_authentication_trailer_before_upstream",
    "proxy_early_final_stops_open_upload",
    "proxy_reset_cancels_origin_keeps_connection_siblings",
    "proxy_separate_listener_sibling",
}
BROWSER_CASES = {"browser_h3_phoenix_document", "browser_h3_phoenix_static"}


class EnvironmentUnavailable(Exception):
    pass


def source_hashes():
    paths = [ROOT / name for name in ("mix.lock", "mix.exs", "flake.lock",
                                      "scripts/generate-fixtures.sh")]
    for app in ("gaoxy", "gaoxy_http", "gaoxy_http3", "gaoxy_proxy"):
        directory = ROOT / "apps" / app
        paths += [directory / "mix.exs"]
        paths += list((directory / "lib").rglob("*.ex"))
        paths += list((directory / "test").rglob("*.exs"))
    phoenix = ROOT / "examples/phoenix_native"
    paths += [phoenix / name for name in ("mix.exs", "mix.lock", "h3_gateway.exs")]
    for name in ("lib", "config", "priv"):
        paths += [path for path in (phoenix / name).rglob("*") if path.is_file()]
    for suffix in ("*.py", "*.exs", "requirements.txt"):
        paths += list((ROOT / "integration/http3").glob(suffix))
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(set(paths)) if path.is_file()}


class Child:
    def __init__(self, name, command, directory, environment, evidence, total_deadline,
                 prefixes=(), raw_json=False):
        self.name, self.command, self.deadline = name, command, total_deadline
        self.events = queue.Queue()
        self.output = (evidence / (name + ".log")).open("w")
        self.process = subprocess.Popen(command, cwd=directory, env=environment,
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, text=True, bufsize=1,
                                        start_new_session=True)

        def read():
            for line in self.process.stdout:
                self.output.write(line)
                self.output.flush()
                try:
                    if raw_json and line.startswith("{"):
                        self.events.put(json.loads(line))
                    for prefix in prefixes:
                        if line.startswith(prefix + " "):
                            self.events.put(json.loads(line[len(prefix) + 1:]))
                except (ValueError, TypeError) as error:
                    self.events.put({"event": "invalid_event", "error": str(error)})

        self.reader = threading.Thread(target=read, daemon=True)
        self.reader.start()
        self.forced_cleanup = False

    def remaining(self, maximum):
        remaining = min(maximum, self.deadline - time.monotonic())
        assert remaining > 0, f"matrix total deadline expired: {self.name}"
        return remaining

    def event(self, maximum=10):
        return self.events.get(timeout=self.remaining(maximum))

    def control(self, command):
        self.process.stdin.write(json.dumps({"command": command}) + "\n")
        self.process.stdin.flush()
        return self.event()

    def wait(self, maximum):
        code = self.process.wait(timeout=self.remaining(maximum))
        self.reader.join(timeout=2)
        assert not self.reader.is_alive(), f"output reader still active: {self.name}"
        assert code == 0, (self.name, code)
        return code

    def cases(self, expected):
        cases = []
        try:
            self.wait(120)
        finally:
            while not self.events.empty():
                cases.append(self.events.get_nowait())
            self.output.flush()
            Path(self.output.name).with_suffix(".cases.json").write_text(
                json.dumps(cases, indent=2) + "\n")
        names = [case.get("name") for case in cases]
        assert set(names) == expected and len(names) == len(expected), (self.name, names)
        assert all(case.get("result") == "PASS" for case in cases), cases
        return cases

    def cleanup(self):
        if self.process.poll() is None:
            self.forced_cleanup = True
            try:
                os.killpg(self.process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(self.process.pid, signal.SIGKILL)
                self.process.wait(timeout=5)
        self.reader.join(timeout=2)
        self.output.close()


def baseline(child, checks, identity, services=None):
    deadline = time.monotonic() + 5
    while True:
        sample = child.control("sample")
        assert sample["event"] == "sample", sample
        states = sample["admission"]
        if services is None:
            states = {identity: states}
        else:
            assert set(states) == set(services), states
        if all(state["active"] == state["retained_bytes"] == state["cleanup_pending"] ==
               state["queued_items"] == state["queued_bytes"] == 0
               and state["cleanup_failed"] is None for state in states.values()):
            checks.append(dict(name=identity + "_admission_baseline", result="PASS", **sample))
            return sample
        assert time.monotonic() < deadline, ("termination_unconfirmed", sample)
        time.sleep(0.01)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--python", default=os.environ.get("GAOXY_QUIC_PYTHON",
                        str(ROOT / "integration/quic_consumer/.venv/bin/python")))
    parser.add_argument("--browser-python", default=str(ROOT / ".audit/browser-venv/bin/python"))
    args = parser.parse_args()
    evidence_root = args.evidence.resolve()
    evidence_root.mkdir(parents=True, exist_ok=True)
    evidence = evidence_root / f"run-{time.time_ns()}"
    evidence.mkdir()
    started = time.monotonic()
    total_deadline = started + 240
    report = dict(status="FAIL", gate="downstream-proxy-phoenix-browser", checks=[],
                  source_sha256=source_hashes(), commands=[], total_deadline_ms=240_000)
    report["source_commit"] = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    report["branch"] = subprocess.check_output(
        ["git", "branch", "--show-current"], cwd=ROOT, text=True).strip()
    children = []
    environment = dict(os.environ, MIX_ENV="test", ERL_FLAGS="+S 2:2")

    def launch(name, command, directory=ROOT, extra=None, prefixes=(), raw_json=False):
        child = Child(name, command, directory, dict(environment, **(extra or {})),
                      evidence, total_deadline, prefixes, raw_json)
        children.append(child)
        report["commands"].append(dict(name=name, command=command,
                                       cwd=str(directory.relative_to(ROOT))))
        return child

    try:
        for executable in (args.python, args.browser_python, "mix", "openssl", "chromium"):
            if shutil.which(executable) is None:
                raise EnvironmentUnavailable(f"required executable unavailable: {executable}")
        for executable, package, required in ((args.python, "aioquic", "1.2.0"),
                                              (args.browser_python, "playwright", "1.56.0")):
            command = [executable, "-c", "import importlib.metadata,sys; print(sys.version); "
                       f"print(importlib.metadata.version({package!r}))"]
            version = subprocess.run(command, capture_output=True, text=True, timeout=10)
            report["commands"].append(dict(name=package + "_prerequisite", command=command,
                                           exit=version.returncode))
            if version.returncode != 0 or version.stdout.splitlines()[-1:] != [required]:
                raise EnvironmentUnavailable(f"required {package}=={required} unavailable: "
                                             + version.stdout + version.stderr)
            report[package + "_environment"] = version.stdout.splitlines()
        with tempfile.TemporaryDirectory(prefix="gaoxy-http3-matrix-") as directory:
            certificate_command = ["bash", "scripts/generate-fixtures.sh", directory]
            with (evidence / "certificates.log").open("w") as output:
                result = subprocess.run(certificate_command, cwd=ROOT, stdout=output,
                                        stderr=subprocess.STDOUT, timeout=30)
            report["commands"].append(dict(name="certificates", command=certificate_command,
                                           exit=result.returncode))
            assert result.returncode == 0, "fixture certificate generation failed"
            report["fixture_certificates_sha256"] = {
                name: hashlib.sha256((Path(directory) / name).read_bytes()).hexdigest()
                for name in ("ca.pem", "cert.pem")}
            origin = launch("h1-origin", [sys.executable, "integration/http3/h1_origin.py"], raw_json=True)
            origin_ready = origin.event(15)
            assert origin_ready["event"] == "ready" and origin_ready["port"] > 0, origin_ready
            proxy = launch("proxy-fixture", ["mix", "run", "--no-compile",
                "integration/http3/matrix_fixture.exs"], extra={"GAOXY_HTTP3_CERT_DIR": directory,
                "GAOXY_HTTP3_H1_ORIGIN": f"http://127.0.0.1:{origin_ready['port']}"},
                prefixes=("GAOXY_HTTP3_MATRIX_READY", "GAOXY_HTTP3_MATRIX_CONTROL"))
            proxy_ready = proxy.event(30)
            assert proxy_ready["event"] == "ready" and proxy_ready["port"] > 0, proxy_ready
            report["proxy_runtime"] = proxy_ready
            peer = launch("proxy-peer", [args.python, "integration/http3/proxy_peer.py",
                "--port", str(proxy_ready["port"]), "--sibling-port", str(proxy_ready["sibling_port"]),
                "--origin-port", str(origin_ready["port"]), "--ca", str(Path(directory) / "ca.pem")],
                prefixes=("GAOXY_HTTP3_MATRIX",))
            report["checks"].extend(peer.cases(PROXY_CASES))
            sample = baseline(proxy, report["checks"], "proxy", ("proxy", "sibling"))
            assert all(state["retained_high_water"] > 0 for state in sample["admission"].values()), sample
            snapshot = origin.control("snapshot")
            assert snapshot["event"] == "snapshot" and snapshot["active"] == 0, snapshot
            receipts = snapshot["requests"]
            assert receipts and all(receipt["closed"] for receipt in receipts), snapshot
            assert all("error" not in receipt or receipt["error"] in
                       ("IncompleteReadError", "ConnectionResetError", "BrokenPipeError")
                       for receipt in receipts), snapshot
            (evidence / "origin-receipts.json").write_text(json.dumps(snapshot, indent=2) + "\n")
            report["checks"].append(dict(name="independent_h1_origin_cleanup", result="PASS",
                                         requests=len(receipts), active=0))
            stopped = proxy.control("stop")
            assert stopped["event"] == "stopped" and stopped["runtime_down"] and stopped["ports_rebound"], stopped
            assert stopped["elapsed_ms"] < 5_000, stopped
            proxy.wait(10)
            report["checks"].append(dict(name="proxy_runtime_stop_rebind", result="PASS", **stopped))
            final_origin = origin.control("stop")
            assert final_origin["event"] == "snapshot" and final_origin["active"] == 0, final_origin
            origin_stopped = origin.event(10)
            assert origin_stopped["event"] == "stopped" and origin_stopped["active"] == 0, origin_stopped
            origin.wait(10)

            phoenix = launch("phoenix-h3", ["mix", "run", "--no-start", "--no-compile", "h3_gateway.exs"],
                directory=ROOT / "examples/phoenix_native",
                extra={"GAOXY_HTTP3_CERT_DIR": directory, "PHOENIX_NATIVE_H3": "1"},
                prefixes=("GAOXY_HTTP3_BROWSER_READY", "GAOXY_HTTP3_BROWSER_CONTROL"))
            phoenix_ready = phoenix.event(30)
            assert phoenix_ready["event"] == "ready" and phoenix_ready["server_disabled"], phoenix_ready
            report["phoenix_runtime"] = phoenix_ready
            marker = uuid.uuid4().hex
            browser = launch("chromium", [args.browser_python, "integration/http3/browser.py",
                "--port", str(phoenix_ready["port"]), "--cert", str(Path(directory) / "cert.pem"),
                "--marker", marker, "--evidence", str(evidence / "browser")],
                prefixes=("GAOXY_HTTP3_BROWSER",))
            report["checks"].extend(browser.cases(BROWSER_CASES))
            browser_sample = baseline(phoenix, report["checks"], "phoenix")
            requests = browser_sample["requests"]
            for path in ("/", "/static/hello.txt"):
                matched = [request for request in requests if request["path"] == path
                           and request["marker"] == [marker]]
                assert len(matched) == 1, (path, requests)
                assert matched[0]["protocol"] == "HTTP/3" and matched[0]["status"] == 200, matched
            report["checks"].append(dict(name="browser_marker_server_h3_confirmation", result="PASS",
                                         marker=marker, requests=requests))
            stopped = phoenix.control("stop")
            assert stopped["event"] == "stopped" and stopped["runtime_down"] and stopped["port_rebound"], stopped
            assert stopped["elapsed_ms"] < 5_000, stopped
            phoenix.wait(10)
            report["checks"].append(dict(name="phoenix_runtime_stop_rebind", result="PASS", **stopped))
            assert report["source_sha256"] == source_hashes(), "source changed during matrix"
            assert report["checks"] and time.monotonic() < total_deadline, "matrix incomplete or expired"
            report["status"] = "PASS"
    except EnvironmentUnavailable as error:
        report["status"] = "BLOCKED_ENV"
        report["error"] = str(error)
        print(report["error"], file=sys.stderr)
    except Exception as error:
        report["error"] = f"{type(error).__name__}: {error}"
        print(report["error"], file=sys.stderr)
        if "origin" in locals() and origin.process.poll() is None:
            try:
                snapshot = origin.control("snapshot")
                (evidence / "failure-origin-snapshot.json").write_text(
                    json.dumps(snapshot, indent=2) + "\n")
            except Exception as diagnostic_error:
                report["origin_diagnostic_error"] = repr(diagnostic_error)
    finally:
        for child in reversed(children):
            child.cleanup()
        report["owned_children_exited"] = all(child.process.poll() is not None for child in children)
        report["owned_child_exits"] = [dict(name=child.name, pid=child.process.pid,
            exit=child.process.returncode, forced_cleanup=child.forced_cleanup) for child in children]
        report["final_source_sha256"] = source_hashes()
        report["source_unchanged"] = report["source_sha256"] == report["final_source_sha256"]
        if (not report["source_unchanged"] or not report["owned_children_exited"] or
                any(child.forced_cleanup for child in children)):
            report["status"] = "FAIL"
        report["elapsed_ms"] = round((time.monotonic() - started) * 1_000)
        report["finished_utc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        (evidence / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
        (evidence_root / "latest.json").write_text(json.dumps(
            dict(run=evidence.name, status=report["status"]), indent=2) + "\n")
    print(json.dumps(dict(status=report["status"], cases=len(report["checks"]), evidence=str(evidence))))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
