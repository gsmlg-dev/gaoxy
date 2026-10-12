# M4 downstream matrix implementation plan

Goal: execute G3 from [the native H3 plan](m4-http3.md) under continuing
authorization, following [the bounded design](../designs/m4-downstream-matrix.md).
Implementation starts after the reviewed G2 shared gate passes. Use the locked
Nix test environment, preserve historical repair counters and commit only
reviewed, freshly verified local slices. Publication is authorized only after
all required M4 gates and independent review actually pass; deployment remains
excluded. An incomplete downstream-only slice does not satisfy that condition.

## Ownership and sequencing

Sol proxy worker owns `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex`,
`http/headers.ex`, scoped proxy tests and
`apps/gaoxy_http3/test/proxy_test.exs`, plus new independent
`integration/http3/h1_origin.py` and `proxy_peer.py`. Root owns new matrix/browser
runner and fixtures, the explicit Phoenix-example dependency/gateway, clean H3
consumer, and acceptance documents. Give independent reviewers read-only source
ownership and their own receipts. Writers are not alone and preserve others'
changes. Serialize umbrella Mix, dependency mutations and live gates; freeze
all hashed source for each live execution.

## Tasks and verification

- [x] Independently review this design/plan before implementation.
- [x] Write meaningful red regressions for H3 trailer policy, H2/H3 fixed/zero
  length trailer translation to H1 chunked framing, and completed body before
  upstream-ready. Keep existing H1/H2/authentication assertions unchanged.
  Assert exactly one upload finish with ordered repeated trailers, no finish
  for nil upload, and no upload reopening when ready follows an early origin
  head; all work stays at the original deadline. Assert fixed Content-Length
  response-trailer declaration rejection for H1/H2/H3.
- [x] Implement the smallest protocol-neutral compatibility repairs. Use only
  supported client Stream/RequestCompletion operations; no private state or
  dependency patch. Run changed proxy tests and `http_headers_test.exs`,
  `http_proxy_wire_test.exs`, `http_proxy_runtime_test.exs`,
  `http_fetch_contract_test.exs` and H2 proxy compatibility as applicable.
- [x] Add independent H1 origin and H3 proxy peer. Verify actual upstream
  target/body/trailers, progressive upload before request FIN and progressive
  download before origin response FIN, response
  trailers, early response, reset isolation and concurrent requests. Require
  real byte counts, exact terminal fields and bounded cleanup.
  An early 413 before upload FIN must stop input; ordinary H1 upload continuation
  after an early final head is outside the existing dedicated adapter profile.
  Check actual fixed upstream Host, regenerated forwarding identity and dropped
  hop/spoofed values; retain forbidden authentication-trailer and destination
  policy rejection evidence.
- [x] Add separate Phoenix H3 gateway/browser fixture with duplicate endpoint
  listeners disabled. Assert actual CDP `h3`, rendered existing page/static
  content and unique server marker; use only process-local fixture SPKI trust.
- [x] Add source-bound matrix runner with finite child teardown, nonzero cases,
  queue/Admission baseline and listener port rebind receipts. Run
  `nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python
  integration/http3/matrix.py --evidence docs/acceptance/evidence/m4/matrix`.
- [x] Run `scripts/external-consumer.sh`, `scripts/http-consumer.sh` and the new
  clean H3 consumer script in separate clean projects; retain lock/version,
  strict compilation, nonzero test counts and runtime-isolation evidence.
- [x] Independently review specification, code and live/browser/consumer
  evidence; resolve findings with unchanged assertions and fresh affected
  checks. Run all `apps/gaoxy_http3/test` plus affected H1/H2/proxy suites using
  `scripts/check-tests.py`, exact-file formatting and strict compilation.
- [x] Synchronize capability/implementation/dependency/usage/acceptance docs
  with executed rows; commit G3 locally. Continue upstream-H3/standalone slices
  automatically under their reviewed written design and plan.

PASS requires executed H3-to-dedicated-H1, local Phoenix/browser H3 and clean
consumer rows, with source unchanged and confirmed owned cleanup. Missing
environment prerequisites are BLOCKED_ENV, not PASS. H3 WebSocket is
UNSUPPORTED; upstream H2 and pools remain unimplemented. Full M4 completion
also requires the separate upstream-H3 and standalone gates.

2026-10-12 checkpoint: the source-frozen downstream/browser runner and fresh
repeat executed19 PASS checks. Core1/0, H1/H2 2/0 and H3 2/0 clean-consumers passed
independent review; the omitted H3 peer hash has a genuine independent pre/post
supplement. Final affected tests passed274/0, exact53-file format and strict
compilation; full M4 depends on the blocked upstream
contract. See [acceptance](../acceptance/m4.md) and
[remaining tasks](m4-upstream-resume.md).
