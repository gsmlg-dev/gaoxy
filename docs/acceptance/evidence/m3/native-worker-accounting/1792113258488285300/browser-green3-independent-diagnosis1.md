# BrowserGREEN3 independent startup diagnosis

Task `native_worker_constructor_spec/browser-green3-diagnosis1`: **DONE** for the bounded source diagnosis and unrun regression proposal. BrowserGREEN3 remains **FAIL**; this report claims no new runtime acceptance.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Saved baseline: `58307a7084298db309a93697b9102b2cc4c87eda`. Evidence root E: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/native-worker-accounting/1792113258488285300`. Root owns all implementation, execution, evidence, and Git operations. Parent was editing production concurrently when the final API checks were read; this report identifies the frozen GREEN3 source separately.

## Confirmed cause

The failing actor is extra pre-admission native C `#PID<0.349.0>`. It raised `MatchError` with RHS `{:error, :einval}` at `apps/gaoxy_http/lib/gaoxy/http/connection.ex:16`, the call to `ThousandIsland.Socket.peername(socket)`. This is **peername**, not setopts. Gaoxy treated a documented fallible metadata API as guaranteed success. The next `sockname` match has the same defect. The safe ledger records the actor's authenticated observer DOWN with `:omitted_terminal_reason`, no ordinary acquisition and no writer. Frozen host5 correctly rejects that terminal at `validate_terminals/2:1463`; its unadmitted-native allowlist only admits peer_closed or handshake/closed.

This actor is distinct from target C345 / writer R350 / worker W351. The saved causal projection shows R350 sending all five `h2_written :ok` results, then receiving actual `:stop` sent by C345 after authorized Chrome closure. Target C's actual terminal is `{:shutdown, :peer_closed}`; R's is `:normal`, authenticated by both observer and Gate monitor observations. GREEN3 therefore has concrete evidence of an extra startup actor crash, not a target writer failure. Original BrowserGREEN2's target cause remains **UNKNOWN**.

A peer retiring after TLS/ALPN is consistent with the socket metadata error. The exact lower-level closure timing is **not independently proved** by saved packets; the confirmed defect is the unchecked fallible metadata result. No dependency defect was identified, so upstream issue routing is unnecessary.

## Narrow repair and terminal contract

Use `with` for real `peername` and `sockname`, performing the existing H2 initialization only after both succeed. For `:closed`, `:einval`, or `:enotconn`, return `{:close, context}`; return `{:error, reason, context}` for other metadata errors. Do not fabricate peer/local values, retry, broadly rescue, or accept all errors.

ThousandIsland's supported close result becomes `{:shutdown, :local_closed}`. It does **not** mean peer_closed. Returning a manufactured peer_closed error would misstate provenance. Explicit acceptance of orderly local_closed for **proved pre-admission native C only** is a disclosed contract correction associated with the newly handled startup path. Bind it to that path where feasible. Keep target/admitted C strictly peer_closed, writers normal, and crashes/unknown terminals rejected. Existing already-closed TLS ALPN can return unsupported_protocol before metadata; this repair does not broaden that unrelated branch.

## Saved run and evidence limits

Qualification executed one H2 case, failed in 10375 ms, and recorded identical source-before/source-after maps; H1 was **NOT RUN**. The run obtained a real H2 HTTP200 visible document and screenshot, request cleanup and target normal joins, strict live/unjoined target C/R close authorization, Chrome graceful exit0, and normal node join. The extra startup C terminal then failed host validation. The upstream peer needed forced cleanup after host failure; all owned groups were gone. No final cohort snapshot was saved because the validator failed before its write. Reaching that validator implies the prior final-cut validation returned, but this is control-flow inference rather than a saved final snapshot.

## Regression proposal

`/tmp/gaoxy-native-worker-startup-metadata-tests1.exs`, SHA256 `4376ae4487f65a66296d1d9949c704b5d3bb3a8f6f81ea1061e05b9e1d184f68`, is a new module intended for appending to `apps/gaoxy_http/test/http2_worker_startup_test.exs`. **Compilation/tests NOT RUN** by this assignment.

It proposes three real-socket cases: closed TCP peername with exact callback-close assertion; TCP closure after actual successful peername with actual sockname failure; and real TLS h2 ALPN held after the actual negotiated-protocol result, real client closure, server recv/peername confirmation, then callback release. The TLS case checks generated handle_continue's shutdown/local_closed result, the preinstalled owned-worker monitor's normal join, zero acquisition and zero Gate counters. It uses finite receive/cleanup deadlines, supported APIs, and no injected metadata outcome, production hook, or dependency patch.

Root has taken ownership for adoption and will remove the proposal's accidental tautological literal-IP match and add `ip: {127, 0, 0, 1}` to the TLS listener. The /tmp proposal is frozen at the hash above so root can adopt it without concurrent edits.

Source-only API checks: `Admission.acquire` sends `{:acquire, bytes, options}`, matching the installed debug-input observer; `Admission.status` is a same-Gate call barrier; TI Socket.getstat delegates transport getstat/1; generated shutdown termination invokes handle_close then do_socket_close. The proposal's command/test result remains unknown until root executes RED/GREEN.

## Evidence identity

Paths below are relative to E.

| Input | SHA256 |
| --- | --- |
| browser-green3/qualification.json | c13a6b262f3b70c79d29ace33233245a1172fa5294085078e31e0af088d95ab4 |
| browser-green3/h2/host.log | 81ed2cd05e6bcc77ca0483817ec8713870380bbb30fba585bd910d1e427f1c01 |
| browser-green3/h2/failure-cohort.log | 9e37ab9a871852c70b94766425e92b37c6a33cc280bfbae15ed827ca0bfec95e |
| browser-green3/h2/browser.log | 1fbe6b37c4f4e85395a8eb98e9f49cac5ecc40af958573103d75932445ea03e4 |
| browser-green3/h2/causal-metadata.log | ad8201002d024305ad59a534d91ac2d0463a4025d3d2578f2d522754041ce945 |
| browser-green3/h2/request-clean-cohort.log | f606454d8e6aed7e6e21fadda0b80e25b171d018cdbbec22573f018230b83251 |
| browser-green3/h2/peer.log | a6c7f2c859429144bfe08835e6f337f1e5c34444219cb357e620ee06d3211781 |
| native-worker-browser-host5.exs | 547df33f444a59a99d61f656f0ff50b53e4caa4d5388883169ea5b5ab2abb213 |
| native-worker-browser-runner6.py | 649b61d108ecb291f411d6029f41bfcd1d352e4bbff292b965b699b5393c5dc2 |
| native-worker-browser-cohort2.exs | 8b2f2d374ae01b8fa0e490d7d02161c134a4fce97e3cb62debc16e5cfeda1406 |

Frozen production source hashes from qualification: HTTP Connection `d74a1ea9b35e996db51da5b698390afd3cdc5c47eb2c499d35c3af69de46d3f2`; H2 Connection `586db509de60712be04f5c7290adfbc6db31300a592344d54cf28e3872d24c52`; Writer `6af7f110ce8a39a834f40409b08f7626ca057230ee66cab0b65304584cec562a`.

## Scope, verification and counters

Only authorized /tmp outputs were written. No repository/evidence edits, Git, network, Mix, runtime, browser, test execution, delegation, original diagnostic2 raw-archive read, full TLS dump or full system-state dump occurred. Source/API reads and safe scalar projections/hashes completed; one initial search path was absent and was corrected. All own commands finished; no own processes were launched. Source/debugging review is complete, while compilation, tests and fresh browser acceptance are **NOT RUN** by this worker. Root owns execution and any repair. No user decision or new permission is required.

Counters received and unchanged: **group38/root49/stage8/Astra2of2 exhausted; diagnostic failures4**. This assignment adds zero runtime attempts and zero repair rounds. Astra gate: none. Remaining risks are the unrun proposal and the unchanged historical GREEN2 cause gap.
