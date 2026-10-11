"""Create exclusive H2 acquisition-failure snapshots; execute no VM or peer."""
import ast
import difflib
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / '.audit/m3-transport/h2-failure-regressions'
SOURCES = {
    'repair1': ('integration/http_fetch_contract/h2_functional_supplement.exs',
                '89cd7237a5864d86e9ffbd7f5f323a275ec9cad1d36cd4f03fc8881842cccbef'),
    'prerepair': ('docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.3/h2-functional-supplement-repair1-original.exs',
                  '83a947b179ce40e3f2b1e511fe3dd8f4995cd4fcff1743bb2b540d9141b43c62'),
    'peer': ('integration/http_fetch_contract/h2_functional_supplement_peer.py',
             'b1bcff8b19eba8c7bccb315ecd3ee66be860816128e76b2a15b5a36e0968f170'),
    'qualification_plan': ('docs/plans/m3-h2-0.21.3-functional-supplement.md',
                           '25fdfb876f7e83f65b97414816a6a82c258ec8f789f0d0eb7f4e07f627ad7270'),
}
PLAN = ROOT / 'docs/plans/m3-h2-acquisition-failure-regressions.md'
ANCHOR = '        deadline = state().oracle_deadline\n\n'
BARRIER = '''        %{"connection" => 1} = event("accept", capped(deadline))
        %{"connection" => 1, "end_stream" => true, "upload_bytes" => 0, "stream" => sid} =
          event("request", capped(deadline))
        true = is_integer(sid) and sid > 0
        operation("negative_acquired_request_barrier", :ok, deadline)

'''
RAISE = '        raise "NEGATIVE_PRIMARY_AFTER_ACQUISITION"\n\n'
HEADER = '                            self.conn.send_headers(self.stream, [(":status", "200")], end_stream=False)\n'
PROBES = [
    ('repair1-acquired-manual', 'repair1', 'H2C98_LATE', ':late', False),
    ('repair1-acquired-follow', 'repair1', 'H2C100_ABORT', ':abort', False),
    ('repair1-lost-alias-follow', 'repair1', 'H2C100_ABORT', ':abort', True),
    ('prerepair-acquired-manual', 'prerepair', 'H2C98_LATE', ':late', False),
    ('prerepair-acquired-follow', 'prerepair', 'H2C100_ABORT', ':abort', False),
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write(path, data):
    with path.open('xb') as stream:
        stream.write(data)
    return {'path': str(path.resolve()), 'sha256': sha(data), 'bytes': len(data)}


def encode(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def diff(before, after, original, snapshot):
    return ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                      fromfile=original, tofile=str(snapshot))).encode()


def build():
    assert Path.cwd().resolve() == ROOT, 'Run from the pinned qualification worktree'
    assert not OUT.exists(), 'Never overwrite a prior regression snapshot'
    originals = {}
    for key, (relative, expected) in SOURCES.items():
        data = (ROOT / relative).read_bytes()
        assert sha(data) == expected, relative
        originals[key] = data
    plan = PLAN.read_bytes()
    builder = Path(__file__).resolve().read_bytes()
    assert originals['peer'].decode().count(HEADER) == 1
    assert originals['repair1'].decode().count('length(results) == 8') == 1
    assert originals['prerepair'].decode().count('length(results) == 8') == 1
    OUT.mkdir()
    (OUT / 'originals').mkdir()
    artifacts = [write(OUT / 'builder-source.py', builder)]
    for key in ['repair1', 'prerepair', 'peer']:
        suffix = '.py' if key == 'peer' else '.exs'
        artifacts.append(write(OUT / 'originals' / (key + suffix), originals[key]))
    rows = []
    for name, base, case, kind, timeout in PROBES:
        directory = OUT / name
        directory.mkdir()
        before = originals[base].decode()
        matches = list(re.finditer(r'  @cases \[\n.*?\n  \]\n', before, re.S))
        assert len(matches) == 1
        original_cases = matches[0].group()
        assert original_cases.count('{"') == 8
        selected = f'  @cases [{{"{case}", "h2c", {kind}}}]\n'
        injection = BARRIER + ('' if timeout else RAISE)
        assert before.count(ANCHOR) == 1 and injection not in before
        after = before.replace(original_cases, selected, 1).replace(ANCHOR, ANCHOR + injection, 1)
        restored = after.replace(ANCHOR + injection, ANCHOR, 1).replace(selected, original_cases, 1)
        assert restored == before, 'Only case selection and barrier/injection may change'
        assert after.count('length(results) == 8') == 1
        assert after.count('shutdowns == 8') == 1
        for text in ['oracle_deadline: t0 + 10_000, cleanup_deadline: t0 + 15_000',
                     'timeout: 6_000', 'connect_timeout: 2_000',
                     'observe("response", deadline, 2_000,']:
            assert text in before and text in after, text
        peer_before = originals['peer'].decode()
        peer_after = peer_before.replace(HEADER, '', 1) if timeout else peer_before
        assert not timeout or peer_after.replace('                            self.stream = event.stream_id\n',
                                                 '                            self.stream = event.stream_id\n' + HEADER, 1) == peer_before
        ast.parse(peer_after)
        source_path = directory / 'h2_functional_supplement.exs'
        peer_path = directory / 'h2_functional_supplement_peer.py'
        source_row = write(source_path, after.encode())
        peer_row = write(peer_path, peer_after.encode())
        source_diff = write(directory / 'source.diff', diff(before, after, SOURCES[base][0], source_path))
        peer_diff = write(directory / 'peer.diff', diff(peer_before, peer_after, SOURCES['peer'][0], peer_path))
        artifacts.extend([source_row, peer_row, source_diff, peer_diff])
        repaired = base == 'repair1'
        expected_operation = ('failure_abort_and_await' if kind == ':late' else 'failure_abort')
        rows.append({
            'name': name, 'case': case, 'source_base': base, 'source': source_row, 'peer': peer_row,
            'source_diff': source_diff, 'peer_diff': peer_diff,
            'reverse_reconstruction_sha256': sha(restored.encode()),
            'case_selection_count': 1, 'unchanged_required_qualification_count': 8,
            'barrier': 'Exact public accept1/request1, GET /target, end_streamtrue/upload_bytes0/positive stream ID, before first Promise.await',
            'primary_oracle': ('Real first Promise.await Task.await timeout at original2s cap; promise_awaitfailed'
                               if timeout else 'NEGATIVE_PRIMARY_AFTER_ACQUISITION before first await'),
            'expected_case_status': 'BLOCKED_HANDOFF' if timeout else 'FAIL',
            'expected_child_exit': 1,
            'failure_cancellation_operation': expected_operation if repaired else None,
            'expected_red_absence': [] if repaired else ['failure_abort_and_await', 'failure_abort', 'failure_response'],
            'no_retry': timeout,
            'dedicated_vm_termination_required': True,
            'evidence_directory_must_be_new': True,
            'runtime': 'NOT_RUN',
        })
    manifest = {
        'schema': 1, 'status': 'PASS_STATIC_SNAPSHOT_BUILD_RUNTIME_NOT_RUN',
        'task_id': 'h2_acquisition_failure_regressions', 'worktree': str(ROOT),
        'builder': {'path': str(Path(__file__).resolve()), 'sha256': sha(builder)},
        'plan': {'path': str(PLAN), 'sha256': sha(plan)},
        'original_inputs': {str((ROOT / path).resolve()): digest for path, digest in SOURCES.values()},
        'deadlines_ms': {'oracle': 10000, 'cleanup': 15000, 'request': 6000,
                         'connect': 2000, 'first_response_await_cap': 2000},
        'normal_qualification_cases_unchanged': 8, 'production_edits': False,
        'probes': rows, 'artifacts': artifacts,
        'parent_requirements': ['Merge absolute input bindings with existing common172+source/wrapper/BEAM/native inputs',
                                'Fresh independent review before dedicated VM execution',
                                'Run all five snapshots as genuine nonzero children; record original failure and cleanup separately',
                                'Original System.halt(1) ends the VM before wrapper post-identity; retain partial identity and outer freezes without claiming wrapper-after PASS',
                                'Confirm process-group/peer shutdown; lost-alias BLOCKED_HANDOFF requires dedicated VM end'],
        'repair_counters_added': 0,
    }
    manifest_row = write(OUT / 'manifest.json', encode(manifest))
    bindings = {str((ROOT / path).resolve()): digest for path, digest in SOURCES.values()}
    bindings.update({str(Path(__file__).resolve()): sha(builder), str(PLAN): sha(plan)})
    bindings.update({row['path']: row['sha256'] for row in artifacts + [manifest_row]})
    bindings_row = write(OUT / 'input-bindings.json', encode(bindings))
    for path, expected in bindings.items():
        assert sha(Path(path).read_bytes()) == expected
    print(json.dumps({'status': 'PASS_STATIC_BUILD', 'plan_sha256': sha(plan),
                      'builder_sha256': sha(builder), 'manifest': manifest_row,
                      'input_bindings': bindings_row, 'snapshot_count': len(rows),
                      'binding_count': len(bindings), 'runtime': 'NOT_RUN'}, sort_keys=True))


if __name__ == '__main__':
    build()
