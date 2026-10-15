# Managed H2 group Probe and owner transfer boundary implementation plan — draft version1

> Root owns repository/index/runtime/evidence writes and execution routing. Source-only authors write assigned /tmp drafts and preserve all concurrent work. Use the already authorized parent-managed Sol workflow; no third Astra or autonomous author delegation. This plan is DRAFT_ONLY and has no implementation entry until the predecessor is completely accepted and committed and this adopted package passes independent SPEC.

**Goal:** Narrow actual Probe starts and wire pure normal/recovery and guarded H2 open/drop/result paths into real owner/Probe consumers while H2 Options and activation stay unavailable.

**Architecture:** Two existing production modules, five internal pure exports and one H2-only claim facade. Legacy args6/state18, H2 args7/state23 and recovery args4/state5 remain distinct. Reuse Boundary.prepare/activation and public completion/client APIs; no new process, dependency, reserve or detached schema framework.

**Tech stack:** Existing Elixir/OTP, current pinned HTTP0.21.10 cohort, accepted source foundation and accepted group opening boundary. Root rechecks exact predecessor/source hashes before entry.

## Task0: Establish entry and exclusive ownership

- [ ] Record actual predecessor acceptance, independent SPEC/CODE/fresh gates and local commit, current HEAD/diff/untracked files and complete cumulative counters. Do not reuse historical HEAD73ddf628 as proof of completed predecessor.
- [ ] Adopt/freeze design/plan/decision and actual owner/Probe/Boundary/client/Options/dependency-lock source identities. Preserve prior drafts/failures unchanged. Record DRAFT=>ADOPTED only after predecessor acceptance.
- [ ] Independent SPEC reviewer checks all seven-key H2 startup implications, normal/recovery separation, original deadline/completion, source consumers, no reserve/H1 fallback, full owner-record equality and future recovery-order unknown. Resolve findings in revised versioned artifacts; no tests or implementation before SPEC PASS.
- [ ] Assign Owner author upstream_groups.ex + managed_h2_group_probe_arguments_test.exs; Probe author probe.ex + managed_h2_group_probe_boundary_test.exs. Freeze exact design APIs first. Root integrates only task-owned paths; no shared source writers or runtime commands.

## Task1: Tests-first owner constructors

Create only `apps/gaoxy_proxy/test/managed_h2_group_probe_arguments_test.exs`. Calls to missing pure helpers use apply(UpstreamGroups, function, args), so UndefinedFunction warnings cannot replace actual missing-function RED. No source-text/AST assertions.

- [ ] Write complete tests for `probe_start_arguments/1`: H1 exact6 versus H2 exact7 keys; exact Selected3 keys; all missing/extra/struct/arbitrary payload cases; full expanded member rejected, because owner must narrow before args construction; both H2 protocols; proper unique T order permutations accepted, duplicates/invalid/nonmembers reject; compact ids/path/URL and actual/raw/advertised URL limits; exact health7 values and finite caps; owner===H.owner coherence; signed64/headroom checks. H1 inputs retain existing accepted values/behavior rather than acquiring H2 backing restrictions.
- [ ] Write complete tests for `probe_recovery_arguments/1`: exact4 keys, both kinds and reference token; original completion strict identity using supported public-shaped opaque fixture; signed64 deadline retained including an expired deadline (constructor does not suppress initial abort attempt); omitted/extra/member/H/client/url/health fields reject; invalid shell rejected without traversing arbitrary interiors; no clock/await runtime test.
- [ ] Root runs the complete new file, captures source/environment/count/exit and verifies intended missing-function RED with nonzero tests and zero skips/exclusions:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test apps/gaoxy_proxy/test/managed_h2_group_probe_arguments_test.exs --warnings-as-errors --max-cases 1 --seed 33013
```

Expected: missing pure helpers, not syntax/fixture/compilation errors. Preserve the receipt before production authoring.

## Task2: Tests-first Probe transformations

Create only `apps/gaoxy_proxy/test/managed_h2_group_probe_boundary_test.exs`; use apply(Probe, :prepare_group_open, [state,instance,now]) and matching dynamic calls for the other missing functions. Fixtures model exact internal states and supported public handles only, not live authority.

- [ ] Test `prepare_group_open/3` with protocols http2/h2c; exact23-key initial H2 state and staged key set; exact Neutral HEAD/fields[]/none/upload1/request limits; Boundary options7 and returned limits5; matching H/owner/member/URL/T/selection/request-pin aliases; mismatches and malformed shapes; inherited absolute launch deadline with opening_deadline identical; one remaining millisecond versus expired/overflow; no now-based renewal; same timer/monitor/pins/token untouched.
- [ ] Test `drop_group_opening/1`: exact identity for legacy H1 normal18/recovery5; H2 idempotence before/after stage/bind; clears member/group/health/url/options/K/submitted_url, preserves stable client/finite limits or nil, handles and original completion, tokens/pins/deadlines/cancellation/outcome. No arbitrary malformed payload retained.
- [ ] Test `group_open_result/3`: original public handle strict identity in request/original_request, stream=nil accepted and HEAD upload=nil; URL provenance; options/K dropped; late success retains original before cancellation/deadline error; invalid handle never retained; impossible nonnil upload retains valid original handle but returns cleanup-unconfirmed invalid_response; raw atom/tuple cleanup-unconfirmed distinguished before normalization; unknown diagnostics bounded to finite enum; ordinary failure drops and preserves ledgers.
- [ ] Root captures complete new-file intended missing-function RED before Probe production authoring:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test apps/gaoxy_proxy/test/managed_h2_group_probe_boundary_test.exs --warnings-as-errors --max-cases 1 --seed 33013
```

No owner/Probe processes, supervisor, timers, pins/checkout/open/Fetch/await, network/browser, fake adapters, AST or source-text tests.

## Task3: Actual owner producer and claim wiring

Modify only `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex` after root confirms Task1 RED.

- [ ] Add the two pure constructors exactly from design. Normal validates originals, accepts only Selected3 and args6/args7 according to protocol/profile, preserves legacy values and applies compact/finite H2 rules. Recovery accepts args4, returns original completion/deadline unchanged and adds no runtime state. Constructor failures return only :invalid_probe_arguments.
- [ ] In launch_probes classify H2 intent before legacy reserve; take member3 BEFORE args construction; compute H2 budget/deadline from one original owner now and min health/member opening/lifetime with signed/headroom checks; construct H2 args7 including actual group.handle. Check constructor then literal Boundary.activation and return unchanged owner state on denial, with no H1 reserve, Probe start, health mutation or token/bytes charge. Do not provide a zero-reserve future branch.
- [ ] Keep H1 launch through current URL/reserve/capacity/start logic using narrow member3 and pure args6 constructor. Existing private counters, ordering, fairness, jitter and outcomes stay local and unchanged. Constructor failure follows existing no-start behavior.
- [ ] In recover keep current deadline computation and original held.completion; pass exact args4 through recovery constructor immediately before start_child. Preserve retries/outcomes/original holds and existing startup failure lifecycle behavior.
- [ ] Add H2-only claim_probe/4 and its exact `{:claim_probe,token,H,deadline}` owner clause. Validate actual token/caller/monitor/one-use/live-instance/active-group and exact original deadline; compare H to stored group.handle in full, owner/epoch/key/generation/profile coherent. Return existing instance scalar; no public H2 compile/prepare/token creation. Keep claim_probe/3 and old H1 clauses unchanged.
- [ ] Root runs complete argument file plus existing pure Boundary/source/envelope cases. A source manual review must confirm the real producer calls constructors before start_child and early denial precedes wrong reserve. Shape helper tests alone are insufficient.

## Task4: Actual Probe H2 callbacks, state release and client routing

Modify only `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/probe.ex` after root confirms Task2 RED and constructor API is integrated.

- [ ] Normal/recovery init consume actual owner pure constructors before monitors/timers. Keep recovery exactly args4+owner_monitor and current :recover/await semantics; H1 normal18 unchanged; H2 normal23 adds only client/limits/request_options/submitted_url to args7+existing controls. Do not invent retained instance/member/config sidecars.
- [ ] Add H2-specific open dispatch before transport:nil/generic H1 clauses. Existing opening_allowed then literal activation denies before any claim/endpoint/pin/checkout. The future-enabled branch uses claim_probe/4 exact H/original deadline, selected protocol/raw origin/instance endpoint validation and current pin/checkout ordering, with cancellation checks after waits. Invalid H2 intent never falls back to legacy open.
- [ ] Implement pure prepare/drop helpers from design. Build validated HEAD Neutral from original compact health.path; enforce original URL/root coherence; clamp endpoint limits by health timeout; call accepted Boundary.prepare with exact context6 and absolute deadline for both deadlines. Return staged continuation with only tagged options/finite limits and payload aliases cleared. Preserve timers and original absolute budgets; no timer renewal.
- [ ] Actual :group_open checks opening_allowed and fresh remaining time, updates only remaining intervals, calls literal activation before ManagedH2Client.open. Current denial drops and settles cancelled. Future open result flows through actual pure result helper; no test bypass or replacement client.
- [ ] Implement result helper and :group_bind. Capture supported original handle before deadline/cancel errors; HEAD upload must be nil; invalid success/cleanup-unconfirmed fail closed with finite discriminator. Bind original completion transport-first then group. Retain both ledgers/original handle on errors. No probe_finished/refund while cleanup is unconfirmed.
- [ ] Route H2 poll/event via transient {request,submitted_url}; subscribe on public handle. Clear residual URL after accepted headers and on terminal/error paths. H2 cleanup always uses original_request based on stable client, even after K drop. Preserve normal finish order original cleanup→transport finish→pins release→probe_finished and existing H1 dispatch/cleanup.
- [ ] Recovery await and recovered owner handlers keep existing semantics. Do not add H/client/transport selection to args4, reconstruct completion or assert strict recovery transport/group release ordering. Record the ordering unknown explicitly as future accounting/activation work.
- [ ] Root runs both complete new files and the accepted related pure files; no filters/skips/exclusions:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test apps/gaoxy_proxy/test/managed_h2_group_probe_arguments_test.exs apps/gaoxy_proxy/test/managed_h2_group_probe_boundary_test.exs apps/gaoxy_proxy/test/managed_h2_group_boundary_test.exs apps/gaoxy_proxy/test/managed_h2_group_session_boundary_test.exs apps/gaoxy_proxy/test/managed_h2_group_source_test.exs apps/gaoxy_proxy/test/managed_h2_envelope_test.exs --warnings-as-errors --max-cases 1 --seed 33013
```

## Task5: Independent CODE, fresh verification and local commit

- [ ] Independent CODE reviewer reads actual owner/Probe source and constructors/callback consumers. Verify narrow member precedes args/start, H2 seventh H key and claim transfer are explicit, producer denial before H1 reserve/start, Probe denial before checkout/open, full owner-record equality, H1/recovery dispatch intact, exact current controls, no hidden sidecar, original deadline/handle, phase-specific cleanup discrimination, URL/client routing and normal bind/finish order. Source review rather than source-text unit tests establishes these routing properties.
- [ ] Resolve actionable findings without weakening assertions. Preserve all RED/failed review/compile/test evidence and cumulative counters. No third Astra; root chooses authorized bounded Sol repairs within inherited routing rules and reports genuine blockers explicitly.
- [ ] Root runs fresh task-owned format check and forced strict compile over current exact source:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix format --check-formatted apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/probe.ex apps/gaoxy_proxy/test/managed_h2_group_probe_arguments_test.exs apps/gaoxy_proxy/test/managed_h2_group_probe_boundary_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --force --warnings-as-errors
```

- [ ] Rerun the complete Task4 pure command after final changes. Then run required existing real H1 compatibility files unmodified, using their real peers and bounded synchronization:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test apps/gaoxy_proxy/test/upstream_group_probe_test.exs apps/gaoxy_proxy/test/upstream_group_transport_probe_test.exs apps/gaoxy_proxy/test/upstream_group_transport_test.exs apps/gaoxy_proxy/test/upstream_groups_test.exs apps/gaoxy_proxy/test/upstream_group_transport_proxy_test.exs apps/gaoxy_proxy/test/upstream_group_member_limits_test.exs --warnings-as-errors --max-cases 1 --seed 33013
```

- [ ] Record exact command/source/runtime identity/nonzero executed counts/exits and no skips/exclusions. Relevant implementation failures enter diagnosis; unrelated failures remain visible and are not repaired outside scope. Environment blocks remain BLOCKED/NOT RUN; no gate promoted to PASS by inference.
- [ ] Root updates scoped source-linked inventory/documentation with actual args6/args7/state18/state23 and args4/state5, real generated child spec and complete GenServer/from/reply wrappers; four startup semantic roots for normal/recovery, added H in each relevant H2 root and claim transfer, retained failed-child/owner recovery overlap, payload release boundaries and unchanged opaque completion. Canonical executable/source binding and maximal aggregate accounting remain separate later gates.
- [ ] After independent SPEC/CODE and all fresh scoped gates pass, root stages only four task code/test files plus adopted scoped docs/evidence and makes one local conventional commit: `feat(proxy): stage managed H2 group probe boundaries`. No push/release/deploy. Record ACCOUNTING_NOT_READY and literal denial; H2 network/browser/real protocol acceptance NOT RUN. No inferred strict cross-owner recovery ordering.

## Next dependency after this package

Use the now concrete request/Probe/owner/recovery source to complete source-linked aggregate accounting, canonical startup-source binding and cross-owner recovery ordering analysis before admission/reserve and any separately reviewed gate removal. Keep Options H1-only throughout this package; do not add a detached ledger first or broaden into the later H2 network stage. The current fixed reserve stays9444956;9Q/8C/4K,2097152 and11542108 remain unproved and unadopted. All commands above are execution instructions, NOT RUN by this draft author.
