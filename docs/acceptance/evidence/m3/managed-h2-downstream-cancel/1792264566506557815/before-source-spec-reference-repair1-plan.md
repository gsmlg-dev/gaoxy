# Managed H2 Downstream Cancellation Implementation Plan

> **For agentic workers:** Execute the bounded tasks in order; root owns independent SPEC→CODE reviewers and runtime custody. No implementation is performed by this preparation assignment.

**Goal:** Qualify four native-H2 downstream RST cases at exhausted upstream credit with a live same-socket sibling.

**Architecture:** Extend the existing independent-peer tests with authentic keyed captures and live-count checks. Reuse existing native stream-ID, peer snapshot, completion and fixture cleanup APIs without changing production or fixtures.

**Tech Stack:** Elixir/ExUnit, native H2 frames/HPAX, independent Python h2 peer, canonical Nix environment and accepted finite evidence collectors/browser tools.

## Task 1: Freeze the real successor entry

- [x] Root verified actual predecessor closure at `e40284971ac1df030ef8bcb46e07b0b3838a3c53` and E10 `docs/acceptance/evidence/m3/managed-h2-downstream-cancel/1792264566506557815`; see actual early-final-postcommit-custody2.json and closure-document-overlay2.json. The preparation baseline ceb3c0c is historical. Confirm exact worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, assigned-file diff and ownership. Preserve others' edits and unrelated protected E4 files; do not enumerate/read/hash/stat those files.
- [ ] Materialize design/plan/acceptance and rebind the nine accepted finite collector/browser/syntax tools into actual E10 by path only. Separately adapt the three audit tools for exact new command/case identities and retained predecessor evidence, with independent full source review. Do not copy giant embedded old runners, alter shutdown/deadline/assertion semantics, or copy suffix2 as the new command identity. Root independently checks materialized bytes and approved path-only differences.
- [ ] Freeze a NEW inventory BEFORE runtime: exact argv/env/cwd/timeouts/roles/output paths, source manifest with actual counts, document pins, candidate byte map and actual base-commit custody, first and final command names. Candidate working-tree changes are not falsely described as already committed. Use predecessor `docs/acceptance/evidence/m3/managed-h2-early-final-exhaustion/1792258318148616262/command-inventory2.json` for exact inner commands/scopes (including Generation `--trace` and all seven format paths after E10 rebind). Its suffix2 names/statuses/count402 are historical, not new evidence.

## Task 2: Add exactly four cases and additive helpers

Modify only `apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs`; retain original 24 cases and singleton `hold_upload`, `capture_holds`, `assert_held`, fixture/clean/close/boundary helpers byte-for-byte.

- [ ] Add fixed/group × `[:h2c,:http2]` describe/tests with downstream fixed to `:http2`; retain the group activation boundary. Each name identifies native H2 RST, exhausted credit and a simultaneous same-socket sibling.
- [ ] Add a keyed capture helper selecting T entry by exact `{guardian,completion}` and preserving every original capture assertion: resource, original request completion, submitted URL/backing, managed flags, transport selection, request keys, nonempty exact public request pins/provider/owner/holder/kind/handles; group selection keyed by the same authentic guardian/completion with distinct G/T tokens. Capture actual worker PID from guardian `state.owner`; require distinct originals/workers/tokens for upload and sibling.
- [ ] Add count-aware authentic-held assertions preserving all original identity/pin/selection checks. Assert exact token-key/pin sets for originals at both2 and sibling1, public T request count and Service cleanup count; for group exact inflight/reserve/controls. Compare stored identities, not newly discovered replacements. Never call the singleton helpers after sibling exists.
- [ ] Use the complete nine-step design sequence. Key operations are:

```elixir
:ok = F.send_body(f, socket, <<0, 255>>, false, 1)
{block, _} = HPAX.encode(:never_store, [{"x-check", "first"}, {"x-check", "second"}], HPAX.new(4_096))
:ok = :gen_tcp.send(socket, Gaoxy.HTTP.HTTP2.Frame.encode(1, 5, 1, block))
:ok = F.send_request(f, socket, "GET", "/hold/response-prefix", [], true, 3)
# After exact sibling prefix and both authentic holds; monitors already installed:
:ok = :gen_tcp.send(socket, Gaoxy.HTTP.HTTP2.Frame.encode(3, 0, 1, <<8::32>>))
```

- [ ] The prefix callback sends a uniquely tagged receipt exactly once. Inside that callback, require upload reset8/response_started=false, worker killed, public completion/guardian normal, T/G/Service both2→sibling1 and still-pending sibling BEFORE sending suffix. Preserve existing 5,000ms event/monitor/await/state budgets; no sleeps as evidence, enlarged deadline or synthetic cancellation. Exact final sibling bytes/trailers and unchanged cleanup close the case.
- [ ] Inspect assigned-file diff against actual entry: four new generated cases only, additive helpers only, originals unchanged, no F/G/peer/dependency/production edit. If unexpected evidence requires broader executable scope, report it with exact failing assertion/source before any expansion; do not silently weaken this contract.

## Task 3: Independent source review, first defining run, then implementation review

- [ ] Before any runtime, independent SPEC→CODE reviews the complete design/plan/acceptance, materialized tools, command inventory and actual implementation candidate. Resolve actionable findings against exact current pins.
- [ ] Run the NEW inventoried first defining command through accepted collector (600s):

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --trace --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs
```

Require nonzero executed tests and all four new names; record actual tests/exits without projecting totals. Preserve any failure and diagnose/repair with original assertions and cumulative counters.
- [ ] After first defining PASS and root audit, obtain independent implementation/evidence SPEC→CODE review against that exact candidate and its actual first-run receipts. Resolve actionable findings; no self-review substitution. Do not infer final acceptance from source support or a first green.

## Task 4: Fresh prescribed gates and bounded closure

- [ ] After resolved reviews, run fresh final commands from the NEW inventory: strict force compile; scoped seven-path format; syntax; defining trace batch; lifecycle batch; unfiltered Generation trace batch; actual Python11 startup methods; isolated Core1 and HTTP2 consumer checks. Keep exact predecessor inner scopes/flags and 600s outer collectors. Preserve the Generation Store-death monitor regression assertions and trace identities.
- [ ] Run re-bound accepted group browser collector for the existing two nativeH1/H2→TLS-H2 rows and root opens all four fresh images. Bind source/command/artifact bytes and exact nonforced actor shutdown receipts; browser rows do not constitute the four temporal RST proofs.
- [ ] Root audits actual counts, source pins, source/disk/index/blob custody, finite actor joins/adopted waits, all receipts and logs; distinguishes top-level exits from adopted child wait conversion. Do not infer uniqueness from overlapping batches, reuse predecessor counts, or label blocked/unexecuted gates PASS. After all checks/reviews pass, root performs fresh required verification and task-owned local conventional commit/custody. Task6/Task5/M3 remain OPEN and broader remaining scope is separately planned.

Inherited counters: counter15 / root431 / orchestration336 / earlyTool31 / downstreamTool2; Astra2/2 exhausted. No new Astra. Ordinary Sol failures enter authorized diagnosis/repair with preserved cumulative counters. This preparation adds no runtime/product repair; root maintains the running totals. No push/publication/deployment/production/Vault/E2E/account setting work.
