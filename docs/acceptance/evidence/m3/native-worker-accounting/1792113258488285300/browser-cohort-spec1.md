# Actual browser complete-cohort SPEC1

Task ID: native_worker_constructor_spec / browser-cohort-actualSPEC1.
Assignment: direct, bounded independent SPEC review, read-only except these /tmp reports.
Status: DONE for review delivery; actual-source specification verdict **FAIL**. No fixture/runtime execution was authorized or performed. This source tuple must not be treated as browser qualification.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`.
Evidence root E: `docs/acceptance/evidence/m3/native-worker-accounting/1792113258488285300`.
Saved stage baseline is `58307a7084298db309a93697b9102b2cc4c87eda`; current Git HEAD/diff were not refreshed because the assignment prohibits Git. Other writers' work was preserved. Parent froze the reviewed tuple; all three source and three design/plan/acceptance hashes matched its manifest on review and final verification.

## Actionable findings

### F1 — HIGH: ordinary leases that end before a cut escape role/reservation validation

Frozen host4 `validate_cut/3:1256-1292` filters all acquisitions by sequence, then removes those with an authentic Gate DOWN before the cut. It validates role, writer-ready owner, acquisition bytes/options, and actual record fields only in `for a <- active`. Frozen helper1 `progress/1:435-443` likewise waits for identity/ready evidence only for acquisitions whose lease is present in that cut.

Frozen host4 `validate_terminals/2:1383-1412` does include every recorded acquisition PID, but its only classification of a non-native acquisition is the final `true -> reason == :normal` branch. It does not require that this PID sent h2_writer_ready to a proved native C, that its acquisition bytes match the independent writer reserve, or that its options/role are valid. Native acquisitions already gone likewise avoid acquisition-byte/options validation.

Concrete source counterexample, not executed: an unknown ordinary acquisition succeeds, ends normally, and its authentic Gate DOWN is processed before the first provider cut. No cut includes its lease in active. The final ledger contains its acquisition and genuine normal terminal, so validate_terminals accepts it as the nonconnection case despite no writer-ready/owner or reservation proof. Exact live map/sum equality does not catch it because the lease has already been removed.

This violates the design's independently authenticated lifetime ledger and explicit rejection of unknown/unproved roles. Repair by validating every-ever acquisition independently against a native-start identity or actual writer-ready→proved native-C identity and the configured independent reserve/options, regardless of current membership. Keep the sequence-filtered acquire-minus-authentic-DOWN live set and exact whole-map sums as a separate proof. Do not discard or exempt a short-lived actor.

### F2 — MEDIUM: the :all trace barrier does not prove delivery for dead writers

Frozen helper1 `progress/1:465` uses only `:trace.delivered(session, :all)` before replying with its ledger. Installed OTP28 `kernel-10.6.3.3/src/trace.erl:1259-1265` documents equivalence to erlang:trace_delivered within a session. Installed `erts-16.4.0.5/src/erlang.erl:6578-6616` states that :all denotes processes **currently** traced; an individual PID may refer to a previously existing/dead process, and its example calls the per-PID barrier after exit before closing the tracer.

A writer that has already died is not covered merely by the current-process :all barrier. Its prior ready/write/stop trace can therefore remain outside the guarantee when the final cut is returned and the session destroyed. Existing active-only ready waiting does not cure this for removed acquisitions (F1). This is a missing completeness guarantee, not evidence that a particular trace was lost in a run.

Repair with finite per-known-acquisition PID delivery barriers, including dead PIDs, and retain the exact returned PID/ref acknowledgment for every barrier before final ledger acceptance/session destruction. A missing required ready remains FAIL. Continue using VM-side safe message filters; no raw trace or broad SSL/system-state log is required.

### F3 — MEDIUM: final Gate zero is neither cohort quiescence nor an all-native join barrier

Frozen host4 stop phase `874-904` waits public Gate global zero, joins only the target worker/C/writer, then takes a single final snapshot and immediately calls validate_terminals. Native starts are monitored before handshake (`helper1:146-161`), so a pre-admission C can be alive without a Gate lease. Gate zero does not wait for that C or its observer DOWN. Its normal terminal may already be queued for the observer while the snapshot returns; helper1 own-DOWN handler `261-280` records the receipt but is not a prerequisite of snapshot progress. Immediate final validation can therefore fail for ordinary scheduling rather than a real cleanup failure.

There is also no listener/acceptor quiescence before the final native ledger is frozen and telemetry detached. An already accepted connection whose start callback is still pending can register after that snapshot, outside the validated final PID set. Chrome's real process join prevents future Chrome activity but is not itself an acceptor/connection-supervisor message barrier. Do not infer absence of such actors from Gate zero.

Repair by closing acceptance after the real Browser.close + successful Chrome join, retaining existing native actors untouched, then finitely waiting for supported backend connection enumeration to be empty AND all ever-known C/writer authentic terminal receipts. Only then perform per-PID trace-delivery completion, final exact status cut, all-ever identity validation, strict terminal reasons and observer normal join. This keeps the original guards/assertions.

Parent proposed public ThousandIsland.suspend(backend) followed by connection_pids(backend)=={:ok,[]} plus authentic receipts. Current dependency source supports that choice: public docs `thousand_island.ex:241-255` say suspension stops acceptance and preserves existing connections; `Server.suspend:31-35` suspends acceptors and terminates only shutdown_listener/listener; AcceptorSupervisor.suspend terminates :acceptor while keeping the earlier :connection_sup. Public connection_pids continues traversing those live connection supervisors. Require exact :ok, keep observation attached through the final barriers, and do not substitute Admission pause, Gaoxy.stop, kills or arbitrary terminal reasons. This proposed repair was not implemented/reviewed/executed by this reviewer; a new frozen tuple still needs SPEC then CODE.

## Preserved and sound source boundaries

- The documents explicitly call this a correction of unsupported global3/global2 topology, not a logical strengthening of the old equality or a retroactive historical pass. They retain original GREEN2 cause UNKNOWN and rejected diagnostics as failures.
- Original provider-owner debug input callbacks synchronously obtain their own Cohort.snapshot before each real pin effect. The caller's actual public Gate :status alias/reply is correlated with the SAME Gate callback output-State. Separate original cuts are validated; their global totals are not equated to a later cohort.
- Ordinary acquire input is observed before its real reply and enables the private safe trace session before writer-ready can be sent. Gate sequential debug events distinguish acquire and authentic ordinary monitor-DOWN before each cut. The independent connection/writer formulas use normalized source operands. Unknown current roles or unexplained current leases fail whole-key-set equality; F1 is specifically the missing lifetime validation of removed acquisitions.
- Target child, token, parent owner/lease, original request deadline, exact W+B and actual native stream linkage remain checked. NativeWorkerBrowserArithmetic is byte-for-byte identical to host3, SHA256 `44d137223cad0029709e94a1dc55ff1508b047d924c0e9bdc448ddb788bc14d4`; the 95-row/complete protocol retained accounting is preserved.
- G7/T8 exact public receipts, real Session-derived custody, cleanup attachment, target worker/Session normal joins, and target C/writer live AND unjoined guard at authorization remain present. Early target normal R death is still rejected. F1–F3 do not justify relaxing that guard or changing deadlines.
- H1 clean_target keeps the target present with bytes0 and validates the Gate record's original request_active/deadline. That matches Admission.retain, which clears timer/token and changes bytes without clearing request_active/deadline. A separate actual connection-state inspection requires idle phase, empty buffer and nil connection request deadline. These two distinct states are not incorrectly equated.
- Runner BROWSER JavaScript is byte-for-byte identical to runner4. It retains real Chrome TLS/ALPN h2, completed document, exact DOM, visible element, screenshot, explicit post-authorization Browser.close and actual graceful Chrome exit0. H1 is a separate required subsequent case, and aggregate PASS needs both actual cases and all clean process joins.
- Raw independent upstream peer retains bounded bodyless request framing, no transfer coding, single numeric-zero/absent content length, empty residual bytes at response barrier, strict complete response send, exact HEAD+GET rows and finite normal worker/thread joins. Forced cleanup remains failure.
- Projected Gate state uses strict fixed-field scalar schemas; VM send/receive filters exclude byte payloads, sockets, TLS/system-state replies, stack traces and spawn arguments. Bounded reason omission is explicit. The writer causal telemetry intentionally omits non-whitelisted complex errors, so absence of such a trace cannot establish historical cause. No unsafe diagnostic raw trace was read.

These are source checks, not runtime PASS. The actionable findings are sufficient to reject this tuple. No unrelated production/interface/dependency change is recommended.

## Frozen identity

| Source relative to E | SHA256 |
| --- | --- |
| native-worker-browser-host4.exs | 0b8320ff81ff1f8c05b3b358af8c25d5c8e6970b08a70d979e984f730fc26d9e |
| native-worker-browser-runner5.py | 0f926418a4cf1023308be064682babe9b5840284fe636b5b0af0cac2f701b37f |
| native-worker-browser-cohort1.exs | 09985d8f003dbe5d3757d183057518486584c986f4e8cd335cf655e63b106eab |

Design SHA256 e48819a032403cbfac35a5ebf9d90a3296964e98139e7d1e73286d418fe23b27; plan 761fa20651c436de0fd8848ddc1ec13306e55f9d90647b259a9be1fa650d86c4; acceptance d970f056b5b84cfcc17897f7f8e313001c76fb73b586ccbea761e0bdb91f6434. Exact paths are in source manifest and companion JSON.

Verification: bounded source reads/searches, Python hashes, source-literal AST extraction (without executing fixture code), and exact source segment comparison. All six frozen hashes matched. Two read-only exploratory globs did not match installed doc paths and one targeted source lookup named a nonexistent file; exact installed source files were subsequently located with rg --files and successfully read. These lookup errors were not runtime/repair attempts. No Mix/browser/test/Git/network command ran. No repository/evidence file changed. Only this Markdown and companion JSON were created. All own commands finished; no owned process remains running.

Counters received and preserved: group37/root48/stage7, Astra2of2 exhausted, nonaccepted diagnostic failures4. This assignment adds zero runtime attempts, zero Sol repair rounds, and zero Astra recoveries; no escalation gate. Parent owns the fresh repair tuple and all implementation/runtime/evidence/Git. No user decision or permission is needed for this report. Remaining acceptance risk: F1–F3 unresolved in the reviewed immutable tuple; complete H2/H1 runtime and CODE review NOT RUN by this reviewer.
