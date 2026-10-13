#!/usr/bin/env python3
"""Bounded public Fetch H3 qualification with independent origin assertions."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import queue
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[3]


def credentials(directory, output, timeout):
    """Generate P-256 signatures supported by the client's public QUIC profile."""
    directory.mkdir(mode=0o700)
    config = directory / "openssl.cnf"
    config.write_text("""[req]
distinguished_name=subject
prompt=no
[subject]
CN=localhost
[ca]
basicConstraints=critical,CA:TRUE,pathlen:0
keyUsage=critical,keyCertSign,cRLSign
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always
[server]
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=serverAuth
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always
subjectAltName=DNS:localhost
""")
    env = dict(os.environ, OPENSSL_CONF=str(config))
    commands = [
        ["openssl", "req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:P-256",
         "-nodes", "-days", "2", "-sha256", "-config", str(config), "-extensions", "ca",
         "-subj", "/CN=Gaoxy upstream test CA", "-keyout", str(directory / "ca-key.pem"),
         "-out", str(directory / "ca.pem")],
        ["openssl", "req", "-new", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:P-256",
         "-nodes", "-sha256", "-config", str(config), "-subj", "/CN=localhost",
         "-keyout", str(directory / "key.pem"), "-out", str(directory / "request.pem")],
        ["openssl", "x509", "-req", "-in", str(directory / "request.pem"),
         "-CA", str(directory / "ca.pem"), "-CAkey", str(directory / "ca-key.pem"),
         "-CAcreateserial", "-days", "2", "-sha256", "-extfile", str(config),
         "-extensions", "server", "-out", str(directory / "cert.pem")],
        ["openssl", "verify", "-x509_strict", "-purpose", "sslserver",
         "-verify_hostname", "localhost", "-CAfile", str(directory / "ca.pem"),
         str(directory / "cert.pem")]]
    for command in commands:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=output,
                                stderr=subprocess.STDOUT, timeout=timeout(10))
        assert result.returncode == 0, "P-256 fixture generation/verification failed"
    for path in directory.iterdir():
        path.chmod(0o600)


def source_hashes():
    files = [ROOT / p for p in ("mix.lock", "flake.lock", "mix.exs",
             "apps/gaoxy_proxy/mix.exs", "scripts/generate-fixtures.sh",
             "deps/abyss/lib/abyss/quic.ex", "deps/abyss/lib/abyss/quic/handler.ex",
             "deps/abyss/lib/abyss/quic/service.ex")]
    files += list((ROOT / "integration/http3/upstream").glob("*"))
    files += list((ROOT / "apps").rglob("*.ex"))
    files += list((ROOT / "apps").rglob("mix.exs"))
    for dependency in ("http_fetch", "http_runtime", "http_core", "elixir_quic",
                       "elixir_quic_http3", "ex_ssl", "quic_nif"):
        base = ROOT / "deps" / dependency
        files += [base / "mix.exs", base / ".hex"]
        for directory in ("lib", "src", "c_src", "native", "priv"):
            files += [p for p in (base / directory).rglob("*") if p.is_file() and
                      "target" not in p.parts and "__pycache__" not in p.parts]
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(files) if p.is_file()}


def shutdown(child):
    if child.poll() is None:
        try:
            os.killpg(child.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait(timeout=5)


def matrix(args):
    """Separate production-adapter gate; no Fetch/Session diagnostic substitution."""
    cases = ("get", "head", "bodyless_204", "bodyless_304", "progressive_upload",
             "progressive_download", "tiny_window_1mib", "duplicate_fields", "raw_compression",
             "escaped_path", "empty_query", "redirect_no_replay", "trailers_zero", "trailers_data",
             "early_final", "downstream_cancel", "upstream_reset", "opening_timeout", "total_timeout",
             "wrong_ca", "wrong_hostname", "interleaved_authorities")
    required = {protocol + "_" + case for protocol in ("h1", "h2", "h3") for case in cases}
    assert len(required) == 66
    evidence = args.evidence / f"matrix-{time.time_ns()}"
    evidence.mkdir(parents=True, exist_ok=False)
    started, deadline = time.monotonic(), time.monotonic() + 240
    up2_counters = {name: int(os.environ.get(variable, "0")) for name, variable in (
        ("up2_repair_rounds", "GAOXY_UP2_REPAIR"), ("up2_failed_rounds", "GAOXY_UP2_FAILED"))}
    if any(value < 0 for value in up2_counters.values()):
        raise ValueError("UP2 counters must be nonnegative integers")
    report = dict(status="FAIL", gate="matrix", checks=[], commands=[], wire_events=[],
                  source_sha256=source_hashes(), qualification_command=[sys.executable, *sys.argv],
                  expected_network_rows=66, expected_policy_rows=2,
                  source_commit=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                  branch=subprocess.check_output(["git", "branch", "--show-current"], cwd=ROOT, text=True).strip(),
                  environment={"MIX_ENV": "test", "ERL_FLAGS": "+S 2:2"},
                  counters={"up0_sol_rounds": 2, "up0_unsuccessful_sol": 2,
                            "up0_astra_rounds": 2, "up0_unsuccessful_astra": 2,
                            "up0_coordinator_repair": 5, "up0_preceding_unsuccessful_coordinator": 4,
                            "up1_repair_rounds": 2, "up1_preceding_unsuccessful_repairs": 1,
                            "up1_initial_unsuccessful": 1,
                            **up2_counters, "astra_recovery_status": "two_rounds_exhausted"})
    children, readers, logs, ports = [], [], [], []
    origin_events, fixture_events, peer_events = queue.Queue(), queue.Queue(), queue.Queue()
    expected_requests = {}
    origin = fixture = peer = None

    def remaining(maximum):
        value = min(maximum, deadline - time.monotonic())
        assert value > 0, "matrix absolute runner deadline exceeded"
        return value

    def launch(name, command, prefix, events, env=None):
        log = (evidence / (name + ".log")).open("w")
        logs.append(log)
        child = subprocess.Popen(command, cwd=ROOT, env=env, stdin=subprocess.PIPE,
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 text=True, bufsize=1, start_new_session=True)
        children.append(child)
        report["commands"].append(dict(name=name, command=command, pid=child.pid))

        def read():
            for line in child.stdout:
                log.write(line)
                log.flush()
                if line.startswith(prefix + " "):
                    try:
                        events.put(json.loads(line[len(prefix) + 1:]))
                    except ValueError as error:
                        events.put(dict(event="invalid_json", error=repr(error)))
            events.put(dict(event="child_exit", name=name, exit=child.wait()))

        reader = threading.Thread(target=read, daemon=True)
        reader.start()
        readers.append(reader)
        return child

    def send(child, command):
        assert child.poll() is None, ("control child exited", child.returncode)
        child.stdin.write(json.dumps(command) + "\n")
        child.stdin.flush()

    def event(events, maximum=5):
        try:
            value = events.get(timeout=remaining(maximum))
        except queue.Empty as error:
            raise AssertionError("matrix child/control event deadline") from error
        assert value["event"] not in ("child_exit", "invalid_json"), value
        return value

    def origin_until(predicate, maximum=5):
        until = time.monotonic() + remaining(maximum)
        while True:
            item = event(origin_events, until - time.monotonic())
            report["wire_events"].append(item)
            if predicate(item):
                return item

    def snapshot():
        send(origin, dict(command="snapshot"))
        return origin_until(lambda item: item["event"] == "snapshot")["requests"]

    def sample(maximum=5):
        send(fixture, dict(command="sample"))
        item = event(fixture_events, maximum)
        assert item["event"] == "sample", item
        return item

    def sample_until(predicate):
        until = time.monotonic() + remaining(1)
        while True:
            item = sample(until - time.monotonic())
            if predicate(item):
                return item
            assert time.monotonic() < until, ("termination_unconfirmed", item)
            time.sleep(0.005)

    def baseline():
        def clean(item):
            assert set(item["admission"]) == {p + s for p in ("h1", "h2", "h3") for s in ("", "_sibling")}, item
            clean = all(value["active"] == value["retained_bytes"] == value["cleanup_pending"] ==
                        value["queued_items"] == value["queued_bytes"] == 0 and value["cleanup_failed"] is None
                        for value in item["admission"].values())
            return clean and item["session_children"] == item["observed_guardians"] == 0
        return sample_until(clean)

    def requests_completed(expected, protocol):
        def ready(item):
            receipts = {receipt["id"]: receipt for receipt in item["receipts"]}
            return all(wanted["id"] in receipts and
                       receipts[wanted["id"]].get("guardian_down") == ":normal" and
                       (receipts[wanted["id"]].get("owner_down") == ":killed"
                        if wanted["case"] == "downstream_cancel" and protocol != "h1"
                        else "result" in receipts[wanted["id"]]) for wanted in expected)
        return sample_until(ready)

    def validate_requests(requests, expected):
        actual = {request["id"]: request for request in requests}
        assert len(actual) == len(requests), ("duplicate/replayed origin request", requests)
        admitted = {identity for identity, value in expected.items() if value.get("admitted", True)}
        assert set(actual) == admitted, ("missing or unexpected origin admission", sorted(actual), sorted(admitted))
        for identity, request in actual.items():
            wanted = expected[identity]
            assert request["method"] == wanted["method"] and request["path"] == wanted["path"], (wanted, request)
            for name, value in ((":method", wanted["method"]), (":path", wanted["path"]),
                                (":scheme", "https"), (":authority", request["authority"])):
                assert [field for key, field in request["headers"] if key == name] == [value], request
            assert request["origin"] == wanted["origin"], (wanted, request)
            assert request["authority"] == f"localhost:{ports[0 if request['origin'] == 'a' else 1]}", request
            assert request["certificate_sha256"] == report["certificate_sha256"][request["origin"]]["cert.pem"], request
            assert request["data_bytes"] == wanted["bytes"] and request["data_sha256"] == wanted["body_sha256"], (wanted, request)
            assert request["trailers"] == wanted["trailers"], (wanted, request)
            assert request["trailer_blocks"] == (1 if wanted["trailers"] else 0), request
            assert request["fin_count"] == wanted["fin_count"] and request["request_fin"] == bool(wanted["fin_count"]), (wanted, request)
            events = report["wire_events"]
            assert sum(item["event"] == "request_fin" and item.get("id") == identity for item in events) == wanted["fin_count"], request
            assert sum(item["event"] == "trailers" and item.get("id") == identity for item in events) == request["trailer_blocks"], request
            assert sum(item["event"] == "headers" and item.get("id") == identity for item in events) == 1, request
            assert sum(item["event"] == "data" and item.get("id") == identity for item in events) == request["data_events"], request
            if wanted["case"] == "duplicate_fields":
                assert [v for k, v in request["headers"] if k == "x-trace"] == ["first", "second"], request
            if wanted["trailers"]:
                assert [v for k, v in request["headers"] if k == "trailer"] == ["x-check"], request
            if wanted["case"] == "upstream_reset":
                resets = [item for item in events if item["event"] == "origin_reset" and item.get("id") == identity]
                assert len(resets) == 1 and resets[0]["error_code"] == 0x10C, resets
            if wanted["case"] == "tiny_window_1mib":
                assert request["data_bytes"] == 1048576 and request["data_sha256"] == hashlib.sha256(b"x" * 1048576).hexdigest(), request

    def validate_receipts(sampled, expected, protocol, case):
        receipts = {receipt["id"]: receipt for receipt in sampled["receipts"]}
        for wanted in expected:
            receipt = receipts[wanted["id"]]
            assert receipt["client"] == "Gaoxy.Proxy.HTTP3SessionClient", receipt
            assert receipt["guardian_down"] == ":normal", receipt
            if wanted["case"] != "downstream_cancel":
                assert "result" in receipt, receipt
            assert not any("cleanup" in error for error in receipt["errors"]), receipt
            if wanted["case"] == "opening_timeout":
                assert receipt["errors"] == [":timeout"], receipt
                assert 450 <= receipt["elapsed_ms"] <= 1500, receipt
            elif wanted["case"] == "total_timeout":
                assert receipt["errors"] == [":request_timeout"], receipt
                assert 1400 <= receipt["elapsed_ms"] <= 2500, receipt
            elif wanted["case"] == "upstream_reset":
                assert len(receipt["errors"]) == 1 and receipt["errors"][0].startswith("{:upstream_reset, 268,"), receipt
            elif wanted["case"] in ("wrong_ca", "wrong_hostname"):
                assert len(receipt["errors"]) == 1 and receipt["errors"][0] == ":closed", receipt
                assert len(receipt["public_closed"]) == 1, receipt
                closed = receipt["public_closed"][0]
                causes = ("unknown_ca", "path_validation_failed") if wanted["case"] == "wrong_ca" else ("certificate_unknown", "hostname_mismatch")
                assert all(cause in closed for cause in causes), receipt
            elif wanted["case"] == "downstream_cancel":
                if protocol == "h1":
                    assert receipt["result"] == {"outcome": "error", "reason": ":closed"}, receipt
                else:
                    # Native framed cancellation kills the endpoint worker; its
                    # monitored actual DOWN is the category, not a fabricated return.
                    assert receipt["owner_down"] == ":killed" and "result" not in receipt, receipt
            else:
                assert receipt["errors"] == [] and receipt["result"]["outcome"] == "ok", receipt

    try:
        with tempfile.TemporaryDirectory(prefix="gaoxy-upstream-matrix-") as temporary:
            directories = [Path(temporary) / identity for identity in ("a", "b", "downstream")]
            for identity, directory in zip(("a", "b", "downstream"), directories):
                with (evidence / ("certificates-" + identity + ".log")).open("w") as output:
                    credentials(directory, output, remaining)
            report["certificate_sha256"] = {identity: {name: hashlib.sha256((directory / name).read_bytes()).hexdigest()
                for name in ("ca.pem", "cert.pem")} for identity, directory in zip(("a", "b", "downstream"), directories)}
            assert len({value["cert.pem"] for value in report["certificate_sha256"].values()}) == 3
            version_command = [args.python, "-c", "import importlib.metadata,sys; print(sys.version); "
                "print(importlib.metadata.version('aioquic')); print(importlib.metadata.version('h2')); "
                "print(importlib.metadata.version('hpack')); print(importlib.metadata.version('hyperframe'))"]
            version = subprocess.run(version_command, capture_output=True, text=True, timeout=remaining(10))
            report["commands"].append(dict(name="python_prerequisite", command=version_command, exit=version.returncode))
            if version.returncode != 0 or version.stdout.splitlines()[-4:] != ["1.2.0", "4.3.0", "4.2.0", "6.1.0"]:
                raise FileNotFoundError("matrix needs pinned aioquic==1.2.0, h2==4.3.0, hpack==4.2.0, hyperframe==6.1.0: " + version.stdout + version.stderr)
            report["python_environment"] = version.stdout.splitlines()
            origin = launch("origin", [args.python, "integration/http3/upstream/origin.py",
                "--cert-a", str(directories[0]), "--cert-b", str(directories[1])], "GAOXY_UPSTREAM_ORIGIN", origin_events)
            ports = origin_until(lambda value: value["event"] == "ready")["ports"]
            env = dict(os.environ, MIX_ENV="test", ERL_FLAGS="+S 2:2", GAOXY_HTTP3_CERT_DIR=str(directories[2]))
            for identity, directory, port in zip(("A", "B"), directories[:2], ports):
                env["GAOXY_UPSTREAM_URL_" + identity] = f"https://localhost:{port}"
                env["GAOXY_UPSTREAM_CA_" + identity] = str(directory / "ca.pem")
            fixture = launch("fixture", ["mix", "run", "--no-compile", "integration/http3/upstream/fixture.exs"],
                             "GAOXY_UPSTREAM_MATRIX_FIXTURE", fixture_events, env)
            ready = event(fixture_events, 30)
            assert ready["event"] == "ready" and ready["http_fetch"] == "0.21.4", ready
            assert set(ready["quic"]) == {"h3", "h3_sibling"}, ready
            for profile in ready["quic"].values():
                assert profile == {"alpn": ["h3"], "poll_interval": 1}, profile
            assert set(ready["h2_limits"]) == {"h2", "h2_sibling"}, ready
            for limits in ready["h2_limits"].values():
                assert limits["receive_window"] == 16_384 and limits["control_rate"] == 2_048 and limits["control_turn"] == 32, limits
            report["fixture"] = ready
            initial = baseline()
            assert snapshot() == [], "matrix starts with nonzero independent origin admission"
            report["initial_baseline"] = initial
            for name in ("absent_trust", "address_policy"):
                assert ready[name] == "invalid_http_proxy_options", ready
                report["checks"].append(dict(name=name, status="PASS", kind="policy", origin_requests=0))
            peer = launch("peer", [args.python, "integration/http3/upstream/peer.py", "--ports", json.dumps(ready["ports"]),
                          "--ca", str(directories[2] / "ca.pem")], "GAOXY_UPSTREAM_MATRIX_PEER", peer_events)
            while True:
                item = event(peer_events, 15)
                if item["event"] == "barrier":
                    command = item["command"]
                    if command == "origin_snapshot":
                        value = snapshot()
                    elif command == "matrix_finish_download":
                        send(origin, dict(command=command, id=item["id"]))
                        value = origin_until(lambda current: current["event"] == "matrix_released" and current["id"] == item["id"])
                    elif command == "cancel_observed":
                        request = next(request for request in snapshot() if request["id"] == item["id"])
                        def cancelled(current):
                            return ((current["event"] in ("reset", "stop_sending") and current.get("path") == request["path"]
                                     and current["connection"] == request["connection"]) or
                                    (current["event"] == "connection_closed" and current["connection"] == request["connection"]))
                        value = next((current for current in report["wire_events"] if cancelled(current)), None)
                        if value is None:
                            value = origin_until(cancelled)
                        report.setdefault("cancellation_receipts", []).append(dict(id=item["id"], observed=value))
                    elif command == "requests_completed":
                        sampled = requests_completed(item["expected"], item["protocol"])
                        validate_receipts(sampled, item["expected"], item["protocol"], item["case"])
                        report.setdefault("completion_barriers", []).append(dict(
                            protocol=item["protocol"], case=item["case"],
                            receipts=[receipt for receipt in sampled["receipts"]
                                      if receipt["id"] in {wanted["id"] for wanted in item["expected"]}]))
                        value = dict(receipts_validated=True, requests=len(item["expected"]))
                    elif command == "row_complete":
                        assert item["elapsed_ms"] < 5000, item
                        for wanted in item["expected"]:
                            assert wanted["id"] not in expected_requests, wanted
                            expected_requests[wanted["id"]] = wanted
                        sampled = baseline()
                        validate_requests(snapshot(), expected_requests)
                        validate_receipts(sampled, item["expected"], item["protocol"], item["case"])
                        report.setdefault("row_baselines", []).append(dict(
                            protocol=item["protocol"], case=item["case"], sample=sampled))
                        value = dict(active=0, retained_bytes=0, cleanup_pending=0, cleanup_failed=None,
                                     owned_guardians=0, origin_requests=sum(value.get("admitted", True) for value in expected_requests.values()))
                    else:
                        raise AssertionError(item)
                    send(peer, dict(status="ok", value=value))
                elif item["event"] == "check":
                    assert item["kind"] == "network" and item["status"] == "PASS" and item["name"] in required, item
                    assert item["name"] not in {value["name"] for value in report["checks"]}, item
                    report["checks"].append(item)
                elif item["event"] == "done":
                    executed = {value["name"] for value in report["checks"] if value["kind"] == "network"}
                    assert item["checks"] == len(executed) == len(required) == 66 and executed == required, item
                    peer.wait(timeout=remaining(5))
                    assert peer.returncode == 0
                    break
                else:
                    raise AssertionError(item)
            report["final_baseline"] = baseline()
            report["origin_requests"] = snapshot()
            validate_requests(report["origin_requests"], expected_requests)
            assert len(report["row_baselines"]) == 66
            assert len(report["completion_barriers"]) == 66
            assert {item["protocol"] + "_" + item["case"] for item in report["completion_barriers"]} == required
            assert len(report.get("cancellation_receipts", [])) == 12
            assert len(report["checks"]) == 68 and {item["name"] for item in report["checks"] if item["kind"] == "policy"} == {"absent_trust", "address_policy"}
            send(fixture, dict(command="stop"))
            stopped = event(fixture_events)
            assert stopped["event"] == "stopped" and stopped["runtime_down"] and stopped["observer_down"] and stopped["ports_rebound"], stopped
            assert stopped["elapsed_ms"] <= 5000, stopped
            fixture.wait(timeout=remaining(5))
            assert fixture.returncode == 0
            report["fixture_stop"] = stopped
            send(origin, dict(command="stop"))
            origin_until(lambda value: value["event"] == "stopped")
            origin.wait(timeout=remaining(5))
            assert origin.returncode == 0
            report["status"] = "PASS"
            report["executed_counts"] = dict(network_rows=66, policy_rows=2)
            report["not_run"] = ["standalone H3 origin", "release-artifact E2E", "deployment"]
    except FileNotFoundError as error:
        report["status"], report["blocker_kind"], report["error"] = "BLOCKED", "BLOCKED_ENV", repr(error)
    except BaseException as error:
        report["error"] = repr(error)
        if origin is not None and origin.poll() is None:
            try:
                report["failure_origin_requests"] = snapshot()
            except BaseException as diagnostic_error:
                report["origin_diagnostic_error"] = repr(diagnostic_error)
        if fixture is not None and fixture.poll() is None:
            try:
                report["failure_fixture_sample"] = sample()
            except BaseException as diagnostic_error:
                report["fixture_diagnostic_error"] = repr(diagnostic_error)
    finally:
        report["children"] = []
        for child in reversed(children):
            forced = child.poll() is None
            if forced and child in (origin, fixture):
                try:
                    send(child, dict(command="stop"))
                    child.wait(timeout=5)
                    forced = False
                except (AssertionError, BrokenPipeError, subprocess.TimeoutExpired):
                    pass
            shutdown(child)
            report["children"].append(dict(pid=child.pid, exit=child.returncode, forced_shutdown=forced))
        for reader in readers:
            reader.join(timeout=5)
        for log in logs:
            log.close()
        while not origin_events.empty():
            report["wire_events"].append(origin_events.get_nowait())
        report["ports_rebound"] = []
        for port in ports:
            try:
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as rebound:
                    rebound.bind(("127.0.0.1", port))
                report["ports_rebound"].append(port)
            except OSError as error:
                report["status"], report["rebind_error"] = "FAIL", repr(error)
        report["source_after_sha256"] = source_hashes()
        report["source_unchanged"] = report["source_after_sha256"] == report["source_sha256"]
        if not report["source_unchanged"] or any(reader.is_alive() for reader in readers) or any(
                value["exit"] is None or value["forced_shutdown"] for value in report["children"]):
            report["status"] = "FAIL"
        report["elapsed_ms"] = round((time.monotonic() - started) * 1000)
        report["actual_exit"] = 0 if report["status"] == "PASS" else 2 if report["status"] == "BLOCKED" else 1
        (evidence / "result.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(dict(status=report["status"], executed=len(report["checks"]), evidence=str(evidence), error=report.get("error"))))
    return report["actual_exit"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gate", choices=["contract", "session-contract", "matrix"], required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--python", default=os.environ.get("GAOXY_QUIC_PYTHON",
                        str(ROOT / "integration/quic_consumer/.venv/bin/python")))
    args = parser.parse_args()
    if args.gate == "matrix":
        return matrix(args)
    evidence = args.evidence / f"run-{time.time_ns()}"
    evidence.mkdir(parents=True, exist_ok=False)
    report = {"status": "FAIL", "gate": args.gate, "checks": [], "commands": [],
              "source_sha256": source_hashes(), "wire_events": [],
              "qualification_command": [sys.executable, *sys.argv],
              "counters": {"direct_session_sol_round": 2 if args.gate == "session-contract" else None,
                           "preceding_unsuccessful_sol": 2 if args.gate == "session-contract" else None,
                           "astra_recovery": 2 if args.gate == "session-contract" else None,
                           "preceding_unsuccessful_astra": 2 if args.gate == "session-contract" else None,
                           "astra_recovery_status": "two_rounds_exhausted" if args.gate == "session-contract" else None,
                           "coordinator_local_repair": 5 if args.gate == "session-contract" else None,
                           "preceding_unsuccessful_coordinator": 4 if args.gate == "session-contract" else None}}
    report["source_commit"] = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    report["branch"] = subprocess.check_output(
        ["git", "branch", "--show-current"], cwd=ROOT, text=True).strip()
    children, readers, logs, ports = [], [], [], []
    probe_events = queue.Queue()
    origin_events = queue.Queue()
    origin = None
    # A total runner deadline includes each readiness, public probe and wire barrier.
    deadline = time.monotonic() + 150

    def remaining(maximum):
        value = min(maximum, deadline - time.monotonic())
        assert value > 0, "total qualification deadline exceeded"
        return value

    def launch(command, filename, prefix, events, env=None):
        log = (evidence / filename).open("w")
        logs.append(log)
        child = subprocess.Popen(command, cwd=ROOT, env=env, stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1,
            start_new_session=True)
        children.append(child)
        report["commands"].append({"command": command})

        def read():
            for line in child.stdout:
                log.write(line)
                log.flush()
                if line.startswith(prefix + " "):
                    events.put(json.loads(line[len(prefix) + 1:]))

        reader = threading.Thread(target=read, daemon=True)
        reader.start()
        readers.append(reader)
        return child

    def send(child, command):
        child.stdin.write(json.dumps(command) + "\n")
        child.stdin.flush()

    def wire(predicate):
        for item in report["wire_events"]:
            if predicate(item):
                return item
        until = time.monotonic() + remaining(5)
        while time.monotonic() < until:
            item = origin_events.get(timeout=until - time.monotonic())
            report["wire_events"].append(item)
            if predicate(item):
                return item
        raise AssertionError("origin wire barrier missing")

    def snapshot():
        send(origin, {"command": "snapshot"})
        until = time.monotonic() + remaining(5)
        while True:
            item = origin_events.get(timeout=until - time.monotonic())
            report["wire_events"].append(item)
            if item["event"] == "snapshot":
                return item["requests"]

    def validate_session_snapshot(requests):
        report["origin_requests"] = requests
        expected = ["/ordinary", "/upload", "/tiny-upload", "/delayed-headers",
                    "/stalled-response", "/blocked-upload", "/owner-loss", "/guardian-loss"]
        expected += [f"/echo-{size}-{declaration}" for size in ("zero", "three")
                     for declaration in ("declared", "undeclared")]
        expected += ["/sibling-" + name for name in ("pending_headers",
                     "unacknowledged_response", "blocked_upload", "owner_loss", "guardian_loss")]
        assert len(requests) == 18, requests
        for path in expected:
            matches = [r for r in requests if r["path"] == path]
            assert len(matches) == (2 if path == "/ordinary" else 1), (path, matches)
        for request in requests:
            identity = request["origin"]
            port = ports[0 if identity == "a" else 1]
            assert [v for k, v in request["headers"] if k == ":authority"] == [f"localhost:{port}"], request
            assert request["certificate_sha256"] == report["certificate_sha256"][identity]["cert.pem"], request
            assert request["path"] in expected, request
        for path, body in (("/upload", b"abcdef"), ("/tiny-upload", b"x" * 1048576)):
            request = next(r for r in requests if r["path"] == path)
            assert request["request_fin"] and request["data_bytes"] == len(body), request
            assert request["data_sha256"] == hashlib.sha256(body).hexdigest(), request
            assert sum(e["event"] == "request_fin" and e.get("path") == path for e in report["wire_events"]) == 1
        for size, body in (("zero", b""), ("three", b"abc")):
            for declaration in ("declared", "undeclared"):
                path = f"/echo-{size}-{declaration}"
                request = next(r for r in requests if r["path"] == path)
                assert request["data_bytes"] == len(body), request
                assert request["data_sha256"] == hashlib.sha256(body).hexdigest(), request
                assert request["trailers"] == [["x-check", "one"], ["x-check", "two"]], request
                assert request["request_fin"] and request["trailer_blocks"] == 1, request
                assert [v for k, v in request["headers"] if k == "trailer"] == (["x-check"] if declaration == "declared" else []), request
                for event in ("trailers", "request_fin"):
                    assert sum(e["event"] == event and e.get("path") == path for e in report["wire_events"]) == 1, request

    def session_item(item):
        event = item["event"]
        if event == "environment":
            report["elixir_environment"] = item
            assert item["http_fetch"] == "0.21.4", item
        elif event == "barrier":
            name, path = item["name"], item.get("path")
            if name == "ordinary_progress":
                wire(lambda e: e["event"] == "headers" and e["origin"] == item["origin"] and e["path"] == path)
                send(origin, {"command": "finish_ordinary", "origin": item["origin"]})
                wire(lambda e: e["event"] == "response_fin" and e["origin"] == item["origin"] and e["path"] == path)
            elif name in ("upload_progress", "trailer_before_finish", "pending_headers", "blocked_upload", "owner_loss"):
                expected = item.get("bytes", 0 if item.get("zero") or name != "trailer_before_finish" else 3)
                wire(lambda e: e["event"] in ("headers", "data") and e.get("path") == path and e["origin"] == item["origin"] and e["data_bytes"] >= expected and (not e["request_fin"] or name in ("pending_headers", "owner_loss")))
            elif name in ("negative_before", "negative_after"):
                requests = snapshot()
                if name == "negative_before":
                    report.setdefault("negative_requests", {})[item["case"]] = requests
                else:
                    assert requests == report["negative_requests"][item["case"]], requests
            elif name in ("pause_upload", "resume_upload"):
                if name == "pause_upload":
                    wire(lambda e: e["event"] == "headers" and e.get("path") == path)
                send(origin, {"command": name})
                wire(lambda e: e["event"] == name)
            elif name == "cancel_observed":
                request = next(r for r in snapshot() if r["path"] == path)
                observed = wire(lambda e: (e["event"] in ("reset", "stop_sending") and e.get("path") == path) or (e["event"] == "connection_closed" and e["connection"] == request["connection"]))
                report.setdefault("cancellation_observed", []).append({"path": path, "event": observed})
            elif name == "finish_sibling":
                wire(lambda e: e["event"] == "headers" and e.get("path") == path)
                send(origin, {"command": name, "origin": item["origin"], "path": path})
                wire(lambda e: e["event"] == "response_fin" and e.get("path") == path)
            elif name == "final_snapshot":
                validate_session_snapshot(snapshot())
            else:
                raise AssertionError(item)
            probe.stdin.write("continue\n")
            probe.stdin.flush()
        elif event == "check":
            assert item["status"] == "PASS", item
            assert item["kind"] in ("network", "policy", "boundary_double"), item
            report["checks"].append(item)
        elif event == "cleanup_result":
            assert item["cleanup_outcome"] == "confirmed", item
            assert item["endpoint_stop"] == ":ok" and item["endpoint_down"] == ":normal", item
            assert item["guardian_down"] == item["stop_task_down"] == ":normal", item
            assert item["bind_port"] == item["rebound_port"], item
            assert item["tasks"] and all(t["down"] in (":normal", ":killed") for t in item["tasks"]), item
            report.setdefault("cleanup_results", []).append(item)
        elif event in ("public_result", "adoption", "request_ref", "blocked_write", "double_receipt"):
            report.setdefault("public_diagnostics", []).append(item)
        elif event == "guardian_loss_result":
            assert item["endpoint_stop"] == ":ok" and item["endpoint_down"] == item["caller_down"] == item["guardian_down"] == ":normal", item
            assert item["bind_port"] == item["rebound_port"] and item["creator_tasks"], item
            assert item["service_completion"].startswith("NOT CLAIMED"), item
            report.setdefault("guardian_loss_results", []).append(item)
        elif event == "done":
            network = {"ordinary_stream_a", "ordinary_stream_b", "progressive_upload", "tiny_window_1mib",
                "wrong_ca", "wrong_hostname", "network_idle_caller_failure", "network_guardian_after_connect", "network_guardian_paused_ack"}
            network |= {f"request_trailers_{size}_{declaration}" for size in ("zero", "three") for declaration in ("declared", "undeclared")}
            network |= {"cancel_" + name for name in ("pending_headers", "unacknowledged_response", "blocked_upload", "owner_loss")}
            policy = {"absent_trust", "address_policy"}
            doubles = {"unknown_connect_reconciled", "unknown_data_no_replay", "unknown_trailers_no_replay", "advanced_error_retained", "blocked_suspend_poll_resume",
                "guardian_loss_blocked_call", "caller_stale_generation_sequence", "caller_reconcile_read_hint_bound", "caller_survives_done_pending_consumption", "guardian_duplicate_result_rejected", "guardian_original_deadline_late_result", "idle_caller_failure_before_connect", "caller_down_before_stop_result", "guardian_normal_endpoint_stop", "creator_crash_after_adoption", "creator_crash_before_descriptor"}
            doubles |= {"ownership_" + stage for stage in ("before_adoption", "after_ack", "after_adoption", "stop_error", "abnormal_down", "before_descriptor", "missing_down", "cleanup_expiry")}
            doubles |= {"guardian_repeated_resume_original_deadline", "guardian_late_success_before_timer"}
            doubles |= {"guardian_normal_" + phase for phase in ("before_connect", "after_connect", "paused_ack")}
            doubles |= {"guardian_normal_bootstrap_" + phase for phase in ("allocation", "adoption")}
            expected_names = network | policy | doubles
            assert item["checks"] == len(report["checks"]) == len(expected_names) == 50, item
            assert {c["name"] for c in report["checks"]} == expected_names
            for kind, names in (("network", network), ("policy", policy), ("boundary_double", doubles)):
                assert {c["name"] for c in report["checks"] if c["kind"] == kind} == names
            report["executed_counts"] = {"network_rows": len(network), "policy_rows": len(policy), "boundary_double_rows": len(doubles)}
            assert len(report.get("cleanup_results", [])) == 20
            assert len(report.get("cancellation_observed", [])) == 4
            adoptions = [e for e in report["public_diagnostics"] if e["event"] == "adoption"]
            assert len(adoptions) == 22 and all(e["alive_after_creator_down"] and e["creator_down"] == ":normal" and e["caller_not_started"] and e["creator"] != e["guardian"] for e in adoptions)
            calls = [e for e in report["public_diagnostics"] if e["event"] == "public_result"]
            callers = {}
            for call in calls:
                key = (call["origin"], call["path"])
                callers.setdefault(key, set()).add(call["caller"])
                assert call["caller_alive"] and call["caller"] != "nil" and call["caller_high_water"] <= 16, call
            assert len(callers) == 22 and all(len(pids) == 1 for pids in callers.values())
            assert len(report.get("guardian_loss_results", [])) == 2
            blocked = [e for e in report["public_diagnostics"] if e["event"] == "blocked_write"]
            assert len(blocked) == 1 and blocked[0]["status"] in ("blocked", "unknown")
            assert any(r.get("owner_monitor_triggered") for r in report["cleanup_results"])
            probe.wait(timeout=remaining(5))
            assert probe.returncode == 0
            report["status"] = report["functional_status"] = report["cleanup_status"] = "PASS"
            report["not_run"] = ["production adapter UP1", "downstream matrix UP2", "standalone H3 origin"]
            return True
        else:
            raise AssertionError(item)
        return False

    try:
        with tempfile.TemporaryDirectory(prefix="gaoxy-upstream-public-") as temporary:
            directories = [Path(temporary) / "a", Path(temporary) / "b"]
            for identity, directory in zip(("a", "b"), directories):
                with (evidence / f"certificates-{identity}.log").open("w") as output:
                    credentials(directory, output, remaining)
                report["commands"].append({"command": "owned OpenSSL P-256 CA/leaf fixture + strict DNS verification",
                                           "exit": 0})
            report["certificate_sha256"] = {
                identity: {name: hashlib.sha256((directory / name).read_bytes()).hexdigest()
                           for name in ("ca.pem", "cert.pem")}
                for identity, directory in zip(("a", "b"), directories)}
            assert report["certificate_sha256"]["a"] != report["certificate_sha256"]["b"]
            version = subprocess.run([args.python, "-c", "import importlib.metadata,sys; "
                "print(sys.version); print(importlib.metadata.version('aioquic'))"],
                capture_output=True, text=True, timeout=remaining(10))
            assert version.returncode == 0 and version.stdout.splitlines()[-1] == "1.2.0", version
            report["python_environment"] = version.stdout.splitlines()
            origin = launch([args.python, "integration/http3/upstream/origin.py",
                "--cert-a", str(directories[0]), "--cert-b", str(directories[1])],
                "origin.log", "GAOXY_UPSTREAM_ORIGIN", origin_events)
            ready = wire(lambda e: e["event"] == "ready")
            ports = ready["ports"]
            env = dict(os.environ, MIX_ENV="test", ERL_FLAGS="+S 2:2")
            for identity, directory, port in zip(("A", "B"), directories, ports):
                env["GAOXY_UPSTREAM_URL_" + identity] = f"https://localhost:{port}"
                env["GAOXY_UPSTREAM_CA_" + identity] = str(directory / "ca.pem")
            probe = launch(["mix", "run", "--no-compile", "--no-start",
                ("integration/http3/upstream/session_probe.exs" if args.gate == "session-contract"
                 else "integration/http3/upstream/probe.exs")], "probe.log",
                "GAOXY_UPSTREAM_PROBE", probe_events, env)
            while True:
                try:
                    item = probe_events.get(timeout=remaining(15))
                except queue.Empty as error:
                    raise AssertionError(f"probe event missing; child exit={probe.poll()}; inspect probe.log") from error
                if args.gate == "session-contract":
                    if session_item(item):
                        break
                    continue
                if item["event"] == "environment":
                    report["elixir_environment"] = item
                    assert item["http_fetch"] == "0.21.4", item
                    exports = item["public_session_functions"]
                    assert "request/4" in exports and "send_data/5" in exports, exports
                    report["session_api_coverage"] = {"functions": exports,
                        "status": "public APIs recorded",
                        "kind": "public export audit, not another live test"}
                elif item["event"] == "barrier":
                    name = item["name"]
                    if name == "ordinary_progress":
                        wire(lambda e: e["event"] == "headers" and
                             e["origin"] == item["origin"] and e["path"] == item["path"])
                        send(origin, {"command": "finish_ordinary", "origin": item["origin"]})
                        wire(lambda e: e["event"] == "response_fin" and
                             e["origin"] == item["origin"])
                    elif name in ("upload_progress", "trailer_before_finish", "pending_headers"):
                        expected = 0 if name == "pending_headers" or item.get("zero") else 3
                        wire(lambda e: e["event"] in ("headers", "data") and
                             e["origin"] == item["origin"] and e["path"] == item["path"] and
                             e["data_bytes"] == expected and not e["request_fin"]
                             if name != "pending_headers" else
                             e["event"] == "headers" and e["path"] == item["path"])
                    elif name in ("negative_before", "negative_after"):
                        send(origin, {"command": "snapshot"})
                        until = time.monotonic() + remaining(5)
                        while True:
                            snapshot = origin_events.get(timeout=until - time.monotonic())
                            report["wire_events"].append(snapshot)
                            if snapshot["event"] == "snapshot":
                                break
                        if name == "negative_before":
                            report.setdefault("negative_requests", {})[item["case"]] = snapshot["requests"]
                        else:
                            assert snapshot["requests"] == report["negative_requests"][item["case"]], snapshot
                    elif name in ("pause_upload", "resume_upload"):
                        if name == "pause_upload":
                            wire(lambda e: e["event"] == "headers" and e["path"] == item["path"])
                        send(origin, {"command": name})
                        wire(lambda e: e["event"] == name)
                    elif name in ("blocked_upload", "owner_loss"):
                        wire(lambda e: e["event"] == "headers" and e["path"] == item["path"])
                    elif name == "final_snapshot":
                        send(origin, {"command": "snapshot"})
                        # Earlier negative snapshots cannot satisfy this fresh barrier.
                        until = time.monotonic() + remaining(5)
                        while True:
                            snapshot = origin_events.get(timeout=until - time.monotonic())
                            report["wire_events"].append(snapshot)
                            if snapshot["event"] == "snapshot":
                                break
                        report["origin_requests"] = snapshot["requests"]
                        expected_paths = ["/ordinary", "/upload", "/delayed-headers", "/stalled-response",
                                          "/blocked-upload", "/owner-loss"]
                        expected_paths += [f"/echo-{size}-{declaration}" for size in ("zero", "three")
                                           for declaration in ("declared", "undeclared")]
                        assert len(snapshot["requests"]) == 11, snapshot
                        for request in snapshot["requests"]:
                            identity = request["origin"]
                            port = ports[0 if identity == "a" else 1]
                            authority = [v for k, v in request["headers"] if k == ":authority"]
                            assert authority == [f"localhost:{port}"], request
                            assert request["certificate_sha256"] == report["certificate_sha256"][identity]["cert.pem"], request
                            assert request["path"] in expected_paths, request
                        for identity in ("a", "b"):
                            assert sum(r["path"] == "/ordinary" and r["origin"] == identity
                                       for r in snapshot["requests"]) == 1
                        for path in expected_paths:
                            assert sum(r["path"] == path for r in snapshot["requests"]) == (2 if path == "/ordinary" else 1), path
                        uploaded = next(r for r in snapshot["requests"] if r["path"] == "/upload")
                        assert uploaded["request_fin"] and uploaded["data_bytes"] == 6, uploaded
                        assert uploaded["data_sha256"] == hashlib.sha256(b"abcdef").hexdigest(), uploaded
                        for size, body in (("three", b"abc"), ("zero", b"")):
                            for declaration in ("declared", "undeclared"):
                                path = f"/echo-{size}-{declaration}"
                                requests = [r for r in snapshot["requests"] if r["path"] == path]
                                assert len(requests) == 1, requests
                                request = requests[0]
                                assert request["data_bytes"] == len(body), request
                                assert request["data_sha256"] == hashlib.sha256(body).hexdigest(), request
                                assert request["trailers"] == [["x-check", "one"], ["x-check", "two"]], request
                                assert request["request_fin"] and request["trailer_blocks"] == 1, request
                                declarations = [v for k, v in request["headers"] if k == "trailer"]
                                assert declarations == (["x-check"] if declaration == "declared" else []), request
                                assert sum(e["event"] == "trailers" and e.get("path") == path
                                           for e in report["wire_events"]) == 1, request
                                assert sum(e["event"] == "request_fin" and e.get("path") == path
                                           for e in report["wire_events"]) == 1, request
                        for path in ("/delayed-headers", "/stalled-response", "/blocked-upload", "/owner-loss"):
                            request = next(r for r in snapshot["requests"] if r["path"] == path)
                            observed = wire(lambda e: (e["event"] in ("reset", "stop_sending") and
                                            e.get("path") == path) or
                                            (e["event"] == "connection_closed" and
                                             e["connection"] == request["connection"]))
                            report.setdefault("cancellation_observed", []).append({"path": path, "event": observed})
                    else:
                        raise AssertionError(item)
                    probe.stdin.write("continue\n")
                    probe.stdin.flush()
                elif item["event"] == "check":
                    assert item["status"] == "PASS", item
                    report["checks"].append(item)
                elif item["event"] == "done":
                    assert item["checks"] == len(report["checks"]) == 15, item
                    assert len({c["name"] for c in report["checks"]}) == 15
                    blocked = [d for d in report.get("public_diagnostics", []) if d["event"] == "blocked_write"]
                    assert len(blocked) == 1 and 1 <= blocked[0]["index"] <= 128
                    assert blocked[0]["result"] == "{:error, :timeout}"
                    probe.wait(timeout=remaining(5))
                    assert probe.returncode == 0, probe.returncode
                    report["status"] = "PASS"
                    report["functional_status"] = "PASS"
                    report["not_run"] = ["production adapter and UP2 downstream matrix"]
                    cleanup = report.get("cleanup_results", [])
                    assert len(cleanup) == 4, cleanup
                    assert len(report.get("normal_completion_results", [])) == 7
                    outcomes = cleanup + report["normal_completion_results"]
                    report["cleanup_status"] = ("PASS" if all(c["result"] == ":ok" for c in outcomes)
                        else "UNSUPPORTED" if all(c["result"] == "{:error, {:unsupported_completion, :http_version}}"
                                                  for c in outcomes) else "BLOCKED")
                    if any(item["result"] != ":ok" for item in outcomes):
                        report["status"] = "BLOCKED"
                        report["blocker"] = "public cleanup completion unqualified; task/stream DOWN and remote cancellation recorded separately"
                    break
                elif item["event"] == "cleanup_result":
                    report.setdefault("cleanup_results", []).append(item)
                elif item["event"] == "normal_completion_result":
                    report.setdefault("normal_completion_results", []).append(item)
                elif item["event"] in ("completion_diagnostic", "blocked_write"):
                    report.setdefault("public_diagnostics", []).append(item)
                else:
                    raise AssertionError(item)
            send(origin, {"command": "stop"})
            origin.wait(timeout=remaining(5))
            assert origin.returncode == 0, origin.returncode
    except FileNotFoundError as error:
        report["status"] = "BLOCKED" if args.gate == "session-contract" else "FAIL"
        report["blocker_kind"] = "BLOCKED_ENV"
        report["error"] = repr(error)
    except BaseException as error:
        report["status"] = "FAIL"
        report["error"] = repr(error)
    finally:
        for child in children:
            if child is origin and child.poll() is None:
                try:
                    send(child, {"command": "stop"})
                    child.wait(timeout=5)
                except (BrokenPipeError, subprocess.TimeoutExpired):
                    pass
            shutdown(child)
        for reader in readers:
            reader.join(timeout=5)
        for log in logs:
            log.close()
        while not origin_events.empty():
            report["wire_events"].append(origin_events.get_nowait())
        report["children"] = [{"pid": c.pid, "exit": c.returncode} for c in children]
        report["source_after_sha256"] = source_hashes()
        report["source_unchanged"] = report["source_after_sha256"] == report["source_sha256"]
        report["ports_rebound"] = []
        for port in ports:
            try:
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as rebound:
                    rebound.bind(("127.0.0.1", port))
                report["ports_rebound"].append(port)
            except OSError as error:
                report["status"] = "FAIL"
                report["rebind_error"] = repr(error)
        if not report["source_unchanged"] or any(c.returncode is None for c in children):
            report["status"] = "FAIL"
        report["actual_exit"] = 0 if report["status"] == "PASS" else 2 if report["status"] == "BLOCKED" else 1
        report["environment"] = {"MIX_ENV": "test", "ERL_FLAGS": "+S 2:2"}
        (evidence / "result.json").write_text(json.dumps(report, indent=2) + "\n")

    print(json.dumps({"status": report["status"], "executed": len(report["checks"]),
                      "evidence": str(evidence), "error": report.get("error")}))
    return 0 if report["status"] == "PASS" else 2 if report["status"] == "BLOCKED" else 1


if __name__ == "__main__":
    raise SystemExit(main())
