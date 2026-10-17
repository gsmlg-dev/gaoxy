# Bounded audit proposal repair1

**DONE, proposal only.** Applied only complete immutable TOOL SPEC1 findings AT1/AT2 to a new `/tmp/gaoxy-group-reload-runtime-audit3.py.txt`. Syntax check and proposal execution are **NOT RUN**. Root's active runtime session47483, source, collector, tool `.py`, repository and evidence were untouched.

Worktree baseline supplied: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation` at `e4a7660baa61a792f4245f511b190a0fcfcbf920`. Candidate2 SHA256 remains `75e790fdb8fee8b17279a807cb8a826a2ad1596b0f1b7fc9250287347b85a19f`; test pin remains `144ff05c2de10f600c9776565711f1072e08e8487b914c5c42250118230ff535`.

AT1 derives the expected collector map by removing only the explicitly named E6 enum JSON from the pinned402-entry map. Its exact hash remains checked and its path/hash are reported. Both receipt maps must equal the complete401-entry expected map; no subset matching or other omission is allowed. The named enum is `docs/acceptance/evidence/m3/managed-h2-group-reload-plateau/1792240357368527898/chromium-netlog-event-enums1.json`, SHA256 `42ad21b2f1d4a317a00a33e90712bc7aa19790a812ce06984fce5e0355eff0ca`.

AT2 removes the unsupported aggregate25000ms cap. `observed_setup_to_ready_ms` must be an actual integer>=0, with no replacement upper cap. The observation covers prepared wait25000ms followed by ready wait5000ms. Original source waits, profile60000ms checks and all product assertions remain unchanged.

The remaining script change is output kind AUDIT2→AUDIT3. Proposal2 stays byte-identical: its SHA256 before/after was `0272af8cd50906284adeec33e381408b3c6f61f5933309372d86ef3800faec4e`. Proposal3 SHA256 is `f52e7ae9b30b630369003abecada0eef7c86cac1979d45ce1fac24fdfd97596e`.

No own command errors occurred. `diff -u` exited1 as expected because the files differ. No repair validation result is claimed: parent owns syntax qualification and fresh independent TOOL SPEC2→CODE1 before audit execution. Received counter14 root263/orch171/groupTool17/auditFailedSPEC1/SolFixtureRepair1 and Astra2/2 remain unchanged here. Assigned audit-tool repair1 is prepared pending that validation. All own commands completed; no process was started in the background or touched.

The complete exact patch follows; only these five hunks differ from proposal2:

```diff
--- runtime-audit-proposal2.py.txt
+++ runtime-audit-proposal3.py.txt
@@ -30,6 +30,7 @@
 G_LIMITS = dict(max_groups=2, max_config_bytes=16777216, max_pins=1024,
                 max_tokens=1024, max_probes=4, probe_bytes=67108864)
 ROOT = '/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation'
+EXCLUDED_ENUM = 'docs/acceptance/evidence/m3/managed-h2-group-reload-plateau/1792240357368527898/chromium-netlog-event-enums1.json'
 
 class AuditError(Exception):
     pass
@@ -180,7 +181,7 @@
         need(inspect_id(p['address']) == '{127, 0, 0, ' + str(epoch + 1) + '}', 'setup.address')
         need(p['port'] == by_key[(0, lane)]['port'] and integer(p['port'], 1, 65535), 'setup.fixed_port')
         need(p['source_class'] == setup['classes'][0 if lane == 'a' else 1], 'setup.lane_class')
-        need(integer(p['observed_setup_to_ready_ms'], 0, 25000), 'setup.peer_ready_budget')
+        need(type(p['observed_setup_to_ready_ms']) is int and p['observed_setup_to_ready_ms'] >= 0, 'setup.peer_ready_observation')
         need(re.fullmatch('[0-9a-f]{64}', p['source_sha256']) is not None, 'setup.source_hash')
         bundle = p['public_ca_bundle']
         need(bundle == peers[0]['public_ca_bundle'], 'setup.common_frozen_bundle')
@@ -459,6 +460,10 @@
          candidate['base_commit'] == 'e4a7660baa61a792f4245f511b190a0fcfcbf920' and
          len(candidate['actual_command_source_sha256']) == candidate['actual_command_source_count_with_enum'] == 402,
          'candidate.source_map_shape')
+    expected_sources = dict(candidate['actual_command_source_sha256'])
+    excluded_enum_sha256 = expected_sources.pop(EXCLUDED_ENUM)
+    need(excluded_enum_sha256 == '42ad21b2f1d4a317a00a33e90712bc7aa19790a812ce06984fce5e0355eff0ca' and
+         len(expected_sources) == 401, 'candidate.exact_collector_map_without_enum')
     need(receipt['name'] == candidate['first_command']['name'] and receipt['cwd'] == ROOT and
          receipt['environment'] == {'MIX_ENV': 'test', 'ERL_FLAGS': '+S 2:2'} and
          receipt['browser'] is None and receipt['log'] == Path(candidate['first_command']['log']).name,
@@ -470,7 +475,7 @@
          receipt['process_group_remaining'] == [], 'command.actual_joined_nonforced')
     need(receipt['source_stable'] is True and receipt['source_changes'] == [] and
          receipt['source_before'] == receipt['source_after'], 'command.source_stability')
-    need(receipt['source_before'] == candidate['actual_command_source_sha256'] and
+    need(receipt['source_before'] == receipt['source_after'] == expected_sources and
          receipt['source_before'][SOURCE] == SOURCE_SHA, 'command.exact_frozen_input_map')
     need(receipt['command'] == candidate['first_command']['payload_argv'], 'command.exact_frozen_argv')
     need(receipt['log_sha256'] == hashlib.sha256(raw_log).hexdigest(), 'command.log_hash')
@@ -492,13 +497,18 @@
     p.add_argument('--log', required=True)
     p.add_argument('--candidate', required=True)
     a = p.parse_args()
-    result = dict(kind='PROPOSED_GROUP_RELOAD_RUNTIME_DATA_AUDIT2', status='FAIL',
+    result = dict(kind='PROPOSED_GROUP_RELOAD_RUNTIME_DATA_AUDIT3', status='FAIL',
                   runtime_executed_by_audit=False, source_sha256=SOURCE_SHA, contexts=0,
                   source_attestations=[], counts_separate='ExUnit only; Python/browser/static excluded')
     try:
         candidate_bytes = bounded(a.candidate, RECEIPT_MAX)
         need(hashlib.sha256(candidate_bytes).hexdigest() == CANDIDATE_SHA, 'candidate.original_frozen_hash')
         candidate = parse_json(candidate_bytes)
+        result['excluded_collector_source'] = dict(path=EXCLUDED_ENUM,
+             sha256=candidate['actual_command_source_sha256'][EXCLUDED_ENUM],
+             reason='Explicit frozen enum JSON is outside the collector E6 .py/.exs whitelist.')
+        result['expected_collector_source_count'] = 401
+        result['candidate_source_count_with_enum'] = 402
         receipt_bytes = bounded(a.receipt, RECEIPT_MAX)
         receipt = parse_json(receipt_bytes)
         raw_log = bounded(a.log, LOG_MAX)
```
