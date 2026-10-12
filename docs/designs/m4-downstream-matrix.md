# M4 downstream proxy and browser integration

This supplements the reviewed native/shared H3 designs after G2. Continuing
authorization permits the necessary compatibility repairs and local commits;
publication, deployment, Vault, production data and release-artifact E2E remain
excluded. This slice qualifies downstream H3 with the existing dedicated H1
origin adapter and a real Phoenix HTTP page. Upstream H3 and standalone opt-in
have their own design and acceptance gates.

## Existing HTTP contracts

Use the existing Router/Endpoint/Exchange/Response path. H3 needs no new proxy
endpoint or upstream session process. Keep fixed reverse-proxy authorities,
destination/authentication policy, public client completion and finite cleanup.
No reusable H1/H2 pools or automatic upstream protocol selection are enabled.

The framed downstream can carry trailers independently of Content-Length.
Allow HTTP/3 in the existing request and response trailer policy, preserving
declaration, forbidden-field, hop-header, forwarding-identity and byte limits.
When an H2/H3 request declares allowed trailers, its dedicated H1 upload must
use chunked framing: remove forwarded Content-Length and select a streaming
upstream body even for a zero-length request. The validated downstream length
and ordered trailers remain the downstream protocol owner's responsibility.
Ordinary H1 fixed-length and H1/H2 trailer restrictions retain their contracts.
Response trailer declarations with Content-Length retain the existing rejection
for H1, H2 and H3 in this bounded proxy profile. Qualify response trailers from
an independent chunked H1 origin, and test fixed-length declaration rejection
for every downstream protocol; the native H3 facade's wider capabilities do not
silently widen this proxy policy.

An H3 request can finish before its worker receives the upstream-ready event.
Finish an existing upload exactly once when the Exchange body is already done,
using its validated trailer policy. A nil upload has no stream to finish.
Never wait for an impossible extra body-read event, lose ordered trailers, or
reopen an upload after an early origin response. Preserve the original request
deadline and the existing guardian's completion/Admission cleanup boundary.
The existing dedicated H1 adapter stops an upload on an early final response.
Qualify progressive upload before request FIN and progressive download before
origin response FIN in separate ordinary cases; separately require an early
413 response before upload FIN and termination of unread input. Do not claim
full duplex upload continuation after a final head from this bounded adapter.

Deterministic regressions cover ready-before/after-complete ordering and actual
H1 wire framing. Real aioquic requests cover escaped/empty queries, streaming
upload/download, fixed and zero-length repeated trailers, early responses,
request reset and same-connection/separate-listener siblings. The origin is an
independent loopback Python HTTP/1 fixture, not another Gaoxy server or mocked
client. It records received bytes, target, headers, trailers and cancellation.
Require the fixed upstream Host, regenerated X-Forwarded-For/Host/Proto, dropped
hop fields and spoofed forwarding identities on the actual origin wire. Reject
forbidden authentication-sensitive trailer declarations before upstream work,
and retain existing negative destination/authentication policy tests.

## Phoenix browser fixture

Add an explicit H3 fixture dependency to the existing Phoenix example and an
external H3 gateway script. Set the Phoenix Endpoint's `server: false` before
starting its application; Gaoxy owns the only H3 listener and serves the Endpoint
as a Plug. Use the existing ordinary index and static content without modifying
the controller, adding a production server, or making a WebSocket claim.

Start only ephemeral IPv4 loopback listeners with generated local test
credentials. Chromium uses a fresh process/context, the fixture leaf's SPKI
pin, an explicit `--origin-to-force-quic-on=localhost:<port>` test mapping and
process-local `--host-resolver-rules=MAP localhost 127.0.0.1` to match the
IPv4-only fixture listener. Preserve Chromium netlog for handshake diagnosis.
No system/browser trust store is changed. CDP must report `protocol: h3` for
the exact document URL; correlate a unique browser request marker with server
evidence and assert the rendered Phoenix page and a static response. H1/H2
fallback cannot satisfy this gate. Record installed Chromium, Playwright,
Python, Elixir/OTP and dependency identities. H3 WebSocket remains UNSUPPORTED.

## Isolation and evidence

Repeat clean core and H1/H2 consumers after shared response extraction. A clean
H3 consumer declares the optional package/QUIC runtime cohort explicitly and
executes a real verified-CA H3 request; the ordinary consumers must exclude the
QUIC and HTTP-fetch runtime applications as their existing assertions require.

The matrix runner starts only owned children, waits for readiness, enforces
finite request/teardown deadlines and captures exact source hashes before/after.
No hashed source may change during a live gate. Require nonzero peer/browser
cases, Admission and resource cleanup, all children exited and ports rebound.
Keep unexpected failures and source-bound repair evidence immutable. G3 does
not substitute for the separately required upstream-H3/standalone M4 gates.
