# Group Generation successor map

Status: DONE — preparatory read-only mapping, not acceptance review, stage design or implementation advancement. Direct assignment. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; HEAD received from root `8131af39a846c292a022ccbfd32c53376cd57887`, not independently queried. Root exclusively owns repository/evidence/Git/runtime; concurrent edits are preserved. Only this report and its JSON companion were written.

## Recommendation and ordering

**After actual group Generation closure, prioritize M3 Task5's same-authority trust/numeric-address rotation requirement for managed upstream H2.** The exact still-open requirement is `docs/plans/m3-upstream-transport.md:560-562`: replace CA contents at the same path between preparations, change the numeric pin for the same authority, prove captured old/new trust and routing, hostname rejection, no credential forwarding and no cross-generation reuse. This is already product scope, not a new feature. Its local precursor is the accepted H1 fixed/group IP+DER Generation fixture; its missing delta is H2-qualified identity rotation under the real prepared-resource/capture/completion path.

The current stage explicitly excludes trust/IP rotation and H2 reload/load/full streaming/standalone (`docs/designs/m3-managed-h2-group-generation.md:13`). Its final plan says to keep rotation/reload/full matrix/standalone/load open and prepare the next existing requirement only after local closure (`docs/plans/m3-managed-h2-group-generation.md:90-96`). Rotation is the next narrower open Task5 item before repeated reloads (`docs/plans/m3-upstream-transport.md:556-565`), and does not require starting the full Task6/7/standalone packages.

Recommended priority is a dependency order, not a newly approved fixture design:

| Priority | Existing requirement | Why this order / closure limit |
|---|---|---|
| 0 | Finish current group Generation implementation, runtime/reviews and local custody closure | Mandatory predecessor. This report supplies no passing gate. |
| 1 | Task5 prepared-H2 same-authority trust/IP rotation, fixed then existing group composition | Direct next security/identity gap. Reuse existing public preparation and real old/new Generation ownership; preserve separate fixed/group claims. A fixed-only first subgate cannot close the whole group/Task5 requirement. |
| 2 | Task5 bounded H2 active/idle reload plateau and held-retirement capacity | Follows stable identity/custody; do not call one replacement a repeated-reload/plateau pass. |
| 3 | Task6 independent full streaming/cancellation matrix and Task7 lifecycle/capacity gaps | Larger separate packages, using their existing explicit gates. Selected-resource saturation with B available remains here, not covered by the current stage's global token denial. |
| 4 | Existing standalone managed integration and both Task7b managed load profiles | Standalone reuses the same runtime; load needs the qualified matrix/lifecycle path and an exclusive frozen run. These remain independent from priority1. |

The roadmap does not prescribe a strict total order between every later independent package; priorities2–4 are recommended sequencing only. They do not authorize work now or redefine those packages' acceptance.

## Current predecessor is not complete

`docs/plans/m3-managed-h2-group-generation.md:11` says IMPLEMENTING, records initial FAIL90/7 with84 warnings/forced descendant cleanup, and says corrected fixture/source re-review and fresh runtime remain pending. Its Tasks1–6 are still unchecked (`:23-94`). Required remaining closure includes real four socket cells/dedup/failure/cancellation/late-cleanup cases; adapted browser fixture review and real four-row execution; final full SPEC then CODE; fresh unfiltered three-batch scoped union, strict compile, active format/syntax, both isolated consumers and browser; acceptance/document/custody audit/local commit (`:45-94`). The current design also requires every original completion/lifetime and zero/peer/actor gate (`docs/designs/m3-managed-h2-group-generation.md:40-50`).

`implement-plan.md:1,5-7` and `docs/plans/m3-upstream-transport.md:517-531` distinguish the locally closed fixed prepared-T stage from the implementing group successor. Older unchecked composite Task5 boxes cannot be closed merely by reading this map. Current exact frozen-source reviews/runtime/custody must determine actual closure first.

## Bounded follow-up scope already justified

The requirement is **upstream identity rotation through the existing prepared-resource and checked Generation contracts**, not operational listener-certificate issuance, new client credentials, a new trust-file API, automatic HTTPS, public management or deployment.

Established contracts:

- Immutable protocol/authority/dial/TLS identity cannot reuse across incompatible policies/generations; no H1 fallback or automatic replay (`docs/designs/m3-upstream-transport.md:264-284`). Prepared policy is authoritative; conflicting duplicates reject before activation; group Resources flatten/dedup under64 (`:325-345`).
- Preserve URL authority/Host/SNI while dialing the validated numeric address; old prepared trust stays immutable and new preparation gets new trust/resource identity (`docs/designs/m3-upstream-transport.md:510-528`). TLS/name/pin rejection is terminal with no replay/fallback; no new client-certificate/Vault/operational-certificate feature (`:530-534`).
- The same-origin changed-trust/pin and same-path replacement requirements are explicit at `docs/designs/m3-upstream-transport.md:630-639`. These are concrete identity/lifetime tests, not resurrection of the dismissed external control-proof request.
- H1 already establishes the analogous atomic IP+DER and fixed/group real peer model (`docs/plans/m3-managed-h1-generation.md:223-241`; `docs/designs/m3-managed-h1-generation.md:222-229,251-259`). Its actual test uses one authority/port on distinct loopback addresses, distinct CA/leaf chains, immutable old policy after CAS, exact SNI/peer/bytes/completion and EOF (`apps/gaoxy_proxy/test/upstream_transport_generation_test.exs:379-445`). It overwrites original CA files after DER preparation at `:416-418`; that alone is not proof of the exact same-path-between-preparations case or H2.
- Current managed-H2 public preparation accepts a compact source with explicit `trust` material (`apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_preparation.ex:42-77`), validates DER list/count/backing bounds (`:538-568`) and copies trust into supported `cacerts` with H2 TLS policy (`:618-629`). Do not add a production path-valued trust interface to implement the old roadmap wording. A future fixture must supply bounded material through this existing API and demonstrate the same-path replacement at the caller's preparation boundary. Its precise loading/fixture design is deferred until priority0 passes.

Expected follow-up work is bounded test/fixture and evidence work, reusing the exact existing anchors below. No unconditional production edits are justified by this map; diagnose an evidenced failure before selecting source repair files.

| Existing exact path | Reuse role / scope restriction |
|---|---|
| `apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs` | Actual checked fixed-T capture/Session/original completion/retirement/accounting fixture; fixed rotation anchor. |
| `apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs` | Current real G/T composition and group source/unselected custody anchor, only after accepted closure. |
| `apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs` | Existing independent h2/TLS peer helper used by both Generation fixtures. |
| `apps/gaoxy_proxy/test/upstream_transport_generation_test.exs` | Existing H1 fixed/group identity rotation and denial compatibility tests; do not relabel them H2. |
| `apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs` | Existing actual prepared-H2 immutable profile and identity/delegation checks; owner-level checks are not the missing network rotation acceptance. |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_preparation.ex` | Supported compact DER/address policy contract; no proposed source change. |
| `docs/plans/m3-upstream-transport.md`, `implement-plan.md` | Sync only facts after future actual review/runtime/custody. |

No future design/plan/test filenames or exact new command inventory are frozen here. The bounded stage's written scope, fixture topology and constructor/lifetime inventory must be selected after priority0, under the continuing workflow; this report is an input map only.

## Required gates: established requirements versus future inventory

**Identity/functional gate already established:** real old native snapshot before dispatch/checkout; replacement preparation+CAS with new immutable identity; old and new reach only intended peers; authority/SNI/hostname verification preserved; CA replacement affects only new preparation; no trust reread during old request/probe execution; no cross-generation reuse, credential forwarding, alternate peer, fallback or replay. Keep original request completion and resource retirement distinct; normal positive paths require actual public success, physical socket closure and accounting restoration (`docs/plans/m3-upstream-transport.md:544-569`; `docs/designs/m3-upstream-transport.md:510-534,630-639`). H2 means actual H2/ALPN peer evidence; an H1 test or owner-level configuration test cannot substitute.

**Denied TLS gate:** retain the existing exact failure/uncertainty contract rather than inventing normal cleanup success. Accepted H1 denial uses502/no upstream HTTP/fallback/replay and retains `cleanup_unconfirmed`/charged records separately from fixture disposal (`docs/designs/m3-managed-h1-generation.md:276-280`). Existing H2 group history explicitly preserves negative TLS cleanup as unconfirmed; current roadmap records this at `docs/plans/m3-upstream-transport.md:510-515`, and `implement-plan.md:851-866` separates real browser/peer denial from retained cleanup failure. The successor must trace and preserve the actual H2 public contract; do not turn missing Service/process death/test teardown into zero usage or success.

**Review/accounting gate:** write a bounded design/plan and exact initialized fixture/source inventory after current closure; independent SPEC before CODE; review actual complete native/Generation operands and lifetimes if new wrappers/topology change them. New constructors/multiplicities/lifetimes reopen their source checkpoint (`docs/designs/m3-managed-h2-group-generation.md:11,26-36`). Preserve existing fixed/group/startup and Service/owner caps; no model-based fixed allowance or bypass of real admission. This map does not prescribe a new numerical worksheet or revive historical control-proof prerequisites.

**Fresh implementation verification/closure gate:** use real listener/network cases with nonzero executed counts and no weakened assertions (`docs/plans/m3-upstream-transport.md:567-569`), independent specification then code review, strict compile/format, affected scoped HTTP/proxy/Generation/server compatibility, external core isolation and required independent-peer/native fixtures, source/lock identities/limits and factual evidence (`:679-705`). Local browser verification remains an implementation requirement under current root workflow; exact adapted rows/commands must be explicitly reviewed/frozen for that future stage, not borrowed from the current stage's screenshots. The exact existing current-stage three-batch/consumer/browser inventory is at `docs/plans/m3-managed-h2-group-generation.md:70-94`; a future scoped inventory must name its actual sources and impacted suites rather than claim those current counts in advance. Keep PASS/FAIL/NOT RUN/BLOCKED separate (`implement-plan.md:608-610`). Root alone executes, audits and commits authorized owned files.

**Do not accidentally close later requirements:**

- Reload plateau remains an independent Task5 requirement (`docs/plans/m3-upstream-transport.md:563-565`). Existing H1 reference is two warmups+20 fixed/group steady-state reloads with physical retirement joins before samples (`docs/plans/m3-managed-h1-generation.md:247-265`); H2 twenty reloads remain open (`implement-plan.md:7`).
- Task6 is H1→H1/H2 and H2→H1/H2 with TLS-H2/h2c distinguished, streaming/trailers/early-final/flow-control/slow/reset/sibling/reuse and finite fixture shutdown (`docs/plans/m3-upstream-transport.md:571-599`). Current group success and two browser navigations cannot close it.
- Task7 includes real configured connections/streams saturation before upstream bytes, guardians/force retirement/late releases, sibling/scope/instance isolation and exact stop receipts (`:601-629`). Current group global token denial explicitly does not establish selected-A saturation with B available (`docs/plans/m3-managed-h2-group-generation.md:60`).
- Task7b needs two actual managed profiles, each>=600 seconds, frozen manifest/concurrency/limits, slow/reset plus>=20 reloads, exact peer observations and one15-second combined confirmed teardown. Short smoke is UNQUALIFIED (`docs/plans/m3-upstream-transport.md:631-677`). Historical dedicated-H1 soak cannot satisfy them.
- Standalone uses the same runtime/data paths and data-only config with validate/prepare/activate+rollback (`implement-plan.md:575-581`). Embedded rotation evidence is not standalone profile activation. Whole M3 still requires remaining interoperability/security/cancellation/slow-peer/reload/load gates (`implement-plan.md:583-593`; `docs/plans/m3-upstream-transport.md:699-703`).

## Dependencies and blockers

1. **Real immediate dependency: current group Generation closure**, including corrected source/fixture/browser review, fresh actual gates and local document/Git custody. It is internal unfinished work, not an external blocker. Do not begin successor design/implementation while it remains open.
2. **Accepted dependency source: HTTP Fetch/Runtime0.21.10**, explicitly the current supported API in `docs/designs/m3-managed-h2-group-generation.md:22` and stage stack in `docs/plans/m3-managed-h2-group-generation.md:9`. The assignment confirms122 closed/0.21.10 accepted. Older `implement-plan.md:196-199` text describing122 blocked is historical, not an active block. No dependency upgrade/API/private transport workaround is indicated by the mapped requirement.
3. **No real external blocker is evidenced by the assigned current documents/source.** Existing Nix/OTP/Elixir, Python h2, local TLS fixtures/native H1/H2 and Chrome/CDP are established stage tools (`docs/plans/m3-managed-h2-group-generation.md:9,20,63-88`), but no environment/network readiness was run here. If a later actual required environment or upstream contract fails, record that actual BLOCKED_ENV/upstream issue according to root policy; do not invent a blocker now.
4. **97 remains dismissed, not an acceptance/release/M4 blocker** (`implement-plan.md:201-208`; `docs/plans/m3-upstream-transport.md:83-91`). Historical proof/accounting paragraphs must not silently reintroduce it. No quota/account request; no third Astra recovery (current stage `docs/plans/m3-managed-h2-group-generation.md:11`).
5. Existing publication/deployment/production/certificate/Vault/public-management/disabled-release-E2E restrictions persist (`docs/plans/m3-managed-h2-group-generation.md:94-96`). Test-owned loopback trust fixtures are not operational certificates; this map authorizes none.

## Verification and handoff

Only read-only specific source/document searches and report writes were performed. Tests executed:0. No Git/Mix/format/compile/browser/peer/network/runtime/background operations, repository writes, agents or Astra. All own commands finished synchronously. No Sol repair or Astra recovery round consumed. Source hashes in JSON bind the inspected snapshot; root's concurrent documentation/test edits can move line numbers. No user/product decision is needed to prioritize the already-established requirement; the exact future bounded design/gate inventory is deliberately not advanced here.
