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

parser = argparse.ArgumentParser()
parser.add_argument('name')
parser.add_argument('--timeout', type=int, default=180)
parser.add_argument('--allow-format', action='store_true')
parser.add_argument('--source-only', action='store_true')
parser.add_argument('--lane', choices=['model', 'fixture', 'h2'], default='fixture')
parser.add_argument('--sol-repairs', type=int, default=0)
parser.add_argument('--sol-unsuccessful', type=int, default=0)
parser.add_argument('--astra-rounds', type=int, choices=[0, 1, 2], default=0)
parser.add_argument('command', nargs=argparse.REMAINDER)
args = parser.parse_args()
command = args.command[1:] if args.command[:1] == ['--'] else args.command
assert command
root = Path.cwd()
out = root / 'docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.3'
assert not (out / (args.name + '.json')).exists(), 'Never replace a prior receipt'
previous = json.loads((root / 'docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.2/h1-no-launch-model-red.json').read_text())
paths = set(previous['inputs_before'])
paths.update([
    'integration/http_fetch_contract/managed_h1_accounting_fixture.exs',
    'integration/http_fetch_contract/managed_h1_accounting_fixture_test.exs',
    'integration/http_fetch_contract/managed_h1_accounting_peer.py',
    'docs/plans/m3-h1-no-launch-timeout-repair.md',
    'docs/plans/m3-h1-qualification-model.md',
    'docs/plans/m3-h1-qualification-fixture.md',
    '.audit/m3-transport/h1-accounting-runtime-config.exs',
    '.audit/m3-continuation-collector.py',
    '.audit/m3-qualified-collector.py',
    '.audit/m3-h1-b21-collector.py',
    '.audit/m3-b21-gate-builder.py',
    'integration/h2_gateway/requirements.txt',
    'docs/plans/m3-h1-b21-tls-connecting.md',
    '.audit/m3-transport/h1-fixture-repair1-ledger-test.exs',
    '.audit/m3-transport/h1-fixture-0.21.3-identity-test.exs',
    'docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.3/h1-fixture-spec-inventory.json',
    'docs/plans/m3-upstream-0.21.3-qualification.md',
])
for binding in ['.audit/m3-transport/h1-accounting-tls95-gate.json',
                '.audit/m3-transport/h1-b21-disposable-root.der']:
    if (root / binding).is_file():
        paths.add(binding)
if args.lane == 'model':
    paths.difference_update([
        'integration/http_fetch_contract/managed_h1_accounting_fixture.exs',
        'integration/http_fetch_contract/managed_h1_accounting_fixture_test.exs',
        'integration/http_fetch_contract/managed_h1_accounting_peer.py',
    ])
for base in ([] if args.source_only else ['_build/test/lib', 'deps/ex_ssl/priv', 'deps/elixir_quic/priv']):
    if (root / base).exists():
        paths.update(str(p.relative_to(root)) for p in (root / base).rglob('*')
                     if p.is_file() and p.suffix in ['.beam', '.app', '.so'])

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def freeze():
    return {p: sha(root / p) if (root / p).is_file() else None for p in sorted(paths)}

def peers():
    lines = subprocess.check_output(['ps', '-eo', 'pid=,ppid=,args='], text=True).splitlines()
    return [line.strip() for line in lines
            if re.search(r'(?:^|/| )(?:managed_(?:h1_accounting_|tls_tracking_|)peer|h2_functional_supplement_peer)\.py(?: |$)', line)]

def save(name, data):
    with (out / name).open('x') as file:
        file.write(json.dumps(data, indent=2, sort_keys=True) + '\n')

before = freeze()
save(args.name + '-source-before.json', before)
owned_before = peers()
env = os.environ.copy()
env.update(ERL_FLAGS='+S 2:2', MIX_ENV='test', PYTHONDONTWRITEBYTECODE='1',
           HTTP_FETCH_PEER_PYTHON='/tmp/gaoxy-m3-h2-soak-venv/bin/python')
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
origin = time.monotonic()
timed_out = False
log = out / (args.name + '.log')
with log.open('xb') as output:
    process = subprocess.Popen(command, env=env, stdout=output, stderr=subprocess.STDOUT,
                               start_new_session=True)
    try:
        code = process.wait(timeout=args.timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        os.killpg(process.pid, signal.SIGTERM)
        try:
            code = process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            code = process.wait(timeout=5)
after = freeze()
save(args.name + '-source-after.json', after)
text = log.read_text(errors='replace')
ansi = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')
plain = ansi.sub('', text)
counts = [dict(tests=int(m[0]), failures=int(m[1]))
          for m in re.findall(r'(?<!\d)(\d+) tests?, (\d+) failures?', plain)]
changed = [p for p in sorted(paths) if before[p] != after[p]]
allowed = {'integration/http_fetch_contract/managed_h1_lease_model.exs',
           'integration/http_fetch_contract/managed_h1_lease_model_test.exs',
           'integration/http_fetch_contract/managed_h1_accounting_fixture.exs',
           'integration/http_fetch_contract/managed_h1_accounting_fixture_test.exs',
           'integration/http_fetch_contract/h2_functional_supplement.exs'}
owned_after = peers()
valid_inputs = not changed or (args.allow_format and set(changed) <= allowed)
receipt = {
    'status': 'PASS_COMMAND' if code == 0 and not timed_out and valid_inputs and not owned_after else 'FAIL_COMMAND',
    'argv': command, 'cwd': str(root), 'started_utc': started,
    'completed_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'elapsed_seconds': round(time.monotonic() - origin, 3), 'exit': code,
    'timeout_seconds': args.timeout, 'timed_out': timed_out,
    'environment': {k: env[k] for k in ['ERL_FLAGS', 'MIX_ENV', 'HTTP_FETCH_PEER_PYTHON', 'PYTHONDONTWRITEBYTECODE']},
    'frozen_source_and_build_files': len(paths), 'inputs_match': before == after,
    'changed_files': changed, 'allowed_format_change': args.allow_format,
    'counts': counts, 'tests': sum(c['tests'] for c in counts),
    'failures': sum(c['failures'] for c in counts),
    'source_before': args.name + '-source-before.json', 'source_after': args.name + '-source-after.json',
    'log': log.name, 'log_sha256': sha(log),
    'owned_peer_processes_before': owned_before, 'owned_peer_processes_after': owned_after,
    'tls_repair_counters': {'sol_repairs': 4, 'sol_unsuccessful': 2, 'astra': 2},
    'lane': args.lane,
    'source_only': args.source_only,
    'lane_repair_counters': {'sol_repairs': args.sol_repairs, 'sol_unsuccessful': args.sol_unsuccessful, 'astra': args.astra_rounds},
}
save(args.name + '.json', receipt)
print(plain[-8000:])
print(json.dumps(receipt, indent=2))
