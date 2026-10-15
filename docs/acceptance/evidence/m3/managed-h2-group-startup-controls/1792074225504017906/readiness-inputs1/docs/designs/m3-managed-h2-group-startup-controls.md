# Managed H2 group canonical startup controls — design1

Status: ADOPTED FOR DESIGN-READINESS SPEC; tests and implementation NOT RUN. Root authenticated all author/canonical/predecessor inputs and fresh entry metadata; no test authoring before readiness PASS. The Probe/owner predecessor is actually accepted and locally committed as `1f32850e4d1cfd2e5c5b913e12bb574bfe924f5b`, tree `b4185c690df1ad113618fda7b0de63ec7a0d917d`. Root receipt `/tmp/gaoxy-h2-group-probe-local-commit1.json` SHA256 `d05f47eb1a789e07924df732958dacfed1b1710b36332142748ab485f70b6e81` authenticates131 feature paths and clean worktree. Implementation SPEC30/0, CODE15/0 and fresh format/forced compile/pure141/0/six-file H1 compatibility70/0 passed, zero skips/exclusions; the author read this receipt but did not execute those checks. Preserve predecessor implementation1/repairSol1/documentationRepair1/failedDocumentSPEC1/reportCustodyFailure1 and Astra2/2. Source authority is `N/gaoxy-h2-group-probe-transfer-inventory1.md/json`, where N=`docs/acceptance/evidence/m3/managed-h2-group-probe-boundary/1792070728396819458`; exact input hashes are in decision1.json. Broader transfer-accounting draft1 remains immutable and is deferred, not discarded.

## Bounded result and scope

Implement exact safe ETF projections and independent size formulas for **named successful normal/recovery Probe startup representations**. Cover owner-produced H1 args6/state18, prospective strict H2 args7/state23 and recovery args4/state5. Bind canonical generated spec, normalized child, local infinity call/from, gen/proc_lib input wrappers, complete init return, success ack/reply and temporary saved entry. Produce `STARTUP_TRANSFER_CONTROL_EVIDENCE_READY` only. This means a partial success-representation catalog is measured and source linked; it is never a universal startup cap, jointly maximal lifetime/overlap claim, aggregate reservation or runtime authority.

Use one small closed test-support module, two complete pure test files and a read-only metadata collector. No production module/interface/validator/constructor/Options/admission/gate/dependency changes. Preserve the fixed projector/reservation and current source/tests. Fixed9444956 and ACCOUNTING_NOT_READY remain. 9Q/8C/4K/2097152/11542108 are unproved/unadopted. No new processes, network/browser, certificates, Vault, deployment, publication, production data, public management or disabled E2E. Astra2/2 remains exhausted.

Owned new files:

- `apps/gaoxy_proxy/test/support/managed_h2_group_startup_projection.exs`
- `apps/gaoxy_proxy/test/managed_h2_group_startup_projection_test.exs`
- `apps/gaoxy_proxy/test/managed_h2_group_startup_catalog_test.exs`
- `scripts/managed_h2_group_startup_sources.exs`
- Root's adopted scoped design/plan/acceptance/evidence and implement-plan pointer.

## API and exact output keys

Namespace `Gaoxy.Proxy.ManagedH2GroupStartupProjection`; only exports `contract/0`, `project/2`, `phase/2`. `mode` is exactly `:h1`, `:h2`, or `:recovery`. Call `project({mode, kind}, original)` where kind is one table row below; no generic kind/schema/cap/count/marker registry. Return:

```elixir
{:ok, %{projection: safe_term,
        projected_etf_bytes: integer,
        payload_etf_bytes: %{config: [integer], url: [integer], health_path: [integer]},
        completion_shells: integer,
        unmeasured: exact_named_atom_list,
        bound: :per_instance_only}}
# or {:error, :invalid_startup_projection}
```

All six keys are exact. Lists are ordered occurrence sizes, not caller-supplied assignments. `projection` preserves complete wrappers/scalars except internally generated known-position payload/opaque/UNMEASURED markers. Each payload marker is paired with the size of the **complete original** validated field; no partial source/control projection is charged twice. `projection` itself is measured including its marker overhead, intentionally conservative when adding full payload bytes. Supplied projection markers are invalid in bounded original payload/shell positions. Known unmeasured positions are excluded by explicit source role, never claimed validated/bounded; their original interior is not traversed or ETF'd and never appears in returned diagnostics.

`contract/0` exact keys/values:

```elixir
%{version: 1, unit: :external_term_payload_bytes,
  disposition: :partial_success_startup_catalog,
  modes: [:h1,:h2,:recovery], kinds: [:arguments, :initial_state, :caller, :generated_spec, :normalized_child, :start_call, :apply_mfa, :gen_start, :gen_init_args, :proc_start, :proc_spawn, :proc_init, :gen_init_call, :callback_input, :callback_return, :otp_return, :init_ack, :child_start_result, :supervisor_return, :start_reply, :saved_entry, :child_state_action],
  phase_keys: [:arguments, :initial_state, :caller, :generated_spec, :normalized_child, :start_call, :apply_mfa, :gen_start, :gen_init_args, :proc_start, :proc_spawn, :proc_init, :gen_init_call, :callback_input, :callback_return, :otp_return, :init_ack, :child_start_result, :supervisor_return, :start_reply, :saved_entry, :child_state_action],
  reservation_bytes: nil, startup_maximum: :unproved,
  recovery_release_order: :unproved,
  fixed_reservation_bytes: 9_444_956}
```

`bound: :per_instance_only` applies to every mode: this slice gives exact sizes/formulas for each validated supplied representation, with no universal control/startup cap. H1 stays parameterized because current owner constructor intentionally accepts an arbitrary integer deadline, unbounded positive config-time integers and arbitrary binary URL. Do not reject those values or impose H2 caps on H1. Also do not certify H1 backing/heap bounds from serialized sizes. Initial state18 describes owner-produced H1 only, not broader direct legacy init.

## Original arguments and exact initial state tables

Use real `UpstreamGroups.probe_start_arguments/1`/`probe_recovery_arguments/1` on originals. No copying/normalization to repair an original before validation.

| mode | Exact args keys | Initial state exact keys/values added to those args | Result bound |
|---|---|---|---|
| h1 | owner, token, member, deadline, health, url | cleanup_deadline=deadline+1000; owner_monitor=ref; timer=ref; request=nil; original_request=nil; managed_transport=nil; transport_selection=nil; transport_pins=[]; terminal=false; cancelled=false; headers=false; outcome=:failure | per_instance_only |
| h2 | preceding6 plus group=H | same12 additions; client=ManagedH2Client; limits===member.config.limits; request_options=nil; submitted_url=nil | per_instance_only |
| recovery | owner, recovery={:selection\|:probe,ref}, completion, deadline | owner_monitor=ref ONLY | per_instance_only |

Owner/token PID/ref and exact Selected3/health/config/H/T are real-constructor contracts, not new test-only schemas. H2 complete `[H|H.transports]` passes real Resources.validate64/65536; keep supplied unique order and selected T exact membership. H1's existing broader constructor values remain accepted. Recovery keeps signed64 original deadline and exact public RequestCompletion shell4. Completion tracker/latch/unsupported interiors are never inspected/serialized/reconstructed, even if functions/large terms. Initial state validation reuses the constructor on Map.take(args keys), exact state key set, original values/identity and the table's added values; no Probe.init/process/timer call. All args/state mode mismatches/expanded members/unknown added fields reject.

Projection within each contained args/state: replace `member.config` with `{:payload,:config}` after complete validation and safe full ETF size; replace `url` with `{:payload,:url}`; replace `health.path` with `{:payload,:health_path}`. Keep Selected wrapper/id/max_inflight and every remaining health/control field intact. H2 `group` and its complete T list remain in control projection under the jointly validated manifest; additional state.limits remains a separately serialized five-field control value even though it aliases config.limits. Recovery completion becomes `{:opaque,HTTP.RequestCompletion}` only after exact shell-only validation; each containing representation contributes its own completion_shells count. No checked-client/scope/native lease exists in these initial shapes.

## Exact22-kind representation table

P=Probe; A=validated args; S=validated matching initial state; O=A.owner; D=local supervisor PID; C=child PID; R=start-call monitor reference; ParentName is exactly `Gaoxy.Proxy.ProbeSupervisor` (actual registered application supervisor); An is the raw process-dictionary Ancestors list captured by proc_lib, with **no claimed bound/interior validation**. All repeated A/S/O/D/C/R values in a phase must be identical. Every term below is an original representation, not an application-level new runtime wire. Tuples describing MFA calls name the actual function and full argument list; they do not imply those calls run in tests.

| kind / phase key | Exact original shape | Additional rule / unmeasured root |
|---|---|---|
| arguments | A | mode constructor |
| initial_state | S | exact state table |
| caller | `{P,A}` | owner DynamicSupervisor argument |
| generated_spec | `%{id:P,start:{P,:start_link,[A]},restart: :temporary}` | exactly3 keys; actual pure child_spec oracle |
| normalized_child | `{{P,:start_link,[A]},:temporary,5000,:worker,[P]}` | exactly5 tuple; significant:false not retained |
| start_call | `{:'$gen_call',{O,R},{:start_child,normalized_child}}` | **plain ref**, local infinity branch |
| apply_mfa | `{P,:start_link,[A]}` | resulting `extra_arguments=[] ++ [A]`; surrounding VM stack unmeasured |
| gen_start | `{:gen,:start,[:gen_server,:link,P,A,[]]}` | actual no-name GenServer.start_link defaults |
| gen_init_args | `[:gen_server,D,D,P,A,[]]` | exact proper6 list |
| proc_start | `{:proc_lib,:start_link,[:gen,:init_it,gen_init_args,:infinity,[]]}` | timeout infinity;5000 is shutdown, not startup timeout |
| proc_spawn | `{:erlang,:spawn_opt,[:proc_lib,:init_p,[ParentName,An,:gen,:init_it,gen_init_args],[:link,:monitor]]}` | An replaced internally with `{:UNMEASURED,:proc_ancestors}`; flag proc_ancestors |
| proc_init | `{:proc_lib,:init_p,[ParentName,An,:gen,:init_it,gen_init_args]}` | same unmeasured An role |
| gen_init_call | `{:gen_server,:init_it,[D,D,C,P,A,[]]}` | child default Name=self()=C |
| callback_input | `{P,:init,[A]}` | exact callback input wrapper |
| callback_return | normal=`{:ok,S,{:continue,:open}}`; recovery=`{:ok,S}` | no fabricated recovery continuation |
| otp_return | `{:ok,callback_return}` | OTP init_it(Mod,Args) outer wrapper |
| init_ack | `{:ack,C,{:ok,C}}` | proc_lib.init_ack success message |
| child_start_result | `{:ok,C}` | supported actual success only; no extra arbitrary term |
| supervisor_return | `{:reply,{:ok,C},DS}` | DS is source-defined private supervisor state; do not traverse/ETF, replace with `{:UNMEASURED,:dynamic_supervisor_state}` and flag that root |
| start_reply | `{R,{:ok,C}}` | local infinity plain-ref reply, not improper alias |
| saved_entry | `{C,{{P,:start_link,:undefined},:temporary,5000,:worker,[P]}}` | saved child map entry only; not full supervisor state |
| child_state_action | normal=`{S,{:continue,:open}}`; recovery=`{S,:infinity}` | explicit successful action/state pair; gen_server ServerData/Debug/internal stack excluded as child_private_runtime |

The final row always flags `:child_private_runtime`. `apply_mfa` flags `:vm_call_stack`. Ancestors must occupy the source outer list position (proc_lib get_ancestors returns a list or[]); no walking/serialization of its elements or assumption of depth. A non-list raw input is invalid for that modeled proc_lib output. DS is a map/struct in its known source role; its contents need not be bounded, traversed or validated by this proof. Full process dictionary, ancestor data, DS prior children and gen_server ServerData/Debug are **UNMEASURED**, not zero-size. Recovery sends the bounded `:recover` self-message, and normal startup installs its expiry timer; mailbox/native lifecycle accounting is outside the selected22 transfer representations. Neither is silently assigned zero size. The projected marker overhead is counted while the actual omitted term is named separately. Arbitrary values in other positions do not gain this exclusion.

Kinds that contain A/S recursively apply only the above known-position validation/projection; they do not call project on arbitrary terms. `project` checks table-local coherence (e.g. duplicate D/C/R identities and exact A-to-S table linkage). Parent root consistency for a complete catalog is checked by phase. Standalone callback_return/state rows validate their own A embedded in S; a separate A is not injected.

## Exact phase API and catalog semantics

`phase(name,bundle)` accepts name only `:h1_startup`, `:h2_startup`, `:recovery_startup`. `bundle` is a map with exactly the22 table keys; processing and output occurrence ordering follow table order. Each key contains that row's **complete original** value. It validates every project row and all cross-row A/S/O/D/C/R/An identities. Missing/extra key, mismatched startup mode/payload/reference, finite-call alias tag, extra arbitrary success, saved args not undefined or wrong continuation is invalid. `An` coherence uses strict equality of the original values only; no explicit traversal, element validation or ETF encoding. This establishes coherence only, not a bound. No user-chosen cap/count/slot/root list.

Return exactly:

```elixir
{:ok, %{disposition: :partial_success_startup_catalog,
        mode: :h1 | :h2 | :recovery,
        representation_count: 22,
        projected_etf_bytes: sum_of_22_safe_projection_sizes,
        payload_etf_bytes: %{config: ordered_occurrence_sizes,
                             url: ordered_occurrence_sizes,
                             health_path: ordered_occurrence_sizes},
        safe_catalog_bytes: projected_sum + all_payload_sizes,
        completion_shells: sum,
        unmeasured: [:proc_ancestors,:dynamic_supervisor_state,:child_private_runtime,:vm_call_stack],
        bound: :per_instance_only, startup_maximum: :unproved,
        reservation_bytes: nil}}
# or {:error,:invalid_startup_projection}
```

There are exactly11 keys. Fixed unmeasured order above; no data-bearing diagnostic. The sum is a **named representation catalog**, deliberately including representations from different steps. It is neither a claim that all22 coexist nor that these are all allocations/copies at an instant. Counting every named containing representation independently avoids sharing assumptions but does not prove an aggregate overlap/lifetime maximum. Four semantic startup roots from inventory classify these rows; four is not an assumed maximum. This package does not model Session startup or request/open/transport/group-owner/recovery held-record overlap; those remain explicit later stages.

## Independent parameterized formulas and coherent witnesses

Define `E(t)=external_size(t)-1` for safe ordinary ETF values (one version byte belongs to the whole term); `S(t)=1+E(t)`. Tests calculate expected wrapper sizes from this explicit grammar, independently of the support module:

- binary of n bytes: `E=5+n`; small tuple of k elements: `E=2+sum(E(items))`; map of k entries: `E=5+sum(E(key)+E(value))`.
- nonempty ordinary proper list k: `E=6+sum(E(items))`; empty list:1. ETF's STRING_EXT optimization is relevant when a fixture list consists entirely of byte integers: its exact nested formula is3+k for k<=65535. Startup wrapper lists contain atoms/maps/tuples and therefore use LIST_EXT. Ancestors are excluded before any list measurement. A finite Lifecycle improper alias From is a negative wrong-cohort fixture, never silently converted.
- integers: exact canonical SMALL_INTEGER_EXT, INTEGER_EXT and SMALL_BIG_EXT/LARGE_BIG_EXT lengths. For integer n outside signed32, let d be the minimum nonzero unsigned base256 digit count of abs(n); `E=3+d` when d<=255 and `E=6+d` otherwise. H1 deadline, deadline+1000 and config time scalars use their actual integer encoding lengths, never a signed64 cap by assumption.
- constants and actual accepted PID/ref leaves: use independently measured scalar leaf sizes `external_size(leaf)-1`, then substitute into explicit wrapper formulas. Exact constant atom encoding is checked against term_to_binary for the canonical runtime; no invented atom/PID/ref universal bound or maximizing claim. Scalar measurements are named parameters, not independent whole-row expected values.

Do not implement a generic ETF encoder, maximum search, marker registry or arbitrary-term walker. Formula helpers live only in tests. Every22-row expected projection is independently assembled from the table and the test's projected A/S expected structure; compare measured ETF bytes, payload occurrence lists, completion counts and exact unmeasured lists. Catalog expected bytes are the independently computed row totals plus full original config/url/path occurrences. It is invalid for expected sizes to call the projector, sum projector results or measure the entire row directly instead of using wrapper algebra. Runtime term_to_binary of each independently constructed expected row is a secondary grammar sanity assertion, not the only oracle.

Use jointly valid H2 contexts from the accepted constructor fixtures: same actual H manifest and selected T/config, original URL/root/path coherence, original deadline and matching initial state. Include1 and32 unique T entries when admitted by the real constructor and supported fixture caps; no independent sidecar maximum, fabricated padding/keys or claim byte-limit attainment. Keep the full H/T controls in each projected representation. For source-linked manifest arithmetic, let B be exact nested H-map bytes excluding only the transports value (retain its key), and T=sum(E(each transport)). Then `E(H)=B+6+T` and the full flattened list external size is `B+13+2*T`; check the equality on supplied admissible witnesses and the actual Resources validation. This is per-instance coherent arithmetic, not a proof of every accepted manifest maximum.

H1 fixtures retain original valid broad constructor behavior. Increase an accepted URL and accepted config time bignum/deadline, then require accepted projections and increased exact parameterized sizes. H1 backing-memory behavior remains governed by existing constructors; ETF evidence adds no backing/heap bound. H2 fixtures stay constructor-admissible but runtime-denied; no child is launched. Recovery fixtures preserve one original exact public completion shell across all representations; replace arbitrary interior values by functions/large terms in a second fixture and require identical safe projection/bytes with the exclusion explicitly reported. Do not ETF, inspect or reconstruct completion interiors, An or DS.

Universal scalar/control/config maxima, byte-limit maximizing fixtures and simultaneous lifetime bounds are outside this slice; this statement imposes no new proof requirement on later stage/release/activation gates. Existing constructor caps are validation authority, not newly proved memory maxima.

## Canonical source binding and exact coverage

Bind actual Elixir jc6g1.18.5 and OTP vp5phk28.5.0.7/ERTS16.4.0.6; six installed source hashes; DynamicSupervisor loaded/disk BEAM3da9dcd2... and actual current Probe source/BEAM. Preserve absence of stripped compile source metadata. Collector uses `mix run --no-start`, public pure Probe.child_spec/Supervisor.child_spec marker identity and metadata reads; no startup. Emit0tests/no_owner_or_probe_started and source/BEAM/package identities. Same-package source provenance is not source-to-BEAM reproducible-build proof. Historical22fy remains history only.

Source coverage table at acceptance has exactly these dispositions:

| Source branch/root | Required disposition |
|---|---|
| Canonical named H1 owner args6/state18 successful representations | PROVED_PARAMETERIZED_SERIALIZED_REPRESENTATIONS; no universal H1 cap |
| Exact H2 args7/state23 successful generic wrappers | PROVED_PER_INSTANCE_SAFE_REPRESENTATIONS; CONSTRUCTOR_ADMISSIBLE_RUNTIME_DENIED |
| Exact recovery args4/state5 and same opaque shell | PROVED_PER_INSTANCE_SAFE_REPRESENTATIONS; interiors excluded |
| Ancestors, full supervisor state, gen_server private state/stack/process dictionary | UNMEASURED_NAMED_EXTERNAL_ROOTS; no byte/lifetime bound |
| Arbitrary start exceptions/stack/extra-success/ignore/stop/DOWN/crash reports | NOT_COVERED_FAILURE_DIAGNOSTICS; source exists, rejecting input proves no runtime impossibility |
| Child timer/monitor/native resources/opaque completion internals | OUTSIDE_ETF_TRANSFER_SCOPE |
| Simultaneous old/new/call/reply/start/failed-child/owner/helper overlaps and release | STARTUP_MAXIMUM_UNPROVED; no simultaneous claim in this catalog |
| Transport versus group recovery release | ORDER_UNKNOWN; later authenticated release or separately bounded held-overlap design |

No omitted family is assigned0bytes or silently included in the catalog claim. Meaningful acceptance is exact safe success projection/formulas/cohort/source mapping with all explicit exclusions unchanged. Later owned-resource accounting may reuse these exact transfer/payload formulas. Whole-VM/native/process-dictionary/private metadata and arbitrary failure-diagnostic bounds are outside this finite catalog claim; they are not new mandatory stage/release/activation requirements or substitutes for dismissed http_fetch#97. Do not pursue or replace that issue. Concrete owner/helper held-resource overlap and recovery release coupling remain separate behavior/accounting questions under their actual product requirements; this catalog does not resolve them. Current recovered handler can release group while transport independently joins its helper; existing finish authenticates original guardian, so a new helper cannot solve order by calling it. Child-local original retention still is not owner publication; pre-bind completion=nil stays fail-closed/uncertain.

Gates remain readiness SPEC -> complete intended RED -> initial complete GREEN -> full implementation SPEC -> CODE -> fresh gates -> scoped local commit -> auto-advance. No routine approval pause and no assertion weakening/skips. Exact commands and ownership are in companion plan.

## Canonical row-to-source map

Line anchors identify the currently inspected installed files, not runtime tracing. Rebind hashes and anchors if canonical packages or accepted source change.

| Rows | Source authority |
|---|---|
| arguments, caller | UpstreamGroups.launch_probes/recover constructors and DynamicSupervisor.start_child entry |
| initial_state, callback_return, callback_input | Probe.init legacy/H2/recovery and init_group; no execution in tests |
| generated_spec | pure generated Probe.child_spec; Supervisor.child_spec public oracle |
| normalized_child | canonical dynamic_supervisor.ex430–475 normalization/defaults |
| start_call, start_reply | dynamic_supervisor.ex1148 infinity call; gen.erl233–250 plain-ref local request/reply |
| apply_mfa, child_start_result, supervisor_return, saved_entry | dynamic_supervisor.ex783–818 apply/success/save/temporary undefined args |
| gen_start | canonical gen_server.ex public start_link no-name/default-options route |
| gen_init_args, proc_start | gen.erl119–131 |
| proc_spawn, proc_init | proc_lib.erl266–269/326–332/510–515 and1198–1209 name/ancestors |
| gen_init_call | gen.erl193–206 default child PID name |
| otp_return, child_state_action | gen_server.erl2232–2279 and2596–2600 success return/action |
| init_ack | proc_lib.erl675 successful ack |

The marker-only metadata oracle proves generated child-spec shape against loaded public code. It does not trace private startup, execute these branches, or prove source-to-BEAM reproducibility. Independent source review binds each named modeled representation to the canonical source.

## Root adoption checkpoint

Adopted after actual predecessor commit1f32850e4d1cfd2e5c5b913e12bb574bfe924f5b/treeb4185c690df1ad113618fda7b0de63ec7a0d917d. Original author drafts and their checker-only row-count failure remain unchanged in the stage evidence. Root fresh entry metadata is exit0/joined/source-stable/zero tests; actual generated spec marker and current canonical source/BEAM identity match. Tests-first RED/initial GREEN/full implementation SPEC/CODE/fresh/commit remain NOT RUN. Current slice implementation0/repairSol0; all predecessor counters retained, Astra2/2 exhausted.
