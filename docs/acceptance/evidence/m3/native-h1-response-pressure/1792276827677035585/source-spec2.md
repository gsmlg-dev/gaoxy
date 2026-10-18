# Native H1 pressure source SPEC2

Verdict: FAIL. Status: DONE; read-only delta review. Sole finding SOURCE-SPEC2-01.

Candidate2 `309987ae5a7f5cc4f1cd62779a77de18b9ada23f16207a57f3fd98a0a430359f`; test `75188f14ab8fa49c36ea5a896d28bc1711cb38f099ef3e7465a1040c6f0dca7f`. Baseline `68476956a03e3b2b219bb2ecc5ab60fadc4e27f96898f020b0ef9b95c7704ec1`.

Finding: `apps/gaoxy_proxy/test/upstream_transport_native_h1_pressure_test.exs:1254`. Failure chronology performs fresh synchronous Process.info(pid, [:status, :current_stacktrace]) on up to4 owned native/client actors before failure_cleanup, outside existing monitored observer machinery and without finite observation deadline/normal join. Count/output bounds do not establish finite observation lifetime. No actual diagnostic hang is claimed.

diagnosis1 controller-catch step permits only already-generated bounded records and says Do not block waiting for new observations. SourceSPEC1 finite-observer discipline remains applicable.

Root accepted removal of fresh Process.info calls: retain already-captured records and owned identity hashes only; add no observer or failure budget. Original EINVAL/stack, failure_cleanup and every acceptance assertion remain unchanged.

All pins PASS404source/2owned/11documents/12dependencies/69evidence; all8 exact baseline preservation checks PASS.

Original assertion lines, success receipt, failure_cleanup, deadline functions, allowlist, numeric bounds and exactly1 test/no selectors remain unchanged. Socket.getstat non-ok still fails the original match, never becomes0/retry/success. Added phases10 sites/output16, last snapshot1, queued packets32, output events64, owned actors4, diagnostic MFA16, tuple depth3/members8; binary reasons expose byte count only.

Initial actual1 EINVAL remains FAIL, root cause UNKNOWN. Candidate2 is diagnostic precursor to actual1 rerun, not fix, pressure acceptance, full4 or dependency defect. All69 evidence pins pass.

Runtime/compile/formatter/tests/browser/Git NOT RUN. Counter9 retained: initial runtimefail1, diagnosticround1, implementationrepair0, Astra2/2 exhausted; review adds0 runtime/repair rounds.

New tooling incidents2: oversized source projection; overbroad local deadline comparison corrected to exact function bodies. Both reported to root; no clipping or protected data reads. Prior incidents not recounted.

Candidate2 sourceSPEC FAIL. Root accepted sole finding, will archive candidate2, remove synchronous actor observations, freeze candidate3 and request fresh delta review. No runtime or CODE review of failed candidate2.

All reviewer commands finished; no runtime processes started. Only requested /tmp reports written.

Repository/docs/evidence/runtime/Git custody returned to /root; preserve other agents work.

