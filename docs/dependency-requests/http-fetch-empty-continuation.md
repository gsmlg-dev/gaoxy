# HTTP Fetch empty-CONTINUATION metadata bound

## Current 0.21.3 disposition — 2026-10-11

Bug#79 has a containing fix in installed0.21.3. Its original finite runtime
diagnostic remains INCONCLUSIVE; this disposition does not turn that historic
measurement into a bound or a passing diagnostic.

Installed coordinated packages are **0.21.3**, tag
`ceecbf2df62ca80c361597c7303f65a153f2ce3c`, tree
`6a44b862e8a09fb2648e48f928e37c20b1c8109a`. Compatibility486/0, public
managed39/39, supplemental TLS95 five cases/five cleanups, H1 baseline20/0,
B21 and public H2 supplement8/8 (TLS4/h2c4) pass with owned joins.
See [current acceptance](../acceptance/m3.md) for the exact execution receipts.
Five acquired-request failure regressions and final delivery review are pending.

Feature [#97](http-fetch-managed-h1-control-frontier.md) remains OPEN and blocks
complete H1 numerical/native control accounting and managed activation. Full
H2 accounting/adversarial backlog, managed integration, matrix and soaks remain
unqualified; managed Tasks4–8 and M4 stay gated. No local workaround is used.

## Historical 0.20.0 request and diagnostic

**Status: BLOCKED** on [Bug #79](https://github.com/gsmlg-dev/http_fetch/issues/79),
verified type Bug and label `internal request`. The runtime diagnostic is
INCONCLUSIVE; the missing finite metadata cap is source-confirmed.

**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m3-gateway`

**Severity:** blocker for Gaoxy M3 upstream H2 retained-state qualification. Dedicated HTTP/1 remains usable. This is separate from managed transport ownership/retirement Feature #78.

**Source-confirmed bug:** `http_runtime` 0.20.0 accepts an ordered response HEADERS without END_HEADERS, then empty CONTINUATION frames on the same stream. `ConnectionOwner` checks only compressed payload bytes (65,536) and retains each fragment as a new list element. Empty payloads keep the byte total at zero while retained fragment metadata grows by one element per frame. A request timeout bounds duration; it supplies no hard retained-fragment count/metadata cap.

Package provenance: Gaoxy pins the coordinated seven HTTP Fetch packages to 0.20.0. Their source is this repo. Actual immutable `v0.20.0` tag commit: `951ec75dadcebd8218f30d3ecdf99da142d4a463`. Installed `http_runtime/lib/http/http2/connection_owner.ex` SHA-256: `933fdbab2d36ca790611d7305e079c8b6f1e2ed825e6e7e62e354ef7f16e32d4`. Installed runtime files match that tag (package `mix.exs` uses the verified publisher staging transformation).

**Minimal source/wire reproduction:**

1. Via public `HTTP.fetch/2`, request an independent loopback h2c peer with `stream_response: true`, `decode_body: false`, `request_mode: :proxy`, finite timeout and isolated `http2_scope`.
2. After the standard connection preface/settings and request, peer sends a valid zero-payload HEADERS on the request stream with END_HEADERS unset.
3. Send a finite batch of zero-payload CONTINUATION on that same stream with END_HEADERS unset. There is no interleaving or server push; every frame has a 9-byte header.
4. `apps/http_core/lib/http/http2/boundary.ex` accepts the frame length/order. In `apps/http_runtime/lib/http/http2/connection_owner.ex:1006-1019`, each frame executes:

```elixir
size = block.size + byte_size(payload)
# payload == <<>>, therefore size remains zero and cannot hit 65_536.
next = %{block | fragments: [payload | block.fragments], size: size}
```

By induction, retained list length grows per accepted empty frame, independently of the compressed payload-byte guard. No private process call or state inspection is required to establish this source defect.

**Finite public diagnostic (inconclusive memory reproduction):** Gaoxy `integration/http_fetch_contract/empty_continuation_probe.exs` with `upstream_peer.py` sent exactly 4 x 20,000 empty CONTINUATION, 80,000 frames / 720,009 total wire bytes / 0 compressed header payload bytes. Elixir 1.18.5, OTP 28, ERTS 16.4.0.6, HTTP Fetch 0.20.0, Linux x86_64. VM-wide median process-used samples: 18,257,896; 21,173,576; 21,173,552; 22,949,528; 22,941,600 bytes. Growth: 4,683,704 bytes; deltas: [2,915,680, -24, 1,775,976, -7,928]. The predeclared criterion requires >=640,000 total growth and >=3 batch deltas of >=160,000. Only 2 deltas qualify, so the original verdict is **INCONCLUSIVE**, preserved without lowering thresholds.

Peer send receipts are not client application acknowledgements at sample time. VM-wide heap samples cannot uniquely attribute memory to the fragment accumulator. This issue is grounded in the source-confirmed missing metadata cap, not a claim that this diagnostic proves runtime memory exhaustion or a total-memory bound.

Public abort/await returned `:ok`, Promise returned `{:error, :aborted}`, peer observed stream reset, one request/one accept, and peer stop confirmed zero live threads/exit 0. Diagnostic exit 0 means the bounded experiment and cleanup completed; it does not pass retained-state qualification. Original logs and before/after source maps are retained locally under `docs/acceptance/evidence/m3/upstream-0.20/`.

**Expected behavior:** enforce a finite total retained header-fragment/count/metadata policy (e.g. do not retain empty fragments and enforce a finite count/time/work policy as needed) before appending. Reject or terminate the offending block/connection conservatively when policy is exceeded; never silently lose request cleanup or corrupt a healthy unrelated connection. Retain the existing compressed-byte, HPACK and decoded-header bounds. Add deterministic source/runtime regressions for empty HEADERS/CONTINUATION, including public request cleanup and documented connection error scope. Ship a containing release before Gaoxy enables upstream H2. No local dependency patch/workaround is authorized.

## Local evidence

- Original diagnostic: [`empty-continuation.json`](../acceptance/evidence/m3/upstream-0.20/empty-continuation.json), session60194.
- Corrected complete-source rerun: [`empty-continuation-final.json`](../acceptance/evidence/m3/upstream-0.20/empty-continuation-final.json), session16352, INCONCLUSIVE, 4,683,568-byte VM process-used growth, 2/4 qualifying deltas; all202 source hashes unchanged.
- Original201 maps omit the shared main probe; [`source-coverage-correction.json`](../acceptance/evidence/m3/upstream-0.20/source-coverage-correction.json) records that limitation and the202-file requalification.
- [`empty-continuation-issue.json`](../acceptance/evidence/m3/upstream-0.20/empty-continuation-issue.json) retains the verified live issue receipt.

Gaoxy leaves upstream H2 disabled. Resume only after a containing package release
passes finite-fragment/control bounds and the managed transport lifecycle gate.
