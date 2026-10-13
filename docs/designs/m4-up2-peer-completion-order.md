# M4 UP2 peer close and completion ordering

Repair4 preserves the original timeout notification assertion and passes all22
H1 network rows plus two policy rows, then fails h2-get's missing endpoint result.
Keep [the actual failure](../acceptance/evidence/m4/upstream-matrix/matrix-1791847880898684510/result.json)
unchanged: nine unsuccessful live executions, four failed production repairs;
no third Astra recovery is authorized.

The independent peer closes its H2 connection when its context exits after wire
FIN, before asking the runner to inspect completion receipts. The proxy still
awaits guardian cleanup and the fixture's trace-delivery barrier. Native H2
connection closure correctly kills unfinished endpoint workers; this premature
test teardown races the required actual endpoint return. Normal guardian DOWN
alone cannot prove that return, and success FIN cannot substitute for it.

Keep every production behavior and existing wire/error/cleanup assertion. Add
an explicit peer-to-runner request-completion barrier while all row connections
remain open. The runner polls the existing observer's actual receipts within the
original finite one-second cleanup budget and validates their unchanged exact
result/error categories. Explicit framed downstream cancellation still requires
the actual killed owner and absence of a result; it is never a success exception.
The peer waits within its original absolute five-second row deadline. Include
the secondary authority and both survival connections in that same context
lifetime. No new sleeps, extended deadline, native lifecycle change or fabricated
completion event is needed.

After the barrier, close the independent clients as before. The existing
row-complete barrier still requires all original zero Admission/cleanup/queue
baselines and validates the same receipts and independent origin request bytes,
trailers, counts and FINs. Thus the added ordering proves actual endpoint
completion before deliberate test teardown and separately proves cleanup after
teardown. All66 network+2 policy rows and12 cancellation receipts remain required.

The unchanged repair4 network failure is the causal RED. Independently review
this contract change, run the complete matrix with frozen sources, inspect actual
evidence and require a fresh repeat. Earlier failures remain FAIL.
