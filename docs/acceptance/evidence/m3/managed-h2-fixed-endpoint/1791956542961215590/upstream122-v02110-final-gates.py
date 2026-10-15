import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E = ROOT / 'docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590'
manifest_path = E / 'upstream122-v02110-ready-candidate-manifest.json'
manifest = json.loads(manifest_path.read_text())
release = json.loads((E / 'upstream122-v02110-postreview-release.json').read_text())
assert release['status'] == 'RELEASED_FOR_FRESH_FINAL_GATES'
assert release['candidate_sha256'] == hashlib.sha256(manifest_path.read_bytes()).hexdigest()
for report in release['reviews']:
    assert hashlib.sha256((ROOT / report['path']).read_bytes()).hexdigest() == report['sha256']


def frozen():
    for name, value in (manifest['source_files'] | manifest['authorities']).items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == value, name


runner = '/tmp/gaoxy-h2-fixed-run3.py'
checks = [
    ('format43', ['unbuffer', 'mix', 'format', '--check-formatted', *manifest['format_paths']]),
    ('strict-compile', ['unbuffer', 'mix', 'compile', '--warnings-as-errors', '--force']),
    ('full58', ['unbuffer', 'mix', 'test', '--warnings-as-errors', '--max-cases', '1', '--seed', '33011',
                *manifest['scoped_paths']]),
    ('public63', ['python', 'integration/http_fetch_contract/h2_02110_qualification.py', '--evidence',
                  str(E / 'upstream122-v02110-postreview-public63')]),
    ('matrix135', ['python', 'integration/http_fetch_contract/managed_h2_fixed_qualification.py', '--evidence',
                   str(E / 'upstream122-v02110-postreview-matrix135')]),
    ('browser3', ['python', 'integration/http_fetch_contract/managed_h2_fixed_browser.py', '--evidence',
                  str(E / 'upstream122-v02110-postreview-browser3')]),
]
record = {'kind': 'UPSTREAM122_V02110_POSTREVIEW_GATES', 'status': 'RUNNING', 'gates': [],
          'candidate_manifest': str(manifest_path.relative_to(ROOT)),
          'candidate_sha256': hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
          'cohort': '0.21.10', 'original_assertions_preserved': True, 'astra_recovery': '2/2'}
out = E / 'upstream122-v02110-postreview-gates.json'
assert not out.exists()
for name, command in checks:
    frozen()
    print('START ' + name, flush=True)
    result = subprocess.run([sys.executable, runner, 'upstream122-v02110-postreview-' + name, *command], cwd=ROOT)
    frozen()
    record['gates'].append({'gate': name, 'actual_exit': result.returncode})
    record['status'] = 'FAIL' if result.returncode else 'RUNNING'
    out.write_text(json.dumps(record, indent=2) + '\n')
    if result.returncode:
        sys.exit(result.returncode)
    if name in ['public63', 'matrix135', 'browser3']:
        qualification = json.loads((E / ('upstream122-v02110-postreview-' + name) / 'qualification.json').read_text())
        expected = {'public63': 63, 'matrix135': 135, 'browser3': 3}[name]
        assert qualification['status'] == 'PASS' and qualification['executed'] == expected
        assert qualification['source_stable']
record['status'] = 'PASS_COMMANDS_REQUIRES_RECEIPT_AUDIT_AND_FINAL_DOC_REVIEW'
out.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2), flush=True)
