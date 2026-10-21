# Embedded Gateway

`Gaoxy.Proxy.Gateway` owns the managed upstreams, route generations, listeners,
recovery and shutdown used by the standalone application. Depend on
`gaoxy_proxy`; add `gaoxy_http3` only when a listener set includes HTTP/3.
`gaoxy_server` is not needed by an embedded application.

## Start and inspect

Declare an upstream with a literal connection address. Hostnames in the origin
remain the HTTP authority and TLS verification name; preparation does not
perform DNS resolution. HTTPS requires explicit trusted DER certificates or a
`cacertfile` whose contents are accepted during preparation.

```elixir
alias Gaoxy.Proxy.Gateway
alias Gaoxy.Proxy.Gateway.Upstream

{:ok, upstream} = Upstream.fixed(%{
  upstream: "http://127.0.0.1:9000",
  upstream_protocol: :http1
})

children = [
  {Gateway,
   id: :edge,
   name: MyApp.Gateway,
   startup_timeout: 5_000,
   listener_sets: [[
     id: "web",
     endpoint: {Gaoxy.HTTP.Router, [%{target: upstream}]},
     listeners: [http: [ip: {127, 0, 0, 1}, port: 8080]]
   ]]}
]

Supervisor.start_link(children, strategy: :one_for_one)
Gateway.info(MyApp.Gateway)
```

`Gateway.compile/1` returns `{:ok, %Gateway.Plan{}}` without initializing targets,
reading files, creating runtime references or opening sockets. The plan can be
reused in `start_link/1` or `child_spec/1`. Each set has a stable atom or bounded
string ID and one uninitialized Endpoint or Plug target. Runtime capabilities
such as PIDs, references and prepared upstream handles are rejected in input
plans. Existing supported raw core `services:` can be supplied alongside sets.
Two gateways can use the same IDs on different bindings.

`info/1` reports `phase`, `instance`, `listeners`, each set's accepted `revision`,
`runtime_epoch`, `cleanup` and `preparations`. Listener entries contain actual
addresses, transports, protocols and lifecycle capabilities. A busy preparation
owner is reported as unknown cleanup, rather than confirmed cleanup.

## Shared H1/H2/H3 listeners

Use `https:` and `http3:` members of the same set to share one route generation:

```elixir
listener_sets: [[
  id: "web",
  endpoint: {Gaoxy.HTTP.Router, routes},
  listeners: [
    https: [ip: {127, 0, 0, 1}, port: 8443,
            certfile: "priv/cert.pem", keyfile: "priv/key.pem"],
    http3: [ip: {127, 0, 0, 1}, port: 8443,
            certfile: "priv/cert.pem", keyfile: "priv/key.pem"]
  ],
  discovery: [port: :bound, max_age: 60]
]]
```

HTTPS keeps its H2/H1 defaults; H3 is explicitly enabled. Equal nonzero ports
share a numeric TCP/UDP port. Separate port-zero declarations bind independently.
Discovery is opt-in and advertises only a currently ready H3 member on secure
H1/H2 final responses, including proxied and streamed responses. An explicit
public UDP port can replace `:bound`. Client caches may outlive a later shutdown.
See [ListenerSets](listener-sets.md) and [Phoenix](phoenix.md).

A new Gateway ListenerSet supplies a 64 MiB byte default for H1/H3 routed
listeners and retains the HTTP/2 builder's larger default. Explicit limits must
also cover the Generation snapshot reservation: H1/H2 reserve it for an admitted
request, H3 for each admitted stream. Preparation rejects an insufficient budget
before binding. These reservations cover retained application work, not total
VM, native or kernel memory. Existing standalone v1 raw service budgets retain
their prior request-admission behavior.

## Reload and reconcile

```elixir
{:ok, %{revision: 2, generation: runtime_token}} =
  Gateway.reload_routes(MyApp.Gateway, "web", new_routes,
    expected_revision: 1, timeout: 3_000, operation_id: "routes-2026-10-21")

Gateway.operation_status(MyApp.Gateway, {"web", "routes-2026-10-21"})
```

Reload changes routes for one set. All its physical listeners capture the same
authoritative Router; requests already running retain their old snapshot and
resource pins. Bindings, certificates and listener limits require restart.
There is no transaction across independent sets.

`expected_revision` compares accepted configuration, not a runtime-generation
reference. At most one reload is in flight per set. Invalid, expired or stale
candidates leave the accepted declaration unchanged. An optional absolute
monotonic-millisecond `deadline` can shorten `timeout`, which is useful to a
host facade that has already spent part of its budget reading configuration.

A lost or late reply returns
`{:error, {:operation_pending, {set_id, operation_id}}}`. Reconcile the same
identity before retrying; conflicting reuse is rejected. Status reports pending,
committed, rejected or unknown. Only the in-flight and latest terminal receipt
are retained; eviction or authority loss cannot establish rejection. A committed
receipt means activation occurred, while old-request or preparation cleanup may
still be pending. `info/1` exposes that distinction.

## Managed resources and recovery

`Upstream.fixed/1` supports the existing managed `:http1`, `:http2` and `:h2c`
transports. Use `Upstream.group/1` with `id`, `members`, `health` and finite
`max_inflight` settings for the existing homogeneous upstream groups. Members
use the same fixed upstream fields plus their own ID and capacity. Unsupported
protocol/policy combinations remain errors.

Stable stores retain the accepted declaration, logical revision, current runtime
epoch and operation receipt together with the active Router. The restartable
runtime group contains one correctly budgeted core instance, upstream owners
and a coordinator. Owner failure withdraws readiness and rebuilds that group
from the latest accepted routes. Accepted upstream trust contents survive changed
or deleted input files. A new explicit reload is required to accept new trust.
Old-epoch candidates cannot install obsolete handles. Complete Gateway-root or
VM loss returns to the host's startup configuration.

## Stop and standalone compatibility

```elixir
:ok = Gateway.stop(MyApp.Gateway, 5_000)
```

Stop first serializes draining barriers against each set's commit authority,
then drains the core while its upstream cleanup owners remain available. A
confirmed stop terminates the root without resurrection. Deadline uncertainty
returns `{:error, {:deadline_exceeded, :cleanup_pending, owner_pid}}`; that
supervised owner keeps driving cleanup after caller timeout or death.
Transport-specific drain limitations remain visible, including H3's local host
cleanup rather than a new graceful protocol guarantee.

Standalone JSON v1 services remain independent sets, even when routes or ports
match. `GAOXY_CONFIG`, readiness output, legacy registration names and
`Gaoxy.Server.reload_routes(service_id, path, timeout)` remain available. The
file facade retains `{:ok, runtime_generation}` success and can expose the
additive pending-operation result above. Server modules decode JSON and files;
the shared Gateway owns orchestration. No public management listener is added.
