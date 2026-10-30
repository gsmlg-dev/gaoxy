# Adaptive resource budgets

Gaoxy coordinates memory admission across instances in one BEAM VM. Each
instance owns service, connection and request/stream allocations in one shared
ledger. Multiple ListenerSet roles or Phoenix Endpoints share the VM pool.
Separate operating-system processes require operator capacity partitioning;
this pool is not a machine-wide allocator.

## Defaults and explicit policies

The adaptive soft limit is `div(effective_capacity, 2)` and hard is twice soft.
Linux detection respects effective cgroup v1/v2 limits, including applicable
hierarchical limits. macOS/Windows use OTP's native `:memsup` physical-memory
facility. Unreliable detection uses 268,435,456 bytes soft and 536,870,912 hard.
Current free memory does not determine capacity. Capacity refreshes at most once
per 60-second periodic interval; a refresh shrink retains existing ownership.

| Accounted or projected usage | State and admission |
| --- | --- |
| At or below soft, including exactly 100% | `:normal`; admit within other limits |
| Above soft through hard, including exactly 200% of adaptive soft | `:warning`; continue admitting with rate-limited warnings |
| Projected above hard | Refuse the new allocation or growth |
| Existing usage above hard after capacity shrink | `:over_limit`; preserve existing work and allow release |

Admission checks and accounting commit atomically. Release immediately restores
capacity; there is no queue waiting for memory. Existing work can use its
committed completion credits. Additional obligations still need admission.

Set one optional instance policy on `Gaoxy.start_link/1`, ListenerSet, Gateway
or Phoenix Endpoint configuration:

```elixir
resource_budget: %{soft_limit: 268_435_456, hard_limit: 402_653_184}
```

Both thresholds must be finite positive integers with `soft_limit <= hard_limit`.
An explicit hard limit is never multiplied. Omission, or both thresholds `nil`,
selects adaptive policy. Partial or mixed nil/numeric pairs are errors. Explicit
instances still participate in the shared VM pool.

An Endpoint's policy belongs beside its `http`, `https` and `http3` options.
Gateway likewise owns one top-level policy; an embedded ListenerSet may omit its
policy or use the adaptive nil pair. An explicit embedded instance policy is
rejected with `:listener_set_resource_budget_requires_gateway_policy`.
Standalone JSON v1 accepts the same two threshold names in `resource_budget`.

## Quotas and migration

Service `limits` separate concurrency from memory:

| Option | Default or explicit meaning |
| --- | --- |
| `max_connections` | 16,384 concurrent transport connections |
| `max_requests` | 65,536 concurrent ordinary requests |
| `max_streams` | 65,536 concurrent H2/H3 request streams; lower protocol ceilings also apply |
| Explicit `max_active` | Legacy aggregate ordinary-lease cap, including connections, writers and workers; excludes cleanup and nonlegacy post-worker stream retention |
| Explicit `max_bytes` | Legacy transport/cleanup byte cap, excluding WebSocket retention; never doubled |

Omitted historical 64-lease and 1/256/16 MiB H1/H2/H3 numeric profiles no longer
act as administrator aggregate admission caps. Explicit values, including those
equal to the old defaults, retain their provenance and hard-cap semantics.
Use the distinct quotas for new concurrency policies and the instance threshold
pair for memory policy. Existing explicit legacy caps can be kept during migration.

Raw TCP/TLS `Gaoxy.StreamHandler` connections reserve finite receive, callback
state and output credit before initialization. With effective socket `buffer`
`B`, the per-connection floor is `2 * (100 * B + 18_437) + 4 * max_state +
3 * max_output` bytes. Defaults require 905,139 bytes per connection. An explicit
`max_bytes` below that floor refuses admission with `:byte_limit`; increase the
cap or reduce the configured state/output bounds when migrating a smaller cap.
Raw listeners default `buffer` and `recbuf` to 2,048 bytes. Explicit transport
settings take precedence, and larger effective buffers increase the funded
floor. These raw stream defaults do not change HTTP or QUIC transport profiles.

Raw QUIC pull streams advertise receive credit bounded by the smallest of the
native buffer capacity, `max_packet` and 16,384 bytes. Consumption replenishes
flow-control credit, so a transfer can exceed one receive window. Native buffer
and writer safety ceilings, operation-result retention and the HTTP/3 profile
remain independent. An explicit service `max_bytes` still covers simultaneously
owned callback, native-buffer and cleanup bytes; it is never increased to fit
the receive window.

Request completion or WebSocket upgrade ends ordinary request membership.
Connections and H2/H3 streams retain their independent lifetimes. Buffered
output, pending operations and cleanup can retain memory after request completion;
worker death alone does not establish that a resource is terminal. Snapshots
therefore need not reach zero as soon as an endpoint returns.

## Safety and accounting scope

Usage adds retained memory and committed temporary obligations without counting
ownership transfers twice. Protocol delivery/decoder peaks are distinct from
retained state. Transport, parser, decoder, flow-control, output and bookkeeping
bounds remain finite independently of host memory. Backend acceptor fanout has
a separate ceiling of 64.

Raw stream credit covers overlapping deliveries, old/new handler state, state
encoding/decoding and bounded output copies. Accepted state is detached from
input backing while preserving its exact term value; returned iodata becomes
an independent binary before send. State that cannot be detached with its value
preserved closes the connection while retaining the original cleanup state.
These commitments bound bridge-owned copies, not arbitrary allocations inside
custom callbacks or NIFs. `max_packet` splits an ordered delivery into callback chunks;
the full delivery backing remains accounted until those chunks finish. Existing
raw connections may reuse their paid credit after the drain barrier, while the
original shutdown deadline still forces closure and cleanup.

An active safety sampler observes physical/cgroup headroom at one-second
intervals. Samples older than three seconds or unavailable required observations
reject new growth with `:safety_sample_unavailable`; insufficient headroom uses
`:system_memory_pressure`. Sampling does not turn fluctuating free memory into
a smaller capacity policy. Process credits guard new worker creation separately.

Usage describes tracked ownership and commitments, not total BEAM RSS, kernel
socket memory or byte-perfect native allocator overhead. Public QUIC buffer byte
metrics may contribute to transport ownership; native packet/stream counts are
counts, never inferred byte measurements. Their independent finite transport
guards remain in force. A failed inspection is unavailable, not zero usage.

Authority restart reconstructs ownership from the canonical ledger. Loss of
the ledger fences admission for that VM lifetime; it cannot reopen around live
resources by substituting an empty usage counter.

## Inspect and observe

Use the instance returned by `Gaoxy.start_link/1`, or the `instance` field from
`Gaoxy.HTTP.ListenerSet.info/1`, `Gaoxy.Proxy.Gateway.info/1` or
`Gaoxy.PhoenixAdapter.listeners/1`:

```elixir
%{instance: instance} = Gaoxy.PhoenixAdapter.listeners(MyAppWeb.Endpoint)
snapshot = Gaoxy.resource_budget(instance)
```

Available snapshots include `capacity`, `soft_limit`, `hard_limit`, `usage`,
`retained_bytes`, `temporary_bytes`, `active_connections`, `active_requests`,
`active_h2_streams`, `active_h3_streams`, `state`, `availability`, `detection`,
`rejections` and aggregate `vm` totals. Calls can return an error. Fenced
inspection reports unavailable state and unknown usage; consumers must not
replace that with zero. No private GenServer inspection is required.

Telemetry follows the existing `[:gaoxy, event]` convention:

| Event | Measurements and metadata |
| --- | --- |
| `:resource_budget_snapshot` | Numeric capacity, thresholds, usage, byte categories and active resource counters; detection/scope metadata |
| `:resource_budget_state` | Usage and thresholds; new state, scope and memory-policy reason |
| `:resource_budget_rejected` | `count`; instance, service and rejection reason |
| `:resource_budget_fallback` | `count`; detection metadata with fallback reasons |

Warning logs include scope, usage, thresholds and pressure reason. Shared warning
pressure is rate-limited to one warning per 30 seconds; per-instance warning
timestamps avoid multiplying aggregate warnings across listeners.
`:memory_hard_limit` identifies shared/instance policy rejection;
`:connection_limit`, `:request_limit` and `:stream_limit` identify quotas.
`:active_limit` and `:byte_limit` identify explicit legacy service caps.
Protocol safety failures and backend/OS resource failures retain their separate
reasons.

Current qualification and unexecuted platform/specialist cases are recorded in
[the acceptance record](acceptance/adaptive-resource-budget.md).
