# Generation compiled route/resource consistency design 1

Status: IMPLEMENTED AND VERIFIED; independent source SPEC/CODE and fresh affected verification PASS. Local commit custody is pending at this checkpoint. Companion plan: [implementation plan](../plans/m3-generation-resource-consistency.md).

## Source and custody

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; branch `codex/m3-h1-resource-foundation`; kickoff HEAD `8160e8bb6d7f55dc836b1aed0403cc2304a539bf`.
The preceding bounded managed-H2 group accounting/activation slice is DONE LOCALLY at feature commit `3fda219a6e166aad2d8e2a066cc7c4648f8dce9c`, closure commit `8160e8bb6d7f55dc836b1aed0403cc2304a539bf`. Its independently reviewed25 command gates/1752 invocations and fresh Chrome3/3 are bound by `local-commit-closure1.json` in the preceding stage evidence. This does not complete M3.

The original source-only preparation documents and readiness SPEC1 are archived byte-for-byte in `docs/acceptance/evidence/m3/generation-resource-consistency/1792103327760528135/`. Their old browser4/HEAD/counter statements are historical. Readiness PASS has no findings; all11 reviewed core/compatibility sources remain identical at this kickoff. Parent owns repository writes, runtime/build/formatter/evidence/index/Git. Agents write only explicitly assigned /tmp proposals and reports; they are not alone and must preserve all concurrent work.

Inherited group counters remain24 failed GREEN attempts/27 ordered root repair events; every earlier stream-local snapshot and exhausted Astra2/2 remain retained. This new slice starts with0 local repair/failed-GREEN events, never resetting inherited counters or permitting a third Astra recovery. No publication/deployment/Vault/production/certificate/public-management/E2E exception is granted.

## Problem and outcome

`Generation.Store.compiled_bound/2` validates that the supplied Router.resources is a bounded generic manifest, but never checks whether it describes the routes. A manually changed/prepared Router can omit a required resource, add a different valid resource, or substitute an old epoch. A static nested Router can carry the same incorrect sidecar into its parent, causing both levels to agree on an incomplete union.

Add a pure internal Router validator and call it from Store.compiled_bound before baseline acquisition. Recollect the expected resource union from the already compiled targets, recursively checking static Router targets, and compare exact resource membership after existing normalization. Reject an inconsistent prepared value with `{:error, :invalid_endpoint_resources}`. Do not repair the sidecar or call endpoint.init again. Accepted inputs remain the exact supplied immutable Router, including its original generation, route terms and sidecar order.

This closes resource consistency only. It does not activate managed H2 Generation, change native snapshot accounting or qualify recursively nested protocol endpoints. Those later slices retain their own designs/gates. Fixed Service9,444,956 and group16,478,862 are unchanged.

## Existing contracts that determine the design

- `apps/gaoxy_http/lib/gaoxy/http/router.ex:19-39`: compile_route initializes each endpoint once; the resulting compiled routes are collected and the router gets a new generation ref. `:45-63` collect_resources calls optional endpoint.resources(config), Resources.validate, then stable Enum.uniq union. Exceptions become invalid_endpoint_resources.
- `Router.init(%Router{})` returns the supplied compiled value directly; `Router.resources/1` returns its sidecar. Static nesting therefore must be checked recursively without compiling again.
- `apps/gaoxy_http/lib/gaoxy/http/resources.ex:12-30`: an input manifest must be a list of raw length<=64 and fullETF<=65,536, with generic provider/owner/owner_epoch metadata and supported pin_many/release/cancel callbacks. It returns Enum.uniq. Duplicate inputs within the raw bound are supported;65 duplicate entries still fail. No G/T public-pin schema is involved here.
- `generation.ex:440-448`: root generation ref/routes checks, input_bound, Resources.validate, generation_bound and full compiled-router byte bound all run before a Store baseline pin call. Public activate preflights this helper; direct Store activate repeats it. Initial router and prepared compilation also converge there.
- `generation.ex:452-488`: generation_validate is optional; known atom errors propagate and invalid returns/exceptions use invalid_generation_endpoint. Preserve this behavior and its existing ordering.
- Dynamic Generation has no resources callback, intentionally contributing[] to an outer router. Its current rights are captured by its own atomic invocation, not by inspecting another Store during static collection.

## Options and selected approach

| Approach | Result |
|---|---|
| Validate and compare already compiled targets, recursively for static Router | Recommended: a small pure seam, existing callback/normalization semantics, no new ownership. |
| Re-run Router.compile or endpoint.init to rebuild candidate | Rejected: can reinitialize/open new resources and change the immutable candidate. |
| Silently overwrite Router.resources with recollected handles | Rejected: publishes a different rights set from the supplied prepared value and masks malformed input. |

## Exact validation algorithm

Add internal `@doc false Router.validate_resource_sidecar/1` (name may follow repository style). It returns only `:ok` or `{:error, :invalid_endpoint_resources}`.

1. Accept a Router struct with a traversable compiled route list and resource manifest. Validate/normalize the supplied manifest using unchanged Resources.validate. The root Store already validates its generation ref. Do not introduce a new requirement that a static empty nested `%Router{}` must have a non-nil generation: static Router dispatch currently does not require one.
2. Reuse the current collection algorithm, adding a private validation mode. `collect_resources(routes)` used by Router.compile retains current behavior. `collect_resources(routes, :validate_nested)` used by the new helper validates each static `{Router, nested}` before reading its sidecar, then uses unchanged normalization/union logic.
3. For an ordinary atom endpoint module, attempt Code.ensure_loaded? before optional resources(config) detection. Preserve the existing absent/unavailable-module[] semantics; normal Router.compile still validates endpoint availability at initialization. This resource-only seam adds no new forged-endpoint grammar policy. Do not infer handles from arbitrary config keys. Preserve arbitrary supported provider modules and map metadata. Never call endpoint.init/call, provider pin_many/release/cancel/checkout/status, Registry/Store lookups or owner processes as part of resource consistency.
4. For exact static Router targets, require a Router value with a valid traversable compiled-target/resource structure, recursively validate it, then obtain its actual declared sidecar using Router.resources. This recursion is the only special endpoint handling. A malformed static Router config returns the finite resource error.
5. For `{Generation, initialized_config}`, follow the ordinary missing-resources-callback path, contributing[]. Do not inspect, snapshot, prepare, activate or pin that Store. Other endpoint modules remain opaque except their existing resources callback.
6. Compare `MapSet.new(normalized_supplied)` and `MapSet.new(expected_union)` with MapSet.equal? so equality is exact resource term identity. Accept equivalent membership in different order and duplicates that the existing raw<=64 normalization accepts. Keep the supplied sidecar unchanged. Router.compile retains its stable first-occurrence ordering and dedup behavior.
7. Normalize malformed resource returns, invalid manifests, callback raise/throw/exit and inconsistent membership to invalid_endpoint_resources using the existing collector rescue/catch pattern. Preserve finite deadlines and existing error paths outside this new check.

The new validation mode must not broaden Router.compile's static behavior. Its purpose is to protect Generation publication of an already compiled Router. Do not add caching, global visited-resource sets, resource freshness lookups, new public provider callbacks, new processes, dependencies or generic endpoint grammar redesign.

Trusted resources callbacks already have a metadata/pure role. Gaoxy introduces no owner effects here. This design does not attempt a theorem that arbitrary user-written callbacks cannot cause side effects; that is outside the supported callback contract and this slice.

## Store insertion and exact errors

Keep the existing compiled_bound order and insert the new check immediately after generation_bound and before final full-router size acceptance:

1. existing root `%Router{generation: ref, routes: list}` guard;
2. existing input_bound(routes, limits);
3. existing Resources.validate(router.resources);
4. existing generation_bound(routes);
5. new Router.validate_resource_sidecar(router);
6. existing fullETF(router)<=max_config_bytes.

Keeping the initial Resources.validate call preserves established error precedence; its bounded repeat inside the internal helper is simpler than a new caller-normalized public interface. All valid-generation targets retain their existing optional hook invocation behavior. Do not add Router.generation_validate, recursive protocol checks or change current hooks in this resource-only slice.

| Input | Error/result |
|---|---|
| Missing/extra/substituted/stale sidecar membership relative to targets | `{:error, :invalid_endpoint_resources}` |
| Nested static Router inconsistent with its own targets | Same resource error, even if outer and nested false sidecars agree |
| Invalid callback result, raise/throw/exit, malformed resource-bearing target traversal | Same finite resource error when reached by this check |
| Reordered or duplicate (raw<=64) equivalent sidecar | `:ok`; supplied Router preserved |
| Raw sidecar>64, fullETF>65,536 or malformed provider metadata | Existing invalid_endpoint_resources |
| Invalid root generation/routes | Existing invalid_prepared_router/input_bound error |
| Existing denied/invalid generation_validate callback | Existing callback atom error/invalid_generation_endpoint, with unchanged precedence |
| Route count, input/compiled byte bound, stale CAS, deadline or retired-release block | Existing exact errors and ordering |

A matching but genuinely retired/stale handle in both route config and sidecar is *consistent*. Provider acquisition remains authoritative for availability. This validator does not call an owner to declare that handle fresh. “Stale sidecar” regression means the sidecar's handle differs from the route callback's exact current handle.

## Paths and state preservation

All paths to Generation publication must reach the new check:

- Public prepare compiles input routes; forged Router terms can enter it as static Router targets. Store compile/compiled_bound then rejects their inconsistent nested sidecars. Do not pass a Router struct as routes to prepare and expect a new API.
- Public activate rejects a forged top-level or nested prepared Router during its existing client preflight.
- Direct `GenServer.call(store,{:activate,expected,forged,deadline},timeout)` is rejected by Store before new baseline acquisition, bypassing no check.
- Initial `Generation.start_link(router: forged)` rejects at activation; initial routes wrapping a forged static Router reject during preparation. Partial empty Store initialization must terminate through the existing startup-error path.

For an existing active Store, refusal leaves exact old generation/router unchanged, old baseline and held authentic request pins unchanged, candidate owner ledger unchanged, and no provider pin/release/cancel/checkout call from the validator. Existing deadline/CAS checks retain precedence. This is refusal before ownership acquisition, not rollback of a partially accepted new baseline.

The recursive walk is over the finite compiled term already subject to input/full-router byte limits. A dynamic Store PID is a leaf; no cyclic process traversal occurs. Do not add a global64 distinct-handle cap across separate nested Generation captures, a33 group cap or new nesting limit. Each static compiled router's existing sidecar and its collected union still obey their local64/65,536 rules.

## Acceptance cases and boundaries

Use a dedicated core HTTP test file and a small test-owned generic provider exposing bounded pin/event status. Test real Store APIs; provider public pins should deliberately retain the existing generic five/six-key shape, proving no G/T schema leak.

Required evidence: forged missing, extra, substituted-resource and old-epoch sidecars; self-consistent false outer+nested sidecars at multiple static levels; nested wrong type/malformed resource callback; duplicate/reordered equivalent acceptance; raw64/65 and ETF boundaries via existing Resources contracts; legacy absent callbacks and callback failures; dynamic Generation[]; canonical compilation/no extra init; each publication route above. For each refusal, compare public current snapshot and test-provider baseline/request-pin identity/event ledger before/after, then release the old request pin as its original holder. No private production owner introspection or synthetic success receipt.

Unchanged focused tests cover loader worker ownership, preparation/activation deadlines, rollback/reconciliation, optional qualification callbacks and existing generic provider release behavior. Required checks are planned, NOT RUN here. No protocol or browser capability claim follows from pure consistency acceptance. The preceding group browser acceptance has now completed as recorded above. Later managed H2 Generation work retains its separate qualification.

Kickoff promoted the independently reviewed source-only design. Implementation now adds only the pure Router validator/private compiled mode and the single Store insertion. All six prescribed command gates PASS with152 test invocations; independent source SPEC then CODE PASS with no open findings. Fresh post-review focused verification PASS61/0 at seed2. The existing91 compatibility cases were executed before review and are reused with independently confirmed unchanged runtime bytes. The combined count213 includes the repeated61 and is not a unique-test count. Exact receipts are indexed in the companion acceptance. All3 earlier normative document bytes are archived before this documentation-only update. No product decision or external permission is needed; local index/actual-commit custody is still pending.
