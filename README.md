# Gaoxy

Gaoxy is an Elixir/OTP server runtime for Plug, Phoenix, reverse proxies and
custom TCP, TLS and UDP services. It provides native HTTP/1.1 and HTTP/2, with
HTTP/3 available through an optional package. Run it inside your application's
supervision tree or use the standalone release with JSON configuration.

This source targets version **0.5.3**:
[GitHub release](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.5.3) ·
[release verification](docs/acceptance/review-repairs-2026-10-20.md).

## Choose a package

| Package | Use it for | Guide |
| --- | --- | --- |
| [`gaoxy`](https://hex.pm/packages/gaoxy) | Custom TCP/TLS/UDP services and runtime lifecycle | [README](apps/gaoxy/README.md) |
| [`gaoxy_http`](https://hex.pm/packages/gaoxy_http) | Plug, Phoenix, HTTP/1.1, HTTP/2 and WebSocket servers | [README](apps/gaoxy_http/README.md) |
| [`gaoxy_websock_adapter`](https://hex.pm/packages/gaoxy_websock_adapter) | Gaoxy's WebSockAdapter distribution for Phoenix and Plug upgrades | [README](vendor/websock_adapter/README.gaoxy.md) |
| [`gaoxy_http3`](https://hex.pm/packages/gaoxy_http3) | Optional native HTTP/3 server over QUIC | [README](apps/gaoxy_http3/README.md) |
| [`gaoxy_proxy`](https://hex.pm/packages/gaoxy_proxy) | Reverse HTTP/WebSocket proxies, upstream resources and gateway services | [README](apps/gaoxy_proxy/README.md) |
| `gaoxy_server` | Standalone application with JSON service and route configuration | [README](apps/gaoxy_server/README.md) |

`gaoxy_server` ships in the standalone release rather than as a Hex package.
Choose `gaoxy_http` to replace Bandit in Phoenix; its dependencies bring in the
core runtime. Add `gaoxy_http3` or `gaoxy_proxy` when your application needs them.

## Replace Bandit in Phoenix

See the [complete Phoenix setup and Bandit migration guide](docs/phoenix.md)
for development, production, HTTPS, LiveView, Channels and option migration.
For an existing Phoenix application, the essential changes are:

1. Replace the explicit Bandit dependency in `mix.exs` with:

   ```elixir
   {:gaoxy_http, "~> 0.5.3"},
   {:websock_adapter, "~> 0.5.3", hex: :gaoxy_websock_adapter, override: true}
   ```

   Keep the dependency name `:websock_adapter`: that is the OTP application
   Phoenix uses. `hex: :gaoxy_websock_adapter` selects the Gaoxy distribution.

2. Set the Endpoint adapter in `config/config.exs`:

   ```elixir
   config :my_app, MyAppWeb.Endpoint,
     adapter: Gaoxy.PhoenixAdapter
   ```

3. Configure a development listener in `config/dev.exs`:

   ```elixir
   config :my_app, MyAppWeb.Endpoint,
     http: [ip: {127, 0, 0, 1}, port: 4000],
     server: true
   ```

   Keep `MyAppWeb.Endpoint` in the application's supervisor. The Endpoint
   starts and owns its Gaoxy listeners. Translate existing Bandit listener
   options using the migration guide's supported option table.

4. Fetch dependencies and start the application:

   ```sh
   mix deps.get
   mix phx.server
   ```

   Open <http://localhost:4000>. Existing routes, Plug pipelines, Channel
   sockets and LiveView declarations remain part of your Phoenix application.

Plain HTTP defaults to HTTP/1.1. HTTPS defaults to HTTP/2 with HTTP/1.1 fallback.
Ordinary HTTP/1.1 WebSocket upgrades work with the adapter above. Native H2/H3
WebSocket additionally requires `extended_connect: true` and an explicit
`websocket_paths` allowlist; the [Phoenix guide](docs/phoenix.md) shows both.

## Serve a Plug

Add `{:gaoxy_http, "~> 0.5.3"}` to your dependencies. Given a Plug module such
as `MyApp.Router`, add a listener to your application's supervision tree:

```elixir
children = [
  {Gaoxy.HTTP,
   id: :web,
   plug: {MyApp.Router, []},
   ip: {127, 0, 0, 1},
   port: 4000}
]

Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
```

The [HTTP package README](apps/gaoxy_http/README.md) covers TLS certificates,
protocol selection, resource limits and multiple listeners. For custom wire
protocols, start with the [core package README](apps/gaoxy/README.md).

## Run the standalone server

Create `config.json`:

```json
{
  "version": 1,
  "services": [{
    "id": "echo",
    "transport": "tcp",
    "handler": "stream_echo",
    "ip": "127.0.0.1",
    "port": 4000
  }]
}
```

From this checkout:

```sh
mix deps.get --check-locked
mix gaoxy.validate config.json
MIX_ENV=prod mix release gaoxy
GAOXY_CONFIG="$PWD/config.json" _build/prod/rel/gaoxy/bin/gaoxy start
```

Startup prints `GAOXY_READY` with actual bound addresses and ports. The
[standalone guide](apps/gaoxy_server/README.md) includes HTTP routes, reverse
proxy configuration, TLS and local route reload.

## Requirements and development

The packages require Elixir **1.18+**. The core's Abyss dependency builds a
Rust NIF, so install Rust/Cargo and a native compiler toolchain. HTTP/3 and the
proxy dependency graph add QUIC/TLS libraries; see their package
guides for requirements. Core-only consumers remain independent of Plug,
Phoenix and the optional QUIC engine.

The locked Nix shell supplies Elixir 1.18.5 / OTP 28, Rust/Cargo, Python,
OpenSSL and Expect:

```sh
nix develop
mix deps.get --check-locked
mix format --check-formatted
mix compile --warnings-as-errors
python3 scripts/check-tests.py
```

Use **Elixir 1.18.5** for canonical formatting. TLS fixtures require OpenSSL 3;
`OPENSSL_BIN` can select its executable. Run network fixtures in their
documented isolated environment.

## Documentation and publishing

- [Phoenix and Bandit migration](docs/phoenix.md)
- [Native HTTP and WebSocket](docs/native-http.md)
- [HTTP/3](docs/http3.md), [HTTP reverse proxy](docs/http-proxy.md) and
  [WebSocket reverse proxy](docs/websocket-proxy.md)
- [Gateway APIs](docs/gateway.md) and [capability limits](docs/capabilities.md)
- [Architecture](docs/architecture.md) and [dependency provenance](docs/dependency-audit.md)
- [Historical README and acceptance records](docs/history/readme-2026-10-20.md)

The manual release workflow builds and publishes all five Hex packages in
dependency order using the `HEX_API_KEY` Actions secret. Each package contains
its own README. The staging tool preserves runtime source bytes and converts
workspace dependencies to exact Hex requirements:

```sh
elixir scripts/stage-hex-packages.exs "$PWD" .audit/hex-packages
python3 scripts/test-stage-hex-packages.py
```

The output directory must be empty. The workflow publishes packages and GitHub
assets; HexDocs are not generated. Historical verification records retain their
recorded source identities, outcomes and scope.

## License

MIT. The WebSockAdapter distribution retains its upstream MIT license and
provenance files.
