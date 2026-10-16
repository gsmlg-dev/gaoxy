# fixed_h2_generation_failure_draft1 — source-only handoff

Status: DONE for the assigned source proposal/report deliverable; runtime acceptance NOT RUN.
Assignment: direct, bounded proposal only. No repository, Git, build, browser,
network, test, or dependency mutations; no subdelegation. Root remains sole
repository/runtime/evidence/Git owner. All tool commands finished synchronously.

Repository: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`.
Baseline supplied by root: `aa272c3dca700a9275a00bd23920d09bbd4748a1`.
This is an actively edited root worktree; the hashes below bind observed source
bytes, not a frozen Git tree or loaded runtime. Root's fixture changed while this
proposal was being drafted. No claim of runtime source stability is made.

## Deliverable

`/tmp/gaoxy-fixed-h2-generation-failure-draft1.txt` contains 572 lines of
executable-shaped Elixir snippets, not a complete module. Insert inside the
root's `Gaoxy.Proxy.ManagedH2FixedGenerationTest`; it depends on the actual staged
primary helpers. Both upstream protocols iterate with native downstream H1;
root's primary tests own the four H1/H2 x h2c/TLS-H2 positive CAS cells.

Proposed 26 tests, all NOT RUN:

| Cells per protocol | Proposed contract |
| --- | --- |
| 1 stale CAS | `:stale_generation`, active snapshot/baseline identical, rejected real preparation/custodian joined, active peer1/request1, rejected peer0/request0 |
| 3 candidate failures | Real preparation precedes `:invalid_route_path`, explicit abandonment, or actual coordinator `:kill`/`:killed`; only candidate retires; active still serves |
| 1 Store death | Actual Store normal DOWN, authentic captured T8 survives closed admission, fresh native500 performs no owner effect, old original completion succeeds, custodian and peer physically join |
| 1 delegation cancellation | Hold exact original owner callback with authentic Store T8; cancel actual Session; owner returns exact `{:error,{:deadline_exceeded,:cleanup_pending}}`; same native operation cancellation observed; no child/token/checkout/bind/peer request |
| 3 identity mismatches | Genuine prepared T4 paired with canonical opposite protocol/scheme, other authority, or real other Gaoxy instance; exact `:transport_endpoint_mismatch` from original delegation; no checkout/bind/Fetch |
| 3 source negatives | Corrupt a copy of genuine Store T8 after capture: nonempty no selected T4 using another genuine prepared T4; forged ref; wrong holder; authentic owner source remains byte-identical |
| 1 late stop | Real original completion held by pending body delivery; exact public short-stop failure; original Session cancellation/owner drain/instance completion barriers; eventual original completion, token/pin settlement, physical termination and real joins; same failed retirement receipt retained |

Each proposal uses `F.peer/2`, real `Transports.prepare/4`, actual Store
`Generation.prepare/activate` and checked native capture. No `F.fixture`, manual
request-pin acquisition, synthetic original completion, simulated peer, or
dependency/private Fetch process lookup occurs. FailureFixed forwards `init`,
`resources`, and `generation_validate` on the initialized ProxyHTTP config.
Its capture message contains the unchanged original Exchange before deliberate
negative mutation. Endpoint result is returned unchanged after the same finite
barrier family as primary. Actual wrapper config/Exchange bytes must enter
root's independently calculated native W/B accounting; no guessed W is supplied.

## Source-traced exact contracts

- `http.ex:278-289,300-329`: captured-shape refusal503 for nonempty missing
  matching handle or wrong holder; shaped forged ref reaches delegation, owner
  refuses `:invalid_resource_pin`, normal managed failure response502.
- `upstream_transports.ex:348-376`: delegation checks exact authenticated source,
  immutable authority/protocol/instance, then live guardian/deadline before
  deriving child. A guardian already DOWN at withheld original input returns
  `pending()`; `pending/0` at1682 is exactly
  `{:error,{:deadline_exceeded,:cleanup_pending}}`.
- `upstream_transports.ex:631-638`: cancellation removes pins by original
  acquirer and operation. Proposal correlates actual `:cancel_pins` to the
  operation seen at the withheld original delegation, not an invented op.
- `upstream_transports.ex:1010-1050`: genuine but wrong caller would be
  `:unauthorized`; a mutated holder/ref is not an authentic source right. The
  proposed wrong-holder test is explicitly a negative copied-envelope mutation,
  refused by ProxyHTTP shape before any owner effect. Do not label it an
  authentic wrong-caller delegation test.
- `generation.ex:517-533`: stale CAS compares expected before baseline pinning;
  current Store snapshot remains unchanged. `request/3:408-414` maps a dead
  Store call to `:generation_unavailable`.
- `router.ex:110-126,139-152`: route `path: :invalid` returns
  `{:error,:invalid_route_path}`. The invalid cell first performs actual
  transport preparation and valid Generation preparation, then asks the same
  real coordinator to prepare this invalid route; cleanup is holder-correct.
- `http/session.ex:1625-1658`: fixed managed captured selection notifies the
  native holder with original handoff, identity and opening deadline; no
  standalone `validate_endpoint/pin_many` route is substituted.
- `http.ex:944-991`: original native pump performs delegation and revokes on
  cancelled Session; `fail/2`502 and `error_response/2` return close:true on
  refused binding/source. Proposal reads actual downstream response and exact
  wrapper return before releasing original source pin.
- `upstream_transport_generation_test.exs:708-776,1092-1182,1881-1909,1950-2030`:
  causal cancellation, finite late original cleanup, owner lifecycle drain,
  and instance completion barriers. Late case retains exact failure after
  successful original completion; its finalizer expects the already stopped
  embedding's `{:error,:not_running}`, never pretends the first stop passed.
- `managed_h2_fixed_lifecycle_test.exs:868-898`: real fixed-H2 original handoff
  cancelled before owner release is a supported existing lifecycle pattern.
  Its standalone/manual-pin fixture is not copied into Generation acceptance.
- `managed_h2_fixed_endpoint_test.exs:10-155,314-370,564-641`: independent peer
  public command/event interface, exact final peer counts, Python exit0 and
  collector normal join. Late body commands use the real peer's supported
  respond/data `ended:false` protocol.
- `service.ex:578-618`: forced short drain preserves cleanup ownership and
  `finish_drain` returns `{:stop,:normal,...}` only after genuine native-resource
  and cleanup completion. This supports the late Service normal-DOWN assertion.

## Explicit seams / integration obligations

1. All code is source-only. Parser, formatter, compiler, runtime, ExUnit count,
   determinism, actual owner replies, stop ordering, and complete joins are NOT
   RUN. Root must review then insert and execute under its serialized runtime
   ownership. No passing behavioral gate follows from this draft.
2. Empty `resource_pins == []` intentionally enters standalone `call_fixed/3`
   with fresh outer acquisition. Do not claim empty-array refusal. Missing in
   this draft means a NONEMPTY copied captured envelope with no selected T4.
   Genuine checked Store does not delete captured pins. Root acknowledged this
   distinction and reports design/plan clarified accordingly.
3. FailureFixed stores additional mutation terms in its initialized endpoint;
   the real primary capture helper independently derives B from actual Exchange
   retained bytes. Root must preserve all constructor/byte assertions and let
   actual native initialization measure this wrapper; no W constant can be
   copied from another wrapper.
4. Late failure deliberately kills native under forced stop and Service/Gate
   resource shutdown occurs before eventual public stop completion. Its ordinary
   `Gaoxy.status(...,:http)` zero check is unavailable after Service exits, so
   the late finalizer uses actual Service/native/owner/instance/custodian joins,
   owner-all-zero while still inspectable, physical peer termination and port
   rebind. If the prescribed failure acceptance also requires observation of the
   original Gate's terminal ledger before its forced death, add a separately
   source-bound Gate observer at the real terminal callback; do not invent a
   Gate0 status from an unavailable process. This extra observation is not in
   this draft and remains an explicit runtime/integration seam.
5. Other live Gaoxy instance in the mismatch negative is test-owned and joined
   with its own normal monitor; it is deliberately real instead of relabelling
   an arbitrary PID as an instance.
6. Primary helper draft's old guarded `refute_receive` line was stale after root
   fixed the actual staged source. This proposal uses the actual helper API,
   adds no copy of that stale assertion, and does not weaken source custody.
7. Plain forged/wrong-holder copied envelopes are intentionally not described
   as authentic Store output. Source acceptance remains the original observed
   T8, exact Store acquirer, native holder, matching operation and owner ledger.

## Observed hashes

SHA256, captured by read-only `sha256sum` (all exit0):

| Artifact | SHA256 |
| --- | --- |
| failure draft txt | `0e6bdad4cfa9a6e1168f0796532c0c1b88296cffca28e0c766943a20925a75c1` |
| root staged fixed-generation test, last observation | `f9ad4d7cc621f649d7fc61ea4c77027d509559197dbc3454d7d11348b2dd73a4` |
| primary tmp draft, earlier observation | `81021b50f902e3043c2aaa85e84c818e60d5f7b4e9726097c3e60f6f22baacfa` |
| AGENTS.md | `73b78c7642c2a38061aa23a36d4ffc2014e97ba7129766fbdb0d10f7e5fde9d4` |
| matching design | `44992f92facc36ecac0f7b7f8b9a463061ac39c629a9ada72e85bcc88b16dc1e` |
| matching plan | `96865d660780324ffe2ce9856798b819c08e8f88d46b65d46a1ef9595e8946ff` |
| ProxyHTTP source | `f567cdb779b3be580c3638ae6a10e1b854079a767d61bafbaa3befa1b3ce42ff` |
| Session source | `8a041a6bc217ef5ec626dc9e4efc2ec495db3a668912214420ad01bd4d449eac` |
| transport owner source | `877bb6e4c891ee3f8c93a425a67b10f390137fcead2eeb52ccd9b78d9b2b1f51` |
| Generation source | `4eeaa5bb6bcc65d181cec52a7fbcd9344c7d327746ef9ec8a10cec0a3cb7630c` |
| Router source | `513db9910d6f0beabf1038db8bc1539ee5c5e8731ace0f6d349b9f2f2db96abd` |
| H1 Generation tests | `63c521979cee9ecea809c1bf78e00e121f97e7b7a65d416d70cf5b620a84b9f4` |
| fixed lifecycle tests | `31b58d5187ba76a5d20abcb5bba83718d773b8e670a71bf79a381c041ba5a416` |
| fixed release-order tests | `51a72d2f78481d27a000111543276fdd6211b5212d24f051af55db2ee724eddb` |
| fixed endpoint/peer fixture source | `e89adb9c7cefa1c64385e9a90962ece819d7dfb492807b42e7b77644f042c33a` |

## Verification and counters

Executed: scoped source reads/searches, own `/tmp` apply_patch writes,
`sha256sum`, and `wc -l`; all completed. An initial guessed path search returned
missing files and was corrected from `rg --files`; one literal-brace regex was
invalid and corrected with separate escaped patterns. These were source lookup
errors, not attempted implementation/runtime repair rounds.

NOT RUN: proposal parsing, formatter, compile, tests, browsers, networking,
builds, Git commands or mutation. No test/build/browser/application process was
launched by this worker. No background command remains.

Latest parent-reported cutoff: group43/root58/Astra2of2 exhausted;
newstage failedGREEN2/fixtureRepair1/productionRepair0/orchestrationRepair1.
Earlier parent-reported root boundary47/0 was NONACCEPTED because source changed
under formatter overlap. Later root fixture compile failure was not relabelled
expected RED; root retained historical evidence and repaired only guarded
`refute_receive` syntax. These are parent messages, not this worker's runtime
observations. Delegate Sol repair rounds:0; received Astra recovery count:2/2.
No escalation; astra_gate not applicable. No external permission or product
decision requested. Root needs the source/risk review and execution described
above; the explicit Gate terminal-ledger seam remains unimplemented in proposal.
