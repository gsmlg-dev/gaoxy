# Native pre-snapshot accounting: bounded pure worksheet prerequisite

Status: SOURCE-BOUND DESIGN, CONDITIONAL EXECUTABLE ARITHMETIC; READY FOR PURE TDD/INDEPENDENT REVIEW ONLY. No finite whole-path runtime reservation is established for current Generation/Resources/Lifecycle. No Admission, owner, Generation or Resources runtime change is part of this slice. Constructor prerequisites below must close before accounted-runtime TDD. Continuing authorization covers these bounded prerequisites; no routine approval or third Astra recovery is requested.

Task `native_accounting_worksheet`, direct source-only assignment. R=`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; branch `codex/m3-h1-resource-foundation`. Source inspected at feature `00cdedb2b348131c6298fa192e753ce5ad1e1b52`; parent reports clean consistency closure `48a71a70acbe9cb46f99b82e4062c6f5f25d9667`, exact closure receipt `/tmp/gaoxy-generation-resource-consistency-actual-closure1.json`. Runtime source identities below are unchanged. Initial parent-owned two custody JSONs and later three doc edits were preserved. Parent exclusively owns repository/runtime/build/evidence/index/Git. Author writes only assigned `/tmp` artifacts and separately parent-authorized prototype2.

Readiness1 W1–W8 are the acceptance checklist. Original design SHA256 `2a6564b3338b2f83fc4b95d7032e374f98d45ef6303e3ee7c29445787921f0fc`; original plan `5f7fb3770ceee2ff9902048f9ce8bf8dc04266ce018ef47589095802b87f1620`; final readiness MD `3f235deff86107feeb9879fb083b76653bd1e8ae5f81120b0f33d2215a2a3400`, JSON `2f4b7b5bce0dd4f3a7cbfb891d9f14c940d982145527d7bf155e1484d008ae2a`. Preserve these historical files.

## Smallest recommended implementation

Use one pure module, `Gaoxy.Proxy.ManagedGenerationAccounting`, for this worksheet and later the existing proposed opt-in managed capture callback. No generic accounting framework, registry, process, dependency or core import of proxy. Pure prerequisite modifies only that new module, one focused proxy test and its design/plan/evidence. Existing native runtime files stay unchanged.

Proposed pure API:

* `worksheet(M, context)` validates original scalar context and returns `{:ok, report}` with `qualification: :conditional_not_runtime_ready`, full machine-readable source-role descriptors, bounds, multiplicities, subtotals, fixed-point B and prerequisite identities. This report is review/test output, not retained runtime payload. `context` is the complete `{store,holder,gate,lease,:request,deadline,retained_bytes}` tuple. PIDs/references are original terms, each ETF<=2,048; deadline is signed64 with the existing cleanup headroom condition; retained_bytes is actual nonnegative Exchange.retained_bytes. Reject unknown keys/shapes/types; no lookup or callbacks. M is actual configured positive integer.
* Pure `preflight_cons(pin, pins)` and `preflight_append(new_pins, existing_pins)` take actual operands, validate their complete managed shape, raw count and ETF before producing any candidate list, then return `{:ok, %{count: n, bytes: e}}` or `{:error, :generation_capture_capacity}`. Schema failures use `:invalid_generation_capture`. They do not return/construct the combined list. For a single pin, reuse existing `ManagedH2GroupAccounting.validate({:owner_reply,:group_or_transport,:pin},{:ok,pin})` (selector369–374, constructor1255–1256), then measure the original complete map and require<=R. This bounded {:ok,pin} validation wrapper is already paid by the provider_result role. Do not construct `[pin]`. For existing capture operands, use `validate(:captured_pins,pins)` on each original list before measuring. Preserve complete terms/order and reject unknown provider; no schema duplication/public validator change is needed.
* The prototype's `{count, ETF}` helpers are arithmetic-only, TRUSTED INTERNAL summaries. Production keeps those helpers private and derives summaries from actual bounded operands in the same call. Neither public runtime input nor a configurable accounting module may supply unverified stats. Test a forged summary separately only if a stats API is exposed: the recommended module has no such public stats API.
* `finite_checked_reason(term)` is a pure normalization contract for later opt-in checked acquisition/release, with an exact finite vocabulary. It does not claim current Lifecycle output is finite. Tests exercise normalization of arbitrary diagnostic terms, which must never be retained in the checked plan/control/result or telemetry. No generic Lifecycle API change.

The minimal proposed future retained plan is exactly `{:native_generation_capture_v1,M,H,Q,B}`. Report role descriptors are compile-time worksheet information, not attached to that tuple or Exchange. If runtime later returns/stores a map instead, rederive its complete ETF and B first. Existing optional interface from proposal1 remains a later task, never a reason to enable H2 Generation.

## Input closure and precise constants

`M = actual Store.limits.max_config_bytes`, not a universal65,536 cap. Generation options145–154 default M=1,048,576 and permit any positive integer. Store.compiled_bound440–449 bounds the complete immutable Router ETF by M, including its generation, route/options nesting and static resource sidecar. H=65,536 and raw manifest count<=64 come from Resources10–26. The selected accepted complete capture list has Q=65,536 and count<=64 from ManagedH2GroupAccounting470–486. Q is the accepted-list cap, not a promise that every genuine provider reply fits it.

All managed G variants accepted by the current accounting grammar remain enumerated: H1 six-key G or seven-key G with transports, and managed-H2 eight-key G. Its transports list<=32 is an existing per-G constructor bound. T is exactly four keys. There is no global64-resource/33-group rule across dynamic Stores. Finite term nesting inside a single accepted immutable Router follows from complete ETF<=M (each constructor consumes positive bytes); no invented depth64 limit is added. A dynamic Generation config retains only its Store PID/options, so the current Router bound does not inspect future Store snapshots or prove a bound on a cyclic Store chain. A later accounted recursion adds its own strictly positive B to route_bytes before each capture; finite actual Admission capacity bounds accepted nesting. Do not traverse dynamic Stores while planning.

S=2,048 is the existing accepted PID/reference scalar cap395–400. For future native refs, use the source-reviewed inequality `E(new_ref)<=E(source_node)+27`, not a fabricated reference. Given NEW_PID_EXT `E(owner)=E(node(owner))+13` and owner<=S, a conservative future-ref Rf=S+14=2,062 follows. This covers genuine outputs larger than the selected scalar acceptance cap too; those outputs are rejected only after their paid receipt role. It does not pretend their size is<=S. The loaded encoder's NEW_PID_EXT and fresh/alias reference length<=5 premises require source/toolchain confirmation; root's one sample is corroboration, not a maximum proof. If those premises are unsupported for a selected provider owner/runtime, return an unqualified worksheet, not an invented smaller Rf. Do not silently restrict existing legacy providers or distributed owner PIDs to local ones.

D=12 is complete signed64 integer ETF upper bound (small-big header plus8 digits), conditional on explicitly validating the selected deadline grammar before provider effects. Resources currently accepts arbitrary positive-deadline integers; only the optional managed profile adds its existing signed64 grammar, leaving legacy unchanged. Future local release deadlines must satisfy the same time/headroom premise or be precomputed/validated before the first charge. M and retained byte integers have no invented fixed byte bound: exact E(M), E(retained+B) are used.

Service9,444,956, group16,478,862, startup5,963,776 stay unchanged. The worksheet neither borrows them nor changes them.

## Exact ETF algebra and genuine receipt bounds

Use E(x)=`:erlang.external_size(x)` with default uncompressed standalone ETF and b(x)=E(x)-1. No compressed/distribution atom-cache size is substituted. For complete child sizes e_i:

```
T(e_1,...,e_n) = 3 + sum(e_i-1)               # tuple arity<=255
Map((keyE,valueE)...) = 6 + sum(keyE+valueE-2)
L(empty)=2
L(nonempty) = 7 + sum(e_i-1)                 # LIST_EXT+NIL_EXT
Alias(r) = 6 + b(:alias) + r-1               # improper [:alias | ref]
From(p,r) = T(p,Alias(r))
Call(payload,p,r) = T(E(:"$gen_call"),From(p,r),payload)
Reply(payload,r) = T(Alias(r),payload)
```

The alias tag is improper; using a proper `[alias,ref]` would be wrong. Tuple3 and map6 include the standalone ETF version once, every nested member loses its own version. No unexplained +16/+65,536 wrapper headroom appears.

The actual G public pin (G892–920 and1376–1387) is the complete seven-key map:

```
%{provider:G, owner:owner, owner_epoch:epoch, ref:new_ref,
  operation:original_operation, handles:exact_batch, kind::request}
```

T901–945 adds exactly `holder:original_holder`, giving eight keys. Given whole batch E<=H, use complete sizes owner<=S, epoch<=S, original fresh operation<=Rf, new ref<=Rf, holder<=S. Derive R_G/R_T by Map above with the actual provider/key/kind atoms. Prototype1 executed by root gives R_G=73,862, R_T=75,921; singleton lists are R_G+6/R_T+6. G-H2 constructs pin then validates `[pin]`1399 before success; G-H1 and T do not perform that Q check. Accordingly all genuine G/T constructors have a separately paid raw complete pin R=max(R_G,R_T), result `T(E(:ok),R)`, actual alias-wrapped result and Store-received result. That includes real valid-by-owner success later rejected by the capture profile. None is placed in the arbitrary-callback exclusion. Mixed H1/H2 G batches use the same public seven-key constructor, and G-H2's smaller accepted result is covered.

Prospective validation uses this constructor-derived R before provider invocation; it need not reject a batch merely because the eventual actual pin might exceed Q. Such a pin fits R and is rejected before accumulator cons. This preserves handle admissibility while limiting the explicitly opted-in accepted capture profile. Legacy paths keep current behavior. Parent may choose a pre-effect prospective Q restriction only as an explicit later design change with compatible-profile tests, never silently.

Complete public snapshot payload is `T(E(:ok),M,M,Q)=2*M+Q+E(:ok)-1` (current encoder:2*M+Q+4): generation is repeated outside the complete Router. Three named payload/wire/received roots below conservatively account all public result ownership; neither a Router-only2M allowance nor M+Q describes those roots.

## Pre-construction arithmetic

For an already validated proper capture list, let n=count and e=its complete ETF. Its element-body sum is s(0,2)=0, s(n>0,e)=e-7. Pins are maps, so STRING_EXT optimization cannot apply.

```
cons_count = n+1
cons_size = 7 + (E(pin)-1) + s(n,e)
append_count = an+bn
append_size = 2                      if an+bn==0
              7+s(an,ae)+s(bn,be)   otherwise
```

Check count<=64 AND size<=Q before `[pin|pins]` or `new_pins++existing_pins`. One input may be empty. Two nonempty input sizes combine as ae+be-7, not ae+be or ae+be-2. E(pin)=Q-6 with empty acc fits exactly; Q-5 rejects. Two individuallyQ operands produce prospective2Q-7=131,065 bytes without allocating that list; counts64+64=128 reject before append. Zero/all-empty inputs remain2bytes. Incoming genuine pin up toR is already paid; no rejected aggregate/128-item candidate is built. If future code constructs any such candidate before preflight, this worksheet ceases to qualify: add its full rejected role (up to131,065/128 entries), rederive B and tests first.

The provider batching partition also has a complete bound. Let A=max(E(G),E(T)), k<=64. Raw input manifest elements contribute <=H-7 body bytes. Complete map of `{provider,owner}=>batch` has bound `6+(H-7)+k*(8+(A-1)+(S-1))`; key tuple-body2 and list-body6 are explicit. Full reverse/unique handle-list scratch is separately paid3H. This is per acquisition, not a global dynamic inventory.

## Whole-role ledger and B

Prototype2 is the superseding executable worksheet; prototype1/run1 stay immutable historical arithmetic. Every role has a machine-readable name, owner, complete constructor, cap, multiplicity, subtotal and release point in `role_specs/1`. B is the conservative sum of all roles; it does not subtract sharing or claim simultaneous physical copies. Symbols and exact constructors above define bounds, not lossy safe projections of real payloads.

| Roles | Count | Complete constructor / owner / end |
| --- | ---: | --- |
| context |1| context tuple above; requester; request end |
| plan |1| five-element native_generation_capture_v1 tuple; requester; request end |
| admission_update_payload / wire / reply |1 each| `{:update,lease,retained+B}`, Call(update), Reply(:ok or finite error); requester/gate; update return |
| snapshot_requester_payload / wire / Store payload / from |1 each| `{:snapshot_for_request,holder,deadline,module}`, Call(request), same complete payload, From(requester,alias); requester/Store; snapshot return |
| validated_manifest |1| original complete resources list<=H; Store; snapshot return |
| partition_map |1| complete batch map formula above; Store; acquisition end |
| provider_handle_normalization |3| complete input/reverse accumulator/unique output lists<=H; provider; provider return |
| provider_request_payload / wire / owner payload / from |1 each| `{:pin or :pin_many,batch,holder,:request,operation,deadline}`, Call(payload), owner payload, From(Store,alias); Store/provider; call return |
| genuine_provider_pin |1| actual seven/eight-key map<=R; provider; validation |
| provider_result_payload / wire / Store received |1 each| complete `{:ok,pin}` or finite error, Reply(result), same received result; provider/Store; validation |
| checked_acquisition_accumulator |3| `{:ok,complete_pins}` input/current/output<=T(E(:ok),Q); Store; snapshot return |
| original_provenance |1| <=64 original `{provider,owner,operation}` list; Store; acquisition end |
| Store_snapshot_payload / wire / requester_received |1 each| `{:ok,generation,router,pins}` or finite error, Reply(result), received payload; Store/requester; snapshot return/request end |
| caller_capture_inputs_and_output |3| complete existing/new/prechecked combined lists<=Q; requester; request end |
| release_payload / wire / reply |1 each| `{:release,complete_validated_pin}`, Call(release), Reply(:ok/finite error); requester/provider; release return |
| cancel_control |64| `{:cancel_pin,Store,original_operation}` or T `{:cancel_pins,...}`; original provider; acquisition cancellation completion/uncertainty |
| known_call_failure_descriptor |1| `{finite_reason,{GenServer,:call,[server,complete_request,timeout]}}`, max of snapshot/provider/release/update; call return |
| known_monitor_down |1| `{:DOWN,ref,:process,pid,finite_reason}`; caller; call return |
| cleanup_observation |2| complete bounded event+measurements+metadata constructor below, original+empty-scope merged metadata roots; requester; emit return |
| finite_failure_payload |1| `{:error,finite_checked_reason}`; requester; request end |

Original provenance list bound is `L(k copies of T(A,S,Rf))`, with provider/owner/operation recorded BEFORE invoking that actual batch. Full holder/kind live in context and batch in partition, never reconstructed from bad output. Store still requires holder===caller. Accepted pin must match exact original provider/owner/epoch/operation/handles, requested kind===:request, T.holder===original requester; G's public pin has no holder field. Exact map keysets remain seven/eight; do not invent fields to make projection easier.

Cancellation is asynchronous (G361–363/T137–139), so all k original operation controls can be outstanding together. Paying only a single synchronous-current control would be unsound. No history is accumulated. Release calls are serial, one complete release/control at a time. Timeout/unknown does not turn sent cancel into confirmed cleanup or refund B.

Plan includes E(B); Admission.update includes E(retained+B). Therefore solve the integer-size fixed point: start B0=0, derive every row including those exact integer ETF sizes, Bnext=sum(count*cap), stop only when Bnext=B. The prototype has a finite iteration guard that is an arithmetic-run sanity guard, not a product nesting/list constraint. Acceptance must demonstrate convergence and every subtotal, including extreme integer-size boundaries. This avoids a guessed global bound for M, retained or B. B is kept in route_bytes through ordinary request teardown after future runtime adoption; later Exchange body/output updates must preserve it. This slice does not adopt that behavior.

Root's historical P1 arithmetic result: M65,536 =>2,416,514; defaultM1,048,576=>8,314,754. These are NOT whole-role totals after source review: P1 paid only one cancel and omitted known Elixir failure/DOWN plus a cleanup metadata root. P2 supersedes them; preserve P1 sha/run receipt and never call its total a valid reservation. P2 numeric table/receipt appears below after parent execution. Neither prototype is ExUnit or accounting runtime acceptance.

## Missing constructor prerequisites: explicit runtime qualification gates

C1. Current Resources cons43 and Generation append128 execute without the new preflight. Pure worksheet tests must first prove arithmetic; later runtime TDD inserts actual-operand precheck at every corresponding checked-path construction and keeps legacy unchanged. Source review locates every cons/append; stats supplied by a caller are never authority.

C2. Current managed pin constructors justify R, not Q. G-H1/T direct success and G-H2 rejected singleton are covered as genuine roles. Parent independently proves exact map/wrapper algebra against actual public owner receipts at configured manifest boundary. Do not sample a small receipt as a maximum. No owner change is needed if R remains separately paid and a rejected pin is canceled using original provenance. Future-ref proof (NEW_PID_EXT/node+13, generated reference<=node+27) must bind the loaded OTP/native provider constructor sources. The probe's29/35 are merely examples. Unsupported constructor premise leaves P/B UNQUALIFIED rather than replacing it with a constant.

C3. Lifecycle.call10–16 and protect19–25 can retain arbitrary `{:operation_exit,raw_reason}` or `{throw_or_exit,raw_reason}`. Current errors therefore have no finite whole-constructor bound. The checked managed path needs a finite conversion at its public acceptance seam, not a generic Lifecycle modification. Select exact finite reasons in prototype; known timeout/nonrunning/invalid/schema/capacity map deterministically to finite checked reasons. Original primary typed failure is preserved where already finite; unbounded provider diagnostics never enter retained checked result, cancellation event or plan. Full known Elixir GenServer.call1117–1131 descriptor duplicates server/request/timeout and is explicitly paid in P2; arbitrary raw process death/diagnostic payload is not bounded by that known descriptor. This is a missing constructor contract, not an allegation of malicious providers. Pure normalization TDD is necessary now; actual checked-path normalization and honest transient scope are a later runtime gate. This scope bounds enumerated accepted/finite public source roles, not total heap from arbitrary exits/callbacks.

C4. Selected signed64 deadline/scalar/context and plan-tuple constructors currently do not exist as an opt-in checked contract. Pure tests must validate them and reject drift; no silent claim that generic Resources already enforces these bounds. Complete report must stay out of retained plan, else rederive its size.

C5. Existing Generation.after release130 ignores its result. The accounted branch later implements the finite policy below and tests outcomes. This is required before runtime qualification, not an excuse to change generic release behavior now.

Until C1–C5 and W1–W8 relevant pure assertions plus independent SPEC/CODE close, `B` is a conditional arithmetic candidate, not an Admission reserve. Pure worksheet completion does not establish native pre-snapshot accounting, native worker transfer, H2 Generation activation, protocol/load acceptance or release readiness.

## Concrete finite cleanup policy for later accounted branch

Use existing `Gaoxy.Telemetry.emit(:generation_capture_cleanup,%{count:1},%{},metadata)` once per failed cleanup, not per pin/history. Metadata is exactly `%{store:original_store,holder:original_requester,lease:original_lease,stage::acquisition_or_release,cleanup::cleanup_unconfirmed}`. PID/ref scalars satisfy context cap. No target result, raw error, stacktrace, exception module, arbitrary service scope, pin/handles or provider response enters metadata. Empty scope avoids merging unbounded caller metadata. The complete emitted constructor and merged-metadata root are paid twice conservatively. Telemetry handler internals are outside this public source-role bound. Source bind Telemetry1–5 before adopting this mechanism.

| Primary operation | Cleanup | Finite observable outcome |
| --- | --- | --- |
| Acquisition/validation fails before dispatch | cancel sent or cancel fails | return original finite checked acquisition error; emit one stage:acquisition cleanup_unconfirmed event. Sent cancel is uncertainty until public confirmation. No Router call. |
| Router returns success | all releases :ok | preserve successful result; no uncertainty event |
| Router returns success | any release fails/raises/times out | return `{:error,:generation_pin_release_failed,latest_exchange}` and emit one stage:release cleanup_unconfirmed event. This is endpoint result accounting, not a new HTTP wire error if response was already sent. |
| Router returns `{:error,primary,latest_exchange}` | release failure | preserve EXACT original primary error/result, emit finite cleanup event; do not wrap/replace primary |
| Router raises/throws/exits | release failure | re-raise/rethrow/re-exit original class/value/stack after bounded cleanup; emit finite cleanup event; never replace primary with cleanup failure |

Preserving an original arbitrary endpoint exception/result does not add it to a new finite control/plan or serialize a copy of its internals. Ordinary request/endpoint accounting owns that original outcome; this narrow allowance does not certify arbitrary endpoints. Keep B until normal request/lease teardown on every path. Failed observations must not replace primary either; concrete later source must catch observer failure without retaining raw observer diagnostics. No cleanup confirmation inferred from telemetry, cancel or ignored result. Legacy APIs keep current outcomes.

## Source identity / loaded-constructor binding

Root executed `/tmp/gaoxy-native-generation-toolchain-probe1.exs`, receipt `/tmp/gaoxy-native-generation-toolchain-probe1.json`, exit0, ERTS16.4.0.6/OTP28/Elixir1.18.5; actual loaded stdlib is `/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7/lib/erlang/lib/stdlib-7.3.0.3`, not the older historical5y0714 path. Actual loaded Elixir is `/nix/store/jc6g5l4a2qg89s3mng0p18r9dbijc28d-elixir-1.18.5`. Author read source only, did not launch this probe. Probe node ETF16/pid29/ref35 are corroboration only.

* stdlib/src/gen.erl251–280 constructs actual `$gen_call`, improper alias and reply;549–554 emits `{tag,reply}`. SHA256 `b828697b055865df24aad48ec4cd7f23821fa54a7aa2baa0408a444a5d0d04be`.
* stdlib/src/gen_server.erl delegates reply to gen:reply; SHA256 `66a4a649c8ed58f3c9ed317047f28ea2e2a61b38032cc467565fbad2c53a09db`.
* Elixir lib/elixir/lib/elixir/lib/gen_server.ex1117–1131 constructs failure exit descriptor and unwraps {:ok,res}; SHA256 `6d00e38c0f2ed6296b3c353e823123042345035da7328a1db6f73de44bf57fe2`.

Local source hashes in next table include all original14 plus G/Lifecycle/Admission and Telemetry. Source roles cite: Generation31–32,107–134,172–180,200–205,440–449; Resources10–67; Router11,56–85,98–108; Exchange367–374; G347–363,541–583,892–920,1376–1420; T108–139,326–335,852–878,901–945; ManagedH2GroupAccounting395–486. HTTP2/HTTP3-related original sources remain preservation identities only, not worker-transfer proof.

| Source | SHA256 |
| --- | --- |
| `apps/gaoxy_http/lib/gaoxy/http/generation.ex` | `aca3f62a1078825c1e6db087f76dacf2ab28611b5b360e2f14169f050ee9a751` |
| `apps/gaoxy_http/lib/gaoxy/http/resources.ex` | `0e58a4f0badd2ba6d21b9f118c5b3f6c4d1070b4371e76e9dfc0656796f0907b` |
| `apps/gaoxy_http/lib/gaoxy/http/exchange.ex` | `75b752c358d861be75446b99fef948f023082e6de177840bef35f99ce20776d0` |
| `apps/gaoxy_http/lib/gaoxy/http/connection.ex` | `d74a1ea9b35e996db51da5b698390afd3cdc5c47eb2c499d35c3af69de46d3f2` |
| `apps/gaoxy_http/lib/gaoxy/http/router.ex` | `513db9910d6f0beabf1038db8bc1539ee5c5e8731ace0f6d349b9f2f2db96abd` |
| `apps/gaoxy_http/lib/gaoxy/http/options.ex` | `3c1a68f1bf58d4f205958b82230e6d28665b719c7b64923593992decdcafdb90` |
| `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex` | `5696219cf250cada82badd531d1f28869b3a4145b78dc7ec43af956d7f765400` |
| `apps/gaoxy_http/lib/gaoxy/http/http2/stream.ex` | `1693bb01f12347a4497bc46b166beeb1ac5fc1102091f1825aac7461a5393a53` |
| `apps/gaoxy_http/lib/gaoxy/http/http2/limits.ex` | `f8d922deee2f7a45ecf3070498a3f82a50af47b5fbe0007545ab11bf3cf831ab` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_accounting.ex` | `933b07a056d3a80baa6ce9ff9df1c84d7b4fc24c49dde1770d16f8855a6ee92f` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_reservation.ex` | `8e897af16bb69c30751a36f9d6f0f0aeff83bcff2b571a6bac9dc270bf5b2100` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex` | `72f70becc478fe0e864015c033bcb1fec5f6aa51a8639cc9b35a0173191b6738` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex` | `f6f638d1f1f88b53c8282dc121466eb0614d241fe8ec56cc57a8a2a8b0d4096e` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex` | `8a041a6bc217ef5ec626dc9e4efc2ec495db3a668912214420ad01bd4d449eac` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex` | `b0330019d771b9f58f6f15eba555cd77ec0ce0fcf2843bd9e19619d65b2ae2c7` |
| `apps/gaoxy/lib/gaoxy/lifecycle.ex` | `7f673e89f59b41af72057ce1afa553fa6c62e56125b450e6d09e58da0a434f75` |
| `apps/gaoxy/lib/gaoxy/admission.ex` | `169f311b2a4995b3de901ac41b5c2768208c8f8c3e26d2e57a58fdefdc013a75` |
| `apps/gaoxy/lib/gaoxy/telemetry.ex` | `749421579aa4d6c5c8d8def5d9cdf502a59c7aa194203a8fb6c3051de1b72961` |

## Verification status and custody

Author ran only read-only source/Git/hash inspection and writes to owned /tmp artifacts. No repository edit, runtime/build/mix/Nix/formatter/tests or Git mutation. Searches for nonexistent historical options/spec files returned errors; actual relevant Generation/Admission sources were then read. These are read-only search corrections, not runtime failedGREEN/repair attempts. All own commands completed; no background processes started or touched.

Root's historical P1 arithmetic receipt is PASS_ARITHMETIC_ONLY, exit0, bound to an earlier copied P1 SHA552cfc747730fd25859f72c2735c010febca7e1b19964c1860c73d297e0ae948. The current /tmp P1 has added machine-readable role_specs metadata from before the freeze message and SHA c0b88ff035e94970297e77525a29966c7e50abe0cd3e3574d986b46e3de4fbef; do not claim run1 executed that later metadata version. Both copies/results must stay distinct; no ExUnit tests or native runtime acceptance. Pure prerequisite ExUnit, independent SPEC/CODE and constructor maximum proof remain NOT RUN by author. Counters: this task runtime attempts0/repair rounds0; inherited group failedGREEN24/root events27/Astra2/2 exhausted unchanged. Prior consistency61new+91old acceptance is predecessor evidence, not this task's test count. No upstream97 proof/task, dependencies patch, publication/deployment/Vault/production/certificates/public-management/release-artifact E2E work.

## Root-executed superseding P2 arithmetic table (conditional only)

Evidence E3=`docs/acceptance/evidence/m3/native-generation-accounting-worksheet/1792105443070191750/`; `prototype2-arithmetic1.json`/`.log`, parent actual collector exit0/join/source-stable,74guards/0unexpected warnings; tests_applicable=false, tests0, NOT_RUNTIME. Exact root command is recorded in its receipt and ran the evidence copy of P2 under nix develop/OTP28/Elixir1.18.5. Author did not execute it. Current /tmp P2 SHA `e8b78c9840bf16138c3a3feedbe0c31d0bb2058c0e9ff38a7a77d28a36fbc53e`; verify it against actual copied artifact before adoption.

For retained=0, M65,536: B=2,758,572; defaultM1,048,576: B=8,656,812. Both fixed points converged after2 iterations. For M>=the demonstrated specializations at identical integer encoding widths and retained0, table sum simplifies to6*M+2,365,356. This is an algebraic specialization, not a global formula across integer encoding transitions: the executable fixed-point worksheet is authoritative there. B remains conditional on the constructor gates above, not a runtime Admission constant.

| Role | Multiplicity | Complete cap at M65536 | Subtotal |
| --- | ---: | ---: | ---: |
| `context` | 1 | 8213 | 8213 |
| `plan` | 1 | 53 | 53 |
| `admission_update_payload` | 1 | 2063 | 2063 |
| `admission_update_wire` | 1 | 6198 | 6198 |
| `admission_update_reply` | 1 | 2116 | 2116 |
| `snapshot_requester_payload` | 1 | 2131 | 2131 |
| `snapshot_call_wire` | 1 | 6266 | 6266 |
| `snapshot_store_payload` | 1 | 2131 | 2131 |
| `snapshot_store_from` | 1 | 4123 | 4123 |
| `validated_manifest` | 1 | 65536 | 65536 |
| `partition_map` | 1 | 199551 | 199551 |
| `provider_handle_normalization` | 3 | 65536 | 196608 |
| `provider_request_payload` | 1 | 69676 | 69676 |
| `provider_call_wire` | 1 | 73811 | 73811 |
| `provider_owner_payload` | 1 | 69676 | 69676 |
| `provider_owner_from` | 1 | 4123 | 4123 |
| `genuine_provider_pin` | 1 | 75921 | 75921 |
| `provider_result_payload` | 1 | 75927 | 75927 |
| `provider_reply_wire` | 1 | 78002 | 78002 |
| `provider_store_received_result` | 1 | 75927 | 75927 |
| `checked_acquisition_accumulator` | 3 | 65542 | 196626 |
| `original_provenance` | 1 | 265543 | 265543 |
| `store_snapshot_payload` | 1 | 196612 | 196612 |
| `store_snapshot_wire` | 1 | 198687 | 198687 |
| `requester_snapshot_received` | 1 | 196612 | 196612 |
| `caller_capture_inputs_and_output` | 3 | 65536 | 196608 |
| `release_payload` | 1 | 65541 | 65541 |
| `release_call_wire` | 1 | 69676 | 69676 |
| `release_reply_wire` | 1 | 2116 | 2116 |
| `cancel_control` | 64 | 4124 | 263936 |
| `known_call_failure_descriptor` | 1 | 71806 | 71806 |
| `known_monitor_down` | 1 | 4164 | 4164 |
| `cleanup_observation` | 2 | 6276 | 12552 |
| `finite_failure_payload` | 1 | 41 | 41 |

Default M1,048,576 changes only the three snapshot-containing rows in this demonstrated integer-width range: payload2,162,692; wire2,164,767; requester received2,162,692. Their subtotals sum6,490,151, versus591,911 at M65536. All other rows sum2,166,661. The complete total8,656,812 is therefore independently auditable from the explicit role deltas. No current runtime bound/acceptance or public receipt maximum follows merely from this script's success.
