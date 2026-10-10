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
