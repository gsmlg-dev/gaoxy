# M3 managed H1 groups and probes acceptance

Status: **PASS — local implementation/runtime accepted; local commit PENDING**.
Independent complete SPEC then CODE review and fresh168/0, strict compile and
formatcheck pass. All historical failures remain immutable. At kickoff,
implementation and runtime acceptance were NOT RUN. The accepted fixed-endpoint predecessor is local
commit `2bf0883cea1dce1a031016700bb012fb3faac8b5`, with final independent SPEC/CODE
and fresh178/0, strict compile and formatcheck PASS.

[Design](../designs/m3-managed-h1-groups.md) and
[plan](../plans/m3-managed-h1-groups.md) define the unchanged required gates.
Parent owns all runtime/build/format/evidence/commits. Writers preserve disjoint
file ownership and freeze before each runtime command. First live preparation
GREEN waits for managed Probe support because publication immediately queues
probes; no scheduling switch or dedicated fallback is acceptable.

Inherited unsuccessful counters: UP2 live20/production8/harness3; Foundation
Step7 5; fixed implementation3/harness1/SPEC rejection1; Astra recovery2/2
exhausted. Groups implementation/harness/SPEC rejection counters start at0.
Preserve failed and expected-RED receipts separately from acceptance.

No publication/deployment, production data/certificates, Vault, public management,
H2/H3/standalone capability changes or disabled release-artifact E2E. TLS managed
ALPN remains exactly null and trust remains explicit immutable DER. #97 is
excluded and #107 is optional. Runtime, hosted CI and production remain separate.

Kickoff: [source/tree/cohort/ownership receipt](evidence/m3/managed-h1-groups/1791934732834992397/kickoff.json).

## Pure configuration checkpoint

Expected RED executed11/11 failures (26 excluded), exit2; pure GREEN then executed11/0 (26 excluded), exit0. Existing dedicated group/member-limit units executed10/0 with no exclusions, exit0. All runtime receipts source-stable; scoped formatter canonicalizes new tests and is not a stable-source acceptance run. Independent bounded SPEC then CODE review PASS with no findings: [review receipt](evidence/m3/managed-h1-groups/1791934732834992397/groups-pure-spec-code-review.json). Owner-authenticated construction, live preparation, Probe and Session remain unexecuted. Expected RED adds zero implementation/repair failures.

## Preparation and initial Probe checkpoint

The twelve preparation regressions and four initial managed Probe regressions
first executed their expected REDs. After facade/owner/Probe integration, the
combined unfiltered preparation, Probe and existing group/member-limit/probe
suite executed **40/0**, zero exclusions/skips, exit0, with stable source and
saved log hash: [GREEN receipt](evidence/m3/managed-h1-groups/1791934732834992397/groups-preparation-probe-initial-green-1791936622730266698.json).
The independent bounded facade/owner static SPEC then CODE review passed with
no findings: [review receipt](evidence/m3/managed-h1-groups/1791934732834992397/groups-facade-owner-static-review.json).
That static review preceded the runtime gate and excludes Probe implementation;
full stage review remains pending. Retirement, deaths, negative TLS, health
thresholds and combined pending cleanup still require the extended live tests.

## Initial Session RED and fixture diagnosis

[Initial Session RED](evidence/m3/managed-h1-groups/1791934732834992397/groups-session-expected-red-1791936666731504592.json)
executed5 tests, four failures, zero skips/exclusions, exit2 and stable source.
Three failures demonstrate the missing managed selected-member path: a separate
dedicated socket, absent transport binding, and lost explicit TLS trust. The
unactivated Session regression passes. One failure occurs before Session
execution in the two-member fixture: concurrent initial probes compete for the
single transport token, preventing the required healthy baseline. This is a
harness failure, not a valid capacity-rejection RED. Repair the test setup using
normal bounded scheduling, then rerun RED before production Session changes.
Groups cumulative counters are implementation0/harness1/SPEC rejection0;
Astra remains2/2. No assertion or required gate is waived.

The supported fixture setting `max_probes: 1` serializes actual initial HEADs
through the existing owner tick. The [repaired RED](evidence/m3/managed-h1-groups/1791934732834992397/groups-session-fixture-repaired-red-1791936849110407843.json)
then executed5/four expected managed-path failures, zero skips/exclusions, exit2
and stable source. All healthy preconditions now execute; capacity test failure
reaches its GET reuse assertion. The unactivated regression passes. This valid
RED releases Session production implementation; the initial harness failure and
unchanged assertions remain recorded. Groups counters remain0/1/0.

Initial Session GREEN is **FAIL**, not acceptance: [receipt](evidence/m3/managed-h1-groups/1791934732834992397/groups-session-initial-green-1791937048779190507.json)
executes40 tests with one failure, zero skips/exclusions, exit2 and stable source.
The capacity-denial case reaches its managed request and refusal assertions but
does not satisfy final accounting settlement under the unchanged finite bound.
The other39 tests pass. Sol diagnosis must identify the retained hold before
repair; implementation versus harness classification is pending. This adds one
unsuccessful GREEN attempt; the prior harness failure remains1 and Astra2/2.

The [focused diagnostic](evidence/m3/managed-h1-groups/1791934732834992397/groups-session-capacity-cleanup-diagnostic-1791937281337807845.json)
executes1/failure1 with4 exclusions, exit2, stable source; it is an intentional
failure reproduction, not an acceptance command. Public status shows Service
active/pending/retained0, group inflight/probes0 with both members healthy, and
transport tokens/helpers0. Three exact baseline batches contain1+1+2 handles,
so the aggregate correctly counts4 pins while the fixture expected3.
[Root-cause assessment](evidence/m3/managed-h1-groups/1791934732834992397/groups-session-capacity-diagnostic-assessment.json)
classifies the GREEN failure as a harness oracle error. Update the exact
per-handle baseline expectation and assert no additional request hold; keep all
zero-accounting, health, replay and finite-deadline assertions. No production
repair is needed by this diagnosis. Verification of that correction remains
pending. Groups cumulative: one unsuccessful GREEN, production0/harness2/SPEC0,
one intentional diagnostic reproduction, Astra2/2.

## Extended Probe checkpoint

[Extended Probe verification](evidence/m3/managed-h1-groups/1791934732834992397/groups-probe-extended-initial-verification-1791937631891844524.json)
executes13 new-package and5 dedicated Probe tests, **18/0**, zero skips/exclusions,
exit0 and stable source. The cases exercise authentic baseline release before
claim, observed `:stale_probe`, guardian/group-owner death, strict negative-TLS
uncertainty, immutable DER/reuse, real health thresholds/timeout and failed short
stop followed by separately confirmed late cleanup/joins. Negative TLS keeps
the inherited conservative non-success and charged failed resource.
The log also records a duplicate test-barrier unblock reaching DynamicSupervisor;
repair this fixture message without suppressing logs or changing production.
Independent Probe review and fresh post-fix verification remain pending; this
checkpoint does not accept the complete groups stage.

## Full initial verification and lifecycle fixture diagnosis

[Full initial command](evidence/m3/managed-h1-groups/1791934732834992397/groups-complete-initial-green-1791938042818460114.json)
executes**168 tests/five failures**, zero skips/exclusions, exit2 and stable
source. All failures are in the extended Session tests; the other163 pass,
including the post-fix Probe cases. This result is **FAIL**, not acceptance.
Sol diagnosis identifies fixture issues: two negative-TLS samples precede a
retirement helper join; the transport-owner death case reads that same owner
while its bind barrier is held, exhausting the deadline before the intended
kill; the raw peer lacks the observed terminal `:enotconn` clause; and short-stop
teardown expects success from the same immutable failed retirement operation.
The targeted repair keeps exact error reasons by moving the immutable lookup
before the barrier, waits for actual helper joins, handles the observed terminal
socket result, and separately asserts cached public failure versus later
physical/ledger cleanup. No production repair is indicated by this diagnosis.
Independent stop-contract inspection cross-checks the last distinction.
Groups cumulative counters now record two unsuccessful GREEN attempts,
production0/harness3 unsuccessful attempts (five failed cases in this attempt),
one intentional focused diagnostic reproduction and SPEC0; Astra2/2. Fresh
verification of the fixture repairs remains pending.

[Independent short-stop contract diagnosis](evidence/m3/managed-h1-groups/1791934732834992397/groups-shortstop-independent-contract-diagnosis.json)
confirms the unchanged accepted Foundation invariant: retirement deadlines only
tighten, and terminal owner-operation failure is immutable. A separate public
scope-retirement confirmation may later succeed without changing that receipt.
The [focused runtime reproduction](evidence/m3/managed-h1-groups/1791934732834992397/groups-session-shortstop-retirement-diagnostic-1791938512181299722.json)
executes1/failure1 with19 exclusions, stable source, exit2. Its failure-only
diagnostic observes the real public ledger fully zero and retired, no remaining
custodians, with the original cached `:cleanup_pending` failure unchanged.
The repair must assert both facts, public scope confirmation and physical/owned
joins; a destructive failed-fixture branch is not acceptance for this short-stop
case. This is the second intentional focused diagnosis, not another unsuccessful
repair. Production0/harness3, unsuccessful GREEN2 and Astra2/2 remain unchanged.

## Post-repair Session checkpoint

The parent formatter completed successfully, then the unfiltered Session,
fixed-endpoint and dedicated-group compatibility command executed **55/0**,
zero skips/exclusions, exit0 and stable source:
[repair GREEN receipt](evidence/m3/managed-h1-groups/1791934732834992397/groups-session-lifecycle-repair-green-1791938979205653013.json).
The full log contains no repeated barrier-unblock error. The repaired short-stop
case preserves the same failed owner receipt twice and independently requires
original request completion, public opaque-scope retirement, physical peer EOF,
worker/custodian joins, all-zero public accounting and normal owner/creator joins.
The two negative-TLS cases still require exact charged uncertainty; no assertion,
deadline or production behavior was weakened. Complete independent SPEC then
CODE review and the fresh complete stage command remain pending. Groups counters
remain unsuccessful GREEN2/production0/harness3/intentional diagnostics2/SPEC0;
Astra recovery2/2 remains exhausted.

## Final local verification

Complete independent [SPEC](evidence/m3/managed-h1-groups/1791934732834992397/groups-final-spec-review.json)
then [CODE](evidence/m3/managed-h1-groups/1791934732834992397/groups-final-code-review.json)
review passes without findings. The parent then executes fresh scoped formatcheck,
strict compile and the entire twelve-file stage command: **168 executed / 0
failures / 0 skips / 0 exclusions**, exit0. Source is stable and all nine
executable hashes match both reviews. The [local acceptance receipt](evidence/m3/managed-h1-groups/1791934732834992397/groups-local-acceptance.json)
links exact commands/log hashes. Its real death scenario emits an intentional
killed-supervisor message; no barrier-unblock error occurs and every test passes.

This accepts managed H1 group requests/probes only. Generation follows its
separate written design/plan after local commit, and full Task5/M3, upstream H2,
standalone managed-resource configuration and publication/deployment/production
acceptance are not inferred. Groups counters remain unsuccessful GREEN2,
production0, harness3, intentional diagnoses2 and SPEC0; inherited counters and
Astra2/2 are unchanged. No original failed receipt or log was rewritten.
