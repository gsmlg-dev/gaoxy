import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
EVIDENCE = Path(Path('/tmp/gaoxy-h2-fixed-evidence-path').read_text().strip())
manifest_path = EVIDENCE / 'sol19-final-static-review-candidate-manifest.json'
manifest = json.loads(manifest_path.read_text())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def frozen():
    assert all(digest(ROOT / path) == value for path, value in manifest['source_files'].items())
    assert all(digest(ROOT / path) == value for path, value in manifest['authorities'].items())

code_report = Path(sys.argv[1])
code = json.loads(code_report.read_text())
assert code['verdict'] == 'PASS_FULL_STATIC_CODE' and not code['findings']
spec_report = EVIDENCE / 'managed-h2-fixed-full-static-spec-sol19.json'
spec = json.loads(spec_report.read_text())
assert spec['verdict'] == 'PASS_FULL_STATIC_SPEC' and not spec['findings']
frozen()
result = dict(kind='SOL19_FRESH_UNBLOCKED_GATES', status='RUNNING',
              candidate_manifest_sha256=digest(manifest_path),
              spec_sha256=digest(spec_report), code_sha256=digest(code_report),
              full58='BLOCKED_UPSTREAM122_NO_RERUN_OR_EXCLUSION', gates=[])
commands = [
    ('format38', [sys.executable, '/tmp/gaoxy-h2-fixed-run-mix-manifest3.py',
                  'format', 'sol19-postreview-format38', '--check-formatted']),
    ('strict-compile', [sys.executable, '/tmp/gaoxy-h2-fixed-run3.py',
                        'sol19-postreview-strict-compile', 'unbuffer', 'mix',
                        'compile', '--warnings-as-errors', '--force']),
]
for kind, script, directory in [
    ('public63', 'h2_0214_qualification.py', 'sol19-postreview-public63'),
    ('matrix135', 'managed_h2_fixed_qualification.py', 'sol19-postreview-matrix135'),
    ('browser3', 'managed_h2_fixed_browser.py', 'sol19-postreview-browser3'),
]:
    commands.append((kind, [sys.executable, '/tmp/gaoxy-h2-fixed-run3.py', directory,
                            'python', 'integration/http_fetch_contract/' + script,
                            '--evidence', str(EVIDENCE / directory)]))

for name, command in commands:
    frozen()
    print('START ' + name, flush=True)
    exit_code = subprocess.call(command, cwd=ROOT)
    frozen()
    result['gates'].append(dict(gate=name, actual_exit=exit_code,
                               status='PASS_COMMAND' if exit_code == 0 else 'FAIL_COMMAND'))
    result['status'] = 'FAIL' if exit_code else 'RUNNING'
    (EVIDENCE / 'sol19-fresh-unblocked-gates.json').write_text(json.dumps(result, indent=2) + '\n')
    if exit_code:
        sys.exit(exit_code)
result['status'] = 'PASS_COMMANDS_STAGE_STILL_BLOCKED_UPSTREAM122'
(EVIDENCE / 'sol19-fresh-unblocked-gates.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2), flush=True)
