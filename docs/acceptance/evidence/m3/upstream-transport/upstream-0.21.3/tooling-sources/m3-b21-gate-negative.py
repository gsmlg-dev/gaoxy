import hashlib
import json
from pathlib import Path
import subprocess

root = Path.cwd()
out = root / 'docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.3'
inputs = root / '.audit/m3-transport/h1-b21-invalid-gates'
inputs.mkdir()
gate = json.loads((root / '.audit/m3-transport/h1-accounting-tls95-gate.json').read_text())
audit = root / '.audit/m3-transport/h1-slice-b-implementation'


def retained():
    return {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in audit.rglob('*') if path.is_file()}


variants = {'malformed': '{', 'oversized': ' ' * 65537,
            'duplicate_key': '{"schema_version":1,"schema_version":1}'}
for name in ['cohort', 'extra_key', 'stale_binding', 'review']:
    value = json.loads(json.dumps(gate))
    if name == 'cohort':
        value['cohort'] = '0.21.2'
    elif name == 'extra_key':
        value['unreviewed'] = True
    elif name == 'stale_binding':
        value['binding_files'][0]['sha256'] = '0' * 64
    else:
        value['reviews']['code'] = 'NOT_RUN'
    variants[name] = json.dumps(value)
paths = {'missing': inputs / 'missing.json'}
for name, payload in variants.items():
    path = inputs / (name + '.json')
    path.write_text(payload)
    paths[name] = path
before = retained()
results = []
for name, path in paths.items():
    argv = ['unbuffer', 'mix', 'run', '--no-compile', '--config',
            '.audit/m3-transport/h1-accounting-runtime-config.exs',
            'integration/http_fetch_contract/managed_h1_accounting_fixture_test.exs',
            '--tls-connecting', '--tls95-gate', str(path)]
    result = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
    # Save the actual exit before interpreting its output.
    receipt = {'name': name, 'argv': argv, 'actual_exit': result.returncode}
    (out / ('h1-b21-gate-negative-' + name + '.log')).write_bytes(result.stdout)
    text = result.stdout.decode(errors='replace')
    receipt['expected'] = result.returncode != 0 and 'BLOCKED_TLS95_GATE' in text and '"registered":0' in text
    receipt['no_fixture_artifact_write'] = before == retained()
    results.append(receipt)
assert all(row['expected'] and row['no_fixture_artifact_write'] for row in results)
with (out / 'h1-b21-gate-negative-analysis.json').open('x') as stream:
    json.dump({'status': 'PASS_EXPECTED_NEGATIVE_GATES', 'executed_probes': len(results),
               'registered_tests': 0, 'rows': results}, stream, indent=2)
print('PASS_EXPECTED_NEGATIVE_GATES', len(results), 'probes; zero registered tests/artifact writes')
