# Issue #14: graceful Phoenix disconnect broadcasts

## Scope and design

Treat exactly `{:shutdown, :disconnected}` as WebSock normal closure. Phoenix
1.8.16 returns this reason from `Phoenix.Socket.__info__/2` for its standard
`%Phoenix.Socket.Broadcast{event: "disconnect"}`. The three-element stop result
must select wire close code 1000; termination must receive `:normal`.

Keep the existing 1012/`:shutdown` handling for `{:shutdown, :restart}` and the
1011/error handling for arbitrary stop reasons. Explicit close codes, close
text and final application messages stay authoritative. No dependency patch
or generalized graceful-shutdown rule is needed.

## Implementation and acceptance

- [x] Reproduce the missing code and termination mapping with controlled stream
  transport tests before the production edit.
- [x] Add only the two exact-match disconnected branches in `WebSocket.result/2`.
- [x] Check normal, disconnected, restart, arbitrary shutdown/error, explicit
  close-code and final-message behavior in the shared WebSocket stream engine.
- [x] Exercise an actual Phoenix endpoint and joined channel over a loopback H1
  WebSocket. Broadcast through `Endpoint.broadcast/3`, inspect wire close 1000,
  acknowledge the close and monitor transport/channel cleanup and TCP EOF.
- [x] Run scoped tests and formatting checks.
- [x] Parent integrates manifest classification and independent review, followed
  by fresh ordinary and full Phoenix fixture verification.
- [ ] Coordinated package publication and fresh public consumer validation under
  the release plan.

The existing `websocket_stream_test.exs` is controlled component coverage and
now executes 14 tests (previously 6). Schedule it in the component suite and
remove its `existing_not_scheduled` inventory entry. The existing Phoenix
compatibility test file increases from 5 to 6 component tests and remains in
the Phoenix fixture gate. No real listener is added to a unit suite.

## Verification evidence — 2026-10-22

Checkout: `/home/gao/Workspace/gsmlg-opt/gaoxy`, shared `main`, baseline
`0b3f97fc08549649b4b367e3a85a8526e162f53f`; Elixir 1.18.5, OTP 28, Linux.
Other concurrent issue fixes are outside this task's ownership.

Before the production change:

- `mix test apps/gaoxy_http/test/websocket_stream_test.exs --warnings-as-errors`:
  14 tests, 2 failures, exit 2. The disconnected case emitted 1011; its explicit
  close-code variant reported `{:error, {:shutdown, :disconnected}}` to terminate.
  The six other new stop-contract cases and six existing cases passed.
- In `examples/phoenix_native`,
  `PHOENIX_NATIVE_H3=1 mix test test/websocket_phoenix_compatibility_test.exs --warnings-as-errors --only line:141`:
  one executed test, one failure, five excluded, exit 2. The actual Phoenix
  disconnect broadcast produced close payload `<<3, 243>>` (1011), expected 1000.
  This line selection was used only to establish RED, not as an acceptance gate.

After the two production branches and test-fixture correction:

- `mix test apps/gaoxy_http/test/websocket_stream_test.exs --warnings-as-errors`:
  **PASS**, 14 tests, 0 failures, exit 0.
- In `examples/phoenix_native`,
  `PHOENIX_NATIVE_H3=1 mix test test/websocket_phoenix_compatibility_test.exs --warnings-as-errors`:
  **PASS**, 6 tests, 0 failures, exit 0. Full output from this run is locally at
  `/tmp/gaoxy-issue14-phoenix-green.log` (temporary, not a release artifact).
- `mix format --check-formatted apps/gaoxy_http/lib/gaoxy/http/websocket.ex apps/gaoxy_http/test/websocket_stream_test.exs examples/phoenix_native/test/websocket_phoenix_compatibility_test.exs`:
  **PASS**, exit 0.
- `git diff --check`: **PASS**, exit 0.

The initial fixture run without `PHOENIX_NATIVE_H3=1` could not start the cached
fixture because `gaoxy_http3.app` was absent. Enabling the fixture's existing H3
dependency switch resolved that environment mismatch; the disconnect test itself
uses H1 only. The first full green attempt reached close 1000 but failed an
incorrect test assumption that the H1 owner exits with `:normal`. Existing H1
connection shutdown uses `{:shutdown, :local_closed}`, which Phoenix propagates
to the channel. The cleanup regression now requires that exact existing reason;
the stream component regression independently requires WebSock terminate
`:normal`. No production change beyond the two disconnected branches was needed.

Sol repair rounds: 1 (test-fixture cleanup-reason correction), successful.
Astra rounds: 0. Publication and downstream consumer validation belong to the
parent release task and are not claimed by these scoped source checks.
