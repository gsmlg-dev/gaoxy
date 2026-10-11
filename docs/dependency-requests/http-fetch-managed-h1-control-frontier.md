# Managed H1 control accounting or acknowledged quiescence

Upstream: [gsmlg-dev/http_fetch#97](https://github.com/gsmlg-dev/http_fetch/issues/97).
Type Feature; label `internal request`; verified OPEN on 2026-10-11.
Numerical qualification/production activation is BLOCKED with no local workaround.
Independent functional Slice B remains authorized. The following is the exact
submitted request; the finite ledger reviews are source inventory evidence,
not a measured leak or a complete native bound.

**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m3-gateway`

**Severity:** blocker for managed H1 numerical accounting and production
activation. Public functional qualification can continue independently.

We need a supported, source-backed bound for included managed H1 control
resources across repeated requests and chunks, or an acknowledged public
control-quiescence contract that makes their release observable. Existing
request completion and scope snapshots/retirement do not certify the required
native/deferred frontier. Our independently reviewed complete ledger leaves
this term unresolved, so it cannot produce a finite activation budget.

Audited cohort: seven coordinated packages at **0.21.2**, tag commit
`f677ca49519a007a7a551a5a515127c0f29d8ae6`, tree
`664a2a0de2bd4820017599b2d25f62bc7dcf63b0`. Runtime: Elixir 1.18.5,
OTP 28.5.0.7 / ERTS 16.4.0.6 / SSL 11.6.0.6, Linux x86_64, two normal
schedulers. Exact original Nix configuration inputs were recovered; the
separate native ABI/layout certification remains incomplete.

The controlled profile has four outer generation slots, per-scope
`max_connections: 2`, `max_requests: 32`, `max_pending: 0`, explicit H1,
OTP `:ssl`, manual redirects, raw streamed responses, bounded nil/PID upload
sources, buffer/recbuf/sndbuf 8192 and finite immutable deadlines. Scope
operations and snapshot callers have fixed counts; there is no retry waiter
fanout or unbounded external diagnostic input. Repeated chunks within one
long request still repeat stream monitor/demonitor operations.

**Minimal ordering traces and affected sources**

1. In OTP `erts/emulator/beam/erl_hl_timer.c` (1089–1147, 1810–1888), a timer
   executor changes ACTIVE to TIMED_OUT before allocating/enqueueing expiry.
   It can pause in that interval. The H1 pool removes its entry and
   `cancel_timer` can return false; the executor later queues `{:expire, token}`.
   Removing the logical entry or seeing false does not acknowledge that
   deferred message or native timer reclamation.
   `apps/http_runtime/lib/http/http1/pool.ex`:104–118,202–212.
2. A chunk caller monitors the stream, sends a chunk, receives ACK and
   demonitor-flushes before producing another chunk. Native demonitor routing,
   signal-buffer deinstallation, reference counts and thread-progress
   reclamation are separate. The controlled data credit needs an additional
   history-independent bound for those native/deferred objects.
   `apps/http_fetch/lib/http/stream.ex`:84–114,214–228; OTP
   `erl_proc_sig_queue.c`:2930–2968,10581–10660 and
   `erl_proc_sig_queue.h`:1957–1977.
3. A timed-out `GenServer.call` deactivates its reply alias, while the target
   can retain the request. A later call from a different sender does not
   establish an all-sender consumption or native reclamation frontier.
   OTP `lib/stdlib/src/gen.erl`:251–280;
   `apps/http_core/lib/http/request_lifecycle.ex`:386–395;
   `apps/http_runtime/lib/http/http1/pool.ex`:16–31.
4. `RequestLifecycle.settle` writes latch 2 before returning stop. A public
   completion waiter can observe that latch and return `:ok` before tracker
   termination and subsequent native exit/monitor processing.
   `apps/http_core/lib/http/request_lifecycle.ex`:358–363;
   `apps/http_fetch/lib/http/request_completion.ex`:116–143.
5. `Process.info(self(), :messages)` copies the message list and consumes
   nothing. Aggregate zero resource counts also do not expose old timer,
   alias or deferred monitor allocations.
   `apps/http_runtime/lib/http/http1/pool.ex`:186–188;
   `apps/http_runtime/lib/http/managed_transport/scope.ex`:56–86.

These traces refute premature release inferences. No arbitrary-repeat memory
leak counterexample has been established; this is a missing supported contract.

**Expected behavior / acceptance**

Provide either a documented conservative history-independent envelope for
included term/native/control resources under this profile, or a supported
acknowledged quiescence operation with precise included objects and ordering.
State each relevant sender/target/native executor edge, outstanding expiry and
cancel queues, aliases, repeated stream monitors, signal buffers and deferred
destruction/refcount/thread-progress costs. Define when old attempt/generation
controls may be refunded and how pending/uncertain outcomes retain ownership.

The contract must include externally visible TLS caller/delivery/tracking
metadata and failed-setup uncertainty, even when private TLS/crypto/kernel
heaps are explicitly excluded. Public send return, helper DOWN, completion,
mailbox inspection and zero snapshots need their individual limits of evidence.
Bind the result to enforceable runtime/profile/source premises. Missing or
mismatched certificates must fail closed. Publish the supported contract in a
dependency release so the requester can update and independently requalify it.

Gaoxy evidence: `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.2/`
`h1-complete-ledger.md/json` and `h1-complete-ledger-independent-review.md/json`:
72 rows, 14 phases, N0–N8 / P0–P6 / Q0–Q5; 187 source/evidence hashes.
We will keep managed production activation disabled and do not use a private
flush, process suspension, dependency patch or inferred frontier workaround.
