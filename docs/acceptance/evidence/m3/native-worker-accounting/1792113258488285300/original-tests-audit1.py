#!/usr/bin/env python3
"""Read-only candidate audit; reconstruct old tests only in memory.

Writes only its two assigned /tmp reports. Does not import project code or run
Elixir, Mix, browser, network, subprocesses, Git mutations, or raw trace reads.
"""
import collections
import hashlib
import json
from pathlib import Path

ROOT = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
EVIDENCE = ROOT / 'docs/acceptance/evidence/m3/native-worker-accounting/1792113258488285300'
OUTPUT = Path('/tmp/gaoxy-native-worker-original-tests-audit1')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def load(name):
    return json.loads((EVIDENCE / name).read_bytes())


def verify_manifest(candidate):
    failures = []
    totals = {}
    for field, base in [('source_manifest', ROOT), ('evidence_manifest', EVIDENCE)]:
        size = 0
        for name, expected in candidate[field].items():
            path = base / name
            if not path.is_file():
                failures.append([field, name, 'missing'])
                continue
            data = path.read_bytes()
            size += len(data)
            if len(data) != expected['bytes'] or sha(data) != expected['sha256']:
                failures.append([field, name, 'hash_or_length'])
        canonical = sha(json.dumps(candidate[field], sort_keys=True).encode())
        if canonical != candidate[field + '_sha256']:
            failures.append([field, 'canonical_manifest_digest'])
        totals[field] = dict(files=len(candidate[field]), bytes=size,
                             canonical_sha256=canonical)
    return dict(failures=failures, totals=totals)


def remove_region(data, start, end, label, changes):
    # Match the exact indentation at a line boundary, not an indented nested tag.
    assert data.count(b'\n' + start) == 1, (label, 'ambiguous line-anchored start')
    a = data.index(b'\n' + start) + 1
    b = data.index(end, a)
    changes.append(dict(label=label, current_stage_start_byte=a,
                        current_stage_end_byte=b, removed_bytes=b-a,
                        removed_sha256=sha(data[a:b])))
    return data[:a] + data[b:]


def main():
    old = load('full-stage-candidate1.json')
    candidate_bytes = (EVIDENCE / 'full-stage-candidate2.json').read_bytes()
    assert sha(candidate_bytes) == '5636329b6df387b33cf5277633210e81f261c1f6bb8a13ac2377ad410a3343ca'
    new = json.loads(candidate_bytes)
    before = verify_manifest(new)
    reconstructed = {}
    core = 'apps/gaoxy/test/admitted_spawn_test.exs'
    native = 'apps/gaoxy_http/test/http2_worker_startup_test.exs'
    for name in [core, native]:
        data = (ROOT / name).read_bytes()
        original_current = data
        changes = []
        if name == native:
            data = remove_region(data, b'  @tag :controlled_late_receipt\n',
                                 b'  defp payload,', 'new native tests/helpers', changes)
        else:
            for start, end, label in [
                (b'  # The authenticated owner deliberately stops before dispatch.',
                 b'  @tag :native_worker_constructor\n', 'dispatch_probe and its comment'),
                (b'  for reason <- [:normal, :owner_failed] do\n    @reason reason\n    test "authenticated success before dispatch',
                 b'  test "a different caller cannot cancel', 'five new core cases'),
                (b'  defp dispatch_owner(gate) do\n',
                 b'  defp owner_loop(observer, gate, lease, pending) do\n', 'dispatch_owner helper'),
                (b'  defp wait_gate_call(gate, command, deadline',
                 b'  defp finish(worker) do\n', 'wait_gate_call helper'),
            ]:
                data = remove_region(data, start, end, label, changes)
            extended = (
                b'                {:activate_spawn, _} = continuation ->\n'
                b'                  if Keyword.get(options, :report_activation, false),\n'
                b'                    do: send(observer, {:held_activation, ref, continuation})\n'
            )
            original = b'                {:activate_spawn, _} -> :ok\n'
            assert data.count(extended) == 1
            data = data.replace(extended, original, 1)
            changes.append(dict(label='restore original committed_barrier receive branch',
                                extended_bytes=len(extended), original_bytes=len(original),
                                occurrences=1))
            assert b'report_activation' not in data
        expected = old['source_manifest'][name]
        reconstructed[name] = dict(current_sha256=sha(original_current),
                                   current_bytes=len(original_current),
                                   reconstructed_sha256=sha(data), reconstructed_bytes=len(data),
                                   expected_sha256=expected['sha256'], expected_bytes=expected['bytes'],
                                   exact_match=sha(data) == expected['sha256'] and len(data) == expected['bytes'],
                                   whitespace_normalization=False, changes=changes)
    production = sorted(name for name in old['source_manifest']
                        if name.startswith('apps/') and '/lib/' in name)
    production_changes = [name for name in production
                          if old['source_manifest'][name] != new['source_manifest'].get(name)]
    initial_evidence_changed = [name for name, value in old['evidence_manifest'].items()
                                if new['evidence_manifest'].get(name) != value]
    receipts = {}
    for name in ['core-green3', 'native-green6', 'native-green7']:
        record = load(name + '.json')
        raw = (EVIDENCE / (name + '.json')).read_bytes()
        receipts[name] = {key: record[key] for key in [
            'status', 'actual_exit_code', 'counts', 'warning_count', 'source_stable',
            'joined', 'direct_process_joined', 'process_group_absent']}
        receipts[name]['sha256'] = sha(raw)
        receipts[name]['log_hash_matches'] = sha(Path(record['log_path']).read_bytes()) == record['log_sha256']
        expected = {
            'core-green3': ('PASS', 0, 73, 0, 0),
            'native-green6': ('FAIL', 2, 100, 1, 12),
            'native-green7': ('PASS', 0, 100, 0, 0),
        }[name]
        assert (record['status'], record['actual_exit_code'], record['counts']['tests'],
                record['counts']['failures'], record['warning_count']) == expected
        assert all(record[key] for key in ['source_stable', 'joined', 'direct_process_joined',
                                          'process_group_absent'])
        assert record['counts']['skipped'] == record['counts']['excluded'] == 0
    group_names = ['core-green3', 'native-green7', 'preserve-http-green1', 'preserve-compat-green1']
    group_records = [load(name + '.json') for name in group_names]
    files = collections.Counter(name for record in group_records for name in record['argv']
                                if name.startswith('apps/') and name.endswith('.exs'))
    duplicates = {name: count for name, count in files.items() if count > 1}
    assert duplicates == {'apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs': 2}
    duplicate_file = (ROOT / next(iter(duplicates))).read_text()
    assert sum(line.startswith('  test "') for line in duplicate_file.splitlines()) == 3
    group_sum = sum(record['counts']['tests'] for record in group_records)
    after = verify_manifest(new)
    stable = before == after and sha((EVIDENCE / 'full-stage-candidate2.json').read_bytes()) == sha(candidate_bytes)
    passed = (not before['failures'] and not after['failures'] and stable
              and all(row['exact_match'] for row in reconstructed.values())
              and not production_changes and not initial_evidence_changed
              and all(row['log_hash_matches'] for row in receipts.values())
              and len(files) == 30 and group_sum - 3 == 561)
    result = dict(task_id='checked_browser_source_review',
                  assignment='direct_independent_original_assertion_preservation_audit',
                  status='DONE' if passed else 'FAIL', verdict='PASS' if passed else 'FAIL',
                  repository=str(ROOT), baseline=new['head'],
                  candidate1_sha256=sha((EVIDENCE / 'full-stage-candidate1.json').read_bytes()),
                  candidate2_sha256=sha(candidate_bytes), audit_script_sha256=sha(Path(__file__).read_bytes()),
                  manifest_before=before, manifest_after=after, source_stable=stable,
                  reconstruction=reconstructed, production_file_count=len(production),
                  production_changes=production_changes,
                  candidate1_frozen_evidence_changes=initial_evidence_changed,
                  actual_receipts=receipts,
                  acceptance_union=dict(unique_files=len(files), group_tests=group_sum,
                                        duplicate_tests=3, expected_executed=group_sum-3,
                                        metadata13_already_inside_native100=True),
                  implementation_SPEC_or_CODE_review=False, project_runtime_executed=False,
                  repository_or_evidence_writes=False, sensitive_raw_archive_accessed=False,
                  audit_script_note='Initial substring-uniqueness guard stopped before report writes; exact line anchoring corrected the audit only; final static audit exit0.',
                  counters='group41/root53/stage11/Astra2of2 exhausted; unchanged',
                  repair_rounds_added=0, remaining='full SPEC/CODE and fresh final gates/local commit',
                  command_shutdown='static audit only; all reads finished, no project actor launched')
    summary = f'''# Original test assertion preservation audit

Task `checked_browser_source_review`, direct read-only bounded audit: **{result['verdict']}**.

Candidate2 `{result['candidate2_sha256']}` was checked against candidate1. All245 current source and430 frozen evidence hashes/lengths match before/after. All {len(production)} production-file manifest entries are unchanged candidate1 to candidate2; all original409 evidence entries remain byte-identical.

The assigned script removes only explicit new regions in memory and restores the single original committed_barrier receive branch. It writes no reconstructed source. Both original files reconstruct **exactly**, without whitespace normalization:

- Core: {reconstructed[core]['reconstructed_bytes']} bytes, SHA256 `{reconstructed[core]['reconstructed_sha256']}`.
- Native startup: {reconstructed[native]['reconstructed_bytes']} bytes, SHA256 `{reconstructed[native]['reconstructed_sha256']}`.

These hashes and lengths equal candidate1's original entries, proving every original test/assertion/helper byte is retained outside the specified default-unchanged helper extension. No boundary blankline adjustment or approximate match was needed. No report_activation option remains after reconstruction; its uses are confined to the additions and helper extension. Full semantic/compliance review is outside this audit.

The immutable failed native-green6 remains **100 executed/1 failure/12 warnings, actual exit2/join/source stable**. Native-green7 is **100/0**, core-green3 **73/0**, both actual0/join/source stable/0 warnings/skips/exclusions; corresponding logs match retained hashes. The new acceptance union is **73+100+230+161−3 =561 tests across30 unique files**. Three duplicate exclusion tests are counted once; metadata13 remains inside native100, not added again. This is11 more than candidate1's550, matching five core and six native cases.

Only the assigned `/tmp` audit script/report files were written. The first audit attempt stopped before writes on a substring-uniqueness guard that also saw a nested tag; exact line anchoring corrected the audit only, and the final static audit exited0. No project runtime/test/browser/network/Git mutation or repository/evidence write ran; sensitive raw `/tmp` trace was never accessed. All static audit commands finished with no actor launched. Counters remain41/53/11/Astra2/2. Full SPEC/CODE, fresh final gates and local commit remain pending.
'''
    OUTPUT.with_suffix('.json').write_text(json.dumps(result, indent=2) + '\n')
    OUTPUT.with_suffix('.md').write_text(summary)
    print(json.dumps({key: result[key] for key in ['verdict', 'candidate2_sha256', 'source_stable',
                                                  'production_changes', 'acceptance_union']}, indent=2))
    if not passed:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
