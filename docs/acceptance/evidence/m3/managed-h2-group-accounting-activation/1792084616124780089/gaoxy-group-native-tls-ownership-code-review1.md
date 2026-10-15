# Native TLS ownership proposal1 focused CODE review

Task: `/root/browser_contract_spec/native-tls-ownership-code-review1`. Direct independent read-only review of another Sol author's unimplemented patch. **DONE_REVIEW / CHANGES_REQUESTED** for the proposal1 test findings below; no new production-code defect found within this focused scope. This is not final stage CODE or implementation acceptance.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Historical supplied baseline `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`; no Git command used. Root owns current source, runtime and Git. Current target bytes exactly match the patch's four declared before hashes. No repository mutation or runtime/build/browser/test/process-control action was performed.

Reviewed `/tmp/gaoxy-group-native-tls-ownership-proposal1.md`, `.json` and `.patch`; patch SHA256 **3821eae059f8b03d01eb20726ce536ee4fcc8c4e05494a4ec72a71314f609d79**.

## Findings

1. **TLS-CODE-01 — expected native connection close is rejected by the new join assertion (medium).** Proposal patch219-221, proposed new test137-139, monitors owner/Writer/worker and applies `reason in [:normal,:noproc,:shutdown]` to all three. Closing the client TLS socket takes ThousandIsland.Handler's existing peer-close path, which terminates the connection owner with `{:shutdown,:peer_closed}` (`deps/thousand_island/lib/thousand_island/handler.ex:421`). That expected tuple fails this new assertion after otherwise successful proxy behavior. Use role-specific expected reasons, including the precise native owner close tuple; retain exact joins and finite deadlines. Do not broaden all actors' outcomes to arbitrary shutdown tuples. Parent reports proposal2 is already addressing this; proposal1 remains preserved with the finding.

2. **TLS-SPEC-01 — owner-side authoritative expiry branch lacks an exercising test (acceptance gap, not a discovered production bug).** Proposal patch111/118, proposed new test29/36, sets a local Exchange deadline to now. Existing Transport.operation checks remaining time at transport.ex27-31 and returns timeout without contacting the owner. The assertion therefore does not execute the new Connection operation's authoritative `stream.deadline` guard (patch23-30). Keep this useful local expiry assertion, and add a separate deterministic actual valid-worker queued call that reaches the owner after its original deadline while preserving Admission's real watchdog. Observe the owner's precise timeout result with actual caller/stream/token identity; do not fabricate a live post-deadline worker or disable the watchdog. This is the parent's known pending SPEC gap, restated as an unmet proposal1 regression requirement. Proposal2 is expected to add that case.

No other actionable finding was identified in this bounded production patch/test source review.

## Production behavior review

- Native Connection continues retaining its complete existing `state.ssl`; constructor patch39-42 makes native H2 per-stream `Exchange.ssl=nil`. This removes the duplicated full TLS payload from the actual group pump rather than filtering it or loosening its accounting grammar. No ManagedH2GroupAccounting/cap change is present.
- New Exchange.ssl_data native-H2 clause (patch7-12) uses existing Transport.operation. Existing Connection.call4 at connection.ex571-580 first matches actual GenServer caller PID to stream.worker plus exact stream ID/token. The new operation is beneath that gate and checks the authoritative original stream.deadline before returning exact state.ssl. Foreign caller with copied token, wrong token and unknown stream fail through the unchanged closed result.
- The live authorized worker receives the original full metadata through both Exchange and Plug. An explicit metadata API call can copy the term into endpoint code, as expected; the production group pump does not call this accessor or capture its result. Public PlugAdapter69 still delegates to Exchange.ssl_data. Peer certificate, secure/peer/sock APIs are untouched.
- HTTP1 keeps its direct Socket.connection_information path; H3/other transported Exchanges keep the old stored-ssl clause because the new clause matches only HTTP2.Transport. Cleartext native H2 naturally returns the owner's nil TLS data.
- A copied native H2 Exchange queried by another process changes from readable stored data to nil/closed, deliberately following the parent-authorized stream ownership boundary. The proposal documents this restriction; no broad cross-process compatibility claim is accepted.
- Transport's existing finite call bound and catch behavior remain. The new owner deadline check prevents a modified local Exchange deadline from extending the original stream authority; exercising that branch remains TLS-SPEC-01.

## Test and evidence review

The proposed two actual-network cases use independently verified TLS/h2 downstream and real TLS-H2/h2c upstream fixture peers; require ALPN h2, nonzero OTP session_data, exact owner/API/Plug equality, nil Exchange payload, real Admission connection/request lease associations, exact original RequestCompletion,16,478,862 cleanup on the actual request lease and correct Service guardian, downstream200/empty body, completion success, actor joins and zero Service/G/T cleanup. The existing group fixture's1,073,741,824 native Service budget is retained, not raised by this patch. Its scoped test adds and removes its extra native TLS Service before existing G.clean/G.close checks.

The structural accounting addition preserves the existing closed vocabulary and adds nil-payload native H2 acceptance plus malformed/PID/logical/backing negatives. It grants no live authority. Existing source assertions remain unchanged. Tests are still a proposal: executed count0 for this patch, syntax/format/runtime/joins not validated by this review.

The cause is now **runtime-confirmed** by the parent's later diagnostic2 capture, not merely the earlier source-derived diagnosis: `E/native-tls-startup-diagnostic2-1792096890813828777/actual-pump-tls-validation.jsonl` has SHA256 **0f6f05ca2b4a8f9bf66f020339fb3d3727aa96869790a2c4de4b8e09915eb07f**, original_result `{:error,:invalid_group_accounting}`, ssl_nil_only_result `:ok`, limits_unchanged true,38 metadata entries, actual owner same_ssl/same_gate true, and actual VM root `.7`/ssl11.6.0.6. Here E is `docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089`. Diagnostic2 exited1 because the unchanged browser still failed; capture is diagnosis, not acceptance. Diagnostic1's failed tuple-wrapper evidence remains preserved. Proposal1's statement that cause attribution is still unconfirmed predates diagnostic2 and should be updated in its successor without editing historical proposal1.

## Source reconstruction and required follow-up

Python standard-library source processing reconstructed the unified patch **in memory only**, asserting exact context and old/new hunk counts; all four current before and proposed after SHA256 values matched proposal JSON:

| Proposed target | Proposed after SHA256 |
| --- | --- |
| apps/gaoxy_http/lib/gaoxy/http/exchange.ex | 513c300e4b3a161d54465696663eaa024acc7061c87aa43f961c42ea54de5652 |
| apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex | 5696219cf250cada82badd531d1f28869b3a4145b78dc7ec43af956d7f765400 |
| apps/gaoxy_proxy/test/managed_h2_group_accounting_test.exs | 300e315d2d37ee927fe6eb2b7c1f210183ce83ec11aa118fc7059f8b87d586a1 |
| apps/gaoxy_proxy/test/managed_h2_group_native_tls_ownership_test.exs | bee3be78b40e51154bf6cf6ccd1d65ab498d77d98a0e46de18e1509bdf3e664c |

Required follow-up: review proposal2 delta for both findings, then parent adoption on matching sources, scoped formatting and strict compilation, nonzero actual regression runs, H1/H2/H3 compatibility, group live/Session and unchanged three browser cases. No existing failing/unexecuted gate is marked passing here. Parent reported startup50 passed and live110+Session46 still running3912 at dispatch; those are parent-owned separate gates, not this patch validation.

Only these two new authorized `/tmp` review artifacts were written. All commands finished. Zero reviewer repair rounds added; parent failedGREEN18/rootrepair20 and separate diagnostic failure1 retained; Astra2/2 exhausted unchanged. Historical negative TLS cleanup remains `UNCONFIRMED_WITH_RETAINED_FAILURE`. No new external decision or permission required; runtime acceptance and pending test repair remain parent-owned.
