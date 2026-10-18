# Native H1 pressure diagnosis1

Status: DONE for bounded read-only diagnosis. Root cause remains UNESTABLISHED; no source/runtime repair was attempted. Root actual probe remains FAIL1/1 exit2 with no success receipt.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; root-verified entry `fb7d0fda2b7c16c42c65579736dc1f643e17d812`. Frozen467 unique manifest files remain byte-identical. Root runtime404 before/after source maps both equal candidate1.
JSON report SHA256: `ddbcae40f940fb8033ab81f357e2a96cb2203eb4ec70c37e881c570567f2bee3`.

## Concrete findings

- **F1 CONFIRMED:** Root probe failed1/1, exit2, zero skipped/excluded; no success receipt. Frozen source before/after both equal candidate1. Collector reports process joined and no remaining process group/descendants. `initial-probe1.json; initial-probe1.log:8-27`.
- **F2 CONFIRMED:** Primary reported error is sampler line739 badmatch on Socket.getstat returning error einval. The sampler catches this at788 and forwards failure to controller; failure_cleanup then closes clients/stops sampler/joins or forces owned actors/stops fixture. The later fixture response-release deadline and forced cleanup must remain recorded as separate cleanup failures. `test:714-789,1170-1234; log:12-23`.
- **F3 CONFIRMED_STATIC:** A declared262144 upstream chunk is accepted by HTTP.HTTP1 parser; parse_chunk_size accepts40000 hex and chunk_data emits min(buffer,remaining,65536). HTTPFetchClient response delivery cap is837637+65536=903173; the proxy max_chunk65536 config controls upload reads/reservation and is not a262144 wire-chunk rejection. No upstream defect or dependency workaround is established. `deps/http_core/lib/http/http1.ex:9,143-184,462-473; HTTPFetchClient:9-15,174-177; HTTP:861-875`.
- **F4 STRONG_CONTROL_FLOW_INFERENCE:** Runtime stack contains failing sample_turn739 and prior sample_turn786. Line786 is reached only after a full successful sample turn including getstat739 and remaining assertions. Thus at least one earlier getstat succeeded with the same captured socket API. Blanket unsupported getstat or universal non-owner observation failure does not fit this run; validity changed later or failure is state-dependent. `log:14-15; test:714-789`.
- **F5 CONFIRMED_EVIDENCE_GAP:** No phase markers, first-error timestamp, client/native DOWN reason, endpoint result, failing sample turn count or latest pending O are emitted before failure cleanup. The receipt therefore cannot distinguish native send-timeout close, endpoint/proxy error close, client error close, late observation after otherwise completed work, or other socket-state change. `test:87-102,714-789,1029-1036; initial-probe1.log`.
- **F6 CONFIRMED_LIMIT:** Per-case5255.1ms includes failure cleanup with separate finite5s budget; ExUnit total8.3s and collector12.042862934998993s measure different scopes. They do not timestamp the primary einval or prove that a request/write deadline expired. No timeout extension or unsupported API substitution follows. `log:8,26; initial-probe1.json:elapsed_seconds; test:1170-1234`.

## Smallest evidence patch proposal

No production fix is supported by current evidence. Keep wire input/deadlines/capacities/assertions unchanged; add only bounded failure chronology to the owned test.

1. Add bounded event-generation controller phase markers at sampler-start, head-received, prefix-dispatched, first-pressure-found, healthy-overlap, after-healthy, release, prefix-consumed, EOF-released and sampler-stop. Use fixed phase names, monotonic microseconds and hashes only; at most16 records.
2. Retain exactly the latest pressure_snapshot in controller process storage, including every failed witness conjunction: bounded MFA-only stack, send_pend, exact pending operation hash/bytes and timestamps. Replace the prior snapshot rather than accumulating samples. This captures an unrecognized native send wait without changing the allowlist or pressure predicate.
3. At sample_turn739 retain the exact Socket.getstat result in a variable; on non-ok send one bounded diagnostic context before executing the unchanged {:ok,socket_stats}=result match. Include turn index, timestamp, exact result, hashed owner/socket/lease, already-read gate lease/pending operation bytes/operation hash, Service counters and phase evidence. Do not replace error with zero/retry/success.
4. Wrap only ObservedEndpoint delegate call with outcome notification: timestamp, owner hash, ok/error/exception class, bounded safe reason, response mode and close flag. Return the exact result or re-raise with original kind/reason/stack. At most2 records; no private upstream-client state or raw body/stack arguments.
5. In controller catch, before failure_cleanup, emit a distinct failure-diagnostic JSON record containing only already-generated bounded phase/sampler/endpoint records, retained scoped telemetry and already-arrived native/client DOWN/failure packets. Preserve the original error and all cleanup assertions. Do not block waiting for new observations or reuse success receipt prefix.
6. No separate getstat runtime preflight is needed: earlier successful sampler turn already demonstrates live use of this API. Root explicitly reports NOT RUN for such a preflight. Independently review the diagnostic-only patch, then run one bounded existing fixed/TCP test with source/count/deadline/assertion freeze and existing collector; no four-row expansion.

Do not convert einval to zero/polling success; do not extend deadlines, increase payload/buffers, reshape upstream chunks speculatively, inspect private client processes or reset counters. No dependency bug is established.

## Incidents, counters and custody

Exactly3 new tooling incidents (not runtime/repair failures):

- 1: Initial receipt read printed nested source-map key lists and exceeded output budget; recovered by full27-line log read and scalar/count-only receipt projection.
  - `Warning: truncated output (original token count: 11216)`
- 2: Resolved package ownership from installed http_fetch mix.exs provenance and scoped filenames.
  - `rg: deps/http_fetch/lib/http/http1.ex: No such file or directory (os error 2)`
- 3: Resolved actual package http_core from installed dependency declaration, then read exact parser source. No repeated known-failing attempt.
  - `rg: deps/http_protocol/lib: No such file or directory (os error 2)`

Counter6 is authoritative; root initial runtimeFail1 awaits counter7. This diagnosis adds0 Sol repairs/0 runtime runs and3 tooling incidents only. Inherited H1Sol4/Astra2/2 exhausted remain unchanged.

All reviewer runtime/tests/compiler/formatter/browser/Git and diagnostic patch execution are NOT RUN. Separate public socket preflight was NOT RUN by root or reviewer and is unnecessary given an earlier successful sample. Only the two requested `/tmp` reports were written; all synchronous commands finished. Return custody to `/root`.


Additional bounded hypothesis from root: the actual OTP wait may be `prim_inet.send_recv_reply/2`, which is absent from the current send/send0 allowlist. An unrecognized real send wait could prevent pressure acceptance until the unchanged2s native write timeout closes the socket. This is UNESTABLISHED: retain the latest failed conjunction snapshot/MFA stack and actual O telemetry before changing any predicate. Root reports2 separate tooling errors, not included in this reviewer's3.
