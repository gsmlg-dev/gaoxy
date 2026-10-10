# Independent Generation/config and destination policy re-review

Reviewer `/root/upstream_cleanup`. Read-only review of parent-owned source and
test/evidence files in `.trees/m3-gateway`, branch `codex/m3-gateway`, baseline
`22b76e8051ddaf09e36797cb781b9b119870a9d4` plus the current task diff.

Final verdict: PASS for the reviewed pure Generation, destination policy and
route/static configuration slice. G1, G2, DP1 and G3 are resolved by source and
fresh scoped evidence. No parent-owned source was edited. This verdict does not
complete standalone Application, H2 reload, Forward or CONNECT integration.

## Resolved findings

- G1: `Generation.activate/4` obtains immutable limits with metadata-only receipt
  and checks `Store.compiled_bound/2` in the caller before the complete candidate
  crosses to Store. Store rechecks bounds, original absolute deadline, and CAS.
  The oversized-activation suspended-store regression checks queued messages
  remain below 1024 bytes and rejects the 2 MB candidate without mutation.
- G2: StaticEndpoint rejects hop fields, duplicate/invalid/mismatched lengths,
  forbidden controls and leading/trailing OWS before activation. Reload
  regressions preserve the original generation for each rejected candidate.
  Valid304 representation length is preserved independently of absent body;
  decimal metadata has the same20digit ceiling as shared H1/H2 Response.
- DP1: `fec0::/10` is now reserved by default; the regression rejects standalone
  and mixed public/site-local answers, while explicit `fec0::1/128` reserved opt-in
  succeeds. A separate deny-CIDR precedence regression rejects a configured
  management destination, including mixed answers, while allowing another public
  candidate. Pure policy remains authentication-first and pins only after all
  returned addresses pass policy.

## G3 — common-header accounting resolved

Exact input: `List.duplicate({"x", String.duplicate("a", 306)}, 100)` with status200
and body`"ok"`. The original `StaticEndpoint.init/1` accepted because ETF external size
is31907<=32000; `H2.Headers.bytes/1` is33900 and default
`Headers.validate(headers,100,32768)` returns
`{:error,:protocol_error,:header_fields}`. The response also adds `:status` and
possibly content-length, requiring headroom in both count and bytes. This can
activate a static route which the default H2 endpoint could not serve.

A standalone no-Mix source probe recorded this in
`relay/static-header-bound-probe.log`, exit0. Current source now counts framed
headers plus one generated `:status` against100 fields, and computes H2 bytes
plus42 bytes of status overhead against32768. Generated Content-Length is
included except204/304 or an explicitly valid supplied length. ETF accounting
remains an additional bound. Validation checks tuple/name/value shapes before
calling H2.bytes, so malformed headers remain clean preparation errors.

The regression covers100 large fields,100 small fields, and98 fields with313byte
values. The98-field input has ETF31955bytes and remains within the field-count
ceiling after Content-Length/status; its rejection independently proves H2 byte
accounting. Fresh `h2/parent-repair-6.log` includes8 route-config tests with zero
failures, seed660832, exit0. Original `static-bound-red.log` shows8 tests with the
expected one failure before the shared bound repair, seed551085, exit2.

## Evidence and limits

`generation-policy-review-green.log`: Generation12, policy8, route-config6 tests,
all zero failures; seed916660, parent-run exit0. `h2/parent-repair-4.log`: HTTP81,
policy8, route-config7 tests, all zero failures; seed791794, parent-run exit0;
includes the304 decimal ceiling regression. These are exact scoped evidence,
not standalone application or production acceptance. H2 reload and standalone
Application gates remain parent integration work and explicitly outstanding.
