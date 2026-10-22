# Gaoxy HTTP/3

`gaoxy_http3` serves Plug applications and Gaoxy HTTP endpoints over QUIC v1 with
ALPN `h3`. It provides an explicit, separate HTTP/3 listener through
`Gaoxy.HTTP.HTTP3`.

## Install

Add to `mix.exs`, then run `mix deps.get`:

```elixir
defp deps do
  [
    {:gaoxy_http3, "~> 0.10.0"}
  ]
end
```

This brings in `gaoxy_http`, `elixir_quic_http3`, `elixir_quic` and `ex_ssl`.
Use Elixir 1.18 or newer with Erlang/OTP crypto and public-key support. Core
Abyss 0.9.0 excludes its former DHCP NIF and Rustler build; Gaoxy does not depend
on `abyss_raw`. Keep the matching QUIC/TLS dependency versions selected by Mix.

## Serve a Plug

```elixir
defmodule MyApp.Hello do
  def init(options), do: options

  def call(conn, _options) do
    Plug.Conn.send_resp(conn, 200, "hello over h3\n")
  end
end
```

Add the listener to your application's supervision tree, using existing PEM
certificate and private-key files:

```elixir
children = [
  {Gaoxy.HTTP.HTTP3,
   id: :https3,
   ip: {127, 0, 0, 1},
   port: 4443,
   tls: %{certfile: "/path/to/cert.pem", keyfile: "/path/to/key.pem"},
   plug: {MyApp.Hello, []}}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

Use a certificate valid for the hostname your client requests. The listener
binds UDP; allow UDP traffic to the configured port. A client must support
HTTP/3 and trust the certificate. For example, when `curl -V` lists HTTP3:

```sh
curl --http3-only --cacert /path/to/ca.pem https://localhost:4443/
```

## Options and composition

Supply exactly one of `plug: {Module, options}` or
`endpoint: {Module, options}`. The latter implements `Gaoxy.HTTP.Endpoint`.
The binding requires a concrete IPv4 tuple; wildcard and IPv6 bindings are
currently rejected. The defaults are loopback, port `0` and ID `:http3`.
TLS credentials are required. Transport is `:quic`, and ALPN is fixed to `h3`.

`Gaoxy.HTTP.HTTP3.service_spec/1` returns `{:ok, service}` for use in a shared
`{Gaoxy, services: [...]}` instance alongside TCP or HTTP/1–2 services.
`Gaoxy.HTTP` accepts HTTP/1 and HTTP/2; `protocols: [:http3]` does not enable H3.
Configure TCP HTTPS separately when clients also need H1/H2.

Start with the supplied resource limits. `:limits`, `:http_limits` and
`:h3_limits` are maps validated together before activation. H3 defaults allow
eight request streams per connection and 32,768-byte header blocks. Dynamic
QPACK table capacity and blocked-stream limits must both remain zero.

## WebSocket and Phoenix

RFC 9220 WebSocket support requires explicit `extended_connect: true`.
For an external Phoenix mount, run the Phoenix Endpoint with `server: false`
and pass its exact socket paths through the compatibility wrapper:

```elixir
plug: {Gaoxy.PhoenixWebSocket,
       {MyAppWeb.Endpoint, ["/live/websocket", "/socket/websocket"]}},
extended_connect: true
```

These replace `plug: {MyApp.Hello, []}` in the listener options. Include only
paths declared by your Endpoint. Follow the
[Phoenix guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/phoenix.md)
for dependencies, Endpoint supervision and socket configuration.

Browser transport selection remains client-controlled; serving a page over H3
does not prove its WebSocket uses H3. See the
[HTTP/3 guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/http3.md)
for protocol limits and the
[native HTTP guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/native-http.md)
for shared Plug/endpoint APIs.

For one Phoenix Endpoint across H1/H2/H3, use the adapter's explicit `http3:`
option or `Gaoxy.HTTP.ListenerSet`; see the [Phoenix guide](../../docs/phoenix.md)
and [ListenerSet contract](../../docs/listener-sets.md). This package supplies
the optional versioned H3 listener provider. HTTP-only consumers do not resolve
or load it, and existing `Gaoxy.HTTP.HTTP3.service_spec/1` remains a single
service builder.
