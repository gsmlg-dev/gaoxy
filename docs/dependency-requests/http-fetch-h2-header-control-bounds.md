# Managed H2 header and control backlog bounds

## Current 0.21.3 disposition

The containing fix is present in the independently verified installed 0.21.3
cohort. [Installed verification](../acceptance/evidence/m3/upstream-transport/upstream-0.21.3/installed-cohort-verification.md)
binds all seven archives, 196 shipped files and 175 runtime sources.
Compatibility486/0 and finite managed39/39 with canonical capacity MATCH and39
joined cleanups pass. Supplemental TLS95 now passes five cases/five cleanups;
the isolated0.21.1 negative control preserves both exact registration mismatches
and both successful cleanups. H1 baseline20/0 and the separately admitted B21
pass on the final grouped source with all joins and unchanged finite deadlines.
These selected functional gates do not establish complete memory accounting.
Feature [#97](https://github.com/gsmlg-dev/http_fetch/issues/97) is still OPEN and
blocks the supported native control bound/frontier needed for numerical H1
accounting and production activation. Full H2 accounting/adversarial backlog,
managed integration/soaks and the complete proxy matrix remain unqualified.
See [current acceptance](../acceptance/m3.md) for the H2 supplement and final
review receipts. The 0.21.2 and older dispositions below are preserved history.

## Historical 0.21.2 disposition

The containing fix is present in independently verified installed 0.21.2.
[Source/API review](../acceptance/evidence/m3/upstream-transport/upstream-0.21.2/source-api-review.md)
and [installed verification](../acceptance/evidence/m3/upstream-transport/upstream-0.21.2/installed-cohort-verification.md)
bind the current artifacts. Compatibility 486/0 and finite managed driver39/39
with canonical MATCH and 39 successful joined cleanups pass. Supplemental TLS95
registration is blocked in local identity tooling before cases; complete memory
accounting is not established. Feature97 blocks H1 numerical accounting and
activation; full H2 accounting/backlog and managed integration/soaks remain open.
See [current acceptance](../acceptance/m3.md). The former 0.21.1 disposition
below is historical; its absent95/remote-state claims do not apply to 0.21.2.

## Historical 0.21.1 disposition

#86 is closed; the containing fix is present in installed0.21.1. Independent
[source/API review](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/source-api-review.md)
finds lifetime informational-head admission, one in-flight capacity update per
owner and copied retained header/frame slices. Independent
[installed verification](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/installed-cohort-verification.md)
binds those bytes to the shipped cohort. Source containment does not complete
the finite adversarial-backlog recipe below or full H2/P0–P6 accounting.
The [finite cleartext green](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-green-analysis.json)
passes24/24 with24 successful joined cleanups and exact canonical capacity MATCH;
it does not execute the complete adversarial-backlog recipe. Full39/TLS remains
BLOCKED because installed0.21.1 lacks95's fix, even though
[refresh4](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/upstream-status-refresh4.json)
now records95 CLOSED. Managed activation remains disabled. The finding below
is historical0.21.0 evidence, not a claim that0.21.1 lacks the reported fix.

## Historical 0.21.0 request

Upstream: [gsmlg-dev/http_fetch#86](https://github.com/gsmlg-dev/http_fetch/issues/86).
Type Bug; label `internal request`.

**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m3-gateway`

**Severity:** blocker for M3 managed upstream HTTP/2 retained-state qualification.
Dedicated HTTP/1 remains enabled. This follow-up is separate from resolved
managed-resource #78 and header-fragment #79; Gaoxy has installed the seven
coordinated 0.21.0 Hex packages and verified their archive checksums, actual tag
source and fix ancestry.

**Source:** immutable v0.21.0 commit
`9813c126dc8b48055b9ee941c693fc27fa691489`. The relevant Owner/Pool/Policy bytes
are unchanged from independently audited PR81 head
`11f1642cf6408219d4813772bda1055e605bbdc4`. Two independent Sol source reviews
confirmed the missing aggregate accounting terms. This issue reports a missing
source-backed hard bound, not a performed runtime leak or memory-exhaustion
measurement.

## Required behavior and source findings

Gaoxy needs a conservative finite reservation before creating a managed H2
generation. Request slots, connection slots, DATA credit, compressed/decoded
header-block limits and the new 256-frame cap are useful but do not charge the
following outstanding notifications created by valid peer bytes:

1. In `apps/http_runtime/lib/http/http2/connection_owner.ex`, `header_events/4`
   (1200–1219) appends decoded response heads to `response_events`.
   `process_bytes/2` (747–765) processes the complete delivery before flushing
   that list. `notify_stream/3` (1545–1549) uses unacknowledged `send` to the
   request recipient. StreamState accepts repeated legal informational heads.
   Fetch's informational limit (128 responses / 65536 serialized bytes,
   SocketClient 1018–1054) is checked by the recipient later; no hard aggregate
   outstanding owner-event/recipient-mailbox admission was found before send.
2. Each valid non-ACK SETTINGS (853–885), including an empty SETTINGS, writes
   its ACK and invokes `report_capacity/1` (1711–1725). That sends an asynchronous
   cast to the managed H2 pool. Incoming rearm does not await pool consumption;
   no bounded outstanding-update admission or coalescing was found. Repeated
   deliveries can renew casts while prior pool messages remain outstanding.

`max_pending: 0` bounds the external request waiting queue, not either of these
queues. Native DATA receive credit does not charge headers/SETTINGS. Active-once
receive controls delivery count per rearm, not accumulated notifications. The
1 MiB writer check (667–710) bounds a synchronous batch; `state.bytes` is not an
aggregate outstanding notification/queue ledger. A request timeout is a finite
duration, not a retained-byte/count maximum. These messages arise from legitimate
wire input, rather than arbitrary excluded caller messages or OS/TLS allocation.

## Minimal finite public-peer reproduction / qualification recipe

This recipe is **NOT RUN** by Gaoxy yet; source accounting, rather than a measured
leak, is the current blocking evidence.

1. Open a public `HTTP.ManagedTransport` with explicit h2c, loopback literal
   address, `max_connections: 1`, `max_requests: 2`, `max_pending: 0`. Fetch a raw
   streamed manual-redirect response through that opaque scope, with a finite
   total deadline. Use an independent Python h2/raw peer.
2. After standard SETTINGS, send legal single-frame informational 103 HEADERS
   (END_HEADERS, no END_STREAM) in predeclared finite batches, first129 and then
   at most4096. Each individual block remains within byte/field/frame limits.
   Record raw peer frame receipts and exact request/connection counts.
3. In a separate named case, send at most4096 legal empty non-ACK SETTINGS,
   draining the client's ACKs. Record generation usage through the public
   snapshot and VM-wide samples with their attribution limits. Do not inspect,
   suspend, or modify private dependency processes.
4. Abort/await the original completion, retire/await the scope and join the
   peer under a single finite cleanup budget. Keep a second independent scope
   progressing and verify no replay. Pending/unconfirmed must remain explicit.

The runtime sample alone cannot prove a hard bound. Source qualification must
identify how every outstanding decoded-header/control notification remains
charged or coalesced before another one can be retained.

## Expected fix and release gate

Provide a supported finite aggregate accounting contract for owner response
events, request-recipient notifications and pool capacity updates, including
transient decode/copy overlap. Bound or coalesce peer-driven control updates
before enqueue; enforce notification admission before accumulation/send, or
provide an equivalent documented mechanism. Preserve healthy H2 sibling progress,
no replay, conservative request cleanup and whole-generation retirement receipts.
Document error scope and hard count/byte limits, with deterministic regressions
for repeated legal informational heads and SETTINGS. Ship the containing fix
before Gaoxy enables managed upstream H2. Gaoxy will not patch dependency source,
use private pool APIs or compensate with timeout-based memory claims.
