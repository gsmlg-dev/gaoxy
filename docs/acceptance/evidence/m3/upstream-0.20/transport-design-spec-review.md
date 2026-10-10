# M3 upstream transport design: independent specification review

**Latest outcome: specification PASS after architecture refinement 1**, recorded
in the re-review below. The original FAIL and all three findings remain intact.
This approves the conditional design, not managed transport runtime acceptance.

Task `m3_transport_design_spec_review`, direct independent Sol review.
Verdict: **SPECIFICATION FAIL** pending the three actionable document findings
below. Ready-now Tasks 0–2 remain unblocked. Conditional transport activation
remains **BLOCKED_ENV** on upstream Feature
[#78](https://github.com/gsmlg-dev/http_fetch/issues/78); this review neither
implements nor qualifies that missing dependency contract.

Workspace `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, HEAD/baseline
`d92d3691e073fbf33195b567af7be10cea6132fc`. Parent-owned dependency/adapter edits,
architecture documents and the ongoing probe worker's scope were preserved.
The reviewer authored the separate public-client audit, but did not author the
reviewed architecture or plan. Exclusive change: this review report.

Reviewed documents:

- `docs/designs/m3-upstream-transport.md`, 355 lines.
- `docs/plans/m3-upstream-transport.md`, 356 lines.

Reviewed SHA256 identities: design
`c82c0a4cc8214ebe98b270dc4864533a7feecf4a61145c8e71b12fd31c3ceabf`;
plan `901c634a2729f96e04484d4903478f6a818702ee7f12ae482ffa55d5eab79abe`.

Requirements were checked against current `AGENTS.md`, `implement-plan.md`
application/lifecycle/proxy/M3 requirements, the M3 gateway/groups designs,
`public-client-audit.md` and the concrete Resources, Instance, GroupEndpoint,
UpstreamGroups and Session source seams. Evolving probe implementations were
not reviewed. No runtime, Mix command, fixture, dependency edit, commit or
publication was performed. Runtime acceptance remains **NOT RUN** by this
reviewer.

## Actionable findings

### S1 — High: name the instance-stop/transport-retirement integration seam

Location: design lines 134–141, 148–150, 200–205; plan Task 4 lines 201–223 and
Task 7 lines 311–313.

The design promises that instance shutdown uses the existing absolute drain
deadline and finishes only after request cleanup **and transport retirement**.
However, the proposed `UpstreamTransports` API contains no stop/retire operation
with that deadline, and the implementation scope lists only necessary proxy
supervision helpers. It never names the caller that joins retirement before the
public instance stop receipt.

Current source cannot supply this implicitly:

- `apps/gaoxy/lib/gaoxy.ex:41–58`: `Gaoxy.stop/2` waits for the Instance stop
  operation and DOWN; it knows no external proxy resource owner.
- `apps/gaoxy/lib/gaoxy/instance.ex:115–125,254–265`: the stop operation drains
  only `live_services`; `terminate/2` lines 180–212 stops the existing service
  supervisor and replies with that result.
- `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex:320–323`: the existing
  external-owner pattern reacts to instance DOWN after termination. It is not
  a pre-stop deadline/receipt integration contract.

An idle transport has no live request cleanup token. Merely supervising or
monitoring the instance therefore cannot guarantee its physical retirement is
joined before `Gaoxy.stop/2` returns, or propagate a retirement uncertainty into
that result. Retaining a ledger after DOWN is correct conservative accounting
but does not establish the promised stop barrier.

Required correction: explicitly identify the public/configuration-owner
lifecycle entrypoint, who sends the original absolute deadline to the transport
owner, and who joins its retirement receipt before reporting shutdown success.
Define pending/unconfirmed/error propagation and owner-death behavior. Name the
necessary implementation files/tests, preserving core independence from HTTP
Fetch. If the selected embedded model instead requires an explicit enclosing
configuration-owner stop operation before `Gaoxy.stop/2`, document that exact
ordering and distinguish its receipt from bare `Gaoxy.stop/2`; do not leave the
stronger instance guarantee implicit.

Verification after correction: with no active request and one retained idle
transport, hold public retirement at a barrier, invoke the documented stop
entrypoint, and prove it cannot report success until retirement confirmation.
Test the same absolute deadline, unconfirmed retirement and a live unrelated
instance. This is a conditional future gate, not a requested runtime test now.

### S2 — Medium: require sustained-load qualification of the managed transports

Location: design acceptance lines 319–338; plan Tasks 6–8 lines 268–339.

The plan has bounded concurrency, repeated reloads, slow peers and retirement
checks, but it does not explicitly require sustained load through the newly
managed H1/H2 resources. Task 8 can close its named transport checks while
reusing the historical 600-second dedicated-H1 proxy soak as the remaining M3
load evidence. That historical profile has no pooled idle/shared lifetime or
managed transport ledger and cannot validate the new resource population under
continuous requests, reloads and pending retirement.

Requirement: `implement-plan.md:247` includes upstream pools and sustained-load
gates; `docs/designs/m3-gateway.md:502–514` requires P8 pool eviction/drain/load
and P9 sustained-load evidence after required slices, with a minimum ten-minute
profile and bounded teardown. Existing `docs/designs/m3-soak.md` expressly
limits its final result to fixed dedicated-H1 proxy behavior.

Required correction: add a conditional sustained-load gate using actual managed
H1 reuse and multiplexed upstream H2, named separately where needed, under
continuous large bounded bodies, slow consumers, request resets, generation
reloads and active/idle/retiring transport churn. Set duration (at least the
existing 600-second gate), capacities and memory/queue ceilings before execution;
record independent accepted connections/streams, exact bytes, request/transport
reservations, public retirement receipts, and finite zero-owned-resource
teardown. Keep the historical dedicated-H1 soak labeled with its original scope.
No additional production feature or publication permission is needed.

### S3 — Low: distinguish Resources facade arities from provider callbacks

Location: design line 143, proposed-interface comment.

`Resources.pin_many/5` and `Resources.cancel/2` are described as existing
signatures. Actual `Gaoxy.HTTP.Resources` exposes `pin_many/4` and `release/1`;
it has **no facade `cancel/2`**. Its resource-provider behaviour separately
requires `pin_many/5`, `release/1`, `cancel/2`
(`apps/gaoxy_http/lib/gaoxy/http/resources.ex:5–8,28–54,58–68`).

Required correction: identify the facade calls as `Resources.pin_many/4` and
`Resources.release/1`, and identify `/5` and `cancel/2` as provider callbacks.
This avoids directing a later implementer toward nonexistent public functions
or an unnecessary generic Resources interface change.

## Requirements otherwise satisfied by the written design

The conditional model preserves the narrow UpstreamClient adapter and request
guardian; it adds a transport metadata owner for mutable admission/lifetime,
without inventing an HTTP protocol stack or starting processes during pure
endpoint compilation. It preserves existing group selections, preparation and
snapshot pins, fail-closed open-to-bind uncertainty, and request completion as
the request-slot release barrier. Transport capacity survives idle and uncertain
retirement; failed/retiring records still debit finite limits.

Protocol/authority/numeric pin/TLS CA/SNI and socket/profile identity remain
immutable, separated from request deadlines. Trust reads/decoding are bounded,
new credentials/Vault features are excluded, forwarding remains dedicated,
redirect/replay/fallback remains forbidden, and explicit H2 requires negotiated
H2. The four protocol directions, TLS H2 versus h2c, demand/ACK/trailer ordering,
early final and connection-wide versus request-local failures have meaningful
independent-peer acceptance criteria.

The absent facade and final byte-accounting constant are correctly conditional
on a containing upstream release and qualification. No private client-state or
global-pool manipulation is authorized. Empty-CONTINUATION retention remains a
source finding with runtime **NOT RUN**, routed only after the parent obtains
focused evidence; no local wrapper workaround is approved. Historical evidence,
new package compatibility, public request probes, product activation and whole
M3 acceptance remain separate. Push/publication/deployment, public management,
Vault and release-artifact E2E restrictions are preserved.

## Verification and handoff

Read-only source/document commands completed. `git diff --check` passed for
tracked changes; this report receives separate whitespace/fence validation.
No reviewer-owned command/process remains running. Fresh review Sol repair
rounds **0**; prior audit repair count **0** preserved; no Astra repair counter
received. No implementation repair or model escalation occurred.

The parent/design owner should correct S1–S3, then request a bounded re-review of
those changed sections. Tasks 0–2 and upstream routing can continue meanwhile;
Tasks 3–8 remain gated. No new user product decision is identified by this review.

## Bounded re-review after architecture refinement 1

Current verdict: **SPECIFICATION PASS** for the corrected design/plan.
**3 original findings resolved / 0 unresolved / 0 new actionable findings**.
The original FAIL report above remains historical evidence for its original
document hashes. This is design acceptance only: managed transport activation
remains **BLOCKED_ENV** on #78 and qualification of complete public bounds;
source empty-CONTINUATION reproduction remains **NOT RUN by this reviewer**.
Ready-now Tasks 0–2 may proceed.

Re-reviewed SHA256 identities, verified against the parent's handoff before
inspection:

- Design: `23930e6cd02510f23848fd1e1a0027ab70c9c3379bbec3d56a6a5aa6394e3346`.
- Plan: `8dbb95027208098e87e9d5a6de74de3faf896fc30bb595493bb1939a74dc6c9e`.

Workspace, branch and baseline remain the original recorded values. This bounded
pass covers corrected lifecycle wiring, soak gates and Resources signatures;
the evolving public-probe implementation is outside the assignment.

| Finding | Corrected sections | Re-review result |
| --- | --- | --- |
| S1: instance-stop barrier | Design 141–144 and 212–303; plan Task 4, 203–254, lifecycle gate 345–352, compatibility gate 420–423 | RESOLVED. A proposed generic core participant registry authenticates/registers the owner before allocation, includes failed registrations in a finite64-entry bound, and rejects new registrations during shutdown. `Gaoxy.stop/2` retains its entrypoint and fans out service drain plus registered participants under the same absolute D. Named coordinator messages join transport retirement before success; idle resources join without request cleanup tokens. Pending/deadline, unconfirmed owner loss and resource errors have explicit result semantics; termination preserves earlier results. New core files/tests are named and carry no HTTP dependency. |
| S2: managed sustained load | Design 438–474; plan Task 7b, 359–405, final acceptance 427–431 | RESOLVED. Separate managed H1-reuse and verified TLS-H2 multiplexed profiles each require actual offered load>=600s. Candidate/worksheet/limits freeze precedes execution; large exact bodies, slow credits, progress resets, >=20 reloads, active/idle/retiring resources and repeated retirement barriers are required. Preselected finite capacities, resource/request reservations, peer connection/stream identities and sampled exclusions are recorded. One15s teardown requires combined stop, retirement receipts, zero owned reservations, process DOWN, socket closure and fixture termination. Historical dedicated-H1 soak and shorter smoke cannot close these gates. |
| S3: Resources arities | Design 147–148; plan 217–219 | RESOLVED. Public facade `Resources.pin_many/4` and `release/1` are distinguished from provider callbacks `pin_many/5`, `release/1`, `cancel/2`; no nonexistent facade cancel is proposed. |

The newly named `Gaoxy.register_lifecycle_participant/2`, participant messages,
and `UpstreamTransports.retire/2` / `await_retirement/2` are explicitly proposed
Gaoxy interfaces. They are not represented as existing HTTP Fetch APIs.
Conditional upstream create/select/limit/retire/await/status signatures must
still be recorded and qualified before runtime edits. The public completion
guardian remains the request-slot barrier; the registry joins the distinct
transport-retirement barrier and does not erase pending or unconfirmed holds.

The correction stays within `implement-plan.md` lifecycle/resource/proxy/M3
scope: necessary generic shutdown integration preserves core isolation; service-
only return compatibility and core-only consumer checks are explicit. It adds
no HTTP3, forward-pool, client-certificate, Vault, management or release feature.
The original publication/deployment and release-artifact E2E restrictions remain.

Verification: read-only `sha256sum`, exact corrected document reads, and final
Python hash/whitespace/fence validation pass; reviewed hashes remain unchanged.
No source, Mix, runtime or fixture command was run. Only this report was appended;
the public-client audit and other workers' files were preserved. All reviewer
commands finished; no owned process remains. Sol audit count **0**, initial
review repair count **0**, re-review repair count **0**; architecture refinement
**1** is document refinement, not a recovery round. All unrelated historical
task repair counters are unchanged. No Astra recovery counter received.
