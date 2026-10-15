import hashlib
import json
import pathlib
import re
import subprocess
import sys
import time

root = pathlib.Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
evidence = pathlib.Path(pathlib.Path('/tmp/gaoxy-h2-fixed-evidence-path').read_text().strip())
label, *command = sys.argv[1:]
assert re.fullmatch(r'[a-z0-9-]+', label) and command
prefix = evidence / (label + '-' + str(time.time_ns()))

def identity():
    paths = [p for app in ['gaoxy', 'gaoxy_proxy', 'gaoxy_http', 'gaoxy_http3']
             for p in (root / 'apps' / app).rglob('*')
             if p.is_file() and p.suffix in ['.ex', '.exs', '.py', '.txt']]
    paths += [p for p in (root / 'integration').rglob('*')
              if p.is_file() and p.suffix in ['.py', '.exs', '.txt', '.mjs']]
    paths += [root / p for p in ['mix.exs', 'mix.lock', 'flake.nix', 'flake.lock',
              'docs/designs/m3-managed-h2-preparation.md',
              'docs/designs/m3-managed-h2-fixed-endpoint.md',
              'docs/plans/m3-managed-h2-fixed-endpoint.md',
              'docs/acceptance/m3-managed-h2-fixed-endpoint.md',
              'docs/plans/m3-h2-0.21.3-functional-supplement.md']]
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(set(paths))}

before = identity()
actual = ['nix', 'develop', '--command', 'env', 'ERL_FLAGS=+S 2:2', 'MIX_ENV=test', *command]
started = time.monotonic()
with prefix.with_suffix('.log').open('wb') as output:
    result = subprocess.run(actual, cwd=root, stdout=output, stderr=subprocess.STDOUT)
raw_bytes = prefix.with_suffix('.log').read_bytes()
plain = re.sub(r'\x1b\[[0-9;]*m', '', raw_bytes.decode(errors='replace'))
counts = []
for total, failures, suffix in re.findall(r'(\d+) tests?, (\d+) failures?([^\n]*)', plain):
    excluded = sum(int(n) for n in re.findall(r'(\d+) excluded', suffix))
    skipped = sum(int(n) for n in re.findall(r'(\d+) skipped', suffix))
    counts.append({'tests': int(total), 'failures': int(failures), 'excluded': excluded,
                   'skipped': skipped, 'executed': int(total) - excluded - skipped})
after = identity()
test_command = 'mix' in command and 'test' in command
format_mutation = 'mix' in command and 'format' in command and '--check-formatted' not in command
valid_counts = not test_command or (bool(counts) and sum(c['executed'] for c in counts) > 0)
passed = result.returncode == 0 and (before == after or format_mutation) and valid_counts
receipt = {
    'kind': 'H2_FIXED_SOURCE_FORMAT' if format_mutation else 'H2_FIXED_SCOPED_VERIFICATION', 'label': label,
    'status': ('FORMAT_APPLIED' if format_mutation else 'PASS') if passed else 'FAIL', 'command': actual, 'cwd': str(root),
    'actual_exit': result.returncode, 'elapsed_ms': round((time.monotonic() - started) * 1000),
    'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
    'runner_sha256': hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),
    'counts': counts, 'nonzero_execution': valid_counts if test_command else None,
    'source_before': before, 'source_after': after, 'source_stable': before == after,
    'authorized_source_format_mutation': format_mutation,
    'log_sha256': hashlib.sha256(raw_bytes).hexdigest(),
    'log': str(prefix.with_suffix('.log').relative_to(root))
}
prefix.with_suffix('.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(plain[-3000:])
print(json.dumps({k: v for k, v in receipt.items() if k not in ['source_before', 'source_after']}, indent=2))
print('RECEIPT ' + str(prefix.with_suffix('.json')))
sys.exit(result.returncode if result.returncode else (0 if passed else 1))
