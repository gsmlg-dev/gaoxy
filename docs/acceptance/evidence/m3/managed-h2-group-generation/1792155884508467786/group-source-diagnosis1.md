# Group source boundary diagnosis1

Task: gaoxy-group-generation-group-source-diagnosis1. **DONE — actual invalid_group_source boundary confirmed; smallest repair recommended.** Read-only direct diagnosis; no repair/runtime PASS claim.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, baseline `8131af39a846c292a022ccbfd32c53376cd57887`.

## What actual diagnostic1 proves

First row h2-h2c fails after38905ms, executed1, source_stable=true. The old navigation and exact genuine request_clean baseline pass.

Fresh native `<0.424.0>` emits host.log49–53 ordinals1..5: captured_resources?=true; actual admission validation=ok; Admission.adjust_bytes=ok; ManagedH2Envelope.validate_group_source returns **{:error,:invalid_group_source}**; Admission.adjust_bytes refund=ok. Host.log54 then records original endpoint result ok/sent/close=true, pre_bound, no observed Session/bound, matching native/ref and14973ms remaining. Host.log55–56 fails the original host3:1651 bound assertion. Browser.log3 independently records exact new URL response **400 over h2**, with extra status400.

Source sequence localizes this run to group_request_options before its compact copy and Session startup. The else maps source rejection to invalid_request and the dispatcher emits400, explaining why the original return still looks ok/sent.

**The trace does not identify the failing field/predicate.** group_source_shape versus target/field compactness is unresolved; no raw backing measurements were captured. Do not attribute this to a particular Chrome header, cookie or HPACK dictionary. Historical browser-green2 remains FAIL with initiating cause UNKNOWN; matching symptoms do not retrospectively link it.

Collector3 itself joined cleanly without forcing/remaining/exhaustion, but the fixture still failed: browser/host exit1, four peers forced TERM/-15, all recorded readers/groups joined, seven adopted children joined and none remaining. A clean outer collector does not override these failures.

## Source mismatch and minimal repair

http.ex:429–475 builds a raw neutral source. At466 it invokes **validate_group_source**, which requires already-compact target and field binaries; only after success does467–473 manually copy them. Thus allowed bounded noncompact input is rejected before its intended compaction can execute.

The existing API already provides the correct boundary:

- managed_h2_envelope.ex:43–46 **prepare_group_source** runs raw group_source_shape before copying target and field names/values.
- :49–55 **validate_group_source** runs the same raw shape plus compactness, for retained/prepared values.
- managed_h2_group_source_test:189–204 already documents bounded4096-backed slices rejected by retained validation but accepted/prepared compactly with identical byte values.

Recommended surgical edit: bind `{:ok, compact_source} <- ManagedH2Envelope.prepare_group_source(source)` at the current validator position, return `{:ok, compact_source}`, and remove the duplicated manual copy block. Preserve the existing else mapping to invalid_request. No envelope/API/dependency redesign is required.

This preserves raw checks before copy: exact six-key shape; method/body/upload/request-limit ranges; target grammar; target logical/backing<=65536; proper fields<=256 with logical/backing totals<=65536; combined target+fields logical/backing<=131072; raw complete ETF<=205337. Outer target/path/query/time and maximum-origin+target<=65536 checks remain. Byte values, duplicate field order and escapes remain exact.

Subsequent neutral accounting and Session retained validators still require compact prepared input. Do not weaken validate_group_source, compact before raw preflight, increase caps/deadlines/lifetimes or add a guessed field exception.

The misuse is source-proven for admissible noncompact inputs. Actual diagnostic1 only proves rejection at this boundary; it does not prove the unseen raw shape was otherwise valid. Fresh verification must establish whether this change resolves the browser failure.

## Deterministic actual H2 regression location

Use managed_h2_group_endpoint_test.exs near the existing wire matrix at18–80, for upstream http2/h2c with H2 downstream. Existing G.fixture, G.connect, G.send_request/7, G.response/4, G.event/G.command and G.clean/G.close provide real native service, actual independent upstream peer and cleanup.

Keep one socket: stream1 response, then stream3 response. **G.request/4 opens/closes each time** (fixture249–255), so it misses connection reuse.

For a deterministic representation case, send an explicit plain/non-Huffman literal :path or benign field over64 bytes but below all limits, such as '/' plus100 '~' bytes, through existing Frame.encode/4/direct TCP HEADERS usage. The fixture's endpoint_module override can host a passive observer that asserts actual native byte_size<referenced_byte_size<=65536, emits only finite sizes/booleans and delegates unchanged. Do not mutate Exchange or assume a client encoding creates subbinaries; assert the witness without skips.

Require both actual200 responses, exact echoed target/peer GET/:path/field and upstream identity, same socket/stream IDs, no retry, original completion/owner cleanup and G.clean/G.close. Existing source tests152–204 keep raw oversized/malformed rejection and retained-preparation distinctions visible. Helper-only tests cannot replace the actual H2 regression or fresh browser matrix.

This is a proposed regression recipe; no test was written or run. Root should obtain deterministic RED before implementation, focused GREEN after, independent review and prescribed fresh scoped/browser gates.

Root selected the existing GroupGeneration `CapturedGroup` wrapper and helpers as the regression location instead of adding the proposed passive observer. This is an appropriate narrower alternative: two per-upstream-protocol cases keep the same open connection, complete/capture/CAS/retire old stream1, then send fresh stream3 with a plain literal benign `x-slice` field of100 bytes. Existing capture inspects the unchanged actual Exchange and asserts noncompact header backing<=65536, native95/R/B/W/custody, exact upstream peer headers, response200, joins and all-zero cleanup. No new wrapper, constructor shape or cap is needed. This acknowledges root's chosen implementation plan only; no new source inspection or runtime execution was performed for this update.

## Evidence binding and limits

Sixteen inputs were hashed before/after with no drift. Five relevant production sources match diagnostic qualification source_before; both observed log digests match artifact receipts. Full manifests are in companion JSON.

- http.ex SHA256: `76ec5ad7e9cf3c986b8da97be191fd7463a417cc0a4d5851f8bdf209004ddb98`
- ManagedH2Envelope SHA256: `c8a63c08ce6852d73a094e9172d5ca61817d68744db949ce478c7aa656831947`
- Actual host log SHA256: `ad0a0642603c953230f35c96448dc739ee58d5a04cd969e9c9f2e8573820e750`
- Actual browser log SHA256: `c47880421c9e6d16d18c7f06aca8f86fc9631d859132064cd0d98a8c5886cb35`
- Collector receipt SHA256: `550ad41d1196cb6474828b5e0eb195d7527c952374637ad64a47f7f1d47ce891`

Read/hash commands exited0. One guessed fixed-fixture support path was absent and resolved to the fixture defined in managed_h2_fixed_endpoint_test.exs. Tests executed0; imports/Mix/build/network/browser/process actions NOT RUN. Raw NetLogs/private keys/forbidden terminal trace were not read. Only the assigned /tmp reports were written, no repository changes; all own commands completed with no running session.

Counters preserved: group failedGREEN51/root97/orchestration29; stage failedGREEN6/production1/fixture7/orchestration22. Own repair rounds0, Astra2/2 exhausted; no reset/escalation. No user decision is required. All implementation, regression and acceptance work remains root-owned.

