#!/usr/bin/env python3
"""Qualify data-only standalone H3 through its actual Application startup path."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "integration/http3"))
from matrix import Child, EnvironmentUnavailable, baseline, source_hashes as matrix_hashes

PEER_CASES = {
    "standalone_h3_static_and_legacy_h1", "standalone_h3_proxy_progressive_upload",
    "standalone_proxy_failure_isolates_h3_and_h1_siblings",
    "standalone_reload_keeps_listener_and_inflight_generation",
    "standalone_invalid_reload_preserves_current_generation",
}
ROLLBACK_CASES = {"standalone_startup_rollback", "standalone_missing_certificate_rollback"}


def source_hashes():
    hashes = matrix_hashes()
    paths = [ROOT / "apps/gaoxy_server/mix.exs"]
    paths += list((ROOT / "apps/gaoxy_server/lib").rglob("*.ex"))
    paths += list((ROOT / "apps/gaoxy_server/test").rglob("*.exs"))
    paths += list((ROOT / "integration/http3/standalone").glob("*"))
    hashes.update({str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                   for path in paths if path.is_file()})
    return hashes


def static(body):
    return {"version": 1, "routes": [{"target": {"type": "static", "body": body}}]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--python", default=os.environ.get("GAOXY_QUIC_PYTHON",
                        str(ROOT / "integration/quic_consumer/.venv/bin/python")))
    args = parser.parse_args()
    evidence_root = args.evidence.resolve()
    evidence = evidence_root / f"run-{time.time_ns()}"
    evidence.mkdir(parents=True)
    started = time.monotonic()
    deadline = started + 180
    report = dict(status="FAIL", gate="standalone-h3", checks=[], commands=[],
                  source_sha256=source_hashes(), total_deadline_ms=180_000)
    report["source_commit"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    children = []
    environment = dict(os.environ, MIX_ENV="test", ERL_FLAGS="+S 2:2")

    def launch(name, command, extra=None, prefixes=(), raw=False):
        child = Child(name, command, ROOT, dict(environment, **(extra or {})),
                      evidence, deadline, prefixes, raw)
        children.append(child)
        report["commands"].append(dict(name=name, command=command))
        return child

    try:
        for executable in (args.python, "mix", "openssl"):
            if shutil.which(executable) is None:
                raise EnvironmentUnavailable(f"required executable unavailable: {executable}")
        version_command = [args.python, "-c", "import importlib.metadata,sys; print(sys.version); "
                           "print(importlib.metadata.version('aioquic'))"]
        version = subprocess.run(version_command, capture_output=True, text=True, timeout=10)
        report["commands"].append(dict(name="aioquic_prerequisite", command=version_command,
                                       exit=version.returncode))
        if version.returncode != 0 or version.stdout.splitlines()[-1:] != ["1.2.0"]:
            raise EnvironmentUnavailable("required aioquic==1.2.0 unavailable: "
                                         + version.stdout + version.stderr)
        report["peer_environment"] = version.stdout.splitlines()
        report["origin_runner_python"] = sys.version
        with tempfile.TemporaryDirectory(prefix="gaoxy-standalone-h3-") as temporary:
            directory = Path(temporary)
            with (evidence / "certificates.log").open("w") as output:
                result = subprocess.run(["bash", "scripts/generate-fixtures.sh", temporary],
                                        cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, timeout=30)
            assert result.returncode == 0, "certificate generation failed"
            origin = launch("origin", [sys.executable, "integration/http3/h1_origin.py"], raw=True)
            origin_ready = origin.event(15)
            assert origin_ready["event"] == "ready", origin_ready
            routes = {"version": 1, "routes": [
                {"prefix": "/proxy", "target": {"type": "reverse_proxy",
                 "upstream": f"http://127.0.0.1:{origin_ready['port']}"}},
                {"target": {"type": "static", "body": "old"}}]}
            config = {"version": 1, "services": [
                {"id": "h3", "handler": "http3", "transport": "quic", "protocols": ["http3"],
                 "ip": "127.0.0.1", "port": 0, "tls": {
                     "certfile": str(directory / "cert.pem"), "keyfile": str(directory / "key.pem")},
                 "limits": {"max_bytes": 134_217_728}, "routes": routes},
                {"id": "legacy", "handler": "http", "transport": "tcp",
                 "ip": "127.0.0.1", "port": 0, "limits": {"max_bytes": 8_388_608},
                 "routes": static("legacy")}]}
            for name, value in (("config", config), ("routes", static("new")),
                                ("invalid", {"version": 1, "routes": [{"target": {"type": "unknown"}}]})):
                (directory / (name + ".json")).write_text(json.dumps(value))
            report["fixture_config"] = config
            fixture_env = {"GAOXY_CONFIG": str(directory / "config.json"),
                "GAOXY_STANDALONE_ROUTES": str(directory / "routes.json"),
                "GAOXY_STANDALONE_INVALID": str(directory / "invalid.json")}
            command = ["mix", "run", "--no-compile", "--no-start", "integration/http3/standalone/fixture.exs"]
            fixture = launch("standalone", command, fixture_env, ("GAOXY_STANDALONE",))
            ready = fixture.event(30)
            assert ready["event"] == "ready" and set(ready["ports"]) == {"h3", "legacy"}, ready
            report["runtime"] = ready
            ports = ready["ports"]
            peer = launch("peer", [args.python, "integration/http3/standalone/peer.py",
                "--port", str(ports["h3"]), "--h1-port", str(ports["legacy"]),
                "--origin-port", str(origin_ready["port"]), "--ca", str(directory / "ca.pem")],
                prefixes=("GAOXY_STANDALONE_PEER",))
            cases = []
            while len(cases) < len(PEER_CASES):
                item = peer.event(30)
                if item["event"] == "barrier":
                    command = item["command"]
                    assert command in ("reload", "invalid-reload"), item
                    receipt = fixture.control(command)
                    assert receipt["event"] == command and receipt["listener_unchanged"], receipt
                    assert receipt["generation_changed"] == (command == "reload"), receipt
                    report["checks"].append(dict(name=command + "_activation_receipt", result="PASS", receipt=receipt))
                    peer.process.stdin.write("continue\n")
                    peer.process.stdin.flush()
                else:
                    assert item["event"] == "check" and item["result"] == "PASS", item
                    cases.append(item)
            peer.wait(10)
            names = [case["name"] for case in cases]
            assert len(names) == len(set(names)) and set(names) == PEER_CASES, cases
            report["checks"].extend(cases)
            baseline(fixture, report["checks"], "standalone", ("h3", "legacy"))
            snapshot = origin.control("snapshot")
            assert snapshot["event"] == "snapshot" and snapshot["active"] == 0, snapshot
            assert len(snapshot["requests"]) == 2 and all(
                request["closed"] and request["complete"] and "error" not in request
                for request in snapshot["requests"]), snapshot
            assert {request["id"] for request in snapshot["requests"]} == {
                "standalone-upload", "standalone-old-generation"}, snapshot
            report["origin_receipts"] = snapshot
            stop = fixture.control("stop")
            assert stop["event"] == "stopped" and stop["ports_rebound"] and stop["owners_down"] == 5, stop
            assert stop["elapsed_ms"] < 5_000, stop
            fixture.wait(10)
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as rebound:
                rebound.bind(("127.0.0.1", ports["h3"]))
            report["checks"].append(dict(name="standalone_stop_owners_down_rebind", result="PASS", **stop))
            stopped_origin = origin.control("stop")
            assert stopped_origin["active"] == 0, stopped_origin
            assert origin.event(10)["event"] == "stopped"
            origin.wait(10)

            rollback = launch("rollback", command=["mix", "run", "--no-compile", "--no-start",
                "integration/http3/standalone/fixture.exs"],
                extra=dict(fixture_env, GAOXY_STANDALONE_MODE="rollback"),
                prefixes=("GAOXY_STANDALONE",))
            rollback_cases = rollback.cases(ROLLBACK_CASES)
            report["checks"].extend(rollback_cases)
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as rebound:
                rebound.bind(("127.0.0.1", rollback_cases[0]["port"]))
            assert report["source_sha256"] == source_hashes(), "source changed during standalone gate"
            assert report["checks"] and time.monotonic() < deadline
            report["status"] = "PASS"
    except EnvironmentUnavailable as error:
        report.update(status="BLOCKED_ENV", error=str(error))
    except Exception as error:
        report["error"] = f"{type(error).__name__}: {error}"
        print(report["error"], file=sys.stderr)
    finally:
        for child in reversed(children):
            child.cleanup()
        report["children"] = [dict(name=child.name, pid=child.process.pid,
            exit=child.process.returncode, forced_cleanup=child.forced_cleanup) for child in children]
        report["source_after_sha256"] = source_hashes()
        report["source_unchanged"] = report["source_after_sha256"] == report["source_sha256"]
        if not report["source_unchanged"] or any(child.forced_cleanup for child in children):
            report["status"] = "FAIL"
        report["elapsed_ms"] = round((time.monotonic() - started) * 1_000)
        (evidence / "result.json").write_text(json.dumps(report, indent=2) + "\n")
        (evidence_root / "latest.json").write_text(json.dumps(
            dict(run=evidence.name, status=report["status"]), indent=2) + "\n")
    print(json.dumps(dict(status=report["status"], cases=len(report["checks"]), evidence=str(evidence))))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
