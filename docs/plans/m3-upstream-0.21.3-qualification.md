# M3 published 0.21.3 and remaining functional qualification

Date: 2026-10-11 Asia/Shanghai. Continuing authorization in `AGENTS.md` applies.
Base: `85c2284a035e0b4ecbf577279eee01142702b5a3`, `.trees/m3-gateway`.

**Goal:** Install the containing parser/cancellation fixes, qualify unchanged
H1 error oracles and complete the remaining independent public functional work.
Full M3 acceptance and managed production activation still require the complete
resource contract; upstream Feature #97 remains a distinct blocker.

**Design:** Keep the existing native server and dedicated H1 production adapter.
Use the seven-package coordinated 0.21.3 release through supported APIs. Preserve
0.21.2 source, failure receipts and reviews. Apply the independently reviewed
B05/B17 amendment: exact source backing copy, and a second pre-reserved late
cleanup observation with the existing cleanup deadline. Keep original D500,
pending result, strict retirement confirmation and operation ceilings. Separate
public functional results from native-frontier/numerical proof.

The recommended route is a published dependency update plus these bounded
fixture repairs. A private dependency patch violates the upstream boundary;
waiting on a released fix would leave independent work unfinished.
The release tag is `ceecbf2df62ca80c361597c7303f65a153f2ce3c`, tree
`6a44b862e8a09fb2648e48f928e37c20b1c8109a`; source/installed verification must
confirm this rather than treating release metadata as qualification.

## 1. Source and dependency gate

Ownership: source worker owns new `upstream-0.21.3` provenance/cache files;
parent owns dependency mutation, command execution and current status docs.

- [x] Download all seven Hex archives/metadata and immutable Git identities;
  verify inner/outer digests, exact coordinated requirements, all shipped
  sources, parser-error retention and untracked cancellation changes.
- [x] Preserve current dirty inputs, 0.21.2 archives and original fixture hashes.
  Change only two direct exact pins and seven lock entries; keep all 17 unrelated
  entries identical. Do not edit `deps/` or update the toolchain.
- [x] Independently check installed bytes against the published archives/tag.
- [x] Strict-compile, canonical-format and execute scoped core/HTTP/proxy/server
  compatibility tests under the existing Nix/OTP profile.

## 2. H1 Slice B recovery and functional gate

Ownership: bounded Astra recovery1 after two unsuccessful Sol fixture rounds,
only the fixture and its test; parent updates canonical plan/inventory first.
The Python peer, model, historical oracles and TLS sources stay preserved.

- [x] Apply the SPEC/CODE-reviewed B05/B17 amendment to the canonical plan.
  Rebind current fixture inventory to 0.21.3; preserve its reviewed original.
- [x] B05 materializes the append-created URL parent with `:binary.copy/1`
  before slicing, keeping exact backing assertions, three rejects/three copies,
  malformed-input checks and zero Fetch.
- [x] B17 slot1 after original pending/D500 waits once on the original abort
  receipt with remaining time to t0+25000. Record original-retirement versus
  late-cleanup purpose/deadline/result separately; assert actual `:ok`, exactly
  one graceful/one abort/two waits, immutable D/pending and all owned joins.
- [x] Adapt cohort identity facts only; B11/B12 keep exact parser errors and
  all twenty original tests. Review implementation SPEC then CODE independently.
- [x] Execute baseline20 with zero skips/exclusions, actual exit0, current-run
  case IDs and all cleanup joins. Retain failure logs and cumulative counters.
  Re-run deterministic ledger-refusal and loaded-code identity regressions.

Commands use `ERL_FLAGS='+S 2:2'`, `MIX_ENV=test` and the existing peer Python:

```sh
nix develop --offline --command unbuffer mix deps.get
nix develop --offline --command unbuffer mix compile --warnings-as-errors
nix develop --offline --command unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy/test apps/gaoxy_http/test apps/gaoxy_proxy/test apps/gaoxy_server/test
nix develop --offline --command unbuffer mix run --no-compile --config .audit/m3-transport/h1-accounting-runtime-config.exs integration/http_fetch_contract/managed_h1_accounting_fixture_test.exs --baseline
```

## 3. TLS supplemental tooling and runtime gate

Ownership: parent/independent Sol. The historical starting counters were
Sol2/unsuccessful2/Astra2; current counters are Sol4/unsuccessful2/Astra2. The
renewed authorization permits necessary local Sol fixes without resetting
counters. No third Astra repair is allowed.

- [x] Diagnose `/memfd:vmem (deleted)` in the existing loaded-identity collector.
  Reproduce its regression; preserve executable file/loaded module assertions.
  Classify anonymous BEAM JIT mappings explicitly without treating them as
  immutable files or omitting file-backed executable/native provenance.
- [x] Add meaningful malformed/path/provenance regressions, apply the smallest
  repair, obtain independent review, and renew actual collector input hashes.
- [x] Run the isolated 0.21.1 negative socket-registration oracle and installed
  0.21.3 positive TLS cases with frozen loaded/native/interpreter identities.
  Claim TLS PASS only for actual registration/handshake/retirement observations.
- [x] B21 remains fail-closed until this supplemental gate passes; then design
  and execute its separately registered TLS-connecting case under the existing
  controlled grammar and original finite deadlines.

Current execution receipts: [installed cohort](../acceptance/evidence/m3/upstream-transport/upstream-0.21.3/installed-cohort-verification.md),
[compatibility486/0](../acceptance/evidence/m3/upstream-transport/upstream-0.21.3/compatibility.json),
[final baseline20](../acceptance/evidence/m3/upstream-transport/upstream-0.21.3/h1-baseline-postb21-current2-analysis.json),
[final B21](../acceptance/evidence/m3/upstream-transport/upstream-0.21.3/h1-b21-current2-analysis.json),
[relative-path gate rejection](../acceptance/evidence/m3/upstream-transport/upstream-0.21.3/h1-b21-gate-relative-negative1-analysis.json)
and [TLS five-case qualification](../acceptance/evidence/m3/upstream-transport/upstream-0.21.3/tls95-supplemental-analysis.json).
The H1 helper grouping repair leaves every function block byte-identical and
removes the compiler warning; counters are Sol3/unsuccessful2/Astra1. TLS remains
Sol4/unsuccessful2/Astra2, with no third Astra recovery. The separately frozen
[eight-case H2 plan](m3-h2-0.21.3-functional-supplement.md) uses an independent
execution receipt; its original design bytes and hard hash remain unchanged.

## 4. Evidence, review and local delivery

- [x] Reconcile current status and conflicting stage rules; preserve historical
  failed/blocked receipts as historical. No ordinary repair-approval pause.
- [x] Complete fresh independent specification and quality review of all owned
  source/docs; fix actionable findings and run affected checks.
- [x] Commit only task-owned changes locally using conventional messages.
- [x] Continue other genuinely unblocked prerequisite work. If #97 still lacks
  the supported complete bound/frontier, record its exact external blocker;
  no managed activation, managed soak or M4 acceptance follows from functional
  PASS. Do not start production Task4–8 while its prerequisites remain open.

Vault, release-artifact E2E, push/publication/deployment, public management and
production-data restrictions remain in force. No new product scope is added.

Execution disposition: [functional qualification and external blocker](../acceptance/evidence/m3/upstream-transport/upstream-0.21.3/execution-receipt.md),
[five expected negative oracles](../acceptance/evidence/m3/upstream-transport/upstream-0.21.3/h2-acquisition-failure-regression-analysis.json)
and [independent H1/H2 review](../acceptance/evidence/m3/upstream-transport/upstream-0.21.3/m3-h1-h2-final-independent-review.md).
The frozen normal H2 plan stays unchanged. All negative VM exits remain1;
negative wrapper post-identity/outcome and loaded-after identity are NOT RUN.
Final affected checks: canonical format, strict compilation and proxy44/0 PASS.

Final delivery review: [SPEC/CODE/docs/evidence PASS, no findings](../acceptance/evidence/m3/upstream-transport/upstream-0.21.3/m3-final-delivery-review.md).
Verified local source commit `bfdd4ab1b557ff01af58670a1902bf7fdb40cf3f` and historical
evidence commit `eb9e87ece318f79617eff0841a8b4058434ad9e1`; current docs/evidence
are delivered by the commit containing [the local receipt](../acceptance/evidence/m3/upstream-transport/upstream-0.21.3/local-delivery.json).
M3 remains BLOCKED on #97; these completed local-delivery tasks do not close
production managed qualification or permit M4.
