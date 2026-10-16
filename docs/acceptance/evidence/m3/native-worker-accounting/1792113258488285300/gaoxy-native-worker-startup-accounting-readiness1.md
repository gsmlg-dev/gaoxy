# Native H2 worker startup accounting readiness review 1

Status: DONE. Assignment: direct independent source-only design/plan readiness review.
Verdict: CONDITIONAL PASS after the two precise canonical wording corrections below and bounded identity/content rebind. No architectural or product decision is outstanding. This is readiness for concrete runtime TDD, not implementation or runtime acceptance.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, baseline `58307a7084298db309a93697b9102b2cc4c87eda`, tree `a038b7d0d24f662a75b9786ee15866957b53abf0`.

## Exact reviewed inputs

- `/tmp/gaoxy-native-worker-startup-accounting-design1.md`: SHA256 `78a2a49d7100c97733c1e05831db746d0ed0e4aeca564a7064aa81370a5e06ef`, 32399 bytes.
- `/tmp/gaoxy-native-worker-startup-accounting-plan1.md`: SHA256 `d100b2e3f48d3f9cec3a67ce7a0f9a62970dad39e4ea04eff0a868ba21b84f58`, 30888 bytes.
- `/tmp/gaoxy-native-worker-startup-accounting-binding1.json`: SHA256 `278c177435e848c0cadd98fb2e11278265d0cc75232fcb787eb50d84e0fac548`, 50324 bytes.

## Actionable findings

### R1 — required_wording_clarification

D positive / positive originalD / Dpositive ambiguously constrain absolute monotonic deadline to D>0. Valid absolute D can be negative. Lifecycle.now uses System.monotonic_time; current Admission validates integer D>now. Locations: `design1.md:84`, `plan1.md:62`, `plan1.md:66`.

Required: Use integer absolute original D with Lifecycle.remaining(D)>0 (equivalently D>Lifecycle.now()) at validation/activation/apply checks; preserve original signed D. Include signed deadline ETF widths and negative live absolute deadline cases in actual-source constructor and lifecycle checks. Never replace D with abs(D), zero-clamp it, or extend it.

Disposition: Accepted clarification; canonical adoption will correct wording and explicitly cover signed ETF arithmetic. Archived draft1/binding bytes remain immutable.

### R2 — editorial_consistency

One explanatory sentence says Public spawn_monitor although normative API/custody blocks require atomic spawn_opt with link+monitor. Locations: `design1.md:86`.

Required: Replace sentence with public atomic spawn_opt(..., [:link,:monitor]); preserve normative atomic link+monitor contract.

Disposition: Accepted canonical correction; no API/design change. Archived draft1 unchanged.

R1 source evidence: `Gaoxy.Lifecycle.now/0`, `deadline/1`, `remaining/1` at lifecycle.ex6-8; existing Admission validation at admission.ex127-138; installed System.monotonic_time documentation at system.ex1222-1244 describes an unspecified origin and integer result. Positive *remaining time* must not be confused with positive *absolute timestamp*. No runtime sampling was needed or performed.

## Coverage

- **minimal_spawn_and_core_boundary**: PASS readiness: public atomic spawn_opt/4; generic core bootstrap; no new dependency, guardian or HTTP/proxy core import; writer remains Task-supervised.
- **authority_alias_and_activation**: PASS readiness: actual parent-lease caller ownership, current token/request-id, private activation ref, committed callback before activation/reply, full improper alias request/reply/check/retirement constructors; finite cancellation and stale-success cleanup.
- **gate_owner_parent_link_custody**: PASS readiness: child link/monitor atomic; trap_exit child isolation; genuine OTP parent EXIT intercept and normal behavior change explicit; explicit unknown-nonparent abnormal-exit stop policy; original owner lease DOWN kills correlated children; same current ordinary lease retained to paired actual EXIT+DOWN; legacy DOWN path preserved.
- **algebra_and_full_operands**: PASS readiness with R1 signed-deadline clarification: complete P+A+J=N,W=N+2head fixed point; original endpoint/request/peer_cert measured; Exchange defaults/__struct__ complete; planned ordered row caps/multiplicity/owners/lifetimes include alias/lease/correlation/bootstrap/monitor/timer/cancel/terminal roles; future local PID/ref caps are source-rebound rather than samples. Numeric per-input actual constructor qualification correctly deferred to required pre-W source checkpoint.
- **pre_effect_and_lifetimes**: PASS readiness: numerical-only preflight before wrappers; tiny scalar queued control exception explicit; no endpoint/Exchange transfer before W; activation secret before endpoint; N retained across updates; current B retained until worker paired EXIT+DOWN; no fixed delta/options cap/private API.
- **test_selection_and_gates**: PASS readiness: behavior RED separated from implementation W; independent actual-source SPEC then CODE before first W execution; pure constructor tag selection; actual Admission barriers; native h2c and real TCP/TLS peer; Chrome negotiated H2 plus visible H1; checked Generation/legacy/H3 compatibility only; isolated core/HTTP consumers; final review then fresh checks/joins/local commit. Tests planned, not executed.

The finalized draft chooses paired admitted-child EXIT/DOWN completion and an explicit unknown non-parent abnormal EXIT stop policy. This supersedes an earlier conversational ignore-all proposal. It satisfies the prior audit condition without extra tombstones/processes: actual OTP parent exits are intercepted, worker exits are isolated, pending and active workers remain in ordinary charged custody, and original-owner normal death explicitly kills correlated children. Source readiness does not infer runtime joins.

The complete intended roles are enumerated now; exact numeric actual-source rows and per-input fixed points remain deliberately gated after implementation and before any changed-W execution. This is acceptable sequencing. It does not permit omitted constructors or sampled maxima at that checkpoint. Full Exchange/default fields match exchange.ex7-32 and existing native constructor; writer supervision and Lifecycle.resources filters are preserved. No #97, physical/global proof or future product scope was introduced.

## Identity, checks and boundaries

Parsed binding1.json and independently rechecked all230 current source hashes,7 qualified installed public sources,11 bound inputs and2 draft outputs: PASS. Source manifest digest `0c5e242d9ca9b0e361b5797e0570aa9352f351e2d305468a00dd1a5548fc58f3`. JSON companion records all identities. Reviewed existing scoped command paths exist; absent bootstrap/calculator/new tests are expressly planned creations. Actual independent Python h2 TCP+TLS execution is selected through existing http2_network_test.exs; real Chrome H2 navigation and H1 visible-page compatibility are required separately.

Parent canonical adoption may rebind proposed candidate1 evidence paths to E5 `docs/acceptance/evidence/m3/native-worker-accounting/1792113258488285300` and canonical docs paths, plus R1/R2 precise corrections. Archived draft1/binding bytes stay untouched. Exact corrected canonical bytes still need the bounded rebind before treating this conditional verdict as unconditional readiness.

No repository edits, Git mutations, project runtime/build/test/network/browser execution occurred. Tracked diff was initially empty. Final check sees concurrent parent adoption: implement-plan.md +2 lines and new canonical design/plan/acceptance docs plus E5 evidence; all230 bound source identities remain unchanged. These parent-owned edits were preserved. All own shell/Python source-validation commands completed; no command sessions or runtime actors remain.

Counters unchanged: group Sol30/root Sol35/Astra2 of2; this review adds0. No Astra gate/escalation. No user decision needed.
