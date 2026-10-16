# Browser-stop CODE1

Task `gaoxy-group-generation-browser-stop-code1`: **DONE — PASS bounded code review only.** No actionable findings. Direct independent read-only review after exact SPEC1 PASS; no runtime/full-stage acceptance.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; branch `codex/m3-h1-resource-foundation`; parent-confirmed unchanged baseline `8131af39a846c292a022ccbfd32c53376cd57887`. ProposalSHA `679e0e18ef48467a93a1cf8884fdf97712fbaa13447258c07113dd6138e9a8d7`; host4 `cf96df4fc521afbcd6308fb5e045fadbb32850bce8f36c464e91593bb45b93a6`; runner4 `ce0f8c353fa1630b627afae44e6bdd6be67a9e835c2bc7b3b616707a7f199427`.

## Exact bounded delta

Host4 equals immutable host3 with exactly one added line after existing successful Gaoxy.stop(instance,10000): :ok=GenServer.stop(s.groups,:normal,5000). Runner4 equals immutable runner3 except HOST filename3->4. All other bytes unchanged; no production/test/cohort/collector changes.

## Owned finite normal stop

Host starts groups directly1039 and monitors it1040; UpstreamGroups218-225 direct GenServer.start_link links to caller, init443-461 only monitors instance; instance DOWN802-812 returns noreply/draining rather than owner termination. Existing socket embedding1632-1633 explicitly stops owner after Gaoxy.stop. New unconditional supported5000ms stop at1979 owns this fixture-created process, returns :ok only on actual success; unexpected dead owner/stop failure still fails. No Process.alive/default/grace/alternative reason/error rescue bypass.

## Original monitor custody retained

Original groups_monitor still maps exact PID/role:group_owner/reason:normal1174. Same join_roles1980 invokes unchanged join_tracked1296-1308; exact original ref/PID/reason remains mandatory and5000ms deadline unchanged. mark_joined1290-1293 still requires actual dead process. No replacement monitor, flush/demonitor, synthetic DOWN or PID-dead-only substitute introduced. Existing genuine joined state contract remains unchanged.

## Cleanup before stop and original terminal after

Original Store stop1939, T allzero1941-1956, group/pins/tokens/probes/config/control/probe bytes allzero1959-1967, custodian exact joins1969, owner debug hook removal/trace disabling1971-1974 and diagnostics off1976 precede instance/group stops. Original transport/group/instance exact joins,rebind1981 and loaded before===after1983 must pass before stopped emitted. No cleanup assumption replaces those gates.

## All original acceptance contracts retained

Exact full-source diff proves native95/independent actual P/N/W/B,512MiB limits, source/baseline/selected child/completion/Gate0/failednil/nativecohort/observer, finite deadlines and all assertions unchanged. Runner path-only diff preserves four H1/H2×h2c/TLS rows,old/new exact200/DOM/title/URL/visibility/console/two screenshots each,Chrome graceful exit0,exact physical peer totals/forced0 and all Actor/readers/groups/adopted joins. Preservation does not mean new execution passes.

## Active source identity and inventory4

Runner4 HOST resolves host4; unchanged runner inventory includes actual HOST/current runner/cohort/peer. Host fixture identity986-1009 dynamically checks Path.expand(__ENV__.file),source bytes/loaded_md5; production source/beam checks unchanged. Inventory4 format targets absolute host4/cohort1; syntax targets runner4 plus collectors/regression and extracts literal BROWSER hashes; initial browsergreen4 and finalbrowserfinal1 invoke runner4 via collector3, distinct untouched receipt/run paths. No stale host3/runner3 reference in inventory4. Syntax/browser remain NOT RUN.

## Historical failures and scoped initial evidence

Frozen green3 classification remains FAIL: only row1 partial navigation/completion/request_clean/nativecohort/Gate0/Chrome0 succeeded,hostexit1/fourpeerforcedTERM violate original fixture gates; exact final group PID liveness/unmatched terminal reason UNKNOWN. Earlier diagnostic1 rejected input/green2 cause UNKNOWN preserved. Bound initial4 classification records93/0/exit0/no warnings/skips/exclusions/stable HTTPdd04/teste805; scope is initial tests only and cannot qualify new browser/full stage.

## Manifest rebind and execution order

All21 declared inputs+proposal+exact SPEC1 pair match before/after=24 frozen identities/no drift. Bounded SPEC->this CODE,then active Python/embeddedJS syntax,new browsergreen4 four rows/eight actual root views,full-stage SPEC->CODE,all fresh inventory4 final gates and document/index/blob review/local commit remain required. No future result inferred.

## Verification and shutdown

Every own scoped read/hash/exactdiff/path check exited0. All24 frozen input pairs matched; full manifests in JSON. Tests0; no syntax/build/runtime/browser/Git/network/agents/repository writes. Only assigned /tmp MD/JSON written. All own commands completed synchronously with no background process/session.

Received cumulative counters preserved: group52/root107/orchestration36; stagefailed7/production2/fixture10/stageorchestration29/invalidRED1/validRED1; Astra2/2 exhausted,own repair rounds0. No reset/escalation or new user decision needed. Initial scoped93 PASS is separate evidence; fresh browser4x2/full-stage/final gates remain pending.
