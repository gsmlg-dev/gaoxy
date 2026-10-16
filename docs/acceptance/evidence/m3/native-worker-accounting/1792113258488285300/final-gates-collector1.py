import datetime as dt
import hashlib
import json
from pathlib import Path

R = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E = R / 'docs/acceptance/evidence/m3/native-worker-accounting/1792113258488285300'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(name):
    return json.loads((E / name).read_text())


candidate = load('full-stage-candidate2.json')
for field, base in [('source_manifest', R), ('evidence_manifest', E)]:
    for name, row in candidate[field].items():
        path = base / name
        assert sha(path) == row['sha256'] and path.stat().st_size == row['bytes'], name
for name, expected in candidate['protected'].items():
    assert sha(Path(name)) == expected, name
reviews = {}
for name in ['full-stage-spec2.json', 'full-stage-code2.json']:
    receipt = load(name)
    verdict = receipt.get('verdict', receipt['status'])
    assert verdict == 'PASS', (name, verdict)
    binding = receipt.get('candidate_sha256', receipt.get('bindings', {}).get('candidate_sha256'))
    assert binding == sha(E / 'full-stage-candidate2.json'), name
    reviews[name] = {'sha256': sha(E / name), 'status': receipt['status'], 'verdict': verdict}

gates = {}
for name, expected in [('acceptance-fresh1', 561), ('compile-fresh1', None),
                       ('format-fresh1', None), ('core-consumer-fresh1', 1),
                       ('http-consumer-fresh1', 2)]:
    receipt = load(name + '.json')
    assert receipt['status'] == 'PASS', name
    assert receipt['actual_exit_code'] == 0 and receipt['joined'] and receipt['source_stable'], name
    assert not receipt['timed_out'] and not receipt['interrupted'] and not receipt['shutdown_actions'], name
    assert receipt['warning_count'] == 0, name
    assert receipt['source_before'] == receipt['source_after'], name
    assert sha(Path(receipt['log_path'])) == receipt['log_sha256'], name
    assert all(receipt['counts'][k] == 0 for k in ['failures', 'skipped', 'excluded']), name
    if expected is not None:
        assert receipt['executed_test_invocations'] == expected, name
    if name == 'acceptance-fresh1':
        assert len([arg for arg in receipt['argv'] if arg.endswith('_test.exs')]) == 30
    compared = 0
    for source, row in receipt['source_after'].items():
        if source in candidate['source_manifest']:
            assert row['sha256'] == candidate['source_manifest'][source]['sha256'], (name, source)
            compared += 1
    gates[name] = {'sha256': sha(E / (name + '.json')), 'counts': receipt['counts'],
                   'actual_exit_code': 0, 'joined': True, 'source_stable': True,
                   'reviewed_source_identities_compared': compared}

browser = load('browser-command6.json')
assert browser['status'] == 'PASS' and browser['actual_exit_code'] == 0 and browser['joined']
assert browser['owned_group_gone'] and browser['source_stable'] and not browser['timed_out']
assert browser['wait_error'] is None
assert not browser['descendant_cleanup']['forced'] and not browser['descendant_cleanup']['remaining']
assert sha(Path(browser['log'])) == browser['log_sha256']
assert sha(Path(browser['qualification'])) == browser['qualification_sha256']
qualification = json.loads(Path(browser['qualification']).read_text())
assert qualification['status'] == 'PASS' and qualification['executed'] == 2 and qualification['source_stable']
assert len(qualification['cases']) == 2 and {c['mode'] for c in qualification['cases']} == {'h1', 'h2'}
assert all(c['status'] == 'PASS' for c in qualification['cases'])
assert len(qualification['joins']) == 6
assert all(j['exit'] == 0 and not j['forced'] and j['reader_joined'] and j['owned_group_gone']
           for j in qualification['joins'])
assert not qualification['adopted_remaining']
for name, expected in qualification['artifact_sha256'].items():
    assert sha(Path(browser['qualification']).parent / name) == expected, name
for name, expected in browser['source_after'].items():
    if name in candidate['source_manifest']:
        assert expected == candidate['source_manifest'][name]['sha256'], name

result = {'kind': 'FINAL_POST_REVIEW_GATE_BINDING', 'status': 'PASS_RUNTIME_GATES_PENDING_DOCUMENT_AND_GIT_CLOSURE',
          'at_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
          'candidate_sha256': sha(E / 'full-stage-candidate2.json'), 'reviews': reviews,
          'reviewed_source_count': len(candidate['source_manifest']),
          'reviewed_evidence_count': len(candidate['evidence_manifest']), 'gates': gates,
          'browser_command_sha256': sha(E / 'browser-command6.json'),
          'browser_qualification_sha256': browser['qualification_sha256'],
          'browser_executed': 2, 'browser_fixture_Actors': 6,
          'browser_adopted_waits': qualification['adopted_joins'],
          'browser_adopted_remaining': [], 'protected_files_match': True,
          'counters': {'group_failed_GREEN': 41, 'root_failure_events': 54, 'stage_failed_GREEN': 11,
                       'stage_production_repairs': 3, 'stage_completed_fixture_repairs': 7,
                       'stage_test_coverage_repairs': 1, 'full_stage_failed_SPEC': 1,
                       'nonaccepted_diagnostic_failures': 4, 'astra_used': 2, 'astra_limit': 2},
          'publication': 'NOT_RUN_NOT_AUTHORIZED_FOR_THIS_STAGE', 'whole_M3': 'INCOMPLETE'}
with (E / 'final-gates1.json').open('x') as out:
    json.dump(result, out, indent=2, sort_keys=True)
    out.write('\n')
print(json.dumps({'status': result['status'], 'tests': 561, 'browser_cases': 2,
                  'consumers': [1, 2], 'all_reviewed_source_and_evidence_unchanged': True}))
