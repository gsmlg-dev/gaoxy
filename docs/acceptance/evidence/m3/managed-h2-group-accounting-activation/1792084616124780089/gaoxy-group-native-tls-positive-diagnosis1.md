# Native TLS positive-case diagnosis1 and repair proposal

Task `/root/group_postactivation_code/native_tls_positive_diagnosis1`: **DONE_DIAGNOSIS_PROPOSAL**, direct source-only assignment. The root-owned actual exception diagnostic confirms both positive cases fail because `Gaoxy.PlugAdapter` is unloaded at Plug's first optional SSL callback probe. A one-line production compatibility repair is proposed; adoption and repaired runtime acceptance remain with root.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; supplied historical baseline `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`. No Git/runtime/build/process or repository mutation was performed by this reviewer. Root reports command77347 fully joined0; root remains sole source adopter.

## Actual evidence

Original GREEN-attempt receipt `fresh-native-tls-1792097971682851911.json` SHA256 `983690f6a0a1bbaf99a19c76749de3eb14efee79c45d3ac807bdf323da6aed0a` records **FAIL41 executed/2 failed/0 skipped/0 excluded**, exit2, joined/no timeout,59223ms, stable189-input source. Log SHA256 `0ef19a5e5000b0cc0f9ad912669a88bde05281878a887959a9cc1f10b8a62ac6`. Both positive cases lacked the observation tuple entirely; only peer startup/control messages were present (log43–130,134–243). Parent reports formatter/strict compiler PASS and accountant/nativeH2 gates NOT RUN due failfast.

Root's diagnostic receipt `native-tls-positive-diagnostic1-1792098286467315265.json` SHA256 `01fd918d56960b7d78d013f424796771d4ab97b15566acc157eac545f0cd874b` records **actual diagnostic FAIL41/2**, exit2, joined/no timeout,54732ms, stable source,0 skipped/0 excluded. This is an explanatory diagnostic failure, not GREEN or repaired acceptance.

Diagnostic log SHA256 `61fda4c0f25e01f9fde0c6fd046a0fcc1163ccbd657251297bfc22a542cbc156`,12169 bytes. Independently read bounded lines140–146 and272–278 both show:

```elixir
{:native_tls_get_ssl_data_error, actual_worker_pid, RuntimeError,
 "get_ssl_data not supported by Gaoxy.PlugAdapter", false}
```

The final false is actual `:code.is_loaded(Gaoxy.PlugAdapter)`. Root's `native-tls-positive-exception-diagnostic1.exs` was independently read: it reads unchanged original nativeTLS test bytes, wraps only the original Plug SSL expression in memory, sends exception class/message/loaded-state, then reraises the original error/stack. It recompiles at the original filename, keeps all original assertions, and runs all41 tests. Both exception selectors are real endpoint failures; the queued authoritative-owner-deadline case remains PASS according to parent and no other test failure is reported. JSON preserves diagnostic receipt/script/source hashes.

All evidence files above are under `docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089/`.

## Root cause and production classification

`ObservedEndpoint.call` constructs all tuple fields before `send` (test23–40). Its Plug metadata expression raises before the observation can be sent. Native `HTTP2.Stream.run:18–25` catches endpoint exceptions into an error result; an unset response becomes500, without forwarding the original exception to the observer. This explains the original empty observation mailbox.

`Plug.Conn.get_ssl_data/1` (`deps/plug/lib/plug/conn.ex:662–668`) probes `function_exported?(adapter, :get_ssl_data, 1)` without loading the adapter. `Exchange.plug_conn:56–77` embeds Gaoxy.PlugAdapter as an atom through `Plug.Conn.Adapter.conn/5`; that constructor (`adapter.ex:37–53`) creates Conn without invoking/loading the adapter. Gaoxy.PlugAdapter implements get_ssl_data, but it was unloaded in both actual cases.

This is a production first-call compatibility gap. Ordinary `PlugEndpoint.init` loads only the user Plug, and `PlugEndpoint.call:27–30` reaches Exchange.plug_conn before the user's first Plug operation. A real user Plug can query SSL metadata first. Loading only in ObservedEndpoint would hide the same source-visible production path. No existing caller-preload requirement was found. Plug intentionally checks an optional callback; Gaoxy owns loading its adapter. No upstream bug or issue is warranted by this evidence.

H2's authenticated metadata path still uses the actual worker pid, original stream id/token and authoritative owner deadline; direct Exchange metadata fetch returns state.ssl through that authenticated operation. The one-line repair changes no H2 authorization, owner deadline, TLS accounting or session metadata ownership.

## Proposed patch and preservation

`/tmp/gaoxy-group-native-tls-positive-repair1.patch` adds only this call plus a blank line at the start of production `Exchange.plug_conn/1`:

```elixir
Code.ensure_loaded!(Gaoxy.PlugAdapter)
```

Patch SHA256 `24d256384037ab88a241e01bc13162f81cb8926874af20d36d81dab8b2d1e371`,297 bytes. Exchange before SHA256 `513c300e4b3a161d54465696663eaa024acc7061c87aa43f961c42ea54de5652`; proposed after/before-formatter SHA256 `75b752c358d861be75446b99fef948f023082e6de177840bef35f99ce20776d0`.

Original formatted nativeTLS test SHA256 remains `601d497749e5daee3c4dc43d6351ddcc70abe5bda17f888be49eee5cd2be4ea3`, matching both current bytes and original failed receipt. No test, assertion, expected reason, timeout, fake event or private state changes are proposed. Root alone may adopt following independent review; command77347 has joined according to parent.

## Verification and next checks

**PASS:** source/artifact hashing; original failure custody; bounded actual exception selector/receipt/script review; production-path source trace; exact current Exchange anchor and one-call-only patch delta; unchanged original TLS test and Exchange bytes after patch generation. Current test/Exchange/Transport/Connection match the original failed manifest. Other inspected source hashes are current observations and are not claimed covered by that189-input receipt.

**NOT RUN by reviewer:** repair adoption, formatting, compilation, fresh repaired runtime and independent review. The patch remains a proposal;41/0 is unproven.

Parent should obtain independent SPEC/CODE review and apply the patch while preserving original test SHA, format/strict compile, and rerun the original unchanged complete nativeTLS suite. Require41 executed/0 failed/0 skipped/0 excluded, joined/no timeout/stable source. Run prescribed accountant/nativeH2 gates previously NOT RUN due failfast and fresh affected gates. Preserve all failure receipts.

Only the new `/tmp/gaoxy-group-native-tls-positive-diagnosis1.md`, `.json` and `/tmp/gaoxy-group-native-tls-positive-repair1.patch` artifacts were written. All reviewer commands finished; no runtime/background/build processes started.

Counters preserved: failedGREEN20, parent event21, Astra2/2 exhausted; reviewer adds0 runtime repair rounds. Earlier explicitly supplied rootrepair20 is recorded without interpreting event21 as a counter reset. No Astra recovery or design decision requested. Remaining risk is unexecuted repair acceptance.

Latest parent custody update: command77347 fully joined0. Parent reports Session fixture repair PASS46/0, joined/stable, receipt `fresh-session-control-1792098341265691639.json` SHA256 `1c2b9f98b2eb44828fa397126b6a7023bc0e30ce223d9d68ca74fb8f243fdfcb`. This update is parent-reported and does not substitute for fresh repaired nativeTLS acceptance.
