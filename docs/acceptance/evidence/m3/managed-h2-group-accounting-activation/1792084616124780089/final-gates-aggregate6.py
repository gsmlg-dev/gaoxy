from pathlib import Path
import ast, collections, hashlib, json, re, subprocess, tempfile

R = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E = R / 'docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):
    return json.loads(p.read_text())
def bound(item):
    p = E / item['path']
    assert sha(p) == item['sha256'], p
    return p

c3p, c6p = E / 'postactivation-full-review-candidate3.json', E / 'postactivation-full-review-candidate6.json'
assert sha(c3p) == '460f92ea04c9392680c07fd51b1fffd0689994289a66ff4219f7b9e7a9cae1a2'
assert sha(c6p) == 'e6fd76f2b204b1755c66123e4d4ba7dd14d64d1ab2d425d91b183099672675c5'
c3, c6 = read(c3p), read(c6p)
s3, s6 = c3['source_manifest'], c6['source_manifest']
assert len(s3) == len(s6) == 198 and s3.keys() == s6.keys()
changed = {p for p in s3 if s3[p] != s6[p]}
assert changed == {'integration/http_fetch_contract/managed_h2_fixed_qualification.py', 'apps/gaoxy_proxy/test/support/managed_h2_group_browser_peer.py', 'integration/http_fetch_contract/managed_h2_group_browser.py'}
assert {p: sha(R / p) for p in s6} == s6
# Exact HOST-only emissions: reverse both reviewed changes to original c3 bytes.
host = 'integration/http_fetch_contract/managed_h2_fixed_qualification.py'
new = (R / host).read_bytes()
line = b'            |> Map.put(:admission_receipts, state.admission_receipts)\n'
needle = b'            |> Map.put(:original_repeat, original_rows(state)) |> Map.put(:native_idle, ledger)\n'
assert new.count(needle + line) == 1
old = new.replace(needle + line, needle, 1)
stale_new = b'      raw = :sys.get_state(state.groups, 1000)\n      public = case Groups.status(state.group) do\n        %{} = value -> value\n        {:error, :stale_group} = error -> %{public_result: inspect(error)}\n      end\n      %{owner: inspect(state.groups), public: public,'
stale_old = b'      raw = :sys.get_state(state.groups, 1000)\n      %{owner: inspect(state.groups), public: Groups.status(state.group),'
assert old.count(stale_new) == 1
assert hashlib.sha256(old.replace(stale_new, stale_old, 1)).hexdigest() == s3[host]
# Exact two-file active-health GOAWAY patch, applied only in a temporary directory.
adopt = read(bound(c6['reviewed_repair']))
patch = bound(adopt['patch'])
assert len(adopt['source_delta']) == 2
with tempfile.TemporaryDirectory(prefix='gaoxy-group-aggregate-goaway-') as temp:
    tmp = Path(temp)
    for rel, delta in adopt['source_delta'].items():
        original = E / 'candidate5-browser-sources-before-goaway-repair1' / Path(rel).name
        assert sha(original) == delta['before_sha256'] == s3[rel]
        dest = tmp / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(original.read_bytes())
    subprocess.run(['git', 'apply', '--unsafe-paths', str(patch)], cwd=tmp, check=True)
    for rel, delta in adopt['source_delta'].items():
        assert sha(tmp / rel) == delta['after_sha256'] == s6[rel]
        if rel.startswith('integration/'):
            prior_ast = ast.parse((E / 'candidate5-browser-sources-before-goaway-repair1' / Path(rel).name).read_text())
            new_ast = ast.parse((R / rel).read_text())
            calls = lambda tree, func: collections.Counter(ast.dump(node, include_attributes=False) for node in ast.walk(tree) if isinstance(node, ast.Call) and func(node))
            requires = lambda node: isinstance(node.func, ast.Name) and node.func.id == 'require'
            events = lambda node: isinstance(node.func, ast.Attribute) and node.func.attr == 'event'
            before, after = calls(prior_ast, requires), calls(new_ast, requires)
            assert sum(before.values()) == 41 and sum(after.values()) == 42 and not before - after
            assert calls(prior_ast, events) == calls(new_ast, events)
a3p, a6p = E / 'full-review3-adoption1.json', E / 'full-review6-source-rebind-adoption1.json'
a3, a6 = read(a3p), read(a6p)
assert a3['candidate_sha256'] == sha(c3p) and a6['candidate']['sha256'] == sha(c6p)
for name, digest in a3['reports'].items():
    assert sha(E / name) == digest
review = a6
while 'preceding_rebind_review' in review:
    for name, digest in review['patch_reports'].items():
        assert sha(E / name) == digest
    review = read(bound(review['preceding_rebind_review']))
assert review['candidate_sha256'] == sha(c3p)
supp = read(E / 'browser-active-goaway-spec-final-supplement1.json')
for name, digest in {**supp['retained_original_reports'], **supp['final_reports']}.items():
    assert sha(E / name) == digest
for key in ['counter_ledger', 'collector', 'required_command_gates', 'browser_wrapper', 'reviewed_repair', 'command_evidence_reuse']:
    bound(c6[key])
gates = (E / c3['required_command_gates']['path']).read_text().splitlines()
assert len(gates) == len(set(gates)) == 25
rows = []
for gate in gates:
    pattern = re.compile(re.escape(gate) + r'-(\d+)\.json')
    paths = [p for p in E.glob(gate + '-*.json') if (m := pattern.fullmatch(p.name)) and int(m[1]) >= a3['run_not_before_ns']]
    assert paths, ('missing command', gate)
    p = max(paths, key=lambda p: int(pattern.fullmatch(p.name)[1]))
    d = read(p)
    assert d['gate'] == gate and d['actual_exit'] == 0 and not d['timed_out'] and d['process_joined']
    assert d['source_stable'] and d['source_before'] == s3 == d['source_after']
    assert d['collector_sha256'] == c3['collector']['sha256'] and not d['unexpected_warnings']
    assert d['failures'] == d['skips'] == d['exclusions'] == 0 and d['zero_skip_exclusion_configuration']
    assert gate in ['fresh-format', 'fresh-compile'] or d['tests_executed'] > 0
    log = R / d['log']
    assert sha(log) == d['log_sha256'] and log.stat().st_size == d['log_bytes']
    rows.append(dict(gate=gate, receipt=p.name, receipt_sha256=sha(p), log=d['log'], log_sha256=d['log_sha256'], tests_executed=d['tests_executed'], failures=0, skips=0, exclusions=0, actual_exit=0, joined=True, source_stable=True, source_candidate=c3p.name))
paths = [p for p in E.glob('browser-command6-*.json') if (m := re.fullmatch(r'browser-command6-(\d+)\.json', p.name)) and int(m[1]) >= a6['run_not_before_ns']]
assert paths, 'missing changed-canonical browser'
p = max(paths, key=lambda p: int(re.search(r'-(\d+)\.json$', p.name)[1]))
b = read(p)
assert b['actual_exit'] == 0 and b['process_joined'] and not b['timed_out']
assert b['source_stable'] and b['source_before'] == s6 == b['source_after']
assert b['collector_sha256'] == c6['browser_wrapper']['sha256'] and b['executed_completed_cases'] == 3 and b['suite_status'] == 'PASS'
assert sha(R / b['log']) == b['log_sha256'] and sha(R / b['qualification']) == b['qualification_sha256']
qpath = R / b['qualification']
q = read(qpath)
assert q['status'] == 'PASS' and q['executed'] == 3 and q['source_stable'] and len(q['browser_joins']) == 3
assert [case['case'] for case in q['cases']] == ['browser-group-native-h2-to-tls-h2', 'browser-group-wrong-ca', 'browser-group-wrong-name']
assert all(case['status'] == 'PASS' for case in q['cases'])
for name, digest in q['artifact_hashes'].items():
    assert sha(qpath.parent / name) == digest
failures = []
for name, digest, completed in [('browser-command3-1792100929073920313.json', '1039207d48dee9b9cd6badc985052a50f387fdbd3ccb5c9eba0e4b4834b40f41', 0), ('browser-command4-1792101328172786028.json', '45d856b653e8b064db66f53a4f79f6891d66e35354f27b0c395dde67ae539e5b', 0), ('browser-command5-1792101661338130027.json', '828e4fa6a358e54961aa5f5e78c7e4ddf3ba03863e60cdf49e9a7b75b1c78817', 1)]:
    f = E / name
    assert sha(f) == digest and read(f)['actual_exit'] == 1 and read(f)['executed_completed_cases'] == completed
    failures.append(dict(path=name, sha256=digest, actual_exit=1, completed_cases=completed))
result = dict(kind='COMMANDS_C3_AND_BROWSER_C6_WITH_REVIEWED_HOST_AND_ACTIVE_GOAWAY_FIXTURE_REBIND', status='PASS_COMMANDS_AND_CANONICAL_BROWSER', candidate=c6p.name, candidate_sha256=sha(c6p), source_manifest=s6, source_count=198, command_candidate=c3p.name, command_candidate_sha256=sha(c3p), source_rebind_adoption=a6p.name, source_rebind_adoption_sha256=sha(a6p), unchanged_production_and_command_tests=True, command25_not_rerun_on_newHOST_or_newBrowser=True, gates=rows, gate_count=25, executed_test_invocations_including_repeated_fixtures=sum(row['tests_executed'] for row in rows), browser=dict(receipt=p.name, receipt_sha256=sha(p), qualification=b['qualification'], qualification_sha256=b['qualification_sha256'], source_candidate=c6p.name, executed_completed_cases=3, actual_exit=0, joined=True), retained_browser_failures=failures, historical_cleanup='UNCONFIRMED_WITH_RETAINED_FAILURE', counter_ledger=c6['counter_ledger'], astra='2/2 exhausted unchanged', remaining='documentation rebind independent closure, index/commit byte custody and local commit')
out = E / 'fresh-final-gates-aggregate6.json'
with out.open('x') as handle:
    handle.write(json.dumps(result, indent=2) + '\n')
print(out.name, sha(out), 'commands', 25, 'executed_test_invocations', result['executed_test_invocations_including_repeated_fixtures'], 'completed_browser_cases', 3)
