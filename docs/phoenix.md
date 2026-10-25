# Phoenix with Gaoxy

This guide migrates an existing Phoenix application from Bandit to
`gaoxy_http` **0.13.0**. It uses `MyAppWeb.Endpoint` and OTP application `:my_app`;
replace those names with your own. The adapter is `Gaoxy.PhoenixAdapter`.
Gaoxy provides the listener and native H1/H2/WebSocket engine, while Phoenix
continues to own the Endpoint pipeline, router, Channels, LiveView, sessions,
Origin checks and application supervision.

## 1. Replace the server dependencies

Remove your explicit `{:bandit, ...}` dependency from `mix.exs`. Add these
entries to your existing `deps/0`, retaining the rest of your application deps:

```elixir
{:gaoxy_http, "~> 0.13.0"},
{:websock_adapter, "~> 0.13.0", hex: :gaoxy_websock_adapter, override: true}
```

The second entry is required for Phoenix: `gaoxy_websock_adapter` is the
published package containing Gaoxy dispatch and native extended-CONNECT
validation. Its application name remains `:websock_adapter`, so use that name
as the dependency key. Do not add both adapter packages under different keys.
Keep this override when upgrading Phoenix until its upstream adapter includes
the required support. See [adapter provenance](../vendor/websock_adapter/GAOXY.md).

Run:

```sh
mix deps.get
mix compile --warnings-as-errors
```

The package requires Elixir `~> 1.18`. The runnable reference uses Phoenix
1.8.16. Keep your normal Phoenix, Plug, LiveView and JSON configuration; adding
Gaoxy does not generate or replace those application files.

## 2. Select the adapter and configure development

Replace `adapter: Bandit.PhoenixAdapter` with `adapter: Gaoxy.PhoenixAdapter`
in the configuration for your Endpoint. If there was no explicit adapter,
add one in `config/config.exs`:

```elixir
import Config

config :my_app, MyAppWeb.Endpoint,
  adapter: Gaoxy.PhoenixAdapter,
  websocket_paths: ["/live/websocket", "/socket/websocket"]
```

Retain your existing `pubsub_server`, `live_view` signing salt, URL, secret,
rendering and error configuration. The path list must reflect socket routes
that actually exist in your Endpoint; remove `/socket/websocket` if you have
no socket mounted at `/socket`. It is used for H2 extended CONNECT, described
below, and does not create Phoenix routes.

In `config/dev.exs`, replace the listener options with supported Gaoxy options:

Edit the original listener definitions in every imported configuration layer
(`config.exs`, environment files and `runtime.exs`). Config recursively merges
keyword lists: appending a new `http` or `https` block can retain unsupported
Bandit keys from an earlier file. Remove those keys at their original definitions.

```elixir
import Config

config :my_app, MyAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  https: false,
  server: true,
  code_reloader: true
```

Keep your existing development secret and Phoenix development settings.
For Phoenix 1.8, include the code-reloader listener in `project/0` in
`mix.exs`, merging it with any existing listeners:

```elixir
listeners: [Phoenix.CodeReloader]
```

Retain the ordinary generated Endpoint code:

```elixir
if code_reloading? do
  plug Phoenix.CodeReloader
end
```

The Gaoxy adapter composes Phoenix's `SyncCodeReloadPlug` when
`code_reloader: true`. Keep your existing live-reload socket and watchers if
you use browser reload; Gaoxy does not configure asset builders.

## 3. Keep the Endpoint supervised and start the server

Leave `MyAppWeb.Endpoint` in your application's existing supervision tree.
A minimal shape is:

```elixir
children = [
  {Phoenix.PubSub, name: MyApp.PubSub},
  MyAppWeb.Endpoint
]

Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
```

Keep your Repo, telemetry, DNS clustering and other existing children, and
preserve `config_change/3` forwarding to the Endpoint. Keep the Endpoint's
router plug, static assets, sessions and socket declarations. Do not add a
separate `Gaoxy.HTTP` child for an Endpoint that owns its listener.

Start from the application directory:

```sh
mix phx.server
# Or, for an interactive node:
iex -S mix phx.server
```

Open `http://localhost:4000`. In the running IEx node:

```elixir
Gaoxy.PhoenixAdapter.server_info(MyAppWeb.Endpoint, :http)
# => {:ok, {{127, 0, 0, 1}, 4000}}
```

`port: 0` selects an ephemeral port; use `server_info/2` to discover it.
`{:error, :not_running}` means the Endpoint's Gaoxy instance is absent.
Phoenix's `server` setting controls listener startup: `server: false` disables
it even if `http` or `https` is configured. In releases, explicitly enable
`server: true`; `PHX_SERVER` alone only works if your `runtime.exs` reads it.

## Production runtime configuration

Read secrets and binding ports in `config/runtime.exs`, so releases use runtime
values. Generate a secret once with `mix phx.gen.secret` and provide it through
your deployment's secret mechanism. Do not copy the example fixture's secret.

For a deployment where an existing reverse proxy terminates TLS and forwards
HTTP to Gaoxy:

```elixir
import Config

if config_env() == :prod do
  config :my_app, MyAppWeb.Endpoint,
    adapter: Gaoxy.PhoenixAdapter,
    server: true,
    url: [scheme: "https", host: System.fetch_env!("PHX_HOST"), port: 443],
    http: [
      ip: {0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT", "4000"))
    ],
    https: false,
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE")
end
```

Use loopback instead of `0.0.0.0` when only a same-host proxy should reach the
listener. The Endpoint's `url` describes the public URL; it does not select the
bind address or enable TLS. Retain your application's trusted proxy and
forwarded-header policy. The protocol between proxy and Gaoxy is determined
by this listener, independently of the browser-to-proxy protocol.

Alternatively, replace that production block with direct OTP TLS termination:

```elixir
import Config

if config_env() == :prod do
  port = String.to_integer(System.get_env("PORT", "8443"))

  config :my_app, MyAppWeb.Endpoint,
    adapter: Gaoxy.PhoenixAdapter,
    server: true,
    url: [scheme: "https", host: System.fetch_env!("PHX_HOST"), port: port],
    http: false,
    https: [
      ip: {0, 0, 0, 0},
      port: port,
      certfile: System.fetch_env!("TLS_CERTFILE"),
      keyfile: System.fetch_env!("TLS_KEYFILE"),
      extended_connect: true
    ],
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE")
end
```

Supply readable PEM files and a certificate chain trusted for `PHX_HOST`.
`https` does not obtain certificates or configure an HTTP-to-HTTPS redirect.
TLS defaults to TLS 1.3 and ALPN `h2`, then `http/1.1`. If you need both TLS
1.3 and TLS 1.2, use `versions: [:"tlsv1.3", :"tlsv1.2"]` in `https`.
Port 8443 avoids requiring a privileged bind; adjust both the public URL and
listener to your deployment.

After building your normal Phoenix release, start it with its existing release
command, for example `_build/prod/rel/my_app/bin/my_app start`, supplying the
environment variables above. Keep ordinary Phoenix asset and database release
steps. This guide changes server configuration, not those application tasks.

## Listener options and protocol selection

The Phoenix adapter accepts only these keys inside `http: [...]` or
`https: [...]`. Unknown keys raise `ArgumentError` during child construction.
These are keyword lists; their three limit values are maps.

| Key | Default / accepted value |
|---|---|
| `ip` | `{127, 0, 0, 1}`; IPv4 or IPv6 address tuple |
| `port` | HTTP `4000`, HTTPS `4040`; integer or decimal string in `0..65535` |
| `protocols` | HTTP `[:http1]`; HTTPS `[:http2, :http1]` |
| `h2c` | `:disabled`; use `:prior_knowledge` with TCP `[:http2]` or `[:http2, :http1]` |
| `extended_connect` | `false`; opt in with `true` for native H2 WebSocket |
| `limits` | `%{}`; merges service admission/lifecycle defaults below |
| `http_limits` | `%{}`; merges HTTP parser/deadline defaults below |
| `h2_limits` | `%{}`; merges H2 limits below |
| `hell_options` | `[]`; validated TCP/TLS backend tuning, described below |
| `certfile`, `keyfile` | HTTPS only, required binary file paths |
| `versions` | HTTPS only, `[:"tlsv1.3"]`; also `[:"tlsv1.2"]` or `[:"tlsv1.3", :"tlsv1.2"]` |
| `alpn` | HTTPS only; automatically derived from `protocols` |
| `verify` | HTTPS only; `:verify_none` default or `:verify_peer` |
| `cacertfile` | HTTPS only; nonempty binary CA path, required for `:verify_peer` |
| `fail_if_no_peer_cert` | HTTPS only; boolean, requires `:verify_peer`; default `false` |

TCP defaults to H1-only with h2c disabled. For H1 and prior-knowledge H2
on the same native listener:

```elixir
http: [ip: {127, 0, 0, 1}, port: 4001, protocols: [:http2, :http1], h2c: :prior_knowledge]
```

Keep the Endpoint as the owner; these options create one HTTP service, with
connection-level protocol selection. For a dedicated H2-only port, select
`protocols: [:http2]` with `h2c: :prior_knowledge` instead. The full 24-byte H2
preface selects H2; the first mismatching byte selects H1. Selection is fixed
for the connection. HTTP/1 `Upgrade: h2c` is unsupported, and there is no
`:auto` setting.

Before first input, the existing idle timeout applies. From the first byte,
detection expires after the minimum of `http_limits.header_timeout`,
`http_limits.request_timeout`, and `h2_limits.frame_timeout`; additional prefix
bytes do not renew it. H1's first header/request budgets and H2's remaining
startup allowance use that original time. H2 startup completes on acknowledgment
of server SETTINGS, and its separate partial-frame timer is preserved.

HTTPS accepts `[:http1]`, `[:http2]` or the default
`[:http2, :http1]`. Leave `alpn` unset unless necessary; if provided, it must
exactly match the selected protocols in order (`["h2", "http/1.1"]`,
`["h2"]` or `["http/1.1"]`). H1-only TLS also permits `alpn: []`.
HTTPS H1 fallback includes clients that do not negotiate ALPN.

For optional verified client certificates on enrollment/runtime listeners, see
[client certificates](client-certificates.md). `verify: :verify_peer` validates
any supplied certificate against `cacertfile`; `fail_if_no_peer_cert: false`
permits anonymous clients. HTTP and WebSocket peer data expose the real TLS DER
certificate, while application authorization decides whether it grants access.

H2 requires the `:inet` TCP backend. For TLS, `Application.get_env(:ssl,
:internal_active_n, 100)` must be an integer in `1..100`; an unsupported host
profile is rejected. See [native HTTP](native-http.md) for the qualified host
profile and protocol boundaries.

### Backend tuning migration

Replace Bandit's `thousand_island_options` with `hell_options` inside each
`http` or `https` listener. The old name is not an alias. For example, migrate:

```elixir
http: [
  port: 4000,
  thousand_island_options: [
    num_acceptors: 4,
    transport_options: [backlog: 2048, nodelay: true]
  ]
]
```

to:

```elixir
http: [
  port: 4000,
  limits: %{max_active: 64},
  hell_options: [
    num_acceptors: 4,
    transport_options: [backlog: 2048, nodelay: true]
  ]
]
```

This gives each of the four acceptors 16 backend connection slots. Gaoxy
retains the service-wide admission and byte budgets. Move connection and
shutdown controls to the existing `limits` fields; arbitrary Thousand Island
options are not portable to Hell. Keep certificates, binding and protocol
policy in their existing listener fields. Remove old options at their original
configuration definitions to prevent Phoenix config merging from retaining them.

For an optional `http3` listener, use
`abyss_options: [event_batch: 16, poll_interval: 5]`. QUIC has no public backend
socket-tuning interface in Abyss 0.9.0. See the complete
[backend support matrix and restrictions](backend-options.md), including the
different UDP buffer API and unused remainders when dividing acceptor slots.

### Service budgets: `limits`

| Key | Default |
|---|---:|
| `max_active` | 64 admission slots |
| `max_bytes` | H1: 1,048,576 bytes; H2 when omitted: 268,435,456 bytes |
| `max_packet`, `max_output` | 65,507 bytes each |
| `max_state` | 65,536 bytes |
| `callback_timeout` | 5,000 ms |
| `idle_timeout` | 30,000 ms |
| `drain_timeout` | 5,000 ms |
| `max_memberships` | 64; relevant to UDP services rather than this HTTP listener |

These are service-wide resource controls, not Bandit/Thousand Island options.
All values are positive integers; `max_packet` cannot exceed 65,507 and
`max_memberships` cannot exceed 64. H2 needs at least three admission slots and
a byte budget covering connection, stream and writer reservations. The default
256 MiB budget passes the default profile; raising H2 header/table or HTTP
buffer limits increases reservations. An explicit smaller budget is validated
and can fail with `:http2_byte_budget`. These limits do not bound total BEAM
memory or allocations made by application code.

### HTTP parser and deadlines: `http_limits`

| Key | Default |
|---|---:|
| `max_request_line` | 8,192 bytes |
| `max_header_bytes` | 32,768 bytes |
| `max_headers` | 100 fields |
| `max_body_bytes` | 8,388,608 bytes |
| `max_chunk_line` | 1,024 bytes |
| `max_trailer_bytes` | 8,192 bytes |
| `max_trailers` | 32 fields |
| `max_read_chunk` | 16,384 bytes |
| `max_buffer_bytes` | 65,536 bytes |
| `request_timeout` | 30,000 ms for ordinary HTTP request/response lifetime |
| `stream_timeout` | `:request`; also `:infinity` or positive response-lifetime milliseconds |
| `header_timeout` | 5,000 ms from the first request byte |
| `read_timeout`, `write_timeout` | 5,000 ms per body read / write |

`request_timeout` also accepts `:infinity` for ordinary H1/H2 native/Plug targets;
all values except `request_timeout` and `stream_timeout` are positive finite
integers. `max_read_chunk` must not exceed `max_buffer_bytes`. For example,
raise the HTTP upload ceiling and request deadline inside the listener with:

```elixir
http_limits: %{max_body_bytes: 16_777_216, request_timeout: 120_000}
```

For explicitly unbounded SSE, call `Gaoxy.HTTP.put_stream_timeout(conn, :infinity)`
in the route before `Plug.Conn.send_chunked/2`, or select a listener default with
`http_limits: %{stream_timeout: :infinity}`. The transition requires request-body
completion and retains finite header/body/write controls and admission budgets.
See [streaming responses](streaming-responses.md) for HTTP/1 and HTTP/2 lifecycle,
polling, cancellation and shutdown. `stream_timeout: :request` retains the
configured request lifetime; it does not itself select a finite timeout.
HTTP/3 does not support this response-stream opt-in.

The separate `request_timeout: :infinity` storage policy covers H1/H2 uploads
and ordinary `send_file` responses without a chunked-response transition.
Ordinary Endpoint-owned Phoenix listeners and ListenerSet Plug targets support
it. Configure it inside the chosen listener:

```elixir
http: [port: 4000, http_limits: %{request_timeout: :infinity}]
```

H3 and Generation targets, including managed gateway targets, reject infinite
requests with `:unsupported_request_timeout` (possibly wrapped as a configuration
error). Wrapping a Generation target in ListenerSet does not add support.
Finite header/read/write limits, admission and shutdown still apply; trusted
application code without I/O owns its own execution/idle policy. See the
[request lifetime guide](streaming-responses.md#uploads-and-file-responses).

HEAD responses preserve validated application Content-Length metadata while
suppressing the wire body. An omitted length is inferred from the body, and
204/205/304 status rules and GET framing retain their existing behavior.

Plug body reads aggregate native pieces up to their logical `:length`, while
`:read_length`, the native chunk cap, cumulative server body limit and per-read
socket timeout remain separate. See the [body-read contract](native-http.md#plug-request-body-reads),
including aggregate byte reservations and the absolute request deadline.
Also retain appropriate Plug parser/upload limits. Increasing the HTTP body
ceiling does not reserve that much service capacity or change LiveView's
application upload rules.

### HTTP/2: `h2_limits`

| Key | Default | Additional constraint |
|---|---:|---|
| `max_streams` | 32 | At most 128 |
| `max_frame` | 16,384 bytes | 16,384–65,535 |
| `max_header_block` | 16,384 bytes | At most 65,536 |
| `table_size` | 4,096 bytes | At most 65,536 |
| `receive_window` | 65,535 bytes | At most 65,535 |
| `frame_timeout` | 5,000 ms | Positive finite integer |
| `control_turn` | 32 frames | At most 128 |
| `control_rate` | 256 frames/second | At most 4,096 |

All are positive integers. `http_limits.max_buffer_bytes` must hold
`h2_limits.max_frame + 9`. Service admission can further restrict streams.

## Channels, LiveView and WebSockets

Use Phoenix's public socket options for persistent WebSockets:

```elixir
socket "/socket", MyAppWeb.UserSocket,
  websocket: [timeout: :infinity],
  longpoll: false

socket "/live", Phoenix.LiveView.Socket,
  websocket: [timeout: :infinity, connect_info: [session: @session_options]],
  longpoll: false
```

Retain your actual `@session_options`, session plug and LiveView configuration.
The HTTP/1 WebSocket Upgrade path works through these routes without
`extended_connect`. For H2 WebSockets, enable both:

```elixir
config :my_app, MyAppWeb.Endpoint,
  websocket_paths: ["/socket/websocket", "/live/websocket"],
  https: [
    port: 4443,
    certfile: "/run/secrets/fullchain.pem",
    keyfile: "/run/secrets/privkey.pem",
    extended_connect: true
  ]
```

`websocket_paths` is an Endpoint-level list, not a listener key. It defaults to
`[]`. Entries are exact, unique paths beginning with `/`; wildcard, query,
fragment and backslash forms are rejected. Include the transport suffix
`/websocket`, accounting for any custom socket path. Include your live-reload
WebSocket path too if it must use H2 extended CONNECT.

The wrapper presents GET to Phoenix only while dispatching an already validated
native WebSocket CONNECT on an allowlisted path. Native protocol metadata is
retained. Phoenix still performs its ordinary Origin, session, CSRF,
authentication and subprotocol checks. Do not disable those checks to make a
migration work.

Phoenix's standard `"disconnect"` broadcast returns
`{:stop, {:shutdown, :disconnected}, state}`. Gaoxy treats this exact reason as
normal WebSock termination and sends close code 1000, matching Bandit. A restart
still sends 1012; arbitrary shutdown/error reasons still send 1011. Explicit
application close codes and final messages remain authoritative. Transport and
channel cleanup follow the close handshake.

The client chooses H1 Upgrade or H2 extended CONNECT; an H2 document load does
not establish which WebSocket protocol was used. `compress: true` and disabling
UTF-8 validation are unsupported. The native engine defaults to infinite
inactivity, lifetime, frame/message and wire-fragment policies. Phoenix supplies
a finite timeout before dispatch, so the explicit `timeout: :infinity` socket
setting above is required for persistence. Omitted frame/message options remain
omitted through the Gaoxy adapter; service byte/state budgets do not cap WS
payloads or callback state. Explicit finite application limits still apply.
Phoenix accepts `max_frame_size`, but not the direct Gaoxy `max_message_size`
override. H2 uses Hell 0.1.3's public idle transition to keep WebSocket owners
persistent and restore ordinary connection idle after the final WebSocket ends.
See [persistent connections and capacity](websocket-limits.md).
See [WebSock limits](native-http.md#websock).

## Running a separately supervised Plug listener

For a plain Plug application, use Gaoxy directly:

```elixir
children = [
  {Gaoxy.HTTP,
   id: :api,
   plug: {MyApp.ApiPlug, []},
   ip: {127, 0, 0, 1},
   port: 4000}
]
```

`Gaoxy.HTTP` accepts `:id`, `:ip`, `:port`, `:transport`, `:tls`, `:limits`,
`:http_limits`, `:protocols`, `:h2c`, `:h2_limits`, `:extended_connect`, and
exactly one of `:plug` or `:endpoint`. `:endpoint` is Gaoxy's native endpoint
contract; use `plug: {Module, options}` for a Plug or Phoenix Endpoint.
Defaults are `id: :http`, loopback binding, `port: 0`, and `transport: :tcp`.
Use distinct IDs for multiple children. For TLS:

```elixir
{Gaoxy.HTTP,
 id: :secure_api,
 plug: {MyApp.ApiPlug, []},
 port: 4443,
 transport: :tls,
 tls: %{certfile: "/run/secrets/fullchain.pem", keyfile: "/run/secrets/privkey.pem"}}
```

The `tls` value is a map here; Phoenix's `https` options are a keyword list
with credential keys directly inside it.

If a separate Gaoxy listener mounts a Phoenix Endpoint, set that Endpoint's
`server: false` **before application startup**, but keep its ordinary Endpoint
supervisor and PubSub running. Mount it with `plug: {MyAppWeb.Endpoint, []}`.
Ensure the global Phoenix `serve_endpoints` setting does not enable a competing
Endpoint listener. For externally managed H2 WebSockets, use
`plug: {Gaoxy.PhoenixWebSocket, {MyAppWeb.Endpoint, paths}}` and enable
`extended_connect` on that external service. See the
[gateway example](../examples/phoenix_native/gateway.exs). Use Endpoint-owned
startup for the usual Phoenix deployment and automatic code-reload composition.

## What changes from Bandit

| Existing setting or responsibility | Gaoxy migration |
|---|---|
| Explicit `{:bandit, ...}` dependency | Remove; add `gaoxy_http` and the published adapter override |
| `adapter: Bandit.PhoenixAdapter` | `adapter: Gaoxy.PhoenixAdapter` |
| Endpoint `http` / `https` | Keep those keys; rebuild their contents from the supported listener table |
| `ip`, `port` | Supported; use an IP tuple and integer/decimal-string port |
| `http_options`, `http_1_options`, `http_2_options` | Not accepted; configure documented `http_limits`, `protocols`, `h2_limits` as appropriate |
| `thousand_island_options`, acceptor/transport options | Rename the supported tuning subset to `hell_options`; put resource/deadline controls in `limits`. See [backend tuning migration](#backend-tuning-migration). |
| TLS option passthrough, `otp_app`, `cipher_suite` inside `https` | Not accepted; use the documented credential paths, `versions`, matching `alpn`, and peer-verification keys |
| HTTP/2 enable/disable options | Select `protocols`; H2 is preferred on HTTPS by default |
| WebSocket compression | Unsupported; remove `compress: true` |
| Router, plugs, Channels, LiveView and session policies | Keep application configuration and code |
| Endpoint supervision | Keep the Endpoint child; it starts its own Gaoxy instance |

There is no blanket Bandit settings compatibility layer. A similarly named
timeout or concurrency option is not necessarily equivalent. Remove obsolete
Bandit application configuration after moving any application requirements
into the supported Gaoxy and Phoenix configuration.

## Troubleshooting and migration checks

| Symptom | Check |
|---|---|
| Dependency conflict for `websock_adapter` | Use app key `:websock_adapter`, `hex: :gaoxy_websock_adapter`, and `override: true` |
| `invalid http listener options` / `invalid https listener options` | Remove leftover Bandit/transport keys; place limits in maps and socket paths at Endpoint level |
| `:missing_credentials` or TLS startup error | Supply both binary credential paths; verify runtime file readability and certificate/host trust |
| `:unsupported_http_alpn` / `:invalid_http_protocols` | Use supported protocol lists; omit custom ALPN; h2c requires explicit TCP prior knowledge with H2-only or H2/H1 protocols |
| `:http2_ingress_budget` | Ensure `max_buffer_bytes >= max_frame + 9` |
| `:http2_byte_budget` | Restore the default H2 byte budget and at least three active slots; account for enlarged headers/tables/buffers |
| `:unsupported_http2_host` | Check the `:inet` backend and TLS `internal_active_n` constraints |
| `:unsupported_request_timeout` | Use finite `request_timeout` for H3 or Generation/managed gateway targets; ordinary H1/H2 native/Plug targets support the opt-in |
| `:duplicate_endpoint_listener` | Choose Endpoint-owned or externally mounted startup; inspect `server` and global `serve_endpoints` |
| No listener / connection refused | Ensure the Endpoint child is supervised, `server: true`, and at least one scheme enabled; inspect `server_info/2` |
| Code changes are not reloaded | Check `code_reloader`, `Phoenix.CodeReloader` Mix listener, and Endpoint plug |
| LiveView or Channels fail after migration | Check adapter override, original socket/session/Origin configuration, then H2 opt-in and exact transport paths |
| Long SSE/HTTP response ends around 30 seconds | Choose an explicit `stream_timeout` for chunked SSE or increase finite `request_timeout`; check proxy timeouts too |

After switching, run your application's ordinary tests, start its development
server and exercise a page, static assets, an API route and the LiveView/Channel
flows you use. Check browser WebSocket behavior and application logs. Verify
TLS and negotiated protocol with an appropriate client, for example
`curl --http2 https://your-host:8443/` when your curl build supports H2 and the
certificate is trusted. For prior-knowledge H2, use
`curl --http2-prior-knowledge http://localhost:4001/`. On a mixed listener,
`curl --http1.1 http://localhost:4001/` uses that same port. A dedicated H2-only
port requires the prior-knowledge client.

## HTTP/3 and runnable examples

HTTP/3 uses optional `gaoxy_http3`. `Gaoxy.PhoenixAdapter` can own an explicit
`http3:` listener alongside `http:` and `https:`, as configured below.
`protocols: [:http3]` remains invalid for TCP/TLS listeners. Applications can
also mount a separate `Gaoxy.HTTP.HTTP3` service. External Phoenix mounts require
`server: false`, the ordinary Endpoint supervisor, a WebSocket wrapper for exact
paths, and their own extended-CONNECT opt-in. See [HTTP/3 setup](http3.md) and
the [H3 gateway example](../examples/phoenix_native/h3_gateway.exs).

The [native Phoenix example](../examples/phoenix_native/README.md) includes
static assets, SSE, Channels and LiveView upload/click flows. Its path
dependencies are for development inside this repository; use the Hex
dependencies at the beginning of this guide in your own application. Its
fixture-only secrets and ephemeral default port are not production settings.

## One Endpoint with HTTP/3

`Gaoxy.PhoenixAdapter` owns one ListenerSet and one core instance for the
Endpoint's enabled roles. Existing `http` and `https` defaults and service IDs
remain in use. Add `gaoxy_http3` to the host application's dependencies and
configure H3 explicitly:

```elixir
config :my_app, MyAppWeb.Endpoint,
  adapter: Gaoxy.PhoenixAdapter,
  server: true,
  http: false,
  https: [ip: {127, 0, 0, 1}, port: 8443,
          certfile: "priv/cert.pem", keyfile: "priv/key.pem"],
  http3: [ip: {127, 0, 0, 1}, port: 8443,
          certfile: "priv/cert.pem", keyfile: "priv/key.pem"],
  http3_discovery: [port: :bound, max_age: 60]
```

`http3: nil` or `false` disables H3. `http3: true` is invalid: H3 requires its
own explicit IP, port, certificate and key. TCP ALPN/version options belong to
`https`; they are not copied to QUIC. Existing `limits`, `http_limits`,
`h3_limits`, `abyss_options` and explicit `extended_connect` are accepted. Unsupported wildcard,
IPv6 and TLS capabilities fail instead of falling back to a different listener.
Two zero ports are independent; two equal nonzero ports deliberately share the
numeric port across TCP and UDP.

All roles share the same initialized Endpoint, code-reload wrapper and exact
`websocket_paths`. H1 Upgrade remains available; H2/H3 WebSocket extended CONNECT
requires explicit enablement. The external duplicate-mount guard remains:
set `server: false` when another runtime owns the Endpoint listener.

`Gaoxy.PhoenixAdapter.server_info(endpoint, :http | :https)` retains its TCP
return shape. Use `Gaoxy.PhoenixAdapter.listeners(endpoint)` to inspect every
role, including actual H3 UDP addresses and degraded/recovering members. An
H3-only Endpoint does not invent a TCP HTTPS listener. Phoenix's `url` remains
the public-origin configuration, independent of ephemeral bound addresses.

See [ListenerSets](listener-sets.md) for startup rollback, optional discovery,
cache lifetimes and transport lifecycle limits. A runnable same-Endpoint example
is in [the Phoenix fixture](../examples/phoenix_native/README.md).
