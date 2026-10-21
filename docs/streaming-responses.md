# Long-lived streaming responses (0.9.0)

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

`stream_timeout` accepts `:request` (the default, retaining the original absolute
request deadline), `:infinity`, or positive milliseconds measured from streaming
response start. `Gaoxy.HTTP.put_stream_timeout(conn, :request)` keeps a particular
route finite even on an infinite-stream listener. Ordinary `send_resp` and
`send_file` responses retain the request deadline.

The request body must be completely consumed before selecting a different
stream lifetime at `send_chunked`. Header acquisition, upload, body reads and
work before that transition retain finite `request_timeout`, `header_timeout`
and `read_timeout`. These options still reject `:infinity`. An unconsumed body
rejects the streaming transition instead of extending an upload indefinitely.

Each write still has a finite `write_timeout`, including H2 flow-control waits;
owner calls are finite. Infinite response lifetime removes the absolute
watchdog, so applications should enforce any desired heartbeat/idle policy in
their stream loop. It does not change admission slots, retained-byte budgets,
instance shutdown deadlines or application subscription ownership.

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
a different streaming lifetime with `:unsupported_stream_timeout`, and its
runtime rejects a route-level transition before modifying a lease. Do not apply
infinite listener defaults to an H3 role. This release adds no H3 infinite-stream
acceptance claim.

This public API also resolves the active Phoenix AI response requirement in
[internal request #7](https://github.com/gsmlg-dev/gaoxy/issues/7). The Phoenix
regression proves delivery across multiple request intervals, explicit finite
route behavior and worker reclamation on client close.
