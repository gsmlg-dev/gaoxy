# E4 source-only cleanup diagnosis 1

Status: SOURCE_ROOT_CAUSE_AND_MINIMAL_PATCH_READY_RUNTIME_NOT_RUN.
Direct bounded Sol diagnosis assignment; root owns every repository/runtime/
build/evidence/Git write. Repository/worktree is
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch
`codex/m3-h1-resource-foundation`, baseline
`7cff6e87edb9b67e2667897bfbb7ee7e0075162e`, with parent-owned dirty implementation.
Running root job58585 was not interacted with.

## One cause, two reported terminal reasons

Only the actual current controlled-live log was used:
`docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089/group-live-green1-1792093715236860711.log`.
It was active when read, so no final gate count or pass/fail conclusion is
claimed from its unfinished tail. Historical RED logs were not used.

The h2c cancellation failure at log13-114 and TLS-H2 opening-timeout failure at
log118-132 both terminate on a genuine original Task result
`{original_task_ref, {:error, :aborted}}`. The printed Session state has:

* `cancelled:true`, `consumed:true`, `cleanup_started:true`, `submitted_url:nil`;
* mutable `request:%{stream:nil,completion:nil,resolved:true,promise:nil}`;
* unchanged `original_request` containing the real Promise/Task ref and original
  `%HTTP.RequestCompletion{}`;
* original selected G and T tokens plus the original transport request pin;
* sanitized `config:%{limits:...}`, not a malformed config.

The ordinary `cleanup_failed cleanup_pending` entries at log135-138,
161-164 and182-185 show the same nil-capability mutable request sentinel and
genuine original request. Thus there is a single demonstrated root cause,
with a different terminal reason selected by the original completion race.
Do not patch `cleanup_pending` into success or weaken the original assertions.

## Exact call chain and boundary rejection

1. `http/session.ex:1321` settle calls `drop_group_opening` and `begin_cleanup`;
   line1324 clears H2 submitted_url. `drop_group_opening:573` also sanitizes
   group config, selector and request-preparation roles. The opaque original
   request is retained intentionally and correctly.
2. Session line1327 chooses `state.original_request` for the managed path.
   `ManagedH2Client.cleanup:80` uses its original completion, and
   `await_completion:60-67` calls `RequestCompletion.abort_and_await(original,0)`
   for cancelled requests. The dependency's public API at
   `deps/http_fetch/lib/http/request_completion.ex:99-102` sends `:abort` and
   awaits the same handle; timeout0 can truthfully return cleanup_pending at
   line133. A subsequent aborted Task result is expected, not upstream-bug
   evidence. Public client socket abort handling also returns aborted.
3. Session generic `handle_info:341-345` still passes this later message through
   `state.client.event(callback_request(state),message)`. Callback context at
   `session.ex:1823` for H2 is `{state.request,state.submitted_url}`. The mutable
   request is still unresolved before headers, while submitted_url is now nil.
4. `ManagedH2Client.context:339-369` validates a nil URL only when resolved:true.
   The valid unresolved original is rejected without its already-dropped URL.
   `event:113-120` then returns `invalid_context:490-492`, whose exact request
   is the nil-capability sentinel printed in the log. Session installs it before
   calling dispatch.
5. `dispatch:1217-1218` only now notices cancelled/consumed and calls settle.
   This terminal branch is too late to prevent response-event parsing from
   destroying the mutable request's valid shell. It never wanted the parsed
   event in the first place.
6. `ManagedH2GroupAccounting.session?:648-668` correctly rejects the new mutable
   request through `optional_handle?:624-625` / `handle?:613-621`: nil Promise
   and completion are not a valid original managed H2 request. The original
   request remains valid and continues to be used for real abort/join.
7. In Session settle's case at1334-1341, accounting error plus cleanup :ok reaches
   the fallback cleanup_failed invalid_request. Accounting error plus genuine
   cleanup_pending reaches the broad `{_,{:error,reason}}` branch and stops as
   cleanup_failed cleanup_pending. Those two reasons therefore depend on the
   completion timing after the same corrupting parser call.

The fixed path shares URL clearing and mutable-request parsing but `account/3`
at session.ex:684-686 returns :ok for non-group state. Its original-request
cleanup can continue despite the mutable sentinel. Newly enabled group state
validation makes the shared terminal-ordering error visible. The accountant's
strict shell and original-identity requirements should remain unchanged.

## Single minimal proposed repair

`/tmp/gaoxy-group-cleanup-diagnosis1.patch` adds a terminal managed-H2 handler
before the generic request handler. It matches actual @h2 plus a nonnil request
and cancelled or consumed. It retains the existing `account_state` and
`account_client_event` checks, then calls settle with the unchanged state.
Rejected controls still use the existing fail-closed local failure/cleanup.

This moves existing H2 terminal behavior before response-event parsing. It
does not expand a valid handle/context schema, grant authority, retain a URL
past its source role, replace a Promise/completion, skip original cleanup,
refund a ledger early, alter deadlines or change normal response handling.
Specific Service cancellation/owner DOWN/timer handlers remain earlier in
function-clause order. H1 and H3 generic event processing remain unchanged;
in particular H3 may need its client-specific cleanup-event processing.

The original real RequestCompletion tracker/join drives request cleanup;
processing an aborted result as a new response is not required to finish that
public barrier. Any late genuine Task result or Task DOWN remains subject to
the existing accounting control checks. Task monitors are released when the
actual Session exits. No response DATA ACK is fabricated. The exact original
G/T finish and Service cleanup sequence remains after confirmed original join.

A late successful response with a dropped provenance URL is still refused by
the existing task envelope validation, and local_group_fail continues genuine
original cleanup. This proposal does not permit a URL-free successful response
or add a terminal response bypass. It merely avoids invoking response parsing
after the validated terminal state has made that path unnecessary.

## Verification and integration

Patch changes only `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex`, +13 lines.
Source SHA256 at draft generation:
`52f17de068ec2746ae7eaaba69bb32614371396bee27f20d892cd69eaef63f04`.
Patch SHA256:
`0cb41d880db06e27c1e4c92aacbe2e76755f9bfbd775aa87dc3d58305f4850d5`.
The sibling JSON records five exact source hashes. Compare before adoption;
root may be concurrently changing owned sources.

Existing real cancellation and opening-timeout tests are the observed failing
regressions and retain their original normal-DOWN/completion/ledger assertions.
Queued cancellation at bind also traverses terminal cleanup. Root should run
those unchanged cases, then the prescribed full nonzero live/Session scoped
gates plus relevant fixed/H1/H3 compatibility. Neither this diagnosis nor the
patch has been compiled, formatted or executed by this author. All such checks
remain NOT RUN and root-owned. The root-owned stale initial health upload_end
fixture correction is a separate cause and is not included in this patch.

All own read and `/tmp` draft-write commands completed. No runtime actor was
started, signalled or stopped; no repository/dependency file changed. Local Sol
repair rounds:0 (proposal only). Inherited counters remain parent-owned and
unchanged; Astra2/2 is exhausted. No escalation or new product decision is
needed. Remaining risk is unexecuted patch behavior, requiring actual gates
and independent review before acceptance.
