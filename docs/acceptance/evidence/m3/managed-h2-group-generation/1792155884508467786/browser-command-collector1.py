#!/usr/bin/env python3
"""Actual bounded browser command, joins and immutable source/receipt binding."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

ROOT = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
EVIDENCE = Path(__file__).resolve().parent

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def group_alive(pid):
    try:
        os.killpg(pid, 0)
        return True
    except ProcessLookupError:
        return False

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
    """Subreaping keeps actor ownership after runner death; forcing always fails."""
    initial, reaped = children(), []
    deadline = time.monotonic() + 15
    while True:
        for pid in children():
            try:
                pgid = os.getpgid(pid)
                assert pgid != os.getpgrp(), 'owned actor shares collector group'
                os.killpg(pgid, signal.SIGTERM if time.monotonic() < deadline - 12
                          else signal.SIGKILL)
            except ProcessLookupError:
                pass
        while True:
            try:
                pid, status = os.waitpid(-1, os.WNOHANG)
            except ChildProcessError:
                break
            if pid == 0:
                break
            reaped.append({'pid': pid, 'wait_status': status})
        remaining = children()
        if not remaining or time.monotonic() >= deadline:
            return {'forced': bool(initial), 'initial': sorted(initial),
                    'reaped': reaped, 'remaining': sorted(remaining)}
        time.sleep(.02)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--name', required=True)
    parser.add_argument('--receipt', required=True)
    parser.add_argument('--runner', required=True)
    args = parser.parse_args()
    for name in (args.name, args.receipt, args.runner):
        assert Path(name).name == name and name not in ('.', '..')
    destination = EVIDENCE / (args.receipt + '.json')
    log = EVIDENCE / (args.receipt + '.log')
    directory = EVIDENCE / args.name
    assert not destination.exists() and not log.exists() and not directory.exists()
    names = set(subprocess.check_output(
        ['rg', '--files', '--hidden', 'apps', 'config', 'scripts', 'integration'],
        cwd=ROOT, text=True).splitlines())
    names = {name for name in names if '__pycache__' not in name}
    names.update(['mix.exs', 'mix.lock', '.formatter.exs', 'AGENTS.md'])
    names.update(str(path.relative_to(ROOT)) for path in EVIDENCE.glob('group-generation-browser-*') if path.is_file())
    names.add(str(Path(__file__).relative_to(ROOT)))
    snapshot = lambda: {name: sha(ROOT / name) for name in sorted(names)}
    before = snapshot()
    # Linux PR_SET_CHILD_SUBREAPER: orphaned peer/host/Chrome sessions stay ours.
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(36, 1, 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), 'PR_SET_CHILD_SUBREAPER')
    command = [sys.executable, '-B', str(EVIDENCE / args.runner), '--evidence-dir', str(directory)]
    started = time.monotonic()
    timed_out = False
    wait_error, process, actual = None, None, None
    try:
        with log.open('xb') as output:
            process = subprocess.Popen(command, cwd=ROOT, stdout=output,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                actual = process.wait(timeout=600)
            except subprocess.TimeoutExpired:
                timed_out = True
                for sig in (signal.SIGTERM, signal.SIGKILL):
                    try:
                        os.killpg(process.pid, sig)
                    except ProcessLookupError:
                        pass  # A concurrent normal exit still needs its actual join.
                    try:
                        actual = process.wait(timeout=10)
                        break
                    except subprocess.TimeoutExpired:
                        continue
                if actual is None:
                    raise TimeoutError('runner did not join after KILL')
    except BaseException as error:
        wait_error = f'{type(error).__name__}: {error}'
    finally:
        descendants = cleanup_descendants()
        if process is not None and actual is None:
            own = next((row for row in descendants['reaped'] if row['pid'] == process.pid), None)
            if own is not None:
                actual = os.waitstatus_to_exitcode(own['wait_status'])
                process.returncode = actual
            elif process.poll() is not None:
                actual = process.returncode
    after = snapshot()
    path = directory / 'qualification.json'
    qualification = json.loads(path.read_text()) if path.is_file() else None
    passed = (not timed_out and wait_error is None and process is not None and
              not descendants['forced'] and not descendants['remaining'] and
              actual == 0 and process.poll() is not None and
              not group_alive(process.pid) and before == after and qualification is not None and
              qualification['status'] == 'PASS' and qualification['executed'] == 4 and
              qualification['source_stable'] and len(qualification['cases']) == 4 and
              {(case['mode'], case['upstream_protocol']) for case in qualification['cases']} ==
              {('h2', 'h2c'), ('h2', 'http2'), ('h1', 'h2c'), ('h1', 'http2')} and
              all(case['status'] == 'PASS' for case in qualification['cases']) and
              all(row['exit'] == 0 and not row['forced'] and row['reader_joined'] and
                  row['owned_group_gone'] for row in qualification['joins']))
    if qualification:
        passed = passed and all(sha(directory / name) == expected
                               for name, expected in qualification['artifact_sha256'].items())
    record = dict(kind='ACTUAL_NATIVE_BROWSER_COMMAND', status='PASS' if passed else 'FAIL',
                  command=command, pid=process.pid if process else None, actual_exit_code=actual,
                  joined=process is not None and process.poll() is not None,
                  owned_group_gone=process is not None and not group_alive(process.pid),
                  wait_error=wait_error,
                  timed_out=timed_out, elapsed_ms=round((time.monotonic()-started)*1000),
                  descendant_cleanup=descendants,
                  source_before=before, source_after=after, source_stable=before == after,
                  log=str(log), log_sha256=sha(log), qualification=str(path),
                  qualification_sha256=sha(path) if qualification else None,
                  executed=qualification.get('executed', 0) if qualification else 0,
                  collector_sha256=sha(Path(__file__)), astra='2/2 exhausted unchanged')
    with destination.open('x') as output:
        json.dump(record, output, indent=2)
        output.write('\n')
    print(json.dumps({key: value for key, value in record.items()
                      if key not in ('source_before', 'source_after')}, indent=2))
    return 0 if passed else (actual or 1)

if __name__ == '__main__':
    sys.exit(main())
