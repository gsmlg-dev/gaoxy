# Controlled managed-H1 accounting envelope

Date: 2026-10-11 Asia/Shanghai. Task: M3 managed-H1 accounting architecture
follow-up; assignment mode **architecture**, gate **PROJECT_ARCHITECTURE**.
Gate evidence: the parent requested the ownership, preparation, representation
and admission contract needed to make the existing managed-H1 design's byte
reservation implementable. This is an architecture deliverable, not a recovery
repair or runtime qualification.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `4cc7a1a967d1b90a62d42db438316b10a03a1e16`.
Only this new memo is owned. Parent-owned dependency, adapter, fixture,
README and design/acceptance edits already exist and are preserved.

## Decision

Proceed first with a **pure compact-input and accounting-expression slice**.
It may construct bounded canonical values, derive constructor counts, identify
missing proof certificates and test rejection. It must not open a scope, start
a process, activate managed reuse or return an activation byte budget while a
proof obligation is unresolved. This removes the circular dependency between
"prepare bounded inputs before accounting" and "finish accounting before any
Gaoxy implementation" without relaxing the activation prerequisite.

The H1 numeric gate is **NOT ESTABLISHED**. `261,199,114` is a historical
conditional subtotal; its delivery assumption and eight-window multiplier are
not certified. The ledger below replaces that expression rather than adding
guessed metadata to it. This investigation has not demonstrated an H1 external
contract defect. Remaining local accounting work is not automatically an
upstream blocker. H2's independent issue
[http_fetch#86](https://github.com/gsmlg-dev/http_fetch/issues/86) remains an
external blocker for H2 activation and full M3 acceptance.

The settled generic lifecycle participant registry, persistent scope custodian,
core isolation, original absolute deadline and public retirement/completion
barriers remain unchanged. This memo does not authorize process integration.

## Evidence and measurement boundary

Use the installed seven-package HTTP cohort `0.21.0`, containing tag commit
`9813c126dc8b48055b9ee941c693fc27fa691489`. Publication/provenance and the
460-test compatibility result are parent evidence, not repeated here. Read
[the narrow review](h1-accounting-review.md),
[the independent worksheet](independent-bounds-review.md),
[the source worksheet](../retained-bounds-source.md), and
[the runtime receipt](qualification-runtime.json) with this memo.

The actual receipt is Elixir 1.18.5, OTP 28.5.0.7, ERTS 16.4.0.6, 64-bit,
SSL 11.6.0.6. This memo inspected that exact installation's Erlang SSL sources
under `/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7/lib/erlang`.
The earlier review's OTP 28.5.0.5 source identity is not the runtime receipt.

The budget covers reachable owned term structure, every distinct retained
binary backing allocation, simultaneous copies and preparation transients,
and owned ETS, atomics, monitor, timer, message, closure and process-object
metadata. It excludes total VM/RSS, unused GC heap capacity, allocator
fragmentation, kernel buffers, and TLS-internal allocations/measurement.
TLS delivery binaries once referenced by the managed pipeline, socket handle
terms and the metadata for tracked TLS resources remain included. Excluding
TLS internals does not permit ignoring oversized backing exposed through a
delivery slice.

Caller data before the controlled boundary and global immutable runtime data
are outside this per-scope budget. That exclusion cannot follow a caller binary
into the scope: all caller-origin backing retained after transfer is included.
Pin the host-CA snapshot as shared global data, with no mutation during a scope
lifetime; count any newly constructed lists/options referencing it. Both
`Policy.freeze_ssl/2` and `HTTP.Transport.SSL` evaluate host CA defaults even
when explicit CAs win. Do not assume that evaluation copies every DER payload,
or that it has zero term-construction cost. Prove it for this runtime (P3).

## Controlled preparation contract

This is an internal adapter profile, not a promise to account for arbitrary
arguments accepted by the public HTTP library. The pure module receives only
the bounded source grammar below. Its future caller must establish that
grammar **before** sending/capturing those values in a managed worker. Calling
`binary.copy/1` after an unbounded binary has entered a mailbox cannot fix the
earlier peak. Rejected, malformed and deadline-expired bounded attempts still
occupy their reservation until their owned values are released.

Fixed transport profile: `C=2`, `R=32`, `P=0`, explicit `:http1`, OTP `:ssl`,
`:native_v1`, `buffer=recbuf=sndbuf=8192`, raw streamed responses and manual
redirects. No decompression, arbitrary `%URI{}`, `content_type:` convenience
input, buffered iodata body, caller callbacks or caller-supplied option tree.
Use a literal pinned IP, explicit authority, finite timeout values and existing
origin validation. These are additional admission restrictions; no upstream
validation is bypassed.

The first pure slice should use this deliberately small source grammar:

| Value | Boundary and canonical form |
| --- | --- |
| URL | Owned compact binary, at most 65,536 bytes including scheme/authority/path/query; no userinfo or fragment; parsed host at most 253 bytes. Rebuild from validated route authority and target, preserving existing escaping and empty-query semantics. Also satisfy upstream's separate target-plus-header charge. |
| Method | Existing supported finite method enum, not a newly allocated atom or arbitrary binary token. |
| Request fields | Proper list of at most 256 binary pairs, `sum(name_bytes + value_bytes + 32) + target_bytes <= 65,536`; bounded traversal stops at field257. Count both list and tuple nodes. Validate complete bounded values without constructing an unbounded diagnostic. |
| Upload | `nil` or one Gaoxy-owned stream PID. Exactly one producer and one outstanding ACKed nonempty binary chunk, at most 65,536 bytes; at most one finish operation. Empty chunks may be omitted. Producer/source backing and its next-read overlap are charged separately. |
| Trailers | Proper list of at most 128 compact binary pairs; `2 + sum(name_bytes + value_bytes + 4) <= 65,536`, plus the existing trailer declaration/forbidden-name checks. This is a wire cap, not ETF size. |
| Trust source | At most 128 compact DER certificate binaries, each at most 65,536 bytes, aggregate at most 1,048,576 bytes; additionally require the final upstream policy ETF cap. This initial pure profile is server authentication, with fixed `verify_peer`, depth4, TLS1.2/TLS1.3 versions and generated SNI. No arbitrary TLS keyword passthrough. |
| File-backed trust | A bounded compact pathname of at most 4096 bytes and an external bounded reader yielding one raw DER file under the same DER limits, or a previously prepared compact DER collection. The pure module performs no I/O. Read at most the allowed source bytes plus one sentinel byte; rejected reads and source-plus-copy coexistence remain charged. |
| Policy structure | Construct a fixed explicit option grammar from the preceding values and fixed socket options. Enumerate every map/list/tuple constructor; do not inherit the public depth16/list4096 grammar as a heap conversion rule. |

The trust limits above are recommended **local profile choices**, not claims
about upstream limits. PEM decoding, client cert/private-key material and other
supported TLS configurations require additional source/normalization schemas
and decoder peak proofs before their activation profile can be added. Existing
dedicated transport behavior is not changed by this preparatory slice; reject
an unsupported managed profile explicitly, with no silent fallback. A later
expansion must preserve the product's trust/credential identity requirements.

Compact means a retained binary's referenced backing is bounded by its logical
size under the pinned representation, not merely that `byte_size` is small.
Construct owned compact copies of all retained binary leaves, including nested
certificates, names, values and URL pieces. Tests use large-parent subbinaries
to check this property. Source values must already have a finite backing cap:
for each transformation charge the old compact source and its new compact copy
until ownership release. Several references to one refcounted binary are one
backing allocation plus several wrappers. Copying short heap binaries across
processes can duplicate payload and must use the corresponding runtime rule.

Pure output should be a canonical policy/request value plus a constructor
manifest and source-size provenance. It must not contain a scope PID/handle,
an executable fun, a completion receipt or a claim that trust is cryptographically
valid. HTTP/OTP retain responsibility for actual certificate/protocol checks.

## Admission and ownership invariants for later integration

1. At most 32 charged attempts exist per scope, **including preparation and
   rejected Fetch attempts**. Acquire a token before Fetch, task capture, upload
   stream creation or managed ETS lookup. A full gate returns without retaining
   request payload in an unbounded admission mailbox. P0 means no payload queue.
2. Add at most one charged policy-construction attempt per future custodian at a
   time; a bounded source may coexist with its normalized result. The manager's
   existing aggregate byte gate must include preparing and retiring generations.
   A per-scope result alone does not bound an unlimited number of scopes/routes.
3. Ownership moves from bounded source to prepared value to request guardian.
   Record every sender, receiver and in-flight message edge. Charge both term
   structures during a copy and distinct binary backing only once when shared.
4. A request token remains charged through public completion. Timeout, cancellation,
   process death or `cleanup_unconfirmed` never refunds an uncertain reservation.
   After rejection before a Promise exists, the preparation owner must finish
   releasing its values before refund. Capacity is not released merely because
   upstream ingress is free.
5. A persistent custodian calls `ManagedTransport.open/1`; a temporary opener
   would die and abort the creator-monitored scope. One bounded retirement
   initiation helper and at most one abort-escalation helper are allowed per
   scope. Public initiation's fixed 5000ms call must not extend the caller's D.
   Pending late work remains tracked. Only successful public
   `await_retired(receipt, finite_remaining_ms)` confirms retirement.
6. Response ACK follows consumer release/transfer of the prior chunk; the consumer
   cannot retain an unlimited history under this ledger. Retaining a completed
   response elsewhere needs its own reservation. Upload ownership obeys the same
   rule. No retry, redirect, periodic snapshot or public-operation spam is included.

These are implementation acceptance invariants, not evidence that the current
Gaoxy adapter already implements them. No core HTTP dependency is introduced.

## Constructor ledger and finite derivations

Represent a charge as a structured expression, not an ETF multiplier. Distinguish
`binary_backing(bytes, provenance)`, `binary_wrapper(kind)`, `cons(count)`,
`tuple(arity, count)`, `map(shape, count)`, `integer(bits)`, closure environments,
and the specific runtime object/message/ETS classes. On this 64-bit VM, a cons
cell is two words and an n-tuple is n+1 words. Runtime-specific wrapper, map,
bignum, monitor, timer, ETS and message constants remain certified inputs (P2).
The same immutable tuple may be shared inside one process; conservative charging
may count references as separate complete representations if that overcount is
explicit. It cannot omit a process/ETS copy edge.

Some useful finite results follow directly from the source:

* A list of h header pairs has `h` cons cells and `h` two-tuples: `40h` bytes of
  skeleton per representation. Thus request fields contribute at most 10,240,
  response fields at most 655,360, and trailers at most 5,120 skeleton bytes.
  The response count is conservatively 16,384: a minimal ordinary header line
  consumes four bytes (`a:\r\n`), and the final line's omitted CRLF is covered
  by the required status-line bytes in a head of at most 65,536. Upstream does
  not impose a 256-field response cap. Strings, maps and temporary lists are extra.
* An upload binary of size n is chunk-framed with at most `hex_digits(n)+4`
  extra bytes, hence at most nine at n=65,536. This does not count the final
  zero chunk/trailer representation, send iodata nodes or a second source buffer.
* Before another normal parser delivery, unfinished head/trailer carry is at
  most H=65,536 logical bytes; incomplete size-line carry is at most8192,
  chunk-CRLF carry at most1, and body states consume available bytes. A terminal
  `:done` remainder is different: it can retain the whole last delivery and is
  charged in the terminal phase, not rearmed as a new H-byte input carry.
* Given a certified maximum delivery logical size d, a parser invocation starts
  with at most `t=H+d` logical bytes. Every `{:body, binary}` event consumes at
  least one byte, so there are at most t body events and at most t total body
  payload bytes in that invocation. There is at most one final-header event,
  one trailer event and one done event. Informational heads are parsed and
  discarded without event fanout (`HTTP1.parse_head_response/5`).
* The body-event accumulator and its reversed result can coexist. Conservatively
  counting separate pair tuples and cons cells for each gives at most `80t`
  bytes of body-event skeleton across those two representations, plus binary
  wrappers, final-header/trailer/done events and their payload structures. This
  is a constructor bound for those two lists only, not a pipeline copy factor.
* Content-length and status decimal integers have at most H source digits;
  complete chunk-size lines have at most t bytes, despite the8192 unfinished-line
  guard. A parsed nonnegative n-digit decimal or hexadecimal value has at most
  4n bits. Use `integer(4n)` with the pinned limb representation and separately
  account for simultaneous accumulators/conversion temporaries. It is incorrect
  to assign one machine word to arbitrary peer lengths.

`HTTP1`'s 65,536 emission cap applies only in `:chunk_data`. Its `:body_eof`
and `:content_length` paths can emit a full delivery-sized binary. Therefore
the response transfer row must use d/t and backing provenance, not F=65,536
for every framing mode. Source: `deps/http_core/lib/http/http1.ex`:
`append_buffer/2`, `parse/2`, `parse_head/1`, `parse_headers/1`,
`parse_content_length/1`; `SocketClient.handle_events/2` consumes the event batch
and blocks on stream ACK before `rearm/1`.

The append peak is **old backing + delivery backing + new concatenation
backing**, with deduplication where proven. Logical carry H does not bound old
backing: a tiny carry may reference a previous t-sized concatenation. Repeated
append/slicing therefore needs a backing recurrence, not just `H+d`. Establish
whether the pinned VM copies, shares or grows appendable backing, and bound
that retained allocation (P1/P2). Do not assume the byte count of a slice is
its allocation size.

Header parsing needs the source line list, split results, pair accumulator,
reverse result and validation byte lists; responses passed to caller/stream
introduce further structures. Bound each source transformation independently,
including its failure path. Total allocated garbage over many informational
heads is not total simultaneously reachable memory, but that distinction needs
liveness evidence; GC heap slack is outside the ledger.

## Required peak expression

For a scope, partition the ledger into nonoverlapping categories:

```text
B_scope = B_fixed
        + B_policy_peak
        + C * B_connection_external_peak
        + R * B_attempt_peak
        + B_shared_control_peak

B_attempt_peak = max over allowed request phases and transitions (
    source/prepared/request term structures and distinct backing
  + parser/delivery/events/stream/consumer structures and distinct backing
  + upload/framing/send structures and distinct backing
  + request-local process/closure/monitor/timer/message objects
)
```

Summing independently proved phase maxima is an acceptable conservative
alternative to solving exact overlap. Every summand must still name its objects,
copy edges and finite multiplicity; an arbitrary factor8 is not such a proof.
Do not count a shared connection's long-lived socket handle/resources once per
request as well as in `B_connection_external_peak` without documenting overcount.
Do not omit the request-local handle copies either.

| Category | Required coverage / finite count already known |
| --- | --- |
| Fixed | Four upstream scope children: coordinator, H1 pool, idle H2 pool, H2 connection supervisor. Two ETS tables, 32 ingress rows, one config row, gate and latch atomics. Add Gaoxy custodian/participant records when integration is designed. |
| Policy peak | Original compact sources, canonical policy, supervisor start arguments, scope state, config ETS copy, serialization/hash, and scope-open temporaries. Separate permanent policy storage from per-attempt ETS lookup and option merge copies. |
| Connection external peak | Two connection reservations, dial/socket/TLS handle resources and retained delivered binary backing outside the TLS-internal exclusion. Derive the exact underlying resource list from the pinned OTP SSL socket representation, not C alone. |
| Attempt peak | Up to eight conservative roles per request: tracker, Fetch task, owner, upload stream, response stream, dial worker, send worker, upload writer.32*8=256 is a role ceiling component, not a complete process count; guardian and adapter roles must be added. Map each role's spawn/exit and overlap. |
| Shared controls | Scope maps, pool pending/idle entries, timers, in-flight calls/replies/casts/DOWN, helper/receipt state and temporary mailbox snapshots. The H1 pool has at most two entries, each with a preparing timer/monitor or idle timer. `queued_socket_event?/1` copies a message-list representation; count it too. |

For several scopes the aggregate gate reserves the sum including retiring
scopes and preparation peaks. No unbounded population is hidden in a "global"
Gaoxy manager. Global OTP service baseline is excluded as declared above.

## Proof obligations with exact closure conditions

| ID | Local work and required evidence | Current disposition |
| --- | --- | --- |
| P0: boundary | Implement the bounded grammar, compact ownership manifest and all-attempt reservation model; identify the native ingress/producer's source-backing bound before crossing into the managed path. Test rejected values and old-source/new-copy overlap. | Pure slice can proceed; current adapter enforcement NOT ESTABLISHED. |
| P1: delivery | For actual inet backend, raw packet mode, no kTLS/distribution path and effective socket options, derive maximum delivered logical bytes d **and backing bytes**, plus simultaneously outstanding deliveries. Pin effective SSL active-N configuration for the scope lifetime. Trace raw driver delivery, TLS record carry, application concatenation and public owner delivery. | Exact Erlang SSL source inspected; driver/source and backing proof incomplete. `d=100*8192+18437` is not certified. |
| P2: representation | Obtain matching ERTS source/build definitions or authoritative matching-layout proof for binary wrappers/backing growth, maps, bignums, ETS table/row objects, atomics, process/monitor/timer/message metadata and copy semantics. Enumerate used classes; supply certified finite constants/formulas with provenance. | Erlang sources available; relevant C definitions not found in this installation's file inventory. Source acquisition is next local evidence work, not a demonstrated upstream API gap. |
| P3: policy | Count fixed constructor grammar and all actual upstream `freeze`, hash/serialization, supervisor, ETS and per-attempt option transformations. Resolve eager host-CA reference/list behavior under the declared immutable-global exclusion. No PEM decoder or client-key proof is implied by the initial DER grammar. | Requires pure tests plus source liveness/copy accounting; no universal ETF multiplier. |
| P4: request phases | Produce a phase/copy table for launch, dial, send, parser batch, response handoff, upload, terminal/failure and cleanup. Each row lists roots, object counts, binary sharing, maximum concurrency and release barrier. Include request wire additions (Host/framing), complete-line bignums and all framing modes. | Finite constructor components above; full overlap table unfinished. |
| P5: turnover | Bound control backlog over arbitrarily many requests/reuses, not only currently live entries. For each signal class prove bounded producers/outstanding operations or an ordering/consumption barrier before capacity can recycle. Include timers, socket transfer, DOWN, timeout replies and mailbox-list copies. | No H1 unbounded sequence demonstrated; induction unfinished. See next section. |
| P6: composition | Evaluate the expression only after P0-P5 are closed, verify aggregate manager admission covers all roots, and independently review category coverage, arithmetic and adversarial transitions. Store source/runtime/profile fingerprints with the result. | No numeric activation reservation; NOT RUN. |

Pinned OTP evidence sharpens P1 without completing it. `ssl_record.hrl` defines
16,384 plaintext bytes, TLS1.2 ciphertext allowance2048, TLS1.3 allowance256;
five record-header bytes give the conservative single TLS1.2 record quantity
18,437. `ssl_internal.hrl:55` defines default internal active-N100, while
`ssl_config:get_internal_active_n/1` and
`tls_gen_connection_1_3:internal_active_n/2` honor an application integer override.
The receipt's `nil` setting was taken before fixture startup; it does not pin
future effective settings. The profile must reject incompatible configuration,
not mutate global SSL settings to manufacture a pass.

`tls_gen_connection:next_tls_record/3` appends parsed records to existing
ciphertexts. `next_record` concatenates consecutive application fragments with
`iolist_to_binary`; `flow_ctrl/2` controls transport reactivation; and
`ssl_gen_statem:read_application_data_deliver/7` stops public delivery when
active-once becomes passive. These show why one TLS record and one raw TCP
read are not automatically the public delivery bound. The scoped exclusion of
TLS internal heaps does not remove this public delivery proof requirement.

### Turnover induction required by P5

For each class use a potential `outstanding = emitted - consumed_or_flushed`.
Prove a constant bound independent of completed-request count. Useful starting
facts from installed sources are:

* Scope ingress is freed on tracked request DOWN, and connection slots wait for
  tracked resource release. These can bound outstanding completion/resource
  controls if all emissions and resource roles are enumerated.
* Scope schedules its next reconcile tick only after processing the current
  one. Controlled retirement contributes at most the one initiation plus one
  escalation, rather than arbitrary repeated `retire` calls.
* H1 pool operations use synchronous calls, and its normal GenServer loop
  consumes unmatched infos. A stalled pool therefore blocks some subsequent
  progress; the 32-attempt gate limits concurrent call producers. However,
  synchronous calls to other processes inside callbacks and pending signals
  must be included in the induction.
* Pool `remove/2` and activation cancel timers; demonitor uses `[:flush]`.
  Cancellation is not proof that a timer message already emitted has been
  consumed. `queued_socket_event?/1` scans, rather than consumes, socket messages.
  Derive the ordering of cancel completion, timer signals, controlling-process
  transfer and the next pool call under exact OTP semantics before bounding
  stale generations.
* Tracker completion uses both calls and casts, and deadline calls can emit
  aborts. Count their per-request maximum, including failure paths. A finite
  resource map does not independently cap its unprocessed controls.

Finite maps plus eventual scheduling are insufficient proof. Conversely, an
unproved late-signal bound is not evidence of unbounded growth. First attempt
the source ordering/credit proof and focused public adversarial tests. If an
arbitrarily repeatable legal sequence can increase outstanding included objects
without consuming a bounded credit, record that sequence and the missing
barrier, then route the specific dependency issue. Do not invent a local private
pool flush, lifetime reuse quota or periodic rotation to conceal the missing
contract. Any such policy change needs separate architectural consideration.

## Next executable slice and acceptance

Recommended ownership for the Sol coordinator: new pure modules under
`apps/gaoxy_proxy/lib/gaoxy/proxy/` named
`managed_h1_preparation.ex` and `managed_h1_accounting.ex`, with corresponding
scoped unit tests. These are proposed additions, not files created by this memo.
Do not edit the adapter or start a manager/custodian in this slice.

Suggested semantic interfaces (final naming can follow repository conventions):

```elixir
prepare_policy(bounded_source) -> {:ok, canonical, constructor_manifest} | {:error, reason}
prepare_request(bounded_source) -> {:ok, canonical, constructor_manifest} | {:error, reason}
accounting_expression(profile, manifests) -> expression_with_named_obligations
evaluate(expression, certified_proofs) ->
  {:ok, bytes, provenance} | {:error, {:unproven, obligation_ids}}
```

No default-zero term, best-effort numeric total or activation-ready object is
allowed when a certificate is missing. Certificate compatibility must include
cohort/runtime/profile identity; arbitrary caller-supplied constants are not
proof. Unit tests may use explicitly synthetic constants to check expression
arithmetic but cannot thereby produce production qualification evidence.

Acceptance for that slice:

1. Enforce the finite input grammar including count257/count129, exact byte
   boundaries, malformed/improper lists, arbitrary `%URI{}`, convenience options,
   buffered iodata, unsupported trust forms and mismatched origin/profile.
   Bounded rejection must not copy an entire rejected arbitrary tree or include
   it in an error value. Tests distinguish source preconditions from guarantees
   the pure function can itself enforce.
2. Verify compact ownership for URL/field/DER slices and source-plus-normalized
   manifest charges; do not use a round-trip-only test. Check ordered duplicate
   fields/trailers and existing URL empty-query behavior.
3. Check independently calculated constructor formulas and separate request,
   response and trailer limits. Cover one-byte chunk event batches, a large
   content-length/EOF event, complete long chunk-size lines and rejected heads
   in the accounting model without claiming they exercised network acceptance.
4. Missing P1/P2/P5 (and any other unresolved row) must prevent evaluation to an
   activation total. Missing or mismatched provenance must fail closed. All
   production profiles remain unqualified until independent proof review.
5. Scoped pure unit tests, formatter and independent review pass with a recorded
   diff; no HTTP runtime/fixture activation, network, dependency patches or core
   dependencies are introduced. Stop that implementation slice at this boundary.

After the pure slice, close P1-P5, independently validate P6, then return to the
existing process-integration plan. Managed H1 public functional probes and its
separate at-least600-second soak are still mandatory; they corroborate lifecycle
and boundedness but cannot replace the symbolic proof. Managed H2 needs its own
proof, issue#86 resolution and separate at-least600-second soak. Existing
compatibility success is not managed activation acceptance.

## Alternatives and migration implications

Keeping the generic public API and assigning a larger constant fails because
tiny slices can retain arbitrarily large backing. Restricting only accepted
policy ETF size misses rejected/preparation peaks and constructor expansion.
The selected compact grammar is auditable and can be extended one representation
at a time, at the cost of initially qualifying fewer TLS input forms. It is a
new managed profile; it does not change existing dedicated-client input support.

A complete peak expression is more work than a single guessed multiplier, but
it makes runtime/cohort drift explicit. Changing OTP, backend, socket options,
producer behavior, TLS options or parser source invalidates affected certificates
and requires requalification before activation. No new external service,
dependency, publication or permission is needed for the pure slice itself.

## Verification and handoff

Architecture deliverable **DONE**; implementation and numeric activation proof
remain **NOT RUN / NOT ESTABLISHED** as identified above. Read-only commands
inspected `git status --short`, `git rev-parse HEAD`, scoped sources and the
runtime JSON; Python SHA-256/arithmetic checks confirmed the constructor
subtotals and historical subtotal. Static markdown/reference and whitespace
checks are recorded by the handoff. No Mix, runtime, fixture, network, dependency
installation, upstream mutation, commit or process-interference command ran.

The initial source-search command named nonexistent `tls_connection.erl` and
returned exit2; it was corrected to the installed `tls_gen_connection` files.
The C-layout filename inventory returned no matches (exit1), leaving P2 open;
neither event is a test regression or external API defect.

Received counters, unchanged: Task1 Sol2 failed / Astra1 PASS; Task5 Sol4 total
with2 unsuccessful / Astra2 total with1 unsuccessful. This architecture
assignment consumes **zero** Astra repair rounds. It grants no additional
recovery budget. All this agent's commands finished; no subprocess or peer was
started. Parent probe session68920 and other workers were not touched.

No new user decision is required for the proposed pure slice under continuing
authorization. The parent owns implementation delegation, proof closure,
upstream routing if a defect is demonstrated, and final activation acceptance.
Residual risk is precisely the unresolved P0-P6 coverage, not a certified memory
budget or a measured leak.

### Inspected input SHA-256

SSL source filenames below are relative to the pinned installation's
`lib/ssl-11.6.0.6/src/`; dependency filenames are relative to this worktree.

| Input | SHA-256 |
| --- | --- |
| `ssl_record.hrl` | `9ece990412395bc6ed2e1c8719d6603a98dc150de3194526007dbcd79bbc468e` |
| `ssl_internal.hrl` | `613a67c2b607b0dc59ab7895ebbfbe3fa04b55579ce0071f2cffd3798e4b450f` |
| `ssl_config.erl` | `012c95f6160700d875147ec38678a25f48d0d3ee88e685a5f38f914806660269` |
| `tls_gen_connection.erl` | `c281f3b8cda54b861f80b3136263f1187755ba6f057885c3a2cbab7eebfd4b7b` |
| `tls_gen_connection_1_3.erl` | `6d42af182b581872842d6943b1efb56aaf92decca01ad0339ff9e2fe11b8ce5c` |
| `ssl_gen_statem.erl` | `6be9ac90ece29d7936bff0ab678fc34511f58964cfe7121962f74bb9ecc37d62` |
| `deps/http_core/lib/http/http1.ex` | `c84ddf5081b4d61a824789ebb9f606dc4c6d6aa91b69f233bde3b3c5d3997422` |
| `deps/http_runtime/lib/http/http1/pool.ex` | `703edf9b1152889ac9bc6d8d48cedda528affed3b9e1ed41fdd057b42c067fcb` |
| `deps/http_runtime/lib/http/managed_transport/scope.ex` | `73fb847f72846aa1d1f3fa0f3e4fc039741f0212b1d7fd4177f63d020e26b57b` |
| `qualification-runtime.json` | `d38c8044be73275926015b8d1af6f74a706040abc521cd009754b3baa8540e4a` |
