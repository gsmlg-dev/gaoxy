# M3 managed H2 fixed-endpoint implementation plan

Current checkpoint — 2026-10-15: managed H2 fixed endpoints remain uncommitted.

Upstream [http_fetch#122](https://github.com/gsmlg-dev/http_fetch/issues/122)
is CLOSED, repaired by PR125 / merge9caf38cabdaa5fc1c65501632a28548ebd27d714
and released in the coordinated HTTP 0.21.10 cohort
(tag ed27a577d418e45266cd54638692362d17fcdcd1). All seven packages are now
pinned/locked to0.21.10. The original cancellation assertion still requires
:aborted and passed unchanged (5 tests /0 failures).

Strict compilation and format41 passed. Two complete full58 runs each
executed853 tests with1 failure, exit2 and stable source; both are retained.
The second exposed a local H1 probe-fixture lifetime race: querying an owner
after instance-driven normal termination returns :not_running. Sol20 added
exact owner-DOWN barriers and reproduced the same class deterministically
(34 tests /22 expected failures), then corrected only fixture teardown
ordering. The complete two-file GREEN passed34/0, exit0/stable source.
Original primary bodies, short-stop failure and TLS uncertainty assertions
remain unchanged. Live-owner zero-status checks remain; body-owned core
shutdown uses a monitor installed before shutdown and an exact normal DOWN.
See sol20-group-cleanup-repair-design-plan.md, independent design SPEC,
RED/GREEN receipts and the explicit test-contract amendment in stage evidence.
This scoped GREEN does not substitute for a fresh full58 gate.

The additive h2_02110 qualification/supplement preserves all63 public cases
and hash-pins historical0.21.4 sources. Matrix/browser use its exact0.21.10
identity wrapper; all135/3 cases and assertions remain. Complete updated
independent SPEC then CODE and fresh format43/strict compile/full58/public63/
matrix135/browser3 remain required before acceptance and local commit.
Current ownership is52 files plus5 authorities; no58-file omission is allowed.

Cumulative prior counters persist: fixedSol19/unsuccessfulGREEN14;
collectorSol17/unsuccessfulGREEN12; matrixfailed11; browserfailed5;
R32diagnosticfailed5; nativeH1 RED2/fixture2; nativeH2 shape RED2/fixture1;
local-status RED2/fixture1; full-staticCODEfailed1. New counters:
0.21.10 full58failed2; fixtureSol20 RED1/GREEN1. Astra recovery2/2 remains
exhausted. Negative TLS cleanup remains UNCONFIRMED_WITH_RETAINED_FAILURE.
Root owns all repository writes/runtime; publication/deployment restrictions
remain. No stage completion, commit or successor activation is claimed.

Historical Sol19 checkpoint before the upstream122 repair follows:

Latest execution (Sol19 final unblocked verification): activation remains
BLOCKED_UPSTREAM122 and uncommitted at baseline `31f23eb`.
Sol19 trusted local_fail now preserves only native400/413/431 for
ManagedH2Client and immediately discards raw diagnostics to :invalid_request.
Generic upstream errors still normalize before status selection; original
cleanup, unset-head/total-expiry, close, caps and deadlines are unchanged.
Independent bounded SPEC then CODE PASS with zero open findings. Complete
endpoint GREEN1 PASS38/0 and affected lifecycle/H1/H3 compatibility PASS141/0
(21 native HTTP +120 proxy), exit0/source stable/zero skips or exclusions.
These scoped passes resolve LOCAL_REQUEST_ERROR_STATUS_LOST, not stage acceptance.

Sol19 RED1 remains fixture FAIL38/8 on its invalid Trailer assertion; its sole
correction asserts exact authentic H2 pseudoheaders and no hop fields. Genuine
RED2 FAIL38/8 reached the exact closed wire response after original pending
barriers and observed502 vs400x2/413x2/431x4. Original30 cases and all8
status/completion/cleanup assertions remain unchanged. Actual release, bounded
design/plan, exact candidates/reviews and RED/GREEN receipts are preserved as
`sol19-local-status-*` in the existing stage evidence directory.

Full independent SPEC Sol19 then CODE Sol19 PASS with zero findings on the
frozen owned46/authorities5 candidate. Fresh post-review format38, strict
compile (--warnings-as-errors --force), public63/63, complete matrix135/135
and browser3/3 all PASS with exit0 and stable source. The matrix executed all
135 unique required identities across four cells, with zero omissions,
skips or exclusions. Actual public command-group, matrix peer and browser
joins, artifact hashes and91 loaded Gaoxy module identities were audited.
Browser negative CA/name outcomes remain UNCONFIRMED_WITH_RETAINED_FAILURE;
these passing cases do not confirm their original cleanup.

`sol19-postreview-unblocked-evidence-audit.json` binds the fresh qualifications,
receipts, full reviews and frozen manifest. Its status is
PASS_UNBLOCKED_GATES_ONLY; full58 and stage acceptance remain blocked.
The earlier Collector Sol17 matrix GREEN12 and browser-sol17-1 passes remain
historical evidence and are not substituted for these Sol19 results.

Live read-only recheck confirms [http_fetch#122](https://github.com/gsmlg-dev/http_fetch/issues/122)
OPEN/Bug/internal request/blocker. Latest v0.21.9/main `81ad386f` is unchanged
and fixes119, not122; dependency cohort remains0.21.4. Historical full58
FAIL845/1 expected original Promise:aborted but observed:einval. Later5/0 and
32/0 are not repairs. Full58 stays BLOCKED_UPSTREAM122 without workaround,
omission or weakened assertion, pending upstream fix and compatible update.
The final read-only snapshot is `sol19-upstream122-final-read-only-check.json`.

Counters: fixedSol19/unsuccessfulGREEN14; collectorSol17/unsuccessfulGREEN12;
matrixfailed11; browserfailed5; R32diagnosticfailed5; nativeH1 RED2/fixture2;
nativeH2 shape RED2/fixture1; local-status RED2/fixture1; full static CODE failed1.
Astra recovery2/2 remains exhausted. Owned46/format38/full58 remain complete.
Forward-only runner3 captures AGENTS.md/implement-plan.md alongside the earlier
source set; old receipts and smaller coverage remain immutable. No stage
acceptance, commit or next-stage activation is claimed.

Previous execution checkpoint (before matrix GREEN12 and Sol19), retained as history:

Latest execution: managed H2 fixed-endpoint activation is INCOMPLETE and
uncommitted. Native H1 Sol17/Sol18 focused GREEN2 passed67/0 with stable
source and narrow independent SPEC then CODE; historical failures are retained.
Fresh format37 and strict compile passed. Full58 executed845/1, exit2,
source stable with zero skips/exclusions. Its sole pre-head public H1
cancellation assertion expected:aborted and observed:einval after confirmed
cleanup. The unchanged file later passed5/0 and the bounded public diagnostic
passed32/0; neither result proves a repair or erases full58's failure.

Upstream [gsmlg-dev/http_fetch#122](https://github.com/gsmlg-dev/http_fetch/issues/122)
is confirmed OPEN, type Bug, label internal request, severity blocker for the
existing cancellation compatibility gate. The callsite has its required TODO;
no local workaround or weaker assertion is authorized. That task remains
BLOCKED until an upstream repair and compatible dependency update. Other
unblocked verification continues. Comment-only routing makes owned46/format38;
the required complete test manifest remains full58, with no omission.

Released canonical Collector Sol16 passed narrow independent SPEC then CODE.
Diagnostic8 PASS4/4 authenticated all128 held cleanup refs and2 refused extras
against all130 authentic raw calls (:ok, max6.594785ms), with real joins and
unchanged1024 caps. Diagnostic7's original overall FAIL remains historical.
Complete matrix GREEN11 remains FAIL87/135, exit1/source stable. The next H2
head-bytes-exact response needs65688 RFC metadata bytes; the fixture advertised
131072 but its decoder retained65536. This establishes a fixture mismatch,
not a production defect. The public update_settings/matching ACK candidate
preserves the existing finite131072 cap,135 identities and120 original collector
assertions. Initial independent SPEC passed; CODE found a first-request/ACK-send
absolute-deadline gap in a controlled-clock model. The targeted candidate repair
passed fresh independent SPEC then CODE with24 deadline and4 fail-closed
models and no actionable findings. Root released Collector Sol17 and its
managed-only peer ACK profile; complete matrix GREEN12 is pending execution.
The first reviewer response-vector arithmetic failure and exact correction are
preserved separately; it occurred before candidate execution.

Fresh public63 PASS63/63 is retained as scoped evidence; browser3 is not fresh
for the eventual final candidate. Current counters: fixed Sol18/unsuccessful
GREEN14; collector Sol17/unsuccessful GREEN12; matrix failures11; browser
failures5; R32 diagnostic failures5; native H1 poll-floor RED failures2/fixture
corrections2; native H2 shape RED failures2/fixture correction1. Astra recovery2/2
is exhausted. Full58 is BLOCKED by upstream122; format38, complete matrix135,
browser3, full stage independent SPEC then CODE and fresh post-review gates
remain required. No phase acceptance or commit is claimed.
Earlier execution summaries below are historical.

Latest native H1 compatibility execution: [clean RED2](../acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/native-h1-partial-upload-red2-1791989000488049202.json)
failed8/4 on exactly the four withheld-eight-byte cases, with the fixture
contracts corrected. Sol13's [GREEN1](../acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/repair13-native-h1-green1-1791989166975977591.json)
executed53/1: all8 new upload cases and original-deadline/cap/network checks
passed; the unchanged trailer-limit error contract was the sole failure.
The bounded short-read [independent SPEC then CODE review](../acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/native-h1-short-read-independent-spec-code-review.json)
passed with no findings. It does not accept the full fixed-H2 slice. Sol14
restores the exact response_trailer_limit reason at the trailer preflight,
retaining every bound and unchanged test assertion. Its focused GREEN passed63/0,
exit0, source stable and zero skips/exclusions.
Current cumulative counters are fixed Sol16/unsuccessful GREEN11, native H1
RED failed runs2/fixture correction1, header RED failed runs2/upload-event
fixture correction1, collector Sol14/unsuccessful GREEN9, matrix failed runs8
and browser failed runs5. Astra recovery2/2 stays exhausted. Sol15 relevant
GREEN87/0 and narrow SPEC/CODE PASS; pre-review full57 PASS824/0, stable exit0
with zero skips/exclusions. Collector Sol14's narrow SPEC then CODE review also
passed with no findings.
Matrix GREEN8 remains FAIL84, exit1/source stable. Both complete H1 cells and
H2→TLS functional/concurrent/controlled cases passed. The R32 repair dispatches
all32 authentic response commands before client joins in17.206/29.193/19.095ms
for those three cells, preserving opening/capacity/identity/byte/cleanup checks.
Those are collector observations, not certified Session timer receipts. Next
H2→TLS head255 expected200 emitted complete empty502. The same255 regular
upstream fields plus status passed both H1 cells. The supported public HPAX
runtime diagnostic confirms256 total fields are feasible: bulk encoding nests
its accumulator to depth258, exceeding the unchanged RendererBounds depth16.
Ordered single-field encoding returns identical bytes, exact public decode and
valid frames at depth4/nodes3832/ETF15994. This is codec diagnosis, not server
acceptance. The diagnostic source and receipt are retained in the evidence root.
Sol16 is planned to build one proper outer list using supported per-field HPAX
calls and carried encoder state, preserving empty-block resize-prefix semantics.
The existing aggregate preflight stays before binary conversion/frames, with
the transient input conservatively charged within the unchanged renderer
allowance, with no cap, field-count, byte or deadline change. Clean native RED2 executed57/2, exactly the head255/trailer128 refusal, while
empty-block wire semantics and renderer arithmetic passed. RED1 executed46/2
with generated-test type warnings; one warning-only fixture correction retained
all assertions. Source-stable RED2 has no compiler warnings. Sol16 production
is released solely for supported codec assembly; native H2 shape RED failed
runs2/fixture correction1 are separate cumulative counters. All earlier
failures and retained uncertainty remain. Complete135 and final complete
review/post-review gates are still incomplete.

Pre-review full57 is PASS824/0. Complete135 matrix, fresh public63/browser3,
final independent full SPEC/CODE and fresh post-review gates remain required
and incomplete.

> **For agentic workers:** Use subagent-driven-development for the disjoint
> ownership below, or executing-plans for dependent tasks. Steps use checkboxes.
> Parent alone executes runtime/Mix/format/build/peers/evidence/commits, with ALL
> writers frozen. Continuing authorization selects this approach automatically.

**Goal:** Activate fixed managed TLS-H2/h2c upstreams for native H1/H2 downstreams
with enforced finite payload envelopes and original-completion cleanup.

**Architecture:** Add ManagedH2Client at the existing UpstreamClient boundary,
a pure envelope, and an additive activation ledger. Reuse owner/Custodian and
Service/Session/pump lifecycle; retain dedicated/managed H1 clients and accepted
pure preparation. No H2 group/probe/Generation/standalone/load activation here.

**Tech stack:** Elixir/OTP, Gaoxy native H1/H2, pinned HTTP0.21.10 public
Fetch/Stream/Promise/RequestCompletion/ManagedTransport, OTP SSL, independent
Python h2 peer and scoped ExUnit tests in the qualified Nix environment.

Status: **IN PROGRESS; prior FULL53 PASS761/0, PUBLIC PASS63, BROWSER PASS3; latest MATRIX FAIL84; final gates incomplete**.
Pure/owner/renderer GREEN2 passed237/0 after Sol repair1; initial237/10 and
client/integration135/51 remain immutable failures, with zero skipped/excluded
tests. Sol repair2 passed the earlier URI/renderer/client regressions but the
combined GREEN2 failed:29 failures awaited FIN-only EOF, and one infeasible
256-regular-field wire fixture exceeded the native limit including status.
Both failure receipts are preserved. Task7 RED executed76/8; its zero-credit
case exposes a downstream H2 operation using the request deadline instead of
the write timeout. An unfiltered H2 network RED executed28/4 and reproduced
the same gap for DATA, queued HEAD/trailers and an expired Writer mailbox head.
Sol repair4 corrects diagnosed fixture contracts and the bounded native H2
operation path. Its strict compile passed, but combined verification executed
759/4 with zero skipped/excluded and stable source. Sol repair5 corrected only
the four diagnosed fixture contracts. Its targeted verification executed107/2,
with zero skips/exclusions and stable source: a real blocked socket send lost
its outcome when the owner link killed Writer, and a retained-byte comparison
crossed the native pump's one-byte poll workspace. Sol repair6 removes the
redundant owner link while retaining monitoring/supervision/finite deadlines,
and makes the exact fixture snapshots deterministic. Its targeted run executed
108/1: network32/0 and both repaired races passed; instance death alone did not
guarantee original uncertainty because the genuine abort could confirm first.
Sol repair7 separates a deterministic confirmed-original/unavailable-Service
case from real published-Stream death before instance collapse, preserving all
uncertainty/retained-token assertions. Its four-file Task7 run passed77/0,
exit0, source stable and zero skips/exclusions. Preserve the preceding9/9
standalone invocation failure: the command omitted the shared fixture in
`managed_h2_fixed_endpoint_test.exs`, then was corrected without source changes.
Browser diagnostic1 failed with zero completed cases; diagnostic2 and3 each
failed after a positive case passed. Diagnostic2 proves exact2C/2W native leases
and346,212,430 bytes, including a speculative connection with `preface:false`.
Historical active3 remains unexplained. The finite Writer-readiness path later
executed with exact2C/2W and `writer_ready:true`. Diagnostic3's complete CDP trace proves h2/502/Content-Length0,
net::ERR_HTTP_RESPONSE_CODE_FAILURE and Chrome's HTTP ERROR502 error page;
the original ordinary-navigation helper contract was wrong for this negative.
Browser negative GREEN1 passed the exact wrong-CA browser assertions but failed
after one positive case with KeyError service.retained_bytes: the actual Service
had exited after original cleanup_unconfirmed. Browser timeline GREEN1 then
proved exact9,444,956 cleanup reserve before exit, terminal missing-Service
receipt and retained owner token, but failed after one case: helpers1 violates
required0. Collector Sol9 then passed complete browser3/3 with actual helper
settlement and helpers0 before disposal. Wrong-CA/name original completions remain
cleanup_unconfirmed with retained failure. No post-exit zero ledger or confirmed
negative cleanup is inferred. All failed receipts and exact assertions
remain in the [acceptance receipt ledger](../acceptance/m3-managed-h2-fixed-endpoint.md#latest-scoped-receipts), including the
[navigation/Service timeline diagnosis](../acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/browser-navigation-and-service-timeline-diagnosis.json).
Full53 GREEN1 passed761/0, public GREEN1 passed63/63 and browser helper-join
GREEN1 passed3/3, all source stable with exit0 and no skips/exclusions. Matrix
GREEN1 failed after5 completed cases: it consumed a stale GET upload_end0 for
POST stream11 despite the actual65536-byte upload completion. Collector Sol10
correlates exact connection/stream; static recorded-event replay passed. Matrix
GREEN2 completed13 cases before C2 refusal returned blank502 instead of required
blank503. The documented public capacity tuple is lost in local normalization;
precise authenticated Task-path RED executed32/4, with all four intended
capacity assertions failing and malformed-error cases passing. Sol10 adds only
the exact documented requests/connections tuple mapping to unavailable.
Control/renderer supplement GREEN1 and GREEN2 each failed63/2; network33/0
proved full-write projection release and repeated terminal rejection. The
bounded trace diagnostic failed30/1 on a non-original-Task `{ref, false}` reply;
Sol11's combined run executed96/1: all capacity cases and renderer33/0 passed;
the real h2c timer reply had matching public cancel_timer CALL/receive/RETURN.
TLS observed zero such replies. The new missing-call counterexample correctly
rejected but raised MatchError through assert/2; Sol12 repairs only assertion
reporting, preserving the expected AssertionError and all provenance/cap limits.
Repair12 combined GREEN passed96/0; real public C2 Promise witness passed with
exact capacity tuple, unchanged original completion, two healthy200 responses
and confirmed public retirement/peer joins. Matrix GREEN3 passed C2 but failed
after14 cases: R32 launched31 clients while connection2 was cold, so P0 correctly
refused5 before the collector's late SETTINGS barrier. Collector Sol11 establishes
both actual16-slot connections before final32-held/refused33 assertions. Limits,
deadlines, simultaneous held requests and all exact oracles remain unchanged.
Matrix GREEN4 then passed R32's two actual ACK16 connections,32 simultaneous
held requests, blank503 refusal33, healthy responses and joins, but remains
FAIL after15 completed cases, exit1 and source stable. The next controlled H1
pre-EOF upload sent16392 bytes; upstream saw only16384, missing8 with declared
Content-Length32781 and EOF withheld. Preserve the immutable
[diagnosis](../acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/matrix-green4-h1-partial-upload-diagnosis.json)
and [run receipt](../acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/matrix-green4-1791987688394641648.json).
The proposed native Exchange repair uses max-sized timeout0 receive probes,
halving to1, followed by one finite wait against the same absolute read deadline;
credit, payload bounds, policy, counts and byte assertions remain unchanged.
Native H1 RED1 executed8/6, exit2, source stable and zero skips/exclusions: four
true byte regressions and two fixture shutdown-expectation failures. The invalid
Endpoint two-tuple abort additionally logged CaseClauseError. B corrects tests
only before RED2; these fixture failures are not capacity/production failures,
and production remains frozen pending parent RED2 and implementation release.
Final SPEC then CODE and fresh gates remain incomplete. The normative
[design](../designs/m3-managed-h2-fixed-endpoint.md) fixes APIs, exact schemas,
slot multiplicities and9,444,956 proposed bytes/request (8,920,668 proxy payload
+524,288 bounded public downstream renderer). The
[acceptance contract](../acceptance/m3-managed-h2-fixed-endpoint.md) lists required
outcomes. Preparation has complete independent SPEC/CODE PASS, fresh format/
strict compile97/0 and fresh public63/0, with zero skips and stable source.
Accepted preparation commit is `c871e3d9ee87cf802acf764d7d7622e0a7b611d6`.
Parent captures source/evidence inventory at kickoff in
`docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/`.
Only verified predecessor/interface work below is checked. Implementation,
client/integration and final acceptance gates remain incomplete. The native URL
diagnostic proved the pinned public URI normalizer omits authority, requiring
strict semantic-field compatibility rather than structural URI equality. It
also distinguished actual reset from orderly EOF. A subsequent normal-retirement
diagnostic confirmed graceful retirement and all three original completions
with reset for both protocols. All paths retain the exact physical signal,
public receipts, request counts and zero forced/live joins. Native-rejected
256-regular-field headers yielded original cleanup_unconfirmed; preserve this
negative outcome and verify retained failure rather than assuming cleanup:ok.
These amendments require final independent review of current document hashes. No
publication/deployment or E2E/Vault scope is granted.

## Ownership and serialization

| Writer | Exclusive implementation/test ownership |
| --- | --- |
| A: envelope/client/accounting | New `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex`, new `managed_h2_client.ex`; additive `managed_h2_reservation.ex`; new `apps/gaoxy_proxy/test/managed_h2_envelope_test.exs`, `managed_h2_client_test.exs`, `managed_h2_activation_reservation_test.exs` |
| B: owner protocol dispatch and Generation exclusion | `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports/options.ex`, `upstream_transports.ex`; `apps/gaoxy_http/lib/gaoxy/http/endpoint.ex`, `generation.ex`; `apps/gaoxy_proxy/test/upstream_transports_options_test.exs`, new `upstream_transport_h2_identity_test.exs`, new `managed_h2_generation_exclusion_test.exs`. B adds optional Endpoint hook/Store invocation; C later adds Proxy.HTTP hook implementation. |
| C: fixed endpoint integration, AFTER A/B API freeze | `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex`, `http/session.ex`, `http/headers.ex`; new `apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs`, `managed_h2_fixed_lifecycle_test.exs`; necessary narrow contract updates in `upstream_transport_proxy_test.exs` and `http_headers_test.exs` |
| Parent | New `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py`, new `integration/http_fetch_contract/managed_h2_fixed_qualification.py`; `apps/gaoxy_http/lib/gaoxy/http/http1/response.ex`, `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex`; new `apps/gaoxy_http/test/managed_proxy_renderer_test.exs`; these three successor documents, evidence; all runtime/build/format/commits |

After the observed Task7 and unfiltered network RED, parent assigned only
`HTTP2.Transport`, `HTTP2.Connection`, `HTTP2.Writer` and, if necessary,
`HTTP2.Stream` to the Sol native write-deadline repair. The existing renderer
guards and ordinary reset/CONTINUATION assertions remain. Parent retains all
format/runtime/evidence/commit ownership, with every writer frozen during runs.
Parent subsequently delegated the fixed collector and its Python peer to A for
the independent four-cell concurrency/capacity/boundary cohorts. This is
exclusive ownership of those two files; parent retains the separate browser
collectors and all runtime/evidence. Their shared host/helper API stays stable.
Parent assigns the native H1 short-read compatibility slice exclusively to B:
`apps/gaoxy_http/lib/gaoxy/http/exchange.ex` and new
`apps/gaoxy_http/test/http1_partial_upload_test.exs`. Parent alone runs RED2,
releases production after the precise RED, and runs all validation/format.
The intended final gate is full57, including the existing
`apps/gaoxy_http/test/native_proxy_seams_test.exs` original-request-deadline
regression; the shorter historical Task8 file list is not the final manifest.

All writers are NOT ALONE and must preserve others' edits. Parent may reassign
test-only ownership explicitly; no shared writer. Preparation production/tests,
Custodian, transport backends, historical supplement/collector and63 public
assertions are read-only. Generation changes are only the optional exclusion
hook; the two public renderers change only for bounded guards/admission.
Any other demonstrated compatibility need requires
parent assignment and narrow regression, not opportunistic cleanup. C starts
only after A/B proposed APIs and protocol identities are frozen. Independent
pure tasks A/B can proceed in parallel; RED, implementation release, runtime,
review, repairs and commits are serialized by parent.

Carry every inherited repair/rejection/harness counter from preparation's actual
kickoff receipt. PROJECT_ARCHITECTURE uses zero recovery; Astra recovery2/2
remains exhausted. Do not reset counters or weaken assertions after a failure.
Parent records new Sol repair/validation attempts and diagnoses separately.
Historical fixed Sol repair round12 and unsuccessful GREEN10 include parent fixture
invocation failure1 and proof supplement failures3. Trace diagnostic failures1
and capacity RED failures1 are separate. Native H1 RED failed runs1 is separately
recorded. Browser failed runs5, matrix failed runs4, collector unsuccessful
GREEN5 and collector Sol repair round11 remain separate; Astra remains2/2 exhausted.

## Task 1: Verify predecessor and freeze interface contract

- [x] Parent reads accepted preparation SPEC/CODE, final97/0 and public63/0
  receipts, local commit receipt and exact source/lock/cohort hashes. Record
  `pwd`, `git branch --show-current`, `git rev-parse HEAD`, `git status --short`
  and task-owned vs pre-existing inventory in the actual worktree.
- [x] Record accepted H1 fixed/group/Generation compatibility sources and the
  existing historical worksheet output; capture all63 public case identities.
- [x] Independent document SPEC readiness checks exact source-field retention,
  protocol identity, thirteen-field Response, opaque projection unit, slot
  ownership/release, sixteen controls and all four network cells. Resolve
  findings in documentation; no runtime acceptance is inferred.
- [x] Freeze additive helper/client/evaluator signatures from the design.
  Parent assigns ownership above, confirms no overlapping process/writer, and
  releases A/B tests-only work. Keep production unedited until observed RED.

## Task 2: Pure envelope and activation accounting (A)

**Files:** New envelope and envelope/activation-reservation tests; additive
reservation only. Historical `worksheet/0` output assertions stay unchanged.
The legacy export whitelist is updated to include the three expressly additive
APIs; its old bytes and results remain available in predecessor commit/evidence.
This necessary test-contract amendment does not change worksheet arithmetic,
activation caps, or the immutable historical evidence.

- [ ] Write executable RED tests with these complete fixture constructors in
  the new envelope test module (`use ExUnit.Case, async: true`):

```elixir
defp config(protocol \\ :http2) do
  %Gaoxy.Proxy.HTTP{
    uri: URI.parse(if(protocol == :http2, do: "https://upstream.test", else: "http://upstream.test")),
    cacertfile: nil, connect_address: nil,
    transport: %{provider: Gaoxy.Proxy.UpstreamTransports, owner: self(),
      owner_epoch: make_ref(), resource: make_ref()},
    upstream_protocol: protocol, client: Gaoxy.Proxy.ManagedH2Client,
    limits: %{max_chunk_bytes: 65_536, opening_timeout: 5_000,
      idle_timeout: 60_000, write_timeout: 5_000, max_lifetime: 30_000}
  }
end

defp source do
  %{url: "https://upstream.test/a%2Fb?", target: "/a%2Fb?", method: :post,
    fields: [{"content-length", "3"}, {"x-trace", "first"}, {"x-trace", "second"}],
    body_mode: {:length, 3}, max_upload_bytes: 65_536,
    request_limits: %{max_headers: 256, max_header_bytes: 65_536,
      max_trailers: 128, max_trailer_bytes: 65_536}}
end

test "pre-Session envelope retains raw Content-Length and raw empty query" do
  assert {:ok, envelope} = apply(Gaoxy.Proxy.ManagedH2Envelope, :prepare, [config(), source()])
  assert map_size(envelope) == 8
  assert envelope.target == "/a%2Fb?"
  assert envelope.fields == source().fields
  assert envelope.body_mode == {:length, 3}
  assert envelope.protocol == :http2
  assert :ok == apply(Gaoxy.Proxy.ManagedH2Envelope, :validate_request, [envelope])
end

test "backing and extra schema are rejected before copying" do
  backing = :binary.copy("x", 65_537)
  small = binary_part(backing, 0, 100)
  assert :binary.referenced_byte_size(small) > 65_536
  assert {:error, _} = apply(Gaoxy.Proxy.ManagedH2Envelope, :prepare,
    [config(), %{source() | fields: [{"x", small}]}])
  assert {:error, _} = apply(Gaoxy.Proxy.ManagedH2Envelope, :prepare,
    [config(), Map.put(source(), :exchange, :forbidden)])
end
```

  Add exact/over URL, target, field count/bytes/backing, effective limits, body
  unsigned64 and signed64 time/deadline cases, all improper tuple/list/map/forged
  struct variants, source/canonical equality and bounded complete sizes. Exact
  boundary tests must be feasible composed inputs, never invented successes.
- [ ] Write RED for exact URI/config/handle/five limits, nil trust/address,
  same authority different protocol, exact four-key trailer policy, token128
  before dedup and129 rejection, allowed128/dropped265/payload65,642/policy67,689.
- [ ] Write RED for exact Response/Headers/Promise/Task schemas, each boolean/
  type/body/stream variant; final status200/599 and199/600 rejection; metadata
  URL provenance; informational128/aggregate2,048 and overhead65,536 boundaries;
  trailer129 rejection before cache; field backing and extra-key forgery.
- [ ] Write arithmetic RED, with direct assertions independent of implementation:

```elixir
test "activation ledger sums complete bounded slots without changing worksheet" do
  b = fn bytes -> bytes + 6 end
  f = fn count, bytes -> bytes + 12 * count + 7 end
  n = fn count, bytes -> bytes + 5 * count + 7 end
  scratch = 3*f.(256, 65_536) + 2*n.(393, 65_642) + 2*b.(65_536)
  assert scratch == 472_157
  proxy = 5*205_337 + 5*147_456 + 2*1_183_744 + 2*67_689 +
    n.(128, 65_536) + 4*f.(256, 65_536) + 4*f.(128, 65_536) +
    3*b.(1_048_576) + 2*b.(65_536) + b.(16_384) + 213_965 + scratch + 65_536
  assert proxy == 8_920_668
  assert 2*81_920 + b.(65_536) + 4_096 == 233_478
  assert 131_072 + f.(1,65_536) + b.(65_536) + 2*73_728 + 4_096 == 413_721
  assert 413_721 <= 524_288
  expected = proxy + 524_288
  assert expected == 9_444_956
  assert expected * 32 == 302_238_592
  assert Gaoxy.Proxy.ManagedH2Reservation.worksheet().named_subtotal_per_request == 2_918_508
  assert apply(Gaoxy.Proxy.ManagedH2Reservation, :reservation_bytes, [[], 1, 1]) == expected
  assert_raise ArgumentError, fn ->
    apply(Gaoxy.Proxy.ManagedH2Reservation, :reservation_bytes, [[], 65_537, 1])
  end
end
```

  Add per-component multiplicity/formula/owner/release-point assertions; prove
  full preparation return fits201,753 Request+3,456 accounting+128 wrappers,
  exact manifest schemas fit3,072 and discard immediately, missing later
  evaluator inputs keep the full ceiling, opaque capability
  projections are typed markers, and private completion/scope interiors never
  reach serialization. Validate schemas/backing before external_size; no
  zero-charged unknown value, complete+projection double charge or sixth copy.
- [ ] Freeze A tests; parent runs the exact scoped RED command below and records
  nonzero executed tests and actual missing-API/assertion failures. It releases
  A production only after that observation.
- [ ] Implement the pure design APIs with bounded recursive traversals and copy
  after preflight; return finite errors. Keep raw envelope Content-Length/source
  fields, use actual-PID preparation only at the later opening gate. Add the
  exact closed `activation_contract/0`, evaluator/manifests and conservative
  validating facade. No process, socket or private capability serialization.
- [ ] Freeze A; parent GREEN runs same files plus historical preparation/
  worksheet tests. Arithmetic and all malformed/exact/over/backing cases pass.

## Task 3: Protocol-bound owner and Options (B, parallel with Task 2)

**Files:** Options/owner and owner tests from ownership table.

- [ ] Write RED for TLS-H2/h2c policy/request dispatch using accepted source
  schemas; no I/O in preparation, exact owner complete accounting and finite
  limits remain required. Verify H1 dispatch unchanged.
- [ ] Write RED for validation AND delegation identity
  `{protocol,scheme,host,port,instance}`. Same HTTP origin H1 vs h2c, TLS-H2 vs
  H1, stale epoch, wrong resource/instance, malformed raw port, forged/excess
  keys and owner death reject before scope admission/Fetch. Authentic captured
  source pin delegates exactly once; wrong holder/operation and late results
  retain the accepted failure/cancellation contract.
- [ ] Write RED for checkout returning exact H2 fetch options, `:http2`/`:h2c`,
  SSL/native_v1/reuse true, manual/raw/stream options and original opaque scope;
  no override path. Assert C2/R32/P0 from accepted preparation.
- [ ] Write RED for optional Endpoint.generation_validate/1 called from
  Store.compiled_bound/2 on preparation and activation, default :ok for old
  endpoints; fixed H2 static Router.compile allowed but Store prepare/activate/
  forged prepared router reject unsupported_generation_endpoint. H1 Generation
  remains accepted. B adds generic hook/Store validation with no proxy dependency;
  C adds Proxy.HTTP rejection after API freeze.
- [ ] Freeze B; parent runs unfiltered new identity + Options RED. Then add only
  pure protocol dispatch, identity comparison and protocol-specific fetch
  options in existing owner; keep owner token/pin/Custodian architecture.
- [ ] Freeze B; parent GREEN includes H1 Options/owner/identity/handoff and
  preparation compatibility. A/B APIs freeze before C production/test release.

## Task 4: Public adapter (A after Task 2 and owner API freeze)

**Files:** New client/client tests. Use public Fetch/Stream/Promise/completion.

- [ ] Write RED for handle schema and original completion, Response projection
  drop, native event validation, raw compression, bodyless behavior, normalized
  bounded task/stream errors, and all client event return forms. Nil/body stream
  and task DOWN cannot fabricate completion.
- [ ] Freeze open/1 exactly as the design's seven-key
  `%{request, managed_transport, timeout, opening_timeout, write_timeout,
  deadline, opening_deadline}` map; nested request is eight keys, checked client
  three keys. No headers/body aliases or overrides. For poll_headers/1 and
  event/2 use `{four_key_handle, submitted_url}` context; return updated exact
  four-key handle. All other callbacks receive the handle unchanged. Session
  retains one compact URL in its existing request slot, until first validated
  head or cleanup; the transient tuple has <=128 wrapper bytes and no URL copy.
  Current/original handles never store URL/Response. H1/H3 keep their old args.
- [ ] Assert cleanup returns only :ok or {:error, finite_reason}; no
  begin_cleanup/3 is added. Pin/task/end/consumption cannot synthesize completion.
- [ ] Write RED for16,385,65,536,1,048,576-byte DATA success;1,048,577 and small
  slice with >1MiB backing rejection. Upload65,536 success;65,537/backing over
  rejection. Trailer128 success/native-valid129 rejection. Assert failure never
  sends public ACK. Test adapter tests without unbounded mocked native interiors.
- [ ] Freeze; parent observes RED. Implement existing behaviour callbacks:
  validate exact opening schemas and checked policy, create owned upload only
  after admitted checkout, prepare actual PID source, Fetch with owner options,
  obtain original completion, return exact handle/upload. Public cleanup uses
  RequestCompletion await/abort-and-await at finite nonblocking polls.
- [ ] Match public Response/Task results by authenticated refs, preflight before
  copying, extract only bounded head and stream, drop all extra metadata. Bound
  native DATA/trailer events; keep original completion even as current handle
  becomes resolved. No raw exception retention or private process inspection.
- [ ] Freeze; parent runs client/envelope/accounting GREEN and existing public
  completion regressions. Confirm any required pinned public option from public
  source/contracts; missing upstream capability routes an issue and blockers.

## Task 5: Pre-Session integration and finite controls (C)

**Files:** HTTP/Session/Headers and integration/lifecycle/Headers tests.

- [ ] Write RED for pure raw+compiled config initialization, supported handle
  protocols and resources(), unsupported dedicated H2/group H2/H3 combinations,
  exact URI/limits/override rejection. Update old fixed-H1 tests only where
  their blanket non-H1 rejection overlaps newly authorized managed H2; retain
  every H1, managed-H3, dedicated-H2 and malformed-input assertion.
- [ ] Write RED observing Session startup arguments before child creation:
  exactly eight request keys, no Exchange/policy/arbitrary limits/path/query/
  manifest; raw compact Content-Length survives nil-body preflight. Test length
  first/middle/last with supplied/generated Content-Type and both protocols;
  actual-PID preparation rejects invalid effective heads before Fetch bytes.
- [ ] Write RED for activation->authenticated checkout->upload creation->Fetch
  ->original completion bind->ready ordering, no pre-admission producer/bytes,
  exact captured-pin/handoff identities and cleanup on each pre-bind rejection.
- [ ] Write RED for request/selector/awaiting/opening payload release after bind,
  one poll timer, <=4 existing actor monitors, nil group, finite control fields,
  no retained full Response, repeated terminal/error messages and no new queues.
  Verify one scalar/control shell is charged once and dedicated payload charges
  survive handoffs. Check signed64 arithmetic before timer creation.
- [ ] Retain managed_path:true after clearing managed_transport payload; assert
  settle still awaits original completion and complete_service checks receipt,
  while submitted_url remains one separately charged request-slot binary until
  head/cleanup. Test both first-response polling and task-message delivery with
  tuple context, plus mismatched Response URL and repeated cleanup.
- [ ] Write RED for bounded Headers token preflight before split/dedup/join,
  allowed/dropped policy schemas and safe declarations; preserve forbidden/
  untrusted filtering and ordered duplicate trailer policy. Verify declaration
  names stay in Exchange.response_trailers/FramedResponse through downstream
  completion/cleanup. Renderer allowance owns encoded head; source request slot owns URL/
  target assembly without an extra simultaneous representation.
- [ ] Freeze C; parent observes RED. Implement minimal dispatch/integration
  branches using the A/B APIs. Before start_child, construct validated compact
  envelope and request reserve; retain raw source fields. Bind original
  completion before ready and clear opening payloads afterward. Keep H1/H3
  branches and exact negative uncertainty behavior through narrow guards.
- [ ] Use one tracked poll timer, cleared when firing; do not schedule a second
  poll during pending cleanup. Apply exact event/control normalization and
  logical/backing checks before Session caches and pump handoffs. Existing
  full downstream write path controls ACK; frame size remains16KiB.
- [ ] Freeze C; parent GREEN includes new pure/integration/lifecycle tests and
  affected H1/H3 compatibility, with no skip/exclusion/relaxed assertion.

## Task 6: Independent fixed-endpoint network matrix (parent)

Before peer execution, parent owns a tests-first public renderer repair:

- [ ] Write/observe RED in managed_proxy_renderer_test.exs for H1 nested
  rendered iodata and H2 public HPAX return/block/frame queue limits. Enforce
  finite proper iodata byte/binary leaves, <=8,192 nodes/depth16, backing/logical
  <=65,536 before serialization/conversion/send. H1 complete head<=81,920;
  H2 returned iodata<=131,072, compact block<=65,536, at most four16KiB header
  frames per block, full frame-list/queue projection<=73,728 and at most two
  request-owned final/trailer projections. Reject duplicate terminal emissions.
- [ ] After RED, add minimal guards in HTTP1.Response/H2Connection and qualify
  full-write return/queue release. Use existing Service attach_cleanup seam,
  not a new owner: reserve9,444,956 including renderer524,288. Remove the
  formerly proposed B(65,536) encoded-head proxy scratch charge to avoid double
  count. H1 sum233,478 and H2 sum413,721 fit524,288; assert all subcaps and
  complete projections rather than rely on observed normal size. Preserve
  per-stream and shared control ordering and existing backend native boundaries.
- [ ] Freeze; parent GREEN includes renderer tests and affected H1/H2 response,
  stream flow-control, frame/write and H3 FramedResponse compatibility. Preserve
  failed/blocked receipts and fresh independent review; no native/private proof.

**Files:** New peer and collector plus new fixed endpoint tests. Keep existing
63 public assertions/collector and old0.21.3 supplement/evidence byte-identical.

- [ ] Add a real Python h2 peer over TLS or TCP, with finite line-delimited JSON
  commands/events, bound socket deadlines, protocol counters and explicit joins.
  Peer commands are `respond`, `data`, `inform`, `reset`, `goaway`, `settings`
  and `stop`; controlled downstream clients use `upload` with `ended:true`
  to release upload EOF. These implement the planned head/DATA/upload/reset/
  GOAWAY/close barriers without introducing aliases. Events identify accepted connection, exact
  ALPN, authority/path, ordered fields/trailers, upload bytes before EOF, stream
  ID, DATA delivery, reset/GOAWAY, peer EOF and stopped child. Never simulate
  Fetch or use Gaoxy as both upstream peer and acceptance oracle.
- [ ] Add four unfiltered matrix cohorts with explicit protocol selectors:
  downstreamH1/TLS-H2, H1/h2c, downstreamH2/TLS-H2, H2/h2c. Use native Gaoxy H2
  downstream via an independent Python h2 client, not a hidden production
  server adapter. Make each case assert exact request/response bytes and finite
  public cleanup rather than HTTP status alone.
- [ ] Cover exact h2/no fallback and wrong CA/name; numeric address preserves
  authority/SNI. Test sequential reuse plus simultaneous streams, two connection
  capacity,32 active request limit/zero pending, refused33rd request/no replay,
  reset/GOAWAY failure with healthy sibling progression. Coordinate saturation
  via observed peer stream IDs/barriers; do not infer refusal from a timeout.
- [ ] Cover escaped target/present empty query, ordered duplicate heads and
  trailers, pre-EOF upload, valid early final stopping producer, manual redirect,
  encoded compression and unchanged CL, HEAD/204/205/304. Record exact original
  completion and final cleanup per cell.
- [ ] Cover exact/over response heads, trailer129, informational limits and
  declarations. Native-valid inputs above adapter limits must actually reach
  the adapter where feasible; malformed/native-rejected cases remain distinct.
  Unit injections independently cover unrepresentable/forged/backing cases.
- [ ] Collector captures source/build/lock before and after; loaded BEAM/native
  identity in each actual VM; toolchain/Python h2 and separate CLI/Python OpenSSL
  versions; exact command/exit/counts, each public result, zero exclusions/skips,
  EOF and joined peer helpers. A counted case must execute its assertions;
  marker-only output is insufficient. Preserve63 actual public cases separately.
- [ ] Run separate local browser acceptance with Chrome DevTools skill: native
  Gaoxy TLS/h2 downstream and test fixed TLS-H2 peer; navigate /probe, fetch
  streamed /stream and /early, verify network protocol h2 and exact visible/
  fetched bytes, plus bounded wrong-name/CA upstream error without replay.
  Positive Page.navigate must have no error and finish normally. Negative
  navigation separately requires exact h2/502/Content-Length0, matching
  errorText/loadingFailed net::ERR_HTTP_RESPONSE_CODE_FAILURE and Chrome's
  errorPage displaying HTTP ERROR502; this DOM is distinct from server blank
  bytes. Record network/console/screenshots or trace and public cleanup/peer joins.
  Wait finitely for Writer readiness before a fresh exact Connection/Writer
  lease bijection and byte snapshot; never retrofit historical active3.
  Confirmed positive cleanup joins Chrome before the unchanged zero ledger.
  Unconfirmed negative cleanup requires the live exact9,444,956 reserve timeline,
  terminal missing-Service receipt, retained original/owner token and explicit
  failed disposal/joins; a missing Service never becomes a zero ledger.
  Use test-only certificate SPKI trust scope where needed; no operational cert,
  global trust or public management. Browser unavailability is BLOCKED_ENV,
  not a Python-peer or unit-test substitute.

## Task 7: Deterministic backpressure, failure and release order (C/parent)

Scoped Sol7 Task7 verification is PASS77/0 with source stable, exit0 and zero
skips/exclusions. The [actual receipt](../acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/repair7-task7-green1-1791978949336750062.json)
does not complete matrix/browser, final independent review or fresh gates.
Checklist completion remains parent-owned after full acceptance.

- [ ] Write/observe RED for a real controlled downstream-write barrier: send a
  valid >16KiB DATA event, withhold the full write, observe no public ACK and
  no next DATA. Release write, observe one ACK then next DATA. Fail after a
  partial piece and assert cancellation/no ACK/no retry/replay/second response.
  Use barrier messages and bounded polling, never arbitrary sleeps.
- [ ] Cover upload/producer death, downstream cancel, unread body, open/idle/
  write/total timeout, Session/transport owner/native actor/instance death, both
  pre-head and post-head failure semantics, repeated cleanup calls and late
  handoff after shortened deadline. Every owned helper must finish or retain
  an explicitly unconfirmed failure receipt.
- [ ] Hold original public completion pending with the deterministic public
  peer/consumer barrier; verify transport token1/request pin1/Service reserve
  remains. Consumption/task DOWN/terminal event alone never frees it. Release
  barrier and observe original completion ->owner finish->pins release->Service
  receipt->Session DOWN. Capture all identities; current handle substitution
  cannot replace the original completion.
- [ ] Verify one completed request releases its request holds while the healthy
  sibling/shared physical connection survives. Retire final owner scope with
  public receipt, actual peer EOF/reset and all owned helper joins, recording owner
  physical vs request vs Service ledgers separately. Wrong CA/name uncertain
  completion is recorded as actual failure/unconfirmed, not a fabricated success.
- [ ] Freeze; parent GREEN runs lifecycle/peer matrix. Diagnose any regression,
  preserve RED/failed receipts and record repairs; never lower assertions.

## Task 8: Independent reviews and fresh scoped verification

- [x] Freeze ALL source/docs/tests/collectors. Parent creates candidate manifest
  with exact hashes, baseline/diff and full gate coverage. Independent SPEC
  review first checks every design/acceptance item against executed evidence.
- [x] Resolve SPEC findings, retain failures/counters, re-freeze and rerun
  affected checks. Independent CODE then checks exact envelope/owner identities,
  opaque accounting/copy multiplicities, preflight-before-serialization, original
  binding and every failure/ACK/cleanup release path. No automatic Astra review.
- [ ] Resolve actionable CODE findings; independent re-review as needed. Parent
  runs fresh post-review format, strict compile, all scoped checks and real peer
  qualification with all writers frozen and source stable. Do not reuse earlier
  green results as the final gate after a later source change.

The required final scoped gate is the parent's complete full58 manifest.
The historical full57 and shorter lists below are scope examples; they cannot
replace all58 paths. After the0.21.10 dependency repair and Sol20 fixture
compatibility change, fresh full58 and public63/matrix135/browser3 are still
required after complete updated SPEC then CODE. Historical passes and the
retained0.21.10 full58 failures are not current stage acceptance.

Commands below are **future parent commands**, not executed by this document
writer. Run from the actual worktree after source freeze; keep each independent
runtime command serial and capture stdout/stderr, environment, hashes and exit.
First use the new tests for RED, then for GREEN; expected RED is nonzero tests
with the missing implementation/assertion failure, GREEN requires zero failures.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_envelope_test.exs apps/gaoxy_proxy/test/managed_h2_activation_reservation_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs apps/gaoxy_proxy/test/upstream_transports_options_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_client_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix format --check-formatted apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_reservation.ex apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports/options.ex apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex apps/gaoxy_proxy/lib/gaoxy/proxy/http/headers.ex apps/gaoxy_proxy/test/managed_h2_envelope_test.exs apps/gaoxy_proxy/test/managed_h2_activation_reservation_test.exs apps/gaoxy_proxy/test/managed_h2_client_test.exs apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs apps/gaoxy_proxy/test/upstream_transports_options_test.exs apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs apps/gaoxy_proxy/test/http_headers_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --warnings-as-errors
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_envelope_test.exs apps/gaoxy_proxy/test/managed_h2_activation_reservation_test.exs apps/gaoxy_proxy/test/managed_h2_client_test.exs apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs apps/gaoxy_proxy/test/managed_h2_preparation_test.exs apps/gaoxy_proxy/test/managed_h2_reservation_test.exs apps/gaoxy_proxy/test/managed_h1_preparation_test.exs apps/gaoxy_proxy/test/managed_h1_accounting_test.exs apps/gaoxy_proxy/test/http_headers_test.exs apps/gaoxy_proxy/test/upstream_transports_options_test.exs apps/gaoxy_proxy/test/upstream_transports_test.exs apps/gaoxy_proxy/test/upstream_transport_identity_test.exs apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs apps/gaoxy_proxy/test/upstream_group_transport_test.exs apps/gaoxy_proxy/test/upstream_group_transport_proxy_test.exs apps/gaoxy_proxy/test/upstream_group_transport_probe_test.exs apps/gaoxy_proxy/test/upstream_group_tls_test.exs apps/gaoxy_proxy/test/upstream_group_member_limits_test.exs apps/gaoxy_proxy/test/http_fetch_completion_test.exs apps/gaoxy_proxy/test/http_fetch_contract_test.exs apps/gaoxy_proxy/test/http_proxy_runtime_test.exs apps/gaoxy_proxy/test/http_proxy_wire_test.exs apps/gaoxy_proxy/test/http_proxy_tls_test.exs apps/gaoxy_proxy/test/http3_session_client_test.exs apps/gaoxy_proxy/test/http3_guardian_test.exs apps/gaoxy_proxy/test/http3_proxy_test.exs apps/gaoxy_http3/test/proxy_test.exs apps/gaoxy_http3/test/headers_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test python integration/http_fetch_contract/h2_02110_qualification.py --evidence "$GAOXY_H2_FIXED_PUBLIC_EVIDENCE"
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test python integration/http_fetch_contract/managed_h2_fixed_qualification.py --evidence "$GAOXY_H2_FIXED_MATRIX_EVIDENCE"
```

The parent defines the two task-specific evidence paths before executing each
collector. The new fixed collector implements the exact `--evidence PATH` CLI;
it writes source identities, cell/case outcomes, counts and joins to
`qualification.json`, and exits0 only for complete matrix success. No expected
activation count is invented: report discovered executable test/case counts,
require >0 and all prescribed cases. The unchanged public gate requires63/0.
When a shared Session/Headers change affects another H3 lifecycle/header seam,
add that exact affected test to fresh scope with reason; do not silently broaden
to unrelated suite cleanup. Upstream defects follow repo issue routing and
blocker policy. `http_fetch#97` is never a gate. A hosted no-start stays
BLOCKED_ENV, without spending/settings requests.

Mandatory additional fresh checks for the two demonstrated compatibility seams
(and the exact production/test files owned there):

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix format --check-formatted apps/gaoxy_http/lib/gaoxy/http/endpoint.ex apps/gaoxy_http/lib/gaoxy/http/generation.ex apps/gaoxy_http/lib/gaoxy/http/http1/response.ex apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex apps/gaoxy_http/test/managed_proxy_renderer_test.exs apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs apps/gaoxy_http/test/managed_proxy_renderer_test.exs apps/gaoxy_http/test/generation_test.exs apps/gaoxy_http/test/generation_resources_test.exs apps/gaoxy_http/test/generation_release_deadline_test.exs apps/gaoxy_http/test/generation_loader_test.exs
```

Parent records the exact affected HTTP1/HTTP2 renderer/connection/flow-control
test paths in the kickoff manifest after inspecting the current inventory, and
runs them unfiltered; these seam tests do not replace required wire/TLS/browser
or the broad named proxy/H3 compatibility cohort above. New tests use tests-first
RED before guards; all required fresh format/compile/peer/browser gates follow
complete independent SPEC/CODE, with actual discovered counts, no guessed pass.

## Task 9: Local closure and next bounded stage

- [ ] Parent updates acceptance with actual predecessor/candidate source and
  environment, exact counts/exits/source stability, passing SPEC/CODE identities,
  actual cleanup uncertainty if any, owner/request reserve and final peer joins.
  Do not tick a required case that failed, was blocked or did not execute.
- [ ] Verify all parent commands stopped safely and no writer/runtime overlaps.
  Stage only task-owned files after full passing fresh gates, and make local
  conventional commit `feat(proxy): activate managed H2 fixed endpoints`; omit
  generated-by/co-author trailers. Record actual commit and preserved inventory.
- [ ] Report fixed-endpoint slice DONE only if every required acceptance item
  passes. Automatically prepare the next written managed-H2 groups/probes plan
  under continuing authorization; then execute it after its independent
  readiness. Keep later Generation, standalone and load claims separate.
  No push/release/deployment/E2E activation is inferred from this local commit.

## Native H1 polling compatibility repair — Sol17 planned after diagnostic6

Diagnostic6 retained all1024 first-distinct original snapshots and rejected
key1025, despite suppressing2737 exact repeats. Raw high-water226 was below1024;
no normal observer/Gate/tracer join or cleanup call executed. This confirms an
actual H1 empty-poll state-combination limit, not merely a raw queue backlog.
The canonical collector remains Sol15 v2; neither experimental projection set
has been released as a passing collector repair.

The recommended bounded repair keeps native buffer/poll workspace as a
persistent conservative request lease floor. Add `poll_buffer_bytes: 0` to
Exchange; `retained_bytes/1` charges `max(byte_size(buffer), poll_buffer_bytes)`
in place of its previous raw-buffer term. For each native poll, prepare a
candidate floor `max(poll_buffer_bytes, 2 * byte_size(buffer) + 2)`, check
Admission against its full total, and perform the unchanged one-byte receive
only after admission. A refused increase returns the original Exchange and
performs no receive. Timeout/close retains the admitted floor. A successful
receive adds one actual buffered byte without increasing the admitted total:
`b + 1 <= 2 * b + 2`. Body/response operations already use `retained_bytes/1`,
so carry the same floor. H2 facade exchanges keep the default0 and previous
buffer accounting.

The floor is at most `2 * max_buffer_bytes`: polling refuses a full buffer
before computing it. For buffer size b, the old buffer b, received byte1 and
new concatenation b+1 have peak2b+2. Preflight charges this peak before receive,
without depending on compiler allocation optimizations. Returned state cannot
exceed that preflight merely because its buffer grew by1. The floor is released
by the existing real request/reuse transition
`Admission.retain(..., byte_size(exchange.buffer))` or connection lease removal;
a newly constructed Exchange starts with0. No Service/Admission lifecycle,
cleanup50ms, limits, slot multiplicities or request deadline is changed.
Original checks continue on every poll; no stale-lease check is bypassed.
The earlier additive b+1 proposal was rejected during read-only arithmetic
review before implementation: it undercounted the separately live input/copy
peak and allowed returned-state growth beyond preflight at an exact cap. This
readiness correction is not a production repair attempt or GREEN result.

Parent first requires real passive TCP regression RED for stable admitted
workspace across repeated empty waits, high-water buffer copy accounting,
byte-cap refusal before consuming input, original deadline/close behavior,
read/send persistence and real native keepalive reuse release. Only the
observed intended RED permits production release. After focused GREEN and
independent narrow SPEC then CODE, use the independently proven exact adjacent
projection suppression experiment against all four original R32 cells/128
cleanup pairs. It may suppress only adjacent states rendering the same full
original snapshot; first different states, invariant failures, both1024 caps,
FIFO fences and sticky overflow remain. A passing experiment does not replace
the full135 matrix or the complete stage reviews and fresh post-review gates.

All writers remain frozen during parent runtime. Current counters are
fixed Sol18, collector Sol16 and R32 diagnostic failures5. Collector Sol16
is released after actual diagnostic8 PASS4/4; full135 is still required. Astra recovery2/2 remains exhausted; no third
round is allowed.

The Sol17 compatibility gate adds the existing
`apps/gaoxy_http/test/connection_poll_test.exs` to the full58 manifest: its old
pending/close assertions require the previous released temporary-credit state.
A necessary explicit contract amendment preserves buffer/body/deadline/errors,
pre-recv refusal and no-consume assertions while asserting the persistent floor
and exact equality with the real Admission ledger. Parent also owns the new
regressions in existing `native_proxy_seams_test.exs`. These two files extend
owned45/format37; full57/format35 receipts stay immutable historical evidence.
The prescribed final gate is now full58/format37, plus strict compile,
public63, matrix135 and browser3 after complete independent SPEC then CODE.
No full58 or format37 result is claimed until actual parent execution.

## Local native request status repair — Sol19

- [x] Trace native HTTP1.Body400/413/431 through Exchange to trusted local_fail
  and independently review the bounded design: preserve only400/413/431 for
  ManagedH2Client, discard raw diagnostics to existing :invalid_request and
  carry a private finite status into shared cancellation/rendering. Generic
  upstream errors normalize before status selection. Preserve cleanup,
  unset-head/total-expiry, close, caps and original deadline predicates.
- [x] Release additive TLS-H2/h2c tests and observe genuine RED2 complete38/8.
  Retain RED1 as fixture failure and its sole test-contract correction.
  Original30 tests and all8 exact status/cleanup assertions remain unchanged.
- [x] Release fresh production only after bounded independent CODE; run complete
  endpoint GREEN and adjacent write/lifecycle/release/compatibility checks.
  Actual Sol19 release and GREEN38/0 plus compatibility141/0 are recorded;
  these passing scoped checks do not establish stage acceptance.
- [x] Freeze owned46 and all complete gate manifests; full independent SPEC
  then CODE, followed by fresh unblocked format38, strict compile, public63,
  matrix135 and browser3. Prior matrix/browser passes are historical evidence.
- [ ] Resume unchanged complete full58 after upstream122 is repaired and the
  compatible dependency is updated. Every prescribed gate and review must
  pass before the stage commit or successor execution.

Native H2 oversized DATA retains reset(CANCEL). A committed final head sets
upload_stopped, making remaining malformed uploads a noncausal post-head case;
retain existing early-final/reset/committed-head cancellation coverage instead.
The per-case wire/completion deadline remains5000ms. Exact diagnosis, design,
plan, TESTONLY/corrected fixture and fresh production candidate are preserved
in the existing evidence directory; no discarded production draft was reused.
