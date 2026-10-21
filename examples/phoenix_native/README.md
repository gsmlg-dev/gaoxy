# Native Phoenix fixture

This independent Mix project exercises a Phoenix 1.8 Endpoint on Gaoxy HTTP.
From this directory run `mix deps.get` and `mix phx.server`. The Endpoint binds
to `127.0.0.1` on an ephemeral port by default; read it with
`Gaoxy.PhoenixAdapter.server_info(PhoenixNative.Endpoint, :http)` in the running
node. Set `PHOENIX_NATIVE_PORT` for a fixed local port and
`PHOENIX_NATIVE_RELOAD=1` to test development code reload.
Set `PHOENIX_NATIVE_HTTPS_PORT`, `PHOENIX_NATIVE_CERTFILE`, and
`PHOENIX_NATIVE_KEYFILE` together to add HTTPS to the same Gaoxy instance.
HTTPS prefers H2 with H1 compatibility. This fixture explicitly enables extended
CONNECT and allowlists `/socket/websocket` and `/live/websocket` through
`websocket_paths`; ordinary HTTP listeners retain H1 unless h2c is selected.

To exercise H1 and prior-knowledge H2 on the same HTTP port, replace the
Endpoint's existing `http` options in `config/config.exs` with:

```elixir
http: [ip: {127, 0, 0, 1}, port: 4000, protocols: [:http2, :http1], h2c: :prior_knowledge]
```

Keep the same Endpoint child; the adapter creates one native HTTP listener.
Use `curl --http1.1 http://localhost:4000/` and an H2-capable
`curl --http2-prior-knowledge http://localhost:4000/`. This is direct H2 prior
knowledge; HTTP/1 Upgrade to h2c is unsupported. Defaults remain H1-only HTTP
and H2-first HTTPS. See the [Phoenix guide](../../docs/phoenix.md#listener-options-and-protocol-selection)
for detection deadlines and first-input budgets.

`/` serves a regular page, `/live-counter` has a LiveView click and text upload,
`/static/hello.txt` is static, `/events` emits SSE, and `/socket` hosts a
`room:test` Channel that echoes `ping`. The browser helpers `fixtureChannel()`
and `fixtureEvents()` are exposed by `/static/app.js`.

For a gateway-managed Endpoint, configure `server: false` and mount
`{PhoenixNative.Endpoint, []}` through `Gaoxy.HTTP.PlugEndpoint`; the Endpoint
supervisor then starts no listener of its own. Run this mode with
`mix run --no-start gateway.exs`.

For H3, enable the optional dependency with `PHOENIX_NATIVE_H3=1` and run
`mix run --no-start h3_gateway.exs`, setting `GAOXY_HTTP3_CERT_DIR` to the local
test certificate directory. It mounts `Gaoxy.PhoenixWebSocket` around the
Endpoint with the same exact paths and `server: false`. The M5 browser runner
in `integration/websocket_multiplexed` records the WebSocket's native protocol
and stream, Channels/PubSub, LiveView click/upload, and ordinary Origin refusal.

## Endpoint-owned HTTPS and H3 together

The fixture can now use its normal Endpoint child for all protocols. Generate
local test credentials from the repository root with
`scripts/generate-fixtures.sh .audit/phoenix-unified-certs`, then from this
example directory:

```sh
PHOENIX_NATIVE_H3=1 mix deps.get --check-locked
PHOENIX_NATIVE_H3=1 \
PHOENIX_NATIVE_HTTPS_PORT=0 PHOENIX_NATIVE_HTTP3_PORT=0 \
PHOENIX_NATIVE_CERTFILE="$PWD/../../.audit/phoenix-unified-certs/cert.pem" \
PHOENIX_NATIVE_KEYFILE="$PWD/../../.audit/phoenix-unified-certs/key.pem" \
mix run --no-halt -e 'IO.inspect(Gaoxy.PhoenixAdapter.listeners(PhoenixNative.Endpoint))'
```

The printed metadata reports the independent actual TCP and UDP ports. Set both
secure port variables to the same nonzero number to share that numeric port.
This path uses `server: true`, the same Endpoint/code reload/WebSocket pipeline,
and opt-in discovery on secure H1/H2 responses. The older `h3_gateway.exs` remains
an explicit external mounting example with `server: false`.

`integration/phoenix_native/unified.py` is the focused real Endpoint gate. It
requires this example compiled in development with H2, H3 and code reload
enabled, plus the Python browser requirements and `aioquic`. It records forced
H1/H2/H3 requests, the exact native H2/H3 Channel and LiveView socket paths,
code reload and source restoration, and Endpoint shutdown. Its default evidence
directory is `.audit/unified-phoenix`.
