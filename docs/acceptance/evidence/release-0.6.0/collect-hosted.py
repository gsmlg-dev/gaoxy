#!/usr/bin/env python3
"""Capture immutable hosted attempt metadata and raw logs without a rerun."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import subprocess

p = argparse.ArgumentParser()
p.add_argument("run", type=int)
p.add_argument("attempt", type=int)
args = p.parse_args()
base = Path(__file__).resolve().parent / "hosted-ci"
out = base / f"run-{args.run}-attempt-{args.attempt}"
out.mkdir()
receipt = {"source": "aaa613985b08edd146f393ddd48f65fd6f3665b2",
           "run_id": args.run, "attempt": args.attempt,
           "captured_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
           "commands": []}
def run(argv, filename):
    r = subprocess.run(argv, capture_output=True, timeout=180)
    path = out / filename
    path.write_bytes(r.stdout)
    err = out / (filename + ".stderr")
    err.write_bytes(r.stderr)
    receipt["commands"].append({"argv": argv, "exit": r.returncode, "output": filename,
                                "sha256": hashlib.sha256(r.stdout).hexdigest(),
                                "stderr": err.name,
                                "stderr_sha256": hashlib.sha256(r.stderr).hexdigest()})
    (out / "capture.json").write_text(json.dumps(receipt, indent=2) + "\n")
    assert r.returncode == 0, (argv, r.returncode, r.stderr.decode(errors="replace"))
    return r.stdout
info = json.loads(run(["gh", "api", f"repos/gsmlg-dev/gaoxy/actions/runs/{args.run}/attempts/{args.attempt}"], "run.json"))
assert info["head_sha"] == receipt["source"] and info["status"] == "completed"
assert info["run_attempt"] == args.attempt
jobs = json.loads(run(["gh", "api", f"repos/gsmlg-dev/gaoxy/actions/runs/{args.run}/attempts/{args.attempt}/jobs?per_page=100"], "jobs.json"))
assert jobs["total_count"] == len(jobs["jobs"]) and jobs["jobs"]
raw = run(["gh", "run", "view", str(args.run), "--repo", "gsmlg-dev/gaoxy", "--attempt", str(args.attempt), "--log"], "logs.txt")
receipt.update(status=info["conclusion"].upper(),
               name=info["name"], html_url=info["html_url"],
               jobs=[{"name": j["name"], "conclusion": j["conclusion"], "id": j["id"]} for j in jobs["jobs"]],
               gate_lines=[line for line in raw.decode(errors="replace").splitlines()
                           if any(k in line for k in ("REPAIR_PASS", "REPAIR_FAIL", "Result:", "tests, 0 failures"))])
(out / "capture.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps({"directory": str(out), "status": receipt["status"], "jobs": receipt["jobs"], "gate_lines": len(receipt["gate_lines"])}))

