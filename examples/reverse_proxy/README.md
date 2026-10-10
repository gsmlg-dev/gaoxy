# Local routes and a streaming reverse proxy

The example's six independent checks pass, but the M2 candidate still has an
upstream raw-target blocker: HTTP Fetch 0.19.0 removes a present empty query
(`/path?` becomes `/path`). See [#64](https://github.com/gsmlg-dev/http_fetch/issues/64)
and [the HTTP proxy guide](../../docs/http-proxy.md).

From the umbrella root, point the example at one trusted upstream authority:

```sh
GAOXY_UPSTREAM=http://127.0.0.1:4001 GAOXY_PORT=4000 mix run examples/reverse_proxy/run.exs
```

The gateway binds loopback. `/local` runs a local Plug directly; every other
path goes to the configured upstream with its raw path and query preserved.
Enter `stop` to drain the gateway and exit. Set `GAOXY_PORT=0` to select an
ephemeral port; the `GAOXY_PROXY_READY` line reports its actual address.

The upstream must be an HTTP or HTTPS authority without userinfo, path or query.
HTTPS uses verified OTP TLS. The endpoint also accepts `cacertfile` for a private
CA; it does not offer a verification bypass. Redirects are returned to the caller,
and failed requests are not replayed. Uploads, downloads, SSE, duplicate response
fields, raw compression and declared trailers pass through the streaming endpoint.
The example uses an explicit 128 MiB service capacity for the proxy's conservative
reservations; this is a capacity limit, not preallocated memory.

Try the local and upstream routes while the example is running:

```sh
curl http://127.0.0.1:4000/local
curl --no-buffer http://127.0.0.1:4000/events
curl --data-binary @payload.bin http://127.0.0.1:4000/echo
```

The upstream supplies `/events` and `/echo`. The independent Python harness starts
its own loopback origin and verifies the example without an external service:

```sh
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test python3 integration/reverse_proxy/run.py
```

WebSocket routes use the separate `Gaoxy.Proxy.WebSocket` endpoint described in
[the WebSocket proxy guide](../../docs/websocket-proxy.md).
