#!/usr/bin/env python3
"""Run local publication-source qualification with immutable per-run evidence."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(tempfile.mkdtemp(prefix="local-qualification-", dir=Path(__file__).resolve().parent))
ENV = dict(os.environ, MIX_ENV="test", ELIXIR_ERL_OPTIONS="+S 2:2",
           GAOXY_QUIC_PYTHON=str(ROOT / ".audit/h2peer/bin/python"),
           GAOXY_H2_PYTHON=str(ROOT / ".audit/h2peer/bin/python"),
           SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt", PIP_CERT="/etc/ssl/certs/ca-certificates.crt")
paths = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z", "--",
    "apps", "vendor", "scripts", "integration", ".github", "mix.exs", "mix.lock"], cwd=ROOT).decode().split("\0")
fingerprints = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in sorted(set(paths)) if p and (ROOT / p).is_file()}
receipt = {"status": "RUNNING", "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
           "baseline": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
           "environment": {k: ENV[k] for k in ["MIX_ENV", "ELIXIR_ERL_OPTIONS", "GAOXY_QUIC_PYTHON", "GAOXY_H2_PYTHON", "SSL_CERT_FILE", "PIP_CERT"]},
           "source_fingerprints": fingerprints, "gates": []}


def save():
    (OUT / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")


commands = [
    ("inventory", ["python3", "scripts/check-test-inventory.py"], 60),
    ("format", ["mix", "format", "--check-formatted"], 60),
    ("compile", ["mix", "compile", "--warnings-as-errors"], 300),
    ("ordinary", ["python3", "scripts/check-repairs.py", "all"], 1200),
    ("staging", ["python3", "scripts/test-stage-hex-packages.py"], 300),
    ("consumers", ["python3", "scripts/test-consumers.py"], 900),
]
save()
print(f"QUALIFICATION_RECEIPT {OUT / 'receipt.json'}", flush=True)
try:
    for name, command, timeout in commands:
        entry = {"name": name, "command": command, "status": "RUNNING", "timeout_seconds": timeout,
                 "log": str(OUT / (name + ".log")), "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
        receipt["gates"].append(entry)
        save()
        started = time.monotonic()
        with Path(entry["log"]).open("wb") as log:
            process = subprocess.Popen(command, cwd=ROOT, env=ENV, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            entry["pid"] = process.pid
            try:
                entry["exit"] = process.wait(timeout=timeout)
            except BaseException:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=5)
                entry["exit"] = process.returncode
                raise
        entry.update(seconds=round(time.monotonic() - started, 3),
                     log_sha256=hashlib.sha256(Path(entry["log"]).read_bytes()).hexdigest(),
                     status="PASS" if entry["exit"] == 0 else "FAIL")
        save()
        print(json.dumps(entry), flush=True)
        if entry["exit"]:
            raise RuntimeError(f"{name} failed; inspect retained log before retry")
    changed = [p for p, expected in fingerprints.items() if hashlib.sha256((ROOT / p).read_bytes()).hexdigest() != expected]
    if changed:
        raise RuntimeError(f"qualification source changed: {changed}")
    receipt["status"] = "PASS"
except BaseException as error:
    receipt.update(status="FAIL", error=f"{type(error).__name__}: {error}")
finally:
    receipt["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save()
    print(json.dumps({"status": receipt["status"], "receipt": str(OUT / "receipt.json"), "error": receipt.get("error")}), flush=True)
raise SystemExit(0 if receipt["status"] == "PASS" else 1)
