# HTTP ListenerSets

A ListenerSet gives one application target a single lifecycle across HTTP TCP,
HTTPS TCP/TLS and optional HTTP/3 UDP/QUIC. Direct embedding creates one core
instance. A Proxy Gateway uses the same preparation contracts inside its own
instance; it does not start one instance per set or protocol.

```elixir
children = [
  {Gaoxy.HTTP.ListenerSet,
   id: :site,
   plug: {MyApp.Router, []},
   listeners: [
     http: [ip: {127, 0, 0, 1}, port: 4000],
     https: [ip: {127, 0, 0, 1}, port: 8443,
             certfile: "priv/cert.pem", keyfile: "priv/key.pem"],
     http3: [ip: {127, 0, 0, 1}, port: 8443,
             certfile: "priv/cert.pem", keyfile: "priv/key.pem"]
   ],
   discovery: [port: :bound, max_age: 60]}
]
```

Use `endpoint: {Module, options}` instead of `plug:` for a native
`Gaoxy.HTTP.Endpoint`. The host explicitly depends on `gaoxy_http3` to enable
H3. An HTTP-only consumer does not acquire the H3 dependency through this API.
An explicitly requested missing H3 provider fails before any bind.

`Gaoxy.HTTP.ListenerSet.plan/1` produces a stable pure Plan. It preserves the
uninitialized application declaration and rejects PIDs, references, ports and
functions as declaration values. Planning does not initialize endpoints,
compile route generations, read credentials or create a runtime. Runtime
preparation resolves required providers, checks their complete service budgets,
reads credentials and initializes the application target once. Revalidating the
resulting service specs reuses that target state.

Gateway generation snapshots retain their existing per-request byte charge.
Final provider preparation checks that each physical listener can fit its
protocol worker reservations plus that snapshot before activation. H3 reserves
the snapshot for every admitted stream; insufficient explicit budgets fail with
`:generation_byte_budget` before any listener binds.

The standard core service IDs are bounded strings such as `"site:https"`.
`service_ids: %{https: :my_https}` can assign explicit core-compatible IDs.
Duplicate IDs and same-family binding conflicts are rejected. TCP and UDP can
share the same explicit nonzero numeric port. Independent port-zero declarations
bind independently; their actual ports must be inspected. Coordinated allocation
of one ephemeral port number for TCP and UDP is unavailable.

`ListenerSet.start_link/1` returns the owner only after every required member is
ready. A required startup failure rolls back the owned listeners. Cleanup that
has not been confirmed is reported as pending with the instance that retains
ownership. Sequential network binds are not an OS-atomic transaction, so a
listener can briefly accept connections before a later member fails.

```elixir
{:ok, owner} = Gaoxy.HTTP.ListenerSet.start_link(options)
%{phase: :ready, instance: core, listeners: listeners} =
  Gaoxy.HTTP.ListenerSet.info(owner)
```

Each listener includes its logical role, core ID, transport, actual `local`
address, selected protocols, current state and lifecycle limits. A recovering
member makes the set degraded. QUIC currently supports local host cleanup and
has no equivalent TCP pause/rebind operation. Stop the owner through its owning
supervisor to stop the set. A normal owner/core stop uses transient restart
semantics.

## Optional HTTP/3 discovery

Discovery is disabled by default. `discovery: [port: :bound, max_age: 60]` uses
the observed nonzero H3 UDP port; an explicit public UDP port can replace
`:bound`. Advertisements retain the same origin host and do not trust a Host
header to construct a new authority. `max_age` is finite, from 1 to 86400 seconds.

For secure H1/H2 final responses, the set owns the Alt-Svc field: it removes
conflicting application/upstream values and inserts one current advertisement
before renderer header budget checks. This covers native endpoints, Plug and
proxy responses, including file and streaming starts. Informational and upgrade
responses receive no discovery insertion. Disabled discovery preserves existing
header behavior.

A positive advertisement requires a committed complete activation and current
ready observations for all set members, including the current H3 service.
Unavailable observations, H3 loss or draining suppress the field. Suppression
does not send `clear`; clients can retain previously advertised alternatives
until their cache lifetime expires. Readiness can change after a response head
is prepared, so this is not atomic cache revocation or proof of WebSocket H3 use.
