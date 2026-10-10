# Charge normalized managed request inputs before admission

Upstream: [https://github.com/gsmlg-dev/http_fetch/issues/87](https://github.com/gsmlg-dev/http_fetch/issues/87).
Type Bug; label `internal request`; severity needed.

**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m3-gateway`

**Severity:** needed for complete managed input accounting. Current Gaoxy uses
bounded URL strings, explicit fields and nil/PID uploads, so these broad public
forms are unreachable in that adapter. This is not an H1 activation blocker or
a runtime leak claim. No dependency/private-API patch is proposed.

**Source:** installed seven-package 0.21.0 cohort, actual immutable tag
`9813c126dc8b48055b9ee941c693fc27fa691489`. Gaoxy verified all196 shipped
files and175 runtime Git blobs. Two independent source reviews confirmed the
following pre-normalization charge gaps. Reproductions below are finite
source-backed recipes, **NOT RUN**; no measured memory or wire outcome is claimed.

## Findings and minimal recipes

Open a public H1 `HTTP.ManagedTransport` pinned to an independent loopback peer,
with finite C2/R32/P0 limits. Use public Fetch, capture original completion,
manual redirects and raw streaming, finite request deadline and bounded cleanup.

1. **Late Content-Type exceeds the managed request field budget.**
   FetchOptions289–310 preserves `content_type`. Managed Policy148–164 checks
   explicit fields/path/query but ignores that convenience input. Request152–154,
   183–189 and263–264 insert Content-Type after admission. HTTP1.prepare_request
   44–52 and safe_header_value535–538 add no size check for printable values.
   Recipe: `{:ok, upload} = HTTP.Stream.start_link(0)`; Fetch a matching URL with
   `body: upload`, no explicit Content-Type, and `content_type: String.duplicate("a", 65_537)`.
   The visible request passes the earlier64KiB field charge while normalized
   serialization has a larger ordinary header. Expected: normalize and reject
   over-budget effective fields before dial/request bytes.
2. **Unused URI authority escapes retained request charge.**
   Fetch282–298 accepts a `%URI{}` unchanged. Policy148–157 charges only fields,
   path/query, and170–173 compares scheme/host/port, not authority. SocketClient
   304–314/531–556 retains the full request;1431 puts the original URL in response.
   Recipe: parse a matching URL then set `authority` to `String.duplicate("a", 131_072)`.
   Expected: normalize/reject unused URI metadata or charge every retained field,
   rather than carrying an arbitrarily large uncharged convenience value.
3. **Buffered empty iodata has no structural retained-input bound.**
   Policy162–164 uses `IO.iodata_length`; FetchOptions278/309–310 retains the
   original term; Request254 flattens later. The original request remains in the
   H1 owner context/state after flattening. Recipe: `body: List.duplicate([], 8_192)`
   has zero logical bytes but thousands of retained list cells. Expected: enforce
   a structural/normalized-input charge or reject such forms before retention.

Run each named case with a finite independent peer and exact accept/request-byte
receipts; abort/await the original completion, retire/await scope and join peer.
These recipes do not inspect private processes or rely on a shared global pool.

## Needed behavior

Apply the managed request charge to the final normalized supported request,
including convenience fields and retained original representations. Include a
finite structural/backing contract where logical payload length is insufficient,
or reject unsupported public forms before admission. Preserve existing public
error/cancellation/retirement behavior and no replay. Add finite regressions and
publish containing artifacts before Gaoxy broadens its controlled input profile.
