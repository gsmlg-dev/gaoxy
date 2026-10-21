# Gaoxy HTTP

`gaoxy_http` serves Plug and Phoenix applications with Gaoxy's native HTTP/1.1,
HTTP/2 and WebSocket implementations. Gaoxy owns listener supervision and
connection admission; Hell provides TCP and OTP TLS. Bandit is not required.

Requires Elixir `~> 1.18`. Package version: **0.9.0**.

## Install

For a Plug application, add:

```elixir
{:gaoxy_http, "~> 0.9.0"}
```

For Phoenix, use both dependencies below, keeping your existing Phoenix,
LiveView and application dependencies:

```elixir
{:gaoxy_http, "~> 0.9.0"},
{:websock_adapter, "~> 0.9.0", hex: :gaoxy_websock_adapter, override: true}
```

`gaoxy_websock_adapter` is the Hex package name; its OTP application and module
names remain `websock_adapter` and `WebSockAdapter`. The override selects the
Gaoxy-compatible adapter for Phoenix's existing dependency. Remove your
explicit `{:bandit, ...}` dependency, then run `mix deps.get`.

## Supervise a Plug server

Define an ordinary Plug:

```elixir
defmodule MyApp.HealthPlug do
  import Plug.Conn

  def init(options), do: options
  def call(conn, _options), do: send_resp(conn, 200, "ok\n")
end
```

Add the server to your application's supervision tree:

```elixir
children = [
  {Gaoxy.HTTP,
   id: :web,
   plug: {MyApp.HealthPlug, []},
   ip: {127, 0, 0, 1},
   port: 4000}
]

Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
```

Start your application with `mix run --no-halt`, then request
`http://localhost:4000`. Give each supervised server a distinct `:id`.
`Gaoxy.HTTP.start_link/1` is also available for manual startup. Its default port
is `0` (an ephemeral port), unlike the Phoenix adapter's fixed defaults.

## Use Gaoxy as Phoenix's server

In `config/config.exs`, select the adapter on your existing Endpoint:

```elixir
config :my_app, MyAppWeb.Endpoint,
  adapter: Gaoxy.PhoenixAdapter,
  websocket_paths: ["/live/websocket", "/socket/websocket"]
```

Edit existing listener definitions in every imported config file, then configure
the development listener in `config/dev.exs`. Config merges nested keyword lists,
so adding a later block can retain obsolete Bandit keys from an earlier file.
Remove unsupported listener keys at their original definitions.

```elixir
config :my_app, MyAppWeb.Endpoint,
  server: true,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  https: false,
  code_reloader: true
```

Keep the Endpoint in your application supervisor, along with its existing
PubSub and other children. Keep the Endpoint's router, plugs, socket routes,
session configuration and secrets. For Phoenix 1.8 development code reload,
ensure `project/0` in `mix.exs` includes `listeners: [Phoenix.CodeReloader]`
(merge with existing listeners), and retain `plug Phoenix.CodeReloader` inside
the Endpoint's `if code_reloading?` block.

Run `mix phx.server` or `iex -S mix phx.server`. In IEx, inspect the actual bind
address with:

```elixir
Gaoxy.PhoenixAdapter.server_info(MyAppWeb.Endpoint, :http)
# => {:ok, {{127, 0, 0, 1}, 4000}}
```

The Endpoint owns its Gaoxy instance. Do not add a second `Gaoxy.HTTP` child
for the same Endpoint. The
[Phoenix migration guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/phoenix.md)
covers production runtime configuration, TLS and externally mounted Endpoints.

## TCP, TLS and HTTP/2

| Listener | Default protocol | Explicit alternatives |
|---|---|---|
| Plain TCP / Phoenix `http` | HTTP/1.1 | `protocols: [:http2]` or `[:http2, :http1]`, with `h2c: :prior_knowledge` |
| TLS / Phoenix `https` | HTTP/2 preferred, HTTP/1.1 fallback | `protocols: [:http1]` or `[:http2]` |

To serve H1 and prior-knowledge H2 on the same TCP port, set:

```elixir
{Gaoxy.HTTP,
 plug: {MyApp.HealthPlug, []},
 port: 4000,
 protocols: [:http2, :http1],
 h2c: :prior_knowledge}
```

The same protocol options work inside Phoenix's `http: [...]`. Plain TCP stays
H1-only with h2c disabled by default; `protocols: [:http2]` with prior knowledge
retains H2-only behavior. Mixed mode compares the complete 24-byte H2 client
preface incrementally; a mismatch selects H1, and the selection lasts for that
connection. HTTP/1 `Upgrade: h2c` is unsupported. Protocol values are `:http1`
and `:http2`; a mixed list must use the order `[:http2, :http1]`. There is no
`:auto` option.

Idle handling applies before the first byte. From first input, detection has
one fixed deadline: the minimum of `http_limits.header_timeout`,
`http_limits.request_timeout` and `h2_limits.frame_timeout`. Further prefix
bytes do not extend it. H1's first header/request budgets and H2's startup
allowance retain that first-input time; H2 startup completes only when the
client acknowledges server SETTINGS. H2's separate partial-frame timer remains
in effect.

A standalone Plug TLS listener uses a **map** for `:tls`:

```elixir
{Gaoxy.HTTP,
 id: :secure_web,
 plug: {MyApp.HealthPlug, []},
 transport: :tls,
 ip: {127, 0, 0, 1},
 port: 4443,
 tls: %{certfile: "/run/secrets/fullchain.pem", keyfile: "/run/secrets/privkey.pem"}}
```

Phoenix instead accepts `certfile` and `keyfile` directly inside its `https`
keyword list. Verified client certificates use `verify: :verify_peer`,
`cacertfile` and `fail_if_no_peer_cert`; see the
[client-certificate guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/client-certificates.md).
TLS defaults to TLS 1.3. Protocol selection supplies matching
ALPN automatically; normally leave `:alpn` unset.

## Limits and WebSockets

`limits`, `http_limits` and `h2_limits` are maps. For example, inside a Phoenix
`http` or `https` listener, or as top-level `Gaoxy.HTTP` options:

```elixir
http_limits: %{max_body_bytes: 16_777_216, request_timeout: 120_000},
limits: %{max_active: 128, max_bytes: 536_870_912}
```

The default request body ceiling is 8 MiB, header ceiling 32 KiB, and whole
request/response deadline 30 seconds. SSE routes can explicitly select an
unbounded response lifetime with `Gaoxy.HTTP.put_stream_timeout(conn, :infinity)`
before `send_chunked/2`; finite header, body-read and write deadlines remain in
effect. A listener default uses `http_limits: %{stream_timeout: :infinity}`.
See the [streaming guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/streaming-responses.md)
for cancellation and shutdown. H1's default service byte budget is 1 MiB; selecting
H2 raises the omitted `max_bytes` default to 256 MiB. These are resource
budgets, not preallocated buffers or guarantees that a request will be admitted.
H2 defaults to 32 concurrent streams per connection; resource admission also
applies. See the migration guide's complete option and limit tables before
lowering H2 budgets or raising parser limits.

Ordinary H1 WebSocket Upgrade uses Phoenix's existing socket routes. To permit
native H2 WebSocket extended CONNECT, set `extended_connect: true` on that
listener and list each exact Phoenix transport path in Endpoint-level
`websocket_paths`. For example:

```elixir
config :my_app, MyAppWeb.Endpoint,
  adapter: Gaoxy.PhoenixAdapter,
  websocket_paths: ["/live/websocket", "/socket/websocket"],
  https: [
    port: 4443,
    certfile: "/run/secrets/fullchain.pem",
    keyfile: "/run/secrets/privkey.pem",
    extended_connect: true
  ]
```

Keep Phoenix's Origin, session and authentication policies. WebSocket
compression is unsupported; `compress: true` is rejected. An omitted message
ceiling follows `max_frame_size`; both remain subject to the service budget. See
[WebSocket limits](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/websocket-limits.md).
The client chooses
its WebSocket transport, so an HTTP/2 page alone does not prove H2 WebSockets.

HTTP/3 is provided by the separate optional `Gaoxy.HTTP.HTTP3` service; it is not an
`https` protocol value. See
[HTTP/3 setup](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/http3.md).

## Further reading

- [Phoenix migration and configuration](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/phoenix.md)
- [Native HTTP API, protocol boundaries and WebSock limits](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/native-http.md)
- [Runnable Phoenix example](https://github.com/gsmlg-dev/gaoxy/blob/main/examples/phoenix_native/README.md)
- [WebSock adapter provenance](https://github.com/gsmlg-dev/gaoxy/blob/main/vendor/websock_adapter/GAOXY.md)
