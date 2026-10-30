# ARB-H1H2-REVIEW2 final frozen-source review

DONE for this bounded read-only source review, direct continuation. No new
unaddressed actionable finding was established. This disposition covers the
frozen H1/H2 differential and inspected references; runtime acceptance remains
separate and parent-owned.

Repository `/home/gao/Workspace/gsmlg-opt/gaoxy`, branch `main`, baseline
`bc8a5ef5199293ada3b432c2e2741070d3b2d115`. Existing dirty integration was
preserved. The candidate is identified by `task-current.patch` SHA256
`f78015590dc5d8a919795602acd985068d0c0c2ae46703602882e68b24c0c48e`.
Only this report and its sibling `receipt.json` were written. No source, test,
example, manifest, Git, build, format, runtime, peer, test or network mutations
were performed. All commands created by this reviewer finished; parent-owned
verification session21877 was not touched. Underlying counters remain
Sol2/Astra16; reviewer Sol0/Astra0. No repair round or escalation occurred.

## Reviewed behavior

- WebSocket transport completion credit is independently classified. In
  `apps/gaoxy_http/lib/gaoxy/http/websocket.ex:589`, temporary credit replenishes
  the transport floor, while live application/message/output state remains
  WebSocket-category retention. Releasing WebSocket bytes does not increase
  that floor. Callback admission records the actually paid transport and
  WebSocket bounds (`:326`), and callback completion/output pop account their
  replacement before using their new bounds (`:417`, `:452`). Known total
  growth selects checked update directly; within-funded changes select
  repartition (`:636`). Send staging and release retain finite original
  lifetime/write bounds. Legacy unfunded category accounting remains present.
- `apps/gaoxy_http/lib/gaoxy/http/http2/stream.ex:69` does not restore the old
  Exchange HTTP-request credit after a WebSocket driver owns the upgraded
  lifetime. The ordinary H2 echo/close/sibling test retains full wire assertions
  and now explicitly requires zero admission rejections. The H1 large-output
  test retains its 10,000,001-byte equality and explicit1MiB transport cap and
  also requires zero rejections during the roundtrips.
- H2 connection accounting uses `max(F, R + Q) + P`, with receive/copy floor Q
  independent of completion and current decoder peak P. The source selects
  repartition from the last confirmed accounted total; true growth uses checked
  update. The original funded floor includes initial state, with bounded
  bookkeeping representation headroom. Delivered wire ownership is measured
  alongside current retained connection state.
- Native TCP reads its effective buffer through public `Hell.Socket.getopts`
  and uses `max(effective_buffer, 16384)`. TLS keeps the original conservative
  aggregation profile and host checks. Receive overflow rejects before
  concatenation; accepted complete partial input, parser rest, continuation
  blocks, queued stream input, delivered pieces and their remaining slices
  detach oversized backing. Controlled tests retain backing-size, actual
  public-buffer, delivered-wire, temporary-floor and real-response assertions.
  The floor test combines its exact reservation equalities with the supported
  native buffer bound; it does not qualify other driver/platform profiles.
- The phase-receipt constructor accounts the actual enlarged payload and
  finite rejection envelope. Pre-reserve deadline proof requires the matching
  token and genuine OTP response alias. Ordinary ambiguous timeout/cancel is
  not absence proof. Retirement pins its lease-or-spawn proof target and
  operation identity across late responses. CORE owner authentication,
  original deadline/revision checks, operation fingerprinting, membership and
  pending-process preservation, funded-total checks, and explicit transport
  cap enforcement remain on the inspected path.

## Close proof and prior finding

Prior P2 `H1H2-REVIEW2-01` is resolved in the frozen source:
`http2/connection.ex:2061` explicitly handles `message/2 -> :close` instead of
recursing with an atom. The controlled expired final-HEADERS-start regression
at `http2_websocket_idle_test.exs:102` retains actual worker-killed and writer
stop assertions. The successful-written sibling branch keeps the same guard.

Close joins only wire-complete workers under one shared absolute deadline,
capped by existing cleanup/drain and applicable worker/write bounds. Unfinished
workers are cancelled. Before submitting output-resource proofs, budgeted close
requires the exact writer monitor DOWN and drops parent stream, parser carry,
continuation and output references. Admission independently requires its own
terminal child evidence and canonical commit. Neither peer close, queued FIN,
local_closed alone, cancellation acknowledgment nor DOWN alone refunds usage.

If writer DOWN is unavailable before the original deadline, no resource proof
is submitted and the charge remains. Finished-worker waiting does not create a
new allowance for unfinished-worker or writer proof. The ordinary two-worker
buffered peer-close regression and normal-final-bookkeeping barrier retain
finite deadlines, killed/normal exit assertions and zero-quota assertions.
Forced-writer/slow-peer specialist qualification remains unrun and outside this
review; no guarantee for that slice is inferred from source or ordinary tests.

## Verification and limits

The before/after SHA256 maps in `receipt.json` match for all25 initially frozen
inputs:15 candidate source/test files,9 reference files and the differential.
No drift occurred. The invariant note was also read and separately hashed with
matching closing observation. Current baseline and branch were checked with
read-only Git queries. Only read-only text/hash/Git commands were executed.

No tests, compilation, formatter, listener, protocol peer, HTTP client or full
runtime were run by this reviewer. Parent-reported378 passing tests are not
independently claimed here. Parent must bind its final runtime/build evidence to
these exact candidate hashes; later source drift invalidates this source-only
approval until reconciled. All original assertions and historical specialist
dispositions remain preserved. No additional product decision is requested.
