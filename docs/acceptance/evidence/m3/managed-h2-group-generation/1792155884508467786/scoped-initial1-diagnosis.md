# scoped-initial1 bounded diagnosis

Status: DONE, read-only diagnosis of two assigned symptoms. This is not independent acceptance review or runtime qualification. Direct assignment; worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; baseline HEAD received from root: `8131af39a846c292a022ccbfd32c53376cd57887` (no Git operation performed by this agent). Root retains exclusive repository/Git/evidence/runtime ownership and is concurrently repairing other fixture concerns. Only this report and its JSON companion were written.

## Findings

1. **Keep the foreign-instance test's 503 contract. There is a production error-accounting integration defect before Session normalization.** The real T owner refuses the foreign instance correctly, without deriving a child. The pump validates the owner's raw error against a normalized finite-error grammar, replaces it with `:invalid_resource_pin`, and thereby changes the intended 503 to 502. Changing the expectation to 502 would encode this lossy transition.
2. **Correct the late-cleanup assertion to exactly five handle holds in exactly three T pin records.** `Transports.status/1` counts handles across batches, not records. The fixed single-T fixture's three weighted pins cannot be carried unchanged into a two-member group. The extra two weighted pins are required baseline/source holds for unselected B, not leaked preparation or health pins.

## Evidence boundary

`docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/scoped-initial1.json` records FAIL, actual exit2,90 tests/7 failures/0 skips/0 exclusions, stable sources, joined command process and no remaining process group. Descendant cleanup separately records one forced/reaped PID with wait status10. This report does not upgrade that run. The foreign-instance failures are in `scoped-initial1.log:2020-2036` and `:2182-2198`; both expect503 and receive502. The two late-cleanup failures are at `:1983-2005` and `:2150-2172`; both report pins5/request_tokens1/helpers0 against expected pins3. The foreign test fails before its later exact delegation-result assertion executes, so the log alone does not establish that observer assertion passed; the exact reason below follows from source.

Source anchoring: root subsequently archived the exact initial test at `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/scoped-initial1-test-source.exs`, SHA256 `d2eb30add39d9ffc66333429c24a5dcee7875549cc7db7af81db718fd94aaf2a`. Test-file line citations below refer to that initial source; concurrent root repairs can move live line numbers. A second bounded receipt read reconfirmed command `forced:false` separately from `descendant_cleanup.forced:true` (PID3753595 reaped, wait status10, none remaining). Root's message describing no descendant cleanup differs from the receipt; this report preserves the recorded fields and leaves correction of that discrepancy to root.

## 1. Exact foreign-instance error path

- The test creates a genuine second Gaoxy instance, keeps authentic G/T receipts, and mutates only the wrapper's Exchange instance before forwarding: `apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs:1822-1845`. It still expects the real owner's `{:error, :transport_endpoint_mismatch}` and no checkout/bind at `:1849-1864`.
- HTTP starts Session with the mutated `exchange.instance` at `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:613-623`. Session selects G once and retains its token at `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex:1443-1466`, creates selected-T identity with `instance: state.instance` at `:1476-1488`, and sends the one-use handoff at `:1490-1513`.
- Native HTTP delegates the selected T with that identity at `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:940-960`. `UpstreamTransports.delegate_request_pin/6` sends the actual authority/instance to its owner at `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex:60-75`. The owner authenticates the genuine source first, then rejects `instance != state.instance` with **`:transport_endpoint_mismatch`** at `:353-365`. `derive_pin` is later at `:372-374`, so this mismatch cannot create the child or initiate T checkout.
- **Defective transition:** HTTP calls `account_pin_reply(config, result)` at `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:963-970`; its helper passes the original raw result directly into the owner-reply grammar at `:1088-1089`. That grammar's error clause requires `reason?(reason)` at `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_accounting.ex:1263-1264`. Its closed atom list is `:60-63`, and fallback `reason?` rejects everything else at `:639-645`. Raw `:transport_endpoint_mismatch` is deliberately not in that normalized list. Thus validation fails; HTTP cancels the genuine operation and **substitutes `{:error, :invalid_resource_pin}`** at `http.ex:968-970`, then sends that substituted error to Session at `:994-995`.
- Session's handoff-error control projection is allowed and bounded: `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_accounting.ex:1308-1313` normalizes reasons through `Session.finite_reason` (`:646`). Session receives the substituted error, calls `local_group_fail` at `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex:209-232`, sets cancelled outcome at `:1175`, then normalizes/notifies/settles at `:1297-1301`. `:invalid_resource_pin` is preserved by `finite_reason` at `:1856-1879`; it is no longer the mismatch atom.
- HTTP receives the Session error through `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:796-813` and dispatches it to `fail` at `:1065`. `fail` normalizes and maps only `:unavailable` to503; its default maps `:invalid_resource_pin` to502 at `:1173-1185`. `error_response` sends the bounded empty closing response at `:1188-1202`. This predicts the observed502 without relying on that output as the contract.
- The intended classification is explicit: **`Session.finite_reason(:transport_endpoint_mismatch) == :unavailable`** at `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex:1892`; HTTP maps this to503 at `http.ex:1181`. Session already normalizes genuine owner errors before applying this same owner-reply grammar in `session.ex:724-728`. The pump omitted that normalization step. No change to the finite grammar, T authentication or status policy is needed.

### Recommended narrow repair and regression assertions

Root should normalize only the error supplied for the pump's owner-reply accounting check, matching `Session.account_owner_reply`, while keeping the original supported owner result for actual handoff and revocation:

```elixir
defp account_pin_reply(%{group: %{execution_profile: :managed_h2}}, {:error, reason}) do
  ManagedH2GroupAccounting.validate(
    {:owner_reply, :transport, :pin},
    {:error, Session.finite_reason(reason)}
  )
end
# Existing managed-H2 success clause and non-managed fallback remain.
```

This is a proposal only; no repair was made or executed here. Keep exact503 in both existing foreign-instance cells. Keep exact raw owner refusal `{:error, :transport_endpoint_mismatch}`, one original delegation, zero T checkout/bind, authentic original G/T source preservation, unchanged member health, finite response/Session settlement and exact peer totals. Strengthen the observer check to bind the exact source/operation/session when useful. The bounded accounting regression should establish that the normalized `{:error, Session.finite_reason(:transport_endpoint_mismatch)}` passes the existing owner-reply constructor while the unnormalized raw mismatch continues to be rejected; do not add the raw atom to `@reasons` or loosen `reason?`. Existing foreign-instance socket cells then verify the real composed path returns503 without allocating a child/Fetch. Root must run the relevant existing accounting/Session/HTTP union and independent review required for an actual source change.

## 2. Exact five T holds and lifetimes

`apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex:1343-1352` computes status pins as `sum(length(hold.public.handles))`, not `map_size(state.pins)`. Store baseline acquisition batches `[T_A,T_B]` in one genuine T receipt (`apps/gaoxy_http/lib/gaoxy/http/generation.ex:517-526`; batching `apps/gaoxy_http/lib/gaoxy/http/resources.ex:34-52`). Checked native capture similarly acquires one authentic batch held by native with Store as acquirer (`generation.ex:443-447`; `upstream_transports.ex:910-954`). Selected delegation adds exactly one child record with singleton handles, holder Session, acquirer native and original source_ref (`upstream_transports.ex:1055-1077`). Hence:

| Weighted hold | Pin record | Holder | Acquirer | Lifetime |
|---|---|---|---|---|
| baseline A | one `[T_A,T_B]` baseline receipt | Store | Store | Active snapshot, until baseline retirement/Store stop; whole-owner retirement overrides it. |
| baseline B | same baseline receipt | Store | Store | Same as baseline A; B remains configured despite A selection. |
| source A | one original `[T_A,T_B]` request receipt | native | Store | Checked capture through endpoint return/finally, independent of Session completion. |
| source B | same original request receipt | native | Store | Same source lifetime; selected A cannot release unselected B early. |
| selected A child | one `[T_A]` derived request receipt | Session | native | Original selected-T request cleanup/finish then child release; `source_ref` equals original request receipt ref. |

These are **five handle holds in three records**, not five independently acquired receipts. G's own baseline/request pins and selection token live in the G owner and do not add T status pins. Direct-T and G dependency preparation receipts have already been released after Store publication; genuine HEAD probes have completed. The original fixed Generation late test's pins3 at `apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs:763-771` meant one baseline handle + one native source handle + one selected child handle. Reusing that scalar for a two-T group is the fixture error.

The assigned checkpoint explicitly suspends native and awaits the original pending completion, exact bound child/source and G completion at `apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs:2121-2138`. It must assert exact5; neither range/tolerance nor extra preparation receipt is warranted.

### Recommended exact assertions

Use the already observed real ledger and real Store baseline; assert identities as well as the weighted aggregate:

```elixir
[baseline] =
  for pin <- :sys.get_state(f.store).baseline,
      pin.provider == Transports,
      do: pin

assert baseline.kind == :baseline
assert baseline.handles === active.transports
assert baseline.holder == f.store
assert ledger.pins[baseline.ref].public === baseline
assert ledger.pins[baseline.ref].acquirer == f.store
refute Map.get(ledger.pins[baseline.ref], :derived, false)

assert captured.tpin.kind == :request
assert captured.tpin.handles === active.transports
assert captured.tpin.holder == native
assert ledger.pins[captured.tpin.ref].public === captured.tpin
assert ledger.pins[captured.tpin.ref].acquirer == f.store
refute Map.get(ledger.pins[captured.tpin.ref], :derived, false)

child = Map.fetch!(ledger.pins, held.child.ref)
assert child.public === held.child
assert child.public.kind == :request
assert child.public.handles === [held.selected]
assert child.public.holder == session
assert child.acquirer == native
assert child.derived and child.source_ref == captured.tpin.ref
assert ledger.pins[captured.tpin.ref].delegations == %{
  held.selected.resource => %{
    guardian: session, operation: held.child.operation, ref: held.child.ref
  }
}
assert MapSet.new(Map.keys(ledger.pins)) ==
         MapSet.new([baseline.ref, captured.tpin.ref, held.child.ref])
assert map_size(ledger.pins) == 3
assert Enum.sum(for {_, p} <- ledger.pins, do: length(p.public.handles)) == 5
assert {:ok, %{resources: 2, reserved_connections: 4,
               request_tokens: 1, pins: 5, helpers: 0,
               failed_resources: 0}} = Transports.status(owner)
```

Because the complete expected ref set is exact, this also excludes leaked preparation/probe/alternate children. Retain the existing original T/G completion identity and G-control assertions; retain the single T token guardian/resource identity from `bound`.

Normal Session settlement first waits original cleanup, then finishes T/releases the child, then finishes G/completes Service (`apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex:1346-1363,1398-1405,1711-1757`). Native original G/T receipts release only after endpoint return (`apps/gaoxy_http/lib/gaoxy/http/generation.ex:308-334`). In an ordinary active-snapshot path this would move weighted T pins5→4 after child cleanup→2 after native return→0 after Store baseline retirement. **Do not require that ordinary sequence after this late fixture's whole-instance stop:** `UpstreamTransports.begin_retirement` explicitly demonitors and clears every pin at `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex:1552-1575`, even while Store still exists. The pending real token/completion/Service custody and sticky failed retirement receipt must remain asserted separately. The fixture's existing later physical close/all-zero/sticky failure checks at `managed_h2_group_generation_test.exs:2161-2223` remain necessary and have not run past the failed initial checkpoint in this receipt.

## Verification, counters and shutdown

Only bounded read-only source/log/JSON inspection and these two `/tmp` report writes were performed. Tests executed by this agent: **0**. Mix/compile/format/browser/peers/network/Git writes: **NOT RUN**. No production or repository edits; no dependency/workaround/API/cap change; no new external issue identified. No Sol repair-and-validation round consumed; no Astra round consumed, Astra2/2 remains exhausted, no agents spawned. All commands finished synchronously; this agent started no runtime/background process. Root must implement and independently review any chosen repair, preserve the original failed receipt and counters, then obtain fresh scoped execution evidence. No user decision is required by these diagnoses.
