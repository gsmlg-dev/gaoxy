# Trailer repair bounded actual-source SPEC1

**PASS.** Actual formatted Transport repair and successful/refused real-native test contracts meet the bounded read-accounting specification. No95-role startup constructor checkpoint reopening is required. Independent CODE and fresh native execution remain required; repaired runtime is NOT RUN by this reviewer.

Task `native_worker_trailer_repair_spec1`, direct independent source review. Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; baseline `58307a7084298db309a93697b9102b2cc4c87eda` from freeze2 receipt. No Git command.

## Repair and test contracts

- **pre_read_capacity**: PASS unchanged credit validation/clamping and real Admission.update(retained(old)+2*credit) precede operation.
- **accepted_read**: PASS builds body/next first, then checks Admission.update(retained(next)); success only after :ok. ProtocolN/routeB/lease/deadline/pins unchanged.
- **final_admission_refusal**: PASS finite {:error,reason,next} preserves consumed framing/trailers/total and matches H1 Exchange.decode_body. It does not claim rejected next has been admitted.
- **pending_restore**: PASS checks exact old restoration; success returns pending only on :ok, refusal returns finite error+old.
- **primary_operation_error**: PASS best-effort old restoration retains original operation error reason, with no nested raw diagnostics.
- **unchanged_input_error**: PASS invalid read length/timeout and maybe_continue contracts unchanged.
- **successful_regression**: PASS source assertions preserved; terminal trailers buffered before admission remain unconsumed initially; explicit credit1 read returns full87-byte trailers, exact actual lease including originalN, poll preservation, real response and cleanup. Credit1 demands growth fromW+2 toW+174.
- **final_refusal_regression**: PASS source new real public configured-capacity case calibrates same path/header/endpointW and ordinary baseline, resets/joins calibration, admits atbaseline+W+2, credit1 read returns {:error,:byte_limit,progressed}, asserts N/full trailers/bodycomplete/total0/requested retainedW+174, while actual ordinary leaseW+2 and Gate totalbaseline+W+2 remain; RST real DOWN and zero/baseline cleanup required.
- **body_and_existing_error_contract**: PASS existing body credit16384 case retains exactN/read/poll/validation-error equality and normal response. No successful trailer assertion weakened.
- **collector_inventory**: PASS collector2 explicitly includes Transport in scoped formatter inventory; no constructor or execution-order change.
- **checkpoint_semantic_rebind**: PASS no reopening: all7 relevant startup/initial constructor production files unchanged vsfreeze2. Transport change runs after admitted initial dispatch inside endpoint read; no95 cap/count/owner/lifetime/shape/input/equation changed. Initial empty trailer body remains unchanged; runtime trailers use existing dynamic2*trailer_bytes on same current lease. Preserve immutable checkpoint1, bind repaired hashes, independent CODE then fresh native required.

Root nativeGREEN2 archived90 executed/1failure/0excluded, actual exit2, joined/source-stable: actual lease607735 versus returned retained607909 (174bytes). That failure is retained; source diagnosis was correct. The actual repair moves exact successful accounting to after construction of returned metadata, with explicit finite failures. No success is asserted for rejected progressed state.

The final-refusal regression is meaningful and meets the requested missing-error-path coverage at source level: original credit1 precharge succeeds, full trailers require growth beyond it, byte_limit is asserted instead of success, and the actual retained lease remains the accepted precharge rather than pretending the rejected returned state was admitted. Metadata/ownership/N and real terminal cleanup remain asserted. The existing successful exact-charge trailer test is preserved and strengthened. No additional pending-restore-rejection test is essential for this narrow fix; that branch is source-checked and no runtime coverage is claimed for it.

## Source identity and checkpoint scope

- Transport SHA256 `9c135f7dad3918f8c2ef4375aecc5a3eb99a536ffa9ea36a9f866747221e5c5a`.
- Startup/native test SHA256 `1244d4dc4369e92ef818cd2e3774b90a72143624d464c74b858e0f4cb1f5d0f7`.
- Relevant9 source comparison: only Transport and startup/native test differ from freeze2. Connection, WorkerAccounting, Stream, Exchange, Headers, Admission and WorkerBootstrap hashes are unchanged; all exact hashes are in JSON.
- Formatting8 PASS, exit0, joined, source-stable; receipt SHA256 `991dd6eef4f37a81364bd6d38d17d31682e64627746703e15939f2132322f9f0`. Formatting7 earlier allowed formatter-only mutation and source_stable false remains historical.
- NativeGREEN2 receipt SHA256 `cc5d998e43c78d67bf7e0f6d40f13f15a84ff1102ef52c10285ec237780c35ea`.

The changed code is reached by endpoint reads after admitted initial full dispatch. It does not modify the initial body with empty trailers/zero trailer_bytes, public spawn/alias/bootstrap, current ordinary lease grammar/lifecycle, any95 row cap/count/owner/lifetime, raw input or A/J/N/W equation. Dynamic returned trailers were already an existing retained-byte obligation. Preserve checkpoint1 immutable and record this semantic rebind/new source identity for independent CODE and subsequent native tests.

No whole-worktree stability claim is made while root works independently; the nine reviewed sources are bound to the formatted candidate and checked stable. All own commands finished; reviewer wrote only these two `/tmp` artifacts and ran no runtime/build/test/formatter/network/Git or delegation.

Counters retained: group34/root39, stage failedGREEN4, production repairs2/fixture repairs3, Astra2of2. This review adds0 runtime attempts and0 repairs. No user decision needed. This is not final stage, repaired-runtime, release, deployment or M3 completion acceptance.
