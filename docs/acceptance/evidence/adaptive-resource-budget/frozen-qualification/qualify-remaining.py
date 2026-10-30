#!/usr/bin/env python3
"""Execute only canonical files not attempted after an immutable failed gate."""
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
suite = sys.argv[1]
assert suite in ('component', 'protocol')
spec = importlib.util.spec_from_file_location('canonical_gate', root/'scripts/check-repairs.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
entries = gate.SUITES[suite]
initial = root/f'.audit/adaptive-resource-budget/qualification/frozen-candidate-{suite}.log'
attempted = re.findall(r'^REPAIR_COMMAND .*?scripts/check-tests.py (\S+) --seed 0 --max-cases 1$', initial.read_text(), re.M)
assert attempted == [path for path, _ in entries[:len(attempted)]], attempted
remaining = entries[len(attempted):]
assert remaining
print('QUALIFICATION_REMAINDER', suite, 'already_attempted_files', len(attempted), 'remaining_files', len(remaining), 'expected_cases', sum(n for _, n in remaining), flush=True)
rows = []
for path, expected in remaining:
    command = [sys.executable, 'scripts/check-tests.py', path, '--seed', '0', '--max-cases', '1']
    print('REMAINDER_COMMAND', ' '.join(command), flush=True)
    result = subprocess.run(command, cwd=root, env=os.environ.copy(), text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout, end='', flush=True)
    summaries = re.findall(r'(\d+) tests?, (\d+) failures?([^\n]*)', result.stdout)
    actual = sum(int(total) for total, _, _ in summaries)
    failures = sum(int(failed) for _, failed, _ in summaries)
    excluded_or_skipped = any(re.search(r'[1-9]\d* (?:excluded|skipped)', suffix) for _, _, suffix in summaries)
    problem = None
    try:
        validated = gate.executed(result.stdout)
        if validated != expected:
            problem = f'case count mismatch: expected {expected}, actual {validated}'
    except ValueError as error:
        problem = str(error)
    status = 'PASS' if result.returncode == 0 and problem is None else 'FAIL'
    rows.append(dict(path=path, expected=expected, actual=actual, failures=failures, excluded_or_skipped=excluded_or_skipped, exit=result.returncode, status=status, verification_error=problem))
    print('REMAINDER_FILE_RESULT', json.dumps(rows[-1]), flush=True)
record = dict(suite=suite, initial_gate_log=str(initial.relative_to(root)), initial_gate_disposition='FAIL retained unchanged', selection='Only unattempted suffix of canonical SUITES; original cases are not omitted or waived', files=rows, expected=sum(n for _, n in remaining), executed=sum(row['actual'] for row in rows), failures=sum(row['failures'] for row in rows), failed_files=[row['path'] for row in rows if row['status'] != 'PASS'])
(root/f'.audit/adaptive-resource-budget/qualification/remaining-{suite}.json').write_text(json.dumps(record, indent=2)+'\n')
print('QUALIFICATION_REMAINDER_RESULT', json.dumps({k:v for k,v in record.items() if k!='files'}), flush=True)
raise SystemExit(2 if record['failed_files'] else 0)
