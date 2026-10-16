# Browser group owner stop diagnosis1

Task `gaoxy-group-generation-browser-stop-owner-diagnosis1`: **DONE — group-owner lifetime mismatch confirmed; explicit finite normal stop recommended.** Direct read-only source diagnosis, no implementation/runtime/full-stage PASS.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; branch `codex/m3-h1-resource-foundation`; baseline `8131af39a846c292a022ccbfd32c53376cd57887` parent-confirmed.

## Actual failing boundary

Both old/new actual browser200/h2 DOM/title/URL probes, completion and request_clean succeeded; Chrome gracefulclose/join exit0; host closed_browser_clean shows original native cohort/observer joins and Gateactive0/retained0/cleanup0/failednil. Full row still FAIL: stopped/rebind/final joins not reached, hostexit1 and four peer actors forcedTERM/-15. Hostlog89 reports exact missing group_owner terminal at1308/1979. No runtime owner-alive-at-timeout snapshot is recorded here. Missing exact DOWN alone is not an independent liveness measurement; source proves omitted stop and no automatic normal owner exit contract.

## Owner contract and missing operation

- `upstream_groups.ex215-225`: child_spec restarttemporary; start_link is direct GenServer.start_link, linking owner to calling browser host, not to instance/supervisor child ownership.
- `upstream_groups.ex443-461`: Owner init stores instance monitor and ready/empty ledgers. It does not register Gaoxy lifecycle participant and exposes no owner-specific stop API or terminate callback.
- `upstream_groups.ex802-812`: Instance DOWN cancels live selections/probes then returns noreply mode:draining; it does not terminate even when all ledgers are empty.
- `upstream_groups.ex773-775/1069-1080`: Probe tick continues normal noreply scheduling; draining launch is inert. Final group removal only deletes group key/subtracts bytes. No idle/allzero owner auto-stop exists.
- `upstream_transports.ex217-239/497-502/667-680 and gaoxy.ex47-58`: Transport owner is deliberately different: registers lifecycle participant, tracks instance_down, and stops normal when instance down and records/tokens empty. Gaoxy.stop covers registered participants; group owner cannot inherit transport lifecycle.
- `browser-host3.exs1039-1040/1174/1939-1979`: Host starts/monitors group owner expecting exact normal. finish stops Store, proves T/group allzero, joins custodians/removes hooks, then only Gaoxy.stop(instance), followed by original group-owner join. No explicit groups stop occurs.
- `managed_h2_group_generation_test.exs1631-1634/1730-1735`: Existing passing socket embedding owns a finite normal groups stop after Gaoxy.stop; finish then consumes original normal owner monitor. This demonstrates intended embedding responsibility.

## Minimal proposed repair

After existing `:ok = Gaoxy.stop(s.instance, 10_000)` and before unchanged original-owner `join_roles`, add `:ok = GenServer.stop(s.groups, :normal, 5_000)` in a reviewed versioned host successor. Allzero group/T and custodian joins/hook removal already precede this location. Host owns the independently started owner, so the finite supported stop owns termination. Retain the original `groups_monitor`, exact PID/:normal join and all existing deadlines/assertions/rebind gates. `stop_join(s.groups)` is possible but adds another monitor and cannot replace the original tracked join. No production/API/lifecycle change or relaxed terminal acceptance is justified. Proposal only, not implemented or run.

## Verification and limits

Seven relevant current source digests match actualrun before/after, host/browser digests match immutable artifact receipts, qualification matches outer receipt. HTTPdd04...c31/teste805...a2fa remain unchanged. Complete11 input hashes appear in JSON. Tests0; no runtime/build/browser/Git/network/agent operations or repository writes. Only assigned /tmp reports written. One initial scoped rg pattern returned regex parse error2 (unescaped `{`); recovered searches exited0, parent notified without inventing counters. All commands completed synchronously; no own session/background child remains.

Received counters preserved: group52/root106/orchestration35; stagefailed7/production2/fixture9/stageorchestration28/invalidRED1; Astra2/2, own repair rounds0. Mailbox handling remains the other reviewer's independent scope. Fresh versioned fixture review/browser4x2 and all final gates remain required. Historical unknown predicates/green2 cause and failedgreen3 evidence remain unchanged; no full-stage acceptance. No user product decision is needed for this bounded fixture correction.
