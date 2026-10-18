# Native H1 pressure diagnostic author1

DONE for diagnostic-only authoring; no runtime or acceptance claim. Root cause remains UNESTABLISHED.

Owned file: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/apps/gaoxy_proxy/test/upstream_transport_native_h1_pressure_test.exs`.
Entry SHA256: `68476956a03e3b2b219bb2ecc5ab60fadc4e27f96898f020b0ef9b95c7704ec1`.
Final SHA256: `e8bf2401c3dd785611110a6201ab829c54ab7be4020af682511569932a06a724`.
Delta: +138/-3 lines. No other repository files edited.

Adds 10 scalar phase markers, one retained existing pressure snapshot, failure-only getstat context and generation timestamps, and bounded failure JSON before original cleanup. Existing send-wait allowlist, assertion/refute lines, success receipt block and failure-cleanup block compare byte-identically to the recovered source. One fixed/TCP test remains. No timeout/body/buffer/production/fixture/dependency changes.

Bounds: 16 phase output entries (10 fixed call sites), one snapshot with existing64-frame assertion,32 queued packets,64 output events,4 client/native actors,16 MFA frames,3 reason tuple levels and8 tuple members. Clipping/limit flags are explicit. Binary reasons expose byte counts only; stack arguments and exception messages are excluded. Failure-only public `Process.info` reads status/current_stacktrace for owned native/client PIDs; no private dependency state or native-owner sys inspection. Original exception, existing badmatch and cleanup failures remain authoritative.

Exact1240-line baseline was recovered by deterministic reverse replacements and matched the required SHA before writing `/tmp/gaoxy-native-h1-pressure-before-diagnostic1.exs.txt`. Reverse script: `/tmp/gaoxy-native-h1-pressure-reverse-diagnostic1.py`. Exact delta: `/tmp/gaoxy-native-h1-pressure-diagnostic-author1.diff`.

Verification: Python byte/hash/custody and unchanged-block comparisons passed. Formatter, compiler, runtime/tests/probe, Git, source freeze and independent review NOT RUN; parent owns them. Risks: source remains uncompiled; unavailable diagnostic IO can omit diagnostics but cannot replace the caught failure; pre-binding native owners are not separately retained. DOWN timestamps are observation times, not death times.

One tooling incident: initial combined read output truncated; nested command exits0. Stopped/reported; parent explicitly resumed smaller reads. No additional runtime runs or Sol repair rounds. Inherited H1Sol4/Astra2of2 exhausted remain unchanged; astra_gate none. No new decisions requested. All synchronous commands finished; no owned runtime was started. Custody returned to root.
