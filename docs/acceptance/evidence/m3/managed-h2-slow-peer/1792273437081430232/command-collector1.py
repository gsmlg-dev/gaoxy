#!/usr/bin/env python3
"""Serial root-owned command receipt; it never converts failure to acceptance."""
import argparse
import ctypes
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
    paths += [str(path.relative_to(ROOT)) for path in EVIDENCE.glob("*") if path.suffix in (".py", ".exs") and path.is_file()]
    paths += [str(Path(__file__).relative_to(ROOT))]
    return {name: digest(ROOT / name) for name in sorted(set(paths))
            if (ROOT / name).is_file() and "__pycache__" not in name}


def children():
    """Only this collector's descendants, including independently sessioned actors."""
    found, pending = set(), [os.getpid()]
    while pending:
        parent = pending.pop()
        try:
            values = Path(f'/proc/{parent}/task/{parent}/children').read_text().split()
        except FileNotFoundError:
            continue
        for value in values:
            pid = int(value)
            if pid not in found:
                found.add(pid)
                pending.append(pid)
    return found

def cleanup_descendants():
    """Join already-exited adopted children before any force; live residue fails."""
    deadline = time.monotonic() + 15
    initial, reaped, signals = children(), [], []
    reap_deadline_exhausted = []

    def reap_ready(phase):
        while True:
            if time.monotonic() >= deadline:
                reap_deadline_exhausted.append(phase)
                return
            try:
                pid, status = os.waitpid(-1, os.WNOHANG)
            except ChildProcessError:
                return
            if pid == 0:
                return
            reaped.append({'pid': pid, 'wait_status': status, 'phase': phase})

    # A zombie requires its actual wait, rather than an attempted group signal.
    reap_ready('before_force')
    pending = children()
    initial_after_reap = sorted(pending)
    forced = bool(pending) or bool(reap_deadline_exhausted)
    while pending:
        for pid in pending:
            try:
                pgid = os.getpgid(pid)
                assert pgid != os.getpgrp(), 'owned actor shares collector group'
                sig = signal.SIGTERM if time.monotonic() < deadline - 12 else signal.SIGKILL
                forced = True
                attempt = {'pid': pid, 'pgid': pgid, 'signal': int(sig), 'outcome': 'attempted'}
                signals.append(attempt)
                os.killpg(pgid, sig)
                attempt['outcome'] = 'syscall_returned_success'
            except ProcessLookupError:
                if signals and signals[-1]['pid'] == pid and signals[-1]['outcome'] == 'attempted':
                    signals[-1]['outcome'] = 'process_lookup_race'
        reap_ready('after_force')
        forced = forced or bool(reap_deadline_exhausted)
        pending = children()
        if not pending or time.monotonic() >= deadline:
            break
        time.sleep(.02)
    return {'forced': forced, 'initial': sorted(initial),
            'initial_after_reap': initial_after_reap,
            'reaped_before_force': [row for row in reaped if row['phase'] == 'before_force'],
            'signal_attempts': signals, 'reaped': reaped,
            'reap_deadline_exhausted': reap_deadline_exhausted, 'remaining': sorted(pending)}


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
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(36, 1, 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), "PR_SET_CHILD_SUBREAPER")
    before = source_manifest()
    start = time.monotonic()
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    forced = False
    wait_error, process, actual_exit = None, None, None
    try:
        with log.open("xb") as output:
            process = subprocess.Popen(command, cwd=ROOT, stdout=output,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                actual_exit = process.wait(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                forced = True
                for sig in (signal.SIGTERM, signal.SIGKILL):
                    try:
                        os.killpg(process.pid, sig)
                    except ProcessLookupError:
                        pass  # A concurrent exit still owes an actual wait.
                    try:
                        actual_exit = process.wait(timeout=10)
                        break
                    except subprocess.TimeoutExpired:
                        continue
                if actual_exit is None:
                    raise TimeoutError("command did not join after KILL")
    except BaseException as error:
        wait_error = f"{type(error).__name__}: {error}"
    finally:
        descendants = cleanup_descendants()
        if process is not None and actual_exit is None:
            own = next((row for row in descendants["reaped"]
                        if row["pid"] == process.pid), None)
            if own is not None:
                actual_exit = os.waitstatus_to_exitcode(own["wait_status"])
                process.returncode = actual_exit
            elif process.poll() is not None:
                actual_exit = process.returncode
    remaining = subprocess.check_output(
        ["ps", "-eo", "pid=,pgid=,stat=,comm="], text=True,
    ).splitlines()
    remaining = [line.strip() for line in remaining
                 if process is not None and int(line.split()[1]) == process.pid]
    after = source_manifest()
    plain = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", log.read_text(errors="replace"))
    summaries = re.findall(r"(\d+) tests?, (\d+) failures?([^\n]*)", plain)
    reported_tests = sum(int(row[0]) for row in summaries)
    failures = sum(int(row[1]) for row in summaries)
    excluded = sum(int(n) for n in re.findall(r"(\d+) excluded", plain))
    skipped = sum(int(n) for n in re.findall(r"(\d+) skipped", plain))
    tests = reported_tests - excluded - skipped
    warnings = [line for line in plain.splitlines() if "warning:" in line
                and not line.startswith("warning: Git tree ")]
    stable = before == after
    verdict = "PASS" if actual_exit == 0 and wait_error is None and not forced and stable and not remaining and not descendants["forced"] and not descendants["remaining"] else "FAIL"
    if args.kind == "red":
        verdict = "INTENDED_RED_REQUIRES_ASSERTION_AUDIT" if actual_exit is not None and actual_exit != 0 and wait_error is None and tests > 0 and failures > 0 and stable and not forced and not remaining and not descendants["forced"] and not descendants["remaining"] else "FAIL"
    if args.kind == "green" and (tests == 0 or failures or skipped or excluded or warnings):
        verdict = "FAIL"
    browser = None
    data = dict(name=args.name, kind=args.kind, verdict=verdict, at_utc=started,
                elapsed_seconds=time.monotonic()-start, command=command,
                cwd=str(ROOT), environment={"MIX_ENV": "test", "ERL_FLAGS": "+S 2:2"},
                pid=process.pid if process is not None else None,
                actual_exit=actual_exit, forced=forced, wait_error=wait_error,
                process_joined=process is not None and process.returncode is not None,
                process_group_remaining=remaining, descendant_cleanup=descendants, tests=tests, reported_tests=reported_tests, failures=failures,
                skipped=skipped, excluded=excluded, warnings=warnings,
                source_stable=stable, browser=browser, source_before=before, source_after=after,
                source_changes=[name for name in sorted(set(before)|set(after))
                                if before.get(name) != after.get(name)],
                log=log.name, log_sha256=digest(log), collector_sha256=digest(Path(__file__)))
    receipt.write_text(json.dumps(data, indent=2)+"\n")
    print(json.dumps({key:data[key] for key in ["name","verdict","actual_exit","forced",
                     "tests","failures","skipped","excluded","warnings","source_stable","browser",
                     "process_joined","process_group_remaining","elapsed_seconds"]}), flush=True)
    if args.kind == "red":
        return 0 if verdict == "INTENDED_RED_REQUIRES_ASSERTION_AUDIT" else 1
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
