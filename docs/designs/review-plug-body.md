# Plug logical request-body reads

R1 repairs only the Plug contract. Native `Exchange.read_body/3` and
`read_body_step/3` still emit one bounded piece. One Plug call aggregates pieces
up to `length` (default 8,000,000); each demand is at most `read_length` (default
1,000,000), the native cap, and the remaining logical allowance. The native
body decoder/stream owner retains its cumulative whole-request limit.

Only the native result establishes completion. At an exact unknown chunked or
streamed boundary, return `more` with the current Exchange, then consume terminal
framing on the next logical call. Do not take an extra data byte to prove EOF.
Buffered H1 trailers and any following request remain owned by the Exchange.

Validate options before I/O. A pending wait maps to `{:error, :timeout}`; an empty
`more` maps to `{:error, :no_body_progress}` rather than spinning. Preserve native
request errors as `Gaoxy.HTTP.RequestError` with the existing status.

Plug's `read_timeout` defaults to 15,000 ms per underlying read. The explicit
server `http_limits.read_timeout` caps that wait and the absolute Exchange
deadline caps every operation. An internal `read_body_step/4` timing mode lets
H1 refresh the socket wait across framing reads without changing native callers'
existing finite-step wait. Each H2/H3 step already requests one transport read.

`Exchange.adapter_body_bytes` charges adapter retention through the existing
Admission lease. Before a read, reserve the accumulated detached chunks, the
old input buffer backing, the output window and its detached copy. Detach each
piece with `binary.copy`, since an H1 result can reference its old input buffer.
The native path's own input/copy reservations remain additive. Before flattening,
reserve both the accumulated bytes and the final binary. On successful transfer
to Plug/application code, clear only adapter ownership; retain the Exchange's
normal buffer/header/trailer charges. On a structured failure or pending result,
drop accumulator ownership and restore that same native retention. All new
adapter and native body-read retention updates use the remaining absolute
Exchange deadline. A stale lease or stopped gate returns a Plug-compatible
error. If the deadline expires while the gate is suspended, queue an ordered,
nonblocking restoration after the outstanding update and retire its reply alias;
restoration occurs when the gate resumes (or lease cleanup ends ownership).
The primary request failure is preserved. Admission failure occurs before the
corresponding read or flatten allocation.

Use reverse chunk accumulation and a single final flatten. No new process,
dependency change, speculative completion, or specialist qualification is needed.


The explicit native H2 worker constructor accounting includes the new Exchange
field, preserving the independent complete ETF-envelope assertions. H2 receive
window reservations and H3 connection/request reservations continue to cover
native input backing until adapter detachment; adapter-owned accumulated copies
and final flattening are additional charges. No send/poll/lifecycle path uses the
new deadline-aware body-retention helper.

H2 body-read operation calls use exactly the remaining hard deadline, without
the general operation path's acknowledgement slack. A suspended/backlogged read
owner returns `timeout`; non-timeout owner exits return `closed`. Send/poll
operation policy remains unchanged. A bounded deterministic regression suspends
a real owner and proves the read returns before the former extra 100ms allowance.

Read-triggered `100 Continue` obeys the same deadline. H1 uses a dedicated bounded
sender, preserving `max_write_chunk`, per-piece Admission operations and the
`expect_sent` transition before any output. An additive Admission start accepts a
caller-owned operation reference and absolute deadline; the gate rejects expired
starts, and a timed-out caller queues an ordered exact-token finish. This prevents
late registration from leaving an unknown token. No socket invocation records
`{:error, :not_submitted}`; after invocation, existing actual/uncertain outcome
semantics apply. Finish and fallback retention cleanup never wait beyond the
request deadline. H2's body-read Continue submits the same write-wrapped empty
100 head with a bounded call, preserving the general informational-response API.
