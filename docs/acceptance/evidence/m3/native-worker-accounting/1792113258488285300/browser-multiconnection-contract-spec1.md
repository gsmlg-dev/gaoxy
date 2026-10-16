# Native browser multiconnection contract SPEC1

Task: `native_worker_constructor_spec/browser_multiconnection_contract_spec1`

**DONE — recommend a deliberate complete-cohort contract correction, with the conditions below.** It is admissible under Task5's original resource-proof wording. It is not a literal logical strengthening of the old `global active==3` predicate, because it permits fully proved extra connections; it removes an unsupported browser-topology assumption while strengthening attribution/completeness. No unknown lease may be filtered, subtracted, ignored or given its observed bytes as its expected reserve. This is source-only SPEC advice, not actual-source fixture review or runtime/acceptance PASS.

Parent-reported diagnostic4 remains FAIL: selected client-side EOF after TLS ready, direction0 with1983/1398 bytes copied, empty queues, two extra frontend attempts rejected; actualexit1/join/groupsgone/source stable. This report did not read runtime/raw trace artifacts. The first-selected relay is not recommended for this Chrome acceptance; all diagnostic failures remain immutable. Original browserGREEN2 target-writer cause remains **UNKNOWN**, and its early-writer guard must not be removed.

## Task5 basis and explicit revision boundary

The original Task5 clause requires actual Gate bytes from independent N/W/B expectations **plus ordinary connection/writer/other observed reservations; no summing unrelated or overlapping leases**. Current `docs/plans/m3-native-worker-startup-accounting.md:120` retains that text. This allows an exact, fully attributed native-listener cohort; it does not require Chrome to open only one physical connection. Current line116 separately codifies the subsequently added isolated exact3/2 profile. That profile and historical fixture must be explicitly superseded/archived by the new written contract, never silently called unchanged or retroactively passed. Use a new immutable direct-browser fixture and independent SPEC→CODE before fresh H2/H1 qualification. No production API, listener limit, dependency workaround or synthetic page is required.

## Preserve the target proof exactly

The selected request still has exactly the original three disjoint role identities in H2: native connection C, its actual writer R, and target requestworker W. They are an exact identified subset of the service cohort, not a replacement global count. Keep the exact95-row independent W constructor proof, original scalar widths, W+B lease bytes, deadline/token/parent-lease/spawn linkage, secure native TLS/ALPN h2, real G7/T8 owner effects/correlation/receipts/Session derived custody, complete upstream response, request release and normal worker/Session joins. No extra requestworker or request dispatch is automatically allowed; anything beyond this expected one request needs explicit independent role/constructor proof or FAIL.

**Keep target C and R alive/unjoined through request_clean and the existing explicit host close-authorized handshake.** A target writer normalDOWN before that phase still FAILs. Cohort generalization does not explain or excuse originalGREEN2. Target request clean still requires its worker lease gone and exact original C/R reservations retained (subject only to their proved send-operation fields, with original accounting semantics); global ordinary extras are reconciled separately at that same boundary. Final service/Gate active0/bytes0/cleanup0 and authentic normal actor joins remain exact global invariants.

## Exact cohort invariant at every proof boundary

For each boundary i, obtain a single immutable Gate state snapshot S_i with its own exact public aggregate P_i and entire lease keyset L_i. Build a disjoint role ledger from genuine identities and independent constructor expectations, then assert:

1. `L_i == proved_lease_refs_i` exactly, with unique PID/lease/role mapping and no duplicate counting or unknown entry.
2. Every actual lease's PID, bytes, parent/owner linkage and relevant request/deadline/monitor/cleanup/send fields match that role. Every ordinary C/R reserve comes from independent arithmetic and its actual normalized options, not from summing stored byte values.
3. `P_i.active == |L_i|` and `P_i.retained_bytes == S_i.bytes == sum(independently_expected_role_bytes_i)`; cleanup remains0 at the existing capture/clean checkpoints. Unexpected cleanup is FAIL rather than an arbitrary additional allowance.
4. Target lease W+B is exact at EACH pre-provider-owner effect and capture boundary; its exact C/R identities remain present and live. All applicable target spawn/token/deadline checks still apply.

Do not replace this with `active>=3`, `retained>=W+B`, `sum(gate.leases[*].bytes)`, total-minus-extras, or a status-only check. Such checks cannot prove target admission or full attribution. The ledger must include every Gate-owned actor for this exact instance/service/generation; upstream health/probe/provider actors on different owners/Gates are not imported into the native cohort. Unknown role, reserve mismatch, overlap, missing/late receipt or impossible transition FAILs.

Chrome extra lifecycle is asynchronous: a snapshot may contain a connection whose writer has not acquired yet, or a retained lease whose owner's DOWN is not processed yet. Do not force a `2*k+1` formula or fabricate a complete pair. Prove each actual lease and transition, including exact parent linkage and monitor identity; an unobserved transient role remains FAIL/UNKNOWN. Actor live checks are mandatory for target C/R, while ordinary retained-after-exit records must be reconciled against authentic recorded terminal/cleanup transitions, not excluded.

## Preeffect snapshots must be local to each original owner effect

Current host7 installs each real provider owner's `:sys.install` input observer before browser start (`host7.exs:576–596`). Its `{:in,{:"$gen_call",{store,_},{tag,batch,holder,:request,op,d}}}` hook runs before that owner's handle_call effect. Today it records only `Gaoxy.status`, then later incorrectly requires BOTH original aggregate totals equal the capture total (`host7.exs:814–818,844`). Extra ordinary connections can legitimately change between these points.

The revised observer must take an **independent complete atomic Gate snapshot per owner effect**, correlated with owner/store/holder/operation/batch/deadline and that status invocation. Validate the target lease's exact W+B at that time. Owner1, owner2, capture and request_clean may have different ordinary cohort keysets and totals; each must pass its own complete invariant, and every difference must be explained by the continuously observed lifecycle ledger. Do not retry the provider effect or wait for extras to disappear until global3 happens. A later snapshot cannot prove a prior owner-effect admission.

## Existing observation seams: no public Gate getter

`Gaoxy.info/2` exposes id/generation/transport/mode/local/pause/drain (`service.ex:158–173`); `Gaoxy.status/2` exposes aggregate admission/service fields (`176–186`). Neither exposes Gate PID or lease map. `Gaoxy.handle/2` and add return only id/generation. Do not invent `info.gate` or use private Registry/instance state as a public API.

Recommended existing **test observer** route before any browser connection:

- Attach to the existing `[:gaoxy,:lifecycle]` ready event before service add. `Service.init` emits this synchronously from service PID (`service.ex:59–60`); callback `self()` identifies service (use instance/service/generation scope and ready event to avoid wrong-service binding). After `Gaoxy.add` completes and before emitting fixture ready, test host reads `:sys.get_state(service).gate` and verifies generation/spec against the returned public handle. Existing repository tests already inspect service.gate (`apps/gaoxy/test/lifecycle_acceptance_test.exs:65`, registry/shutdown tests). This is a supported OTP test inspection seam, **not a new Gaoxy public getter or production dependency**.
- Install a test-owned Gate `:sys.install` observer before launching Chrome, so it sees every native lease admission/release and status proof from the beginning. Project only scalar ledger fields. Existing HTTP checked-capture tests use `:sys.install` before Gate updates (`generation_checked_capture_test.exs:1442–1464,2004–2025`); host already uses the same mechanism for provider-owner input and cleanup attachment. Do not suspend/replace Gate state or change capacities.
- Alternatively, an outer test-only public `Gaoxy.HTTP.Endpoint` wrapper can register scalar gate/lease/holder/deadline/transport identity in test-owned ETS synchronously before delegating to real `Generation.call`. This yields target context before provider effects without changing `ManagedGenerationAccounting`. It changes actual endpoint constructor data and therefore requires fresh binding/calculation of all95 roles; never reuse stale W. It is a fallback, not necessary if early service observer supplies Gate.

`Generation.call` itself constructs `{store,self(),gate,lease,:request,deadline,retained}`, computes B, commits actual Admission.update and only then calls Store/provider path (`generation.ex:132–145,269–279,443–446`). `Generation.Accounting` is an existing public callback contract; tests instrument reservation context (`generation_checked_capture_test.exs:788–800`). A test wrapper may observe this supported seam if needed, but it must delegate the genuine accounting/receipts and bind resulting constructor values; never replace original managed proof with a fake accountant.

## Match aggregate and ledger to one Gate state

A sequential `:sys.get_state(gate)` then `Admission.status(gate)` is NOT an atomic pair while extras mutate. Source `Admission.handle_call(:status)` computes active/count and bytes from its exact current State (`admission.ex:472–482`). Installed OTP28.5 `gen_server` debug event contains `{out,Reply,From,State}` (`gen_server.erl:2591–2594`). A preinstalled Gate debug hook can observe the exact `:status` request/response, correlate by caller/tag, and project **the same State** plus returned public aggregate. No reentrant Gate call may occur from its own debug callback.

Thus each provider input hook calls direct public `Admission.status(gate)` before returning to the real owner callback. The Gate out observer records exact reply/From/tag plus safe scalar state projection for that invocation. `gen_server` sends Reply immediately before running out-debug callback; its immutable State still denotes the status-response linearization point before the provider hook returns and the owner effect begins. Recorder delivery can occur later or out of cross-process order; correlate references/owner-operation/sequence rather than asserting wall-clock log arrival proves order. Gate debug callback must not wait for provider/Store/host or write raw state. Preserve finite deadlines and fail if proof receipt is missing.

This uses public OTP debugging rather than adding a production atomic-snapshot endpoint. Keep source-bound OTP event shape in evidence; no claim that arbitrary runtimes provide the same observer receipt.

## Lifetime ledger and authentic teardown

Record all actual native connection start/ready and terminal PIDs before capture using the reviewed safe telemetry whitelist/projection. Record Gate lease acquisition/ref/owner/reserve and release/DOWN transitions from the start. Bind ordinary writers to their actual native parent (e.g. exact sanitized writer-ready/start identities or whitelisted native connection state fields), not merely similar byte values. No raw TLS state, sys replies, arbitrary messages, reason strings or exception fields may be logged. Full-state inspection may occur in local test code only with explicit safe projection before any artifact/output.

Every cohort actor ever admitted remains owned until authentic monitored/recorded join, including actors already gone at capture. A late monitor reporting :noproc cannot establish its original reason. Retain exact source-supported terminal reason checks; any permitted ordinary speculative connection close must be explicitly enumerated and proved (clean peer_closed with its actual writer normal join, or a separately reviewed pre-admission handshake lifecycle), not inferred from noerror telemetry or accepted as arbitrary normal. No extra actor may be killed or forced merely to attain expected accounting. Strict upstream peer empty-idle-reset policy is unchanged.

After request cleanup, the target W is gone and C/R remain exact/live; every additional live ordinary lease is still accounted independently in the current cohort. Browser.close only after the unchanged target authorization; then every cohort actor and lease/cleanup must genuinely converge to global0 and all owned browser/host/upstream/observer/logreader/process groups join normally within existing finite deadlines. Force is FAIL. H1 needs the analogous complete native connection ledger while keeping its target retained+B and real request proof exact. Browser native TLS/ALPN/CDP h2, visible full response and screenshot remain required.

## Review and evidence disposition

Prepare a written correction explaining old exact3/2 assumptions and new exact role-set equations, then independent actual-source SPEC→CODE of the new fixture; fresh H2/H1 and existing scoped gates on the same frozen production source. Preserve all old failed runs/assertions, no failed or NOT RUN gate becomes PASS. Test-only actor bookkeeping/observers require finite bounds and normal joins. Unknown transient cohorts may make qualification harder; that is an honest failure rather than permission to weaken role proof.

Read-only commands inspected scoped plans/source/test observer examples and installed OTP source; no actor, Mix/test/browser/network/Git command ran. A few bounded searches used guessed absent paths/globs and were corrected; they are search mismatches, not runtime/test failures. All own commands finished. No repo/evidence edit or raw runtime artifact read. Only this `/tmp` report was created.

Counters preserved: group37/root48/stage7/Astra2of2; parent diagnosticfails4. This investigation adds0 runtime/failedGREEN/Sol repair rounds. Full stage remains OPEN; original target writer cause remains **UNKNOWN**. No new user product/publication decision or upstream defect is established by this test-contract correction.

Reviewed SHA256 identities:

- `docs/plans/m3-native-worker-startup-accounting.md`: `527d13a932d48cde4f0ad233ab5e12ffb18b2dc66e9b588dd8b1e7a4dd060751`
- `apps/gaoxy/lib/gaoxy/service.ex`: `740d69a364e52cda9d05a997136ce864e9ec464149adcc81045bc9c109ed4472`
- `apps/gaoxy/lib/gaoxy/admission.ex`: `81c96e55e56d514f4bd93cecb7af906a55279927d3f100f7b2045181f1eaf107`
- `apps/gaoxy/lib/gaoxy.ex`: `f996f20926086b80f79aa66c82253164430616ffac15118f87bd8a88bc00fa5e`
- `apps/gaoxy/lib/gaoxy/instance.ex`: `510bcf614c5a289fbd6c454693930b68c09bd9bdd8510a547e458cca54838dcf`
- `apps/gaoxy/lib/gaoxy/telemetry.ex`: `749421579aa4d6c5c8d8def5d9cdf502a59c7aa194203a8fb6c3051de1b72961`
- `apps/gaoxy_http/lib/gaoxy/http/endpoint.ex`: `47583a44f422da86bfd98054ce148328f53a79b6b11ce0d85cf2c45cf721ab93`
- `apps/gaoxy_http/lib/gaoxy/http/generation.ex`: `4eeaa5bb6bcc65d181cec52a7fbcd9344c7d327746ef9ec8a10cec0a3cb7630c`
- `apps/gaoxy_http/test/generation_checked_capture_test.exs`: `b5acda74cf15a5213444dfe4590e1261994fdd9a8bc24268232fdc9f8e1eea8b`
- `docs/acceptance/evidence/m3/native-worker-accounting/1792113258488285300/native-worker-browser-diagnostic-host7.exs`: `a8e19636c70e338bb32574f6896058f9214d1bbc5f6e850e6a657140ef39b513`
- `/nix/store/5y0714j8czhkjbmjb6l6m46n5w5fyr6q-erlang-28.5.0.5/lib/erlang/lib/stdlib-7.3.0.1/src/gen_server.erl`: `66a4a649c8ed58f3c9ed317047f28ea2e2a61b38032cc467565fbad2c53a09db`
