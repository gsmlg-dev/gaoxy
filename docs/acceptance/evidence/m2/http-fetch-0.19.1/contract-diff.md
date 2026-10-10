# HTTP Fetch 0.19.1 bounded contract and source audit

Audit checkout: `gsmlg-opt/gaoxy`, `codex/m2-native`, baseline
`cee83108ccb862bad55cd43583e8ec976fe31ff9`. Root concurrently owns dependency
installation and runtime validation; this audit makes no production changes.

## Release identity

- GitHub release `v0.19.1` is published, non-draft and non-prerelease at
  `2026-10-10T07:20:34Z`: `release.json`.
- Independently resolved tag commit:
  `c26a17712a02a03985a764b6b100ca840fcc4349`: `release-ref.json`.
- Release workflow `38033156381` is completed/success. Its dispatch head is
  `b9b729949b5982c70015d571714010d05519132a`; the release tag is one subsequent
  `chore(release): v0.19.1` commit which changes package/root version declarations.
  The tag commit, rather than the workflow dispatch head, identifies audited source.
- Upstream [issue #64](https://github.com/gsmlg-dev/http_fetch/issues/64) is closed
  with reason `completed` at `2026-10-10T07:03:45Z`: `empty-query-issue.json`.
- Seven package release metadata files report version `0.19.1`, no retirement,
  and outer checksums matching the installed root `mix.lock`: HTTP Fetch, Core,
  Runtime, WebSocket, ExSSL, Elixir QUIC and Elixir QUIC HTTP3. The corresponding
  `*-hex.json` files preserve dependency requirements and published checksums.
  Package build metadata is unchanged; dependency requirements differ only by
  updating the existing exact cohort pins from 0.19.0 to 0.19.1.

## Source verification method

**PASS: immutable Git-tree verification.** The exact tag commit's recursive
Git tree is untruncated (`source-archive-git-tree.json`). Installed library path
sets exactly match the corresponding published trees. For every file,
SHA-1 of `blob <byte_size>\0<contents>` equals the published Git blob identity.
The audit additionally records per-file SHA-256 in `package-source-hashes.json`.

| Package | Verified library files | Difference from 0.19.0 |
|---|---:|---|
| http_fetch | 16 | Byte-identical |
| http_core | 32 | Only `lib/http/request.ex`, one predicate |
| http_runtime | 19 | Byte-identical |
| http_web_socket | 10 | Byte-identical |

`package-source-verification.json` records exact path-set/hash checks, missing,
extra and mismatched files (all empty), and all seven Hex/lock comparisons.
The ignored `.audit/http-fetch-0.19.1/source/apps/` directory contains these verified installed library bytes;
it is a library-only source snapshot, **not** an extracted full repository archive.
Other packages have release/lock metadata verification only, not a new complete
source/runtime qualification.

**Full archive download: incomplete.** The initial immutable codeload request
timed out after 60 seconds (exit 28, 13,254,656 partial bytes). The bounded
GitHub tarball retry was interrupted after the parent approved Git-tree
verification (exit 130, 14,856,192 partial bytes). Both partial files remain in the ignored audit directory; their
digests are identified in `source-archive-download-results.json`; neither is
presented as a complete archive. Both command sessions have stopped. No further
archive retry or Mix command was run by this worker.

## Public contract change

The complete four-library comparison against the 0.19.0 tag source
(`09b1686fb2ce529a17287d97801107c53b1ac57c`) has no added or removed library
files. Its only changed library line is `HTTP.Request.origin_form/1`, line 120:

```diff
-    if uri.query && uri.query != "" do
+    if uri.query do
```

An empty string is truthy in Elixir. Therefore `query: ""` now serializes the
existing path plus `?`; `query: nil` still omits the delimiter, and nonempty
queries follow the same previous branch. Request-target validation is unchanged.
No new raw-target override, public interface, default option or provider fallback
is introduced. The existing public HTTP Fetch path uses this corrected serializer.

## Cancellation, streaming and capacity

All public RequestCompletion/Promise code, RequestLifecycle ownership code,
SocketClient, Stream, H1 upload/parser/trailers, runtime delivery/dialer and
TCP/OTP-SSL transport files are byte-identical to audited 0.19.0. Consequently
this release does not change the direct-H1/manual/non-reused/:ssl completion
boundary, acknowledged upload/download ordering, cancellation scope, finite
deadlines or transport options used by Gaoxy.

No receive/parser/copy-capacity assumption changes were found. The previous
source-qualified OTP 28.5.0.5/default `:inet`/active-N 1..100 evidence remains
applicable to the unchanged receive path: explicit 8,192-byte receive buffers,
837,637-byte conservative SSL delivery and 65,536-byte framing carry. This is
not qualification of another OTP version, ExSSL/QUIC runtime, or total BEAM and
kernel memory. The newly retained delimiter was already present in the caller's
URL footprint charged by Gaoxy's reservation.

## Verdict and validation boundary

**PASS: provenance and bounded source-contract audit.** No unexpected regression
or additional upstream blocker was identified in the compared library sources.
The intended #64 serializer fix is present in the published, installed 0.19.1
source. Runtime/wire regressions, compilation and final M2 acceptance belong to
the root's separate validation; this worker ran no Mix tests and does not claim
those gates passed from source comparison alone.
