from pathlib import Path
import datetime, hashlib, json
R = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E = R / 'docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089'
h = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
cpath = E / 'postactivation-full-review-candidate6.json'
c = json.loads(cpath.read_text()); s = c['source_manifest']
assert h(cpath) == 'e6fd76f2b204b1755c66123e4d4ba7dd14d64d1ab2d425d91b183099672675c5'
assert all(h(R / p) == v for p, v in s.items())
apath = E / 'fresh-final-gates-aggregate7.json'
a = json.loads(apath.read_text())
assert a['status'] == 'PASS_COMMANDS_AND_CANONICAL_BROWSER' and a['gate_count'] == 25
assert a['executed_test_invocations_including_repeated_fixtures'] == 1752
assert a['browser']['executed_completed_cases'] == 3 and a['source_manifest'] == s
ledger = json.loads((E / 'counter-ledger15.json').read_text())
assert ledger['current_stage_failed_GREEN_attempts'] == 24 and ledger['root_repair_events_count'] == 27
paths = ['docs/designs/m3-managed-h2-group-accounting-activation.md', 'docs/plans/m3-managed-h2-group-accounting-activation.md', 'docs/acceptance/m3-managed-h2-group-accounting-activation.md', 'implement-plan.md', 'docs/plans/m3-upstream-transport.md']
archive = E / 'documents-before-final-runtime-sync2'
archive.mkdir()
original = {p: (R / p).read_bytes() for p in paths}
for p, data in original.items():
    dest = archive / p
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
status = 'Status: VERIFIED LOCALLY for the bounded managed-H2 group accounting/activation slice. The complete independent FULL SPEC3/CODE3 review plus exact reviewed HOST/GOAWAY fixture rebinds, original-candidate25 command gates (1,752 executed test invocations including repeated fixtures) and fresh candidate6 Chrome/CDP3/3 all pass. Final document and Git byte custody bind this result to the local commit; no full-M3, H2 Generation, standalone-profile or sustained-load acceptance is claimed. Historical negative TLS/browser cleanup remains UNCONFIRMED_WITH_RETAINED_FAILURE; ledger15 retains24 failed GREEN attempts/27 ordered root repair events and exhausted Astra2/2.'
common = '''
## Local accounting/activation verification — 2026-10-16

The final command/browser aggregate is `fresh-final-gates-aggregate7.json` in
`docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089/`.
It authenticates the198-source candidate6, original FULL SPEC3/CODE3 reports,
all subsequent exact source rebinds,25 command receipts/logs and the fresh whole
Chrome/CDP suite. `final-gates-aggregate7.py` is independently source-reviewed;
its actual execution and hash are recorded by the final evidence closure.

The25 command gates actually ran on candidate3 (manifest460f92ea04c9392680c07fd51b1fffd0689994289a66ff4219f7b9e7a9cae1a2),
not on the later HOST/browser bytes. Their explicitly reviewed reuse is limited
to unchanged production/ExUnit/dependency sources:1,752 executed test invocations
including repeated fixtures, zero failures/skips/exclusions/unexpected warnings,
all real joined exit0 with stable198-entry maps. Format and forced strict compile
also passed. Key counts: nativeTLS41, accountant69, startup50, live110,
Session controls46, existing pure454, compatibility603, affected fixture97,
nativeH2 81, nativeH3 proxy7, standalone compatibility65 and core isolation1.

Candidate6 (manifest e6fd76f2b204b1755c66123e4d4ba7dd14d64d1ab2d425d91b183099672675c5)
changes only three sources from candidate3: the HOST exposes its already-fenced
real admission_receipts and serializes the explicit stale_group public status;
the dedicated negative peer sends real GOAWAY before its initial healthy HEAD
response, and the canonical driver verifies that exact command instead of
sending after health cleanup. Every41 original require and all event/deadline
calls remain; one strict GOAWAY identity assertion is added. The original20s
physicalEOF, actual initial worker join, exactly1 health request and real TLS
certificate rotation remain mandatory. This is active-health GOAWAY preparation;
it does not claim immediate idle-GOAWAY retirement or alter the public runtime.

Fresh `browser-command6-1792102241447455688.json` records PASS3/3, actual exit0,
joined in32,655ms and stable198-entry sources. The positive browser case proves
native TLS/h2 navigation, streamed/early bodies, real full16,478,862-byte Service
holds, G/T original/probe identity and complete timelines, then normal positive
retirement, requests4/accepts1/forced0/live0 and a real browser join. Each isolated
wrong-CA/name case proves exact native502/zero declared body/browser error page,
real changed-certificate failed handshake, no replay (exact1 health HEAD), actual
initial physicalEOF and worker join, and its own final peer/browser joins.
All three isolated browser profiles are removed after real exit0.

Negative cases retain **UNCONFIRMED_WITH_RETAINED_FAILURE**: original cleanup
failed/held ledgers and explicitly labelled test-owned disposal are retained.
A missing Service is never zero usage or a cleanup receipt. Browser3 and4 remain
actual FAIL/zero complete cases; browser5 remains actual FAIL/one complete case.
Their receipts/logs/artifacts and every earlier diagnostic/RED/GREEN failure are
immutable. Browser5 also retains baseline native peername einval logs from the
unchanged HEAD source; this is not a GOAWAY cause or an unreported repair.
The unexecuted aggregate5/6 source drafts and their corrections are separately
recorded; neither is runtime acceptance or a failed GREEN test attempt.

Ledger15 retains24 failed GREEN attempts and27 ordered root repair events, with
all inherited/stream-local counter snapshots intact. Root events are not a
relabelled global Sol repair count. Astra recovery2/2 remains exhausted, with
no third round. Fixed Service9,444,956, group16,478,862 and startup5,963,776 stay
unchanged; these serialized payload contracts are not physical-memory proof.

The final document-only rebind preserves all runtime source bytes and explicitly
archives the earlier documents. Independent final closure plus disk/index/actual
commit byte audit is required before the accepted result is attached to a local
conventional commit. No push, package/image/release publication, deployment,
production data, operational certificates, Vault changes, public management or
release-artifact E2E enablement follows.

Next bounded slice: validate compiled Router route/resource-sidecar consistency
through the existing generic Resources contract, including static nested Router
checks and rejection before baseline pins. It does not activate managed-H2
Generation. Subsequent H2 Generation accounting/activation, full8-cell matrix,
CAS/rollback/store death, CA/IP rotation,20 reload plateau, standalone integration
and both required600-second load modes retain separate verification/review gates.
The complete M3 milestone remains IN PROGRESS.
'''
for p in paths[:4]:
    text = original[p].decode()
    lines = text.splitlines(keepends=True)
    indices = [i for i, line in enumerate(lines) if line.startswith('Status: ')]
    assert len(indices) == 1
    i = indices[0]
    lines[i] = status + '\n'
    lines.insert(i + 1, '\nThe checkpoints below preserve their historical status at each cutoff; this current verification and the final closure receipt supersede earlier pending/NOT RUN statements.\n')
    (R / p).write_text(''.join(lines) + common)
p = paths[4]
text = original[p].decode()
start = text.index('**Current bounded activation — 2026-10-14:**')
end = text.index('\nModify: ', start)
replacement = '''**Current bounded activation — 2026-10-16:** Task4 foundation, fixed H1,
managed H1 groups/probes and H1 Generation are locally accepted at their recorded
commits. Fixed managed H2 completed independent review, full58 853/0, public63/63,
real-peer135/135 and isolated Chrome3/3 with HTTP0.21.10 (feature bbbc50dc628d4d82fde7377b5bcff68bb35e1867,
evidence5516ea1b398d7970e861cabdb2c2c3075be7eeae). The bounded managed-H2
[group accounting/activation](m3-managed-h2-group-accounting-activation.md) now
passes complete FULL SPEC3/CODE3 plus exact fixture rebind review,25 original-source
command gates/1,752 test invocations and fresh Chrome/CDP3/3. Its final document/
Git custody and local commit are recorded in stage acceptance. The actual native
H1/H2 downstream to h2c/TLS-H2 group subset is qualified; this is not H2 Generation
or standalone-profile activation. Historical negative TLS/browser cleanup remains
UNCONFIRMED_WITH_RETAINED_FAILURE. Fixed9,444,956/group16,478,862/startup5,963,776
are unchanged; cumulative24 failed GREEN attempts/27 ordered root events and
Astra2/2 remain retained. Complete Task5/M3, H2 Generation, standalone integration,
reload/rotation and sustained load retain their separate gates.

Next prerequisite: compiled Router route/resource-sidecar consistency before any
new Generation baseline pin, followed by separate native Generation accounting
and actual H2 Generation qualification. A reachable path is not an accepted
Generation capability. The continuing authorization advances these bounded
slices after their verification and independent review; no routine approval stop.
'''
text = text[:start] + replacement + text[end:]
old = '- [ ] Change adapter options only through the verified public managed facade;'
assert text.count(old) == 1
text = text.replace(old, '- [x] Change adapter options only through the verified public managed facade;', 1)
(R / p).write_text(text)
now = {p: h(R / p) for p in s}
changed = {p: {'before_sha256': s[p], 'after_sha256': now[p]} for p in s if s[p] != now[p]}
assert set(changed) == set(paths[:4])
d = {'kind':'DOCUMENT_ONLY_REBIND_AFTER_RUNTIME_CANDIDATE6_PASS','recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'runtime_candidate':{'path':cpath.name,'sha256':h(cpath)},'runtime_aggregate':{'path':apath.name,'sha256':h(apath)},'source_manifest':now,'source_count':198,'unchanged_runtime_source_count':194,'document_delta':changed,'additional_parent_plan':{'path':paths[4],'before_sha256':hashlib.sha256(original[paths[4]]).hexdigest(),'after_sha256':h(R / paths[4])},'prior_document_archive':str(archive.relative_to(E)),'old_documents':{p:hashlib.sha256(data).hexdigest() for p,data in original.items()},'counter_ledger':c['counter_ledger'],'stage':'LOCAL_RUNTIME_VERIFIED_PENDING_FINAL_DOC_GIT_CUSTODY','no_runtime_rerun_for_document_only_change':True,'scope':'bounded managedH2 group accounting/activation; complete M3 remains IN_PROGRESS','local_commit':'PENDING_FRESH_DOCUMENT_REVIEW_AND_INDEX_CUSTODY'}
with (E / 'final-document-source-rebind2.json').open('x') as f:
    f.write(json.dumps(d, indent=2) + '\n')
print('updated5 docs; only4 of198 source entries changed; final doc rebind',h(E / 'final-document-source-rebind2.json'))
