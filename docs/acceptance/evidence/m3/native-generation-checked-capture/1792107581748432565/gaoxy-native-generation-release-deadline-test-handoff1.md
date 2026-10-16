# Deadline public API test handoff

Task `native_generation_deadline_api_test_proposals`, direct source-only assignment. **PROPOSAL_READY_NOT_RUN**. Parent supplied R=`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, HEAD`e189894882bb6a530f2c38538be4efaf384be261`. Source hashes/anchors read below. Only assigned /tmp proposal/handoff files written; no repository/runtime/Nix/mix/test/formatter/Git operation.

Seven new meaningful cases: Admission3, Groups2, Transports2. No toy state model or fake provider/client. API absence is an explicit assertion on the existing loaded module before new fixture creation. Calls to additive functions use dynamic apply, so missing functions produce semantic API RED rather than undefined-remote compilation warnings. No invalid-timeout expectation is invented while only the positive-integer contract is prescribed.

## Adoption and exact scope

- `/tmp/gaoxy-native-generation-admission-timeout-test-proposal1.exs` → new `apps/gaoxy/test/admission_timeout_test.exs`,3 tests. SHA256`ebc96c34f13ec8ccb5ec823f3e1dbb2cf0612cd8ee30f39365182a544012479e`.
- `/tmp/gaoxy-native-generation-release-deadline-test-proposal1.patch` inserts2 tests+local observation/fixture helpers before Groups test line212 `defp head_peer do`, and2 tests+observer helpers before Transports test line1773 `defp owner/1`. SHA256`17d2d06e100a6e58ce250b802f13ff485b6c6513f70c2f3eda46d7eab642c8b4`. Original test bodies/helpers/assertions remain unchanged.

The patch is a standard unified source proposal with exact current anchors; parent owns checking/adopting it against concurrent changes. No patch was applied or parsed by Git here. Parent owns scoped formatting and RED/implementation/GREEN.

## Cases and real fixtures

Admission's new case measures exact37 retained bytes after update/4 on a real gate/lease acquired by the same calling test process. Its timeout case suspends that gate synchronously, calls explicit25ms update/4, checks the real `{:timeout,{GenServer,:call,[gate,{:update,lease,37},25]}}` exit, resumes in after, and then observes the genuine queued update through public status. A timeout is not successful authorization for a caller to advance; this API test does not invent a Generation endpoint or claim the queued call was cancelled.

The third Admission case preserves real update/3 success and checks its actual default5000ms timeout behind the same suspension barrier. This intentionally takes about5s in a real GenServer call, with a10s ExUnit deadline; no arbitrary sleep/timing inequality is used. The guard against accidentally changing legacy defaults is the exact5000 descriptor. All retained bytes are set back to0 publicly. Lease lifetime is owned by the real test actor, and the ExUnit supervised gate is stopped/joined on teardown. No caller helper is spawned or left waiting.

Gate limits use the same real map shape as QUICContextTest (`max_active/max_bytes/max_state/callback_timeout`), and scope identity follows native/cleanup tests. A dummy network handler is unnecessary. NativeStreamTest/cleanup tests were read to confirm caller-owned lease and public status patterns.

Groups tests use the real owner fixture pattern: compiled actual group → prepare → public baseline pin activates it → release preparation. Existing supported `probe_bytes:1` owner limits avoid independent health work, as already used in Groups tests. Metadata release needs no network peer. First case acquires a real request pin, releases it with explicit D, observes pins2→1, then directly exercises original release/1 on baseline and observes stale group.

Transports cases reuse existing real `owner()`, `policy_source()`, `deadline()`, `eventually()` unchanged. This creates a real Gaoxy instance/owner/public managed scope. First case acquires a real request pin, releases via explicit D, then directly preserves release/1 and awaits public physical-resource/helper retirement. No dependency private client or fake owner is used.

Each provider's second case first calls release/2 with an expired absolute deadline and requires the parent-confirmed `{:error,:deadline_exceeded}` plus identical public status and no owner release input. It then suspends that real owner, releases a genuine baseline pin using D=now+50ms, requires Lifecycle's honest `{:error,{:deadline_exceeded,:cleanup_pending}}`, and retries the same now-expired D. Retry must return the flat deadline error and send no second request. After resume, the original queued call actually releases the pin; public counters and an input spy require exactly one real release dispatch.

The input spy is only an OTP sys debug callback observing real `$gen_call` input; it never substitutes owner state/behavior/replies. Public status after resume provides a same-sender ordering barrier. Every suspension is enclosed by try/after resume; every debug observer is removed in outer after. Group owner/gate supervision and existing Transports owner cleanup own actor joins. Existing bounded public retirement polling is retained; no new sleep helper is added. No expiry of a request pin is mistaken for the timed-out release, because wait cases retain nonexpiring baseline pins.

## Required additive production contract

Admission.update/4 must pass the positive integer timeout into the same `GenServer.call(gate,{:update,lease,bytes},timeout)`; update/3 stays unchanged at default5s.

Parent explicitly accepted release/2's positive-remaining precheck: expired D returns `{:error,:deadline_exceeded}` before dispatch, otherwise use supported `Lifecycle.call(owner,{:release,pin},D)`. Existing Lifecycle.call does send a GenServer call with timeout0, so calling it unconditionally cannot meet no-dispatch. Release/1's guards/default100ms Groups/default1000ms Transports/errors stay intact. No generic Lifecycle rewrite is proposed.

The old conditional64-cancel worksheet is not a runtime reserve. Parent's revised65-cancel/full-constructor design proceeds independently; these API proposals do not assert whole-path reservation/dispatch/refund acceptance.

## Read source identity

Loaded OTP28 gen_server source line2393 supplies the debug observer with `{in, Msg}`, and lines2686–2689 confirm the full `$gen_call` message shape. Read-only source SHA256 `66a4a649c8ed58f3c9ed317047f28ea2e2a61b38032cc467565fbad2c53a09db`; path `/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7/lib/erlang/lib/stdlib-7.3.0.3/src/gen_server.erl`. No trace or runtime was executed by this author.

| Source | SHA256 |
| --- | --- |
| apps/gaoxy/lib/gaoxy/admission.ex | 169f311b2a4995b3de901ac41b5c2768208c8f8c3e26d2e57a58fdefdc013a75 |
| apps/gaoxy/lib/gaoxy/lifecycle.ex | 7f673e89f59b41af72057ce1afa553fa6c62e56125b450e6d09e58da0a434f75 |
| apps/gaoxy/test/native_stream_test.exs | fbde6f0efc90fd10cfa90626d0dbed081fc41c146d7e60c43a0998b9c70dc1ad |
| apps/gaoxy/test/cleanup_attachment_test.exs | f3a2457c52fda27c039e35ba16d1dfd8958e85dbde1541e920a77f09f34682c4 |
| apps/gaoxy/test/quic_context_test.exs | e9bd176c8d3c5c41da3d159d6ba55d73dcd3e8aedde0e265680fda31588ab3e4 |
| apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex | b0330019d771b9f58f6f15eba555cd77ec0ce0fcf2843bd9e19619d65b2ae2c7 |
| apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex | f6f638d1f1f88b53c8282dc121466eb0614d241fe8ec56cc57a8a2a8b0d4096e |
| apps/gaoxy_proxy/test/upstream_groups_test.exs | 395cb0def7dff55acabd682f7a234ebbf08b270c587b97af0a69b19b67edf632 |
| apps/gaoxy_proxy/test/upstream_transports_test.exs | a74e5b19e9d1f0a1725f2df57cf29d38b6ede2d8a042cb900bf2702ebec7c208 |

Only read-only source/hash commands and /tmp writes completed. Initial search used a wrong native_stream path under gaoxy_http; actual gaoxy/test/native_stream_test.exs was located/read. No runtime failure, fixture trial or repair round occurred.

## Parent-owned verification, NOT RUN here

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy/test/admission_timeout_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_groups_test.exs apps/gaoxy_proxy/test/upstream_transports_test.exs
```

Expected new case counts are3 Admission +2 Groups +2 Transports; existing provider suites retain all original cases. Parent collector must record actual nonzero totals/skipped/excluded/exit/source identity and join. The original Admission default-timeout test is expected to pass during initial RED; new API guards should identify exact absent APIs. Syntax/fixture/compile errors require diagnosis before calling a run behavioral RED.

All own commands have finished; no background process started/touched. Counters unchanged: inherited group24/events27; worksheet failedGREEN1/test repair1/production0; Astra2/2 exhausted; this assignment runtime attempts0/repairs0. Remaining risk is proposal syntax/fixture compatibility until parent adoption/run. No third Astra, publication, deployment or native runtime acceptance is implied.

