# Native TLS close-order proposal: independent code review

**DONE — PASS_SOURCE_ONLY_NO_OPEN_FINDINGS.** Direct bounded review, task `/root/browser_contract_spec/native-tls-close-order-code1`.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; historical supplied baseline `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`. Candidate2 SHA `2429bbdecb1bba716627af84f24c59209a10d953f985acace590736978e0fb7e`: all 198 current source hashes independently match.

Reviewed unadopted patch `/tmp/gaoxy-group-native-tls-close-order1.patch`, SHA `6b40b036469187b3944c0a5f7071cd070c6eddca7eebfe36ca143a5b869a91a8`. Current test SHA is `601d497749e5daee3c4dc43d6351ddcc70abe5bda17f888be49eee5cd2be4ea3`; in-memory proposed test SHA is `f0f44cdbb02845fddf33b76a7d0f34379630c584c2b5d8e161492354979e951d`. No patch was applied.

The diagnostic receipt SHA `bb78ba8e641510cf724e208904428268cc74fd0fd79d087a6064491c2b6ffe73` and log SHA `4b3a67e0bf99bafdbf7534f3ffd429c404ec72bc36df5dea6ac4e9a4b5f2da51` authenticate 41 tests / 1 failure, exit 2, joined/no timeout, stable candidate2 sources. Both positive original workers were still waiting in `HTTP.await_cleanup` with stream 1 present immediately before peer close. HTTP2 roles joined owner `{:shutdown, :peer_closed}`, writer `:normal`, original worker `:killed`; h2c original worker joined `:normal`. The in-memory diagnostic adds logging and retains the original assertions.

Root cause is a fixture ordering race: upstream `RequestCompletion.await` is not a downstream worker join. `HTTP2.Connection.close/1` deliberately kills workers still present in its stream map. The 11-line, additions-only proposal waits for the captured original worker to die and stream 1 to retire before closing the client; it also checks the original owner/writer are alive.

No deadlock cycle was identified. Response finish precedes `Session.consumed`; session cleanup can stop normally, allowing `HTTP.await_cleanup` to return. `Stream.run` then sends `h2_stream_done` and returns, and the owner discards the completed stream without killing its worker. These steps do not require client close. The existing `G.eventually` helper has a finite deadline, and `:sys.get_state` is bounded; an owner failure errors rather than satisfying the barrier.

All original monitors are installed before dispatch and remain unconsumed. Added polling neither replaces nor flushes them. An already killed worker may satisfy the dead-worker predicate, but its original `:killed` DOWN still fails the unchanged precise worker reason assertion. Owner/writer/worker joins, reason sets, cleanup/accounting, service removal and no-extra-request assertions remain byte-identical. No production behavior or accepted reason was changed.

Read-only SHA/JSON checks passed (exit 0), including diagnostic source maps and log length. In-memory hunk applicability and preservation/order checks passed (exit 0). Source tracing covered HTTP dispatch/await_cleanup, Session consumed/cleanup_complete, Stream.run, Connection done/discard/close and the finite fixture helper. No runtime/build/test execution occurred in this review. Fresh repaired TLS, command gates and canonical browser3 are NOT RUN BY REVIEWER; no runtime or stage acceptance is claimed.

Parent counters remain failed GREEN 21 / ordered root events 23 / Astra 2/2 exhausted; reviewer adds zero repair rounds. A separate cumulative Sol-round number was not specified in the handoff; parent ledger remains authoritative and unreset. No Astra gate or new decision is requested. Only the two authorized `/tmp` reports were written. All reviewer commands finished; repository, runtime, Git and parent processes were left untouched.
