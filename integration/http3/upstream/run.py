#!/usr/bin/env python3
"""Bounded public Fetch qualification; exit 2 for a reproduced required feature gap."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import queue
import signal
import socket
import subprocess
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
subjectAltName=DNS:localhost,IP:127.0.0.1
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
             "apps/gaoxy_proxy/mix.exs", "scripts/generate-fixtures.sh")]
    files += list((ROOT / "integration/http3/upstream").glob("*"))
    for dependency in ("http_fetch", "http_runtime", "http_core", "elixir_quic",
                       "elixir_quic_http3", "ex_ssl"):
        base = ROOT / "deps" / dependency
        files += list((base / "lib").rglob("*.ex")) + [base / "mix.exs"]
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gate", choices=["contract"], required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--python", default=os.environ.get("GAOXY_QUIC_PYTHON",
                        str(ROOT / "integration/quic_consumer/.venv/bin/python")))
    args = parser.parse_args()
    evidence = args.evidence / f"run-{time.time_ns()}"
    evidence.mkdir(parents=True)
    report = {"status": "FAIL", "gate": args.gate, "checks": [], "commands": [],
              "source_sha256": source_hashes(), "wire_events": []}
    report["source_commit"] = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    report["branch"] = subprocess.check_output(
        ["git", "branch", "--show-current"], cwd=ROOT, text=True).strip()
    children, readers, logs, ports = [], [], [], []
    probe_events = queue.Queue()
    origin_events = queue.Queue()
    origin = None
    # A total runner deadline includes each readiness, public probe and wire barrier.
    deadline = time.monotonic() + 100

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
                "integration/http3/upstream/probe.exs"], "probe.log",
                "GAOXY_UPSTREAM_PROBE", probe_events, env)
            while True:
                item = probe_events.get(timeout=remaining(15))
                if item["event"] == "environment":
                    report["elixir_environment"] = item
                    assert item["http_fetch"] == "0.21.3", item
                    exports = item["public_session_functions"]
                    assert "request/4" in exports and "send_data/5" in exports, exports
                    report["session_api_coverage"] = {"functions": exports,
                        "status": "UNSUPPORTED request trailing HEADERS operation in this cohort",
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
                    elif name == "final_snapshot":
                        send(origin, {"command": "snapshot"})
                        snapshot = wire(lambda e: e["event"] == "snapshot")
                        report["origin_requests"] = snapshot["requests"]
                        for path, body in (("/echo-three", b"abc"), ("/echo-zero", b"")):
                            requests = [r for r in snapshot["requests"] if r["path"] == path]
                            assert len(requests) == 1, requests
                            request = requests[0]
                            assert request["data_bytes"] == len(body), request
                            assert request["data_sha256"] == hashlib.sha256(body).hexdigest(), request
                            assert request["trailers"] == [] and not request["request_fin"], request
                            assert not any(name == "trailer" for name, _ in request["headers"]), request
                        for path in ("/delayed-headers", "/stalled-response"):
                            request = next(r for r in snapshot["requests"] if r["path"] == path)
                            observed = wire(lambda e: e["event"] in ("reset", "stop_sending") and
                                            e.get("path") == path or
                                            e["event"] == "connection_closed" and
                                            e["connection"] == request["connection"])
                            report.setdefault("cancellation_observed", []).append(observed)
                    else:
                        raise AssertionError(item)
                    probe.stdin.write("continue\n")
                    probe.stdin.flush()
                elif item["event"] == "check":
                    assert item["status"] in ("PASS", "BLOCKED"), item
                    report["checks"].append(item)
                elif item["event"] == "done":
                    assert item["checks"] == len(report["checks"]) == 7, item
                    assert sum(c["status"] == "BLOCKED" for c in report["checks"]) == 2
                    probe.wait(timeout=remaining(5))
                    assert probe.returncode == 0, probe.returncode
                    report["status"] = "BLOCKED"
                    report["blocker"] = item["reason"]
                    report["not_run"] = ["production adapter and UP2 downstream matrix",
                        "wrong CA/hostname, absent trust and connect_address negative probes",
                        "blocked-upload and owner-loss cancellation alternatives"]
                    break
                else:
                    raise AssertionError(item)
            send(origin, {"command": "stop"})
            origin.wait(timeout=remaining(5))
            assert origin.returncode == 0, origin.returncode
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
        (evidence / "result.json").write_text(json.dumps(report, indent=2) + "\n")
        (args.evidence / "latest.json").write_text(json.dumps({"run": evidence.name,
            "status": report["status"], "executed": len(report["checks"])}, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "executed": len(report["checks"]),
                      "evidence": str(evidence), "error": report.get("error")}))
    return 2 if report["status"] == "BLOCKED" else 1


if __name__ == "__main__":
    raise SystemExit(main())
