# Task 3 checked Store constructor tests — proposal1

Task: native_generation_checked_store_test_proposal. Direct source-only assignment; DONE for the proposal deliverable. Runtime implementation/acceptance remains NOT RUN by this worker.

## Custody and placement

Repository/worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, baseline `e189894882bb6a530f2c38538be4efaf384be261`. Parent remains the only repository writer and runner. All pre-existing parent modifications/untracked docs/tests were preserved. This worker wrote only the three assigned `/tmp/gaoxy-native-generation-checked-store-test-*1` artifacts; no repository, index, Git, dependency, runtime, format or test changes.

Proposal SHA256: `1acb6ad87907cb51b84598ceb760d69e84387128c8279c52bfc383bb3144d6fe`.

Split at the explicit marker:

- HTTP module `Gaoxy.HTTP.GenerationCheckedCaptureTest`: 18 tests, for `apps/gaoxy_http/test/generation_checked_capture_test.exs`; no proxy references/dependency.
- Proxy module `Gaoxy.Proxy.ManagedGenerationCheckedOwnerTest`: one test, append to the parent-owned `apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs`. Distinct name avoids the existing accounting proposal module. `async: false` for per-process BEAM trace setup.

All 19 tests were tagged `checked_capture_constructor` at creation. Source text checks found 19 tests/19 tags and zero Generation.call or Admission API invocations. The HTTP test accounting implements all seven callbacks; reservation raises if accidentally called. Every test setup first asserts the three checked APIs are exported; new public API calls use `apply`. Thus missing APIs produce executed ExUnit capability assertion failures rather than undefined-function compile warnings or unsupported Store messages.

## Contract and coverage

Raw malformed/improper/count>64/ETF>H/unknown-provider manifests and malformed/non-signed64 deadlines return invalid_generation_capture/clean; valid expired D returns deadline_exceeded/clean. Invalid/dead holder returns invalid_resource_holder/clean. Store wrong-holder validation occurs before provider effects. Missing or malformed callback outcomes normalize generation_unavailable, with clean/unconfirmed determined by whether the authentic ledger started.

The HTTP provider is explicitly a test fixture, not genuine managed-provider proof. It retains authentic test-owner records and exposes bounded barrier/cancel observations. Two independently paused owners let the first encountered batch succeed and the second fail without assuming map/PID iteration order. A corrupt current receipt cannot redirect rollback: both exact original Store/operation pairs must cancel, current entry included, baseline holdings remain. Additional cases mutate all complete fixture receipt fields, reject malformed/huge/deep diagnostics, malformed callback results and invalid normalizer output, preserve complete original deduplicated batch/order, reject a genuine fixture receipt whose capture singleton exceeds Q, and compare Store state before/after to reject retained failure ledger/history. Expiry and holder death behind successful provider barriers reject late publication with original rollback.

Checked cleanup tests cover same absolute Dc for each success, first callback consuming Dc so second dispatch never starts, finite non-ok/raise/throw/exit/garbage release errors, malformed/expired Dc before dispatch. No per-pin renewed wait is used.

The genuine T test prepares a real transport resource, obtains a real Store baseline pin and releases preparation. The owner debug callback suspends the actual Store before its request-pin reply. A per-owner BEAM send trace proves a genuine T8 success with exact original handle/holder/op while owner status reports two pins. After D, only the suspending owner resumes Store, using the already-tested owner-context mechanism. T public pin_many then performs its own postcheck cancellation and Store performs full original-ledger rollback: exactly TWO actual Store send controls and TWO owner receive observations for the same original Store/op are required. A trace-delivery fence plus owner status pins=1 bounds the no-third-send assertion. Store snapshot/state stay unchanged and requester remains live through custody assertions. This uses no fabricated T pin, production hook, global trace pattern, suppressed self-cancel or deduplication.

Parent explicitly selected the exact finite normalizer addition `finite_checked_reason({:deadline_exceeded, :cleanup_pending}) -> :deadline_exceeded`; genuine T expects `{:error, :deadline_exceeded, :cleanup_unconfirmed}`. Unknown nested diagnostics remain generation_unavailable. Parent/accounting-test owner must include that exact mapping regression.

## Execution and counters

PASS: read-only workspace/head/status/source inspection; source text test/tag counts; absence of Admission-consuming calls; OTP sys.erl source confirms three-element debug installation with removable identifier. These are source checks only, not Elixir parsing or runtime evidence.

NOT RUN: parse, compile, format, Nix, mix, ExUnit, runtime/real-T behavior, constructor arithmetic gate, independent runtime SPEC/CODE review. Current checked Resources/Store APIs are absent in inspected baseline, so first parent execution should RED at capability assertions until implemented. No claim of passing test behavior is made.

Recommended parent-owned constructor command (NOT RUN):

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 --only checked_capture_constructor apps/gaoxy_proxy/test/managed_generation_accounting_test.exs apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs apps/gaoxy_http/test/generation_checked_capture_test.exs apps/gaoxy_http/test/generation_resources_test.exs apps/gaoxy_proxy/test/upstream_transports_test.exs apps/gaoxy_proxy/test/upstream_groups_test.exs apps/gaoxy/test/admission_timeout_test.exs
```

Parent must record actual executed/excluded counts and warnings/exits, inspect any fixture failures, format adopted application files and run fresh on reviewed source. No Admission-consuming execution before Task3.5 closure.

Current proposal runtime attempts=0, repairs=0. Preserve inherited worksheet failedGREEN1/test-contract repair1/production repair0 and group failedGREEN24/root events27/Astra2of2 exhausted; no counter reset or third Astra. Source-only draft improvements are not runtime repair rounds. No Astra handoff or escalation gate. All own commands finished with no live sessions/processes. Remaining risk: uncompiled source proposal; runtime semantics and timing require parent verification. No product decision needed.

## Inspected source hashes

- `docs/designs/m3-native-generation-checked-capture.md`: `bc959d350c12d9cfc4baf392539f36564135d7c0f3024639cdd775aace296093`
- `docs/plans/m3-native-generation-checked-capture.md`: `2a1880dd346a36a40b741311b7cd1c18de23db96a5e21a2d1b02e924ceadf650`
- `apps/gaoxy_http/lib/gaoxy/http/resources.ex`: `0e58a4f0badd2ba6d21b9f118c5b3f6c4d1070b4371e76e9dfc0656796f0907b`
- `apps/gaoxy_http/lib/gaoxy/http/generation.ex`: `aca3f62a1078825c1e6db087f76dacf2ab28611b5b360e2f14169f050ee9a751`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_generation_accounting.ex`: `73249ba0952f33cb7605d1ca8a5c7aecfe240d93456a3ad9f877ee9a9501636c`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex`: `877bb6e4c891ee3f8c93a425a67b10f390137fcead2eeb52ccd9b78d9b2b1f51`
- `apps/gaoxy_proxy/test/upstream_transports_test.exs`: `b04dbc52a5608fa7b74e2a6207b3c84f2f22dcbda07ad45f92c4657d4cd50d86`
- `apps/gaoxy_http/test/generation_resources_test.exs`: `8153e748b1815e7984401408d5705c197af9cecde1c2e40dd19418e6d88a2444`
- `apps/gaoxy_http/test/generation_release_deadline_test.exs`: `e31674b1703f566c23fbea31ba185144e910cc730fde780b3061498048e56225`
- `/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7/lib/erlang/lib/stdlib-7.3.0.3/src/sys.erl`: `266f18abd9ba539c1da69e076844c4cfcf1162adc6fae1cf816e8be09411dd82`
