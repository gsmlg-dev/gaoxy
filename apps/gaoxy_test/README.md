# Gaoxy.Test

Real, isolated HTTP fixtures with atomic expectations and ordinary Plug handlers.
Install the aligned package as a test-only dependency:

```elixir
{:gaoxy_test, "~> 0.11.1", only: :test}
```

The application starts fixture supervision, but starts no listener until `open/1`.
Do not add `runtime: false`. The helper never starts ExUnit for its consumer.

```elixir
test "fetches a resource" do
  fixture = Gaoxy.Test.open()

  Gaoxy.Test.expect_once(fixture, :get, "/resource", fn conn ->
    assert conn.query_string == "format=text"
    Plug.Conn.send_resp(conn, 200, "resource")
  end)

  # Exercise your HTTP client with Gaoxy.Test.url(fixture, "/resource?format=text").
  # The per-test on_exit hook verifies expectations and closes the fixture.
end
```

Automatic mode belongs in a test body or per-test `setup`, not `setup_all`.
Shared fixtures require explicit manual ownership, verification and closure:

```elixir
fixture = Gaoxy.Test.open(mode: :manual, profile: :https)
Gaoxy.Test.expect(fixture, :post, "/upload", fn conn ->
  {:ok, body, conn} = Plug.Conn.read_body(conn)
  Plug.Conn.send_resp(conn, 201, body)
end, times: 2)

info = Gaoxy.Test.info(fixture)
# Configure the client to trust info.tls.cacertfile; retain hostname verification.
# Exercise Gaoxy.Test.url(fixture, "/upload") twice.
:ok = Gaoxy.Test.verify_and_close!(fixture)
```

`expect/5` requires at least one admission, `times: n` requires exactly `n`, and
`stub/4` has no count obligation. Duplicate exact routes are rejected. Methods
normalize to uppercase and paths exclude queries. Reservation is atomic across
concurrent streams; callbacks execute outside the coordinator. Assertions,
exceptions, throws and exits remain verification failures even when a client
accepts the resulting error response. Ordinary Plug body reads stay lazy.

`requests/1` returns a bounded journal with truncation accounting; journal eviction
does not discard failures or obligations. `capture_body: bytes` opts into bounded
body observation as the callback reads. `await_request/3` accepts an exact
`%{method: ..., path: ..., after: cursor}` matcher and returns `{:ok, entry}` or
`{:error, :timeout}`. `verify!/2` checks a snapshot without closing the fixture.
`close/2` returns a final report; `verify_and_close!/2` raises on failures.
Terminal options accept a finite positive `timeout:` in milliseconds.

## Profiles and trust

| Profile | Actual wire protocol | Streaming/SSE | WebSocket helper |
| --- | --- | --- | --- |
| `:http1` (default) | TCP HTTP/1.1 | Finite and persistent SSE | H1 |
| `:https` | TLS HTTP/1.1, ALPN `http/1.1` | Finite and persistent SSE | H1 over TLS |
| `:h2c` | TCP HTTP/2 prior knowledge | Finite and persistent SSE | Unsupported |
| `:http2` | TLS HTTP/2, ALPN `h2` | Finite and persistent SSE | Unsupported |
| `:http3` | Optional UDP/QUIC HTTP/3, ALPN `h3` | Finite and persistent SSE | Unsupported |

Profiles never fall back. Addresses are loopback and ports are OS-assigned.
`info/1` exposes the actual bound endpoints, selected profile, readiness,
capabilities and TLS trust, plus opaque fixture identity. H3 uses an ordinary
`https://` URL with its UDP endpoint; configure the client to require HTTP/3.
Explicit H3 requires an additional aligned `gaoxy_http3` dependency. Ordinary
H1/H2 consumers need no H3/QUIC/ExSSL, proxy, standalone, HTTPFetch or WebSocket
client packages. An unavailable H3 dependency fails preflight before listener
allocation. Production consumers should use `only: :test` to exclude the helper.

TLS assets live in packaged `priv/tls` and resolve through the OTP application
directory. The dedicated test CA signs one leaf for DNS `localhost` and IP
`127.0.0.1`, with `serverAuth` purpose and approximately twenty-year validity
(through October 2046). The leaf private key is intentionally public test data;
the CA private key is not shipped. These assets are exclusively for test fixtures.
Use `info.tls.cacertfile` with normal peer and hostname verification. No runtime
certificate generation or machine trust-store installation is needed.

## Streaming and observations

```elixir
Gaoxy.Test.expect_once(fixture, :get, "/chunks", fn conn ->
  Gaoxy.Test.Response.stream(conn, 200, ["one", "two"], headers: [{"x-test", "yes"}])
end)

Gaoxy.Test.expect_once(fixture, :get, "/events", fn conn ->
  Gaoxy.Test.SSE.stream(conn, [%{event: "update", id: "7", data: "first\nsecond"}, "last"])
end)
```

`Response.send/4` supplies optional headers; `Response.redirect/3` supplies a
location and optional status. Finite streams accept a list of iodata chunks.
SSE text and `%{data: text, event: name, id: id, retry: milliseconds}` events
encode multi-line data correctly; only `:data` is required.

For a persistent SSE response, use `SSE.open(conn, initial_events, timeout: 30_000)`.
It emits headers and initial events before establishing the session. The session
PID is the request process. `SSE.send_event(pid, event)` emits another event and
`SSE.finish(pid)` completes normally. Its total lifetime has a finite timeout.
Only successfully established sessions may be cancelled by fixture shutdown;
ordinary blocked callbacks and failures before establishment still fail.

The fixture owner receives event-driven observations:

```elixir
{:gaoxy_test_event, fixture_id, request_id, event}
```

Use `Gaoxy.Test.info(fixture).fixture_id` to select the fixture. Events also appear
in its bounded request journal. `event.type` includes `:stream_headers`,
`:stream_chunk`, `:stream_complete`, `:sse_event`, `:sse_established`, and
`:session_cancelled`. Establishment events contain `:session`; SSE event
observations contain `:event`. Wait on these messages for deterministic barriers.
Cancellation and failure observations remain distinct from successful completion.

## H1 WebSocket

```elixir
Gaoxy.Test.expect_once(fixture, :get, "/socket", fn conn ->
  Gaoxy.Test.WebSocket.upgrade(conn, echo: true)
end)
```

The helper implements the public WebSock callbacks through Plug's public upgrade
API. Echo is enabled by default; `echo: false` observes incoming messages without
echoing. WebSock wire options such as `timeout`, `callback_timeout`, `close_timeout`
and `max_lifetime` pass through the server's normal finite validation.
`:websocket_established` is emitted only from WebSock initialization after the
successful wire handshake. Incoming/outgoing observations are
`:websocket_received`/`:websocket_sent`, with `:opcode` and `:payload`.
`WebSocket.send(session, :text | :binary, payload)` queues an outgoing message;
its observation describes the handler push, not proof of client receipt.
`WebSocket.close(session, 1000, "bye")` starts a controlled close. Termination
emits `:websocket_closed`; abnormal termination records a session failure.
Extended CONNECT over H2/H3 is outside this helper's scope.

## Ownership and public integration

Each fixture owns one public Gaoxy runtime. Normal close, owner exit and final
verification share bounded finalization. Successfully established persistent
sessions receive `{:gaoxy_test_cancel, :fixture_close}`; pre-establishment failures
and ordinary callbacks retain their obligations. The server independently monitors
the coordinator, and its runtime monitors its owner, so abrupt coordinator loss
cannot restart an empty fixture or leave its sockets running. Cleanup errors
remain errors. A finite retained report supports automatic ExUnit teardown and
immediate repeated manual close; expired or missing state fails verification.

The adapter uses `Gaoxy.HTTP.service_spec/1`, optional
`Gaoxy.HTTP.HTTP3.service_spec/1`, and public `Gaoxy.info/2`/`Gaoxy.stop/2`.
Gaoxy 0.8's declarative `ListenerSet.plan/1` deliberately rejects PIDs and
references, while the dispatch bridge requires a per-fixture coordinator PID and
reference. The direct service APIs preserve that identity without a registry or
another listener abstraction. Independent raw/negative peers remain useful for
malformed framing and exact reset tests; this package does not replace them.

## Local verification

From the umbrella root, after installing normal dependencies and independent
Python peers (`h2` and `aioquic`):

```sh
GAOXY_QUIC_PYTHON="$PWD/.audit/h2peer/bin/python" MIX_ENV=test \
  mix test apps/gaoxy_test/test/protocol_test.exs apps/gaoxy_test/test/helper_test.exs
```

The network tests require those peers and fail explicitly if unavailable. They
exercise actual protocol negotiation, verified TLS, multiplexing, uploads,
finite responses/SSE, persistent cancellation, WebSocket interaction, and socket
cleanup with finite deadlines. Isolated staged/Hex consumers and production
closure checks are separate integration gates.
