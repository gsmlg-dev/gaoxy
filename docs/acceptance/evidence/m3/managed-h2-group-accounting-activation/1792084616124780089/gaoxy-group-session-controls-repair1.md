# Session-control repair1 diagnosis and patch proposal

Task `/root/group_postactivation_code/session_controls_repair1`: **DONE_DIAGNOSIS_PROPOSAL**, direct source-only assignment. This completes the proposal, not runtime acceptance.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Supplied historical baseline: `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`; no Git command was run. Root owns repository, runtime, build, formatting, evidence, Git and process mutations. The reviewer wrote only the three new `/tmp/gaoxy-group-session-controls-repair1.{md,json,patch}` artifacts. No repository files were edited.

## Authenticated failure

Receipt `fresh-session-control-1792097388206486059.json` SHA256 `f629d63f371a816323b9457d4dfca1df03d6f808bc7ebbbc4f6955438a883011` and log SHA256 `d595e8ddfcffe1ad2cef3fd90ed0c2a9e43f87cec703f9f25fd7911a05b9211e` are under `docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089/`.

Actual **FAIL: 46 executed, 4 failures, 0 skipped, 0 excluded**, exit2, process joined, no timeout, 53623ms. The receipt's 189-input source-before and source-after agree. Root has since made unrelated task-owned TLS/accounting/docs changes; this is not a claim that the current complete tree still matches that failed run. PATH erl `.5` is PATH-only evidence, not proof of the loaded VM.

Command recorded by the receipt:

```sh
env ERL_FLAGS='+S 2:2' MIX_ENV=test unbuffer mix test apps/gaoxy_proxy/test/managed_h2_group_session_control_test.exs --warnings-as-errors --max-cases 1 --seed 33015
```

## Root causes and limits

1. **Streaming fixture violates the declared-trailer contract.** Both upstream protocols close the real H1 socket during final chunk reading (log45–55 and155–165; test213). `managed_h2_fixed_peer.py:347–385` sends initial fields from `value.get("fields", [])`; this test omitted fields while requesting `x-check` trailers. Proxy `http/headers.ex:40–108` derives allowed trailer names from initial `Trailer` fields, and `http.ex:1051–1058` validates final trailers before finishing. Native H1 `http1/response.ex:58–67,90–137` independently requires declaration. The missing declaration is source-proven and consistent with the closure. The failed run did not directly capture the exact final rejection selector.

2. **The owner-DOWN test uses an invalid immediate-death stimulus for its H1 process.** Both original monitor/pump matches received `{:shutdown, :local_closed}` instead of the unchanged large diagnostic (log99 and185; diagnostic payload omitted). `deps/thousand_island/lib/thousand_island/handler.ex:356` sets `trap_exit` true; `http/connection.ex:175–220` executes the endpoint synchronously. Proxy `http.ex:781–825` nested `pump_wait` receives only recognized proxy/DOWN/drain messages. An arbitrary external `Process.exit` becomes queued EXIT rather than immediate death. The specific later local_closed timing/path is not fully captured. This diagnosis does not assert a production H1 defect. `:sys.terminate` also queues while that nested endpoint receive does not service system requests.

Native H2 `http2/stream.ex:6–30` creates a genuine supervised stream worker, links the native owner, acquires a lease and runs the endpoint without setting trap_exit. `http2/connection.ex:1025–1060` constructs/distributes the genuine Exchange. Session `http/session.ex:47–53,306–316` monitors and accounts the authentic owner DOWN. The proposed assertion validates the actual worker trap flag at runtime. The existing fixture does not expose Exchange transport state; no new exposure or private-state mutation is proposed.

## Narrow proposed change

Only `apps/gaoxy_proxy/test/managed_h2_group_session_control_test.exs` is targeted:

- Extend fixture `open` with optional `downstream \\ :http1`, preserving its existing preactivation default. Existing cases retain native H1 downstream.
- Add initial response `"fields" => [["trailer", "x-check"]]` to the streaming manual response.
- Select native H2 downstream only for genuine owner-DOWN cases, retaining both upstream protocols.
- Assert `{:trap_exit, false} = Process.info(pump, :trap_exit)` immediately before the original external exit.

The original `{:actual_owner_failure, :binary.copy("diagnostic", 16_384)}` is unchanged. Every original assertion-starting line is unchanged and ordered. Exact diagnostic DOWN reason, authentic guardian control/down trace, normalized upstream-failure projection, completion await, guardian normal join, body/trailer and all cleanup assertions remain. No fake DOWN/reply, Process.flag mutation, private state mutation, broader allowed reason, sleep, watchdog/deadline relaxation, production change or assertion weakening is introduced.

Patch: `/tmp/gaoxy-group-session-controls-repair1.patch`, 1947 bytes, SHA256 `aaa4d5cf6adafcae036e3e586a0d7b238d490a86c98335815729b5cb54a97071`.

Target before SHA256: `72d3f593e52abbdc57ba35a7a31cd571cd0cdb940e36711a417c15a89869cb6a`. Proposed target before formatting SHA256: `87915005988001f9e2249c3d3cb1bc8f82e10eef1bfa06538cc14b4d3f8736be`. The before identity matches the failed receipt and was re-read before handoff. Current read-only source hashes are in the JSON report.

## Validation and next checks

**PASS (artifact/source checks only):** Python checked exact patch context/hunk counts, reconstructed proposed bytes, original assertion ordering/preservation, unchanged diagnostic, no introduced Process.flag/sys.terminate, and matching default-argument backslash style. Receipt/log/patch/target hashes were re-read. All reviewer commands completed; no background/runtime processes were started.

**NOT RUN:** formatter, compiler, runtime/tests, real-peer acceptance, independent proposal review. Root exclusively owns these actions. No runtime success is claimed.

Parent should obtain independent SPEC/CODE review, adopt the proposal, format/compile its scoped source, then run the unchanged complete Session-control suite. Require actual 46 executed / 0 failed / 0 skipped / 0 excluded, joined process, no timeout, stable authenticated source and loaded-VM identity evidence. If streaming remains failed, trace the actual response policy and final Headers.trailers/Response.finish selector with bounded output. If H2 owner-DOWN remains failed, preserve actual trap flag and exact diagnostic reason, then inspect authentic guardian monitoring/completion. Never fake DOWN or broaden the reason assertion. Preserve failed receipts and root-owned TLS/browser work.

Inherited counters remain ledger6, failedGREEN19, rootrepair20, Astra2/2 exhausted; this source-only reviewer adds **0 runtime repair rounds** and requests no Astra recovery. Latest parent update reports root-owned TLS test-only RED41/3, exit2, stable/no compile error, with production proposal2 adopted at event21 but not yet run. That parent event is recorded without resetting or reinterpreting counters.

No design decision is needed. Remaining risk: proposed runtime behavior is unverified; dynamic final failure selectors were not directly captured.
