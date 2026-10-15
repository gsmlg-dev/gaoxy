import hashlib
import json
import subprocess
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E = ROOT / 'docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def joined(record):
    assert record['event'] == 'joined', record
    assert record['forced'] == 0 and record['live'] == 0 and record['failed'] is False, record


def loaded(identity):
    count = 0
    for app in identity['applications']:
        for module in app['modules']:
            assert module['loaded_code_md5'] == module['disk_code_md5'], module['module']
            for field in ['source', 'beam']:
                item = module[field]
                assert digest(Path(item['path'])) == item['sha256'], item['path']
            assert module['compile_source'] == module['source']['path'], module['module']
            count += 1
    assert count > 0
    return count


manifest_path = E / 'sol19-final-static-review-candidate-manifest.json'
manifest = read(manifest_path)
assert len(manifest['source_files']) == 46 and len(manifest['authorities']) == 5
assert all(digest(ROOT / name) == value for name, value in manifest['source_files'].items())
assert all(digest(ROOT / name) == value for name, value in manifest['authorities'].items())
for label in ['spec', 'code']:
    report_path = E / f'managed-h2-fixed-full-static-{label}-sol19.json'
    report = read(report_path)
    assert report['verdict'] == f'PASS_FULL_STATIC_{label.upper()}' and report['findings'] == []

supervisor = read(E / 'sol19-fresh-unblocked-gates.json')
assert supervisor['status'] == 'PASS_COMMANDS_STAGE_STILL_BLOCKED_UPSTREAM122'
assert supervisor['candidate_manifest_sha256'] == digest(manifest_path)
assert supervisor['spec_sha256'] == digest(E / 'managed-h2-fixed-full-static-spec-sol19.json')
assert supervisor['code_sha256'] == digest(E / 'managed-h2-fixed-full-static-code-sol19.json')
assert supervisor['full58'] == 'BLOCKED_UPSTREAM122_NO_RERUN_OR_EXCLUSION'
gates = {}
for gate in supervisor['gates']:
    name = gate['gate']
    assert name not in gates and gate['actual_exit'] == 0 and gate['status'] == 'PASS_COMMAND'
    paths = list(E.glob(f'sol19-postreview-{name}-*.json'))
    assert len(paths) == 1, (name, paths)
    receipt = read(paths[0])
    assert receipt['status'] == 'PASS' and receipt['actual_exit'] == 0 and receipt['source_stable'] is True
    assert receipt['head'] == manifest['head']
    assert digest(ROOT / receipt['log']) == receipt['log_sha256']
    gates[name] = {'receipt': str(paths[0].relative_to(E)), 'sha256': digest(paths[0]), 'actual_exit': 0,
                   'source_stable': True, 'elapsed_ms': receipt['elapsed_ms']}
assert set(gates) == {'format38', 'strict-compile', 'public63', 'matrix135', 'browser3'}

public_path = E / 'sol19-postreview-public63/qualification.json'
public = read(public_path)
assert public['status'] == 'PASS' and public['executed'] == public['expected'] == 63
assert public['exit'] == 0 and public['source_stable'] is True
counts = {'completion16': 16, 'managed39': 39, 'supplement8': 8}
for name, count in counts.items():
    gate = public['gates'][name]
    assert gate['status'] == 'PASS' and gate['executed'] == len(gate['cases']) == count
    assert len(set(gate['cases'])) == count
    assert gate['failed'] == gate['skipped'] == 0 and gate['loaded_identity_stable'] is True
for command in public['commands']:
    assert command['exit'] == 0 and command['timed_out'] is False
    assert command['group_shutdown_confirmed'] is True and command['remaining_after_cleanup'] == []
    assert digest(public_path.parent / command['log']) == command['log_sha256']
for artifact in public['artifacts']:
    path = public_path.parent / artifact['path']
    assert path.stat().st_size == artifact['bytes'] and digest(path) == artifact['sha256'], artifact['path']
assert read(public_path.parent / 'source-before.json') == read(public_path.parent / 'source-after.json')

matrix_path = E / 'sol19-postreview-matrix135/qualification.json'
matrix = read(matrix_path)
assert matrix['status'] == 'PASS' and matrix['executed'] == len(matrix['cases']) == 135
assert matrix['failure'] is None and matrix['source_stable'] is True
assert matrix['source_before'] == matrix['source_after']
assert matrix['exclusions'] == matrix['skips'] == []
execution = matrix['execution_manifest']
ids = [case['case'] for case in matrix['cases']]
assert len(set(ids)) == 135 and all(case['status'] == 'PASS' for case in matrix['cases'])
assert Counter(ids) == Counter(execution['required']) == Counter(execution['executed'])
assert execution['complete'] is True
assert all(execution[key] == [] for key in ['missing', 'unexpected', 'exclusions', 'skips'])
assert {cell['cell'] for cell in matrix['cells']} == {'h1-to-tls', 'h1-to-h2c', 'h2-to-tls', 'h2-to-h2c'}
for cell in matrix['cells']:
    assert cell['status'] == 'PASS'
    joined(cell['joined'])
matrix_modules = loaded(matrix['candidate_identity'])

browser_path = E / 'sol19-postreview-browser3/qualification.json'
browser = read(browser_path)
assert browser['status'] == 'PASS' and browser['executed'] == len(browser['cases']) == 3
assert browser['failure'] is None and browser['source_stable'] is True
assert browser['source_before'] == browser['source_after']
assert {case['case'] for case in browser['cases']} == {'browser-native-h2-to-tls-h2', 'browser-wrong-ca', 'browser-wrong-name'}
for case in browser['cases']:
    assert case['status'] == 'PASS'
    joined(case['joined'])
    join = case['browser_join']
    assert join['event'] == 'joined' and join['passed'] is True and join['forced'] is False
    assert join['process'] == {'code': 0, 'signal': None} and join['isolated_profile_removed'] is True
    if case['case'] != 'browser-native-h2-to-tls-h2':
        assert case['cleanup_status'] == 'UNCONFIRMED_WITH_RETAINED_FAILURE'
        assert case['cleanup_proof']['original']['result'] == '{:error, :cleanup_unconfirmed}'
for name, value in browser['artifact_hashes'].items():
    assert digest(browser_path.parent / name) == value, name
browser_modules = loaded(read(browser_path.parent / 'host-gaoxy-after.json'))

upstream = {}
for name, endpoint in [('issue', 'issues/122'), ('latest_release', 'releases/latest'), ('main', 'commits/main')]:
    command = ['gh', 'api', f'repos/gsmlg-dev/http_fetch/{endpoint}']
    process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=30, check=True)
    upstream[name] = {'command': command, 'actual_exit': process.returncode, 'response': json.loads(process.stdout)}
issue = upstream['issue']['response']
assert issue['state'] == 'open' and issue['type']['name'] == 'Bug'
assert 'internal request' in {label['name'] for label in issue['labels']}
assert '**Severity:** blocker' in issue['body']
upstream.update({'kind': 'SOL19_UPSTREAM122_FINAL_READ_ONLY_CHECK', 'checked_at_utc': datetime.now(timezone.utc).isoformat(),
                 'stage_status': 'BLOCKED_UPSTREAM122', 'installed_cohort': '0.21.4', 'dependency_updated': False,
                 'full58_not_rerun': True, 'local_workaround': False})
upstream_path = E / 'sol19-upstream122-final-read-only-check.json'
assert not upstream_path.exists()
upstream_path.write_text(json.dumps(upstream, indent=2) + '\n')

report = {'kind': 'SOL19_POSTREVIEW_UNBLOCKED_EVIDENCE_AUDIT', 'status': 'PASS_UNBLOCKED_GATES_ONLY',
          'stage_status': 'BLOCKED_UPSTREAM122', 'baseline': manifest['head'],
          'checked_at_utc': datetime.now(timezone.utc).isoformat(), 'script_sha256': digest(Path(__file__)),
          'candidate_manifest_sha256': digest(manifest_path), 'frozen_owned_files': 46, 'frozen_authorities': 5,
          'frozen_source_stable': True, 'gates': gates,
          'qualifications': {name: {'sha256': digest(path), 'executed': count, 'status': 'PASS'} for name, path, count in
                             [('public63', public_path, 63), ('matrix135', matrix_path, 135), ('browser3', browser_path, 3)]},
          'public_command_groups_joined': len(public['commands']), 'public_artifacts_hash_verified': len(public['artifacts']),
          'matrix_manifest_complete': True, 'matrix_cases_unique': 135, 'matrix_exclusions': [], 'matrix_skips': [],
          'matrix_main_peer_joins': 4, 'matrix_loaded_modules_verified': matrix_modules,
          'browser_peer_joins': 3, 'browser_process_joins': 3, 'browser_artifacts_hash_verified': len(browser['artifact_hashes']),
          'browser_loaded_modules_verified': browser_modules,
          'negative_browser_cleanup': 'UNCONFIRMED_WITH_RETAINED_FAILURE',
          'upstream_check': {'path': upstream_path.name, 'sha256': digest(upstream_path), 'state': issue['state'],
                             'latest_tag': upstream['latest_release']['response']['tag_name'],
                             'main_sha': upstream['main']['response']['sha']},
          'full58': 'BLOCKED_UPSTREAM122_NO_RERUN_OR_EXCLUSION', 'historical_full58': {'executed': 845, 'failed': 1, 'exit': 2},
          'stage_commit': 'NOT_RUN', 'successor': 'NOT_RUN', 'repair_counters_changed': False, 'astra_recovery': '2/2'}
report_path = E / 'sol19-postreview-unblocked-evidence-audit.json'
assert not report_path.exists()
report_path.write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
