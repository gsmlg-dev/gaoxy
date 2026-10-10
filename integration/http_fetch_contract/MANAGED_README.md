# Managed transport probe preparation

## Current 0.21.1 cleartext qualification

All seven packages are installed at0.21.1, actual tag
`bdf849adf119039ed679d24d5fbb0a321f5e578a`, tree
`2188645d94575d7cb452e41eab156e80d38a26ef`. The
[release](../../docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/release-provenance.json)
and [tag/source provenance](../../docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/tag-source-provenance.json)
are reconciled by independent
[source/API](../../docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/source-api-review.md)
and [installed-cohort reviews](../../docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/installed-cohort-verification.md):
196 shipped files, seven archive/inner/outer/lock identities, both direct pins
exactly `== 0.21.1`, exactly seven changed lock entries and17 unrelated preserved.
Fixes86–89 are present;95 is absent. Fresh
[compatibility](../../docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/compatibility.json)
passes486/0, seed21111026, exit0,429 unchanged source identities, strict format
and compile. The
[cleartext green](../../docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-green-analysis.json)
passes24 distinct cases (9 H1,15 h2c),24 successful joined cleanups, exact
canonical connection-capacity MATCH, exit0,429 unchanged inputs and no remaining
peer after [canonical code review](../../docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-canonical-code-review.md).

The explicit `--cleartext` profile selects all existing H1/h2c cases and requires
exactly24 completed cases; default execution retains39. Unsupported arguments
reject before app/peer startup. Parent serializes execution after independent
review and complete input freeze; see the
[cleartext plan](../../docs/plans/m3-upstream-0.21.1-cleartext.md) and current
invocation/status in [README](README.md). The
[initial red](../../docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red-analysis.json)
remains a cleanup FAILURE with16 case receipts,17 peer joins and16 fully
successful cleanups. [Repair1 review](../../docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red-repair1-review.md)
moved the same hard capacity match after normal finite completion without
weakening cleanup. The [repaired red](../../docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red-repair1-analysis.json)
passes the expected-red gate:16 cases,17 fully successful cleanups, exit1.
Harness counters are Sol repair1 successful, unsuccessful0, Astra0; historical
0.21.0 counters below remain separate. The canonical green requires exact MATCH.
[Refresh4](../../docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/upstream-status-refresh4.json)
observes#95 CLOSED at20:19:06Z, but GitHub/Hex latest and installed0.21.1 lack
its fix. Full39/TLS remains **BLOCKED95**, and this24-case pass
does not qualify full M3, memory accounting, held preparing/connecting saturation,
the complete#86 adversarial-backlog gate or Task4/M4 activation.

## Historical 0.21.0 fixture and runtime evidence

All receipts, source pointers, formulas and instructions below describe the
historical0.21.0 checkpoint. Preserve them unchanged; they do not establish
0.21.1 canonical compliance or qualify its new normalization/copy phases.

Status: **Finite public resource-property qualification PASS:39/39 cases,
39 successful joined peer cleanups, exit0 and425 unchanged frozen source hashes.**
Astra recovery1 passed independent specification/code-quality delta review,
strict format/compile and18 focused tests, then the complete serialized run.
Receipts are `managed-preflight-recovery1.json` and `managed-probes-recovery1.json`
under `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/`.
No owned peer remained. Canonical H2 capacity errors remain **MISMATCH** in both
verified TLS H2 and h2c; retained-byte accounting, Gaoxy integration and full M3
remain unqualified.

Historical failures are preserved:
The initial run exited1 after11 case
receipts and12 cleanup receipts; all425 frozen hashes matched and all12 owned
peers stopped. The TLS H2 force-retirement case failed before its case receipt;
cleanup also rejected unconfirmed completion and masked the primary exception.
That failed run established no full39-case PASS. Parent installed the coordinated Hex0.21.0
cohort at tag `9813c126dc8b48055b9ee941c693fc27fa691489` and recorded compatibility
PASS460/0 separately. These new files
do not qualify Gaoxy integration, the HTTP/2 retained-state gate or M3 acceptance.
Repair1 passed every abnormal-retirement and actual-deadline case but failed on
the first256-frame positive empty response. All25 peers cleaned up successfully,
all425 source hashes matched and no owned peer remained. The fixture passed
the exact empty binary body to a PID-only stream helper. Repair2 requires
exact200/empty-binary response for HEADERS END_STREAM and a stream PID with
exact `bounded` body for the nonempty variant; original completions still must
confirm exactly ok. The historical helper is unchanged. Installed SocketClient
final-header END_STREAM handling sends `Response.with_buffered_body(response, "")`
before the streamed-response branch, matching the public Response binary/PID
contract. This corrects fixture dispatch, not the256-frame assertion.

The TLS GOAWAY capacity case now confirms the canonical error shape MISMATCH:
actual `{:error, :pending_capacity}`, documented
`{:error, {:transport_scope_capacity, :connections}}`. Its finite no-extra-byte,
independent-scope and replacement checks passed; h2c capacity was not reached
in repair1. Recovery1 later exercised both profiles successfully while recording
the same canonical MISMATCH. No canonical compliance follows. Initial/diagnostic/repair1
failed receipts remain unchanged. Sol unsuccessful repair validations:2, comprising
one full runtime failure and one formatter-preflight failure. Initial runtime
FAIL1 and diagnostic runtime FAIL1 are separate. Astra recovery rounds:1 of2;
this round's parent verification passed the full runtime; unsuccessful Astra
recoveries:0. Sol unsuccessful full runtime repairs:1. No second recovery was used.

The public contract was read at immutable upstream PR81 head
`11f1642cf6408219d4813772bda1055e605bbdc4`, containing the PR80 frame limit.
The source cache at
`/tmp/gaoxy-http-fetch-source-11f1642cf6408219d4813772bda1055e605bbdc4/manifest.json`
records facade, policy, scope, frame-owner and upstream-test blobs/hashes.
Additional immutable SocketClient, lifecycle and H2-pool sources are cached at
`/tmp/gaoxy-managed-fixture-source-11f1642cf6408219d4813772bda1055e605bbdc4`.
Installed0.21 source was reconciled with the selected pointers during the
separate independent bounds review; published Fetch's RequestCompletion
construction change is recorded there. Root owns the complete installed-source
freeze and provenance gate.

`managed_transport_probe.exs` prepares **39 explicit nonzero cases**, retaining
the original36 and adding three actual absolute-deadline cases. It uses
only `HTTP.fetch`, the original Promise's public completion, streamed response
messages, and opaque public managed scope/snapshot/retirement APIs. Scopes open
in the long-lived probe caller except the explicit creator-death case. No
private dependency process inspection, global pool retirement, dependency
patches, or replay is used.

| Profile | Prepared cases |
| --- | --- |
| H1, verified TLS H2, separate h2c | Seven each: unequal request/connect deadlines on one reused connection; two private scopes and rejected route/retired scope with no fallback; occupied request saturation before request bytes with `max_pending: 0`; graceful pending receipt then late checkin closes; abort closes A while live B survives and finishes exact body; creator death escalates graceful to abort; an actual short absolute deadline expires while a longer request remains held/live and later finishes exact body. Repeated/concurrent finite receipt waits and request-completion versus idle generation lifetime are explicit. |
| H1 | Two additional: connection saturation with request capacity remaining and no extra accept/request bytes; admitted POST failure on reused socket with exact body and no replay. |
| TLS H2, h2c | One additional each: GOAWAY retains an admitted stream at connection capacity; a following PING/ACK confirms client-side GOAWAY processing, new admission rejects without extra accept/request bytes, an independent scope progresses, and replacement waits for public zero connection/request counts. |
| TLS H2, h2c | Seven additional each: exact256 frames succeed with empty or bounded body; frame257 rejects for empty/nonempty × final/nonfinal; connection-wide failure settles a sibling, preserves another scope and permits one explicit replacement on a new connection after the public request/connection/resource ledger is zero, with no failed-request replay. |

The original unequal-budget sequential reuse check stays independent of the
new expiry check. For actual expiry, the peer holds a5500-ms request's response,
then withholds a700-ms request's response headers. H2 uses the same connection;
H1 uses a second connection in the same scope. The original short Promise must
return exactly `{:error, :request_timeout}` after650–1700ms, completion must
confirm, and the peer must observe H2 reset or H1 closure. The longer completion
must still be pending with one live admitted request, then deliver exactly
`abcdefgh`. A further request must reuse the surviving connection under unequal
budgets. These pre-header expiry assertions follow installed SocketClient's
deadline paths982–987/1356–1357/1551–1569; they do not widen error expectations
to hide a stream-abort race.

Zero rejected request bytes use independent raw counters, not only decoded
requests. H1 counts every receive and retains partial-header progress. H2
counts HEADERS/CONTINUATION frames and their bytes before `h2.receive_data`,
including incomplete payloads; a short unclassified frame prefix remains
visible separately. Control ACKs are excluded from request-frame counts.
`wire_snapshot` first waits for the acceptor's actual no-pending-listener
barrier, then every owned reader's no-pending-receive or closed-socket barrier
under one2-second control deadline. Negative policy,
request/connection capacity and retired-admission cases compare counters and
accept counts before/after rejection; held request and connection capacity
cases repeat the comparison after retirement. Complete-request lists remain
strict additional assertions. A PING ACK establishes owner wire processing of
GOAWAY; it does not certify consumption of an asynchronous pool cast. The
separate observed admission outcome tests functional draining behavior.

The source predicts an **error-contract mismatch** for H2 GOAWAY capacity:

- Facade `apps/http_runtime/lib/http/managed_transport.ex:45–48` documents
  `{:error, {:transport_scope_capacity, :connections}}`.
- `apps/http_fetch/lib/http/socket_client.ex:466–482` propagates reservation
  errors unchanged. `apps/http_runtime/lib/http/http2/pool.ex:504–505` rejects
  the zero-length waiting queue with `{:error, :pending_capacity}` while the
  draining owner occupies the only connection.

The first runtime attempt must emit `MANAGED_CAPACITY_ERROR_CONTRACT` with the
documented, source-expected and actual results. The prepared assertion requires
the exact source-predicted result and separately labels canonical compliance
`MISMATCH`; finite admission/resource property results do not certify the
documented error shape. The TLS mismatch was confirmed in contract repair1 and
routed by the parent as [upstream Bug89](https://github.com/gsmlg-dev/http_fetch/issues/89),
severity needed; the probe retains its TODO/WORKAROUND references. Recovery1
separately confirmed the same mismatch for h2c; the failed repair1 receipt still
does not qualify h2c.

`managed_peer.py` supplies new raw H1 and Python `h2` behavior. It imports the
historical `upstream_peer.py` read-only for disposable TLS, accept/close receipts
and joined shutdown. The Elixir probe loads `pooled_completion_probe.exs`
read-only with its runner suppressed, using only its finite control, ACK/body
and completion helpers. Both historical files must therefore join the source
freeze. The peer runs at most45 seconds after TLS readiness preparation; socket,
control, Promise, completion, scope and shutdown waits are finite. `openssl`
creates a disposable CA/server leaf with localhost verification and `h2` ALPN;
Fetch uses `verify_peer` and that CA, without fetch-time TLS overrides.

Fragment injection is finite and valid: positive empty-body wire uses one
empty HEADERS with END_STREAM,253 empty nonfinal CONTINUATION, one nonfinal
`0x88` status200 fragment and one empty END_HEADERS CONTINUATION (256 total).
The bounded-body positive uses empty HEADERS,254 empty continuations, final
status200 continuation, then one END_STREAM DATA. Each negative uses empty
HEADERS,255 empty continuations and one variant257th continuation. The peer
requires connection closure, rather than a stream-local reset. Managed H2
connections use shared owners; affected original completion receipts must
remain `{:error, :cleanup_unconfirmed}` after shared-owner fragmentation loss.
Generation retirement is separately required to prove resource termination.
All original completions are captured before await; cleanup attempts every
scope and completion, retaining confirmed conservative outcomes, then joins
the owned peer. Each successful case emits a receipt; final count must be39.

Diagnostic1 changed failure reporting only. `with_peer/2` emits
`MANAGED_PRIMARY_FAILURE` before cleanup and preserves the original exception
kind/reason/stacktrace. Cleanup still runs every registered scope/completion and
joins the peer; any cleanup assertion failure emits `MANAGED_CLEANUP_FAILURE`.
Before cleanup, `MANAGED_PRE_CLEANUP` records each remembered scope's public
snapshot with a100-ms wait and each original completion's zero-wait result;
these read-only observations distinguish live independent work from the later
forced cleanup of that scope. Snapshot/observation exceptions are recorded.
`MANAGED_COMPLETION_CLEANUP` records the exact expected and observed public
completion result before enforcing their existing equality. If both phases
fail, the primary exception is re-raised and the cleanup failure remains in the
log. If only cleanup fails, that failure is re-raised. The diagnostic full run
again exited1 with11 case/12 cleanup receipts and all425 frozen hashes unchanged.
It identifies `Peer.complete(A)` returning `{:error, :cleanup_unconfirmed}` as
the primary TLS H2 force-case failure. Before cleanup, B was open with one active
request/connection, four resources and a pending original completion; A was
retired with unconfirmed request evidence. These original receipts are preserved.

The containing-tag [retirement contract](https://github.com/gsmlg-dev/http_fetch/blob/9813c126dc8b48055b9ee941c693fc27fa691489/docs/managed-transports.md#retirement-proof)
states that individual request evidence may be conservative after abnormal
termination while generation retirement independently proves monitored resources
gone. Installed Scope188–200/383 cancels ingress and immediately shuts down
tracked H2 connections; SocketClient1304–1317/1345–1348 marks failed pooled
release confirmation unconfirmed. Requiring every force-retired H2 request's
completion to be exactly ok is stronger than that documented contract. The
initial run's second unconfirmed result appeared only after failure cleanup
force-retired the independent scope; it does not establish a scope-isolation
violation. The failed assertion required stronger evidence than this public
abnormal-termination contract promises; no dependency bug is established here.

Actual contract repair1 applies only to scope-abort and creator-death cases.
H1 retains exact `:ok`; TLS H2/h2c require one of exactly `:ok` or
`{:error, :cleanup_unconfirmed}`. Scope cancellation reaches the request tracker
while Scope immediately shuts down its H2 connection; the request's release
confirmation can win or lose that independently scheduled shutdown. The later
generation/peer-closure barrier cannot reconstruct that ordering. An exact
unconfirmed result is therefore not assumed deterministic. Pending, arbitrary
errors and unsupported completion remain failures. `MANAGED_FORCE_COMPLETION`
and the case receipt record the exact observed request outcome; unconfirmed is
never converted to request-cleanup ok. Concurrent and repeated public waits
must return that same exact outcome, which is saved as this original completion's
cleanup expectation; global cleanup still pins expected versus observed equality.

Both abnormal paths require successful generation retirement, peer connection
closure and a retired public snapshot before observing request completion.
Generation `:ok` separately proves zero monitored resources/slots and coordinator
termination (Scope209–228, Facade159–164 and the containing retirement contract);
a retired snapshot alone is not zero-resource proof. The abort case additionally
requires B pending/open with one active request/connection, no preparations or
pending queue, and positive resources before A's completion wait. B remains
pending afterward, delivers exact `abcdefgh`, completes exactly ok and retires
normally. All39 cases, wire/capacity/deadline/no-replay assertions and primary
diagnostics remain. Normal, deadline and graceful request paths still require
exact ok; fragment-owner-loss cases still require exact unconfirmed. Repair1's
abnormal cases passed, but its full run FAILs on the empty-response helper.
Repair2's independent source review passed, but strict preflight then failed
because the new `if body` block lacked the formatter-required following blank
line; compile/tests and runtime did not execute. Astra recovery1 changed only
that blank line in the probe. The canonical scoped formatter and format check
both exited0; removing that line reproduces the reviewed incoming hash exactly.
All39 cases and exact assertions are unchanged. Sol unsuccessful repair
validations remain2 (runtime1, formatter-preflight1); Astra recovery rounds1 of2.
The parent's recovery1 verification subsequently passed all39 cases and39 joined
cleanups under a renewed425-file freeze, with exact source stability and no
remaining owned peer. This closes the finite functional gate only.

After installation, freeze and explicit execution authorization only, run in a
separate otherwise idle VM, serialized with every other Mix/network fixture:

```sh
HTTP_FETCH_PEER_PYTHON=/tmp/gaoxy-m3-h2-soak-venv/bin/python \
  nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; unbuffer mix run --no-compile --no-start integration/http_fetch_contract/managed_transport_probe.exs'
```

Record installed package versions, immutable upstream/release identity, frozen
source hashes before/after, raw outputs, executed case count, original public
completion outcomes, every joined peer shutdown and exit status. A passing
resource-property probe does not resolve the separately reported canonical
H2 capacity error mismatch or any unrelated retained-event backlog gate.
