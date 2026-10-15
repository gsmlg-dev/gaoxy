from pathlib import Path
import hashlib, json, re

R = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E = R / 'docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
c3p = E / 'postactivation-full-review-candidate3.json'
c4p = E / 'postactivation-full-review-candidate4.json'
c3, c4 = json.loads(c3p.read_text()), json.loads(c4p.read_text())
assert sha(c3p) == '460f92ea04c9392680c07fd51b1fffd0689994289a66ff4219f7b9e7a9cae1a2'
assert sha(c4p) == '045494d4e74fcb23f829579aeede1ea175d3a2155b443b9193a0df5593c305d5'
s3, s4 = c3['source_manifest'], c4['source_manifest']
assert len(s3) == len(s4) == 198 and s3.keys() == s4.keys()
changed = [p for p in s3 if s3[p] != s4[p]]
assert changed == ['integration/http_fetch_contract/managed_h2_fixed_qualification.py']
current = {p: sha(R / p) for p in s4}
assert current == s4
fixed = R / changed[0]
new = fixed.read_bytes()
line = b'            |> Map.put(:admission_receipts, state.admission_receipts)\n'
needle = b'            |> Map.put(:original_repeat, original_rows(state)) |> Map.put(:native_idle, ledger)\n'
assert new.count(needle + line) == 1
old = new.replace(needle + line, needle, 1)
assert hashlib.sha256(old).hexdigest() == s3[changed[0]]
assert sha(R / 'integration/http_fetch_contract/managed_h2_group_browser.py') == '5c6544a5b3f70329f083ad2fb48b522b81fe7a990135136a12358dd436ef6dfa'
a3p, a4p = E / 'full-review3-adoption1.json', E / 'full-review4-source-rebind-adoption1.json'
a3, a4 = json.loads(a3p.read_text()), json.loads(a4p.read_text())
assert a3['candidate_sha256'] == sha(c3p)
assert a4['candidate']['sha256'] == sha(c4p)
for p, digest in {**a3['reports'], **a4['patch_reports']}.items():
    assert sha(E / p) == digest
for item in [c4['counter_ledger'], c4['collector'], c4['required_command_gates'], c4['browser_wrapper'], c4['reviewed_repair'], c4['command_evidence_reuse']]:
    assert sha(E / item['path']) == item['sha256']
gates = (E / c3['required_command_gates']['path']).read_text().splitlines()
assert len(gates) == len(set(gates)) == 25
rows = []
for gate in gates:
    pattern = re.compile(re.escape(gate) + r'-(\d+)\.json')
    paths = [p for p in E.glob(gate + '-*.json') if (match := pattern.fullmatch(p.name)) and int(match[1]) >= a3['run_not_before_ns']]
    assert paths, ('missing command', gate)
    p = max(paths, key=lambda p: int(pattern.fullmatch(p.name)[1]))
    d = json.loads(p.read_text())
    assert d['gate'] == gate and d['actual_exit'] == 0 and not d['timed_out'] and d['process_joined']
    assert d['source_stable'] and d['source_before'] == s3 and d['source_after'] == s3
    assert d['collector_sha256'] == c3['collector']['sha256'] and not d['unexpected_warnings']
    assert d['failures'] == d['skips'] == d['exclusions'] == 0 and d['zero_skip_exclusion_configuration']
    assert gate in ['fresh-format', 'fresh-compile'] or d['tests_executed'] > 0
    log = R / d['log']
    assert sha(log) == d['log_sha256'] and log.stat().st_size == d['log_bytes']
    rows.append({'gate': gate, 'receipt': p.name, 'receipt_sha256': sha(p), 'log': d['log'], 'log_sha256': d['log_sha256'], 'tests_executed': d['tests_executed'], 'failures': 0, 'skips': 0, 'exclusions': 0, 'actual_exit': 0, 'joined': True, 'source_stable': True, 'source_candidate': c3p.name})
paths = [p for p in E.glob('browser-command4-*.json') if int(re.search(r'-(\d+)\.json$', p.name)[1]) >= a4['run_not_before_ns']]
assert paths, 'missing newHOST browser'
p = max(paths, key=lambda p: int(re.search(r'-(\d+)\.json$', p.name)[1]))
b = json.loads(p.read_text())
assert b['actual_exit'] == 0 and b['process_joined'] and not b['timed_out']
assert b['source_stable'] and b['source_before'] == s4 and b['source_after'] == s4
assert b['collector_sha256'] == c4['browser_wrapper']['sha256'] and b['executed_completed_cases'] == 3 and b['suite_status'] == 'PASS'
assert sha(R / b['log']) == b['log_sha256'] and sha(R / b['qualification']) == b['qualification_sha256']
qpath = R / b['qualification']
q = json.loads(qpath.read_text())
assert q['status'] == 'PASS' and q['executed'] == 3 and q['source_stable']
assert [case['case'] for case in q['cases']] == ['browser-group-native-h2-to-tls-h2', 'browser-group-wrong-ca', 'browser-group-wrong-name']
assert all(case['status'] == 'PASS' for case in q['cases'])
for name, digest in q['artifact_hashes'].items():
    assert sha(qpath.parent / name) == digest
failed = E / 'browser-command3-1792100929073920313.json'
assert sha(failed) == '1039207d48dee9b9cd6badc985052a50f387fdbd3ccb5c9eba0e4b4834b40f41'
assert json.loads(failed.read_text())['actual_exit'] == 1
result = {'kind': 'COMMANDS_C3_AND_BROWSER_C4_WITH_REVIEWED_HOST_EMISSION_REBIND', 'status': 'PASS_COMMANDS_AND_CANONICAL_BROWSER', 'candidate': c4p.name, 'candidate_sha256': sha(c4p), 'source_manifest': s4, 'source_count': len(s4), 'command_candidate': c3p.name, 'command_candidate_sha256': sha(c3p), 'source_rebind_adoption': a4p.name, 'source_rebind_adoption_sha256': sha(a4p), 'unchanged_production_and_command_tests': True, 'command25_not_rerun_on_newHOST': True, 'gates': rows, 'gate_count': len(rows), 'executed_test_invocations_including_repeated_fixtures': sum(row['tests_executed'] for row in rows), 'browser': {'receipt': p.name, 'receipt_sha256': sha(p), 'qualification': b['qualification'], 'qualification_sha256': b['qualification_sha256'], 'source_candidate': c4p.name, 'executed_completed_cases': 3, 'actual_exit': 0, 'joined': True}, 'retained_browser3_failure': {'path': failed.name, 'sha256': sha(failed)}, 'historical_cleanup': 'UNCONFIRMED_WITH_RETAINED_FAILURE', 'counter_ledger': c4['counter_ledger'], 'astra': '2/2 exhausted unchanged', 'remaining': 'documentation rebind independent closure, index/commit byte custody and local commit'}
out = E / 'fresh-final-gates-aggregate3.json'
with out.open('x') as handle:
    handle.write(json.dumps(result, indent=2) + '\n')
print(out.name, sha(out), 'commands', len(rows), 'executed_test_invocations', result['executed_test_invocations_including_repeated_fixtures'], 'completed_browser_cases', 3)
