# M3 H1 B21 TLS connecting implementation plan

> **For agentic workers:** Execute the implementation steps in order after parent
> admission and independent specification review. Preserve the existing fixture
> assertions and every original public handle. Parent owns delegation and review.

**Goal:** Run exactly one separately admitted B21 proving two TLS handshakes in
progress, a third connection rejected at C2, and genuine public cleanup uncertainty.

**Architecture:** Extend the existing H1 fixture's selected invocation and fixed
ledger slots. Reuse its Python peer's `tls-clienthello` mode and public managed
transport/completion APIs; no dependency or product adapter changes.

**Tech stack:** Elixir/OTP, published HTTP cohort 0.21.3, existing Python standard
library peer, SHA-256-bound parent TLS95 receipts.

Date: 2026-10-11 Asia/Shanghai. Task `h1_b21_implementation`, direct Sol design
assignment; worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, parent-supplied HEAD
`85c2284a035e0b4ecbf577279eee01142702b5a3`. No Git operation verifies this HEAD in
this design turn. Sole writing ownership is this new document. Other writers and
all existing TLS inputs remain untouched.

H1 counters remain Sol2/unsuccessful2/Astra1; TLS counters remain
Sol4/unsuccessful2/Astra2. This design runs no VM, test, peer, network or Git and
increments no repair counter. Parent reports actual supplemental TLS PASS; this
author does not create its receipts or treat that report as an independently
validated gate. Implementation still requires the parent's gate and independent
review of this document.

## Decision and boundaries

Use the current three fixture files, with no new peer protocol. A separate TLS
fixture would duplicate the ledger, joins and runner; a TLS test in baseline20
would change its required registration/count contract. The chosen extension
selects baseline20 or TLS1 before ExUnit registration; it uses no skip/filter.

The canonical [fixture specification](m3-h1-qualification-fixture.md#b21--separately-admitted-tls-connecting-and-failed-handshake) is the
behavioral contract. Its historical 0.21.2 references are superseded here by the
parent-admitted 0.21.3 candidate: tag commit
`ceecbf2df62ca80c361597c7303f65a153f2ce3c`, tree
`6a44b862e8a09fb2648e48f928e37c20b1c8109a`. Parent owns canonical-document and H1
inventory rebinding after actual qualification; do not edit them during design.

B21 is `PASS_FUNCTIONAL` only. Keep `ACCOUNTING_BLOCKED_INPUT`, native frontier
`unestablished`, occupied launched attempt/generation proof slots and outstanding
native controls. Issue #97's complete numerical/native-control proof still blocks
production managed adapter Tasks4–8, soaks and M4. No operational certificate
issuance, keys, production data, publication or deployment enters this work.

## Exact parent gate envelope

CLI accepts only no flags, `--baseline`, or exactly
`--tls-connecting --tls95-gate <absolute-json-path>` in that order. Gate validation
precedes ExUnit registration, run-identity/result writes, and peer/source allocation.
Missing, stale, malformed or mismatched proof raises a compact
`BLOCKED_TLS95_GATE` with `registered: 0`; it never skips/registers B21.

Parent writes a new receipt with these exact required keys and values. Object
keys are strings; digests are lowercase 64-character SHA-256 hex. `binding_files`
and `artifacts` are nonempty bounded arrays (maximum256 rows each), with unique
absolute regular-file paths. Reject duplicate JSON keys, extra top-level keys,
wrong scalar types, relative paths and unknown status strings. Bound gate bytes
to65536 by reading65537 before decode. Gate fields:

| Key | Exact value or shape |
| --- | --- |
| `schema_version` | integer1 |
| `status` | `PASS_TLS95_SUPPLEMENTAL` |
| `cohort` | `0.21.3` |
| `tag_commit` | `ceecbf2df62ca80c361597c7303f65a153f2ce3c` |
| `tree` | `6a44b862e8a09fb2648e48f928e37c20b1c8109a` |
| `candidate` | `{executed:5, passed:5, failed:0, cleanup_passed:5, exit:0}` |
| `baseline` | `{cohort:"0.21.1", executed:2, passed:0, failed:2, cleanup_passed:2, exit:1, negative_oracle:"EXACT_TLS_REGISTRATION_MISMATCH"}` |
| `registration` | `{tls_h1:{expected:3, baseline_observed:1, candidate_observed:3, handoff:"PASS"}, tls_h2:{expected:4, baseline_observed:2, candidate_observed:4, handoff:"PASS"}}` |
| `identity` | `{source_before_sha256:<digest>, source_after_sha256:<same digest>, loaded_profile_before_sha256:<digest>, loaded_profile_after_sha256:<same digest>, native_profile_before_sha256:<digest>, native_profile_after_sha256:<same digest>}` |
| `reviews` | `{spec:"PASS", code:"PASS", tooling:"PASS"}` |
| `binding_files` | `[{kind:<enum>, path:<absolute>, sha256:<digest>}, ...]` |
| `artifacts` | `[{kind:<enum>, path:<absolute>, sha256:<digest>}, ...]` |
| `root_der` | `{path:<absolute>, sha256:<digest>, bytes:<integer1..65536>, purpose:"DISPOSABLE_TEST_ROOT"}` |

Nested keys shown in the table are literal required JSON keys; do not serialize
Elixir atom names. Binding kinds are `runtime_source`, `loaded_beam`,
`native_binary`, `native_profile`, `fixture_inventory`, `reviewed_input_manifest`.
Artifact kinds are `candidate_log`, `candidate_receipt`, `baseline_log`,
`baseline_receipt`, `source_before`, `source_after`, `loaded_profile_before`,
`loaded_profile_after`, `native_profile_before`, `native_profile_after`,
`spec_review`, `code_review`, `tooling_review`, `qualification_analysis`.
Require every kind, allowing several rows of one kind for separate runs. Parent
analysis binds the five exact candidate IDs from the TLS95 plan and both exact
old inventory IDs, matched assertion inputs, raw case/cleanup records, wrapper
exits and handoff/source provenance. No old result or static containment alone
qualifies any field. Preserve failed preflight runs in analysis; they contribute
zero executed TLS cases, never to the required old2 oracle.

Identity fields are digests of the normalized common identity payloads that the
parent analysis extracts from the hashed raw artifacts, not hashes of whole
before/after receipts containing different timestamps. Parent normalization must
retain `PASS_ORIGINAL_COMPARISONS_AND_MONOTONIC_LOADED_CLOSURE`: every before-loaded
row remains byte-identical in after, and every newly loaded row is independently
validated by the original loaded/disk identity checks. Never normalize by an
arbitrary intersection that could hide a missing or changed before row. The
matched common digest preserves this directed comparison; it does not describe
the expanding raw loaded closure as identical. Every referenced artifact
is hashed from current bytes using a streaming4096-byte reader. The envelope is
parent attestation of semantic extraction; fixture validates exact values,
current hashes, required kinds and current-runtime binding, without reparsing
large raw logs into memory. Require at least one binding per kind and all
runtime source/loaded BEAM/native identities used by the H1 inventory, excluding
H1 fixture-owned files that necessarily change during this implementation.
Compare its current identity against `binding_files`; require the loaded module
MD5/object-code/disk identity checks already performed by `identity/1` as well.
Parent rebinds/reviews the H1 inventory, not the frozen TLS fixture inputs.

Root conversion may use the already published disposable `root.pem` at
`.audit/m3-transport/upstream-0.21.3/tag-source/apps/ex_ssl/test/fixtures/pkix_identity/`.
Parent converts only its public certificate into an owned new `.audit` DER path,
hashes it and records provenance; no new certificate/key is generated. Configure
checks path/type/declared length only. Actual DER bytes are read/hash-checked by
the reserved policy-source actor after G/root reservation, with a65537-byte read
and exact1..65536 length. Do not load DER into the controller or pass filename,
PEM or `cacertfile` to upstream.

## Source-supported observations

Source paths below are relative to
`.audit/m3-transport/upstream-0.21.3/packages/`, the immutable shipped cohort.

| Source | Consequence for B21 |
| --- | --- |
| `http_core/lib/http/transport/ssl.ex:30`, `:91` | TCP is registered before `:ssl.connect`; a returned TLS connect error calls `unconfirmed_setup`/`unconfirmed_tls` then closes TCP. No returned TLS socket supplies TLS-private DOWN proof. |
| `http_core/lib/http/request_lifecycle.ex:330`, `:394` | Tracker forwards uncertainty to Scope; terminal latch is3 when uncertain. Public completion returns genuine `cleanup_unconfirmed`; local lost proof is unnecessary. |
| `http_runtime/lib/http/runtime/dialer.ex:186` | Dial worker marks complete after transport connect and before sending its result/normal exit. This path differs from deliberately killing a worker. |
| `http_runtime/lib/http/managed_transport/scope.ex:83`, `:194`, `:214`, `:383` | C2 counts connector slots; abort closes tracked TCP and cancels tracked request/dial roles. Uncertainty precedes retirement settlement; final public receipt is unconfirmed. |
| `http_fetch/lib/http/request_completion.ex:75`, `:94`, `:109` | Initial await0 consumes its one helper and returns pending while held. Later reserved abort-and-await observes actual terminal uncertainty. |
| `http_runtime/lib/http/managed_transport.ex:163` | Receipt await returns uncertainty from latch3; it is not a public proof that private TLS workers terminated. |

Fixture references: original registration before Promise.await at
`managed_h1_accounting_fixture.exs:972`; request/connect deadlines at`:727`;
retirement deadline at`:1993`; current normal/late result restrictions
at`:1943`, `:2020`, `:3400`; failure cleanup at`:3122`, `:3284`, `:3345`.
Pure policy preparation already supplies HTTPS `verify_peer`, copied `cacerts`,
loopback pin, H1, `:ssl`, C2 and pending0 in
`apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h1_preparation.ex:25`, `:434`, `:447`.
Keep that module unchanged.

Peer `managed_h1_accounting_peer.py:239` already reassembles handshake type1
across record type22, caps65536 wire bytes, emits `head` phase`clienthello`
with length/digest, then waits for its connection-number release without sending
ServerHello/certificate. Parser/grammar remain unchanged. Its `request` for TLS
is connection ID1/2; fixture attempt wire slots are0/1. Never use
`release_peer(ctx, attempt)` or `peer_event(ctx, attempt, ...)` for TLS IDs.

## Concrete implementation steps

### 1. Select one registration branch and validate gate

Files: modify `integration/http_fetch_contract/managed_h1_accounting_fixture.exs`
and `managed_h1_accounting_fixture_test.exs`. Parent rebinds inventory separately.

- [ ] Have `configure!/1` return `:baseline` or `:tls_connecting`, persist the
  selected bounded IDs/validated gate metadata in the existing run identity, and
  choose total20 or1 in `finish!/1`. Baseline remains exact B01–B20. TLS requires
  exact `["B21"]`, total1/failures0/skipped0/excluded0/cases_passed1.
- [ ] In the test module wrap all existing test definitions in the baseline
  branch without editing their bodies or assertions; TLS branch defines one B21
  test. Do not use tags, include/exclude, skip, environment selectors or filters.
- [ ] Enforce suite absolute deadline45000 for TLS versus660000 for baseline;
  leave ExUnit35000, peer35000 and case phases15000/25000/30000 unchanged.
- [ ] Include gate path/digest and selected mode in run identity/result summary;
  preserve actual wrapper exit independently of printed output.

### 2. Reuse peer mode, connection receipts and reserved policy source

Files: modify `managed_h1_accounting_fixture.exs` only. Peer Python unchanged.

- [ ] Add the selected mode to the existing peer-start scalar descriptor. B21
  launches `--mode tls-clienthello`; ready must contain that exact protocol/case.
  B21 origin is `https://127.0.0.1:<ready.port>`; baseline remains HTTP/H1.
- [ ] In the existing peer actor add one fixed tuple of8 connection rows for
  `accepted`, `eof`, `closed` receipts. Validate connection1..8, case and bounded
  shape; retain only compact current fields. Reject duplicate/conflicting receipt
  evidence. Keep128 request rows,64 controls,128 events and4096-byte lines.
- [ ] Support direct scalar connection-ID event queries in `peer_wait/3`; B21
  reads `head` rows1/2 and releases requests1/2 directly with existing `release`.
  Both `accepted` and `head` receipts must bind the same ID. No new command.
- [ ] Add B21 policy-source descriptor `{origin, root_der_metadata}` alongside
  the existing baseline origin descriptor. In that reserved actor read/hash DER,
  then call the existing pure constructor:

  ```elixir
  Preparation.prepare_policy(%{
    origin: origin, connect_address: {127, 0, 0, 1}, trust: [der]
  })
  ```

  Retain policy/manifest using existing roots and drop source/DER by the existing
  tail-frame ACK before its next command. No source actor or root before G.
- [ ] In B21 Fetch only, after original registration ACK and before Promise.await,
  send the already-supported owned gate message:

  ```elixir
  send(caller, {:fixture_gate, token, operation, :original_registered})
  ```

  Reuse `wait_gate/6`, existing source caller/operation and original connect
  deadline. This adds no public operation/helper/actor or arbitrary polling.

### 3. Execute deterministic B21 and retain exact outcomes

File: add `scenario(:b21, ctx)` in `managed_h1_accounting_fixture.exs`.

- [ ] Reserve one G before policy source/open; reserve three distinct attempts
  before their respective capture/Fetch. Prepare empty GETs using current
  `{:standard, nil, :none}`. Launch originals A/B and observe both registration
  ACK gates before any completion await. No HTTP `arm` calls in TLS mode.
- [ ] Wait for accepted IDs1/2 and complete ClientHello heads1/2, each within
  its attempt's original `D_connect`. Require phase`clienthello`, ID agreement,
  length4..65536 and lowercase digest; keep only receipt metadata. Then initial
  completion await0 for each original must return `{:error,:cleanup_pending}`.
  The peer sends no server handshake. These combined observations establish
  connecting; an aggregate snapshot alone cannot establish phase.
- [ ] Launch third, register its originals, obtain exactly
  `{:error,{:transport_scope_capacity,:connections}}`, then original completion
  `:ok`. Drop local source roots without releasing its launched proof credit.
  One snapshot must show connections2/pending0; one `wire_cut` must show total
  accepted connections2. TLS peer's HTTP request counter is0, not2. Retained
  ClientHello IDs must remain exactly1/2; no accepted/head ID3 is allowed.
- [ ] Register one graceful receipt while both peer gates held; consume its
  initial await0 and require `{:error,:cleanup_pending}`. Register one abort
  receipt, preserving the same original retirement deadline. Do not probe abort
  receipt with await0: it can already be unconfirmed, and would consume slot1.
- [ ] Release peer IDs1/2 once with existing controls. Join retained EOF receipts
  and later peer workers; no handshake response is sent. Abort can already reset
  TCP, so record EOF's actual finite phase without claiming EOF caused failure
  or requiring an orderly client-observed close.
- [ ] Collect both source replies using original request deadlines; require
  actual errors, never response success/Promise-await exit. Preserve compact
  public errors as reported; existing SSL/abort branches permit finite
  `:closed`, `:aborted`, `:timeout` and `:request_timeout` (do not infer exact TCP
  reset order). Unexpected error shape is a contract failure with retained
  originals, not arbitrary-term stringify or synthetic substitution.
- [ ] Use each original's one reserved `abort_wait` and require genuine
  `{:error,:cleanup_unconfirmed}`. Consume only receipt wait slot1 on the original
  abort receipt, within original retirement D, and require the same uncertainty.
  Graceful/initial request pending observations stay immutable.
- [ ] Return the asserted oracle: accepted2, ClientHello2, third capacity error,
  no third accept, snapshot connections2/pending0, third completionok, original
  initial completionspending2, terminal completionsunconfirmed2, graceful
  initial receiptpending, abort final receiptunconfirmed, joinsPASS and zero
  native refunds. Per-attempt and per-generation JSONL retains exact originals,
  public/late outcomes and original deadlines; no opaque handles/DER are encoded.

### 4. B21-only uncertainty handling and complete failure cleanup

File: `managed_h1_accounting_fixture.exs`; model and B01–B20 assertions unchanged.

- [ ] Centralize the existing result checks so baseline allows onlyok/pending;
  B21 additionally allows genuine `{:error,:cleanup_unconfirmed}`. Apply the
  exact same restriction to normal completion/retirement and `settle_role`
  late-result paths. Map that tuple to model `:cleanup_unconfirmed` only when
  actually returned. Existing model control result marks uncertainty; do not
  emit `request_completed`, `scope_retired` or `control_frontier_released`.
- [ ] For actual B21 retirement uncertainty record `generation_unconfirmed`;
  retain `retired:false` and separate terminal-unconfirmed evidence. Failure
  cleanup must distinguish terminal public uncertainty from pending, rather
  than requiring `retired:true` or marking uncertainty as confirmed retirement.
- [ ] Before original/scope cleanup release every accepted TLS gate1/2 whose
  release bit is unused, even if failure preceded a ClientHello receipt. The
  current armed-only loop misses TLS gates. Retain baseline armed-only behavior.
  Release at most existing fixed connection gates; do not allocate retry actors.
- [ ] During `cleanup_attempt`, terminal B21 uncertainty satisfies the retained
  expected public-outcome obligation while local actors still require joins.
  If neither terminal result nor unused abort_wait exists, record failure.
  Pending/unknown outcomes are never accepted as terminal. Third remainsok.
- [ ] `cleanup_scope` uses only unused original graceful/abort/wait slots. B21
  requires the recorded terminal-unconfirmed receipt plus all owned actor/peer
  joins; if both receipt waits were already consumed, inspect saved results and
  never call a third wait. Abort/graceful initiations still require original
  receipt registration. A failed primary assertion remainsFAIL even if cleanup
  succeeds. No N8 claim follows from public uncertainty or owned worker EOF.
- [ ] Preserve local root/helper release only after existing actual joins;
  keep uncertain model leases and native controls charged in final artifacts.
  Peer stop must still report accept_jointrue/alive_workers0/exit0, and fixture
  actor shutdown must finish. Forced-owned fallback or missing originalsFAIL.

## Verification and admission checklist

- [x] Static inspection of canonical deadlines, peer parser/control grammar,
  registration ACK order, genuine uncertainty route and model support completed.
- [x] This design creates only its owned document; no executable change/test/run.
- [ ] Parent maps real old2/candidate5 receipts into the exact gate envelope,
  hashes disposable DER and current artifacts, and rebinds H1 source inventory.
- [ ] Independent Sol specification review passes this design and gate schema.
- [ ] Parent admits implementation after validating actual supplemental TLS PASS.
- [ ] Static review confirms identical B01–B20 bodies/assertions, no model or
  dependency diff, no new peer grammar, no extra operation/time budget.
- [ ] Before runtime freeze final fixture/test source and gate hash; invalid
  relative/missing gate is verified to fail with registered0. Preserve failures.
- [ ] Run baseline20 and TLS1 separately through parent-owned sanitized collector
  using existing `h1-accounting-runtime-config.exs` and pinned interpreter/native
  profile. Baseline command suffix is
  `mix run --no-compile --config .audit/m3-transport/h1-accounting-runtime-config.exs integration/http_fetch_contract/managed_h1_accounting_fixture_test.exs --baseline`;
  TLS suffix adds exactly `--tls-connecting --tls95-gate <absolute gate path>`
  in place of `--baseline`, preserving the same started invocation and explicit
  runtime config. Do not add `--no-start`: configure checks loaded application
  versions and the historical passing launch starts them. Parent resolves path then passes structured argv,
  records actual exit0, new run IDs and all source/profile before/after digests.
  B21 internal suite limit remains45000; external wrapper adds no request budget.
- [ ] Baseline result is20/0/skipped0/excluded0, exact B01–B20/joins20; TLS result
  is1/0/skipped0/excluded0, exact B21/joins1. Verify three attempt rows and one
  generation row, each≤4096 bytes, with exact public outcomes and charged proofs.
- [ ] Independent specification/code-quality review passes final source/evidence;
  fresh scoped verification precedes parent's permitted local commit.

If supported public controls cannot achieve required pending/uncertain outcomes,
preserve primary/cleanup/identity logs and report `BLOCKED_CONTRACT` to parent.
Do not replace them with lost fixture proof, inspect/kill/suspend private TLS
workers, add sleeps or retries, weaken C2, extend original deadlines or silently
route around an upstream defect. Counter continuation and recovery routing stay
with parent; this plan does not authorize a third TLS Astra round.
