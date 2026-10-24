# Gaoxy WebSockAdapter

[`gaoxy_websock_adapter`](https://hex.pm/packages/gaoxy_websock_adapter) is the
Gaoxy distribution of Phoenix's WebSockAdapter. It connects
`WebSockAdapter.upgrade/4` to `Gaoxy.PlugAdapter` and validates native HTTP/2
and HTTP/3 WebSocket extended CONNECT requests, including Phoenix requests
whose method is temporarily presented as GET.

Use this package with `gaoxy_http` when serving Phoenix Channels, LiveView or
a Plug that upgrades connections to WebSocket. Its public modules and OTP
application keep the upstream name **`WebSockAdapter` / `:websock_adapter`**.
Its package version follows Gaoxy, currently **0.11.0**; the upstream source
base is WebSockAdapter **0.6.0**.

## Installation

Add these entries to your application's `mix.exs` dependencies:

```elixir
{:gaoxy_http, "~> 0.11.0"},
{:websock_adapter, "~> 0.11.0", hex: :gaoxy_websock_adapter, override: true}
```

Then run `mix deps.get`. The override makes Phoenix's existing
`:websock_adapter` dependency resolve to this distribution. Keep the override
while using Gaoxy; selecting the canonical upstream package removes Gaoxy
dispatch and native H2/H3 validation.

## Phoenix configuration

Replace the explicit Bandit dependency with the dependencies above and select
Gaoxy in `config/config.exs`:

```elixir
config :my_app, MyAppWeb.Endpoint,
  adapter: Gaoxy.PhoenixAdapter
```

For local development, configure `config/dev.exs`:

```elixir
config :my_app, MyAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  server: true
```

Keep the Endpoint under your application's supervisor and start it with
`mix phx.server`. Phoenix continues to own socket declarations, authentication,
Origin checks and LiveView settings. Ordinary H1 WebSocket upgrades use your
existing socket paths.

For persistent Channels and LiveView connections, explicitly disable Phoenix's
inactivity default through the public Endpoint socket configuration:

```elixir
socket "/socket", MyAppWeb.UserSocket,
  websocket: [timeout: :infinity],
  longpoll: false

socket "/live", Phoenix.LiveView.Socket,
  websocket: [timeout: :infinity, connect_info: [session: @session_options]],
  longpoll: false
```

Keep your existing session options. Phoenix inserts a finite timeout before the
adapter receives the upgrade; this explicit integration setting keeps healthy
quiet connections open. Gaoxy leaves omitted frame/message limits unbounded;
this distribution preserves that omission. Explicit application limits still
apply. The upstream frame default for other adapters remains unchanged.

For native WebSocket over HTTP/2, add exact paths at the Endpoint level and
enable extended CONNECT on the HTTPS listener:

```elixir
config :my_app, MyAppWeb.Endpoint,
  websocket_paths: ["/live/websocket", "/socket/websocket"],
  https: [
    ip: {127, 0, 0, 1},
    port: 4040,
    certfile: "/absolute/path/to/cert.pem",
    keyfile: "/absolute/path/to/key.pem",
    extended_connect: true
  ]
```

The paths must match sockets actually declared by your Endpoint; include the
`/websocket` suffix. These settings enable the server capability. The client
selects the WebSocket transport. HTTP/3 uses a separate optional
`Gaoxy.HTTP.HTTP3` service and external Endpoint mount.

See the [complete Phoenix and Bandit migration guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/phoenix.md)
for production configuration, development code reload, supported listener
options and HTTP/3 setup.

## Upgrade a Plug connection

Define a WebSock handler and route an upgrade through your Plug:

```elixir
defmodule MyApp.EchoSocket do
  @behaviour WebSock

  def init(state), do: {:ok, state}

  def handle_in({data, [opcode: opcode]}, state) when opcode in [:text, :binary],
    do: {:reply, :ok, {opcode, data}, state}

  def handle_info(_message, state), do: {:ok, state}
end

defmodule MyApp.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/websocket" do
    conn
    |> WebSockAdapter.upgrade(MyApp.EchoSocket, nil, timeout: :infinity)
    |> halt()
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
```

Supervise `{Gaoxy.HTTP, plug: {MyApp.Router, []}, port: 4000}` and connect a
WebSocket client to `ws://localhost:4000/websocket`. This example serves H1;
native H2/H3 requires the protocol-specific listener and routing setup in the
[HTTP guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/native-http.md).

Early upgrade validation is enabled by default. Leave it enabled. Gaoxy also
validates the handshake and owns transport/lifecycle enforcement. WebSocket
compression is unsupported; use `compress: false` when an existing socket
explicitly enabled it.

## Upstream source and license

The source checkout preserves the upstream `README.md` unchanged. Hex staging
uses this Gaoxy guide as `README.md` and retains the upstream document as
`README.upstream.md`. The package also includes `GAOXY.md`, `SOURCE.json`,
`gaoxy.patch`, the upstream changelog and licenses. `SOURCE.json` describes the
vendored snapshot paths; its `README.md` hash refers to the retained upstream
document.

See [snapshot provenance](https://github.com/gsmlg-dev/gaoxy/blob/main/vendor/websock_adapter/GAOXY.md)
and [upstream WebSockAdapter](https://github.com/phoenixframework/websock_adapter).
MIT; upstream `LICENSE` is retained and Gaoxy's license is included as
`LICENSE.gaoxy` in the Hex package.
