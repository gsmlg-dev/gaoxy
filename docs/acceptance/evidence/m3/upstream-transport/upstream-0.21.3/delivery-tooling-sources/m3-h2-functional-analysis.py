import hashlib
import json
from pathlib import Path
import re
import sys

root = Path.cwd()
out = root / 'docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.3'
name = sys.argv[1]
receipt = json.loads((out / (name + '.json')).read_text())
assert receipt['status'] == 'PASS_COMMAND' and receipt['exit'] == 0
assert not receipt['timed_out'] and receipt['inputs_match']
assert not receipt['owned_peer_processes_before'] and not receipt['owned_peer_processes_after']
log = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', (out / receipt['log']).read_text())
def records(tag):
    return [json.JSONDecoder().raw_decode(line.split(tag + ' ', 1)[1])[0]
            for line in log.splitlines() if tag + ' ' in line]
cases = records('H2_FUNCTIONAL_CASE')
summary, = records('H2_FUNCTIONAL_SUMMARY')
before, = records('TLS95_IDENTITY_BEFORE')
after, = records('TLS95_IDENTITY_AFTER')
wrapper, = records('TLS95_WRAPPER_OUTCOME')
assert wrapper == {'primary': {'status': 'OK'}, 'post_identity': {'status': 'OK'}}
expected = ['TLS98_LATE', 'TLS98_EARLY', 'TLS100_ABORT', 'TLS100_DEADLINE',
            'H2C98_LATE', 'H2C98_EARLY', 'H2C100_ABORT', 'H2C100_DEADLINE']
assert [case['case'] for case in cases] == summary['cases'] == expected
assert summary['status'] == 'PASS' and summary['executed'] == summary['peer_shutdowns'] == 8
assert summary['tls'] == summary['h2c'] == 4
assert summary['skipped'] == summary['failed'] == summary['exit'] == 0
assert summary['source_stable'] and summary['source_before'] == summary['source_after']
assert summary['python_stable'] and summary['python_identity']['packages'] == {
    'h2': '4.3.0', 'hpack': '4.1.0', 'hyperframe': '6.1.0'}
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
for path, expected_hash in summary['source_before'].items():
    assert sha(path) == expected_hash
assert before['cohort'] == after['cohort'] == '0.21.3'
assert before['applications'] == after['applications'] and before['inputs'] == after['inputs']
assert after['static_inputs_unchanged']
assert before['runtime']['applications'] == after['runtime']['applications']
for key, value in before['runtime'].items():
    if key not in ['actual_loaded_modules', 'mapped_files', 'jit_memory_exclusions']:
        assert after['runtime'][key] == value
for key in ['actual_loaded_modules', 'mapped_files']:
    original = {json.dumps(row, sort_keys=True) for row in before['runtime'][key]}
    final = {json.dumps(row, sort_keys=True) for row in after['runtime'][key]}
    assert original <= final
for identity in [before, after]:
    for row in identity['runtime']['actual_loaded_modules']:
        if 'beam_path' in row:
            assert sha(row['beam_path']) == row['beam_sha256']
            assert row['loaded_code_md5'] == row['disk_code_md5']
    for row in identity['runtime']['mapped_files']:
        assert sha(row['path']) == row['sha256']
rows = []
for case in cases:
    assert case['status'] == 'PASS' and not case['cleanup_errors'] and not case['forced_cleanup']
    assert case['peer_shutdown'] and case['peer_exit'] == 0 and case['peer_port_down'] == ':normal'
    assert case['promise_acquired'] and case['promise_await'] == 'resolved'
    assert case['cleanup_deadline_ms'] - case['oracle_deadline_ms'] == 5000
    assert len(case['controls']) <= 3 and len(case['events']) <= 128
    assert all(len(json.dumps(event, separators=(',', ':')).encode()) + 1 <= 4096
               for event in case['events'])
    events = case['events']
    accept, = [event for event in events if event['event'] == 'accept']
    request, = [event for event in events if event['event'] == 'request']
    reset, = [event for event in events if event['event'] == 'reset']
    stopped, = [event for event in events if event['event'] == 'stopped']
    assert accept['connection'] == request['connection'] == reset['connection'] == 1
    assert request['end_stream'] and request['upload_bytes'] == 0
    assert stopped['live_threads'] == 0 and stopped['accepts'] == stopped['requests'] == stopped['resets'] == 1
    assert not stopped['failed'] and stopped['controls'] == len(case['controls'])
    assert not any(event['event'] == 'failure' for event in events)
    closed, = [event for event in events if event['event'] == 'closed']
    assert closed['owned_shutdown']
    operations = {operation['operation']: operation for operation in case['operations']}
    parser = '98_' in case['case']
    reason = ':invalid_headers_transition' if parser else (':aborted' if 'ABORT' in case['case'] else ':request_timeout')
    assert reset['code'] == (1 if parser else 8) and reset['stream'] == request['stream']
    assert operations['exact_terminal_error']['result'] == reason
    assert operations['exactly_one_terminal_error_and_normal_stream_down']['result'] == ':ok'
    if parser:
        assert operations['original_completion_after_reader']['result'] == ':ok'
        assert operations['original_completion_repeated']['result'] == ':ok'
        malformed, = [event for event in events if event['event'] == 'malformed_trailers']
        assert malformed['successful_send'] and malformed['wire_hex'].endswith('0001780176')
        if 'LATE' in case['case']:
            assert operations['original_completion_before_reader']['result'] == '{:error, :cleanup_pending}'
        else:
            assert operations['reader_attached_and_sentinel_acked']['result'] == ':ok'
    else:
        assert operations['unsupported_completion']['result'] == '{:error, {:unsupported_completion, :redirect}}'
        assert not any('original_completion' in operation for operation in operations)
    if case['protocol'] == 'tls':
        tls, = [event for event in events if event['event'] == 'tls']
        assert tls['alpn'] == 'h2' and 'verify_peer' in case['options']
        assert not Path(case['ready']['ca']).parent.exists()
    rows.append({'case': case['case'], 'protocol': case['protocol'], 'reset_code': reset['code'],
                 'terminal_error': reason, 'peer_exit': 0, 'peer_port_down': ':normal',
                 'cleanup_errors': [], 'public_completion': 'confirmed' if parser else 'unsupported_redirect'})
artifacts_dir = Path(receipt['argv'][-1])
assert json.loads((artifacts_dir / 'results.json').read_text()) == summary
for case in cases:
    assert json.loads((artifacts_dir / (case['case'] + '.json')).read_text()) == case
for suffix, value in [('loaded-before', before), ('loaded-after', after), ('wrapper-outcome', wrapper)]:
    with (out / (name + '-' + suffix + '.json')).open('x') as stream:
        stream.write(json.dumps(value, indent=2, sort_keys=True) + '\n')
analysis = {'status': 'PASS_PUBLIC_H2_FUNCTIONAL8', 'actual_exit': 0,
            'executed': 8, 'tls': 4, 'h2c': 4, 'failed': 0, 'skipped': 0, 'peer_shutdowns': 8,
            'frozen_collector_inputs': receipt['frozen_source_and_build_files'],
            'wrapper': wrapper, 'directed_loaded_row_preservation': True,
            'rows': rows, 'source_before': summary['source_before'],
            'artifacts': [{'path': str(path.relative_to(root)), 'sha256': sha(path), 'bytes': path.stat().st_size}
                          for path in sorted(artifacts_dir.iterdir()) if path.is_file()],
            'analysis_tool_sha256': sha(Path(__file__)),
            'qualification': 'Selected public functional errors and owned joins; no managed activation, native frontier or complete M3 acceptance'}
with (out / (name + '-analysis.json')).open('x') as stream:
    stream.write(json.dumps(analysis, indent=2) + '\n')
print(analysis['status'], '8/8, TLS4/h2c4, joins8, actualexit0, directed loaded/native identity preserved')
