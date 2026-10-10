# Managed 0.21 public probe independent specification review

Task: Task3 managed probe review; direct independent Sol assignment. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `4cc7a1a967d1b90a62d42db438316b10a03a1e16`.
Reviewed 2026-10-11 Asia/Shanghai. Probe author is `m3_public_client_audit`;
reviewer did not edit fixture sources. Reviewer owns only this report. Parent
is serially running compatibility and the initial managed fixture under a
source freeze; no Mix, fixture, application, network peer, or private upstream
API was run by this reviewer. The separate retained-bound worksheet is this
reviewer's earlier authored work and is **not independently certified here**.

## Verdict

**CHANGES REQUESTED for complete Task3 prerequisite qualification.** Static
inspection supports a meaningful finite public-resource smoke, but a green
36-case execution cannot establish deadline preservation or zero rejected
request bytes from the current assertions. Parent runtime results are separate
and were not available at review completion. No upstream issue or mutation was
performed; actionable findings were sent to parent before writing this report.

## Actionable findings

1. **High: unequal-deadline values are exercised without deadline behavior.**
   `managed_transport_probe.exs:270–296` makes two fast sequential successful
   requests with different total/connect timeouts and requires one accepted
   connection. A client which shares a mutable timeout between requests or
   ignores a short total deadline can still pass. Task3 explicitly requires
   reuse **while preserving each absolute deadline**, not only identity reuse.
   Add a finite peer-held short-deadline request and assert its exact public
   timeout/cleanup outcome; for H2 retain a longer-deadline sibling through that
   timeout and complete it on the same connection, then admit a further sibling.
   H1 can prove a timed-out request cleans up and the next request uses the
   permitted connection lifecycle; concurrent multiplexing is not an H1 claim.
   A zero-time wait yielding cleanup_pending alone does not exercise a deadline.

2. **High for the advertised before-bytes gate: complete requests are not all
   request-bearing bytes.** `managed_peer.py:22–40` records H1 requests after
   reading all headers/body; H2 `:65–76` records only `RequestReceived`, with no
   independent raw HEADERS/CONTINUATION counter. A rejected operation can emit
   a partial request line/header or an unfinished H2 header block on an existing
   socket and then fail without appearing in `Peer.requests`. Negative cases
   check the list of complete requests and sometimes accept count, so their
   `before_bytes` labels overstate the observable guarantee. Add finite raw H1
   ingress/request progress and H2 request-frame/bytes counters, with peer-side
   observation barriers around each rejection. H2 control ACKs remain valid and
   must not be mistaken for rejected request bytes. Narrowing prose to “no
   complete request” accurately describes current evidence but does not satisfy
   Task3's zero request-byte acceptance requirement.

3. **Medium: request saturation omits the no-extra-accept assertion.** Common
   request-capacity case `managed_transport_probe.exs:328–347` asserts one live
   connection at a snapshot and a single completed request path. An extra
   accepted socket that closes before the snapshot escapes both checks.
   Require exactly one peer accept after rejected completion and teardown, as
   the H1 connection-capacity and H2 GOAWAY cases already do. This complements
   finding2; it does not replace byte-level observation.

4. **Medium: fragment replacement lacks scope/connection identity and confirmed
   aggregate release checks.** Shared-fragment case `:648–667` calls `idle(a)`
   (request counters only), then replaces; it asserts three total accepts and
   path order without connection IDs. Pin offender and sibling to failed cid,
   healthy scope to healthy cid, and replacement to a new cid different from
   both. If the result claims replacement waits for confirmed connection
   capacity, use the existing public `zero_connections/2` helper before retry.
   `closed(peer,cid)` proves peer socket closure, not independently tracked TLS
   and protocol-owner release. The GOAWAY case already uses that stronger
   public aggregate condition.

5. **Low: GOAWAY PING comment overstates the barrier.** Peer `:109–111` says ACK
   proves the preceding GOAWAY's draining notification to the pool. It proves
   the connection owner processed GOAWAY and sent its pool notification before
   parsing/sending PING ACK. Source Owner uses asynchronous `GenServer.cast`;
   ACK does not prove the pool consumed the cast. The strict subsequent observed
   `pending_capacity` result plus snapshots supplies the functional draining
   assertion when runtime passes. Describe the barrier as owner wire processing,
   without claiming independently synchronized pool consumption.

## Static strengths and coverage limits

| Requirement | What the reviewed source actually asserts |
| --- | --- |
| Public-only resource selection | Opaque scopes/receipts passed to supported ManagedTransport APIs; no private scope fields, connection-owner calls, global retirement or dependency patches. Public stream PID ACK protocol is shared from the historical helper. |
| Private same-origin scopes | Two accepts and exact `/a`→cid1, `/b` and `/b-survives`→cid2 mappings; retired A rejects and conflicting address rejects. Existing B is idle at A retirement. |
| Request completion vs generation lifetime | Original completion captured before Promise.await; completed reused requests leave one connection/resource count before explicit retirement. Held requests and graceful receipts return cleanup_pending separately. |
| Request and connection capacity | R1/C1 common rejection and R2/C1 H1 rejection are distinct; H2 GOAWAY holds one admitted stream while independent scope proceeds and replacement waits for zero public counts. Findings2/3 limit before-byte claims. |
| Retirement/creator lifecycle | Graceful drain rejects late work then closes late checkin; abort closes held request; creator normal DOWN escalates a pending graceful receipt. Repeated and two concurrent receipt waits are exercised after terminal success. Concurrent pending receipt waits are not exercised. |
| Fragment count boundary | Peer explicitly builds HEADERS plus continuations and asserts len256/257. Two256 successes cover empty and bounded bodies; four257 variants cover empty/nonempty × final/nonfinal. Client requires exact header_block_too_fragmented error and peer connection closure. |
| Affected siblings and independent scope | Offender Promise and same-connection sibling stream receive exact connection failure; independent held response remains cleanup_pending and later completes. Original shared-owner completion remains cleanup_unconfirmed; separate scope retirement must confirm termination. |
| No replay | Exact complete request path lists and accept counts reject ordinary full-request replay; partial rejected request bytes and replacement identity need findings2/4. H1 reused POST also checks exact method/body and one accept. |
| Shutdown and conservative uncertainty | Cleanup attempts every registered scope and original completion, captures failures, then requires joined peer with live_threads0 and process exit0. Expected unconfirmed completion is registered only after exact observed await; cleanup never rewrites it to ok. |

The prepared case count is **36** by static enumeration: six common cases across
three protocols (18), two H1 extras, two H2 GOAWAY capacity cases, and seven
fragment cases across two H2 protocols (14). `run/0` asserts the executed count;
each case emits its receipt before the enclosing cleanup, so only final process
exit0 and final marker together establish a successful run.

The canonical H2 error mismatch is explicitly separate: lines491–505 log
`documented`, `source_expected`, `observed` and mismatch; the strict assertion
requires source-predicted `{:error,:pending_capacity}`, and case/final reports
retain `canonical_error_contract: :mismatch`. This is acceptable diagnostic
coverage but **cannot be recorded as canonical contract PASS**. Parent owns
runtime confirmation and upstream routing.

Not covered here: valid header/control backlog limits, RSS/heap hard bounds,
600-second managed soak, Gaoxy integration, reload churn, certificate rejection
or trust rotation, stalled uploads/trailers, request-local abort preserving a
healthy same-scope H2 sibling, or live scopeB surviving scopeA force retirement.
These are separate gate coverage; connection-wide fragment failure preserving B
must not be substituted for request-local cancellation or force-retirement
isolation. A count of36 is not full M3 acceptance.

## Reviewed source identity and checks

Parent supplied containing-tag identity v0.21.0 at
`9813c126dc8b48055b9ee941c693fc27fa691489` and installed archive/runtime source
provenance PASS. This reviewer did not rerun artifact installation/provenance.
The following hashes pin the local files actually reviewed:

| Local file | SHA-256 |
| --- | --- |
| `integration/http_fetch_contract/managed_transport_probe.exs` | `f3aa2cdad934d62e323dc41c491d2d9292089c8284fddce3c37bd3f8efb7f5a5` |
| `integration/http_fetch_contract/managed_peer.py` | `a32d9121431fdaa308ba0391ad05178ec9abf8fcaf130334a9cc206dc5d05bb5` |
| `integration/http_fetch_contract/MANAGED_README.md` | `fc3894b1e43dacae6860df3507b6573acf409db45010c457dd22bf3806b0e210` |
| `integration/http_fetch_contract/pooled_completion_probe.exs` | `f681723ff58754cb6169d0b42fb681a8439eeaa6c7ec7e94c752894405ce1e30` |
| `integration/http_fetch_contract/upstream_peer.py` | `f2e40b0e72362f06b4c933b14f45d49e768b2133bee4281c4241bbd122d9b95f` |

Verification performed by reviewer: read-only source/spec inspection, Python
AST parsing for managed/historical peers (no import or pyc), static36-case
arithmetic, report whitespace check and source hashes before/after report creation.
Runtime/Elixir syntax execution: **NOT RUN**. All reviewer commands completed;
no reviewer peer/process remains. Sol repair rounds0; no Astra counter received.
Fixture repairs and frozen-source restart are parent-owned. No architecture
expansion or user decision is needed for the assertion repairs above.
