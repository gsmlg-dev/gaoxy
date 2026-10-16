# Native worker numeric accounting proposal

Task: native_worker_accounting_impl. Direct source-only assignment. Source proposals
only; NOT RUN for all compile, format, tests, application/runtime, network or W use.
Repository R=/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation,
baseline 58307a7084298db309a93697b9102b2cc4c87eda. Root owns repository integration,
runtime gates, all other writers and Git. No repository file was modified here.

Final source-only binding:

* accounting proposal SHA256 aef39aff4182afca78aa2bf6f6f993a2adece1b64b0a69a1cdc190368147e0a4
* constructor tests SHA256 0e74b92bde9ef75dcdaf9775a7e9c36f202e9afea2fff31e8926301a806dc144
* core draft SHA256 59a0cb66668bdabcfb039ced1bce9f27e9f20e092723f4f50ed933d823260439
* bootstrap draft SHA256 690f28e66240e9047eba6a463b192bbedbdad2f6b14220a04a1773878122e227
* connection draft SHA256 2339365e821ccf6688e2b8de910809a4d5d8f633f17de92a0f554e578b52978d
* Stream draft SHA256 1d0b28ecb3ec4b2b62d2d01005197868587c701d8c7fddca87def5ab13692412

The final proposal has 95 ordered rows; every row cap has an independent raw-term
constructor expectation. These are source artifacts, not executed byte receipts.
Fresh read-only SHA256 checks of the current repository Admission, bootstrap,
connection and Stream files matched the four draft hashes above exactly. Parent
reports unchanged qualified Elixir1.18.5/OTP28/ERTS16.4.0.6; this worker did not run
the toolchain probe or any Elixir command.

Proposal interface (parent's explicit final choice):

* `reservation(state, stream) -> {:ok, {:native_http2_worker_v1,N,W}} |
  {:error,:worker_capacity}`.
* `describe(state,stream,plan)` creates the ordered row report only for diagnostics.
  Production must charge first; the native production path never calls describe.
  This pure API cannot prove remote Gate custody and introduces no Gate query.

`E(x)` means complete original default `:erlang.external_size(x)`. Numeric tuple,
list, map composition removes only component version bytes. Tuple tag width is
included. Improper aliases are `[:alias | request_id]`, not proper singleton lists.
Future local PID cap is `E(node())+13`; future generated local ref cap is
`E(node())+27`, conditional on the already qualified NEWER_REFERENCE_EXT <=5-word
source/toolchain proof. Original parent lease/token and complete endpoint, request,
peer/local/service/instance/peer_cert/secure terms retain their original widths.

The preflight builds only numeric tuples and arithmetic-size operand lists. It
does not build request, endpoint, MFA, dispatch, Exchange, lease or diagnostic rows.
Every ordered role has its cap, multiplicity, subtotal, owner and lifetime in the
diagnostic report. The static metadata clauses are also the numeric summation
order; no row/list/map report is built by reservation.

The whole recursion starts A=J=N=W=0 and repeatedly computes all caps, sums A/J,
then N=P+A+J and W=N+2*head_bytes. Completion requires every next component <= its
current component, with finite 64-iteration refusal. This covers the widths of all
four budget numbers inside args, request, ordinary lease, native correlation,
Exchange and return envelopes. Numeric A/J/N/W/next/iteration roots each occur twice.
The complete input-size tuple, its {:ok,input} return, original size scalars,
totals and settle return, final plan/return, and complete raw/final cap tuples are
also charged. The final cap tuple's own appended summary integer is closed by a
small numeric ETF-width post-fixed point, not unpriced guessed wrapper headroom.

Row derivation is in proposal source order. Startup consists of scalar planning,
complete numeric summaries and results; public async spawn payloads/from/wire/
reply/request-id/check_response-or-receive_response results; provisional reserved
bytes/slot map; original scalar args/MFA, public spawn args/MFA/options/frame/result;
timer result; FULL ordinary child lease and {lease,record} plus timer/terminal
replacement overlaps; FULL correlation and {token,correlation} plus phase/terminal
overlaps; timer/control/monitor/link/EXIT/DOWN roots; bootstrap/run/apply/activation;
cancel public payloads/wrappers/results; complete native pending map and scalar
timer/PID/monitor/lease/N/W/D roots; done/finite errors/terminal monitors/deadlines.
Dispatch consists of replacement limits, full body, parent X, dispatch x2, child X,
matched original initialized endpoint and transport_state. Full Exchange struct
defaults and __struct__ key are explicitly present, including socket:nil,
ssl:nil, close:false, resource_pins:[], route_bytes:0 and expect_sent:false.

Source reconciliation already performed against parent drafts:
`/tmp/gaoxy-admission-integrated-draft1.ex` and
`/tmp/gaoxy-worker-bootstrap-integrated-draft1.ex`.
The actual phase is :pending_activation (wider than :running/:cancelled), complete
correlation has owner,parent_lease,worker,lease,activation,from,deadline,phase,
exit_seen,down_seen. Lease has pid,monitor,bytes,token,timer,send,drain_notify,
request_active,cleanup,deadline. Timer nil/ref transitions fit the full ref cap.
Replacement overlap pays the initial/updated ordinary lease maps explicitly.
`spawn_timer` returns {:ok,timer}|:error; primitive spawn returns {worker,monitor}
or the finite caught :error. Spawn has public [:link,:monitor] options.

Final native source reconciliation performed against
`/tmp/gaoxy-http2-connection-integrated-draft1.ex` and
`/tmp/gaoxy-http2-stream-integrated-draft1.ex`: the only precharge new control
constructors are the already-priced scalar MFA/request/async alias/native timer
and startup map. Full Exchange/endpoint construction occurs only inside dispatch,
after the public check_response success matches current native token, original
parent lease, D and live local child PID. Scalar native Process.monitor(worker)
root is explicitly priced. Separate complete results price check_response,
original spawn alias retirement, and cancel alias retirement; cancel public-result
cap follows its actual :ok|finite-error payload grammar. Stream imports no Task
wrapper, acquires no child lease and matches original gate/lease/D/N/transport state
before endpoint work. Actual ordinary source-controlled death reasons are priced;
arbitrary callback diagnostic terms are outside this source-role claim.

Confirmed implementation invariants requiring independent source checkpoint review:

* Native connection uses exactly `[owner,id,token,gate,N,D]`; bootstrap prepends the
  ordinary lease before `apply` and Stream run/7 uses the original D and N.
* Native pending map is exactly request,timer,token,parent_lease,protocol_bytes,
  bytes,deadline; timer is {:h2_worker_start_timeout,id,token}; native also retains
  its existing worker/monitor/lease fields.
* Original D is an integer later than now and may be negative. Parent confirmed
  D is originally `Lifecycle.deadline(state.limits.request_timeout)` and unchanged.
  All native remaining-time values are nonnegative and <= that configured timeout,
  so ETF timeout cap is E(request_timeout). Synthetic pure width cases explicitly
  give request_timeout enough width. No D>0 condition is introduced.
  Synthetic arithmetic D may already be expired; these tests do not claim liveD
  acceptance. Actual Admission separately rejects D<=Lifecycle.now().
* Successful Gate reserved bytes/active values are <= spec.limits.max_bytes and
  max_active. Their original numeric ETF widths bound the provisional two-field
  map. Oversized arithmetic proposals can still be rejected by real Admission;
  reservation arithmetic is not an ownership/capacity proof.
* Known mode rejection is :paused/:draining/:failed or projected once to
  :invalid_spawn_request. Service has an actual paused caller at service.ex:207.
  Arbitrary host/callback/linked termination diagnostics are excluded original
  inputs, and are never claimed bounded by postreceipt projection.
* No endpoint initialization, Store callback, dependency/private API, global size
  cap, Service/group/startup constant change, #97 revival or VM/RSS claim.

Proposed tests: six tagged pure :native_worker_constructor tests. They independently
instantiate the complete real constructor terms, measure ETF, and count only
occurrences of specifically newly generated references up to the qualified source
cap. Original input refs remain measured exactly. They compare every role and
multiplicity against independent constructors, then derive independent A/J totals
and validate the whole N/W equation. Cases include large initialized endpoint,
full request/cert/service/instance, signed D, integer-width transitions, missing
max_write_chunk insertion, finite invalid input/stale report. They never call a
production sum twice, spawn workers or use Admission W.

All commands are finished; no owned process remains. One initial read-only
`git rev-parse HEAD`/`git status --short` was inadvertently executed before the
assignment's no-Git boundary was noticed; no Git mutation occurred, this was
reported immediately, and no subsequent Git command was run. One text search
used a nonexistent path and another had invalid regex; both were corrected by
scoped reads, with no application execution.

Counters unchanged: cumulative group30/root35, Astra2/2 exhausted; this proposal
adds zero runtime/repair attempts. No standalone DONE runtime claim, publication
or changed-W use follows from the proposal. Root must bind final integrated
source hashes, independent SPEC then CODE, and fresh nonzero tagged
pure tests before any changed-W runtime.
