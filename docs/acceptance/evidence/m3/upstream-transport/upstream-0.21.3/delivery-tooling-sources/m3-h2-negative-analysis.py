import hashlib
import json
from pathlib import Path
import re

root = Path.cwd().resolve()
out = root / 'docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.3'
manifest = json.loads((root / '.audit/m3-transport/h2-failure-regressions/manifest.json').read_text())
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
rows = []
for probe in manifest['probes']:
    name = 'h2-negative-' + probe['name'] + '1'
    receipt = json.loads((out / (name + '.json')).read_text())
    ownership = json.loads((out / (name + '-parent-ownership.json')).read_text())
    assert receipt['exit'] == 1 and not receipt['timed_out'] and receipt['inputs_match']
    assert sha(out / receipt['log']) == receipt['log_sha256']
    assert not receipt['owned_peer_processes_before'] and not receipt['owned_peer_processes_after']
    assert ownership['collector_exit'] == 0 and ownership['parent_inputs_match']
    assert ownership['group_members_observed'] and not ownership['group_members_after']
    assert ownership['vm_proc_after_exists'] is False
    before = json.loads((out / (name + '-parent-inputs-before.json')).read_text())
    after = json.loads((out / (name + '-parent-inputs-after.json')).read_text())
    assert before == after and len(before) == ownership['parent_frozen_inputs'] == 1285
    for path, expected in after.items():
        assert sha(path) == expected
    log = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', (out / receipt['log']).read_text())
    def records(tag):
        return [json.JSONDecoder().raw_decode(line.split(tag + ' ', 1)[1])[0]
                for line in log.splitlines() if tag + ' ' in line]
    identity, = records('TLS95_IDENTITY_BEFORE')
    case, = records('H2_FUNCTIONAL_CASE')
    summary, = records('H2_FUNCTIONAL_SUMMARY')
    vm, = records('H2_NEGATIVE_VM_IDENTITY')
    assert int(vm['vm_os_pid']) == ownership['vm_os_pid']
    assert not records('TLS95_IDENTITY_AFTER') and not records('TLS95_WRAPPER_OUTCOME')
    assert identity['cohort'] == '0.21.3' and len(identity['inputs']) == 1285
    assert {row['path']: row['sha256'] for row in identity['inputs']} == before
    assert summary['cases'] == [probe['case']] and case['case'] == probe['case']
    assert summary['executed'] == summary['failed'] == summary['exit'] == 1
    assert summary['skipped'] == 0 and summary['source_stable'] and summary['python_stable']
    assert summary['source_before'] == summary['source_after']
    operations = {operation['operation']: operation for operation in case['operations']}
    assert len(operations) == len(case['operations'])
    assert operations['negative_acquired_request_barrier']['result'] == ':ok'
    assert case['peer_exit'] == 0 and case['peer_port_down'] == ':normal'
    stopped, = [event for event in case['events'] if event['event'] == 'stopped']
    assert stopped['live_threads'] == 0 and stopped['accepts'] == stopped['requests'] == 1
    assert not stopped['failed'] and not case['forced_cleanup']
    assert len(case['controls']) <= 3 and len(case['events']) <= 128
    assert case['cleanup_deadline_ms'] - case['oracle_deadline_ms'] == 5000
    if probe['name'] == 'repair1-lost-alias-follow':
        assert summary['status'] == case['status'] == 'BLOCKED_HANDOFF'
        assert case['promise_acquired'] and case['promise_await'] == 'failed'
        assert 'Task.await(' in case['primary'] and '** (EXIT) time out' in case['primary']
        assert 'time out' in operations['response']['result']
        assert operations['failure_abort']['result'] == ':ok' and 'failure_response' not in operations
        assert len(case['cleanup_errors']) == 1
        assert 'original Promise response ownership unconfirmed' in case['cleanup_errors'][0]
        assert operations['unsupported_completion']['result'] == '{:error, {:unsupported_completion, :redirect}}'
    else:
        assert summary['status'] == case['status'] == 'FAIL'
        assert 'NEGATIVE_PRIMARY_AFTER_ACQUISITION' in case['primary']
        assert not case['cleanup_errors']
        if probe['source_base'] == 'repair1':
            assert case['promise_acquired'] and case['promise_await'] == 'resolved'
            assert operations[probe['failure_cancellation_operation']]['result'] == ':ok'
            assert 'failure_response' in operations and 'failure_stream_down' in operations
            assert 'response' not in operations
        else:
            assert all(operation not in operations for operation in
                       ['failure_abort', 'failure_abort_and_await', 'failure_response', 'failure_stream_down'])
    directory = out / (name + '-artifacts')
    assert json.loads((directory / 'results.json').read_text()) == summary
    assert json.loads((directory / (case['case'] + '.json')).read_text()) == case
    with (out / (name + '-loaded-before.json')).open('x') as stream:
        stream.write(json.dumps(identity, indent=2, sort_keys=True) + '\n')
    rows.append({'probe': probe['name'], 'case': case['case'], 'actual_vm_exit': 1,
                 'fixture_status': case['status'], 'original_primary_failure_retained': True,
                 'operations': case['operations'], 'cleanup_errors': case['cleanup_errors'],
                 'peer_exit': 0, 'peer_port_down': ':normal', 'vm_process_group_joined': True,
                 'parent_frozen_inputs': 1285, 'wrapper_post_identity': 'NOT_RUN_SYSTEM_HALT',
                 'artifacts': [{'path': str(path.relative_to(root)), 'sha256': sha(path)}
                               for path in sorted(directory.iterdir()) if path.is_file()]})
analysis = {'status': 'PASS_EXPECTED_NEGATIVE_REGRESSION_ORACLES', 'probes': 5,
            'normal_suite_cases_added': 0, 'actual_nonzero_vm_exits': 5,
            'source': 'Pinned prerepair source lacks acquisition cancellation; repaired source performs public cancellation before stream exposure and never retries a failed await',
            'fixture_failures_preserved': 4, 'fixture_blocked_handoffs_preserved': 1,
            'loaded_after_identity': 'NOT_RUN_FOR_NEGATIVES', 'rows': rows,
            'analysis_tool_sha256': sha(Path(__file__)),
            'claim': 'Expected failure-path behavior and dedicated VM/peer shutdown; no native reclamation or M3 acceptance proof'}
with (out / 'h2-acquisition-failure-regression-analysis.json').open('x') as stream:
    stream.write(json.dumps(analysis, indent=2) + '\n')
print('PASS_EXPECTED_NEGATIVE_REGRESSION_ORACLES five probes; all real exit1; original fourFAIL/oneBLOCKED_HANDOFF preserved')
