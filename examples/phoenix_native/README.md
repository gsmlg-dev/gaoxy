# Native Phoenix fixture

This independent Mix project exercises a Phoenix 1.8 Endpoint on Gaoxy HTTP.
From this directory run `mix deps.get` and `mix phx.server`. The Endpoint binds
to `127.0.0.1` on an ephemeral port by default; read it with
`Gaoxy.PhoenixAdapter.server_info(PhoenixNative.Endpoint, :http)` in the running
node. Set `PHOENIX_NATIVE_PORT` for a fixed local port and
`PHOENIX_NATIVE_RELOAD=1` to test development code reload.
Set `PHOENIX_NATIVE_HTTPS_PORT`, `PHOENIX_NATIVE_CERTFILE`, and
`PHOENIX_NATIVE_KEYFILE` together to add HTTPS to the same Gaoxy instance.

`/` serves a regular page, `/live-counter` has a LiveView click and text upload,
`/static/hello.txt` is static, `/events` emits SSE, and `/socket` hosts a
`room:test` Channel that echoes `ping`. The browser helpers `fixtureChannel()`
and `fixtureEvents()` are exposed by `/static/app.js`.

For a gateway-managed Endpoint, configure `server: false` and mount
`{PhoenixNative.Endpoint, []}` through `Gaoxy.HTTP.PlugEndpoint`; the Endpoint
supervisor then starts no listener of its own. Run this mode with
`mix run --no-start gateway.exs`.
