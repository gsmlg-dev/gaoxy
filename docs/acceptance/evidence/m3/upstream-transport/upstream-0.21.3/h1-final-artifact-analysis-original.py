import hashlib
import json
from pathlib import Path
import re
import sys

root = Path.cwd()
out = root / 'docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.3'
name, mode = sys.argv[1:]
receipt = json.loads((out / (name + '.json')).read_text())
assert receipt['status'] == 'PASS_COMMAND' and receipt['exit'] == 0
assert receipt['inputs_match'] and not receipt['timed_out']
assert not receipt['owned_peer_processes_before'] and not receipt['owned_peer_processes_after']
log = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', (out / receipt['log']).read_text())
assert 'clauses with the same name' not in log and 'should be grouped together' not in log
cases = [json.JSONDecoder().raw_decode(line.split('H1_ACCOUNTING_FIXTURE_CASE ', 1)[1])[0]
         for line in log.splitlines() if 'H1_ACCOUNTING_FIXTURE_CASE ' in line]
summaries = [json.JSONDecoder().raw_decode(line.split('H1_ACCOUNTING_FIXTURE_SUMMARY ', 1)[1])[0]
             for line in log.splitlines() if 'H1_ACCOUNTING_FIXTURE_SUMMARY ' in line]
assert len(summaries) == 1
summary = summaries[0]
expected = ['B%02d' % number for number in range(1, 21)] if mode == 'baseline' else ['B21']
assert summary['ids'] == expected and sorted(c['id'] for c in cases) == expected
assert summary['tests'] == receipt['tests'] == len(expected)
assert summary['failures'] == receipt['failures'] == summary['skipped'] == summary['excluded'] == 0
assert summary['cases_passed'] == len(expected)
for case in cases:
    cleanup = case['cleanup']
    assert case['status'] == 'PASS_FUNCTIONAL' and case['joins']
    assert case['run_origin'] == summary['run_origin']
    assert cleanup['identity_stable'] and not cleanup['failed_steps'] and cleanup['peer']['ok']
    assert cleanup['actors_joined'] == cleanup['actors_total']
    assert cleanup['uploads_joined'] == cleanup['uploads_total']
audit = root / '.audit/m3-transport/h1-slice-b-implementation'
assert json.loads((audit / 'summary.json').read_text()) == summary
saved = out / (name + '-artifacts')
saved.mkdir()
artifacts = []
sha = lambda data: hashlib.sha256(data).hexdigest()
for path in sorted(audit.rglob('*')):
    if path.is_file():
        relative = path.relative_to(audit)
        target = saved / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        data = path.read_bytes()
        with target.open('xb') as stream:
            stream.write(data)
        artifacts.append({'path': str(relative), 'sha256': sha(data), 'bytes': len(data)})
source_rows = []
for relative in ['integration/http_fetch_contract/managed_h1_accounting_fixture.exs',
                 'integration/http_fetch_contract/managed_h1_accounting_fixture_test.exs',
                 'integration/http_fetch_contract/managed_h1_accounting_peer.py']:
    data = (root / relative).read_bytes()
    assert sha(data) == json.loads((out / receipt['source_before']).read_text())[relative]
    target = saved / Path(relative).name
    with target.open('xb') as stream:
        stream.write(data)
    source_rows.append({'source': relative, 'saved': str(target.relative_to(root)), 'sha256': sha(data)})
analysis = {'status': 'PASS_FUNCTIONAL_BASELINE20' if mode == 'baseline' else 'PASS_FUNCTIONAL_B21',
            'tests': len(expected), 'failures': 0, 'skipped': 0, 'excluded': 0, 'actual_exit': receipt['exit'],
            'grouping_warning_absent': True, 'frozen_inputs': receipt['frozen_source_and_build_files'],
            'source_snapshots': source_rows, 'artifacts': artifacts,
            'rows': [{'id': c['id'], 'joins': c['joins'], 'controls_charged': c['outstanding_controls']}
                     for c in sorted(cases, key=lambda c: c['id'])],
            'native_frontier': 'UNESTABLISHED', 'activation': 'DISABLED',
            'analysis_tool_sha256': sha(Path(__file__).read_bytes())}
if mode != 'baseline':
    case, = cases
    oracle = case['oracle']
    assert oracle['connections'] == oracle['accepted'] == oracle['clienthellos'] == 2
    assert oracle['capacity'] == ['error', ['transport_scope_capacity', 'connections']]
    assert oracle['no_third_accept'] and oracle['third_completion'] == 'ok'
    assert oracle['initial_completions'] == [['error', 'cleanup_pending']] * 2
    assert oracle['terminal_completions'] == [['error', 'cleanup_unconfirmed']] * 2
    assert oracle['initial_retirement'] == ['error', 'cleanup_pending']
    assert oracle['terminal_retirement'] == ['error', 'cleanup_unconfirmed']
    assert oracle['public_errors'] == [['error', 'aborted']] * 2 and oracle['refunds'] == 0
    assert case['outstanding_controls'] == 8 and case['occupied_attempts'] == [3, 0, 0, 0]
    analysis.update(oracle=oracle, cleanup=case['cleanup'], outstanding_controls=8,
                    occupied_attempts=case['occupied_attempts'])
    analysis['jsonl'] = []
    for artifact in artifacts:
        if artifact['path'].endswith('.jsonl'):
            lines = (saved / artifact['path']).read_bytes().splitlines()
            assert len(lines) == (3 if 'attempt' in artifact['path'] else 1)
            assert all(len(line) <= 2048 for line in lines)
            analysis['jsonl'].append({'path': artifact['path'], 'rows': len(lines),
                                      'max_row_bytes': max(map(len, lines))})
with (out / (name + '-analysis.json')).open('x') as stream:
    stream.write(json.dumps(analysis, indent=2) + '\n')
print(analysis['status'], len(expected), 'cases;', len(artifacts), 'raw artifacts retained; no grouping warning')
