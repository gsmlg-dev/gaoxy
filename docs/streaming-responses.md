# Request and streaming response lifetimes (0.12.0)

HTTP/1 SSE and HTTP/2 streaming responses can explicitly outlive the ordinary
absolute request deadline. Defaults remain finite. Use a route-level selection
before starting the response:

```elixir
conn
|> Gaoxy.HTTP.put_stream_timeout(:infinity)
|> Plug.Conn.put_resp_content_type("text/event-stream")
|> Plug.Conn.send_chunked(200)
```

Alternatively, set the streaming default on a dedicated listener:

```elixir
Gaoxy.HTTP.start_link(
  plug: {MyStreamPlug, []},
  http_limits: %{request_timeout: 30_000, stream_timeout: :infinity}
)

# Phoenix Endpoint configuration
config :my_app, MyAppWeb.Endpoint,
  adapter: Gaoxy.PhoenixAdapter,
  http: [port: 4000, http_limits: %{stream_timeout: :infinity}]
```

`stream_timeout` accepts `:request` (the default, retaining the configured
request deadline), `:infinity`, or positive milliseconds measured from streaming
response start. `Gaoxy.HTTP.put_stream_timeout(conn, :request)` restores the
request lifetime for that route: it is finite under the default request policy
and infinite when `request_timeout: :infinity` was explicitly selected.
Ordinary `send_resp` and `send_file` responses retain the request lifetime.

The request body must be completely consumed before selecting a different
stream lifetime at `send_chunked`. A response stream policy does not extend an
upload or work before that transition. Header acquisition and body reads keep
their finite inactivity limits; the configured request deadline applies until
the transition. An unconsumed body rejects the streaming transition.

Each write still has a finite `write_timeout`, including H2 flow-control waits;
owner calls are finite. Infinite response lifetime removes the absolute
watchdog, so applications should enforce any desired heartbeat/idle policy in
their stream loop. It does not change admission slots, retained-byte budgets,
instance shutdown deadlines or application subscription ownership.

## Uploads and file responses

For storage handlers that must continue while data progresses, native
HTTP/1 and HTTP/2 listeners accept an explicit whole-request opt-in:

```elixir
Gaoxy.HTTP.start_link(
  plug: {MyStoragePlug, []},
  http_limits: %{
    request_timeout: :infinity,
    header_timeout: 5_000,
    read_timeout: 5_000,
    write_timeout: 5_000
  }
)
```

The same `http_limits` apply to `Gaoxy.HTTP.child_spec/1`, native endpoint
specifications and ordinary Plug targets through ListenerSet or Phoenix:

```elixir
config :my_app, MyAppWeb.Endpoint,
  adapter: Gaoxy.PhoenixAdapter,
  http: [port: 4000, http_limits: %{request_timeout: :infinity}]
```

This policy covers `Plug.Conn.read_body/2`, ordinary responses and `Plug.Conn.send_file/3` (including offset/length variants), or the
corresponding native Exchange/Response operations. It removes the total request
watchdog without requiring a `send_chunked` transition. The default remains
30,000 ms; a positive finite `request_timeout` still caps the entire request,
even when body reads keep making progress.

Header acquisition, each body-read wait and each socket write retain finite
limits. H2 flow-control waits, admission slots, byte budgets, backpressure,
client cancellation and finite shutdown deadlines remain in force. Body-size
and Plug parser limits are independent of the time policy. Trusted application
code that waits or computes without I/O can run indefinitely under this opt-in;
applications own any additional execution, heartbeat or idle policy and should
poll for peer cancellation when waiting.

This opt-in supports native H1/H2 requests with ordinary native or Plug targets.
HTTP/3 and `Gaoxy.HTTP.Generation` targets, including managed gateway targets,
reject it with `:unsupported_request_timeout` (possibly inside a configuration
error). Wrapping a Generation target in ListenerSet does not add support;
ListenerSet and Endpoint-owned Phoenix with ordinary Plug targets can use it.
The target and protocol determine support.

## Polling, completion and cancellation

Applications waiting for PubSub or notification messages should poll for peer
closure at a finite cadence. The public Plug helper preserves adapter state:

```elixir
def stream(conn) do
  receive do
    {:event, bytes} ->
      case Plug.Conn.chunk(conn, bytes) do
        {:ok, conn} -> stream(conn)
        {:error, _reason} -> conn
      end

    :complete ->
      conn
  after
    1_000 ->
      case Gaoxy.HTTP.poll_connection(conn, 0) do
        {:pending, conn} -> stream(conn)
        {:more, conn} -> conn
        {:error, _reason, conn} -> conn
      end
  end
end
```

`:more` retains received input and is subject to the input-buffer limit. A
response-only SSE loop may end on unexpected input. A native endpoint uses
`Gaoxy.HTTP.Exchange.put_stream_timeout/2`, `poll_connection/2`, and the
protocol-neutral `Gaoxy.HTTP.Response` operations directly.

Returning the connection finishes a stream normally. Call
`Gaoxy.HTTP.abort(conn, reason)` to close an H1 response or reset only the current
H2 stream. H1 returns `{:ok, conn}`; H2 reset joins the calling stream worker, so
the caller can terminate before observing a return. Client close/reset and
finite instance shutdown also reclaim workers and admission resources. Keep
subscription cleanup tied to worker ownership/monitoring; a worker forcibly
stopped at the shutdown deadline cannot run application `after` callbacks.

HTTP/3 uses its existing finite request contract. Its public configuration rejects
an infinite request lifetime with `:unsupported_request_timeout` and a different
streaming lifetime with `:unsupported_stream_timeout`. Its runtime rejects a
route-level stream transition before modifying a lease. Do not apply infinite
listener defaults to an H3 role.

This public API also resolves the active Phoenix AI response requirement in
[internal request #7](https://github.com/gsmlg-dev/gaoxy/issues/7). The Phoenix
regression proves delivery across multiple request intervals, explicit finite
route behavior and worker reclamation on client close.
