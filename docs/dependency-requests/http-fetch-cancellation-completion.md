**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m2-native`

**Severity:** blocker

Gaoxy M2 must cancel a streaming upstream request on downstream disconnect,
connection-owner death, and service drain, and distinguish confirmed cleanup
from cleanup still pending at its deadline. Published HTTP Fetch 0.18.1 fixes
the earlier body and WebSocket blockers, but its public HTTP request API does
not expose request-owned transport cleanup completion.

This request concerns HTTP/1 with `http1_reuse: false`. It does not require
closing unrelated shared pools or proving that a remote application received
earlier bytes.

**Public API sequence:**

```elixir
controller = HTTP.AbortController.new()
promise = HTTP.fetch(url,
  signal: controller,
  http_version: :http1,
  http1_reuse: false,
  redirect: :manual,
  stream_response: true,
  decode_body: false,
  timeout: 10_000
)
response = HTTP.Promise.await(promise)
stream = response.stream
monitor = Process.monitor(stream)
send(stream, {:read_chunk, self(), :ack})
:ok = HTTP.AbortController.abort(controller)
# A stream_error and stream DOWN can confirm stream termination, but the public
# API supplies no request transport completion event/handle to await here.
```

The source at released commit
`f3a72c7b5f059c9862b8fdc0221cffcdaddde301` establishes the distinction:

- `apps/http_fetch/lib/http/abort_controller.ex`: `abort/1` sends `:abort` and
  returns after updating controller state; it does not await request cleanup.
- `apps/http_fetch/lib/http/socket_client.ex`: `await_owner/3` demonitoring and
  returning a streamed response lets the Promise task terminate at response
  headers. `fail/2` signals `HTTP.Stream.error/2` before `finish/1` calls
  transport cleanup. The stream and request owner are separate processes, so
  stream DOWN is not a transport-cleanup barrier.
- The request owner ignores its Promise parent's DOWN after `response_sent?`.
- The README correctly promises that monitoring a stream confirms that
  stream's cleanup; it does not promise request-socket cleanup.

This is a missing public synchronization contract, not a claim that ordinary
cancellation never closes the socket. Eventual peer closure in a test cannot
provide a production completion barrier for a particular request.

**Expected behavior:** Provide a supported request-scoped completion handle or
operation, available before connection establishment, that permits bounded
cancellation and awaiting cleanup across dialing, TLS, upload, and post-header
response streaming. Report success only after request-owned transport/resources
and upload helpers have stopped; distinguish deadline expiry with cleanup
pending. Define cancellation before owner registration, owner death, and
repeated cancellation. A separate completion event or an abort-and-await API
would both satisfy this requirement; API naming is up to the upstream project.

Please cover delayed cleanup with deterministic barriers so a stream terminal
event cannot be mistaken for completed transport teardown. H1 is sufficient
for Gaoxy's current milestone; this request does not add H2/H3 requirements.

Gaoxy will not read AbortController Agent state, inspect upstream process links,
call private SocketClient helpers, or return successful drain on an unconfirmed
abort. HTTP proxy cleanup integration is blocked pending this public contract;
independent native HTTP work can continue.
