# H2 Continue diagnostic follow-up

Task: unified-listeners-embedded-gateway/core_lifecycle/h2-diagnostic-followup.
Assignment: direct read-only. Status: DONE for diagnosis; Unit 39632124759 remains FAIL.
Source: `fd39888412ac5092d63d8ccbba4f1ad51b10c7cc`, worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/unified-gateway`.

The existing trace establishes a 105.148ms H2 Continue operation: request_start 362us, gen:do_call schedule-out 386us, schedule-in 105470us, request_done 105510us. The principal waiting interval is **105.084ms**. No code-server wait appears in that operation. The preceding direct H2 read test has a separate code-server interval 361–96680us, **96.319ms**; its operation totals 98.584ms and passes. These are different causes/candidates and must not be conflated.

## Generic +100ms fallback is not supported by the evidence

`Transport.read_body_step/3` calls `maybe_continue/1`, which passes exactly `:read_continue` to `operation/2`. Its specific clause at `apps/gaoxy_http/lib/gaoxy/http/http2/transport.ex:58` wraps the 100 Continue write and sets its absolute deadline to the minimum of the original exchange deadline and write deadline. It then calls GenServer.call with the remaining duration **without** adding 100ms. The earlier specific read clause also omits that allowance.

The generic clause at line 71 does add 100ms, but it is a distinct clause; the special clause does not recurse into it after wrapping its write operation. The generic catch also maps a GenServer timeout to `{:error, :closed}`. The failing test successfully asserts `{:error, :timeout}` before its elapsed-time assertion fails. Together source dispatch and error mapping support the special clause, rather than the generic fallback. The current scheduling trace records MFA only, not arguments or exceptions, so it cannot conclusively exclude stale loaded code or a different runtime call. A 105ms interval alone is not evidence that +100 was selected.

## OTP 28/29 and Elixir wrappers

Read the actual official tagged sources through GitHub's read-only content API:

- [OTP 29.0.2 gen.erl](https://github.com/erlang/otp/blob/OTP-29.0.2/lib/stdlib/src/gen.erl#L251)
- [OTP 28.5 gen.erl](https://github.com/erlang/otp/blob/OTP-28.5/lib/stdlib/src/gen.erl#L251)

These complete files are byte-identical, SHA256 `b828697b055865df24aad48ec4cd7f23821fa54a7aa2baa0408a444a5d0d04be`. Their finite do_call/4 path creates an alias monitor, sends the request, and enters `receive ... after Timeout`. At timeout it demonitor-flushes, performs an immediate receive with `after 0`, then exits `timeout`. There is no 100ms grace or delayed fallback in that implementation. OTP29 gen_server.call/3 forwards its argument unchanged to gen:call.

The relevant [Elixir 1.20.1 GenServer.call](https://github.com/elixir-lang/elixir/blob/v1.20.1/lib/elixir/lib/gen_server.ex#L1172) body equals [Elixir 1.18.5](https://github.com/elixir-lang/elixir/blob/v1.18.5/lib/elixir/lib/gen_server.ex#L1117): resolve the server, forward the timeout unchanged to `:gen.call`, and wrap an exit with the call arguments. Neither wrapper introduces a 100ms wait. Identical Erlang source does not prove identical VM/OS timer scheduling behavior; that separate measurement is parent-owned.

## Bounded next step

Retain the original 30ms deadline, every `<100`/`<250` assertion, seed0/max-cases1, and full 180-case gate. Extend the existing test-only diagnostic to capture the actual finite `:gen.do_call/4` call arguments, operation/request shape, and return/exception timestamps around this one operation. A call/exception trace distinguishes a genuine <=30ms timeout delayed by runtime resumption from an accidentally larger timeout or wrong loaded operation. Record the loaded Transport BEAM origin/digest if runtime dispatch differs from source. Correlate with the parent's timer and scheduler observations; the current out/in trace does not distinguish timer expiration from when the caller becomes runnable.

If the actual timeout is <=30ms, removing the unrelated generic +100 allowance cannot address this observed wait. Follow VM/host timer/resumption evidence. If it exceeds30ms or shows a different request form, investigate that concrete dispatch/loaded-code discrepancy before editing production code. Separately, preloading only the direct-read test's evidenced cold module before creating its deadline is a justified fixture candidate for its96ms load interval; it is not an established remedy for the Continue wait, where no such load occurred.

No production remedy is justified by the current trace alone. No test threshold change, skipped case, speculative source repair, or repeated blind rerun is recommended. Unit remains failed, with67 executed/66 passed/1 failed and113 required cases not run on macOS, as preserved in the original diagnostic summary.

Only `.audit/unified-h2-diagnostic-followup.md` and `.json` were written. Existing tests/docs/source/audits were preserved. Commands were scoped file reads, Python parsing, and read-only GitHub official source queries. No root Mix, tests, CI mutation, or production changes. All commands completed. Sol repair increment0; Astra increment0; parent counters unchanged. Foundation monitoring remains a separate outstanding assignment.
