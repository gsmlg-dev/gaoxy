# Independent review: HTTP/2 Exchange accounting compatibility

Reviewer: Sol (`websocket_limits`), independent of the one-line repair author.
Checkout: `main`, baseline `32933790457bcfa3533e40dc2ae4d51ad91aa86d`.

Verdict: **PASS — no actionable findings**.

The streaming change adds `stream_timeout: nil` to every newly constructed
`Gaoxy.HTTP.Exchange`. `HTTP2.WorkerAccounting` independently enumerates the
complete initial Exchange as a numeric ETF constructor. Omitting this new field
under-counted it by 21 bytes; the existing independent `%Exchange{}` constructor
tests correctly reported six failures out of seven. Adding exactly
`stream_timeout: e(nil)` restores the complete initial map model. It does not
change assertions, substitute a budget constant or weaken the exact arithmetic.
No other hand-enumerated Exchange numeric maps were found in HTTP/proxy runtime.

Failing candidate evidence remains
`.audit/release-0.9.0/ordinary-final-candidate-1.log`. The author reran
`python3 scripts/check-tests.py apps/gaoxy_http/test/http2_worker_accounting_test.exs`:
7 tests, 0 failures, exit 0, recorded in
`.audit/internal-requests/3/worker-accounting-green.log`. The reviewer inspected
that actual result, the one-line production diff and unchanged independently
instantiated `%Exchange{}` test constructors. No redundant Mix run or source
mutation was performed by this reviewer. Final ordinary compatibility is a
separate release-owner gate.
