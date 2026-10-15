# Managed H2 Group Boundary Implementation Plan

> For agentic workers: execute tasks with explicit ownership and independent SPEC then CODE review. Root alone owns repository writes, Mix/runtime/evidence/index. Reuse source-only agents in parallel for independent review/test drafting. Continuing authorization supplies routine design/execution approval; no new approval prompt. This plan is not activation authorization.

**Goal:** Implement an actual, fail-closed selected-envelope installation, pre-open release and all error-drop states, while every live H2 group prepare remains rejected.

**Architecture:** One pure boundary module produces exact ManagedH2Client opening options and finite effective limits. A new group-only Session branch returns sanitized state across prepare→open→bind continuation boundaries; a literal gate denies open. Pure state/result helpers expose the same production transitions to tests.

**Tech Stack:** Existing Elixir/OTP, exact HTTP0.21.10 cohort and accepted ManagedH2Envelope APIs; no new dependency/process.

## Entry, ownership and file map

- [ ] Root confirms current pure group-source acceptance, exact local commit/source identity and independent reviews; preliminary107/0 is insufficient. Preserve fixed HEAD192745a and predecessor failures/counters. Astra2/2 remains exhausted.
- [ ] Adopt companion design as authority; independent SPEC reviewer checks no live path, exact state variants and every error route before implementation. Record a separate boundary-package Sol repair counter starting0 without resetting inherited counters.
- [ ] Freeze current source manifest/diff/untracked inventory and canonical Nix command/toolchain identity. Runtime/build/tests remain root-only; writers preserve each other's edits.

| Ownership | Exact paths |
|---|---|
| Pure implementation/test draft author | create `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_boundary.ex`; create `apps/gaoxy_proxy/test/managed_h2_group_boundary_test.exs` |
| Session author, dependent on pure API | modify `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex`; create `apps/gaoxy_proxy/test/managed_h2_group_session_boundary_test.exs` |
| Root | adopt scoped design/plan/acceptance evidence; integrate patches; run all commands; review fixes; exact local commit |

No changes to HTTP admission, Options, owner, Probe, reservations, deps or fixed projector in this package. No H2 group owner fixture is started by its pure tests. The plan's paths are rooted at `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`.

## Task 1: Pure bridge tests

- [ ] Write the complete new `managed_h2_group_boundary_test.exs` before production implementation. Test absent `Boundary.prepare/4` and `Boundary.activation/0` as intended undefined-function RED; import existing accepted config/Neutral constructors or duplicate only bounded fixtures, never replace a dependency call.
- [ ] Name and implement cases: `selected member creates exact opening options for both H2 protocols`; `raw target and selected raw origin survive preparation`; `selected client origin protocol and transport membership must agree`; `member limits reduce upload without weakening header limits`; `boundary rejects expanded members arbitrary sidecars and noncompact retained inputs`; `all opening deadlines and effective limits are finite`; `activation stays accounting not ready`.
- [ ] For both TLS-H2 and h2c, pure checked-client fixture uses accepted policy constructor and exact supported Fetch options, with opaque scope shell. Mark it shape-only; it is never submitted. Assert exact opening seven keys, exact effective five limits, selected URL/target/protocol, unchanged fields/order/body mode, no selected/Neutral/context/identity sidecars. Assert pure function returns no full config.
- [ ] Reject H1/H3/mixed marker/extra H keys, duplicate/out-of-order transport list, foreign selected transport, bad scalar/id/backing/path, expanded member health counters, wrong checked profile/origin, extra checked keys, bignum/signed overflow/deadline expiry. Enforce complete flattened manifest bound using existing public contract, without adopting unproved H/E/control caps.
- [ ] Root records intended RED with exact source hashes, count/exit/runtime; no build/environment failure is accepted as intended RED.

Run:
```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test apps/gaoxy_proxy/test/managed_h2_group_boundary_test.exs --warnings-as-errors --max-cases 1 --seed 33012
```
Expected: executed tests fail for missing boundary functions. Command NOT RUN by this plan author.

## Task 2: Implement pure boundary and permanent gate

- [ ] Add exactly `prepare/4` and `activation/0` public internal API, with private exact clauses. No runtime reads, module-global configuration, callbacks, side effects or generic recursive serialization. Reuse Envelope validators/preparation; no copied H2 grammar implementation.
- [ ] Implement finite context/group/selected/profile checks, effective-limit minimum, selected transport inclusion, canonical authority equality and original raw-root URL assembly. Clamp only upload to selected effective chunk; enforce original source and effective header/body contracts through accepted Envelope.prepare_group_request. Check signed arithmetic before subtraction/addition.
- [ ] Make gate immutable in code:
```elixir
@doc false
def activation, do: {:error, :accounting_not_ready}
```
No alternate clause/configuration/test bypass. Map denial to the existing finite unavailable public reason at Session, while evidence retains accounting-not-ready disposition.
- [ ] Root runs Task1 command and complete accepted pure source/envelope tests. Require nonzero executed, zero failures/skips/exclusions. Keep results scoped as pure boundary contracts.

## Task 3: Pure Session transition regression before implementation

- [ ] Create `managed_h2_group_session_boundary_test.exs` with calls to proposed internal `Session.prepare_group_open/3` and `Session.drop_group_opening/1`; tests construct exact Session maps but start no Session/owner/timer/client. `prepare_group_open(state, selected, now)` reads Neutral and checked client already in state, invokes Boundary.prepare and returns `{state, continuation}` or finite error/sanitized state. These are the same functions the actual callback branch uses.
- [ ] Assert prepare success stores only `{:group_prepared, options}`, config `%{limits: effective}`, client ManagedH2Client, managed_path=true, nil selector/awaiting/handoff/managed_transport, unchanged selection/transport_selection/pins and original handles. Deliberately place recognizable source/config/K sentinel structures only in valid bounded fields; prove none survive outside exact prepared options.
- [ ] Assert errors and drop helper preserve exact original request/completion, transport/group tokens and pins, service cleanup token, cancellation flags and finite limits. They remove Neutral/envelope/tagged options, selected config, managed transport and submitted_url. Running drop twice is idempotent. Fixed and H1/H3 states are rejected/no-op by explicit group clause and must not be transformed.
- [ ] Add pure opening-result transition tests without invoking open: success moves only URL and original handle into bind state; ordinary error, cleanup-unconfirmed error and bind failure sanitize state without refund or fake completion. The result helper introduced by Session author has one fixed name `group_open_result/3` and returns tagged decisions consumed by actual callbacks; tests assert exact tags/fields for each design failure case.
- [ ] Keep unit tests on returned options and production state transitions. Add no AST or source-text tests. Assign gate dominance, exact continuation dispatch, no caller-flag bypass/public-message route, transport-first bind, no replay and unchanged Options/HTTP/Probe source to independent CODE review in Task5.
- [ ] Root captures intended missing-helper RED using the complete new file, no tags/exclusions.

Run:
```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test apps/gaoxy_proxy/test/managed_h2_group_session_boundary_test.exs --warnings-as-errors --max-cases 1 --seed 33012
```

## Task 4: Guarded actual Session installation/drop path

- [ ] Add the three internal pure helper entry points tested above. Do not expose a runtime test adapter or user-configurable open function. Keep existing Session top-level key set so fixed projector does not change.
- [ ] Add specific H2 selected-config group clause before generic open_selected. Validate proposed H profile only as shape; current real H1 handle never enters it. No marker/tag is owner authority. Invalid H2 group input must fail in this clause rather than fall through to generic open. The group classification sets stable client=ManagedH2Client/managed_path=true before normalized group cleanup; do not mutate legacy state. Use pure prepare, exact reduced config/tagged options, and return `{:noreply, staged, {:continue, :group_open}}`. Preserve selected identity before URI rewriting: add a specific group H2 checkout return clause based on selected config protocol/client, not old state.client. Generic H1/fixed checkout behavior remains unchanged.
- [ ] Implement `handle_continue(:group_open, ...)`: ensure exact prepared group variant, recompute finite remaining time, check cancellation/deadline and immutable activation. In this package gate always denies; call sanitized finite failure path. Include future success/open result code behind the gate with no bypass. Annotate source that live replacement requires R-GROUP-ACCOUNTING plus Probe/admission gates, not a comment promising an accepted reserve.
- [ ] Implement group_open_result success as pure state update and bind decision: request/original_request same handle; submitted_url from envelope; clear tagged options/K; return `:group_bind`. Keep old/new transition roots explicit in subsequent accounting inventory.
- [ ] Implement `handle_continue(:group_bind, ...)` using unchanged bind/cleanup operations. On both bind failures, sanitize URL/opening payloads before fail; success notifies ready only after both binds. No selected config or checked client is needed for bind/cleanup; retain only tokens/pins/original completion/client/limits.
- [ ] Route all group opening preparation/validation/pin/checkout/cancellation/expiry/open/bind errors through drop helper before returning cleanup state. Do not erase tokens/pins to make tests pass. Preserve cleanup-unconfirmed hold/stop semantics and existing finite health classification. Leave fixed release_opening_payloads helper unchanged.
- [ ] Before any future gate removal, implement explicit finite queued cancellation/DOWN inspection for handle_continue pre-open ordering. Record this as activation dependency, not passed by pure package. No third Astra recovery; ordinary failures enter Sol diagnosis.
- [ ] Root reruns Task1+Task3 files and accepted pure source/envelope files on integrated source. Record source and test hashes, counts and exits.

## Task 5: Independent review, fresh gates, local commit

- [ ] Independent SPEC reviewer (not writer) checks every design shape/result/failure/identity and package exclusion. Independent CODE reviewer checks actual gate dominance, internal continuation dispatch, absence of caller-flag/public-message/test bypasses, legacy clause dispatch, transport-first bind, no replay, exact payload stripping and no lost original completion. This source review replaces brittle AST/source-text unit tests. Resolve actionable findings without weakening assertions.
- [ ] Root runs scoped format on the four task-owned files, forced warnings-as-errors compile, then these complete pure contract files without filters:
```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test apps/gaoxy_proxy/test/managed_h2_group_boundary_test.exs apps/gaoxy_proxy/test/managed_h2_group_session_boundary_test.exs apps/gaoxy_proxy/test/managed_h2_group_source_test.exs apps/gaoxy_proxy/test/managed_h2_envelope_test.exs apps/gaoxy_proxy/test/managed_h2_activation_reservation_test.exs apps/gaoxy_proxy/test/managed_h2_reservation_test.exs apps/gaoxy_proxy/test/managed_h2_preparation_test.exs --warnings-as-errors --max-cases 1 --seed 33012
```
- [ ] Because Session dispatch changed, run existing scoped fixed lifecycle/write/release/control suites and upstream H1 transport proxy/probe compatibility files required by the parent manifest. Do not guess a reduced acceptance count; record real executed counts. Any unrelated failure remains separately visible and is not silently repaired. Broader predecessor network/browser requalification is not claimed from pure tests; parent records whether required by actual changed reachable clauses.
- [ ] Update per-phase root inventory from implementation lines. Bind canonical Elixir/OTP source identity; retain startup four-root transfer and no-persistent-temporary-supervisor-args observations as explicit later accounting obligations; add no detached validators or constructor tests here. Keep final Q/C/K maxima UNKNOWN until complete request/probe/recovery paths and maximizers exist. No 9/8/4 or2MiB adoption.
- [ ] Record statuses: boundary code/pure tests/review PASS only when true; R-GROUP-ACCOUNTING ACCOUNTING_NOT_READY; live group/Probe/network/browser NOT RUN; Options/prepare still reject H2. Stage only four task-owned paths and adopted scoped docs/evidence; local conventional commit `feat(proxy): stage managed H2 group opening boundaries`. No push/release/deploy.

## Task 6: Automatic successor after this package passes

Implement protocol-aware Probe boundary and exact owner→Probe/recovery transfer wiring while Options stays H1-only. Add transfer constructors/validators and tests only alongside these actual consumers, using the observed separate normal/recovery schemas preserved in the design. Narrow H2 normal member before child construction; reserve remains unavailable, so no H2 child can claim/open. Probe preparation uses accepted selected envelope/HEAD body-none, same checked identity, same staged drop and H2 URL callback; bind original completion transport-first then group-probe. Recovery helper uses original public completion only; actual completion confirmation precedes transport finish/pins/probe_finished/refund. Tests-first pure transfer/drop plus actual source routing precedes full request/probe/recovery phase bundle measurements. Then independently qualify accounting, implement real admission/probe reserve, remove immutable gate in an explicit activation patch, and execute existing group peer/browser/lifecycle acceptance. This sequence advances bounded implementation without a proposal-only loop.

Stop this boundary package once scoped gates/reviews and local commit complete; do not report full groups/probes or accounting acceptance. Continuing authorization permits automatic execution of the next bounded package with its own written design/plan and review.
