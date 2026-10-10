# Dependency follow-ups

## Proposed feature: ex_ssl TCP server transport

Target: `gsmlg-dev/http_fetch`, `apps/ex_ssl`, inspected at
`a02af288d8729c3bdcae4d3de8dc2751c2b04e37` (0.17.0).
Requester: `gsmlg-opt/gaoxy`, branch `main`; no remote existed when this
follow-up was prepared during implementation acceptance.
Severity: needed for optional custom TLS; ordinary OTP TLS remains independent.

The public `SSL` facade exposes clients but lacks TCP listen, accept, server
handshake and directional shutdown. Add a bounded server ownership contract,
then a formal Thousand Island transport adapter. Acceptance must cover
credentials, independently verified handshakes and failures, active/passive
delivery, controlling-process transfer, send/recv, half shutdown, close,
peer/local metadata, ALPN, getopts/setopts/statistics and every required transport
callback. Unsupported mTLS/packet/options must reject before I/O; explicit
provider selection cannot fall back. Existing HTTPS client or QUIC TLS checks do
not establish the required TCP server behavior.

Historical M1 record: no upstream issue, label, source edit, patch publication
or push was performed when this specification was prepared under that task's
external-mutation boundary. Current dependency discoveries follow the explicit
upstream issue-routing instructions in `AGENTS.md`; routine issue creation is
authorized there. Upstream source changes and publication still require their
own authorization.

## M3 public reusable transport ownership

The installed coordinated HTTP Fetch stack is0.20.0 and contains #66/#67's
public request-completion and H2 upload-trailer fixes. The
[new public source audit](acceptance/evidence/m3/upstream-0.20/public-client-audit.md)
confirms a separate missing caller-owned pool and deadline-confirmed retirement
contract, routed as [Feature #78](https://github.com/gsmlg-dev/http_fetch/issues/78),
type Feature, label `internal request`, severity blocker. See
[the concrete request](dependency-requests/http-fetch-managed-transports.md)
and [conditional execution plan](plans/m3-upstream-transport.md).

The [positive public probes](acceptance/evidence/m3/upstream-0.20/public-probes-final.json)
pass 16/16, including H1 reuse and separate verified TLS H2/h2c cleanup/trailers.
The audit also identifies a source-evidenced H2 empty-CONTINUATION fragment
metadata gap, routed after independent source review as
[Bug #79](https://github.com/gsmlg-dev/http_fetch/issues/79), type Bug,
label `internal request`, severity blocker. See [source/wire reproduction](dependency-requests/http-fetch-empty-continuation.md).
Its [finite diagnostic](acceptance/evidence/m3/upstream-0.20/empty-continuation-final.json)
is INCONCLUSIVE: 80,000 empty frames correlate with 4,683,568 bytes of VM-wide
process-used growth, but only two batch deltas meet the preset threshold, and
send receipts do not establish sample-time consumption. The bound remains
unresolved. Dedicated H1 remains enabled and passes460 upgrade-compatibility
tests. Gaoxy reusable
H1/upstream H2 activation and full M3/M4 progression remain blocked until
containing artifacts and the prescribed lifecycle/bounds/matrix gates qualify.
No private-client or dependency-source workaround is used.
