# Independent H1 fixture specification and no-launch repair review

Verdict: **PASS_STATIC_SPEC_WITH_B13_PREREQUISITE**. The narrow no-launch timeout repair is **APPROVED_FOR_IMPLEMENTATION**. Baseline functional execution, repaired-model execution, implementation code review and B21 remain **NOT RUN by this review**. Numerical qualification remains `ACCOUNTING_BLOCKED_INPUT`; Task4 and activation stay disabled.

Task `m3_h1_complete_and_fixture_spec_review`, direct independent Sol static assignment. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, parent-supplied branch `codex/m3-gateway`, baseline `b2ac78b518f459ec2c95b7823226640413f2ca95`. No Git checkpoint, Mix/VM/formatter/build, dependency mutation, peer/network or upstream issue operation was performed. Only this report, its JSON and the separate complete-ledger review pair are owned writes.

## Exact reviewed inputs and inventory

| Input | SHA256 |
| --- | --- |
| `docs/plans/m3-h1-qualification-fixture.md` | `1bc54a09507a070d50a1a316b3e875fac615bf2a98d9aaa7de77ea0a9dcbd0bf` |
| `h1-fixture-spec-inventory.json` | `da8e1d2922587c57227ff3f93774e8cd1be9a08a2ac1cfb7ab1567a3125704bf` |
| `docs/plans/m3-h1-no-launch-timeout-repair.md` | `12aae5945f23619144a85c4ec40f1a24fddc2274fbaf13940fb6649d3ce9e914` |
| Historical model | `0fd4f9fe81dc605ad6265635ddbfce1f4855245df05c73d0bcbe2cc03541dd6d` |
| Historical model tests | `4399f426e993f8e87f8628b3b80c9aae97028c6d31419700b316f04f96d77b1f` |

The refreshed inventory has **204/204 matching frozen hashes**, including **175 distinct runtime paths**, all present in the hash map. The twenty named headings and inventory rows are exactly B01–B20; each declares one test. B21 is one separate admitted TLS invocation. The historical 22/0 receipt qualifies only the old model/test bytes above; static source contains 22 named tests, but this reviewer executed none. The parent must freeze newly authorized model bytes and rerun the scoped 22-test runner after repair.

## B13 prerequisite and smallest lawful repair

Current `managed_h1_lease_model.exs:723–726` expires a pending attempt into `outcome: :timed_out, phase: :cleanup_hold` and leaves `completion: :none`. `reject_attempt` at359–372 accepts only pending reserved/preparing attempts; `release_attempt` at568–585 requires `:not_launched` for unlaunched owners. Therefore an expired pre-Fetch owner cannot currently supply terminal no-launch evidence even after all its local roots are explicitly released. N8 is not the cause of this local-only compatibility gap.

Approve the existing `reject_attempt` event for an unlaunched timed-out owner in cleanup_hold only when `lost_proof=false` and every control is unused. Record `completion: :not_launched`, enter releasing and preserve the original timed-out outcome/deadline, all roots, chunks and controls. Repeat matched evidence is duplicate. Timeout alone, public completion, helper death or result delivery grants no root/control/native refund. Pending prelaunch rejection keeps its prior behavior.

Implementation must also narrowly update the existing invariant predicates: `valid_attempt_phase?/1` at910–913 currently accepts unlaunched releasing only with rejected outcome; `valid_completion?/1` at923–924 accepts not_launched only with rejected outcome. These predicates must admit the same reviewed safe timed_out/not_launched state. This is a required implementation dependency, not authorization for a wider model or protocol change.

Keep 22 named tests by extending the current prelaunch-rejection test. Preserve its pending-rejection assertions and add reserved and preparing expiry at the original deadline; timeout without refund; explicit rejection while roots remain charged; matched root releases before same-slot fresh-nonce reuse; immutable original outcome/deadline; duplicate evidence; and late old success/completion/root/rejection/release events leaving the occupied replacement unchanged. Launched and lost-proof paths must fail to gain no-launch evidence. Controls remain independently charged; no `control_frontier_released` event is added. The parent owns deterministic RED, minimal model implementation, event-row synchronization, formatting, fresh22/0/no-skip/exit0 evidence, then independent specification/code-quality review.

## Source/API and arithmetic review

The public call sequence is valid for actual0.21.2 sources. Persistent custodian performs `HTTP.ManagedTransport.open/1`; original scope/receipts remain opaque. Source actor gets `HTTP.Promise.completion/1` and registers the original Promise/completion with ACK before `Promise.await/2`. Receipt registration similarly precedes `await_retired/2`. Promise.await delegates to Task.await; the specification correctly catches caller exit rather than relying on its misleading documented returned timeout tuple. No hidden prepare/admit/pool/tracker/stream-stop API, private task/PID inspection or reconstructed completion is admitted.

Pure preparation checks target plus supplied field charge. Actual Policy initial normalization checks after Fetch's UA insertion, using scheme/host/path/query bytes, excluding port and separator. Effective H1 normalization adds Host, replaces Connection, applies nil/PID framing and target charge. With `C=sum(name+value+32)`, explicit Connection gives `I-E=13` for nil query and12 for present-empty query. Generated Connection is `10+10+32=52`, so E65536 gives I65497/65496. Both advertised boundary families are correct. Explicit/absent UA, Host, TE/CT and nil CL deletion produce the B03 counts; source copies occur before some rejection branches and remain charged. Generated UA uses the supported public value under immutable identity.

Sources checked: Gaoxy `managed_h1_preparation.ex:24–121,246–272`; upstream `http.ex:282–340`, `managed_transport/policy.ex:157–212,264–298`, `request.ex:178–225`, `promise.ex:61–81`, `request_completion.ex:75–143`, `managed_transport.ex:108–207`, `stream.ex:26–29,85–140,194–228,316–356`, `http1/upload.ex:20–59,95–164`, `http1.ex:142–200,394–440`, and `trailers.ex`.

## Finite cases, custody and observation limits

The plan supplies role/capacity, scalar command, nonce, original-deadline, operation, evidence and cleanup contracts, rather than leaving them to implementation. Ceiling arithmetic is `3+4*(1+32+32+32+64+2+2+1)=667` fixture roles, plus128 separately charged public upload streams. Four generation rows and32 attempt rows/generation remain fixed. Two cleanup helpers/attempt, one graceful and one abort initiation/generation, two retirement waits and three snapshots/generation have whole-case caps. Peer is one process/listener with at most8 worker slots,64 control commands and128 event lines; outputs4096 bytes, wire4MiB/case. B12's three finish validations are explicitly budgeted. No per-rejection helper or growing historical nonce/result list is allowed.

Original primary/cleanup/shutdown deadlines are fixed; zero-time public observations consume existing operation slots. B17's owned delayed helper keeps the original retirement outcome/D and does not guarantee blocking of a private upstream call. Source/helper death is distinct from public completion and lost local proof is distinct from cleanup_unconfirmed. Original cleanup handles are installed before awaits and late already-issued returns remain registered; all declared owned actors and peer workers join or record explicit failure. The failure path uses the same finite operation slots.

B08 proves actual head-before-body wire order and one producer-root/ACK sequence, without claiming a blocked private writer/kernel send. B09 tests1365 body bytes with sole current consumer credit without demanding1365 callbacks or one parser delivery. B10 preserves CL/EOF totals above F without asserting a >F delivery. B11 correctly respects match-before-incomplete-line checking and finite4096-hex-digit bignum source behavior. B12's exact trailer length is `5+65527+4=65536`; both over-limit parser branches reject. B19 uses nine distinct proof slots for finite connection reuse. Local rejected attempts may reuse only after explicit no-launch and root evidence; launched functional completion cannot manufacture native frontier.

Specification quality has no blocking finding beyond the already disclosed B13 implementation prerequisite. Executable code quality is not reviewed because the three future fixture executables are not implemented by this assignment. The wording 'unchanged lease model' describes the authored starting point and is superseded only by the separately reviewed narrow repair; executable handoff must freeze its revised identity.

## Gates and verification limits

B21 is **NOT RUN, gate required**. Parent handoff reports diagnostic TLS build PASS in89.53s but wrapper failure with zero TLS cases; neither that build, source containment, full39 nor historical receipts provide the required PASS_TLS95_SUPPLEMENTAL envelope. B21 requires actual five-case TLS/cleanup evidence, identity/negative oracle and independent review; its real failed-handshake uncertainty cannot be substituted with local proof-loss. Baseline does not register or skip B21.

Parent subsequently reported18 TLS recovery2 harness setup errors before assertions (the public :application.load tuple/API distinction), with failure logs/source snapshots preserved and correction in progress. This supplies no new TLS qualification PASS.

Read-only commands were `rg --files`, `rg -n`, `cat`, scoped `sed -n`, and Python JSON/hash/shape/count/arithmetic checks. Python recomputed every204 inventory hash, checked175 unique runtime paths, twenty ordered case IDs and22 named historical tests; all these static checks passed. One shell glob used an incorrect Gaoxy path and returned no matches; exact paths were then discovered and read. One guessed installed OTP header directory was absent; actual16.4.0.6 headers were discovered and matched. Neither diagnostic was a runtime or implementation repair.

Review counters Sol0 / unsuccessful0 / Astra0 / received Astra0; retain all other historical failure/recovery counters. All own commands completed synchronously with no owned background job. No production, numeric evaluation, TLS supplemental success, repaired-model success or fixture runtime pass is claimed. Next dependency is parent implementation/verification of the approved B13 repair, then assigned fixture code and fresh scoped qualification.
