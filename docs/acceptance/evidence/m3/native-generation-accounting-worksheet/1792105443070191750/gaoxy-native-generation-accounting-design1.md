# Native pre-snapshot accounting foundation — design proposal 1

Status: SOURCE-ONLY PROPOSAL. No implementation, compilation, test, protocol, browser or accounting runtime PASS is claimed. Parent may adopt/revise this bounded recommendation under continuing authorization after the current resource-consistency slice closes. This is not a new human-approval stop.

Inspected worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, HEAD `8160e8bb6d7f55dc836b1aed0403cc2304a539bf`, plus the parent's Router/Generation resource-consistency changes. New consistency test/docs/evidence are parent-owned and untouched. Read-only source inspection; writes only the assigned proposal files in `/tmp`.

## Recommendation and precise scope

Split the next work into **accounted Generation capture** first and **native worker transfer accounting** second. First implement a deliberately selected managed-provider capture profile through a small optional core accounting-module seam. Preserve all legacy Generation/provider entry points and generic five/six-key pin receipts. The managed profile accepts only the already supported G/T capture vocabulary; it is selected explicitly for subsequent managed-H2 qualification. Core never imports/references a proxy module.

The first slice makes a real Admission decision before its Store snapshot request or provider pin effects. It reserves a source-derived whole capture allowance, validates genuine returned receipts, retains every capture, and cancels failed acquisitions using original acquisition provenance. It does not activate an H2 endpoint. The second slice closes native worker creation/dispatch ownership. Only after both and their independent reviews can a separate H2 Generation activation design remove the existing exclusion.

This accounting concerns serialized external-term payload of enumerated owned source roles. It does not certify heap, stack, arbitrary callback output, arbitrary mailboxes, VM, SSL/native allocation or private dependency internals. Do not reintroduce http_fetch#97 or equivalent evidence requirements.

## Source findings

* `generation.ex:107–132`: init stores `snapshot_bytes = 2*max_config_bytes`. call increments route_bytes and calls Admission.update before `snapshot_for_request`; then appends returned pins and releases this capture in `after`. The precharge exists, but its source description covers routers, not complete pin responses/capture provenance/control wrappers. It cannot prove arbitrary pins finite.
* `generation.ex:197–207`: Store pins its current Router resources, then replies `{:ok,generation,router,pins}`. Current generation is repeated outside the Router. The complete reply and provider exchanges need named ownership; a Router-only cap cannot simply be relabeled as complete snapshot cap.
* `resources.ex:11–35`: a single static manifest is raw-list<=64 and complete ETF<=65,536. These bounds apply to handles. `resources.ex:38–70` accepts any `{:ok,pin}`; there is no generic finite receipt contract. Its rollback reads fields from prior returned pins. Do not infer a pin-output bound from the handle-input bound.
* `exchange.ex:367–374`: retained_bytes counts buffer/head/trailers/route_bytes/protocol_bytes, not resource_pins. An accepted additional capture must remain represented in route_bytes (or a specifically justified replacement field) through later body/output updates; a one-off Admission delta alone is insufficient.
* `connection.ex:179–210`: H1 builds Exchange then updates admission before endpoint call. This does not preaccount arbitrary endpoint config. This first slice changes only accounted Generation capture, not a universal H1 configuration guarantee.
* `http2/connection.ex:479–570`: connection retains request/stream metadata before worker admission. start_next's Task closure refers to `state` and `stream`; source alone does not establish BEAM closure capture granularity. Narrow it to explicit scalar arguments in the later worker slice; never assert that a whole connection state is physically copied without evidence.
* `http2/stream.ex:6–16`: the worker exists before it acquires/begins its lease. `http2/connection.ex:1034–1067` sends Exchange plus endpoint tuple after protocol-stream admission; that reserve derives from header/read limits, not endpoint config or future Generation capture. This is a separate transfer gap, not solved by a new Generation validator.
* `managed_h2_group_accounting.ex:470–486` requires exact G/T receipts and captures<=64/65,536; `:captured_pins` is already a real HTTP pump gate. G has seven keys; T eight including holder. Generic five/six-key fixtures are a different supported contract. `http.ex:748–753` consumes this capture gate before group startup.
* `http.ex:242–246` rejects fixed H2/h2c Generation endpoints. KEEP THIS EXCLUSION. Pure Router sidecar validation deliberately leaves dynamic Generation stores opaque; do not turn it into recursive protocol qualification.

## Considered approaches

1. Increase `2*M` or the fixed/group reserve by an unexplained constant: reject. It does not bound generic receipts, identify owners or pay native transfers.
2. Globally restrict Resources pin output to G/T or 65,536: reject. It changes generic-provider behavior, confuses manifest and receipt limits and imposes a new protocol decision on unrelated consumers.
3. Add a universal recursive bounded-term/accounting framework: reject. This slice needs one existing managed capture profile, not a new general resource architecture.
4. **Recommend a small explicit optional accounting-module seam plus a managed implementation**, followed by the separate native transfer slice. It supplies a meaningful finite profile without core-to-proxy dependency or legacy schema changes.

## Minimal purposeful seam

Add one opt-in endpoint input form, `Generation.init({:accounted, store, accounting_module})`; existing `init(store)` and its initialized option map remain identical. The initialized accounted map has existing store/snapshot_bytes plus `request_accounting: accounting_module`. Do not add a global default, provider registry, process or dependency. Options.normalize already delegates endpoint init, so it needs no change.

The optional module exposes exactly three pure operations, both `@doc false` implementation contract:

* `capture_plan(max_config_bytes, existing_pins, context)` returns `{:ok, %{bytes: B, receipt_bytes: P, ...closed source bounds...}}` or a finite error. context contains original holder/store PIDs and deadline solely for finite scalar/control preflight, not Store lookup or provider calls. Validate existing captures before planning. Plan must include complete enclosing wrappers, acquisition-provenance records and composition scratch. Never serialize opaque dependency interiors.
* `validate_resources(handles)` returns :ok only for a bounded manifest of the selected actual managed provider modules, before calling any provider. It performs no pin/status/Store operation; provider-module membership alone does not authenticate a handle.
* `validate_capture(pins)` returns :ok or finite `{:error,:invalid_generation_capture}` / `{:error,:generation_capture_capacity}`. Managed implementation reuses the existing G/T capture validator unchanged. It must not trim/reorder/deduplicate pins, mutate handles or call owners.

Implement the managed module in gaoxy_proxy (proposed `Gaoxy.Proxy.ManagedGenerationAccounting`), core behavior in gaoxy_http (proposed `Gaoxy.HTTP.Generation.RequestAccounting`). The contract module is explicitly supplied by an embedding caller. It is not discovered by inspecting dynamic Stores. No static Router qualification or H2 gate removal follows from supplying it.

Accounted capture uses an internal checked Resources path (proposed `pin_many_checked/5`, existing four arguments plus pure validator), keeping existing `pin_many/4` untouched. A private common acquisition helper may be extracted surgically if this avoids duplicating current behavior. It records `{provider,owner,operation}` from the actual batch before invoking that provider. On validator failure or a later batch failure, cancel the current operation and all previously acquired operations through these original records, never through fields of an invalid returned pin. Cancellation is the existing public contract, not a newly invented successful-release receipt. `cancel` can fail/be uncertain; retain/report this honestly. No success may claim cleanup confirmed merely because cancel was sent.

Accounted Store request can use a distinct internal tuple `{:snapshot_for_request,holder,deadline,accounting_module}`. Existing public snapshot_for_request/3 and legacy Store tuple remain compatible. Accounted Generation.call preplans/admission-charges before this request. Store checks actual holder==caller and validates the actual current manifest through validate_resources before any provider callback. Checked acquisition correlates every accepted receipt with the original batch provider/owner/operation and exact batch handles, without requiring these extra checks on legacy generic receipts. Store validates each accepted accumulator through checked acquisition, and returns the unchanged public success tuple. On success, caller also validates **new pins ++ existing pins** before Router.call. A local 64/65,536 capture gate is the existing managed HTTP gate, not a global64 distinct resources or33 groups rule across opaque dynamic Stores. Failure to fit rejects this selected profile; never silently discard captures.

## Reservation derivation: no guessed new constant

Keep fixed Service **9,444,956**, group **16,478,862**, and group startup **5,963,776** unchanged. None pays for this new capture by assumption. New reservation is computed, not added to any of those constants.

Let M be the existing Store max_config_bytes. Let P=65,536 be the **explicit selected managed capture** cap already enforced by validate_capture; it is not a generic provider guarantee. H=65,536 is the existing per-static-manifest bound. k<=64 follows from one manifest's number of provider batches, not from all dynamic Stores globally.

Implement a pure executable source-role worksheet that pays, conservatively, for:

| Role | Bound and release point |
| --- | --- |
| Requester pre-snapshot controls and Store request | Actual complete call payload and source-derived local call-wrapper bound; ends at call return. No fabricated future reference or private process record. |
| Provider current handles request | H plus complete provider call shell; one serialized synchronous call at a time; ends on callback return. |
| Accepted accumulator input, current accepted reply, accumulator output | Each whole list <=P by the checked path. Conservatively reserve three P roles even if callbacks overlap less. These are named code roots, not a physical-copy assertion. |
| Acquisition provenance | Complete list of <=k original provider/owner/operation tuples. Use actual permitted provider module atoms plus the existing managed scalar ETF<=2,048 contract; derive list/tuple shell from ETF syntax. Retain through acquisition failure cancellation or success return. |
| Store final snapshot reply and requester received snapshot | Two complete enclosing envelopes. A safe reply bound uses router<=M, repeated generation<=M because it is a Router member, pins<=P, and exactly derived tuple/`:ok` shell. Do not charge only M+P while omitting repeated generation. Ends at Store callback/caller boundary respectively. |
| Caller combined capture input/output | Existing validated capture<=P, new capture<=P and accepted combined capture<=P; conservatively three P roles during composition, then only the full accepted capture role remains. No unbounded append before preflight. |
| Cancellation/release controls | One closed current public call/message shell, from actual original scalars and finite normalized errors. No history or arbitrary diagnostics. |

Use the sum of the named role bounds as B in the first implementation, explicitly conservative over phases; do not silently optimize alias lifetimes or subtract shared fields. The complete snapshot reply shell is measurable from closed ETF syntax, not guessed headroom. Future local GenServer alias/reference bounds must reuse the already reviewed local-node constructor reasoning (`node ETF+27` for reference), validate supported local host/scalar assumptions, and test real public envelopes. The exact executable formula and every numeric subtotal must appear in implementation evidence and independent review before READY; this source-only proposal deliberately does not invent a numeric result without those actual constructors.

Pre-admission charge must remain represented in the returned Exchange so later retained_bytes updates preserve it. Initially keep the whole B in route_bytes for this capture's request lifetime; do not refund on snapshot return while caller/Router/captured pins still exist. Existing conservative route_bytes lifetime is retained. On Admission refusal return the original Exchange and exact Admission reason before Store/provider effects. On later failure keep the charged allowance until ordinary request/lease teardown; do not invent a successful cleanup/refund. Nested accounted captures add their own B and preserve every outer capture; admission capacity, finite deadlines and selected managed capture limit bound accepted execution. No cross-Store inventory or new global resource maximum.

## Trust boundary and required honesty

A provider callback can return an arbitrary term before any local validator sees it. The accounted path proves bounds for accepted retained receipts and named supported source roles, not arbitrary malformed callback transient output. A post-return size check must never be called a pre-callback ingress bound. Managed G/T implementations are the qualified provider constructors; inspect their actual public output/owner records and validate that every supported success satisfies P. If constructor evidence fails, fix/design that bounded managed constructor before qualification; do not disguise it with a generic lossy projection or local upstream workaround.

Generic callbacks and old pins continue through the legacy path; no finite generic-output claim is added. This selected managed path therefore does not make every Generation request accounted or make the product ready for H2 activation.

## Acceptance of first slice

Use real Admission leases owned by the endpoint task, a real Generation Store and actual G/T public owners where applicable. A test-owned provider with public operation ledger supplies exact five/six-key legacy compatibility and invalid-receipt rollback cases; it is not protocol acceptance.

* Pure contract: exact role names, complete wrapper arithmetic, all scalar/byte/cardinality boundaries, unknown modules/shapes, no callbacks/Store/pin/timer/process effects. Constructor evidence explains every term; synthetic CALL descriptors are not extra payload roots.
* Before-snapshot barrier: block a real provider callback after observing its request. Public Admission.status already shows >=B plus original retained Exchange bytes. Test byte_limit by capacity B-1 and B exactly; denied path observes no provider request and unchanged Store/router/baseline. No sleeps.
* Actual native H1 and native downstream-H2 test endpoint barrier immediately after capture and before Router target proceeds. Assert route_bytes and public retained_bytes cover the accepted plan, correct original pins, and later body/output calls retain the same allowance. These are capture smoke tests, not the separate worker-transfer proof.
* Every managed receipt/combined-capture boundary: accepted64/65,536, rejected65/>65,536 where representable, and multiple dynamic Stores with independent local manifests. No claim of global64/33 handles. Existing mandatory G/T schema tests stay intact.
* Invalid callback/oversize/partial-batch failure: original provider operation cancellation identities exact; no Router dispatch or new upstream open; baseline unchanged. Public cancellation/join status separately recorded; unconfirmed cancellation is not zero accounting or success.
* Legacy init(store), public snapshot_for_request/3, generic five/six-key pins, equivalent sidecar ordering/duplicates and current generation error precedence remain supported.
* Store death/timeout at this seam returns existing finite generation error, preserves original request failure and never opens a target. This is not full managed H2 Store-death qualification.
* Fresh independent SPEC then CODE, affected gates after findings, source-bound evidence and local conventional commit before advancing.

## Deferred gates and risks

Next native worker slice must account its actual startup request/child input/endpoint dispatch before each transfer using explicit bounded arguments, handle pre-worker/refusal/owner death deterministically, preserve real Task/Admission ownership and keep protocol reservations intact until evidenced replacement. Do not introduce a test-only production hook: barriers come from test endpoint/provider public messages and controlled public Admission calls. Exact Task closure/start-request source/loaded-toolchain evidence is needed only for the claimed serialized roles, not total-memory proof.

Later H2 Generation activation still needs the downstream/upstream matrix, CAS/rollback/Store-death, same-authority CA/IP rotation,20 reload plateau, standalone and each-mode>=600-second load plus real independent peers/browser. Do not remove fixed/group protocol exclusions during either foundation. Native H3 capture compatibility is preserved, but H3 worker accounting is not qualified here.

Inherited counters remain group failed GREEN24 / ordered root repair events27 and Astra recovery2/2 exhausted. Proposal has zero runtime attempts and does not reset those counters. No new upstream issue, publication, push, deployment, Vault/production data, operational certificates, public management or release-artifact E2E work.

## Inspected source identities

Line references describe the inspected candidate, including the parent's in-progress sidecar insertion. Rebind to its actual closure commit before implementation.
| Source | SHA-256 |
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
