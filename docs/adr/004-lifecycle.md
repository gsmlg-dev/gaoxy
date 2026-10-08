# ADR 004: Coordinated lifecycle, Registry reconciliation, and bounded cleanup

## Cooperative shutdown

`Gaoxy.remove/3`, `Gaoxy.stop/2`, normal embedding-supervisor shutdown, and the
standalone application's `prep_stop/1` use the same service drain operation.
The instance dispatches every service barrier before awaiting any service. Its
children continue running their callback loops while the instance is terminating;
no child calls back into that terminating instance or its blocked supervisor.

A drain closes admission first. TCP/TLS stop accepting new connections while
admitted connections retain I/O. UDP keeps its original shared socket until
admitted datagram handlers finish. A stream lease ends when its connection ends;
receiving a response does not itself close that lease. On expiry or cleanup-helper
failure, the service forces owned resources closed and confirms their termination.
Control messages carry generation and operation tokens; stale results cannot
complete another drain or reopen its gate. The ordinary data path is unchanged.

The public timeout is **one total budget**, including lookup, barriers, draining,
resource confirmation and instance termination. It is not a fresh timeout at each
layer. A zero/tiny budget may return before the requested operation executes.
Timeout does not cancel that operation. Cleanup remains owned by the service;
there is one drain helper per service and one removal coordinator per service.
Repeated concurrent removal returns `{:error, :already_draining}`; concurrent
instance stop returns `{:error, :stopping}`. At most two service drain waiters
support a removal already in progress plus instance shutdown. Caller death does
not abandon cleanup. After removal completes, a repeated remove returns
`{:error, :not_running}`; re-adding creates a new generation.

| Public result | Meaning |
|---|---|
| `:ok` | Required resources and service termination confirmed before the public deadline; for instance stop the instance is also confirmed dead |
| `{:error, {:cleanup_failed, reason}}` | The cleanup operation failed, even if emergency cleanup subsequently closed its resources |
| `{:error, {:deadline_exceeded, :cleanup_pending}}` | Caller budget expired; completion was not confirmed to this caller, and owned cleanup may still be running |
| `{:error, {:services, [{id, error}, ...]}}` | Instance coordinator observed service failures and aggregated them |

A caller deadline can expire before the aggregate is available. Such a caller
gets the deadline error, never a fabricated aggregate or success. Confirmed drain
telemetry distinguishes `:completed`, `:forced`, and `{:cleanup_failed, reason}`;
`:termination_unconfirmed` explicitly records failure to confirm termination.
Polling `Gaoxy.info/2` until `:not_running`, or monitoring the instance after stop,
observes eventual completion. A local send result remains distinct from peer
delivery; forced pending sends retain their original operation and unknown outcome.

## Outer supervision budget

The initial instance drain budget is the maximum configured service
`limits.drain_timeout` (5,000 ms for an empty instance). Its generated child spec
adds **2,000 ms** of bounded cleanup/supervisor headroom. A service child spec
likewise adds 2,000 ms to its configured drain timeout. Services get no fresh full
budget during instance shutdown. Emergency resource confirmation is bounded to
1,000 ms; the outer headroom also covers terminating the service supervisor.

Because an existing outer child spec cannot be enlarged after startup, adding a
service whose drain timeout exceeds the initial instance budget returns
`{:error, :shutdown_budget_exceeded}`. Start with the needed budget. Explicit
operations can specify their own total timeout; concurrent parent shutdown still
caps its wait by the configured outer policy. Do not override the generated child
shutdown with a smaller timeout and expect the same guarantee. `:kill`, VM/process
termination, and noncooperative externally shortened budgets are outside the
cooperative guarantee. No worker child spec uses infinite shutdown to hide this.

Abnormal service/backend failures still restart under the service supervisor with
a fresh generation. Intentional removal, successful stop, and Registry outage
expiry stop normally and do not restart a listener. Cleanup inspects OTP ownership
metadata/links, excludes Registry and unrelated handler-linked processes, and
monitors captured descendants in addition to the backend root. QUIC permits its
direct host-owned raw reader; it retains the narrower **local host cleanup**
contract, with no pause or full protocol/application drain claim.

## Registry outage policy

Services monitor the public owner PIDs returned by registration for both lifecycle
and backend telemetry keys. A partition or whole-Registry failure starts one
operation-scoped retry timer: immediate reconciliation, then at most one attempt
per 25 ms for a **1,000 ms absolute window**. Both bindings must be restored under
the same process/generation before public management resumes. A partially
reconciled service returns `{:error, :registry_unavailable}`. Registry failures
cannot leak raw Registry exceptions through management APIs.

Existing traffic may continue within that bounded window. If reconciliation
expires, the service closes its resources and stops normally; it cannot remain
permanently invisible while listening, or create a restart storm. Other embedded
instances follow the same policy independently. Recovery during drain restores
visibility only; it never changes admission, starts a backend, overwrites another
process's key, or revives a removed generation. Backend telemetry is omitted while
its binding is missing, rather than attributed to another instance/generation.
Startup failure rolls back already-created resources. An abrupt Registry root
kill can also exhaust the Registry application's own restart intensity; externally
embedded listeners still follow the bounded fail-closed policy.

## Pause and resume

UDP pause is an admission barrier and retains the endpoint/memberships. TCP/TLS
pause unbinds/rebinds acceptance; an ephemeral port can change on resume. QUIC
pause is unsupported. Repeated already-paused/already-ready operations succeed
idempotently. Concurrent transitions return `:transition_in_progress`.

The gate stays closed during explicit `:pausing` / `:resuming` states. Backend
control runs in one owned, monitored helper (bounded by the lesser of callback
timeout and 1,000 ms). The service commits `:paused` or `:ready` only after backend
and gate coordination succeeds. Backend errors/exits/timeouts enter `:failed`
with closed admission and `{:error, {:transition_failed, operation, reason}}`;
resume from failed is rejected. Admitted work retains its existing resources when
the gate remains healthy. Gate failure triggers owned cleanup. A gate timeout is
an uncertain operation, so it is not followed by speculative reopening. Drain
cancels any pending transition and rejects its late completion.

Instances explicitly named through `{:via, Registry, {Gaoxy.Registry, key}}`
(including a registration value) also monitor that name's owner. On its loss the
instance drains with at most 1,000 ms and stops normally, instead of retaining an
unresolvable name. Atom-named instances such as the standalone release retain
normal service reconciliation. OTP may record registered parent names in
`$ancestors`; ownership confirmation recognizes the known direct parent's name
as well as its PID, without consulting a failing Registry.
