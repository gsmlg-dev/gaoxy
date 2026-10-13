# M3 H1 Resource Foundation Implementation Plan

> For agentic workers: use executing-plans or parent-managed
> subagent-driven-development for bounded task execution. Sol implements and
> independently reviews. Continuing authorization replaces routine approval
> pauses; the parent releases executable freezes and serializes Mix/live commands.

**Goal:** Implement existing M3 upstream-transport Task 4's owned H1 resources,
starting with a generic instance-stop barrier and ending before Task 5 activation.

**Architecture:** Core participates through authenticated generic lifecycle
messages only. Proxy owns immutable H1 policy, a finite ledger and persistent
scope custodians. Request completion and physical retirement settle different
holds; all stop work shares one absolute deadline.

**Tech stack:** Existing Elixir/OTP umbrella, ExUnit, HTTP Fetch/http_runtime
0.21.4 public ManagedTransport and RequestCompletion APIs, independent raw
TCP/CPython OpenSSL fixtures. No new production dependency.

**Status:** **DONE — Steps 0–7 locally accepted**. Final independent SPEC then
CODE review passes with no findings. Fresh proxy **77/0**, scoped format and
strict compile pass. Complete TCP/TLS execution passes **8/0**, exit 0, with zero
skips/exclusions and all owned cleanup receipts passing. Unchanged core **36/0**
and external consumer **1/0** remain source-bound. Historical REDs, failed GREEN
reviews and 8/4, 8/5, 8/4 runs remain preserved below and in
[acceptance](../acceptance/m3-h1-resource-foundation.md). Execute the
[next fixed-endpoint package](m3-managed-h1-fixed-endpoint.md) under continuing
authorization after the local foundation commit.

**Historical planning checkout:** `.trees/m4-http3`, `codex/m4-http3`, baseline
`d5831d7613e8c8edd2adf76fbd7b86b408e62de6`, concurrently modified for M4.
Source review confirmed installed 0.21.4 APIs; no fresh managed-H1 execution is
claimed. The parent provides the execution baseline and cumulative Sol/Astra
counters at each handoff. This package does not reset them or authorize another
Astra recovery round.

## Release and execution handoff — 2026-10-13

Published v0.3.0 and qualified artifact source:
`4931982cff7b07c8e9f42a5e4561d22854d418bd`; annotated tag object
`ba9ce0b8e124ac6b819488c8ebe074d53d5a581d` peels to that source.
[Publication/download verification](../acceptance/evidence/release-0.3.0/publication-1791863800600551728/publication-verification.json)
is **PASS_PUBLICATION_AND_FRESH_DOWNLOAD**, SHA256
`2c04e39cd566469072006b4b13c5be2542e8305f791d5bae3e6cc4e000db5e89`:
three downloads equal qualified bytes, safe inventory 1,420 entries, five
applications at 0.3.0 and two checksums verified. The [publication independent review](../acceptance/evidence/release-0.3.0/review-actual-publication-fresh-download-1791864019336220804.json)
is **PASS**, with no findings; API `immutable: false` is retained. Final main
documentation push is pending at this snapshot. Final main
documentation is a descendant identity, recorded separately from artifact/tag
source. The [design handoff](../designs/m3-h1-resource-foundation.md#release-identity-and-execution-handoff--2026-10-13)
links exact-source, artifact/runtime, hosted and prior preparation reviews.

[Final portable evidence](../acceptance/evidence/release-0.3.0/portable-final-1791863003049561405/manifest.json)
records build 3/finalize/runtime 2 **PASS**, 757 tests/zero failures, core 3,
gateway 2, H3 three and ELF 21, with child/removal zero exits and owned-container
absence confirmed. Hosted CI remains **BLOCKED_ENV**, ten no-start jobs/zero
steps; disabled release-artifact E2E remains **NOT RUN**. These facts do not
execute or accept this Task 4 package.

The verified lock is seven HTTP/QUIC/TLS cohort packages at **0.21.4**, SHA256
`aa9220766e1699f5cfa9d8513df95910a613cf2cbba37e8ce977267e3b68d9ab`;
the public ManagedTransport facade remains
`2f89d9535c116dfc129f7e64c36d54256271a24405d1f860d58911e2bc397e5a`.
Carry **20 live / 8 production / 3 harness** unsuccessful UP2 outcomes and
**Astra recovery 2 exhausted**, with zero rounds added here. Preserve earlier
histories and the separate portable-harness repair ledger; no counter reset or
third Astra recovery is authorized.

Implementation checkout bootstrap: `.trees/m3-h1-resource-foundation`, branch
`codex/m3-h1-resource-foundation`, actual HEAD
`4931982cff7b07c8e9f42a5e4561d22854d418bd`. The [bootstrap receipt](../acceptance/evidence/release-0.3.0/next-task4-bootstrap-1791864162247441315.json)
is **PASS_CLEAN_BOOTSTRAP_FROM_VERIFIED_RELEASE_SOURCE**, SHA256
`b541d7f1b1fe05cad357a06262ffb9fe91e24e80688342736b00be6e4606746a`;
tracked diff and untracked inventory are empty. After final documentation main
push, the parent fast-forwards this checkout from the released source.
A separate kickoff receipt records actual path/branch/HEAD/tree, docs/evidence
only diff from released source and current diff/untracked inventory. Final fast
forward and kickoff remain pending; no final SHA or executable ownership is
assigned in advance. M4 executable freeze remains intact at this snapshot;
its release and future disjoint writers are recorded by the parent kickoff.
The parent retains serialized Mix/build/live command
ownership. All Step 0 boxes remain unchecked, and no Task 5 activation starts.

## Execution kickoff — 2026-10-13

The parent verified clean execution checkout `.trees/m3-h1-resource-foundation`
on `codex/m3-h1-resource-foundation` at
`449a4c4d470128d9e138564fe71b40e8fcebe358`, equal to remote main. The descendant
diff from released source is documentation/evidence only. M4 acceptance/publication
reviews are complete; the preparation freeze is released for assigned Task 4 files.
The scope table now assigns executable ownership; its documentation-only limits
describe the earlier handoff.

[Kickoff receipt](../acceptance/evidence/m3/h1-resource-foundation/1791870010586271722/kickoff.json) records
source/cohort hashes, writer ownership and inherited counters. The parent owns
all Mix/build/live commands. Astra recovery remains 2/2 exhausted; ordinary
failures enter local Sol diagnosis and repair. Renewed continuing authorization
supersedes routine approval/phase-stop rules; product, publication/deployment,
Vault, production and disabled-E2E boundaries remain. Independent specification review PASS. Initial core/options verification: 66 tests/0 failures;
Options independent SPEC/CODE review PASS. Core SPEC/CODE review PASS, core-only consumer 1/0 PASS and fresh post-review
format/strict compile/66 tests PASS. Steps 1–3 are accepted. Step 4 initial
40/0 GREEN did not satisfy its independent review: helper/creator joins and
actual failed-open accounting needed repair. Repair 1 RED is 44 tests/four
expected failures, exit 2, source stable; the earlier 40/0 result remains
preserved. [Repair review](../acceptance/evidence/m3/h1-resource-foundation/1791870010586271722/ledger-review-repair1.json)
and fresh post-review 44/0 verification accept Step 4. Peer source repair 1 independently passed SPEC/CODE review; network
acceptance remains NOT RUN.

## Scope and ownership

Historical preparation ownership (superseded by the verified execution kickoff):
the handoff writer owned only these two documents and a preparation review
receipt. The table below now assigns Task 4 executable ownership; its earlier
freeze has been released.

| Slice | Files and responsibility | Dependency |
| --- | --- | --- |
| A: core participant | Modify `apps/gaoxy/lib/gaoxy.ex`, `gaoxy/instance.ex`, `gaoxy/lifecycle.ex`; create `apps/gaoxy/test/lifecycle_participant_test.exs` | Parent releases freeze; specification review |
| B: pure options | Create `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports/options.ex`; reuse `managed_h1_preparation.ex`; create `apps/gaoxy_proxy/test/upstream_transports_options_test.exs` | Independent of A's source edits; resource startup waits for A acceptance |
| B/C: ledger/custodian | Create `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex` and `upstream_transports/custodian.ex`; create `apps/gaoxy_proxy/test/upstream_transports_test.exs` | A accepted; pure options accepted |
| C: real public contract | Create `integration/http_fetch_contract/h1_resource_foundation_peer.py` and `h1_resource_foundation_probe.exs`; add scoped tests to `upstream_transports_test.exs` | Independent peer source can be prepared alongside the ledger; probe/resource integration and execution wait for ledger/custodian/request-hold acceptance |
| Evidence/review | New `docs/acceptance/evidence/m3/h1-resource-foundation/<run-id>/` receipts and these two docs | Parent assigns writer; no historical evidence overwrite |

Start the owner explicitly under the embedding supervisor using its child spec;
do not add a global transport owner or change production adapter supervision.
If a necessary helper needs another file, assign its exact ownership before
editing. Core remains independent of HTTP/Plug/Fetch. Preserve unrelated edits
and user-owned files; do not patch `deps/` or alter historical accounting code.

Do not modify `HTTPFetchClient`, `Proxy.HTTP`, Session, GroupEndpoint,
UpstreamGroups, Generation/router activation, standalone configuration or
capability declarations in this package. Those are Task 5 or later. No M5,
public management, deployment, Vault or disabled E2E work is included.

## Step 0: prepare a verified execution handoff

- [x] Parent completes the current M4 acceptance boundary and releases the
  relevant source freeze; assign the implementation checkout and exclusive files.
- [x] Verify path, branch, HEAD, current diff and untracked files. Preserve the
  pre-existing M4 changes. Use a `codex/` branch under the project's `.trees/`
  directory if isolation is needed.
- [x] Read current AGENTS, this design and existing Task 4. Treat old conditional
  native/control proof requirements as superseded by the reviewed disposition.
- [x] Recheck direct/lock versions and public facade source identity. Current
  facade SHA256 is `2f89d9535c116dfc129f7e64c36d54256271a24405d1f860d58911e2bc397e5a`.
  Re-read the documented API if it changes; do not silently use old behavior.
- [x] Parent arranges independent specification review and resolves findings
  before executable edits. Record received repair counters and command ownership.

## Step 1: register generic instance-lifetime participants

Owned files: Slice A core files and new participant test.

- [x] Write RED tests for self-authenticated caller identity, one registration
  per PID, 64 accepted registrations/65th rejected, failed-entry retention,
  stopping rejection and cross-instance isolation. Include registration timeout
  with no subsequent test-resource allocation.
- [x] Parent runs the new scoped test and records the actual expected RED result.
- [x] Implement `Gaoxy.register_lifecycle_participant(instance, timeout_ms)` and
  the instance-owned monitored registry; no transport/dependency terms in core.
  Use bounded failure metadata and no unregister/replacement API.
- [x] Parent runs GREEN. Inspect nonzero count/exit and source stability, then
  obtain independent code review and fresh verification before the local commit.

## Step 2: join services and participants under the original stop deadline

Owned files: same Slice A files. Depends on Step 1.

- [x] Add receive-barrier RED tests proving every drain is dispatched before
  any wait; services and participants observe identical D; Instance remains
  responsive; no receipt is accepted from wrong/stale/duplicate identities.
- [x] Cover held success, confirmed failure, pending at D, participant death,
  coordinator death, supervisor termination and both receipt/monitor delivery
  orders. Existing service-only result shapes must remain exact.
- [x] Implement the combined bounded coordinator and termination helper using
  the design's message tuples and result shapes. Preserve failed explicit-stop
  results through termination and keep cleanup headroom outside success budget.
- [x] Run participant tests plus the listed core lifecycle compatibility tests.
  Parent also runs the existing core-only consumer isolation gate. Record
  actual counts/exits; resolve actionable independent review before committing.

## Step 3: construct immutable H1 options without effects

Owned files: Options module and its test. This can run in parallel with A when
writers are disjoint; runtime commands remain parent-serialized.

- [x] Write RED tests for strict fields/duplicates, finite ledger limits,
  resource count at most 64, protocol/authority/literal-address mismatch,
  bounded policy/trust backing, unknown request overrides and compact values.
- [x] Implement the smallest pure wrapper over `ManagedH1Preparation`; retain
  fixed C2/R32/P0 H1 policy and explicit DER trust. Reject caller SSL callbacks,
  raw option passthrough, H2/H3 and mutable trust-path configuration.
- [x] Define required finite resource/pin/token/owned-payload limits. Label
  owned-payload accounting accurately; no VM/native memory reservation constant
  or evaluator is introduced.
- [x] Test boundary refusal before scope/process/network creation and immutable
  policy equality with existing preparation. Parent records GREEN and review.

## Step 4: create registered ledger records and persistent custodians

Owned files: UpstreamTransports, Custodian and resource test. Depends on Steps
2 and 3 acceptance.

- [x] Write RED tests proving registration success and capacity reservation
  precede all resource effects, limit exhaustion has no queue/effects, and
  opening/retiring/failed records plus helpers remain counted.
- [x] Implement explicit owner startup and temporary supervision, instance
  monitoring, redacted bounded status, and `prepare/4`. Each record's persistent
  custodian calls public `ManagedTransport.open/1`; use no opaque-field access.
- [x] Use test-owned receive barriers for preparer death, deadline before open
  result, late success, open failure and custodian death. Assert no late handle
  publication, retained uncertain holds and public retirement of late scopes.
- [x] Bound control helpers per record, keep open/retire fixed-call waits outside
  the ledger, and preserve the caller's absolute deadline independently of their
  5,000 ms control-call duration.
- [x] Parent runs resource/option tests, then independent code review and fresh
  verification. Commit only the assigned source/test/doc changes.

## Step 5: provide metadata pins and separate request completion holds

Owned files: ledger/custodian/resource tests. Depends on Step 4.

- [x] Write RED tests for `Resources.pin_many/4` and `release/1` through provider
  `pin_many/5`, `release/1`, `cancel/2`: batch rollback, operation cancellation,
  holder death, duplicate release, stale owner epoch and exact bounded counts.
- [x] Implement provider behavior without changing Resources or Generation.
  Serialize only same-owner metadata mutations; no nested provider calls.
- [x] Write/implement `checkout/4`, `bind_completion/3`, `finish/2` tests for an
  authenticated guardian and request pin, separate request token, immediate
  binding, completion pending/unconfirmed, duplicate finish and guardian death.
- [x] Exercise open-to-bind uncertainty. Retain the request hold and retire the
  associated scope; no DOWN/stream terminal event alone releases credit.
- [x] Assert request completion releases exactly the request hold and leaves
  transport capacity intact for idle reuse. Parent records GREEN and review.

## Step 6: retire owned resources and join the core stop receipt

Owned files: ledger/custodian/resource tests. Depends on Steps 2 and 5.

- [x] Write RED tests for immediate admission closure, idle retirement despite
  baseline pins, admitted-request drain, same receipt/repeated waits, D never
  extended, graceful-to-abort escalation and pending initiation at short D.
- [x] Implement `retire/2`, `await_retirement/2` and generic participant message
  handling. Only public `await_retired/2 == :ok` refunds transport capacity.
- [x] Test lost initiation result recovery through repeated public `retire/2`,
  pending/unconfirmed receipts, helper/owner/instance death and late confirmed
  refund without rewriting the earlier failed stop result.
- [x] Keep a successfully retired owner inert until instance DOWN. Test that
  stop success waits for its cached authenticated result and every resource
  receipt; no blank-ledger restart is permitted after uncertain ownership.

## Step 7: execute the independent H1 resource acceptance profile

Owned files: new peer/probe, resource tests and new evidence run directory.
No production endpoint wiring. Depends on Step 6.

- [x] Implement an independent origin with bounded readiness/control pipes,
  peer connection IDs and request IDs; CPython/OpenSSL verifies TLS CA/hostname.
  Keep finite deadlines, body hashes/trailers and owned process/socket joins.
- [x] For TCP and verified TLS, use only public managed scope + Fetch APIs to
  send two sequential self-delimited requests on one accepted connection. Capture
  original completions immediately and assert no request replay.
- [x] Prove request completion succeeds while that connection remains idle and
  its transport reservation remains held. Retire publicly, observe peer EOF,
  join the receipt and then assert transport capacity release.
- [x] Hold an unread response/upload at a peer barrier. Exercise request abort,
  retained request credit before confirmation, short-D pending stop, later
  cleanup and unchanged failed stop receipt. No private pool/process inspection.
- [x] Keep a second instance/scope to the same origin live while retiring the
  first; a fresh request on the second must succeed with exact bytes.
- [x] Record actual nonzero executed cases, exits and source/cohort hashes.
  Missing peer/environment tools are BLOCKED_ENV, never skips or PASS. A real
  dependency defect follows AGENTS upstream issue routing with a reproduction;
  no speculative dependency issue or local blocker workaround.

## Scoped verification and completion

The parent alone executes commands in the qualified environment. The commands
below were planned during the document assignment. Scoped core/proxy commands
have now executed through Steps 1–6 acceptance after repairs; see the acceptance
receipts for actual counts/exits. Step 6 repair 2 acceptance follows the preserved
repair 1 review rejection and returned-error RED. The first independent probe execution remains **FAIL (8/4, exit 1)** in its
immutable receipt. Repair 6 and fresh post-review all-eight runs now **PASS
(8/0, exit 0)** under the restored original policy/explicit-null contract:

```sh
unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy/test/lifecycle_participant_test.exs apps/gaoxy/test/lifecycle_fault_test.exs apps/gaoxy/test/lifecycle_ownership_test.exs apps/gaoxy/test/lifecycle_acceptance_test.exs
unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transports_options_test.exs apps/gaoxy_proxy/test/upstream_transports_test.exs apps/gaoxy_proxy/test/managed_h1_preparation_test.exs
unbuffer mix run --no-compile --no-start integration/http_fetch_contract/h1_resource_foundation_probe.exs
```

- [x] Execute existing core-only consumer isolation plus scoped canonical format
  and strict compilation in the repository's qualified environment. Record exact
  wrappers, tools, source hashes, test counts, exits and all peer cleanup receipts.
- [x] Independent specification and code review: resolve actionable findings;
  run fresh affected checks after changes. Preserve original failing evidence.
- [x] Verify checklist against the design, distinguish source/functional bounds
  from total VM/native memory, and stage only owned files for local conventional
  commits. No push/release follows automatically from foundation acceptance.
- [x] Stop this package when its in-scope gates pass. Report resource foundation
  DONE while production managed-H1 activation/full M3 remain NOT RUN. Advance
  under continuing authorization to the existing M3 Task 5 fixed-endpoint
  activation package; groups/probes/upstream H2 remain separate later work.

## Historical Step 7 repair 3 execution disposition

Pure ALPN policy regression GREEN is **77/0**, exit 0. The unchanged eight-case
network profile is **8/5 FAIL**, exit 1. Four TLS cases reject public open with
`:invalid_transport_scope_tls_policy`; zero connections accepted, and admitted
failed-open owner retirement/owner-DOWN cleanup is unconfirmed/failed, not PASS.
The TCP held-upload one-shot finish check races the independently joined abort
helper; completion success alone does not certify helper settlement. Ordinary
Sol harness repair 4 retains strict final `:ok` with same-token finite polling.
Public ALPN support requires a minimal public-API reproduction and upstream
routing if confirmed; no assertion weakening or dependency patch is permitted.
See the repair 3 live assessment receipt. Step 7 unsuccessful repairs: **3**;
Astra **2/2 exhausted** unchanged. Full foundation and Task 5 activation are not
accepted by the pure GREEN or source review.

## Reviewed contract correction, not an external gate

Public A/B diagnostic confirms only that optional H1 ALPN injection is unsupported.
Independent scope audit traces the already accepted TLS plan's exact Python None /
JSON null requirement and compact preparation's SSL grammar without advertisement.
The harness's expected negotiated `http/1.1` was wrong. Parent and initial review
incorrectly made optional Feature #107 a blocker; severity/body are corrected to
`nice-to-have`, with initial assessment and failed evidence preserved.

Repair 4 executed all8/4, exit1: all TCP4 primary/cleanup PASS, exact same-token
finish pending then :ok; four TLS cases still reject the unsupported candidate.
Four unsuccessful Step7 package attempts remain recorded; no Astra round added.
Repair 5 restores exact original SSL grammar and requires every peer ALPN exactly
null, rejecting every nonnil value. Keep all H1 framing/bytes/trailers/identity,
CA/hostname/SNI/reuse/no-replay, credits/owned joins/cache/deadline assertions.
Run pure contract RED/GREEN, independent SPEC then CODE, fresh complete8 plus
affected scoped checks. No weaker/multi-protocol assertion, dependency patch or
new product approval is needed. Advance Task5 only after actual foundation gates.

## Repair 5 review and repair 6 explicit telemetry

Repair 5 restores the original policy and passes pure77/0, but independent CODE
review rejects a missing-field acceptance: map lookup returned nil for either
JSONnull or an absent ALPN key. Repair 6 uses `Map.fetch!` so the key must be
present and its value exactly nil. Every nonnil or missing selection fails.
Other protocol/security/credit/deadline/join assertions remain unchanged. This
review failure is preserved separately; Step7 unsuccessful attempts **5** before
repair6 acceptance. Inherited counters and Astra2/2 exhausted remain unchanged.

## Completed final gate

The [final independent review](../acceptance/evidence/m3/h1-resource-foundation/1791870010586271722/foundation-final-independent-review.json)
and [final acceptance receipt](../acceptance/evidence/m3/h1-resource-foundation/1791870010586271722/foundation-final-acceptance.json)
record all prescribed gates. All eight independent cases and all primary/cleanup
receipts pass; fresh proxy77/0, scoped format and strict compile pass with stable
source. Relevant core/consumer sources equal their verified36/0 and1/0 receipts.
All historical failed runs, the blank-line format failure and wrapper invocation
failure remain unchanged. Five prior unsuccessful Step7 attempts and inherited
UP2/Astra counters remain recorded. Parent stages only task-owned source/docs/
evidence for a local conventional commit, then records its actual SHA in Task5
kickoff; no future commit identity is invented here. Task5's fixed endpoint starts
automatically, with its own RED/GREEN, independent review and acceptance gates.
