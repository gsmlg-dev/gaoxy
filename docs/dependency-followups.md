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

## Current M3 managed transport disposition — 2026-10-11

Installed coordinated HTTP packages are0.21.3. Fixes#66/#67/#78/#79/#86–#89/#95/#98/#100
are present. Compatibility486/0, finite public driver39/39 with canonical MATCH
and39 joined cleanups, H1 baseline20/0 and actual TLS supplemental5/5 pass.
The two-case isolated0.21.1 negative registration oracle executes with exact
mismatches and both successful cleanups. Installed bytes are bound by
[provenance](acceptance/evidence/m3/upstream-transport/upstream-0.21.3/installed-cohort-verification.md).
B21 and the public eight-case H2 supplement pass on final source. Five
acquisition-failure probes meet their expected negative oracles; independent
H1/H2 specification, code and evidence review passes.

The user dismissed the former control-proof request on 2026-10-11. It is
archived, must not be pursued, and does not block v0.2.0 or M4. See
[ADR007](adr/007-m3-beta-and-m4.md). Reusable H1/upstream H2 integration is
unimplemented; numerical/managed-soak fixtures retain their original status.
[Current acceptance](acceptance/m3.md) supersedes older disposition statements.

## Historical 0.21.0 public reusable transport ownership

At that historical checkpoint, [remote status](acceptance/evidence/m3/upstream-transport/upstream-0.21/upstream-status-refresh1.json)
records #86–#89 CLOSED, with latest published/installed release still0.21.0.
Their installed-source findings and canonical MISMATCH remain until containing
artifacts are installed and qualified. Historical issue receipts are preserved.
[Bug95](dependency-requests/http-fetch-otp28-tls-tracking.md) is OPEN, typed Bug,
labeled `internal request`, severity blocker for managed OTP28 TLS lifecycle.
The actual eight-element TLS socket skips the installed three-element tracking
clause. A verified public shape diagnostic confirms the mismatch and joins its
peer; full lifecycle races are NOT RUN. Managed activation stops without a
local workaround; pure input/source-proof work can continue.

Installed coordinated HTTP Fetch0.21.0 contains #66/#67 request cleanup and
upload trailers, #78 caller-owned scopes and confirmed retirement, and #79's
256-frame header-fragment cap. [Published/installed provenance](acceptance/evidence/m3/upstream-transport/upstream-0.21/installed-provenance.json)
and [compatibility460/0](acceptance/evidence/m3/upstream-transport/upstream-0.21/compatibility.json)
qualify these containing artifacts. The former
[Feature78](dependency-requests/http-fetch-managed-transports.md) and
[Bug79](dependency-requests/http-fetch-empty-continuation.md) requests remain
historical; no longer treat them as missing installed operations/caps.

Current [Bug86](https://github.com/gsmlg-dev/http_fetch/issues/86), type Bug,
label `internal request`, severity blocker, addresses valid peer-driven decoded
head events and asynchronous SETTINGS capacity notifications without hard
aggregate outstanding bounds. See [the exact request](dependency-requests/http-fetch-h2-header-control-bounds.md),
[source worksheet](acceptance/evidence/m3/upstream-transport/retained-bounds-source.md)
and [independent installed-source confirmation](acceptance/evidence/m3/upstream-transport/upstream-0.21/independent-bounds-review.md).
This is source evidence, not a measured runtime leak. Dedicated H1 remains
enabled; managed H2 activation stops without a dependency/local workaround.

Narrow managed H1 functional qualification proceeds separately, preserving
frozen8192-byte buffers and nil/PID acknowledged binary upload. Its complete
policy/preparation/copy/structure/metadata and managed OTP-delivery accounting
is still required before activation. Neither protocol's component subtotal is
an approved reservation. Follow the [transport plan](plans/m3-upstream-transport.md).

[Bug87](dependency-requests/http-fetch-managed-request-inputs.md), severity
needed, requests charging final normalized request inputs, including late
Content-Type, unused URI authority and zero-payload iodata structure.
[Feature88](dependency-requests/http-fetch-managed-tls-backing.md), severity
needed, requests an explicit retained-backing contract for frozen TLS material.
Both are independently source-confirmed; their finite recipes are NOT RUN and
retention amounts are unmeasured. Existing URL-string/explicit-field/nil-PID
inputs exclude#87's broad forms. Controlled compact DER preparation is the
recommended narrow managed profile for#88, with source-plus-copy peaks charged;
it is not yet an enabled transport or a complete reservation. Adapter TODO and
WORKAROUND comments link both requests without dependency patches.

[Bug89](dependency-requests/http-fetch-managed-capacity-error.md), severity
needed, records the verified TLS H2 GOAWAY capacity error shape: the public
facade documents `{:error, {:transport_scope_capacity, :connections}}`, while
the pool returns `{:error, :pending_capacity}`. The named finite resource case
passed before the unrelated empty-response fixture failure in repair1; h2c
was not reached in that cited run. The later complete recovery1 run passes39/39
and independently confirms the same mismatch for both TLS H2 and h2c. The functional fixture records the exact
observed rejection separately from canonical **MISMATCH**; it cannot claim
canonical compliance. Adapter/fixture TODOs and the explicit fixture WORKAROUND
link#89. No production H2 error normalization or transport activation is added.

Historical0.20 [positive request probes](acceptance/evidence/m3/upstream-0.20/public-probes-final.json)
passed16/16. Its [finite fragment diagnostic](acceptance/evidence/m3/upstream-0.20/empty-continuation-final.json)
was INCONCLUSIVE:80,000 frames correlated with4,683,568 bytes VM-wide
process-used growth; only two preset batch deltas met threshold, and send
receipts did not prove sample-time consumption. Preserve these limits and logs.
No private client/source patch is used. The historical managed gate is
superseded for release/M4 progression by the reviewed scope in ADR007.
