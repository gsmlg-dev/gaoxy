import datetime
import hashlib
import json
import re
import subprocess
from pathlib import Path


ROOT = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
EVIDENCE = ROOT / 'docs/acceptance/evidence/m3/native-generation-checked-capture/1792107581748432565'
BASELINE = 'e189894882bb6a530f2c38538be4efaf384be261'
APPLICATION = [
    'apps/gaoxy/lib/gaoxy/admission.ex',
    'apps/gaoxy/test/admission_timeout_test.exs',
    'apps/gaoxy_http/lib/gaoxy/http/generation.ex',
    'apps/gaoxy_http/lib/gaoxy/http/generation/accounting.ex',
    'apps/gaoxy_http/lib/gaoxy/http/resources.ex',
    'apps/gaoxy_http/test/generation_checked_capture_test.exs',
    'apps/gaoxy_proxy/lib/gaoxy/proxy/managed_generation_accounting.ex',
    'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex',
    'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex',
    'apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs',
    'apps/gaoxy_proxy/test/upstream_groups_test.exs',
    'apps/gaoxy_proxy/test/upstream_transports_test.exs',
]
DOCUMENTATION = [
    'docs/designs/m3-native-generation-checked-capture.md',
    'docs/plans/m3-native-generation-checked-capture.md',
    'docs/acceptance/m3-native-generation-checked-capture.md',
]


def git(*args, check=True):
    return subprocess.run(['git', *args], cwd=ROOT, capture_output=True, check=check)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_json(name):
    return json.loads((EVIDENCE / name).read_text())


freeze = read_json('candidate-freeze1.json')
spec = read_json('gaoxy-native-generation-full-spec1.json')
code = read_json('gaoxy-native-generation-full-code1.json')
tail = read_json('gaoxy-native-generation-closeout-tail-review1.json')
fresh = read_json('acceptance-fresh1.json')
assert git('rev-parse', 'HEAD').stdout.decode().strip() == BASELINE
assert not git('diff', '--cached', '--name-only', '-z').stdout, 'index must start empty'
assert spec['status'] == 'PASS' and not spec['actionable_findings']
assert code['verdict'] == 'PASS' and not code['findings']
assert tail.get('status', tail.get('verdict')) == 'PASS', tail
assert not tail['findings'], tail['findings']
for name, expected in tail['canonical_document_sha256_after'].items():
    assert digest((ROOT / name).read_bytes()) == expected, name
assert fresh['status'] == 'PASS' and fresh['actual_exit_code'] == 0
assert fresh['joined'] and fresh['process_group_absent'] and fresh['source_stable']
assert fresh['counts'] == dict(tests=493, doctests=0, properties=0, failures=0, skipped=0, excluded=0)
assert fresh['warning_count'] == 0 and not fresh['timed_out'] and not fresh['interrupted']
assert digest(Path(fresh['log_path']).read_bytes()) == fresh['log_sha256']

frozen_source_mismatches = []
for name, entry in freeze['source_manifest'].items():
    if digest((ROOT / name).read_bytes()) != entry['sha256']:
        frozen_source_mismatches.append(name)
assert set(frozen_source_mismatches) == set(DOCUMENTATION), frozen_source_mismatches
for name, entry in freeze['evidence_manifest'].items():
    assert digest((EVIDENCE / name).read_bytes()) == entry['sha256'], name
for name, expected in freeze['protected_files'].items():
    assert digest(Path(name).read_bytes()) == expected, name

owned_evidence = sorted(str(p.relative_to(ROOT)) for p in EVIDENCE.rglob('*') if p.is_file())
expected_paths = sorted(APPLICATION + DOCUMENTATION + owned_evidence)
assert len(expected_paths) == len(set(expected_paths))
tracked_changes = git('diff', '--name-only', '-z').stdout.decode().split('\0')
assert set(filter(None, tracked_changes)).issubset(APPLICATION), tracked_changes
assert git('diff', '--check').returncode == 0
git('add', '--', *expected_paths)
staged_paths = sorted(filter(None, git('diff', '--cached', '--name-only', '-z').stdout.decode().split('\0')))
assert staged_paths == expected_paths, (set(staged_paths) - set(expected_paths), set(expected_paths) - set(staged_paths))

manifest = {}
for name in staged_paths:
    staged = git('show', ':' + name).stdout
    assert staged == (ROOT / name).read_bytes(), name
    blob = git('rev-parse', ':' + name).stdout.decode().strip()
    manifest[name] = dict(bytes=len(staged), sha256=digest(staged), git_blob=blob)
    if name in APPLICATION:
        assert digest(staged) == freeze['source_manifest'][name]['sha256'], name

strict = git('diff', '--cached', '--check', '--', *APPLICATION, *DOCUMENTATION, check=False)
assert strict.returncode == 0, strict.stdout.decode() + strict.stderr.decode()
raw = git('diff', '--cached', '--check', check=False)
raw_output = raw.stdout.decode() + raw.stderr.decode()
if raw.returncode != 0:
    archive_prefix = str(EVIDENCE.relative_to(ROOT)) + '/'
    issue_lines = [line for line in raw_output.splitlines() if re.match(r'^.+:\d+: ', line)]
    assert issue_lines and all(line.startswith(archive_prefix) for line in issue_lines), raw_output

for name, entry in freeze['source_manifest'].items():
    if name not in DOCUMENTATION:
        assert digest(git('show', ':' + name).stdout) == entry['sha256'], name

receipt = {
    'status': 'PASS_INDEX_CUSTODY',
    'at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'baseline': BASELINE,
    'branch': git('branch', '--show-current').stdout.decode().strip(),
    'fresh_scoped_union': {'receipt': 'acceptance-fresh1.json', 'sha256': digest((EVIDENCE / 'acceptance-fresh1.json').read_bytes()), 'counts': fresh['counts'], 'exit': fresh['actual_exit_code']},
    'reviews': {name: digest((EVIDENCE / name).read_bytes()) for name in ['gaoxy-native-generation-full-spec1.json', 'gaoxy-native-generation-full-code1.json', 'gaoxy-native-generation-closeout-tail-review1.json']},
    'frozen_source_count': len(freeze['source_manifest']),
    'frozen_evidence_count': len(freeze['evidence_manifest']),
    'frozen_source_changes': frozen_source_mismatches,
    'documentation_only_closeout': True,
    'all_frozen_application_and_test_sources_match_index': True,
    'all_frozen_evidence_matches_index': True,
    'protected_files': freeze['protected_files'],
    'staged_count': len(manifest),
    'application_count': len(APPLICATION),
    'documentation_count': len(DOCUMENTATION),
    'manifest': manifest,
    'strict_nonarchive_diff_check': {'exit': strict.returncode, 'output': strict.stdout.decode() + strict.stderr.decode()},
    'raw_staged_diff_check': {'exit': raw.returncode, 'output': raw_output, 'disposition': 'PASS' if raw.returncode == 0 else 'ARCHIVAL_WHITESPACE_ONLY_PRESERVED'},
    'self_exclusion': 'This receipt is appended and staged after this snapshot; it cannot contain its own hash. Final commit/blob verification covers it.',
    'counters': {'stage_failed_GREEN': 6, 'stage_runtime_abort': 1, 'stage_metadata_failure': 1, 'group_failed_GREEN': 30, 'root_failure_events': 35, 'astra_used': 2, 'astra_max': 2},
    'commit': 'PENDING',
}
target = EVIDENCE / 'index-custody1.json'
assert not target.exists(), target
target.write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
print(json.dumps({k: receipt[k] for k in ['status', 'staged_count', 'application_count', 'documentation_count', 'strict_nonarchive_diff_check', 'raw_staged_diff_check']}, indent=2))
