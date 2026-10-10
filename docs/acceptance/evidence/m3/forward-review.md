# Independent Forward HTTP and CONNECT review

Reviewer `/root/upstream_cleanup`, direct read-only review of parent-authored
ForwardHTTP, HTTPFetchClient numeric pin, HTTP proxy seam and H1 CONNECT dispatch.
Worktree `.trees/m3-gateway`, branch `codex/m3-gateway`, baseline
`22b76e8051ddaf09e36797cb781b9b119870a9d4` plus shared current task changes.
Reviewed approved `docs/designs/m3-gateway.md` and Task 3 acceptance criteria.
No parent-owned production or Forward test file was edited by this reviewer.

Verdict: PASS for ForwardHTTP and H1 CONNECT integration after the parent F1/R3
repairs and fresh scoped evidence below. This review does
not qualify the H2 engine independently; reviewer authored its initial version.

## F1: TLS listener rejects ordinary HTTP forward targets

`HTTP.Connection.parse/2` derives `:https` from a secure listener, then rejects
any nonnil absolute target scheme that differs from that listener scheme before
calling the endpoint. `ForwardHTTP.target/1` accepts absolute `:http` targets,
as required for forward HTTP; HTTPS target traffic uses CONNECT. Consequently,
a TLS ForwardHTTP listener rejects every ordinary forward request with 400.
For example, an authenticated allowed request `GET http://localhost:PORT/a
HTTP/1.1` with matching Host must forward to the authorized HTTP destination
through the TLS proxy connection, but cannot reach authentication or the dial.

Repair must preserve ordinary endpoint scheme validation while allowing the
explicit ForwardHTTP endpoint to authorize its target independently of proxy
listener security. Require a real TLS proxy client and HTTP upstream regression,
exact origin-form path/Host, stripped credentials, and restored resources.
Parent repaired F1 using optional Endpoint.absolute_form_scheme?/1; ForwardHTTP
opts in only for `:http`, and ordinary endpoint scheme validation stays intact.
The HTTP application has no Proxy dependency. The new verified TLS-listener
regression checks the exact escaped origin request, response and credential
removal, using a CA-verified localhost TLS client and a separate HTTP peer.

## Confirmed source paths and current evidence

- Configuration requires an explicit authenticator and nonempty rules. Every
  request authenticates before destination authorization and DNS/dial. Invalid,
  missing and duplicate credentials yield 407, denied destinations 403. Errors
  do not include credential values. Strict H1 parsing rejects userinfo, ambiguous
  framing and Host/authority disagreement before dial.
- DestinationPolicy validates each returned A/AAAA candidate, normalizes mapped
  IPv6, applies configured management deny CIDRs with precedence, and selects one
  numeric address only after all candidates pass. HTTPProxy retains the URL host
  and forwards the address through public `HTTP.fetch/2` `connect_address` with
  manual redirects and dedicated H1. No URL-to-IP rewrite or second DNS lookup.
- Request header normalization removes proxy credentials and connection-named
  hop fields; upstream path/query escaping and target Host are preserved. The
  HTTPS numeric-pin regression binds 127.0.0.2 while asserting localhost SNI,
  Host and certificate identity; trust/hostname rejection has no replay.
- CONNECT requires H1.1 authority form with explicit port and no framing fields.
  It authenticates and authorizes before dial and 200, uses a separate `:tunnel`
  state, and transfers post-head bytes exactly once through the original owner,
  lease and absolute deadline. H2 CONNECT is unsupported without closing sibling
  streams. TLS directional half-close remains explicitly unsupported by relay.
- `forward-initial.log` records Forward 7, TLS 4, policy 8 and H2 integration 9
  tests: 28 executed, zero failures, seed 857389, exit 0. The new UDP controller
  compiler warning means that run does not establish the clean strict compile
  gate. F1's TLS-forward case was absent in that initial run.

## R3 dependency and verification boundary

CONNECT uses StreamRelay.bridge and its upstream cleanup. Relay's both-EOF
normal closure can still enter OTP queued-output close waiting, which does not
service a later drain deadline. `relay/normal-close-probe.log` demonstrates the
public OTP behavior with 999424 accepted bytes and 12160 pending driver bytes;
normal close waited beyond 200 ms, then preserved all bytes after read credit.
The real-relay test gates peer reads and waits for both writer DOWN receipts
before requesting a 100 ms service stop. Parent-run `relay/normal-close-red.log`
executes that test and fails exactly at the stop result:
`{:error, {:deadline_exceeded, :cleanup_pending}}`; seed 250425, exit 2, one
executed failure and fifteen excluded tests.

Parent R3 repair stops/observes both writers before entering an output-drain
pump. The pump reads public socket `send_pend` stats and services control and
absolute idle/lifetime/drain deadlines. Only empty driver queues permit normal
close; expiry aborts uncertain output. The additional read-credit regression
checks every accepted byte survives normal EOF cleanup. Fresh
`h2/parent-repair-7-relay-f1.log` records proxy 33 tests, zero failures, seed
910150. Its concurrent HTTP suite has 28 tests with one unrelated H2 fixture
failure, so that complete run is not green. Parent subsequently repaired and
qualified the affected H2 fixtures separately. Reviewer
read the current minimal F1/R3 source, both new network regressions and this log.
This PASS covers those integration repairs and does not independently qualify
the H2 engine or claim milestone/production acceptance.

Reviewer holds no Mix window and has no running commands. Local acceptance is
separate from hosted CI, publication, deployment and production qualification.
