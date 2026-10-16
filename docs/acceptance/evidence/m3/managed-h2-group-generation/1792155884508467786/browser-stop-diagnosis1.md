# gaoxy-group-generation-browser-stop-diagnosis1

**DONE — source-confirmed fixture stop omission.** Actual failed group owner's final liveness/terminal reason remains UNKNOWN. Diagnosis only; browser-green3 stays FAIL.

Direct read-only assignment; /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation; branch codex/m3-h1-resource-foundation; baseline 8131af39a846c292a022ccbfd32c53376cd57887. No Git command run. Systematic-debugging skill used for source/evidence tracing; no reproduction/repair authorized.

## D1: fixture waits for an owner it never stops

Host3 starts UpstreamGroups directly (1039), monitors it (1040), and saves the original ref/PID with exact :normal expectation (1174). finish verifies empty owner ledgers and custodian joins, then calls only Gaoxy.stop(instance,10000) at1978 before joining the group owner at1979.

UpstreamGroups starts as an ordinary GenServer linked to the host (218–226). init443–464 monitors the instance and schedules probes, without registering lifecycle participation. Its instance DOWN handler802–812 cancels live operations then returns {:noreply,mode:draining}. It does not terminate; recurring probe/catchall callbacks also retain the process. The transport owner separately registers for lifecycle drain and has an explicit normal stop condition. The existing scoped test environment1631–1633 explicitly stops its separately owned group process after Gaoxy.stop, which is the missing ownership step here.

This is a definite source-level omission and sufficient explanation on the normal path. Recorded host output does not expose final group PID liveness or an unmatched DOWN reason, so those runtime facts remain UNKNOWN.

## Monitor custody answer

No examined source path discards the registered group-owner normal DOWN. track1272–1287 preserves the authentic monitor; mark_joined1290–1294 saves joined state only after confirming the actor is dead. The actual helper is mark_joined; mark_actor_down is absent. Main loop1757–1760 fetches exact ref, asserts PID/reason and records it. join_tracked1296–1310 consumes only original ref/PID/exact reason, or checks a previously recorded terminal. An unexpected reason would remain unmatched and time out; it is not accepted.

Other host receives guard their own Probe/Session/custodian/observer monitor refs. stop_join2396–2404 only consumes its own fresh ref. Gaoxy.stop48–66 uses/flushed only a fresh private instance monitor. Lifecycle.collect has a broad receive but runs in Instance.operation's spawned coordinator, not this host process. No generic host DOWN drain was found. Normal EXIT and trace receive clauses cannot match DOWN tuples.

## Minimal recommended repair

After successful Gaoxy.stop and before existing owner/instance join_roles, explicitly request:

```elixir
:ok = GenServer.stop(s.groups, :normal, 5_000)
```

Keep the original groups_monitor registered and let existing join_roles consume its exact normal terminal. Keep all earlier empty-ledger/Gate/nativecohort/completion/peer-closed assertions. Do not substitute a new monitor, flush the original, widen reasons, or accept only PID-dead state. This fixture-owned stop needs no production lifecycle/API change. Root should independently review the bounded versioned fixture diff and rerun the required fresh browser matrix, retaining exact normal joins and finite deadlines.

## Actual recorded results

- browser.log2–5: old/new probes have exactDOM/title/URL, visibletrue, status200/protocolh2; Chrome closes code0/signalnull and browser joins passedtrue.
- host.log45/47/85–88: both original completions and request_clean; final nativecohort authenticated peer_closed/normal terminals and Gateactive0/retained0/cleanup0/failednil.
- host.log89–92: RuntimeError original actor exact terminal missing :group_owner at join_tracked1308/finish1979. No stopped/exited event.
- qualification: FAIL,executed1,source_stabletrue,elapsed22918ms. Browserexit0,hostexit1;four peers forcedTERM/-15;all6 readers/ownedgroups joined/gone,adopted_remaining[]. Outer cleanup success does not satisfy host graceful-stop acceptance.
- Parent reports only2 screenshots viewed; reviewer did not view images. No full4row/8image acceptance. Historical green2/browserdiag1 causes remain UNKNOWN.

## Complete input hashes

All10 inputs unchanged. Six supporting sources were first hashed after initial bounded reads then rechecked; host/evidence/browser log captured before inspection/parsing.

| Input | Before SHA256 | After SHA256 |
| --- | --- | --- |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-green3/h2-h2c/host.log | eab74ec8e5af3b9c2fe8c44115bc4101d7abd396569ddc4e9f07c01df5a23ed3 | eab74ec8e5af3b9c2fe8c44115bc4101d7abd396569ddc4e9f07c01df5a23ed3 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-green3/qualification.json | 1bf70fe99997b439f129a43cfe8f80f1f2ff5da2e0726e5fa187c974e1596204 | 1bf70fe99997b439f129a43cfe8f80f1f2ff5da2e0726e5fa187c974e1596204 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/group-generation-browser-host3.exs | a3dd5731a954f509ed724fa77910eb9ab377466f0c03d7434cf3444997eb51a4 | a3dd5731a954f509ed724fa77910eb9ab377466f0c03d7434cf3444997eb51a4 |
| apps/gaoxy/lib/gaoxy.ex | f996f20926086b80f79aa66c82253164430616ffac15118f87bd8a88bc00fa5e | f996f20926086b80f79aa66c82253164430616ffac15118f87bd8a88bc00fa5e |
| apps/gaoxy/lib/gaoxy/instance.ex | 510bcf614c5a289fbd6c454693930b68c09bd9bdd8510a547e458cca54838dcf | 510bcf614c5a289fbd6c454693930b68c09bd9bdd8510a547e458cca54838dcf |
| apps/gaoxy/lib/gaoxy/lifecycle.ex | 7f673e89f59b41af72057ce1afa553fa6c62e56125b450e6d09e58da0a434f75 | 7f673e89f59b41af72057ce1afa553fa6c62e56125b450e6d09e58da0a434f75 |
| apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex | e98dea5d0769258838c0c53b397da4740d0b6f303c02d1c13cf712cb32a645c9 | e98dea5d0769258838c0c53b397da4740d0b6f303c02d1c13cf712cb32a645c9 |
| apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex | 877bb6e4c891ee3f8c93a425a67b10f390137fcead2eeb52ccd9b78d9b2b1f51 | 877bb6e4c891ee3f8c93a425a67b10f390137fcead2eeb52ccd9b78d9b2b1f51 |
| apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs | e80503bb68521d29fa3423a3c93c9059598d0602eec1858cd1c751aba759a2fa | e80503bb68521d29fa3423a3c93c9059598d0602eec1858cd1c751aba759a2fa |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-green3/h2-h2c/browser.log | 4f4714a5a2c5552c7a8997aed205ccd9654996c414c48f6c2b0fde01609c8185 | 4f4714a5a2c5552c7a8997aed205ccd9654996c414c48f6c2b0fde01609c8185 |

## Counters and shutdown

Received cumulative counters: group52/root106/stagefailed7/orchestration35/stageorchestration28/production2/fixture9/invalidRED1/Astra2of2. Reviewer repair rounds0; no reset or implementation performed.

Only assigned /tmp MD/JSON reports written. All own source/hash/log commands exited0 and finished synchronously. No runtime/build/tests/browser/Git/network/agents/repository/evidence writes or live sessions/processes. No full-stage/Task5/M3/release/deployment acceptance. Root owns any repair, review and new verification; no product decision needed.
