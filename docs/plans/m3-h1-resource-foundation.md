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

**Status:** Prepared execution handoff; final documentation main push and
execution kickoff pending. Every implementation/test/code-review task below is
**NOT RUN**. Read [the design](../designs/m3-h1-resource-foundation.md) and
[existing Task 4](m3-upstream-transport.md#task-4-pure-policy-and-bounded-transport-resource-conditional).

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

## Scope and ownership

During this handoff assignment, the writer owns only these two documents and
one unique preparation review receipt.
The following executable files are future Task 4 ownership, not permission to
edit them during the M4 freeze.

| Slice | Files and responsibility | Dependency |
| --- | --- | --- |
| A: core participant | Modify `apps/gaoxy/lib/gaoxy.ex`, `gaoxy/instance.ex`, `gaoxy/lifecycle.ex`; create `apps/gaoxy/test/lifecycle_participant_test.exs` | Parent releases freeze; specification review |
| B: pure options | Create `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports/options.ex`; reuse `managed_h1_preparation.ex`; create `apps/gaoxy_proxy/test/upstream_transports_options_test.exs` | Independent of A's source edits; resource startup waits for A acceptance |
| B/C: ledger/custodian | Create `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex` and `upstream_transports/custodian.ex`; create `apps/gaoxy_proxy/test/upstream_transports_test.exs` | A accepted; pure options accepted |
| C: real public contract | Create `integration/http_fetch_contract/h1_resource_foundation_peer.py` and `h1_resource_foundation_probe.exs`; add scoped tests to `upstream_transports_test.exs` | Ledger/custodian and request-hold behavior accepted |
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

- [ ] Parent completes the current M4 acceptance boundary and releases the
  relevant source freeze; assign the implementation checkout and exclusive files.
- [ ] Verify path, branch, HEAD, current diff and untracked files. Preserve the
  pre-existing M4 changes. Use a `codex/` branch under the project's `.trees/`
  directory if isolation is needed.
- [ ] Read current AGENTS, this design and existing Task 4. Treat old conditional
  native/control proof requirements as superseded by the reviewed disposition.
- [ ] Recheck direct/lock versions and public facade source identity. Current
  facade SHA256 is `2f89d9535c116dfc129f7e64c36d54256271a24405d1f860d58911e2bc397e5a`.
  Re-read the documented API if it changes; do not silently use old behavior.
- [ ] Parent arranges independent specification review and resolves findings
  before executable edits. Record received repair counters and command ownership.

## Step 1: register generic instance-lifetime participants

Owned files: Slice A core files and new participant test.

- [ ] Write RED tests for self-authenticated caller identity, one registration
  per PID, 64 accepted registrations/65th rejected, failed-entry retention,
  stopping rejection and cross-instance isolation. Include registration timeout
  with no subsequent test-resource allocation.
- [ ] Parent runs the new scoped test and records the actual expected RED result.
- [ ] Implement `Gaoxy.register_lifecycle_participant(instance, timeout_ms)` and
  the instance-owned monitored registry; no transport/dependency terms in core.
  Use bounded failure metadata and no unregister/replacement API.
- [ ] Parent runs GREEN. Inspect nonzero count/exit and source stability, then
  obtain independent code review and fresh verification before the local commit.

## Step 2: join services and participants under the original stop deadline

Owned files: same Slice A files. Depends on Step 1.

- [ ] Add receive-barrier RED tests proving every drain is dispatched before
  any wait; services and participants observe identical D; Instance remains
  responsive; no receipt is accepted from wrong/stale/duplicate identities.
- [ ] Cover held success, confirmed failure, pending at D, participant death,
  coordinator death, supervisor termination and both receipt/monitor delivery
  orders. Existing service-only result shapes must remain exact.
- [ ] Implement the combined bounded coordinator and termination helper using
  the design's message tuples and result shapes. Preserve failed explicit-stop
  results through termination and keep cleanup headroom outside success budget.
- [ ] Run participant tests plus the listed core lifecycle compatibility tests.
  Parent also runs the existing core-only consumer isolation gate. Record
  actual counts/exits; resolve actionable independent review before committing.

## Step 3: construct immutable H1 options without effects

Owned files: Options module and its test. This can run in parallel with A when
writers are disjoint; runtime commands remain parent-serialized.

- [ ] Write RED tests for strict fields/duplicates, finite ledger limits,
  resource count at most 64, protocol/authority/literal-address mismatch,
  bounded policy/trust backing, unknown request overrides and compact values.
- [ ] Implement the smallest pure wrapper over `ManagedH1Preparation`; retain
  fixed C2/R32/P0 H1 policy and explicit DER trust. Reject caller SSL callbacks,
  raw option passthrough, H2/H3 and mutable trust-path configuration.
- [ ] Define required finite resource/pin/token/owned-payload limits. Label
  owned-payload accounting accurately; no VM/native memory reservation constant
  or evaluator is introduced.
- [ ] Test boundary refusal before scope/process/network creation and immutable
  policy equality with existing preparation. Parent records GREEN and review.

## Step 4: create registered ledger records and persistent custodians

Owned files: UpstreamTransports, Custodian and resource test. Depends on Steps
2 and 3 acceptance.

- [ ] Write RED tests proving registration success and capacity reservation
  precede all resource effects, limit exhaustion has no queue/effects, and
  opening/retiring/failed records plus helpers remain counted.
- [ ] Implement explicit owner startup and temporary supervision, instance
  monitoring, redacted bounded status, and `prepare/4`. Each record's persistent
  custodian calls public `ManagedTransport.open/1`; use no opaque-field access.
- [ ] Use test-owned receive barriers for preparer death, deadline before open
  result, late success, open failure and custodian death. Assert no late handle
  publication, retained uncertain holds and public retirement of late scopes.
- [ ] Bound control helpers per record, keep open/retire fixed-call waits outside
  the ledger, and preserve the caller's absolute deadline independently of their
  5,000 ms control-call duration.
- [ ] Parent runs resource/option tests, then independent code review and fresh
  verification. Commit only the assigned source/test/doc changes.

## Step 5: provide metadata pins and separate request completion holds

Owned files: ledger/custodian/resource tests. Depends on Step 4.

- [ ] Write RED tests for `Resources.pin_many/4` and `release/1` through provider
  `pin_many/5`, `release/1`, `cancel/2`: batch rollback, operation cancellation,
  holder death, duplicate release, stale owner epoch and exact bounded counts.
- [ ] Implement provider behavior without changing Resources or Generation.
  Serialize only same-owner metadata mutations; no nested provider calls.
- [ ] Write/implement `checkout/4`, `bind_completion/3`, `finish/2` tests for an
  authenticated guardian and request pin, separate request token, immediate
  binding, completion pending/unconfirmed, duplicate finish and guardian death.
- [ ] Exercise open-to-bind uncertainty. Retain the request hold and retire the
  associated scope; no DOWN/stream terminal event alone releases credit.
- [ ] Assert request completion releases exactly the request hold and leaves
  transport capacity intact for idle reuse. Parent records GREEN and review.

## Step 6: retire owned resources and join the core stop receipt

Owned files: ledger/custodian/resource tests. Depends on Steps 2 and 5.

- [ ] Write RED tests for immediate admission closure, idle retirement despite
  baseline pins, admitted-request drain, same receipt/repeated waits, D never
  extended, graceful-to-abort escalation and pending initiation at short D.
- [ ] Implement `retire/2`, `await_retirement/2` and generic participant message
  handling. Only public `await_retired/2 == :ok` refunds transport capacity.
- [ ] Test lost initiation result recovery through repeated public `retire/2`,
  pending/unconfirmed receipts, helper/owner/instance death and late confirmed
  refund without rewriting the earlier failed stop result.
- [ ] Keep a successfully retired owner inert until instance DOWN. Test that
  stop success waits for its cached authenticated result and every resource
  receipt; no blank-ledger restart is permitted after uncertain ownership.

## Step 7: execute the independent H1 resource acceptance profile

Owned files: new peer/probe, resource tests and new evidence run directory.
No production endpoint wiring. Depends on Step 6.

- [ ] Implement an independent origin with bounded readiness/control pipes,
  peer connection IDs and request IDs; CPython/OpenSSL verifies TLS CA/hostname.
  Keep finite deadlines, body hashes/trailers and owned process/socket joins.
- [ ] For TCP and verified TLS, use only public managed scope + Fetch APIs to
  send two sequential self-delimited requests on one accepted connection. Capture
  original completions immediately and assert no request replay.
- [ ] Prove request completion succeeds while that connection remains idle and
  its transport reservation remains held. Retire publicly, observe peer EOF,
  join the receipt and then assert transport capacity release.
- [ ] Hold an unread response/upload at a peer barrier. Exercise request abort,
  retained request credit before confirmation, short-D pending stop, later
  cleanup and unchanged failed stop receipt. No private pool/process inspection.
- [ ] Keep a second instance/scope to the same origin live while retiring the
  first; a fresh request on the second must succeed with exact bytes.
- [ ] Record actual nonzero executed cases, exits and source/cohort hashes.
  Missing peer/environment tools are BLOCKED_ENV, never skips or PASS. A real
  dependency defect follows AGENTS upstream issue routing with a reproduction;
  no speculative dependency issue or local blocker workaround.

## Scoped verification and completion

The parent alone executes commands in the qualified environment. These are
planned commands, **NOT RUN** in this document assignment:

```sh
unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy/test/lifecycle_participant_test.exs apps/gaoxy/test/lifecycle_fault_test.exs apps/gaoxy/test/lifecycle_ownership_test.exs apps/gaoxy/test/lifecycle_acceptance_test.exs
unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transports_options_test.exs apps/gaoxy_proxy/test/upstream_transports_test.exs apps/gaoxy_proxy/test/managed_h1_preparation_test.exs
unbuffer mix run --no-compile --no-start integration/http_fetch_contract/h1_resource_foundation_probe.exs
```

- [ ] Execute existing core-only consumer isolation plus scoped canonical format
  and strict compilation in the repository's qualified environment. Record exact
  wrappers, tools, source hashes, test counts, exits and all peer cleanup receipts.
- [ ] Independent specification and code review: resolve actionable findings;
  run fresh affected checks after changes. Preserve original failing evidence.
- [ ] Verify checklist against the design, distinguish source/functional bounds
  from total VM/native memory, and stage only owned files for local conventional
  commits. No push/release follows automatically from foundation acceptance.
- [ ] Stop this package when its in-scope gates pass. Report resource foundation
  DONE while production managed-H1 activation/full M3 remain NOT RUN. Advance
  under continuing authorization to the existing M3 Task 5 fixed-endpoint
  activation package; groups/probes/upstream H2 remain separate later work.
