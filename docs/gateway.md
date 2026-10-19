## v0.5.0 release status — 2026-10-20 (Asia/Shanghai)

Published [v0.5.0](https://github.com/gsmlg-opt/gaoxy/releases/tag/v0.5.0) from
`b0e1531b9d2ac682e4af19d4616ad4461e3ca6f2` with Hell 0.1.2 (`Hell` namespace,
`:hell` application) replacing Thousand Island. Accepted protocol and Phoenix
functionality is unchanged; published v0.4.0 source and binaries retain
Thousand Island. Fresh ordinary portable verification passed **210 executions /
0 failures / 144 excluded / 0 skipped**. Packaged H2/h2c/H3 WebSocket passed
**15/15 each** in builder and offline runtime; all **21 ELF objects** passed
dependency checks. Three freshly downloaded release assets match the qualified
bytes and hashes. New hosted CI remains **NOT RUN**. See the
[release notes](releases/0.5.0.md) for platform support and retained limits,
and [release acceptance](acceptance/release-0.5.0.md) for exact evidence.
Historical results below retain their recorded source identities and outcomes.

## v0.4.0 release status — 2026-10-19

Accepted embedded gateway capabilities include managed H1 reuse, managed H2/h2c fixed/group upstreams, probes and bounded Generation/resource accounting. H2/h2c uses explicit managed handles. Standalone JSON supports fixed H1/H3 origins and HTTP services defaulting to H1 with explicit H2/h2c or separate H3 selection, without managed handles/groups/probes or WebSocket activation. Authentication, destination validation and connection-time policy requirements remain in force.

Published [v0.4.0](https://github.com/gsmlg-opt/gaoxy/releases/tag/v0.4.0) from `ebd2b12a997750109ffd3fc7db4f3eda223ab79b`. Fresh ordinary portable verification: **200 executed / 0 failures / 90 excluded**; packaged H2/h2c/H3 WebSocket **15/15 each** in builder and offline runtime. All **21 ELF objects** passed dependency checks; three freshly downloaded assets match the qualified bytes and hashes. [Release acceptance](acceptance/release-0.4.0.md) records source, artifact and publication evidence. New hosted CI remains NOT RUN.

Earlier snapshots retain their capture-time scope and actual failed, blocked and unexecuted results. Specialist qualification remains with its dedicated environment; deployment and production acceptance remain NOT RUN.

# Gateway policies, relays and generations

These APIs belong to `gaoxy_http`, `gaoxy_proxy` and `gaoxy_server`; ordinary
core consumers retain transport-only dependencies. [M3 acceptance](acceptance/m3.md)
records local evidence and the remaining upstream blockers.

## Authenticated forward HTTP and CONNECT

Mount `Gaoxy.Proxy.ForwardHTTP` as an endpoint with an explicit policy:

```elixir
policy = %{
  authenticate: &MyApp.ProxyAuth.authenticate/1,
  rules: [%{
    principals: ["operator"], hosts: ["service.example"], ports: [80, 443],
    operations: [:forward, :connect], methods: ["GET", "POST", "CONNECT"],
    cidrs: ["93.184.216.0/24"]
  }]
}
{:ok, proxy} = Gaoxy.HTTP.start_link(
  endpoint: {Gaoxy.Proxy.ForwardHTTP, %{policy: policy}},
  limits: %{max_bytes: 67_108_864}
)
```

The application authentication function receives one Proxy-Authorization value
and returns `{:ok, principal}` or rejects it. Missing, duplicate or invalid
credentials produce 407. Rules require matching principal, host, port, operation,
method and resolved address. Replace the example host/CIDR with the actual
approved destination. Every A/AAAA result must satisfy policy; the dial uses
one approved numeric address while preserving authority and TLS identity.
Explicit `deny_cidrs` wins. Reserved IPv4/IPv6 destinations require a deliberate
`allow_reserved: true` rule with a /24-or-narrower or /64-or-narrower CIDR.

Forward requests use absolute `http` targets; HTTPS destinations use H1 CONNECT.
Proxy credentials never reach the upstream. CONNECT accepts H1.1 authority form
without a request entity, transfers buffered tunnel bytes once, and retains the
original finite request deadline. TLS to the proxy terminates at that listener;
the CONNECT payload remains opaque. H2 CONNECT, interception, SNI inspection,
SOCKS and PROXY protocol are unsupported. No redirect, retry or replay occurs.

## TCP and TLS stream relay

Use `Gaoxy.Proxy.StreamRelay` as a native TCP/TLS handler with
`handler_mode: :native` and options such as
`%{upstream: {{127, 0, 0, 1}, 9000}, mode: :tcp}`. Destinations are explicit numeric
addresses. Modes are `:tcp`, `:tls_termination`, `:tls_upstream` and
`:tls_passthrough`. Verified upstream TLS needs
`upstream_tls: %{server_name: "origin.example", cacertfile: "/path/to/ca.pem"}`;
the numeric destination does not change the verified certificate identity.
Opaque passthrough parses no TLS metadata.

One credited chunk per direction, acknowledged writer completion and finite
connect/write/idle/lifetime budgets bound transfer. TCP FIN shuts down the
opposite write direction after submitted output is confirmed, allowing the
remaining response to return. OTP TLS has no qualified directional half-close;
TLS EOF explicitly closes both directions. Forced stop retains uncertainty for
unconfirmed output. The qualified host backend is `:inet`, and TLS uses the
documented OTP internal-active bound; arbitrary callback/kernel memory is outside
payload accounting.

## UDP unicast associations

`Gaoxy.Proxy.UDPRelay` uses `handler_mode: :datagram_dispatcher` on an ordinary
Gaoxy UDP service. Required handler options are an explicit literal
`upstream: {address, port}`, nonempty `ingress` CIDRs, and
`destination: %{allow: cidrs}` (optional `deny` and `allow_reserved`). Configuration
rejects self-loops, multicast/broadcast destinations and unsupported service modes
before binding. The product's broadcast/multicast relays remain UNSUPPORTED in
this slice; ordinary core multicast hosting keeps its earlier contract.

Associations are generation-tagged by ingress peer. Defaults limit associations
to 256, each queue to 8 items/65,536 bytes, datagrams to 65,507 bytes, idle time to
30 seconds and lifetime to 300 seconds. Service admission and aggregate byte
capacity apply as well. Empty payloads still charge one item/byte. Only the
pinned upstream source earns return delivery, and return packet/byte credits
come from admitted ingress. Rates and amplification ratios are finite; no
uncertain/admitted send is retried. UDP CIDRs restrict sources without
authenticating them. Local writer receipts do not prove peer delivery.

## Route generations and standalone JSON

```elixir
{:ok, store} = Gaoxy.HTTP.Generation.start_link(routes: initial_routes)
{:ok, gateway} = Gaoxy.HTTP.start_link(endpoint: {Gaoxy.HTTP.Generation, store})
{:ok, generation} = Gaoxy.HTTP.Generation.reload(store, replacement_routes, 5_000)
```

Preparation compiles a bounded immutable router outside its owner. Activation
checks generation/deadline atomically; old requests retain their selected router
and resource pins while new requests see the replacement. Invalid or stale
candidates leave the current routes intact. The publication receipt precedes
bounded retired-resource reconciliation. Pending releases reject further
activation with `:resource_release_pending`, preserving capacity conservatively.
Listener/address/TLS changes require a separate restart; reload changes routes.

Standalone `GAOXY_CONFIG` version-1 JSON adds `handler: "http"` and a `routes`
object containing its own `version: 1` and `routes` list. Named targets are
`static` and fixed `reverse_proxy`; unknown keys, arbitrary modules/atoms and
code evaluation are rejected. File preparation runs under the same bounded
deadline, including regular-file checks and a 1 MiB configuration ceiling.
`Gaoxy.Server.reload_routes(service_id, path, timeout)` is a local Elixir API;
it leaves the listener and in-flight snapshots stable. There is no public
management listener. External JSON for upstream groups, forward policy or
stream/UDP relay endpoints is UNSUPPORTED by this allowlist.

## Supervised upstream groups

The configuration owner starts `Gaoxy.Proxy.UpstreamGroups` with `instance: pid`,
compiles a bounded group with `id`, `members` and optional `health` settings,
then calls `prepare(owner, compiled, holder, deadline)` to obtain an immutable
handle and preparation pin. A member has a unique `id`, fixed HTTP/verified-HTTPS
`upstream` and finite `max_inflight`. Mount
`{Gaoxy.Proxy.GroupEndpoint, %{group: handle}}` in a Generation router; activation
owns baseline pins, and each request snapshot owns request pins. Release the
preparation pin only after the router takes its baseline hold.

Common endpoint and selected-member limits intersect: opening, idle, write,
total lifetime and chunk size use their smaller values. Total lifetime is
anchored to the original Session start and clipped to the downstream deadline;
selection does not restart it. The pump receives the effective policy before
upload or response writes. Opening expiry can send 504 while the total budget
remains; absolute total expiry closes without an extra error-write budget.
Intentional total/idle expiry preserves member health, and cleanup remains
required before releasing the selected-member hold.

Selection is deterministic round robin, skipping unavailable or saturated
members. Initially unknown or
stale/unhealthy peers are unavailable until finite HEAD probes establish health;
thresholds govern failure and recovery. Saturation/unavailability produces 503
without a second dial or health penalty. A selected request never moves to
another member. Its selection hold releases only after public confirmed client
cleanup, including cancellation. Old snapshots can still select their old group
while new traffic uses the replacement; retirement cancels probes and waits for
all baseline/preparation/request/selection/probe holds to clear. Owner/caller
loss preserves failed cleanup instead of inventing successful retirement.

Each request/probe uses a dedicated H1 transport. Group balancing and health are
implemented. Installed HTTP Fetch0.21 contains request cleanup/trailers and
managed ownership/retirement, but reusable H1 and upstream H2 remain disabled
pending complete H1 accounting and managed runtime qualification, and H2
header/control bound [#86](https://github.com/gsmlg-dev/http_fetch/issues/86).
See the [transport plan](plans/m3-upstream-transport.md).
