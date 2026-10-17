# Managed H2 Identity Rotation Implementation Plan

> **For agentic workers:** Use subagent-driven-development and executing-plans task by task. Root exclusively writes repository/evidence/Git and executes runtime/build/tests/browser; delegated Sol workers own explicit proposal/review files only. Continuing authorization selects the recommended approach and advances passed gates automatically.

**Goal:** Qualify same-authority TLS trust/numeric-address rotation through real fixed and group checked Generations, including caller-side same-path CA replacement and independent resource retirement.

**Architecture:** Extend the accepted fixed/group Generation fixtures and independent H2 peer; preserve supported compact DER/address APIs and all existing bounds. Fixed and group browser fixtures each execute native H1/H2→TLS-H2, yielding four positive trust rows.

**Tech stack:** Existing Nix Elixir1.18.5/OTP28, HTTP Fetch/Runtime0.21.10, Python `/tmp/gaoxy-m3-h2-soak-venv/bin/python` with h2=4.3.0/hpack=4.1.0/hyperframe=6.1.0, OpenSSL3, Chrome/CDP and Node.

Current qualification — 2026-10-17: **PASS for the managed H2 same-authority identity-rotation slice**. Final fixed6 and group2 each actually passed both native H1/H2→TLS-H2 rows, and root viewed all eight fresh OLD/NEW images. Fixed6 exited0 after32.097s with eight named Actors; group2 exited0 after36.352s with twelve. Every named Actor exited0/nonforced with joined readers and absent groups. Each endpoint recorded eleven genuine adopted waits: nine exit0 and two signal10/-10, with none remaining. Raw wait statuses are preserved.

Candidate9/inventory9 and `fixed-observer-final-adoption1.json` bind415 source pins: prior411 with two active fixed fixture observations updated, plus four reviewed diagnostic/enum inputs. There was no production, test-contract, dependency, Chrome flag, assertion, deadline or cleanup relaxation in this final observer change. Actual outer snapshots were399 for each endpoint, inner287 fixed/286 group, each stable and an exact matching subset of the415 inventory. Root verified48 fixed/54 group artifact hashes,102 loaded module records per row before=after (97 disk BEAM/source hashes and five in-memory fixture source/loaded-MD5 records), request_clean while the native connection remained alive, explicit Chrome.close, original resource retirement, zero accounting, normal owner/custodian/instance joins and listener rebind.

Seven original nonbrowser results and the separate Python startup audit are reused only for unchanged relevant executable inputs; original401-entry receipt maps remain immutable. Scoped counts remain248+217+475=940 invocations/0 failures, isolated core1/0 and HTTP2/0, and Python startup11/0errors/0skips, all reported separately. Active Elixir formatfinal2 and Python/extracted-JavaScript syntaxfinal3 freshly passed after source review/adoption; each is static0 tests. The reviewed diagnostic observations preserve all113 Python assertions and embedded BROWSER bytes. Final source SPEC2→CODE1 passed after resolving the two retained inventory/document-pin findings in SPEC1.

Historical final fixed2/fixed4/fixed5 remain FAIL, not repaired retrospectively. Fixed5 attempted one H2 row/zero PASS and failed its line1535 monitor pid/reason expectation while awaiting old_retired; neither old_retired nor request_clean was reached. Safe metadata records session60/socket55 FINISHED_GOING_AWAY/net_error0 after188-byte DATA and empty END_STREAM. The initiating cause and specific mismatched monitor remain UNKNOWN; this does not prove a wire GOAWAY. Its host exited1 and three named Actors were forced/-15; nine adopted waits remain4exit0/3signal15/1signal9/1signal10, with no residue. Bounded close diagnostic2 and invalidation diagnostic1 each passed two diagnostic rows only as nonreproduction. Those rows are not final rows or a causal/stability guarantee; all safe prefix projections remain explicitly incomplete.

All three TLS denial tests retain the real sticky {:error, :cleanup_unconfirmed} outcome,9444956 reserved bytes and failed_actor_disposal=true, with zero upstream HTTP requests. This is the accepted negative accounting oracle, not normal retirement or a refund claim. `counter-supplement61.json` preserves root221/orchestration134/tooling62/runtime failed-green9/group63, fixture/Sol repair rounds5/production repairs0/Astra2of2 exhausted, plus all inherited categories. Categories are distinct and must not be summed. Counter55 controls the corrected failure-point wording in historical counter54.

The locked environment is qualified: eighteen compressed FileSize/FileHash checks, native exact-eighteen copy (eleven new/seven existing), exact-eighteen trusted-signature/content verification and locked Elixir1.18.5/OTP28/ERTS16.4.0.6 passed. Earlier transfer/readiness/materialization failures remain preserved; client require-sigs/key evidence is not daemon attestation. Final independent result/document review and local disk/index/committed-byte custody close this slice. Postcommit custody is verified in the historical fixed plateau kickoff below; the current successor runtime verification checkpoint follows it; final document/local-commit custody remains separate. Whole Task5/M3 and the other required matrices/load/composition gates remain open; publication, deployment, production/Vault/operational-certificate/public-management/account changes and disabled release-artifact E2E activation remain excluded.

Design: `docs/designs/m3-managed-h2-identity-rotation.md`. Baseline: `8f6b884524d81d8defa7c5081230b8ab635e8107`. Evidence: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/`, specifically `full-stage-candidate9.json`, `final-command-inventory9.json`, `fixed-observer-final-adoption1.json`, `identity-final-format1-final2.json`, `identity-final-syntax1-final3.json`, `fixed-browser-command6-root-audit1.json`, `group-browser-command2-root-audit1.json`, the two final root image-review records and `counter-supplement61.json`. Historical failed/diagnostic/environment receipts and source-count clarifications remain immutable. The immediately preceding pending55 documents are archived as `final60-before-*.txt`; they are historical checkpoints.

## Ownership and files

Root owns the two canonical documents, matching acceptance and evidence, `apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs`, `apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs`, and `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py`. The fixture-defining `managed_h2_fixed_endpoint_test.exs` or existing lifecycle/identity files may receive a necessary bounded test helper/negative-case extension; no production edit is presumed. Preserve existing test cases, assertions, dependency/lock bytes, protected prompts and historical evidence. A new test helper must justify its use; no general fixture refactor.

### Task0: Readiness and frozen baseline

- [x] Verify predecessor feature/document commits, actual tree and38 changed closure paths,402 accepted sources, protected files and clean worktree. Preserve the actual receipt in kickoff1 rather than making another self-referential closure commit.
- [x] Map existing fixed/group/peer/browser seams with independent read-only workers. Keep their original reports and all recovered tooling errors.
- [x] Finish design/plan self-review and exact source/counter manifest. Complete independent readiness SPEC then CODE. Both passed with no findings; original candidate/report hashes are preserved.
- [x] Qualify the actual pinned peer interpreter/packages, Nix/unbuffer, OpenSSL3, Node and Chrome. `environment-preflight1.json` records passing tool prerequisites and0 protocol tests; system Python's absent h2 is an unused-interpreter fact.

### Task1: Bounded concurrent peer identities

- [x] Add explicit loopback address and listen-port options to `managed_h2_fixed_peer.py`, retaining existing default127.0.0.1:0 and existing client `--port` semantics. Constructor/start changes are:

```python
self.bind_address = bind_address
self.listen_port = listen_port
self.listener.bind((self.bind_address, self.listen_port))
```

The CLI accepts only127.0.0.1 through127.0.0.4 and listen-port0..65535; ready reports the actual address/port. No fallback/retry to another authority.
- [x] Use two/four actual peers at one OS-selected port. Assert all numeric socket tuples distinct, all authorities equal and every chain/leaf distinct. Keep finite launch/handshake/process shutdown and actual zero forced/live counters.
- [x] Add bounded caller-side PEM read and same-path replacement helpers inside existing Generation tests. Decode before the supported four-key preparation call:

```elixir
%{protocol: :http2, origin: "https://localhost:#{port}",
  connect_address: address, trust: certificates}
```

Read no more than1,048,577 bytes before PEM decode; reject oversized source. Record old/new public PEM/DER/leaf hashes. Never expose key material.

### Task2: Fixed rotation and rejection witnesses

- [x] Keep the original four fixed standard cells intact; add TLS `:rotated` identity cases for each native downstream. Reuse `candidate/3`, `activate/3`, `capture/4`, `bound/3`, `complete_return/7`, original source release and `finish/3`.
- [x] Prepare OLD from stable PEM, capture before checkout, replace same path, prepare/activate NEW with equal origin and different address/DER, invalidate the path, and dispatch. Assert actual retained policy and distinct resource identities; h2 ALPN/SNI/authority, exact target/bytes and peer counts must match. Both handshakes occur after path replacement.
- [x] Send synthetic old/new Proxy-Authorization values and assert both stripped; any normal Authorization marker must remain confined to its own actual request. No new origin-credential filtering policy.
- [x] Complete NEW while OLD pending; complete OLD but retain source until endpoint return. Preserve original completion/source/custodian/socket ordering and exact all-zero/normal-join/rebind assertions.
- [x] Add three native-H1 fixed TLS denial cases: oldCA/newIP, newCA/oldIP, and wrong hostname/trusted CA. Capture actual original completion at bind, prove finite502/handshake rejection/zero application requests/no fallback or replay. Validate the complete actual confirmed or sticky-unconfirmed accounting branch; preserve failed receipts and separate failed-fixture disposal.
- [x] Prove equal authority does not permit new T to use an old authentic source capture. Refuse before checkout/bind/Fetch/fallback, preserve genuine originals for cleanup, and keep existing unrelated negative assertions unchanged.
- [x] Freeze changed fixture/test sources, complete bounded SPEC→CODE, then run the full defining endpoint plus fixed Generation suites with nonzero counts. Any real failure enters diagnosis and source re-review before another run. No artificial RED is required for qualification of existing behavior; a production fix requires its genuine failing regression.

### Task3: Group rotation and cold identity

- [x] Keep standard group cells/reuse assertions intact; add TLS `:rotated` native-H1/H2 cells using the existing0→1→0 old/new captures and authentic G+[A,B] batches.
- [x] Prepare/complete real health HEADs and original probe completions. Send peer `goaway` with completed HEAD stream and error0. Queue reader-owned public TLS `unwrap` within the original five-second command/180-second peer limits, then actual raw write-half-close before its ACK; await the original real EOF/reset witness within the unchanged physical deadline. No owner/client state mutation or failure normalization.
- [x] Replace per-member stable PEM contents between OLD/NEW preparations at equal authority/common port, invalidate the paths, and CAS while OLD sources remain captured. A dedicated rotation request helper requires a fresh accept/TLS/connection for each first member GET, distinct from its HEAD connection. Further A GETs reuse that fresh connection.
- [x] Assert socket peers each accept2; A has3 requests, B2. Preserve independent G/T original completion, selected children, unselected-B last-source retention, actual resource/custodian joins and final fresh-connection retirement.
- [x] Add equal-authority cross-group negative dispatch with authentic OLD captures and explicit NEW endpoint input; prove finite refusal before selection/delegation/checkout/Fetch, unchanged source pins and no alternate peer request. Preserve existing group TLS negative/lifecycle scope; do not call probe refusal selected forwarding denial.
- [x] Freeze/review complete group changes SPEC→CODE and run unfiltered group/fixed/defining-endpoint suites. Preserve genuine failed evidence and finite deadlines.

### Task4: Four real TLS browser rows

The completed Task4 checkboxes record only the historical initial qualification fixed-browser-green3/group-browser-green1. At the later fixed5 checkpoint, fixed5 failed and group final2 had not run; those historical outcomes remain preserved. Current Task5 final qualification is fixed6/group2: all four actual rows and eight fresh root-viewed images passed under candidate9/inventory9. Initial successful assertions do not substitute for these final results; independent final document review and local commit/advancement custody remain separate closure steps.

- [x] Derive fresh fixed host from accepted `managed-h2-fixed-generation/1792147726386855423/fixed-generation-browser-host3.exs` and group host from accepted `managed-h2-group-generation/1792155884508467786/group-generation-browser-host4.exs`; derive each runner4. Copy the corresponding unchanged cohort with its hash. New names are `fixed-identity-rotation-browser-host1.exs`, `fixed-identity-rotation-browser-runner1.py`, `group-identity-rotation-browser-host1.exs`, `group-identity-rotation-browser-runner1.py`, with matching explicitly inventoried cohorts.
- [x] Adapt actual numeric identities, stable same-path public CA replacement, retained policy/DER proofs and group completed-HEAD cold connection schedule. Preserve genuine captures, native95/accounting, original completions, every Actor/process-group/reader/adopted-child join and source/BEAM before/after checks.
- [x] Copy the accepted collector3 to `browser-command-collector1.py`; make its explicit endpoint manifest require exactly two rows `{h1,http2},{h2,http2}` per invocation, inventory the actual new host/runner/cohort/peer sources, and aggregate two receipts as four rows. Never count navigations as rows.
- [x] Freeze exact sources and command/row inventory. Complete fixture SPEC→CODE; check Python and extracted JavaScript syntax/host+cohort formatting before browser execution.
- [x] Run fixed two rows, then group two rows. Require actual public h2 handshakes at old/new numeric peers, visible DOM/title/URL/status/protocol and console silence; root views all8 images. Browser uses inherited serial OLD/NEW navigation and selects A only; sockets establish NEW-first overlap, B/wraparound and denial cleanup. Browser rows make none of those socket-only claims.
- [x] Use legal per-request origin Authorization browser markers, strictly assert exact origin marker at genuine native ingress and the intended peer, and assert Proxy-Authorization absent at both. Preserve the failed browser1 and same-version four-header diagnostic; browsers do not claim positive proxy-header stripping. Keep every genuine injected marker/stripping assertion in fixed/group native-H1/H2 socket tests unchanged.
- [x] Preserve request_clean while native connection lives, explicit Chrome close, actual terminal groups/readers/children, final owner/Service/Gate/cohort zero+normal joins and rebind. Health closure is separate from selected GET retirement. Denials are separately labeled socket tests with their exact cleanup outcome.

### Task5: Final review and fresh verification

- [x] Freeze full implementation candidate and complete independent full-stage SPEC then CODE. Bind all new test/fixture operands and previous unchanged contracts. Resolve every actionable finding.
- [x] Freeze exact argv/collector/timeouts before execution. Use unfiltered `mix test --warnings-as-errors --max-cases 1` with `MIX_ENV=test`, `ERL_FLAGS=+S 2:2`, Nix and unbuffer. Always include the complete defining `managed_h2_fixed_endpoint_test.exs` when F is used.
- [x] Run relevant union: fixed/group Generation and endpoint/lifecycle/release-order/failure/native-TLS suites; preparation and H2 identity; H1 Generation/failure/handoff/group compatibility; checked capture/accounting, group sources/envelope and generic Generation/native-H2 startup/stale-start seams. Serialize batches to avoid competing runtime; exact full file lists belong in the frozen inventory, with no excludes/skips or waived warnings.
- [x] Force strict compile; check every changed active Elixir source and exact active host/cohort formatting, all changed Python and extracted runner JavaScript syntax. Static gates execute0 tests.
- [x] Run separate core/HTTP isolated consumers and fresh post-review browser2+2. Record executed counts/exits, every actual wait status, nonforced terminal custody and matching source/artifact hashes; never translate signal termination to exit0.
- [x] Write exact acceptance, retain failed/UNKNOWN/sticky history and cumulative counters, complete independent document SPEC→CODE and disk/index/blob checks, then make local conventional commits and verify actual committed bytes. Documentation-only postcommit identity may be recorded in the next kickoff to avoid an endless closure loop.
- [x] Advance automatically to the next existing bounded requirement (H2 active/idle reload plateau) only after this slice actually closes. Broader Task5/M3 and all other remaining gates stay open.

No publication/deployment/production/Vault/operational-certificate/public-management/account change or disabled release-artifact E2E activation follows. Astra remains2/2 exhausted; ordinary failures enter authorized Sol diagnosis without weakening assertions or requesting routine approval.

## Verified local closure and historical successor kickoff

Entry — 2026-10-17: identity rotation is locally closed by `88e435a73429666717a4d20a83f9fca13e0a67e9`.
The postcommit audit is `docs/acceptance/evidence/m3/managed-h2-fixed-reload-plateau/1792235229996913527/identity-postcommit-custody1.json`
(SHA256 `6a8e6264cba5dfe33859f1968ce6c5063df3ad45e53b9c79cfc8c3d4ee97b77b`): 973 task files, 415 source pins and committed bytes verified;
tracked tree clean and index empty before this kickoff. Identity final fixed6/group2
provided four actual rows/eight root-viewed images; the seven unchanged-input
nonbrowser gates remain explicitly reused historical evidence, not new executions.
Historical FAIL/UNKNOWN/sticky receipts remain immutable. Counter62 is inherited
without reset; Astra2/2 is exhausted. Fixed plateau is now in kickoff review;
all new runtime gates remain NOT RUN. E5 is `docs/acceptance/evidence/m3/managed-h2-fixed-reload-plateau/1792235229996913527`.

## Fixed reload plateau current checkpoint — 2026-10-17

Current fixed-plateau checkpoint — 2026-10-17: eight native H1/H2 × h2c/TLS-H2 × active/idle profiles passed fresh final scoped verification on one persistent instance/owner/epoch/Store per profile, with two warmups and twenty measured reloads each. Full implementation SPEC1→CODE1 has zero findings; final scoped batches passed242/0 and400/0 across20 distinct paths (642 test invocations, not642 unique tests). Strict compile, changed-source format and active fixture syntax passed as static0-test gates. Core consumer passed1/0 and HTTP consumer passed2/0. Pinned Python startup passed11 unittest methods (the ExUnit-only collector remains static0). Fresh fixed browser passed two actual nativeH1/H2→TLS-H2 rows; root opened all four OLD/NEW PNGs. Implementation and runtime gates are PASS. Final independent document review, local commit and committed-byte custody remain pending and are recorded separately before fixed-slice closure. See `docs/acceptance/m3-managed-h2-fixed-reload-plateau.md` and E5 `docs/acceptance/evidence/m3/managed-h2-fixed-reload-plateau/1792235229996913527`. Group reload design/execution follows actual fixed closure; whole Task5/M3, full matrix, multi-owner, selected-A R32/B-available, standalone, two ≥600s load profiles and H3 accounting stay open. No publication/deployment or other excluded operation follows.
