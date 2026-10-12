#!/usr/bin/env python3
"""Run owned loopback HTTP/3 peers; retain source-bound evidence and finite teardown."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import queue
import signal
import subprocess
import sys
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[2]


def source_hashes():
    paths = [ROOT / "mix.lock", ROOT / "flake.lock", ROOT / "mix.exs"]
    for app in ("gaoxy", "gaoxy_http", "gaoxy_http3"):
        paths += list((ROOT / "apps" / app / "lib").rglob("*.ex"))
        paths += [ROOT / "apps" / app / "mix.exs"]
    paths += list((ROOT / "integration/http3").glob("*.py"))
    paths += list((ROOT / "integration/http3").glob("*.exs"))
    paths += [ROOT / "integration/http3/requirements.txt"]
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(paths) if p.is_file()}


def shutdown(child):
    if child.poll() is None:
        try:
            os.killpg(child.pid, signal.SIGTERM)
        except ProcessLookupError:
            child.wait(timeout=5)
            return
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait(timeout=5)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gate", choices=["minimal", "diagnostic", "shared"], required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--python", default=os.environ.get("GAOXY_QUIC_PYTHON",
                        str(ROOT / "integration/quic_consumer/.venv/bin/python")))
    args = parser.parse_args()
    args.evidence.mkdir(parents=True, exist_ok=True)
    evidence_root = args.evidence
    args.evidence = evidence_root / f"run-{time.time_ns()}"
    args.evidence.mkdir()
    report = {"status": "FAIL", "gate": args.gate, "checks": [],
              "source_sha256": source_hashes(), "commands": []}
    report["source_commit"] = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    report["branch"] = subprocess.check_output(
        ["git", "branch", "--show-current"], cwd=ROOT, text=True).strip()
    children, readers = [], []
    fixture_events = queue.Queue()
    log = (args.evidence / "fixture.log").open("w")

    def monitor(child, output, events, prefixes):
        def read():
            for line in child.stdout:
                output.write(line)
                output.flush()
                for prefix in prefixes:
                    if line.startswith(prefix + " "):
                        events.put(json.loads(line[len(prefix) + 1:]))
        reader = threading.Thread(target=read, daemon=True)
        reader.start()
        readers.append(reader)
        return reader

    try:
        with tempfile.TemporaryDirectory(prefix="gaoxy-http3-") as directory:
            command = ["bash", "scripts/generate-fixtures.sh", directory]
            with (args.evidence / "certificates.log").open("w") as cert_log:
                result = subprocess.run(command, cwd=ROOT, stdout=cert_log,
                                        stderr=subprocess.STDOUT, timeout=30)
            report["commands"].append({"command": command[:-1] + ["<temporary fixture directory>"],
                                       "exit": result.returncode})
            assert result.returncode == 0, "fixture certificate generation failed"
            version = subprocess.run([args.python, "-c", "import importlib.metadata,sys; "
                "print(sys.version); print(importlib.metadata.version('aioquic'))"],
                capture_output=True, text=True, timeout=10)
            assert version.returncode == 0 and version.stdout.splitlines()[-1] == "1.2.0", version
            report["python_environment"] = version.stdout.splitlines()
            command = ["mix", "run", "--no-compile", "integration/http3/fixture.exs"]
            fixture = subprocess.Popen(command, cwd=ROOT, env=dict(os.environ, MIX_ENV="test",
                ERL_FLAGS="+S 2:2", GAOXY_HTTP3_CERT_DIR=directory,
                GAOXY_HTTP3_PROFILE="shared" if args.gate == "shared" else "minimal"), stdin=subprocess.PIPE,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1,
                start_new_session=True)
            children.append(fixture)
            report["commands"].append({"command": command})
            monitor(fixture, log, fixture_events, ["GAOXY_HTTP3_READY", "GAOXY_HTTP3_CONTROL"])
            ready = fixture_events.get(timeout=30)
            assert ready["event"] == "ready", ready
            report["runtime"] = ready

            def control(command):
                fixture.stdin.write(json.dumps({"command": command}) + "\n")
                fixture.stdin.flush()
                return fixture_events.get(timeout=8)

            def peer(mode, interactive=False):
                command = [args.python, "integration/http3/peer.py", "--mode", mode,
                           "--port", str(ready["port"]), "--sibling-port", str(ready["sibling_port"]),
                           "--ca", str(Path(directory) / "ca.pem")]
                if mode == "busy":
                    command += ["--busy-port", str(ready["busy_port"])]
                output = (args.evidence / (mode + ".log")).open("w")
                events = queue.Queue()
                child = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                    bufsize=1, start_new_session=True)
                children.append(child)
                reader = monitor(child, output, events, ["GAOXY_HTTP3_PEER"])
                try:
                    if interactive:
                        event = events.get(timeout=20)
                        if mode == "busy":
                            assert event["event"] == "busy_ready", event
                            cleaned = control("kill-busy")
                            assert cleaned["event"] == "busy-cleaned", cleaned
                            assert all(cleaned[key] for key in
                                       ("owner_down", "worker_down", "ets_deleted", "admission_alive")), cleaned
                            assert cleaned["pins"] == 0 and cleaned["admission_after"]["active"] == 0, cleaned
                            assert cleaned["admission_after"]["retained_bytes"] == 0, cleaned
                            assert cleaned["service_cleanup_failed"] is None, cleaned
                            assert cleaned["cleanup_remaining_ms"] > 0, cleaned
                            assert not cleaned["plug_release_sent"] and not cleaned["worker_kill_requested"], cleaned
                            report["checks"].append(dict(name="shared_busy_confirmed_cleanup", result="PASS", **cleaned))
                            child.stdin.write("cleaned\n")
                        else:
                            assert event["event"] == "shutdown_ready", event
                            removed = control("remove-main")
                            assert removed["event"] == "removed" and removed["port_rebound"], removed
                            report["checks"].append(dict(name="bounded_listener_remove", result="PASS", **removed))
                            child.stdin.write("removed\n")
                        child.stdin.flush()
                    code = child.wait(timeout=120)
                    reader.join(timeout=2)
                    report["commands"].append({"command": ["<temporary CA>" if item ==
                        str(Path(directory) / "ca.pem") else item for item in command], "exit": code})
                    cases = []
                    while not events.empty():
                        cases.append(events.get_nowait())
                    report["checks"].extend(cases)
                    assert code == 0 and cases, (mode, code, cases)
                    assert all(case.get("result") == "PASS" for case in cases), cases
                finally:
                    shutdown(child)
                    reader.join(timeout=2)
                    output.close()

            if args.gate == "diagnostic":
                peer("diagnostic")
            else:
                peer("shared" if args.gate == "shared" else "ordinary")
                sample = control("sample")
                assert sample["event"] == "sample" and sample["blocked"] > 0, sample
                report["checks"].append(dict(name="definitely_blocked_output", result="PASS", **sample))
                if args.gate == "shared":
                    limits, high = ready["application_limits"], sample["application_queue_high_water"]
                    assert sample["application_queue_observations"] > 0, sample
                    assert 0 < high["slot_count"] <= limits["max_slots"], sample
                    assert 0 <= high["ingress_bytes"] <= limits["max_ingress_bytes"], sample
                    assert 0 < high["output_bytes"] <= limits["max_output_bytes"], sample
                    assert 0 < sample["admission"]["retained_high_water"] <= limits["admission_max_bytes"], sample
                    report["checks"].append(dict(name="shared_application_queue_bounds", result="PASS",
                                                 limits=limits, **sample))
                    deadline = time.monotonic() + 2.5
                    while True:
                        baseline = control("sample")
                        state = baseline["admission"]
                        if (state["active"] == state["retained_bytes"] == state["cleanup_pending"] ==
                                baseline["application_slots"] == 0 and state["cleanup_failed"] is None):
                            break
                        assert time.monotonic() < deadline, ("termination_unconfirmed", baseline)
                        time.sleep(0.01)
                    report["checks"].append(dict(name="shared_admission_slots_returned_to_baseline",
                                                 result="PASS", **baseline))
                    peer("busy", interactive=True)
                peer("malformed")
                peer("cancellation")
                peer("shutdown", interactive=True)
            stopped = control("stop")
            assert stopped["event"] == "stopped" and stopped["runtime_down"] and stopped["ports_rebound"], stopped
            assert stopped["elapsed_ms"] < 5_000, stopped
            fixture.wait(timeout=8)
            assert fixture.returncode == 0, fixture.returncode
            report["checks"].append(dict(name="bounded_runtime_stop", result="PASS", **stopped))
            assert report["source_sha256"] == source_hashes(), "source changed during acceptance"
            assert report["checks"], "zero executed cases"
            report["status"] = "PASS"
    except Exception as error:
        report["error"] = f"{type(error).__name__}: {error}"
        print(report["error"], file=sys.stderr)
    finally:
        for child in reversed(children):
            shutdown(child)
        for reader in readers:
            reader.join(timeout=2)
        log.close()
        report["owned_children_exited"] = all(child.poll() is not None for child in children)
        report["owned_child_exits"] = [{"pid": child.pid, "exit": child.returncode}
                                       for child in children]
        report["final_source_sha256"] = source_hashes()
        report["source_unchanged"] = report["source_sha256"] == report["final_source_sha256"]
        if not report["source_unchanged"]:
            report["status"] = "FAIL"
        report["finished_utc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        (args.evidence / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
        (evidence_root / "latest.json").write_text(json.dumps(
            {"run": args.evidence.name, "status": report["status"]}, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "cases": len(report["checks"])}))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
