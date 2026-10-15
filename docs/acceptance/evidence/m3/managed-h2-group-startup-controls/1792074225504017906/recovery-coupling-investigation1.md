# Group/transport recovery coupling: source investigation 1

Task: probe_owner_author / group-recovery-coupling-investigation1.
Status: DONE for assigned source investigation only. Direct assignment, read-only repository access.
Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`.
Branch: `codex/m3-h1-resource-foundation`.
Baseline HEAD: `1f32850e4d1cfd2e5c5b913e12bb574bfe924f5b`.

## Verdict

Strict transport-before-group **recovery** release is not implemented and is not required to preserve the existing, separately admitted group and transport ledger capacities. Each owner must retain and independently reclaim its own holds. Releasing a group slot is not evidence that a transport token, transport payload charge, resource, or transport abort helper has been released. Normal Session/Probe cleanup does order transport finish/pin release before group finish; guardian-DOWN recovery has no equivalent cross-owner ordering.

This conclusion concerns the specified ledger counts and serialized payload charges. It does not establish a complete memory/process bound, approve H2 group activation, or adopt a new reserve. A distinct group-side result/exit gap prevents deriving a configured bound on all live group recovery helpers solely from held group records. This does not violate the proved record-count limits: no existing all-helper-process-count requirement is established by this investigation. Strict cross-owner ordering would not itself close that gap.

## Scope and provenance

Read source only; no tests, network probes, compilation, runtime tracing, Git mutation, repository edits, dependency edits, or delegation. Wrote only this report and its sibling JSON under `/tmp`. Existing modified/untracked startup-controls and boundary documents belong to the parent and were preserved; this is not independent review of those documents. Source anchors below are worktree-relative and apply to the source hashes listed at the end.

Counters: zero repair rounds consumed by this investigation. Parent cumulative Sol counter unchanged (numeric total not supplied in this assignment); Astra recovery 2/2 exhausted, unchanged. No escalation requested. No production bug is claimed or reproduced. No previously passing test counts are reused as current evidence.

## What each ledger actually holds

### Group owner: `upstream_groups.ex`

- Configuration admission charges `external_size(compiled)` plus serialized transport handles when present, bounded by max_groups/max_config_bytes/max_pins (445-505). It is not complete group-owner memory accounting.
- Selection checkout requires guardian caller, live group/pin/deadline, group inflight below compiled max, owner token count below max_tokens, and eligible member below max_inflight (556-575, 847-888). Each token stores key/index/original guardian/monitor, deadline, completion:nil and recovery:nil (865-873). Group/member inflight increments with token insertion.
- Only the original guardian binds the original public completion once (577-587). Normal finish requires that guardian and valid outcome but does not independently await completion (590-604); correctness of its normal cleanup order comes from consumers.
- Active H1 probe admission checks max_probes and accumulated probe_bytes plus exact reservation; a record stores bytes, original PID/monitor, deadline, completion:nil and recovery:nil; member.probe identifies the record (1007-1062). H2 group launch remains denied and starts no child (965-1005).
- Group pin release/DOWN/expiry removes the pin and reconciles groups, but does not remove live token/probe holds (708, 723-727, 788-845, 915-935). Reconcile can delete group configuration only with no pins, zero inflight, and no probes for that key. It does not query transport state.
- Normal/recovered selection finish removes the token and decrements exact group/member inflight (892-907). Probe finish removes its record, subtracts its stored bytes and clears member.probe (1064-1114).
- Actual guardian/probe monitor DOWN preserves the record and dispatches recovery (723-746). With nil completion it fails the group and retains the token/probe/inflight/bytes; it does not invent or retrieve the dead child's private completion (1127-1150).
- With bound completion it validates an exact four-field recovery constructor, retaining the original opaque public completion unchanged, and starts one tracked recovery child for that record (54-73, 1127-1147). Deadline is max(original deadline, now+1000); start failure fails the group without refund.
- Successful recovery accepts the stored recovery PID, demonitor-flushes its recovery monitor, then removes the token/probe immediately (750-765). Error result or observed helper DOWN fails the group and retains its hold (738-743, 767-773). There is no result-plus-helper-DOWN join on success.

Group owner defaults in `upstream_groups/options.ex:14-21`: tokens1024, probes4, config16MiB, groups64, pins1024, probe_bytes64MiB. Configured ceilings are tokens16384, probes32, config64MiB, groups1024, pins16384, probe_bytes512MiB (80-94). These are separate limits, not a universal byte total.

### Transport owner: `upstream_transports.ex`

- Module contract counts compact policy and metadata/control-slot serialized payload, excluding opaque scopes/completions, process heaps and socket/native allocations (5-14).
- Resource reservation retains policy and two finite lifecycle control slots; resource, pin and owned-payload admission are checked independently (760-849). Pin admission counts per-handle holds and serialized held payload (914-945); holder DOWN or authorized release removes pins, not request tokens (674-725, 1093-1106).
- Every admitted request gets a charged token payload plus original guardian/monitor, completion:nil and one abort-helper slot (1171-1214). Global max_request_tokens, per-resource32, and aggregate owned serialized payload are checked before admission. Pending old tokens participate in all three checks.
- Bind/finish authenticate actual caller as original guardian and match handle/resource/token (418-433, 436-466, 1217-1232). A group recovery child cannot call finish as a substitute guardian; the original public completion is not authority to impersonate that guardian.
- Finish without completion retires resource and retains the token; finish while abort helper exists returns cleanup_pending; otherwise only public await==ok removes the token (436-448). Unknown token finish is idempotent, not permission to drop a different hold.
- Guardian DOWN with nil completion retains token and retires resource (1263-1266). With bound completion it starts at most one abort helper per token; an already present helper is preserved (1268-1303).
- Abort result is matched to stored helper PID; DOWN is matched to its stored monitor (631-640, 712-718). `join_request_helper` needs result AND DOWN before clearing the helper slot, then requires result==ok and a fresh public await==ok before token removal (1305-1318).
- Pending/error cleanup can be polled without an active helper. Exhausted polling deadline retains charge/capacity; it does not refund an unconfirmed token (643-655, 1320-1332). Retirement also refuses token removal while an abort helper exists (1595-1602).
- Token removal is the operation that removes its payload charge and revisits resource settlement (1234-1249). Group record removal has no such effect.
- A resource without configuration pins stops admission; remaining pins or tokens defer ordinary retirement (1108-1149). Final resource removal requires transport_confirmed, custodian_down, opening:false, zero entry helpers, no request token for the resource, and no grouped multi-resource pin containing it (1513-1541). Completion success alone cannot delete that resource charge.
- Aggregate counts tokens, per-handle pins, entry/opening helpers and token abort helpers separately (1334-1355). Transport options have no defaults; configured ceilings are resources64, pins4096, request_tokens2048 and owned serialized payload64MiB (`upstream_transports/options.ex:5-12,17-30`).

### Consumers and original completion

Session binds transport first, group selection second from `state.client.completion(original_request)` (`http/session.ex:1199-1210`). Probe computes one completion from original_request, binds transport first and group probe second (`upstream_groups/probe.ex:669-680`). The sequence has a pre-bind window between the two calls; they are not atomic.

Normal Session settles original_request for managed paths, finishes transport, releases transport pins, then finishes group selection and service cleanup (`http/session.ex:957-975,1007-1030,1212-1242`). Normal Probe cleans the original request, finishes transport, releases pins, then calls probe_finished (`upstream_groups/probe.ex:771-841`). A pending/error transport finish does not advance normal group finish.

Recovery uses the original public completion only: Probe calls HTTPFetchClient.await_completion(completion,true), which calls public RequestCompletion.abort_and_await(completion,0) (`probe.ex:686-704`; `http_fetch_client.ex:24-27`). On ok, Probe sends its result and then returns a GenServer stop tuple. It does not finish a transport token or transfer original-guardian authority.

## Interleavings and exact count consequences

Notation: G=held group selection records; P=held group probe records; T=held transport request tokens; Ht=live/unjoined transport request abort helpers. Limits: Gmax/Pmax/Tmax; Tr=transport tokens for one resource. These counts describe ledger representations, not distinct requests or total VM memory. Per fixed owner:

- `0 <= G <= Gmax`, each group/member inflight stays within its configured admission cap.
- `0 <= P <= Pmax`, sum of stored active H1 probe reserves <= configured probe_bytes.
- `0 <= T <= Tmax`, `Tr <= 32`, `Ht <= T`.
- Charged transport resources/pins/tokens together stay within configured owned serialized payload admission, whose exclusions remain unchanged.
- For a fixed finite set of owners, the sum of these held-record counts is bounded by the sum of their configured limits. No fixed global bound on the number of owners is established here.

| Interleaving | Source-held state / refill | Consequence |
| --- | --- | --- |
| Normal confirmed cleanup | Completion ok -> T finish -> transport pins release -> G/P finish | Normal caller provides transport-before-group order. A failure prevents subsequent normal finish. |
| Both completions bound; G recovery wins | Original guardian DOWN reaches owners independently. G helper reports ok; G/P released while old T/helper may remain. Refill consumes new G/P and must independently pass T checkout. | Safe for separate held-record capacities. With Gmax1 and Tmax2, old T1 plus new G1/T1 gives G1,T2; never infer old T vanished. With Tmax1, new T checkout fails until old T releases; a new G hold may exist transiently without an admitted T. |
| T recovery wins | T helper result+DOWN+fresh await removes old T while old G/P remains until its own recovery outcome. | New unrelated T admissions may use transport capacity; they cannot use occupied old G/P slot without passing group admission. Safe for separate counts. |
| Transport bind succeeds, group bind not yet accepted; guardian dies | T has original completion and can independently abort/join/reclaim. G/P completion=nil fails group and retains its own hold. | No cross-owner release dependency; bounded but potentially permanently unavailable G capacity. Cleanup liveness is not guaranteed. |
| Neither bind accepted; guardian dies | G/P retains/fails; T retains token and retires resource. | Fail closed. The existence of a completion only in a dead child is not release evidence; no autonomous recovery guarantee for nil completion. |
| Group bound but transport unbound | Not produced by the current transport-first consumer sequence when both ledgers exist. Possible only with another API caller or no transport ledger. | Do not silently use this case to infer current consumer behavior. Independently, nil T remains charged; G cannot reclaim T. |
| Helper pending, bad result, startup failure, or deadline exhaustion | G failure retains G/P; T failure/pending retains T until its own allowed completion path. | Capacity/liveness loss is possible; no refund or counter overflow follows from the failed cleanup alone. |
| Release group config while transport hold remains | Group pins gone and G/P absent allows reconcile; T resource/token checks remain independent. | Group config refund is not transport record refund. New resources still pass transport resource/pin/payload admission. |
| Incorrect future implementation treats G refund as T refund | Dropping old T/helper or subtracting its charge based only on G result bypasses T auth/join/await. | Unsafe proposed interleaving; absent from traced source. Do not introduce it. |

The same one-old-plus-one-new overlap applies to an admitted probe ledger in principle, but current managed-H2 group activation is denied. Existing H1 probe due/health policy can delay refill; it does not establish cross-owner T release ordering. No H2 runtime acceptance is inferred from this table.

## Separate result-before-exit obligation

Tracked group recovery helpers are attached one-per-held G/P record. Before release, their count is at most `G+P`. On successful result, however, the owner demonitor-flushes and forgets the helper before observing process exit. Probe sent that result before returning `{:stop,:normal,state}`; its state still contains the opaque original completion until it exits (`probe.ex:29-37,686-690`; `upstream_groups.ex:750-759`). The application ProbeSupervisor is a DynamicSupervisor with no project-specific max_children setting (`application.ex:8-12`).

Let U denote helpers whose successful result was accepted but whose exit has not yet occurred. The source-proved expression is `group recovery helper processes <= tracked helpers + U`, with tracked helpers <= G+P. Current G/P admission does not track or bound U by a configured constant. With one selection slot, a finite schedule can process a successful result, preempt that helper before exit, refill the slot, and process a later recovery result before the earlier helper exits. After k such cycles the accounting representation can be G0 (or G1 after refill) plus k unjoined exiting helpers. This describes an allowed scheduling/count prefix, not an observed production accumulation, a permanent hang, an infinite execution under fair scheduling, or a quantified byte leak. Actual scheduling and termination normally allow helpers to exit; no configured overlap bound was found in the traced source.

Transport's result+DOWN join avoids this specific request-abort-helper refill gap: its token remains held through helper DOWN. Forcing transport release before group release alone would not prove group helper exit; even after T is gone, G can still send its result then be preempted before exit. A cross-owner coupling feature is therefore not the smallest source-justified repair for this obligation.

Related limit: normal Probe calls probe_finished before its own process stop (`probe.ex:803-810`), so any later claim bounding *all* live Probe processes solely by P must also account for normal result/reply-to-exit overlap. This investigation does not propose changing normal cleanup semantics or quantify that overlap.

## Recommended smallest later slice

The immediate next deliverable should state which group-local lifecycle holds the future accounting contract actually charges. The concrete existing max_tokens/max_probes/probe_bytes limits constrain held records/reservations; they do not expressly establish a cap on all exiting helper processes. Do not make a new universal helper-exit proof a gate. If a bounded later slice explicitly uses one retained G/P slot to account for each live recovery helper through its exit, the minimal source mechanism is **group-local recovery result/DOWN accounting**, independently from transport release ordering. Preserve original-guardian authentication, original public completion identity, finite deadlines, nil-completion retention, once-only settlement, all existing assertions and current H2 denial. For that explicit through-exit contract, recommended behavior to design and test is to retain G/P charge and recovery slot until matching successful result and matching helper DOWN are both observed, with explicit behavior for failed result or DOWN without acceptable result. This can be implemented locally by storing separate authenticated result and monitor-DOWN facts on the held record and using one settlement function from both handlers; it requires no T/G authority transfer or cross-owner protocol. Do not infer success solely from DOWN.

Use deterministic barriers/controlled child lifetime to verify no refill before required group-local evidence; then verify G-first/T-first recovery does not bypass either ledger's admission and that pre-bind nil cases retain holds. If a full normal-Probe process bound is a later acceptance requirement, include its normal finish-to-exit overlap in that separately stated slice rather than claiming recovery-only work covers it.

This is later-stage preparation, not an instruction to edit current startup-controls documents or production code now. Parent decides stage scope and ownership. No new reserve, new activation, recovery authority transfer, strict cross-owner barrier or universal dependency/VM/native/private/diagnostic memory requirement is justified by this investigation. Fixed reserve9,444,956 remains unchanged; 9Q/8C/4K, extra2,097,152 and total11,542,108 remain hypotheses, not accepted accounting.

## Unknown / not validated

- No runtime or deterministic scheduler test was executed; recovery concurrency and actual U were not measured.
- No full lifetime/process/heap/opaque-completion byte bound is established by count constraints or serialized payload ceilings.
- No guarantee that every nil-completion hold eventually releases, that every successful cleanup is promptly observed, or that failed group capacity automatically recovers.
- No H2 group activation/admission reserve proof, no publication/deployment acceptance, and no external/upstream status verification.
- No new assessment or replacement proof for dismissed http_fetch#97.

## Verification and command completion

PASS: read-only HEAD/branch/status inspection and targeted `rg`, `nl`/`sed`, SHA-256 source inspection; all commands completed with exit0. Initial HEAD matches assigned baseline. Repository edits were not made by this task. Source hashes are checked again when final artifacts are validated. Tests/build/runtime/network: NOT RUN, as explicitly prohibited for this assignment. Artifact validation: PASS; JSON parse, all eight source-hash equality checks, matching assigned HEAD, report-file existence and Markdown SHA-256 linkage checked fresh. See sibling JSON/final handoff for source and artifact hashes. No running task-owned processes or sessions remain. Remaining work is parent-owned design, implementation and independent verification of any accepted later slice; no user decision or new permission is needed for this investigation.

## Source SHA-256 inventory

- `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex`: `6b4aa4be3ab570c9698979bb464b5b8279e0aebf7b291248f593cdff7e35fd65`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/options.ex`: `cc20a304f5d4c5930224a989a2ed65ee7f3162fe86a95276132c584e741f6473`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/probe.ex`: `9f3de8e0fc74f8ebfe358629d3e11ca6c65ee20c34fe4043b4b2770f199bcd63`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex`: `f6f638d1f1f88b53c8282dc121466eb0614d241fe8ec56cc57a8a2a8b0d4096e`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports/options.ex`: `c3a7b5b56f7fc0f6bf843de2600920316bd525577f69cdd69214f80626dd9a5e`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex`: `82fa47d3cd53343b64afce1e9703defbe09dead95b8133baa86d455e604fdce1`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex`: `a4f6e5f6a2e7212ab641c8a33bb10d177d9ffba008362945620b6aa6e402cf22`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/application.ex`: `0142d4ba20e942f702fab7b99a0938d3efcbb61253cb2f102d9f8c72e6fbc708`
