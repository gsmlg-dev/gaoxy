# Managed transport merged-source review

Prepared 2026-10-11 Asia/Shanghai; Gaoxy baseline `4cc7a1a967d1b90a62d42db438316b10a03a1e16`,
branch `codex/m3-gateway`. Independent Sol source audit and Astra architecture
memo; no package installation or runtime qualification is claimed here.

## Source identity and result

PR81 head `11f1642cf6408219d4813772bda1055e605bbdc4` is merged as
`a75ec3c34446a1877366a0e52055743d28eabcc9`. PR80 is merged as
`ed7a8e23fb969b1337703d8ea5d12f774e5a5edb`. The inspected public operations
satisfy the source-level operation requirements in Feature#78. Installed
containing artifacts, retained-state bounds and independent Gaoxy runtime gates
remain unqualified. GitHub issue closure is not artifact acceptance.

The audited immutable source files include:

| Source at PR81 head | Git blob | SHA-256 |
| --- | --- | --- |
| `apps/http_runtime/lib/http/managed_transport.ex` | `558d65acd6867b712e84ec0727448d7eb223c069` | `92e0cc7649790029cf95b51c09e6d4e845c6183462083ab2272818cf57197c54` |
| `apps/http_runtime/lib/http/managed_transport/policy.ex` | `5f6c2b56f9f7d0cbc86851426530a045e714979c` | `d2164cc922893b9cb626b3886d1fbdc1c4f479f1253446277120df6720df1279` |
| `apps/http_runtime/lib/http/managed_transport/scope.ex` | `12ab5fa83c5945e591458f63b4db478e9ae9216a` | `73fb847f72846aa1d1f3fa0f3e4fc039741f0212b1d7fd4177f63d020e26b57b` |
| `apps/http_runtime/lib/http/http2/connection_owner.ex` | `01287bff0506b04b7254f8db0860af1c392790f6` | `18bb290088ebbfd8b56d141f45210f7055081deecbd01ab55edf47dc580d8857` |

Public documentation: [managed-transports.md at the immutable head](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/docs/managed-transports.md).
Source inspection is scoped; this table is not a complete upstream archive map.

## Exact public contract

`HTTP.ManagedTransport.open(options)` returns `{:ok, scope}` or an error. Required
options are `origin` URL, literal `connect_address` tuple and explicit
`http_version`: `:http1` for HTTP/HTTPS, `:http2` for HTTPS, `:h2c` for HTTP.
Allowed optional keys are `tls_backend`, `ssl`, `socket_opts`, `max_requests`,
`max_connections`, `max_pending`, `idle_timeout` and `http2_profile`. Only OTP
`:ssl` and `:native_v1` are supported. Duplicate/unknown fields reject.

| Limit | Accepted range | Default |
| --- | --- | --- |
| `max_requests` | 1..2048 | 100 |
| `max_connections` | 1..256 | 2 |
| `max_pending` | exactly 0 | 0 |
| `idle_timeout` | 1..60000 ms | 30000 ms |

Fetch selects the opaque scope with `transport_scope: scope`, manual/error
redirects, `decode_body: false` and `stream_response: true`. Frozen origin,
literal destination, TLS trust/material, writer/socket settings and protocol
must match; supplied conflicting overrides reject before dialing. Per-request
connect/total deadlines do not change managed reuse identity. Preparation and
unread responses retain request slots. Capacity covers raw sockets, TLS and
protocol owners until their tracked resources terminate.

`snapshot(scope, finite_ms)` returns redacted aggregate usage/limits, lifecycle
and policy digest; it does not expose credentials, connection identities or
history. After coordinator termination it may report `:transport_scope_retired`;
this error is not a cleanup receipt.

`retire(scope, mode: :graceful | :abort)` returns `{:ok, receipt}` or an error.
Repeated calls share a durable receipt; graceful can escalate to abort. The
public call has a fixed 5000-ms control timeout and no caller deadline option.
`await_retired(receipt, finite_ms)` is repeatable/concurrent and returns `:ok`,
`:cleanup_pending` or `:cleanup_unconfirmed` as appropriate. Success requires
both the completed durable latch and coordinator termination. Keep receipts
opaque in Gaoxy.

Request completion remains a separate barrier. An unresponsive caller upload
source can keep its request and retirement pending; connection-wide fragmented
header failure can correctly leave affected pooled request completion
unconfirmed. Neither outcome may be rewritten to success.

## Required Gaoxy mapping

`open/1` sets its caller as creator; creator DOWN initiates abort retirement.
Its handle call also has a fixed 5000-ms timeout. Reserve the transport record
and register its ledger with the generic core lifecycle participant before
allocation. Each bounded persistent proxy custodian opens and holds one scope.
Short-lived preparation helpers cannot create scopes. On preparation timeout,
reject publication, retain allocation holds and retire late-created scopes.

Run retirement initiation in bounded monitored helpers so the core, ledger and
custodian remain responsive. Limit helpers per scope to one initiation plus one
abort escalation. Preserve the original absolute shutdown deadline D, close
local admission immediately, and pass remaining time to public receipt waits.
Helpers outliving D produce pending shutdown, not five seconds of new success
budget. Recover a lost initiation result only through bounded repeated public
retire calls. Late confirmation may refund capacity but cannot turn a timed-out
stop into success. Helper/creator DOWN alone never proves retirement.

## Fragment bound and publication gate

PR80 limits a header block to 256 frames including initial HEADERS and final
END_HEADERS, rejects frame257 before retention/HPACK decoding, omits empty
fragments and preserves the 65536 compressed-byte cap. Error scope is the
connection (`:header_block_too_fragmented`). Independent regression must cover
256 success, 257 rejection with empty/nonempty and final/nonfinal variants,
affected siblings, independent connection progress and no replay.

At the last live check, 2026-10-10 16:39:53 UTC, latest GitHub and Hex artifacts
remain0.20.0. [Release38067971805](https://github.com/gsmlg-dev/http_fetch/actions/runs/38067971805)
is running at head `0833de2c4bbe7567cc19eed4a86a69005d2058f6`; its source
changelog declares0.21.0. This is a live upstream job, not a published artifact.

No supported coordinated immutable-Git consumer path was established. Source
manifests retain umbrella-relative paths and sibling dependencies; upstream's
publisher transforms portable manifests and qualifies Hex consumers. Keep the
installed containing-artifact gate and do not locally stage a replacement
release. This read-only architecture assignment used no recovery round.
