# M3 H1 resource foundation acceptance

Status: **DONE — local resource foundation accepted**. Independent final SPEC then
CODE review passes with no actionable findings. Fresh post-review verification
passes: proxy **77 tests/0 failures**, strict compile, scoped canonical format,
and the complete independent TCP/TLS profile **8 executed/0 failures**, exit 0,
zero skips/exclusions. Source-equivalent core **36/0** and external core-only
consumer **1/0** remain verified. This completes existing M3 Task 4; fixed-endpoint
activation proceeds as the next separately qualified Task 5 slice.

Execution checkout: `.trees/m3-h1-resource-foundation`, branch
`codex/m3-h1-resource-foundation`, verified kickoff
`449a4c4d470128d9e138564fe71b40e8fcebe358`. See the
[design](../designs/m3-h1-resource-foundation.md),
[plan](../plans/m3-h1-resource-foundation.md) and
[kickoff receipt](evidence/m3/h1-resource-foundation/1791870010586271722/kickoff.json).

## Accepted components

| Gate | Actual evidence | Status |
| --- | --- | --- |
| Generic lifecycle participants and immutable H1 options | Fresh 36 core + 30 proxy tests, zero failures; independent SPEC/CODE reviews | PASS |
| External core-only consumer | One executed test, zero failures, exit 0 | PASS |
| Ledger/custodian | Initial 40/0 GREEN rejected by review; repair 1 RED 44/4, then GREEN and fresh 44/0, exits 2/0/0 | PASS after repair |
| Ledger format and strict compilation | Stable source, exit 0 | PASS |
| Independent peer source | Repair 1 independently passes SPEC/CODE review; network execution not included | PASS source only |
| Metadata pins and request tokens | Expected RED 57/13; initial implementation 57/1, exit 2; review rejects grouped-pin removal; repair RED 58/1, GREEN and fresh 58/0; independent SPEC/CODE review | PASS after repair |
| Owner/core retirement integration | Expected RED 73/15; combined edge run 74/2; repair 1 GREEN 74/0 rejected by SPEC; repair 2 RED 75/1, GREEN and fresh 75/0, independent SPEC/CODE, format and strict compile | PASS after repair 2 |
| Independent TCP/TLS public-API profile | Repair 6 and fresh post-review complete runs both 8/0, exit 0, zero skips/exclusions; all primary and cleanup receipts pass | PASS after contract/harness repair |
| Final independent review and fresh affected verification | SPEC then CODE; proxy 77/0, strict compile and scoped format; source-equivalent core 36/0 and consumer 1/0 | PASS |

[Core/options acceptance](evidence/m3/h1-resource-foundation/1791870010586271722/slice-a-options-acceptance.json),
[ledger acceptance](evidence/m3/h1-resource-foundation/1791870010586271722/ledger-step4-acceptance.json),
[rejected ledger review](evidence/m3/h1-resource-foundation/1791870010586271722/ledger-review-initial.json),
[accepted repair review](evidence/m3/h1-resource-foundation/1791870010586271722/ledger-review-repair1.json),
[peer source review](evidence/m3/h1-resource-foundation/1791870010586271722/peer-source-review-repair1.json)
and [Step 5 expected RED](evidence/m3/h1-resource-foundation/1791870010586271722/holds-step5-expected-red.json),
[rejected Step 5 review](evidence/m3/h1-resource-foundation/1791870010586271722/holds-review-initial.json)
and [accepted Step 5 repair review](evidence/m3/h1-resource-foundation/1791870010586271722/holds-review-repair1.json)
preserve the separate outcomes. Commands, hashes, counts, actual exits and raw
logs remain in the run directory. Expected RED is not an acceptance PASS.

[Retirement design review](evidence/m3/h1-resource-foundation/1791870010586271722/retirement-design-review.json)
and [eight-case TCP/TLS profile design review](evidence/m3/h1-resource-foundation/1791870010586271722/profile-design-review.json)
are source/design acceptance only. The [retirement RED assessment](evidence/m3/h1-resource-foundation/1791870010586271722/retirement-step6-expected-red.json)
records 15 newly exercised missing retirement behaviors. It does not accept
the implementation or execute the independent network profile.

[Step 6 repair 1 review](evidence/m3/h1-resource-foundation/1791870010586271722/retirement-review-repair1.json)
preserves the P1 rejection despite 74/0 GREEN: an explicit initiation error can
consume the only replacement in graceful mode, preventing abort at D. Repair 2
covered returned errors with a held real request and retained the two-call bound.
[Accepted repair 2 review](evidence/m3/h1-resource-foundation/1791870010586271722/retirement-review-repair2.json)
and [Step 6 acceptance](evidence/m3/h1-resource-foundation/1791870010586271722/retirement-step6-acceptance.json)
record independent SPEC then CODE and fresh 75/0, format and strict compile PASS.

[Initial profile source review](evidence/m3/h1-resource-foundation/1791870010586271722/profile-review-initial.json)
requires the exact terminal owner deadline tuple in the upload/cache/core checks.
Request-completion pending and terminal owner failure remain distinct. The public
post-abort snapshot is observation; prescribed Gaoxy holds and completion checks
remain assertions. No dependency defect or native certification gate is inferred.

[Repair 1 profile review](evidence/m3/h1-resource-foundation/1791870010586271722/profile-review-repair1.json)
and [repair 2 source review](evidence/m3/h1-resource-foundation/1791870010586271722/profile-review-repair2.json)
preserve the separate CODE rejection and subsequent source PASS. The
[first live assessment](evidence/m3/h1-resource-foundation/1791870010586271722/profile-step7-live-assessment.json)
records actual 8/4, exit 1. Every TLS connection has peer-observed ALPN `null`;
that rejected snapshot retained the incorrect exact `http/1.1` expectation; the later scope audit supersedes it with the original exact null requirement. Public completion/retirement, actor DOWN,
genuine remote EOF before fixture stop, peer exit/zero threads/connections and
certificate removal all passed. Native post-abort counts remain observations;
original completion and Gaoxy holds remain strict assertions. Historical repair 3 attempted an unsupported TLS policy; its later scope audit
restores the established contract without a dependency workaround.

## Environment and accounting boundary

Qualified commands use `nix develop --command env 'ERL_FLAGS=+S 2:2'
MIX_ENV=test`. Elixir 1.18.5, OTP 28, ERTS 16.4.0.6, Python 3.13.15 and
OpenSSL 3.6.5 were recorded. The seven-package HTTP/QUIC/TLS cohort is 0.21.4;
lock SHA256 `aa9220766e1699f5cfa9d8513df95910a613cf2cbba37e8ce977267e3b68d9ab`.
The public ManagedTransport facade SHA256 remains
`2f89d9535c116dfc129f7e64c36d54256271a24405d1f860d58911e2bc397e5a`.

Finite resource, per-handle metadata pin, request token and owned serialized
payload limits govern admission without queues. The payload counter covers
compact Gaoxy policy and metadata/control slots. It excludes opaque dependency
handles, process heaps, sockets and native/OS memory. It is not a total-memory
reservation or native reclamation certificate.

Request completion and physical transport retirement settle different holds.
Helper and creator termination remain independently joined. Unknown request
completion retains its token even after confirmed physical retirement; late
cleanup cannot rewrite an earlier failed stop result.

## Reviewed ALPN contract and preserved rejected candidate

The [independent scope audit](evidence/m3/h1-resource-foundation/1791870010586271722/profile-step7-alpn-scope-audit.json)
traces the original accepted `a2296e2` requirements: the
[TLS qualification plan](../plans/m3-tls-tracking-qualification.md) explicitly
requires selected ALPN Python `None` / JSON `null` for managed H1; the compact
preparation design's exact SSL grammar omits ALPN. Foundation requires verified
H1 wire behavior, reuse and lifecycle proof, with negotiated ALPN required only
for upstream H2. The harness-added `http/1.1` expectation contradicted that
existing contract. Parent and initial review incorrectly classified it as an
upstream blocker. The scope audit corrects that decision.

The [public diagnostic](evidence/m3/h1-resource-foundation/1791870010586271722/profile-step7-alpn-upstream-blocker.json)
accurately demonstrates that an optional explicit ALPN option is unsupported.
Its initial blocker classification is historical and superseded by the scope
audit. [Feature #107](https://github.com/gsmlg-dev/http_fetch/issues/107) is now
`nice-to-have`, with a transparent scope correction; no stage/release depends
on it. Preserve its initial and corrected bodies and all 8/4, 8/5, 8/4 failures.
No failed run is relabelled PASS and no dependency workaround is introduced.

Repair 4's [source review](evidence/m3/h1-resource-foundation/1791870010586271722/profile-step7-review-repair4.json)
and [network assessment](evidence/m3/h1-resource-foundation/1791870010586271722/profile-step7-repair4-live-assessment.json)
show the same-token finite finish fix: actual held-upload results are exact
`cleanup_pending` then `:ok`, all four TCP primary/cleanup cases PASS. Four TLS
cases still reject the unsupported ALPN candidate, including visible failed-open
owner retirement/DOWN failures. Full profile remains 8/4 FAIL.

Repair 5 restores the original constructor/canonical SSL grammar, strengthens
injected-option rejection, and requires selected ALPN **exactly null**. Every
nonnil selection fails; no multi-protocol alternative is accepted. Peer H1 framing,
TLS CA/hostname/SNI, exact bytes/trailers/identity, no replay, all credits/joins
and finite deadlines remain required. Repair 6 and the fresh post-review
all-eight runs below now pass those assertions.

## Accepted final verification and unchanged boundaries

Repair 6 completes the original contract; no new product approval or upstream
ALPN feature is a prerequisite. Actual public Fetch, RequestCompletion and
ManagedTransport behavior passes independent TCP and verified TLS peers, exact
bodies/trailers/request identities, genuine remote EOF, all owned actor joins and
successful fixture removal. The final receipt binds commands, hashes and counts.

Production endpoints remain dedicated H1. Managed-H1 endpoint/Session/generation
activation, groups/probes, upstream H2 and full M3 acceptance remain separate.
No foundation push, release, deployment, production data/certificate change,
public management, Vault change or disabled release-artifact E2E enablement is
authorized here. Historical hosted `BLOCKED_ENV` remains separate from local
foundation evidence.

Inherited unsuccessful UP2 counts remain **20 live / 8 production / 3 harness**;
**Astra recovery 2/2 exhausted**. Ledger repair 1 passed; peer source repair 1
passed source review. Step 5's initial implementation has one harness execution
failure and one production review rejection; its repair 1 passed.
Step 6 repair 1 failed independent specification review, recording one
unsuccessful Step 6 repair. Its earlier combined edge run also retains the
production failure and harness failure; the latter was corrected in repair 1.
Step 7 initially had two unsuccessful repairs: repair 1 failed CODE source review; repair 2 passed source review then failed live TLS ALPN. Repair 3 passed pure 77/0 then failed live 8/5, recording a third unsuccessful Step 7 repair. Its failing evidence is preserved in profile-step7-repair3-live-assessment.json. Repair 4 then passed TCP but retained full8/4 FAIL, recording four unsuccessful Step 7 package attempts before the contract correction. The scope audit restores the already established exact null requirement for repair 5; #107 is optional. Expected TDD RED outcomes do not
add unsuccessful repair rounds. Historical evidence and
the reviewed dismissal of `gsmlg-dev/http_fetch#97` remain intact.

## Repair 5 review and repair 6 explicit telemetry

Repair 5 restores the original policy and passes pure77/0, but independent CODE
review rejects a missing-field acceptance: map lookup returned nil for either
JSONnull or an absent ALPN key. Repair 6 uses `Map.fetch!` so the key must be
present and its value exactly nil. Every nonnil or missing selection fails.
Other protocol/security/credit/deadline/join assertions remain unchanged. This
review failure is preserved separately; Step7 unsuccessful attempts **5** before
repair6 acceptance. Inherited counters and Astra2/2 exhausted remain unchanged.

## Final acceptance — repair 6

[Final independent review](evidence/m3/h1-resource-foundation/1791870010586271722/foundation-final-independent-review.json)
verifies all eight cases and raw peer transcripts: ten accepted connections and
ten genuine remote EOF events before fixture shutdown; ten response hashes,
lengths and ordered trailers; fourteen unique request heads and guardian joins;
two upload-source joins and ten owner/instance joins. All final ledgers are zero.
The held-source cases retain request/connection/helper holds at short D and keep
the exact cached failure after late successful cleanup. Every TLS connection has
an explicit ALPN field containing exactly null under verified CA/hostname/SNI.

The [fresh network summary](evidence/m3/h1-resource-foundation/1791870010586271722/foundation-final-run-1791891426055/summary.json)
is **8/0**, exit 0, with every primary and cleanup receipt PASS. The
[final acceptance receipt](evidence/m3/h1-resource-foundation/1791870010586271722/foundation-final-acceptance.json)
binds this run, fresh proxy **77/0**, format/strict compile and unchanged
core/consumer evidence to the accepted source. Total tests are not inflated by
adding historical reruns. All previous failures/review rejections remain FAIL.
Five unsuccessful Step 7 attempts precede repair 6. The missing blank-line format
failure and the final wrapper's omitted `unbuffer mix` invocation (exit 127) are
preserved separately; the corrected actual format command passes. They add no
Astra round and do not relabel an unexecuted command as passing.

Only Task 4's local foundation is accepted. Automatically execute the written
[fixed-endpoint design](../designs/m3-managed-h1-fixed-endpoint.md) and
[plan](../plans/m3-managed-h1-fixed-endpoint.md) under continuing authorization.
Groups, probes/Generation, upstream H2 and full M3 remain separate gates.
