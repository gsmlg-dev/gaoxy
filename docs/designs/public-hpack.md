# Public http_core HPACK migration

Date: 2026-10-22. Requested migration from HPAX to the first-party shared codec.
Upstream prerequisite: gsmlg-dev/http_fetch#141, completed in the published
HTTP Fetch 0.21.16 package cohort. Verify the installed public documentation
before using the API.

## Design

`gaoxy_http` depends directly on `http_core`, with the existing `~> 0.21`
compatibility range and a minimum of 0.21.16. Its native HTTP/2 connection uses
`HTTP.HTTP2.HPACK` directly. Gaoxy continues to own socket, stream, admission,
flow-control and lifecycle state. HTTP/1.1, HTTP/2 and HTTP/3 remain required
product capabilities; QUIC and QUIC/HTTP3 dependencies are expected.

Keep one decoder per connection and retain its returned state across complete
header blocks, including blocks belonging to closed or rejected streams. Set
decoder limits from Gaoxy's existing compressed-block limit and conservative
expansion bound, rather than adopting the codec's smaller default field/byte
limits. Preserve pre-decode admission reservations and application-level header
validation and error scope.

Each response header/trailer block starts with an encoder resized to zero and
uses never-indexed literals with Huffman disabled. Carry encoder state through
the existing bounded per-field rendering, including the empty-block case.
Preserve ordered fields, duplicate fields, SETTINGS size updates, cancellation
independence and existing rendering bounds. Exact encoding assertions target
the selected public codec; RFC vectors and independent protocol peers retain
their independent wire checks.

Migrate source test peers and clean consumers to the public codec without a
compatibility shim. Remove HPAX from direct dependencies, package requirements
and active lockfiles. Core-only consumers continue to exclude HTTP/QUIC packages.
Historical design/acceptance evidence is immutable. Unscheduled and specialist
test sources receive only necessary codec API compatibility edits and retain
their existing execution disposition.

## Verification

Require warning-free compilation, codec/unit and curated ordinary HTTP/2
regressions, independent H2 RFC cases, built-package metadata and clean-consumer
checks. Unit cases must use no sockets or services. Network/protocol and package
checks run separately under their existing harnesses. Record exact positive
case counts, source identity and failures. No publication or deployment is part
of this migration.
