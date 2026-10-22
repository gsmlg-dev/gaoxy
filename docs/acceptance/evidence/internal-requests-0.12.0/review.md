# Internal request review for 0.12.0

Date: 2026-10-22, Asia/Shanghai. Checkout:
`/home/gao/Workspace/gsmlg-opt/gaoxy`, shared `main`, baseline
`0b3f97fc08549649b4b367e3a85a8526e162f53f`.

The `head_metadata` worker implemented #12 and independently reviewed #13 and
#14. Its #12 assessment below is a self-review; the separate `phoenix_disconnect`
worker independently reviewed #12 and reported PASS to the parent. No reviewer
claims that its own implementation is independently reviewed by itself.

## Issue 12: HEAD representation metadata

**PASS.** Self-review found the production change limited to H1 header selection
and shared H2/H3 response preparation. A supplied validated HEAD length survives;
an absent length is inferred. Body suppression remains in effect, GET uses actual
response size, and 204/205/304 retain their existing rules. Duplicate and invalid
lengths still fail before headers are sent.

Direct evidence from the implementing worker:

- RED: three network tests failed on the expected `12345` versus `0` metadata
  assertion; four unit tests included one expected supplied-length failure.
- GREEN: with `ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test`,
  `python3 scripts/check-tests.py apps/gaoxy_http/test/head_content_length_test.exs apps/gaoxy_http/test/head_content_length_network_test.exs apps/gaoxy_http3/test/head_content_length_network_test.exs apps/gaoxy_http3/test/transport_test.exs --seed 0 --max-cases 1`
  passed 20 tests, including 48 independent H1/H2/H3 protocol cases.
- Scoped formatting and diff checks passed.
- Additional existing H1/H2 compatibility execution had 37 tests and one failure:
  `http_network_test.exs:351` returned 500 instead of body `2000`. Baseline status
  was not established. The worker stopped that unrelated investigation and
  preserved the result; this review does not relabel that run as passing.

The independent `phoenix_disconnect` review examined exact metadata and body
assertions, all 48 protocol cases, status precedence and malformed framing, and
reported no actionable findings. Parent fresh gates remain separate evidence.

## Issue 14: Phoenix administrative disconnect

**PASS, independent specification/code review.** Exactly
`{:shutdown, :disconnected}` maps to 1000 and WebSock termination `:normal`.
Restart retains 1012/`:shutdown`; arbitrary errors retain 1011/error semantics.
Explicit close codes, text and final messages remain authoritative.

The controlled stream test matrix checks these callback forms and termination
results. The actual Phoenix regression joins a real channel, broadcasts through
the socket ID, checks close 1000 on the wire, acknowledges the close, and requires
both transport and channel DOWN plus TCP EOF. The existing H1 owner shutdown
reason `{:shutdown, :local_closed}` remains distinct from the WebSock callback's
normal termination reason.

The implementing worker reported 14 stream component tests and six full Phoenix
compatibility tests passing. This reviewer inspected that evidence and code;
it did not rerun those tests during the independent review.

## Issue 13: inactivity-only request lifetime

**PASS, independent specification/code review after the configuration-boundary
repair.** No actionable source finding remains in the reviewed scope.
The independent review examined option validation, H1 header/request deadlines,
Admission timer/token rotation, H2 bootstrap/dispatch/owner transition, signed
monotonic deadlines, response writes, worker accounting, independent peers and
HTTP3 rejection.

Resolved review findings:

- H2 acceptance now outlives its finite 150 ms startup deadline with an upload
  lasting at least 600 ms. A finite H2 control still expires. A file response
  waits beyond startup but below its write bound before window credit is given.
- The reset case waits for a 103 response emitted after body consumption, proving
  an activated request is reset; its sibling completes.
- Accounting retains the original signed startup deadline and separately charges
  the larger request-deadline representation only for Exchange variants. The
  independent constructor test builds both forms and retains exact row equality.
- H1 100 Continue obtains a finite operation deadline; additional actual-listener
  cases cover blocked file writes, bounded stop and the continue handshake.

Admission cancels its previous timer and changes its token when transitioning
to infinity, preserving protection against stale expiry messages. Monitor-based
ownership cleanup, finite H2 startup, and finite I/O bounds remain intact.

The final configuration repair resolves the remaining wrapper finding:

- HTTP options recursively inspect `ListenerSet.Target` endpoint wrappers and
  reject direct or wrapped Generation with `:unsupported_request_timeout`
  before the normalized endpoint's initialization. Ordinary prepared Plug
  targets remain accepted. Phoenix uses that supported Plug path.
- Gateway's pure declaration compiler rejects infinity for managed logical
  listener sets and raw Router services. These always become Generation
  endpoints at runtime, so rejection now precedes their runtime preparation.
  Recompiling a prepared Plan routes through the same declaration validation.
- Unit regressions cover direct/wrapped rejection, supported prepared Plug
  acceptance, and both managed gateway declaration forms. The parent reproduced
  two boundary failures before the repair; no assertion was removed or relaxed.

The parent reported an earlier focused 23-test run passing. At final source
review, its updated focused 26-test run and broader gates were still running;
this reviewer did not run or interfere with them. Their actual final outcomes
belong in the parent's validation evidence. The historical 451-test gate
snapshot predates the additional gateway case; the current manifest requires
452 tests and must be qualified on the publication source.

The reviewer changed only this artifact during #13/#14 review and ran no tests
or compilation during the parent's concurrent gates. Read-only diff and source
inspection completed; `git diff --check` passed.

This artifact is source review evidence. Publication, hosted CI, package checks,
deployment and downstream acceptance are separate states owned by the parent.
