# Native downstream to H3-origin matrix (UP2)

Run from the worktree root only under the coordinator's exclusive execution
lease, after UP1 and strict compilation. The exact candidate sources must remain
frozen throughout the run:

```sh
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python \
  integration/http3/upstream/run.py --gate matrix \
  --evidence docs/acceptance/evidence/m4/upstream-matrix
```

The chosen `--python` environment must contain the existing pinned independent
peers `aioquic==1.2.0` and `h2==4.3.0`, with the existing test pins
`hpack==4.2.0` and `hyperframe==6.1.0`. Under the coordinator's execution lease,
prepare the existing peer environment with the two locked requirement files:

```sh
integration/quic_consumer/.venv/bin/python -m pip install \
  -r integration/http3/requirements.txt \
  -r apps/gaoxy_http/test/support/h2-requirements.txt
```

The runner checks those exact versions without
installing or changing dependencies. Missing tools/packages are BLOCKED_ENV.
Importing `run.credentials(directory, output, remaining)` still needs only the
standard library; portable release smoke and the two older gates remain intact.

The matrix executes **66 network rows**: 22 for each actual native TLS H1, TLS
H2 and QUIC H3 listener, forwarding to two independent aioquic H3 authorities.
Each authority and the downstream listeners have separate disposable P-256
CA/leaf identities. It also requires two actual production-policy rejections,
absent CA and forbidden address pinning, before endpoint allocation. These two
rows assert zero origin requests and the initial clean runtime baseline.

Per protocol the rows are GET, HEAD, 204, 304, progressive upload, progressive
download, a 1 MiB tiny-window roundtrip, duplicate fields, raw gzip bytes, escaped
path/query, a present empty query, redirect/no-follow/no-replay, zero/three-byte
ordered request trailers, early final response, downstream cancellation, upstream
reset, opening timeout, total timeout, wrong CA, wrong hostname and interleaved
distinct authorities. Declaration-bearing request trailers exercise Gaoxy's
existing shared trailer policy; declaration-free direct Session semantics remain
covered by UP0. Ordered repeated response trailers must arrive after DATA in
exactly one terminal block. HEAD/204/304 must carry no response DATA or trailers.
The three H1 bodyless rows explicitly request `Connection: close` and read through
actual EOF within that same row's five-second deadline. Their receipts record
observed EOF, post-header octet count/SHA256 and a preview capped at 64 bytes;
zero post-header octets is required. Closure before complete headers, read errors
or a missing EOF cannot pass. HEAD's advertised Content-Length remains intact.
HEAD and304 require exactly one Content-Length7 field;204 requires none, across
all three protocols. Only H3 HEAD/304 use a bounded independent response decoder
with public QUIC events, varints and static/literal pylsqpack QPACK. aioquic1.2.0's
generic validator rejects their legal metadata length at zero-DATA FIN without
tracking bodyless semantics. The independent decoder rejects every DATA frame,
dynamic QPACK, repeated HEADERS, forbidden response frames, oversized carry/frame
and partial-frame FIN. Success requires the actual complete FIN. Each bodyless
row records its decoder profile; other H3 responses retain standard aioquic
validation and its control streams/request encoding remain active throughout.
For chunked H1 responses, EOF before the next chunk-size line, during a chunk
delimiter or before the complete trailer terminator records premature closure
with `closed=true` and `ended=false`. Completed body chunks remain visible;
truncation cannot count as a successful terminal zero chunk and trailer block.

The origin receive window remains 16 KiB; framed downstream receive windows are
2 KiB (H3 connection credit 4 KiB). Both H2 fixture listeners explicitly select
the supported finite `control_rate: 2_048` per second for this 1 MiB/tiny-window
workload, with receive window16KiB and parser turn32. Their actual normalized
limits are recorded in startup metadata and checked by the runner. The native
production default remains256; its earlier GOAWAY11 failures are preserved,
and real network regressions verify the exact256/2048 caps and next-frame
GOAWAY11. This profile does not qualify burst throughput under the default256.
Every row has one absolute five-second peer
deadline, including the unchanged 1 MiB byte/hash assertion. The fixture's normal
request lifetime is five seconds. Dedicated opening/total test routes use 500 ms
and 1,500 ms respectively; their original timers cannot be extended by polling.
Cleanup uses a separate bounded one-second Service headroom. Upload/download
progress is held behind independent origin snapshots/control barriers rather
than timed sleeps. The runner has a 240-second absolute bound.

Every row validates exact origin method, escaped target, fixed authority,
certificate identity, one request, DATA length/SHA256/event count, ordered
trailers, trailing-block count and one request FIN. Early final keeps zero DATA
and zero request FIN and requires a separate peer cancellation receipt. Wrong
CA/hostname rows require actual downstream 502, exact public unknown_ca plus
path_validation_failed / certificate_unknown plus hostname_mismatch causes,
and no origin admission. Generic closure or timeout cannot pass. Upstream reset
requires its exact 0x10C category; opening/total expiry requires :timeout /
:request_timeout and the finite elapsed bounds.

For each failure, two progressive sibling responses start before the failure and
hold their FIN until afterwards: one on the same framed connection and one on a
separate listener. Both must survive. H1 cancellation closes its connection, so its sibling uses another
connection to the same listener. A healthy followup is additional evidence:
every row must independently return all six services' active, retained-byte,
queued-item/byte and cleanup counts to zero with no cleanup failure; all observed
guardians and the public SessionSupervisor active-child count must return to zero.

`fixture.exs` records only selected Gaoxy adapter entry/notification fields with
fixture-local BEAM tracing. It never traces SDK calls, reads private state or
serializes opaque Session terms. Public closed reasons are capped at 4 KiB,
recorded lists at 16 entries and the tracer mailbox at 256 messages. The tracer
is disabled and its normal DOWN collected before bounded runtime stop. Runtime
normal DOWN, listener TCP/UDP rebind, independent origin UDP rebind and every
owned child exit are mandatory. Forced shutdown cannot produce PASS.

Results go to a unique `matrix-<timestamp>/result.json` with child logs, exact
source/lock and certificate hashes, commands/environment, request observations,
per-row baseline receipts and actual exits. Private keys are temporary and never
copied into evidence. Exit 0 requires all 66 network + 2 policy rows and complete
cleanup; exit 1 records a failure; exit 2 records an actual environment block.
The coordinator must first retain a run of this same matrix against the detached
pre-activation source where HTTP3SessionClient is absent. Source preparation is
not RED proof or runtime PASS. Independent frozen-source/evidence review and a
fresh coordinator-owned live repeat remain required. Standalone, release and
deployment acceptance remain separate.
Root supplies cumulative live counters through `GAOXY_UP2_REPAIR` and
`GAOXY_UP2_FAILED`; both must be nonnegative integers and default to zero. The
runner records them as `up2_repair_rounds` and `up2_failed_rounds`. Preparation
reviews/repairs remain separate from live attempts and are not inferred as
executed network rows.

## Current execution disposition — 2026-10-13

Repair12 completes all66network+2policy rows in both the
[first execution](../../../docs/acceptance/evidence/m4/upstream-matrix/inflight-cleanup-abort-first-execution-1791855763442076358.json)
and required [fresh repeat](../../../docs/acceptance/evidence/m4/upstream-matrix/inflight-cleanup-abort-fresh-execution-1791856339843843409.json).
[First review](../../../docs/acceptance/evidence/m4/upstream-matrix/review-up2-inflight-cleanup-abort-first-full-matrix-1791856167153077070.json)
and [fresh-repeat review](../../../docs/acceptance/evidence/m4/upstream-matrix/review-up2-inflight-cleanup-abort-required-full-repeat-core-consumer-1791856738628854349.json)
PASS. Original cancellation/sibling/window/deadline/bytes/hash/FIN and cleanup
oracles remain unchanged. H3 tiny-window completion4985ms first/4567ms fresh
meets the original5s deadline with selected1ms host polling; no default10ms
throughput margin is claimed.

All prescribed final implementation executions PASS as linked in
[the gate ledger](../../../docs/acceptance/m4.md#final-implementation-gate-ledger--2026-10-13).
Final independent M4 acceptance remains pending. Portable build/runtime and
publication are NOT RUN. Historical repair11 FAIL39 and earlier failed runs
remain FAIL; exact cancellation causality for that failed run stays UNKNOWN.
Unsuccessful counters20live/8production/3harness and prior19/7/3,18/6/3,17/5/3
are preserved.

# Selected public Session qualification (UP0-Session)

The selected upstream route follows the original
[Session design](../../../docs/designs/m4-public-session-upstream.md) plus the
reviewed [consumer-affinity amendment](../../../docs/designs/m4-public-session-consumer-affinity.md).
Run from the worktree root only under the coordinator's exclusive lease and
frozen coordinated 0.21.4 sources:

```sh
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python \
  integration/http3/upstream/run.py --gate session-contract \
  --evidence docs/acceptance/evidence/m4/upstream-contract
```

The [fragment-size amendment](../../../docs/designs/m4-session-frame-fragmentation.md)
selects public `Session.new(max_frame: 8_192)` as the marked temporary workaround
for [http_fetch#105](https://github.com/gsmlg-dev/http_fetch/issues/105), originally
`needed`, now CLOSED via PR#106/main`e17ceea`. The [latest provenance audit](../../../docs/acceptance/evidence/m4/upstream-contract/latest-http-fetch-main-update-audit-1791855535947755021.json)
finds published/installed0.21.4 still lacks the fix; retain this selection until a
containing publication and separate qualification. Application DATA calls remain
16 KiB, the peer window remains 16 KiB,
and the body/hash assertion remains 1 MiB. Session splits encoded wire bytes into
8 KiB fragments and caps individual reads at 8 KiB; existing batch/deadline/queue
limits remain. The existing double row checks exact 8,192/8,192/5 DATA fragments,
single final FIN, and blocked/unknown second-fragment resumption without prefix
replay. UP0 Session50/50 and reviewed fresh50/50 qualify this selection
separately from the historical repair11 failed UP2 repeat. The current repair12
UP2 first and required fresh repeat both pass68/68, as recorded in the final
implementation ledger above.

The separate Session gate requires 50 named rows: 17 independent network rows,
two pure pre-admission policy rows and 31 labelled boundary-double rows. Network
rows cover two independently certified authorities, progressive transfer,
1 MiB upload/download through tiny windows, four exact zero/three-byte declared/
undeclared duplicate request-trailer forms, duplicate response fields/trailers,
strict wrong-CA/hostname authentication rejection, four cancellation stages with
independent peer receipts and sibling survival, idle caller failure after
establishment, and normal guardian loss after establishment/during paused ACK.
Absent CA and the probe's address-pin allowlist are policy rows; the latter's
scope is limited to the probe policy. Completed production UP1 and UP2 separately
verify Gaoxy's actual allowlist; the probe row does not establish that coverage.
Raw Transport is not claimed to reject Fetch's address-pin option.

A bootstrap creator makes a dedicated public descriptor with the guardian as
explicit acceptor. The guardian adopts it and observes creator normal DOWN
before a separate stable Session caller connects with `consumer: self()`.
Each full command/result is correlated; the guardian chooses every operation,
retains advanced state and original deadlines, and never waits for caller DOWN
between operations. The caller discards ready hints in finite batches and relays
bounded public closed reasons with caller/request/generation correlation,
including after calls and while idle. It checks its exact guardian monitor
before/after calls and remains alive
through paused consumption. Matching guardian DOWN includes normal exit. A
synchronous public call retains SDK/resolver bounds; its death may be delayed
until that call returns. Doubles explicitly release these barriers and do not
claim immediate native interruption or replace independent network evidence.

Named doubles retain unknown-connect/DATA/trailer reconciliation without replay,
definite blocked suspend/poll/resume, advanced error state, bootstrap cancellation
and creator loss, caller/guardian loss, original deadline and stale-result behavior,
supported-hint mailbox high-water, pending consumption, teardown receipt ordering,
stop error and abnormal/missing endpoint DOWN. Ownership rows drive the actual
creator/guardian helpers, including cancellation before descriptor creation,
before adoption, after ACK and after creator DOWN. Repeated resume commands keep
one deadline; a successful result held across that deadline is rejected before
timer handling. A blocked public stop outliving the original cleanup grace yields
`cleanup_unconfirmed`; releasing the barrier later records task termination,
without changing that outcome. Unknown/abnormal cleanup retains uncertainty.
Cleanup collects all required receipts under the earlier of the supplied Service
deadline and total + 1,000 ms; individual waits never restart the grace.
Synthetic supported-hint bounds are labelled separately from observed native
mailbox high-water; arbitrary BEAM-message injection is outside that claim.

Paused request polls validate every returned event rather than requiring an empty
list. The fixture allows only `:ready`, `:writable`, authenticated H3 ready
metadata and valid SETTINGS pairs; response headers/informational/DATA/trailers/
done, errors/resets, GOAWAY, datagrams and unknown shapes fail visibly. No event
filter hides a delivery. Within the existing `blocked_suspend_poll_resume` row,
scripted public Transport/codec subcases reject forbidden events alone or mixed
with controls and hold real Session response DATA/FIN behind a paused ref: repeated
polls perform zero request reads or sends until explicit pause release. This
proves the direct Session pause contract, not production downstream ACK handling.
The exact empty scripted poll and all 50 named rows remain required.

Every real allocated endpoint records distinct creator/caller/guardian identities,
all owned task termination, explicit public stop outcome, monitored normal endpoint
DOWN and independent same-address/port UDP rebind. Normal guardian-loss observer
receipts make no Service completion claim; they confirm an already-observed normal
endpoint DOWN, then public stop and rebind. These rows do not invent a remote
cancellation receipt. The original four cancellation peer assertions remain
mandatory. The bounded runner records actual exit, nonzero row kinds, source and
lock hashes before/after, commands/environment, public outcomes, exact request/DATA/
trailer/FIN counts, owned child exits and origin UDP rebind. Disposable fixture
keys never enter evidence. All cases must pass for exit 0; failures exit 1 and
actual external blocks exit 2. UP1/UP2/standalone and final M4 gates remain separate.

The missing-gate red check and both initial failed runs are immutable:
`session-red-1791826524525693638` (EXPECTED_RED, no child),
`run-1791826957389704425` (compile FAIL/zero rows), and
`run-1791827038372979204` (nine boundary-double PASS, first network poll FAIL
`:not_consumer`). Their original assertions and hashes are retained. The amended
gate is not qualified merely by compilation or architecture approval.
`run-1791830942072768771` also remains immutable: Sol round 2 failed after 31
double rows and two network rows because its paused poll returned `[:writable]`.
`run-1791831993043786216` records Astra round 1's actual failure after 31 double
and six network rows: the default 16 KiB wire fragment could not fit the remaining
tiny stream credit. No tiny-upload cleanup receipt was captured. Those facts and
the initial diagnosis-only receipt remain immutable; the later 8 KiB supported
route supersedes its blocker classification without declaring runtime success.
`run-1791833149635393377` records Astra2's actual FAIL: all 1 MiB request bytes
and its single FIN reached the origin, but response completion and the tiny
request's cleanup remained unconfirmed. Both Sol rounds and both Astra rounds
remain unsuccessful. The coordinator's separately recorded local repair 1 follows
the [response scheduling amendment](../../../docs/designs/m4-session-response-scheduling.md):
poll again immediately after target-request progress, retaining the complete
event batch and the original five-second total deadline. Control-only/other-ref
batches retain the five-millisecond idle wait. Raw poll DATA counts/bytes and
operation timing are recorded before inspect truncation. Static preparation
alone is not recovery or gate PASS; independent pre-live review and fresh
coordinator-owned execution remain required. No third Astra round is authorized.

`run-1791834217971221876` retains coordinator repair1's FAIL:37 PASS/13 NOT RUN,
exactly901615 response bytes and unconfirmed tiny-request cleanup. Coordinator
repair2 follows the [observation overhead amendment](../../../docs/designs/m4-session-observation-overhead.md):
the existing correlated operation reply carries actual caller identity/liveness
and mailbox high-water, replacing a separate identity RPC on every operation.
Binary previews are64bytes; raw poll event/DATA counts, bytes and SHA256 remain
exact and are computed before inspection. Public results, all50 rows and all
original acceptance/deadline/cleanup checks are unchanged. Runtime was pending at that historical checkpoint; the final ledger above supersedes that state.

`run-1791834829044880836` retains coordinator repair2's FAIL:37 PASS/13 NOT RUN,
750223 exact response bytes and confirmed tiny-request local teardown. Public
abort remains unknown; Service completion is NOT CLAIMED. Normal endpoint/all
owned-task/guardian DOWN, public stop and same-port rebind establish this local
teardown, not response completion. Coordinator
repair3 applies the [measured origin-observation correction](../../../docs/designs/m4-origin-observation-cost.md):
keep the complete body and every wire observation, but update its SHA256 once
per original DATA chunk instead of copying/hashing the entire growing body for
each snapshot. Snapshot counts/hashes/fields/FIN are identical. All50 rows,
original five-second deadline and full cleanup/byte/hash assertions remain.

`run-1791835529186878739` retains repair3 FAIL42/50: the original1MiB roundtrip
and allfour request-trailer rows passed, with confirmed local teardown. Wrong CA
failed because ready returned generic :closed and the caller discarded the
public closed reason. Coordinator repair4 follows the
[TLS observation amendment](../../../docs/designs/m4-session-tls-rejection-observation.md):
retain that bounded public consumer notification with owned caller/request/
generation correlation, while preserving the unchanged Session result. TLS
negative proof requires both actual public failure and the original specific
unknown_ca/path_validation_failed or certificate_unknown/hostname_mismatch
cause, plus zero origin requests and confirmed local teardown. Generic closure
or timeout alone cannot pass. All50 rows and original limits remain required.

# Fetch functional diagnostic (preserved contract gate)

Run from the worktree root with the coordinator's exclusive Mix/live lease and
frozen coordinated HTTP Fetch/QUIC 0.21.4 sources:

```sh
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python \
  integration/http3/upstream/run.py --gate contract \
  --evidence docs/acceptance/evidence/m4/upstream-contract
```

The independent aioquic 1.2.0 origin and public Fetch/Promise/Stream probe execute
15 functional rows: progressive downloads from two separately certified
localhost authorities, progressive upload, four ordered request-trailer forms
(zero/three DATA bytes, with/without a valid `Trailer` declaration), wrong CA,
wrong hostname, absent trust, unsupported `connect_address`, and cancellation
before headers, with an unacknowledged response, during a blocked upload and on
downstream owner loss. Every request must use the exact authority and the
corresponding fixture certificate identity; rejected configurations must produce
no origin request. Every trailer request must reach exactly one terminal trailing
HEADERS block with the exact repeated fields, DATA hash and FIN, exactly once.
The response protocol, body, repeated fields and response trailers are asserted.
A local `finish/2` return of `:ok` is recorded separately from wire success.

Wire/control barriers precede upload and response FIN. Blocked-upload control
pauses the origin's owned public asyncio UDP transport after HEADERS, then writes
bounded 16 KiB deliveries until one public producer write reaches its finite
300 ms timeout while the peer is paused. That pending delivery is never replayed.
The origin resumes after cancellation to observe the remote cancellation receipt.
All loops retain finite deadlines, including a 150-second absolute runner limit.

The runner separately records public cleanup results for all eleven real
requests, normal public task/upload/response termination, and independent remote
cancellation for four lifecycle stages. Abort acknowledgment, Promise resolution,
task/stream DOWN and origin cancellation do not individually certify the Fetch
transport cleanup boundary. Unsupported or uncertain public completion therefore
makes the overall gate BLOCKED even when all 15 functional rows PASS. The public
Session export list is an API audit, not another live protocol qualification.
Production adapter activation depends on a supported cleanup contract reviewed
by the coordinator; this harness never inspects private client owners or sessions.

Each run writes a unique evidence directory with commands, versions, source and
lock hashes before/after, fixture CA/leaf hashes, wire observations, public
results, owned child exits and UDP rebinds. Historical 0.21.3 FAIL/BLOCKED runs
and `latest.json` are preserved unchanged. Disposable keys are never copied to
evidence. Exit 0 means this Fetch contract is fully qualified; exit 2 means its
cleanup contract is unsupported or uncertain; exit 1 means unexpected failure.
Full UP0 also requires qualification of the selected caller-owned Session
lifecycle. The production adapter and UP2 matrix remain separate gates.

`run-1791836503490777437` retains repair4 FAIL:47 PASS, one attempted
cancellation FAIL and two cancellation rows NOT RUN. Actual public TLS causes
and pending-header cancellation passed. The stalled-response local teardown
was confirmed, but no independent peer cancellation arrived within the original
five-second barrier. Coordinator repair5 follows the [abort/stop ordering
amendment](../../../docs/designs/m4-session-abort-stop-order.md): idle caller
abort precedes stop, with the existing <=100 ms fallback inside unchanged
cleanup grace; an outstanding operation still triggers immediate independent
stop. Local teardown and peer cancellation remain separate requirements.

## Selected UP2 host polling profile

Both H3 listeners select the public QUIC host `poll_interval: 1` millisecond
option through completed service specifications revalidated by `Gaoxy.Config`.
Startup records and verifies both normalized ALPN/polling maps. Trusted embedded
QUIC specifications accept integers 1..1000; omission retains 10 milliseconds.
H3 Options and the standalone data schema retain their existing inputs.
The complete matrix qualifies this explicit 1ms workload profile; it does not
qualify default 10ms tiny-window burst throughput. The 68 rows, five-second
deadlines, 2KiB/4KiB peer windows, 16KiB origin window and exact 1MiB bytes/hash/FIN
remain unchanged. Public Abyss host, Handler and Service source hashes are
recorded before and after each run.
