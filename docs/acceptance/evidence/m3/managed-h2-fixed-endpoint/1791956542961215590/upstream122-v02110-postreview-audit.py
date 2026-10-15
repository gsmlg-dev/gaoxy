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


manifest_path = E / 'upstream122-v02110-ready-candidate-manifest.json'
manifest = read(manifest_path)
assert len(manifest['source_files']) == 52 and len(manifest['authorities']) == 5
assert len(manifest['format_paths']) == 43 and len(manifest['scoped_paths']) == 58
assert all(digest(ROOT / name) == value for name, value in (manifest['source_files'] | manifest['authorities']).items())
release = read(E / 'upstream122-v02110-postreview-release.json')
assert release['status'] == 'RELEASED_FOR_FRESH_FINAL_GATES' and release['candidate_sha256'] == digest(manifest_path)
for item in release['reviews']:
    assert digest(ROOT / item['path']) == item['sha256']
    report = read(ROOT / item['path'])
    assert report['verdict'].startswith('PASS') and report['findings'] == []

supervisor = read(E / 'upstream122-v02110-postreview-gates.json')
assert supervisor['status'] == 'PASS_COMMANDS_REQUIRES_RECEIPT_AUDIT_AND_FINAL_DOC_REVIEW'
assert supervisor['candidate_sha256'] == digest(manifest_path)
gates = {}
for gate in supervisor['gates']:
    name = gate['gate']
    assert name not in gates and gate['actual_exit'] == 0
    paths = list(E.glob(f'upstream122-v02110-postreview-{name}-*.json'))
    assert len(paths) == 1, (name, paths)
    receipt = read(paths[0])
    assert receipt['status'] == 'PASS' and receipt['actual_exit'] == 0 and receipt['source_stable'] is True
    assert receipt['head'] == manifest['head']
    assert digest(ROOT / receipt['log']) == receipt['log_sha256']
    gates[name] = {'receipt': str(paths[0].relative_to(E)), 'sha256': digest(paths[0]), 'actual_exit': 0,
                   'source_stable': True, 'elapsed_ms': receipt['elapsed_ms']}
    if name == 'full58':
        assert receipt['command'][-58:] == manifest['scoped_paths']
        assert receipt['nonzero_execution'] is True
        assert all(c['failures'] == c['excluded'] == c['skipped'] == 0 and c['tests'] == c['executed'] > 0 for c in receipt['counts'])
        full_counts = receipt['counts']
        assert sum(c['executed'] for c in full_counts) == 853
assert set(gates) == {'format43', 'strict-compile', 'full58', 'public63', 'matrix135', 'browser3'}

public_path = E / 'upstream122-v02110-postreview-public63/qualification.json'
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

matrix_path = E / 'upstream122-v02110-postreview-matrix135/qualification.json'
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

browser_path = E / 'upstream122-v02110-postreview-browser3/qualification.json'
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

provenance = E / 'upstream122-v02110-provenance.json'
assert digest(provenance) == 'b9388af71f60055f0beba90f7f9d301472032ddabb607189ea78cdd0eef112cc'
assert digest(ROOT / 'mix.lock') == 'c93b608b77c457e4324430544c1acc2b384ee21e1a2b8ab528bad248ac666cb6'
report = {'kind': 'UPSTREAM122_V02110_POSTREVIEW_COMPLETE_EVIDENCE_AUDIT',
          'status': 'PASS_ALL_REQUIRED_GATES_PENDING_DOC_CLOSURE_AND_COMMIT',
          'baseline': manifest['head'], 'checked_at_utc': datetime.now(timezone.utc).isoformat(),
          'script_sha256': digest(Path(__file__)), 'candidate_manifest_sha256': digest(manifest_path),
          'frozen_owned_files': 52, 'frozen_authorities': 5, 'frozen_source_stable': True,
          'reviews': release['reviews'], 'gates': gates, 'full58_counts': full_counts,
          'full58_executed': sum(c['executed'] for c in full_counts),
          'qualifications': {name: {'sha256': digest(path), 'executed': count, 'status': 'PASS'} for name, path, count in
                             [('public63', public_path, 63), ('matrix135', matrix_path, 135), ('browser3', browser_path, 3)]},
          'public_command_groups_joined': len(public['commands']), 'public_artifacts_hash_verified': len(public['artifacts']),
          'matrix_manifest_complete': True, 'matrix_cases_unique': 135, 'matrix_exclusions': [], 'matrix_skips': [],
          'matrix_main_peer_joins': 4, 'matrix_loaded_modules_verified': matrix_modules,
          'browser_peer_joins': 3, 'browser_process_joins': 3, 'browser_artifacts_hash_verified': len(browser['artifact_hashes']),
          'browser_loaded_modules_verified': browser_modules, 'negative_browser_cleanup': 'UNCONFIRMED_WITH_RETAINED_FAILURE',
          'upstream_provenance': {'path': provenance.name, 'sha256': digest(provenance), 'issue_state': 'closed', 'cohort': '0.21.10'},
          'retained_failures': {'old_cancel_full58': {'executed': 845, 'failed': 1, 'exit': 2},
                                'v02110_pre_repair_full58_runs': 2, 'fixture_sol20_red': {'executed': 34, 'failed': 22, 'exit': 2}},
          'fixture_sol20_green': {'executed': 34, 'failed': 0, 'exit': 0},
          'stage_commit': 'NOT_RUN', 'successor': 'NOT_RUN', 'astra_recovery': '2/2'}
report_path = E / 'upstream122-v02110-postreview-complete-evidence-audit.json'
assert not report_path.exists()
report_path.write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
