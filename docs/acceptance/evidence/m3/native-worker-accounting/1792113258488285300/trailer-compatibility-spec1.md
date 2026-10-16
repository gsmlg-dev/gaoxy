# Native trailer compatibility source analysis1

**DONE: narrow post-read repair recommended. No95-row constructor checkpoint reopening is required for this repair.** This is source-only analysis, not an observed native regression failure or repaired-runtime PASS.

Task `native_worker_trailer_compatibility_spec1`, direct assignment. Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; baseline `58307a7084298db309a93697b9102b2cc4c87eda` from frozen receipt. Root owns repository/runtime/tests/evidence/Git; reviewer writes only the two permitted `/tmp` artifacts.

## Source defect

HTTP2.Transport.read_body_step:65 restores Admission to `Exchange.retained_bytes(exchange)` before lines69–77 construct the returned body and its trailers. Exchange.retained_bytes:367–373 already includes `2*body.trailer_bytes`, unchanged protocol N, and any route B. The returned state can therefore retain trailers absent from its current lease charge.

The regression at http2_worker_startup_test.exs:377 supplies `{x-check,first}` and `{x-check,last}`. Headers.bytes adds32 per pair, so trailer bytes are `(7+5+32)+(7+4+32)=87`; source arithmetic predicts returned charge exceeds the current restored charge by174. This has not been observed by a runtime execution here.

## Smallest recommended implementation

1. Keep the existing credit validation/clamping and pre-read Admission.update(retained_bytes(exchange)+2*credit) before operation. A refusal still prevents the read operation.
2. Remove the unconditional ignored restore against old exchange before result matching.
3. For {:ok|:more, bytes, ended, trailers}, build body and next=%{exchange|body:body}; then Admission.update(next.gate,next.lease,Exchange.retained_bytes(next)) before returning success.
4. On exact post-read update :ok return {kind,bytes,next}. On {:error,reason}, return {:error,reason,next}, matching existing HTTP1 Exchange.decode_body semantics: preserve consumed framing/metadata and expose admission failure; never report successful exact accounting for a refused update.
5. For :pending, restore old retained_bytes(exchange); return {:pending,exchange} only on :ok; propagate finite {:error,reason,exchange} on restore refusal.
6. For operation {:error,reason}, perform the existing best-effort restore of old retained bytes and return the original {:error,reason,exchange}; do not replace original error with nested raw cleanup diagnostics.
7. Preserve maybe_continue errors, original N/route_bytes/resource pins/deadline/lease identity, body total/phase/trailers semantics, response/error handling and paired Gate cleanup. No new helper process, public API or limit is needed.

The final-update failure branch should match existing HTTP1 Exchange.decode_body: a failed update returns an error with progressed metadata. It must not be described as an admitted exact-success result. In particular,2*credit is body-data precharge, not a source bound on trailer bytes; tiny credit can require a growing post-read admission. Do not discard consumed framing/metadata, ignore a refused exact update, report success, or add a speculative always-reserved trailer maximum to pass this test. Original operation errors remain primary.

## Why checkpoint1 remains valid

- This method is reached from the endpoint after Stream.run receives its admitted full dispatch and invokes module.call. It does not execute on the pre-admission or startup path.
- Connection.dispatch and WorkerAccounting still build the identical initial body %{phase:data|done,total:0,trailers:[],trailer_bytes:0}; all complete initial Exchange/default/request/endpoint fields remain unchanged.
- No calculator input, EFT constructor shape, role cap, count, owner, lifetime, alias/spawn/activation/cancel wrapper, bootstrap apply argument, link/monitor/timer root or whole equation is modified.
- The same current ordinary lease is updated using Exchange.retained_bytes(next), which already includes unchanged protocol_bytes N and any route_bytes B. Runtime trailers are the existing dynamic 2*trailer_bytes obligation, not a new startup allowance.
- Gate ordinary-lease schema/ownership/paired DOWN+EXIT release remain unchanged and terminal refund already subtracts current lease.bytes. There is no lease transfer or early worker refund.
- The startup rows named body_map,parent_exchange,dispatch_envelope,child_exchange refer to the complete initial dispatch shapes. Later body-read mutations are existing runtime operations; they do not create another initial dispatch or extend any startup role lifetime.
- Although the Transport source hash changes, the checkpoint reopening condition is a changed charged constructor/lifetime/multiplicity/equation, not every unrelated source byte. Preserve checkpoint1 immutably and record/review the exact new Transport hash and this semantic rebind before running the affected native test.

This conclusion is conditional on the narrow repair above. A changed startup Exchange, WorkerAccounting input, ordinary lease schema, activation, startup control role or lifetime/multiplicity/equation reopens the same checkpoint before further W consumption. The original checkpoint receipt stays immutable. A new Transport hash must be bound and reviewed with the repair and fresh runtime evidence.

## Required scoped verification

- Existing terminal-trailers regression must retain body-incomplete/empty initial trailers, explicit read consumption, returned exact trailer bytes and retained lease assertion, poll persistence, normal wire response and real worker/Gate cleanup.
- Existing full-N read/poll/validation-error/normal-response regression remains exact. Keep original stale-start/control responsiveness/error assertions.
- Preserve pre-read byte-limit refusal and finite pending/error paths; final update refusal must not return {:ok|:more,...}. An admitted return must have lease.bytes==Exchange.retained_bytes(returned).
- Small read credits do not bound trailer size. With credit1 and these87bytes of trailers, final retained old+174 exceeds read precharge old+2; post-read update may require a real extra admission. Propagate refusal honestly; do not assume every final update is a shrink or invent a larger always-reserved trailer maximum for this narrow repair. This mirrors existing H1 post-decode admission-error behavior.
- Fresh affected scoped native tests and final full-stage independent review on the repaired source are required. This source-only analysis is neither observed runtime failure nor repaired-runtime PASS.

## Source binding and shutdown

All9 relevant production/test source hashes match freeze2 before/after this analysis; exact hashes are in JSON. Transport SHA256 `b497b15778847aa56f3f0a0e5ec5aa68323fcd609c8b9d0aa091e4c1e9200302`; worker-accounting SHA256 `3ee7f96df0c1394d25354280f77bba71ae59defd6fd252702f1847fcf58b78a7`; startup regression SHA256 `1d806feb85fbdb56793b61671198eb876b6f8f91280ea67cc3e3c5336a530eaa`. Constructor checkpoint1 SHA256 `76aa418d71b9c82675cbb86f3ed0043797e2bae5cd7faa338fd9b1b40f4c2f4f`. No whole-worktree stability claim is made while root independently repairs its core fixture.

Counters retained: effective group32/root37, stage failedGREEN2, Astra2of2 exhausted. This analysis adds0 attempts and0 repairs. All own commands finished. No runtime, build, tests, network, Git, delegation, repository/evidence edit or background process. No product decision is required.
