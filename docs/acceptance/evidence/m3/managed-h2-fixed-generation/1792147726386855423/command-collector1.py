#!/usr/bin/env python3
"""Serial root-owned command receipt; it never converts failure to acceptance."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[6]
EVIDENCE = Path(__file__).resolve().parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_manifest():
    paths = subprocess.check_output(
        ["rg", "--files", "--hidden", "apps", "config", "scripts", "integration"],
        cwd=ROOT, text=True,
    ).splitlines()
    paths += ["mix.exs", "mix.lock", ".formatter.exs", "AGENTS.md"]
    return {name: digest(ROOT / name) for name in sorted(set(paths))
            if (ROOT / name).is_file() and "__pycache__" not in name}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--kind", choices=["green", "red", "static"], default="green")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    assert command and re.fullmatch(r"[a-z0-9-]+", args.name)
    receipt = EVIDENCE / (args.name + ".json")
    log = EVIDENCE / (args.name + ".log")
    assert not receipt.exists() and not log.exists(), "immutable output already exists"
    before = source_manifest()
    start = time.monotonic()
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    forced = False
    with log.open("wb") as output:
        process = subprocess.Popen(command, cwd=ROOT, stdout=output,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            actual_exit = process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            forced = True
            os.killpg(process.pid, signal.SIGTERM)
            try:
                actual_exit = process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                actual_exit = process.wait(timeout=10)
    remaining = subprocess.check_output(
        ["ps", "-eo", "pid=,pgid=,stat=,comm="], text=True,
    ).splitlines()
    remaining = [line.strip() for line in remaining
                 if int(line.split()[1]) == process.pid]
    after = source_manifest()
    plain = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", log.read_text(errors="replace"))
    summaries = re.findall(r"(\d+) tests?, (\d+) failures?([^\n]*)", plain)
    tests = sum(int(row[0]) for row in summaries)
    failures = sum(int(row[1]) for row in summaries)
    excluded = sum(int(n) for n in re.findall(r"(\d+) excluded", plain))
    skipped = sum(int(n) for n in re.findall(r"(\d+) skipped", plain))
    warnings = [line for line in plain.splitlines() if "warning:" in line
                and not line.startswith("warning: Git tree ")]
    stable = before == after
    verdict = "PASS" if actual_exit == 0 and not forced and stable and not remaining else "FAIL"
    if args.kind == "red":
        verdict = "INTENDED_RED_REQUIRES_ASSERTION_AUDIT" if actual_exit != 0 and tests > 0 and failures > 0 and stable and not forced and not remaining else "FAIL"
    data = dict(name=args.name, kind=args.kind, verdict=verdict, at_utc=started,
                elapsed_seconds=time.monotonic()-start, command=command,
                cwd=str(ROOT), environment={"MIX_ENV": "test", "ERL_FLAGS": "+S 2:2"},
                pid=process.pid, actual_exit=actual_exit, forced=forced,
                process_joined=process.returncode is not None,
                process_group_remaining=remaining, tests=tests, failures=failures,
                skipped=skipped, excluded=excluded, warnings=warnings,
                source_stable=stable, source_before=before, source_after=after,
                source_changes=[name for name in sorted(set(before)|set(after))
                                if before.get(name) != after.get(name)],
                log=log.name, log_sha256=digest(log), collector_sha256=digest(Path(__file__)))
    receipt.write_text(json.dumps(data, indent=2)+"\n")
    print(json.dumps({key:data[key] for key in ["name","verdict","actual_exit","forced",
                     "tests","failures","skipped","excluded","warnings","source_stable",
                     "process_joined","process_group_remaining","elapsed_seconds"]}), flush=True)
    if args.kind == "red":
        return 0 if verdict == "INTENDED_RED_REQUIRES_ASSERTION_AUDIT" else 1
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
