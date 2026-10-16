# Task 4 runtime tests — source-only proposal1

Task: native_generation_runtime_test_proposal. Direct source-only assignment; DONE for the proposal deliverable. Parent retains all repository writes, implementation, parsing/compilation/format/testing, source gates, reviews and execution evidence.

## Custody and adoption

Repository/worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, assignment baseline `e189894882bb6a530f2c38538be4efaf384be261`, branch `codex/m3-h1-resource-foundation` (inherited assignment binding). This worker changed ONLY the three assigned `/tmp/gaoxy-native-generation-runtime-test-*1` files. Existing constructor tests and all parent changes were preserved. No repository/index/Git mutation, runtime/Nix/mix/test/format command was run. Read-only source/status inspection occurred; no process/session remains running.

Patch SHA256 `0d95a50962b8b6234d140610dae7a4cd88e818a5bbe9c2d9f24b24f55149e83e`. It contains one append-only hunk adding `Gaoxy.HTTP.GenerationCheckedRuntimeTest` to `apps/gaoxy_http/test/generation_checked_capture_test.exs`. The target was inspected at 628 lines, SHA256 `e4ef156aa8a6e2ce6183c7d0951e2cd666da68c9bdbf6824ace893535e946f4b`. Rebind this before adoption; if the parent reformats/changes the target, append the added second module without overwriting the original constructor module. The patch removes/rewrites zero existing lines.

Every generated/new case carries ONLY `checked_capture_runtime`. Do NOT run these cases until Task3.5 closes on actual production source. They may be compiled alongside constructor tests, but the constructor tag filter must exclude all128 runtime cases. No fixture toggles or changes to production interfaces/dependencies are proposed. HTTP-only public fixtures `GenerationCheckedCaptureTest.Provider` and `Accounting` are reused; no proxy import. Private constructor-test helpers are not accessed.

## Expected case inventory

Expected compiled runtime cases: 128, NOT an executed count. Six source-level tagged test templates expand as follows:

- Four explicit cases: exactly one byte short of required fixtureB, exact charge at Store/provider entry, suspended real gate timeout, and real-socket ordinary-retention path.
- 120 named C5 cases: five primaries (ok, returned arbitrary nested raw error, raise, throw, exit) x six cleanup modes (ok, arbitrary error, raise, throw, exit, shared-deadline exhaustion) x four observer modes (ok, raise, throw, exit).
- Four named acquisition-uncertainty cases, one per observer mode, proving finite primary/original Store rollback/one acquisition event and no Router/release.

The RuntimeAccounting fixture provides all seven callback signatures. It returns explicit compact fixtureB=16384 with H=Q65536 and configured M, delegates genuine test-provider validation/correlation/preflights and controls cleanup in the actual caller. This budget is a behavior fixture value, NOT managed runtimeB, numeric source-role qualification, or coverage of arbitrary endpoint allocation. Genuine managedB, peers and native H1/H2 are separate parent/proxy acceptance tasks.

## Evidence each test demands

Every actual Generation caller independently acquires its REAL Admission lease, initializes the opt-in Generation config, and invokes Generation.call itself. No mocked Admission callback/status/lease is used. Prior route_bytes=37 is nonzero. A single lease is the only charge in its gate, so exact public retained_bytes comparisons are meaningful.

B-1 test sets free credit to fixtureB-1, expects byte_limit and the proposed charged exchange, observes unchanged actual gate charge and zero checked Store/provider/Router/release/event effects. Exact-B test uses the existing provider pause barrier; a test-owned Store debug observer queries REAL Admission.status at incoming checked snapshot BEFORE provider invocation, then provider-entry public status corroborates the same charge. This is observation only, not production state mutation/hook or substituted gate authority.

Suspended-gate test traces the actual caller's real update wire and lets original D expire. It requires finite timeout, no capture/Router/event, then resumes the real gate and proves its queued update can still be charged. It never treats timeout as permission to refund or proceed. Gate suspension/tracing are restored in after.

C5 Target.original_marker records the actual original class/value/__STACKTRACE__ and re-raises it. The outer caller must receive exactly that class/value/stack; no independent second invocation or fresh-stack comparison is used. Returned results preserve exact arbitrary raw reason and latest exchange; successful primary plus failed release selects only the finite generation_pin_release_failed error. Endpoint identity markers establish Router once. Every release attempt must reference an actual captured request pin, original caller and exactly Dc=D+1000; duplicate refs are forbidden, success releases both receipts, and shared deadline allows exactly one dispatch. The request holder stays live after outcome, letting public gate status prove no refund on release success/error/timeout/cancel/event. Only actual caller termination may drive gate active/bytes to zero, and bounded polling confirms that teardown.

A permanent successful witness handler records cleanup events independently of the deliberately failing observer. This matters because telemetry detaches failed handlers; otherwise duplicate emissions could be hidden. Exact metadata is only store/holder/lease/stage/cleanup, exact measurements only count1, with empty-scope behavior enforced by a gate scope marker that must not appear. No reason/stack/handle/pin/raw diagnostic is accepted in telemetry. Every unconfirmed capture/release emits once despite observer raise/throw/exit; no event on successful cleanup or pre-capture Admission failure. Public external handler functions avoid anonymous-handler diagnostics. Expected failing-handler logs use ExUnit capture_log and remain available on failure; event assertions are unchanged.

The ordinary path uses real loopback TCP sockets with actual Exchange/HTTP1 body and response operations, not a fabricated transport. It polls an incoming byte, reads a chunked body and request trailer, sends chunked response/head/body/trailer/finalization, checks completed wire, closes peer and returns exact peer error. Public gate retained bytes are checked at each stage, all observed absolute updates must retain prior route_bytes+B, accepted pins are released once and charge remains until actual lease teardown. This is a focused Exchange path, not a native listener/proxy or production acceptance claim.

## Parent verification and limits

PASS (text-only): one append-only hunk; six test templates and six runtime tags; expected expansion128; zero constructor tag or proxy references in addition; actual caller acquire/call and two independent telemetry handlers present. This is NOT Elixir parsing, compilation, formatting, runtime or test evidence.

NOT RUN: patch apply/check, Elixir parse/compile/format, Nix/mix/ExUnit, source constructor gate, runtime C5/network behavior, reviews and managedB/native acceptance. Initial runtime cases are intentionally not executed while parent implements Tasks1-3. Parent must record actual discovered/executed/excluded counts; expected128 is not a passing receipt. Shared-deadline matrix cases intentionally wait through one original Dc, so those20 cases together add roughly30 seconds with500msD under normal scheduling, not64 renewed waits.

After Task3.5 closure, optional focused proposal command (NOT RUN):

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 --only checked_capture_runtime apps/gaoxy_http/test/generation_checked_capture_test.exs
```

Canonical full Task4 group (NOT RUN):

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_http/test/generation_checked_capture_test.exs apps/gaoxy_http/test/generation_resources_test.exs apps/gaoxy_http/test/generation_test.exs apps/gaoxy_proxy/test/managed_generation_accounting_test.exs apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs
```

Review/format/apply and constructor source rebinding remain parent-owned. Any wiring/repair changing charged production constructors reopens Task3.5 before another B-consuming run. Preserve all constructor/legacy assertions. Current task runtime attempts0/repairs0. Inherited counters remain worksheet failedGREEN1/test-contract repair1/production repair0; group failedGREEN24/root events27/Astra2of2 exhausted. No reset or Astra escalation. Remaining risk is uncompiled source proposal and unverified test timing/fixtures; no product decision is required.

## Source hashes at final proposal inspection

- `apps/gaoxy_http/test/generation_checked_capture_test.exs`: `e4ef156aa8a6e2ce6183c7d0951e2cd666da68c9bdbf6824ace893535e946f4b`
- `apps/gaoxy_http/lib/gaoxy/http/generation.ex`: `aca3f62a1078825c1e6db087f76dacf2ab28611b5b360e2f14169f050ee9a751`
- `apps/gaoxy_http/lib/gaoxy/http/exchange.ex`: `75b752c358d861be75446b99fef948f023082e6de177840bef35f99ce20776d0`
- `apps/gaoxy_http/lib/gaoxy/http/http1/response.ex`: `dbf43ff0ee063758125093505749c8941fe2d4bda7f4d6b9429fe907f19cca85`
- `apps/gaoxy_http/lib/gaoxy/http/router.ex`: `513db9910d6f0beabf1038db8bc1539ee5c5e8731ace0f6d349b9f2f2db96abd`
- `apps/gaoxy_http/lib/gaoxy/http/request.ex`: `44895f9382e126cfda120f95f2a6925e987383f5c5a2adf8d05dd9dc4edb1f1c`
- `apps/gaoxy_http/test/connection_poll_test.exs`: `9100a928c7b44925e40f682716161d73fbb5c51071a06f8dadf2b775d5026027`
- `apps/gaoxy/lib/gaoxy/admission.ex`: `04272b4f7d9647c6b43db4feeac1cc77ee8ce1386572a851024a89c1defba03d`
- `apps/gaoxy/lib/gaoxy/telemetry.ex`: `749421579aa4d6c5c8d8def5d9cdf502a59c7aa194203a8fb6c3051de1b72961`
- `docs/designs/m3-native-generation-checked-capture.md`: `bc959d350c12d9cfc4baf392539f36564135d7c0f3024639cdd775aace296093`
- `docs/plans/m3-native-generation-checked-capture.md`: `2a1880dd346a36a40b741311b7cd1c18de23db96a5e21a2d1b02e924ceadf650`
