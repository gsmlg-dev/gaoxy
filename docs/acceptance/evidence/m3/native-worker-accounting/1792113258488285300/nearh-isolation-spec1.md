# Near-H constructor isolation SPEC1

PASS. Task `/root/native_worker_constructor_spec`; direct bounded independent SPEC analysis of the actual narrow test-only patch.

Repository: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Baseline from archived native-green3: `58307a7084298db309a93697b9102b2cc4c87eda` on `codex/m3-h1-resource-foundation`; no Git commands run by reviewer. Actual test SHA256: `cf83fe8f9b4e5e79292a8c7679d2abd30c9c79059801b3e42281fb85ce4dadd7`. Reversing exactly the five inspected text changes reconstructs pre-edit SHA256 `6510bed801ef21e7d0b30d169ab821074ca623e5a13005611ef02c0088edf4ef`; other test content, including strict peer sends/joins and original manifest/pin proof, is unchanged. Relevant production hashes are bound in companion JSON.

The supported public owner option `probe_bytes: 1` isolates unrelated health traffic for this no-dispatch constructor case. `Options.owner/1` accepts positive1; H1 reservation has a 7,225,384-byte constant base before chunk/ETF additions. `launch_h1_probe` checks the full reservation before starting a Probe child or opening a connection. Applying the allowance at owner creation excludes probes from both sample-release and final-release races. Public preparations and genuine H1 pin constructors do not require health success. The test still exercises real constructor and admission paths.

Actual patch preservation:

- Only near-H opts into fixture(probe_bytes: 1); every default caller retains the existing 67_108_864-byte allowance.
- Real normalized owner allowance1 is asserted immediately; public owner-wide probes0 and used probe_bytes0 are asserted after the 64 genuine handles and baseline exist and again before stop_store.
- All 32 real transport preparations, sample preparation/release, 64 real group preparations, public validations, exact E(handles)==H, G7/T8 identities/correlation and ETF algebra remain.
- Singleton above Q, preflight-cons rejection, original cancellation/status cleanup, unchanged generation/router and no-dispatch proof remain.
- Shared serve_peer, complete response sends, monitored worker completion/strict joins, normal DOWNs and real zero-resource teardown remain byte-identical.
- Actual native health/dispatch cases keep default fixture behavior. This constructor-only profile does not claim health/dispatch coverage.
- Preserve native-green3 FAIL; independent implementation CODE review and fresh runtime gate are still required.

Source evidence: `upstream_groups/options.ex:88-105`; `http_fetch_client.ex:12-14,29-35`; `upstream_groups.ex:470-530,654-679,900-928,1056-1077,1145-1200`. Public status counts actual owner-wide probes and used bytes, while normalized owner limits assert configured allowance1. This is valid test scope isolation without weakened assertions or hidden skips. A complete-response barrier is unnecessary here. If actual health traffic were required, a barrier would need to join complete HEAD response and prevent a new launch before retirement; a zero-probe poll alone races.

Immutable native-green3 remains FAIL:91 executed/1 failure, zero skipped/excluded, exit2, joined/source-stable. Strict peer join failed after an in-flight HEAD response send returned `{:error, :closed}`; retirement legitimately cancels probes. Receipt SHA256 `a2e239fc18f0ef0e53b2db4f16f18fab03c82701f3a96009a68e4271ae07d8ed`.

Verification: source reads, exact text reverse/hash comparison and receipt parsing only. No tests, runtime, builds, formatter, network or Git commands. No repository or archived evidence edits. Only assigned two `/tmp` reports written; all reviewer commands finished and no background processes started.

Counters unchanged: effective group35/root40/stage failedGREEN5/Astra2of2 exhausted; review adds0 repairs. No design decision or escalation. Independent CODE review and fresh prescribed runtime evidence remain required; SPEC PASS is not repaired runtime acceptance.
