# M3 managed H2 group source foundation implementation plan

> Execute with subagent-driven development, explicit ownership and independent SPEC then CODE. Continuing authorization selects the recommended approach without routine approval.

**Goal:** Complete a pure, bounded origin-neutral source and selected-member H2 envelope constructor without enabling groups/probes.

**Architecture:** Add three functions to existing ManagedH2Envelope, reusing its finite validators and fixed prepare/2. Root applies all changes and runs all commands. Source-only agents may draft a test patch in /tmp. Tech stack and seven-package HTTP0.21.10 lock remain unchanged.

## Task 1 — freeze design and pure test contract

- [x] Confirm accepted fixed commit bbbc50d, actual evidence5516ea1, preserved prompts and current scoped diff. Adopt the companion design and obtain independent non-live readiness SPEC. Record this stage evidence path/source identities/counters. No new runtime actor is allowed by this gate.
- [x] Write `apps/gaoxy_proxy/test/managed_h2_group_source_test.exs` first. Use dynamic apply for the missing new functions so strict compilation does not replace intended assertion RED with a warning. Test all exact API return shapes defined by the design.
- [x] Include named behavioral cases: `origin-neutral source preserves raw target`; `source rejects unknown shapes before serialization`; `source validates all fixed scalar ranges`; `source rejects malformed target grammar`; `source bounds complete proper fields`; `logical source bounds are inclusive`; `backing limits precede compact copies`; `retained validation rejects noncompact fields`; `maximum complete neutral value fits the existing request slot`; `selected TLS H2 and h2c use their actual origin`; `selected request preserves escapes double slash and empty query`; `selected assembly bounds origin and joined URL`; `selected envelope still rejects forbidden fields`; `selected envelope keeps effective pseudoheader limits`; `selected upload limit remains member-specific`; `fixed activation accounting and public preparation remain unchanged`.
- [x] Root runs the new file alone with the canonical command below; preserve actual nonzero missing-function RED, full output/exit and source-before/after. Fixture/compilation/environment failures require diagnosis and are not intended RED.

## Task 2 — implement the minimal pure source

- [x] Edit only `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex`. Add prepare_group_source/1 and validate_group_source/1 using one private exact schema validator, existing bounded_binary/pairs/body_mode/request_limits/url_text helpers, then compact the admitted target/pairs. Add finite fallback clauses.
- [x] Add prepare_group_request/2: validate retained source and config; render raw root as validated config.uri.scheme <> "://" <> config.uri.authority (preserve raw port text; no URI.to_string canonicalization); check root<=8192 and total<=65536 before compact concatenation; construct exact seven-key map and call prepare/2. Map all failure branches to invalid_request. Do not use synthetic origins, URI.merge, group owner calls, Fetch or reservations.
- [x] Run GREEN on new file plus the four exact compatibility files below. Diagnose failures while preserving assertions and records. Any repair consumes a separately recorded source-foundation Sol round; never start third Astra recovery.
- [x] Run scoped formatter for the two owned Elixir files, then strict compile. Capture an exact candidate manifest with the two source hashes, this design/plan/acceptance, dependency hashes and complete commands. Preserve predecessor historical evidence; do not overwrite it.

## Task 3 — independent review and fresh final gates

- [x] Complete independent SPEC review for all source, tests, grammar/backing/ETF semantics and non-live boundary. Only after SPEC PASS obtain independent CODE review of the same candidate. Resolve actionable findings and re-freeze/re-review affected candidate; no source/runtime overlap.
- [x] Root runs fresh scoped format check, forced strict compile and complete five-file tests against unchanged reviewed source. Require nonzero executed tests and zero failures/skips/exclusions, exit0 and source hashes stable. Audit the actual log and receipts; previous GREEN is not the fresh gate.

Canonical Mix prefix from this worktree is `nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix`. Commands use argv arrays and finite parent deadlines; no global toolchain/account/repository setting changes.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test apps/gaoxy_proxy/test/managed_h2_group_source_test.exs --warnings-as-errors --max-cases 1 --seed 33012
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test apps/gaoxy_proxy/test/managed_h2_group_source_test.exs apps/gaoxy_proxy/test/managed_h2_envelope_test.exs apps/gaoxy_proxy/test/managed_h2_activation_reservation_test.exs apps/gaoxy_proxy/test/managed_h2_reservation_test.exs apps/gaoxy_proxy/test/managed_h2_preparation_test.exs --warnings-as-errors --max-cases 1 --seed 33012
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix format --check-formatted apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex apps/gaoxy_proxy/test/managed_h2_group_source_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --warnings-as-errors --force
```

## Task 4 — local closure and successor

- [x] Update the acceptance ledger with actual counts/exits/identities and review hashes, preserve RED/FAIL and counters, then obtain any needed documentation-only closure review. Check raw evidence bytes against actual staged blobs. Stage only owned paths and make local `feat(proxy): prepare bounded managed H2 group sources` with no generated/co-author trailer.
- [x] Record actual commit/tree and source identity. Advance to the closed group-control/startup/recovery ledger and boundary-enforcement design. R-GROUP-ACCOUNTING and live group/probe activation remain NOT_RUN/ACCOUNTING_NOT_READY until those separate prerequisites and required real peer/browser gates pass. This pure package does not claim full M3, live groups, sustained load, hosted CI, publication or production acceptance.

## Preserved implementation review repair1

Complete SPEC1 rejected the first implementation candidate for missing the feasible joined65536 acceptance regression. The existing raw8192 origin uses zero-prefixed443, while selected effective authority is canonical; target57344 therefore fits the unchanged effective-head limits. Seven additive setup/assertion lines now prove successful URL65536 and retain the original65537 rejection. Full107/0 GREEN, scoped format and forced strict compile passed again; production bytes are unchanged. Failed SPEC1 and all earlier receipts remain immutable. Source-foundation repairSol1/failedSPEC1, unsuccessfulGREEN0, custody/harness failure1 and intendedRED1 are separate counters; Astra2/2 remains exhausted. Complete re-SPEC2 then CODE1 and fresh format/forced strict compile/107 tests passed; zero failures/skips/exclusions and all33 source identities remained stable. Source is committed locally at `060f92641ae12345b7121e220549222418a40b0e`.

## Local closure and continuing successor

The feature commit is `060f92641ae12345b7121e220549222418a40b0e`, tree `515f56e2b412ea499fe162e14746af506e6e2e10`. The raw-index audit authenticated63 original staged files and484475 bytes with zero mismatches; its new audit output was separately byte-checked and all64 paths verified against the actual commit. The actual closure receipt preserves the accepted candidate/review/fresh-gate identities. Original custody failure, intendedRED, failedSPEC1 and repairSol1 remain retained.

The next group opening-boundary design is in independent readiness/repair under continuing authorization. This advances the real selected-envelope install/pre-Fetch/error-release work; no new group reserve or live Options/Probe admission is accepted. Later complete startup/recovery accounting and real peer/browser gates remain prerequisites to activation. No publication or deployment follows from this local commit.
