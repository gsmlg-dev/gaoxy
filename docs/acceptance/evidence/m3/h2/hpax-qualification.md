# HPAX 1.1.0 and native H2 qualification checkpoint

Source checkout: `22b76e8051ddaf09e36797cb781b9b119870a9d4` plus task diff. Qualification runtime: pinned Nix shell, Elixir 1.18.5 / OTP 28 / ERTS 16.4.0.6, x86_64 64-bit BEAM. No dependency source edits.

## Artifact and public API — PASS

- Hex `hpax` exactly 1.1.0, source `https://github.com/elixir-mint/hpax`, Apache-2.0, Elixir `~> 1.15`, no runtime dependencies.
- Untouched downloaded package `.audit/hpax-1.1.0/package.tar` SHA256 `0b8d0f05832f55571d65ac720f79bf8994138ffbb133209dc4685eae0ad456a8`; matches Hex outer checksum pinned in mix.lock. Inner checksum `782931867cc23217c68fb5f68fe1a11f5e7544c7fda82c8a7019a5df5a4a1cdf`.
- Only public HPAX `new/1`, `decode/2`, `encode/3`, `resize/2` are called by production H2. Internal package modules are inspected for qualification only. Public `protocol_resize/2` is available if a future local decoder resize is needed; initial decoder capacity remains fixed.
- Sender uses `:never_store`; encoder peer table capacity is clamped to the local finite limit. No HTTP Fetch private H2 machinery or production Bandit dependency.

## Expansion reservation — source and regression PASS

For compressed block B and decoder table T reserve before any decode:

`decode = 2 * B * (max(T, 128) + 2) + 512 * B + 2 * T`

Pinned source justification: each decoded header consumes at least one encoded byte (HPAX.ex decode_headers clauses); indexed dynamic field payload is bounded by T; static table maximum field payload is below128; literal/Huffman payload expansion is below twice compressed length (minimum Huffman code5bits); table occupancy counts header bytes plus32 and cannot exceed T. HPAX.Types bounds integer decode to32bits and five continuation octets. The allowance includes payload copies, two table payloads and conservative per-field term/list bookkeeping for the qualified64bit runtime. It is a conservative payload/copy/term allowance, not an assertion about whole-process RSS, GC heap fragments, socket/kernel memory or application-owned bodies.

Owner reserves decode capacity plus16MiB and initial65535byte receive capacity before H2 SETTINGS; stream/writer Admission leases are additive. Default profile decode=142680064bytes; connection=159522815bytes; stream=196608bytes; writer=66560bytes. Minimum service budget for one of each=159785983bytes and max_active>=3. Core defaults remain unchanged; qualified examples supply512MiB/128active/32localstream slots.

`http2_codec_test.exs` includes independent RFC7541 C.4 Huffman/dynamic-table vectors; a4000byte dynamic value repeated16384times via index0xBE, checked against the payload bound and flat term size; malformed indices, long integers, Huffman literals, oversized table update and invalid mid-block update. All3 codec regressions passed in checkpoint-repair-2.log. HTTP2ProtocolTest4 pure tests also passed.

## Current protocol/network evidence

- Initial engine green:12 tests/0 failures, engine-repair-1-actual.log (TCP native framing/concurrent bodies, stream worker reset isolation, zero-window sibling, trailers, continuation exclusivity, façade/pure tests).
- Scoped H1 compatibility and added H2 checkpoint:60tests/1failure, exit2, checkpoint-repair-2.log. Malformed TLS error preservation is repaired; H1 checks in this command pass.
- Independent Python h2=4.3.0/hpack=4.2.0/hyperframe=6.1.0 peer installed only in isolated `.audit/h2peer` tooling venv; requirements and finite peer are checked-in test support. Its first TCP connection fails at SETTINGS because it advertises standard extension setting8=0 and the server currently rejects every8 value. Raw independent SETTINGS `{1:4096,2:1,4:65535,5:16384,8:0,3:100,6:65536}`. Expected unsupported-extension handling is to ignore the setting while continuing to reject extended CONNECT pseudoheaders. No peer assertion has been weakened.
- Independent TCP flow-controlled90KB request/response, Huffman/dynamic peer traffic, HEAD/trailers: FAIL at initial SETTINGS; verified TLS ALPN/cross-process SSL send: NOT RUN because TCP case stopped first. Existing H1 TLS network check passes.
- P3 proxy/guardian H2/reset/disconnect/drain/writer-crash/reload acceptance: NOT RUN. Native H2 must not be claimed complete from the initial green tests.

## Repair budget and shutdown

H2 Sol repair rounds cumulative2: round1 fixed missing response façade delegates and passed; round2 repaired TLS validation shape and coalesced receive-window credits, but independent SETTINGS failure remains. One of the two repair rounds was unsuccessful. Source edits stopped for parent budget/routing clarification; this is not a technical impasse. All own shell/Mix sessions have completed; no worker-owned command remains running. No commits or pushes.

## Current qualification after independent S1–S4 repairs

The earlier failures/repair counters remain historical. The finalized round11
connection reserve adds configurable parsercarry and qualified active-once OTP
SSL delivery/copy allowances while preserving prior codec/state capacity:

`connection = decode + 16777216 + 65535 + 4*max_buffer_bytes + 8*(100*16384+18437)`

Fixedbuffer16384 is independent of body-read credit; qualified backend:inet,
TLS internal_active_n integer1..100. The connection's initial65535credit is
independent of the configured per-stream receive window. Defaultconnection
173039655bytes; stream196608; writer66560; one-of-each minimum173302823bytes.
This remains a scoped retained payload/copy/term allowance, not a total BEAM
heap/GC or OTP/kernel-memory measurement.

`../canonical-round11-formatted.log`: strictformat/compilePASS; scoped456/0
seed216300, correctedRFC40/0 and cleanexternalcore1/0 seed387754, exit0.
Independent Python TCP plus CA/hostname-verified TLSALPN/cross-process writes
now PASS in the196-test HTTP scope. SETTINGS8 is ignored as an unsupported
extension while extendedCONNECT remains rejected. NativeH2 proxy cancellation,
guardians, repeated generations and finite ownership teardown execute in that
scope. ParentnativeH2Sol11, unsuccessfulproduction1, Astra0; expectedTDDreds and
fixture/format correction failures remain separately preserved. FullM3 remains
BLOCKED on upstream66/67, and finalpost-S5/browser/600s gates remain pending.
