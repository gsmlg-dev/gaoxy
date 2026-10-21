# Verified TLS client certificates

Gaoxy 0.9.0 supports OTP TLS client-certificate verification on native TLS and
Phoenix HTTPS listeners. Certificate identity comes from the TLS handshake.
Forwarded HTTP headers never supply a peer certificate.

For a listener that permits first enrollment without a certificate and verifies
any certificate the client supplies:

```elixir
config :my_app, MyApp.Endpoint,
  adapter: Gaoxy.PhoenixAdapter,
  https: [
    port: 4040,
    certfile: "/run/secrets/server.pem",
    keyfile: "/run/secrets/server-key.pem",
    verify: :verify_peer,
    cacertfile: "/run/secrets/client-ca.pem",
    fail_if_no_peer_cert: false,
    versions: [:"tlsv1.3", :"tlsv1.2"]
  ]
```

Set `fail_if_no_peer_cert: true` to require every client to present a trusted
certificate. With either presence policy, a supplied untrusted certificate
fails the handshake before HTTP handling. This verifies certificate trust;
application authorization must still check that the certificate belongs to an
allowed machine or user.

Direct services use the same keys inside their `tls` map:

```elixir
Gaoxy.HTTP.start_link(
  plug: {MyPlug, []},
  transport: :tls,
  tls: %{
    certfile: "/run/secrets/server.pem",
    keyfile: "/run/secrets/server-key.pem",
    verify: :verify_peer,
    cacertfile: "/run/secrets/client-ca.pem",
    fail_if_no_peer_cert: false
  }
)
```

Core `Gaoxy` service specifications also accept these keys in `tls`. Embedded
`Gaoxy.HTTP.ListenerSet` declarations accept them in the `https` keyword list.
TLS defaults to server-only verification (`:verify_none`) and TLS 1.3. Peer
verification requires a nonempty binary `cacertfile` path; CA and certificate
presence options require `verify: :verify_peer`. Unknown verification modes and
nonboolean presence policies return `{:error, :invalid_tls_verification}`.
Unreadable or invalid CA material fails listener startup; verification is never
silently downgraded.

For HTTP, `Plug.Conn.get_peer_data(conn).ssl_cert` is the peer's DER certificate,
or `nil` when no certificate was presented. For a Phoenix WebSocket, request
`connect_info: [:peer_data]` in the socket's websocket configuration and inspect
`connect_info.peer_data.ssl_cert` in `connect/3`. Applications permitting anonymous
enrollment must separately deny runtime access when this value is `nil`.

This support applies to OTP TLS listeners. HTTP/3 client-certificate policy is
not part of this interface.
