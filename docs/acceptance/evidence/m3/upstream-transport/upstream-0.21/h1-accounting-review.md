# Narrow managed H1 retained-accounting review

Task: `m3_final_review`, narrow H1 accounting; direct Sol source investigation.
Reviewed 2026-10-11 Asia/Shanghai. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, HEAD `4cc7a1a967d1b90a62d42db438316b10a03a1e16`.
Only this report is owned. Existing parent/peer source and documentation edits
are preserved. No Mix, fixture, network, dependency change, upstream action or
commit was performed. Prior worksheet is this reviewer's work, not a separate
independent certification. This review supplements its missing H1 terms.

## Verdict

**Complete numeric H1 retained reservation: NOT ESTABLISHED.** The existing
**261,199,114-byte value is a component subtotal**, not a hard retained-byte
bound. No guessed copy multiplier, zero unknown term or empirical RSS value
completes it. Broad public API inputs lack binary-backing and convenience-input
bounds. Gaoxy's narrower controlled input contract can exclude those public
inputs; that does not supply the remaining allocation/lifecycle/OTP proofs.

Profile reviewed: C2/R32/P0, explicit H1, OTP `:ssl`, `:native_v1`, frozen
`buffer=recbuf=sndbuf=8192`, nil/PID uploads, a single ACKed binary producer
with chunks at most65536, raw streamed responses, manual redirects. Admission
must gate **all attempts before `HTTP.fetch`**, including rejection preparation,
not merely successfully admitted requests. Pending and unconfirmed capacity
remains charged through public completion/retirement. No new H1 peer-driven
unbounded-notification defect is demonstrated here; the separate H2 header
and SETTINGS findings are not an H1 proof or H1 defect.

## Public-input gaps and controlled preparation

Policy accepts binary trust material by logical `byte_size`, list/depth and
`external_size` checks (Policy48–103,187–211,289–293,310 onward); it neither
compacts slices nor checks referenced backing allocation. A finite tiny slice
can retain an arbitrarily larger caller-created refcounted binary after the
caller ceases to retain it. The following is a **NOT RUN**, source-backed
minimal recipe, assuming HTTP applications already started and a valid DER CA
`der` with `64 < byte_size(der) <=4096`:

```elixir
def create_scope(der) do
  backing = der <> :binary.copy(<<0>>, 8 * 1_048_576)
  slice = binary_part(backing, 0, byte_size(der))

  HTTP.ManagedTransport.open(
    origin: "https://localhost:443",
    connect_address: {127, 0, 0, 1},
    http_version: :http1,
    tls_backend: :ssl,
    http2_profile: :native_v1,
    max_connections: 2,
    max_requests: 32,
    max_pending: 0,
    idle_timeout: 30_000,
    socket_opts: [
      buffer: 8192, recbuf: 8192, sndbuf: 8192,
      send_timeout: 1000, send_timeout_close: true
    ],
    ssl: [verify: :verify_peer, cacerts: [slice]]
  )
end
```

All keys/profile values are accepted by installed Policy; CA validation accepts
binary entries without decoding them at scope opening. The slice's logical
size and serialized policy fit1MiB; the extra8MiB is absent from those checks.
`open` creates scope state and configuration ETS without a fetch/dial. On
return and caller GC, the scope can remain the reason the backing stays live.
Caller originally allocates the bytes; this is a **managed retention after
caller ownership ends** gap, not evidence that scope allocates8MiB itself.
State/ETS/task references can share that one allocation: do not multiply8MiB
by reference count. Increasing the finite appended length defeats any bound
based solely on logical policy bytes. Runtime subbinary representation and
memory observations were not executed or measured.

This deserves upstream **needed**, rather than automatically blocker, if
Gaoxy constrains preparation to owned bounded file/DER inputs and documents
that provenance. Parent owns verification/routing. Such a contract must cap
original source and normalized backing, preparation concurrency and failed
preparation inputs, and count file/PEM/DER conversion peaks. File loading reads
at most1MiB+1 before rejecting and closes the file (Policy240–252), but source
cap alone is not a PEM decoder heap/copy proof. No dependency workaround is
implemented here.

Other broad inputs are separately excluded by the intended adapter:

- `%URI{authority: huge}` survives Fetch282–298; managed origin checks host,
  scheme/port, while request charge checks path/query/headers, not authority.
- `content_type:` is retained unchanged (FetchOptions289–290,306–307) and H1
  adds Content-Type after managed preparation (Request152–154,183–189,
  263–264). A large convenience value with PID body and no existing field
  escapes the earlier header charge. URL strings and explicit bounded headers
  in Gaoxy do not use these public forms.
- Buffered iodata can have arbitrary zero-payload structure. The nil/PID
  contract excludes it; ACK alone does not make a binary chunk compact.
  Controlled upload producers must bound source/backing provenance as well
  as each logical chunk. Request/header/URL slices need the same provenance
  contract. Parser-generated response slices need delivery/backing accounting.

Policy.freeze eagerly evaluates `:public_key.cacerts_get()` even when a CA list
is supplied (Keyword.put_new); SSL's default option construction also obtains
host CAs before dropping defaults/merging. The host snapshot is not bounded by
the configured final1MiB policy. Charge the host/global capture and temporary
list/normalization terms, or explicitly state a pinned shared-global exclusion.
Do not assume fetching persistent-term data duplicates every binary payload.

## Representations and copy stages

These are distinct live **representations**, not proven independent copies of
binary payload. Structures can copy across processes/ETS while large immutable
binary backing is shared. Maximum simultaneous overlap remains to be resolved.

| Stage | Retained/transient representations | Source / unresolved multiplicity |
| --- | --- | --- |
| Preparation | Original options/source paths; up to1MiB+1 file read; PEM decoded entries; normalized TLS/socket keywords; deterministic policy serialization/hash; host CA snapshot | Policy48–103,187–252. Accepted policy caps do not bound rejected caller terms or decoder peak; bounded Gaoxy preparation contract required. |
| Scope creation | Policy in supervisor start args, Scope state and configuration ETS; opaque handle contains no policy | Facade94–118, Scope11–50. State+ETS representations explicit; exact DynamicSupervisor retention/GC must be proved, not assumed zero. |
| Per-attempt preparation | ETS lookup `{policy,injection}` copied to caller; merged transport keyword and prepared request | Facade193–214. At mostR only if all callers are gated; ingress alone does not bound concurrent rejected attempts. |
| Request launch | Caller request; Fetch task capture; owner task capture; lifecycle registration/control messages | Fetch322–388, SocketClient45–75. Phase overlap and message/closure structures need constructor-specific counts. |
| New connection/TLS | Dial options, normalized/default/merged SSL options, OTP TLS state/cert decoding/session internals; socket buffers | SSL wrapper and pinned OTP. C bounds reserved transports, not number/heap of OTP processes or normalization transients. |
| H1 request send | Headers list/Request, inserted body headers, header iodata, wire serialization, send-worker arguments | SocketClient1701–1768. Request charge is not an exact serialized-wire cap; Host/framing/status delimiters are extra. nil send and PID upload are alternatives. |
| PID upload | Producer held chunk, stream/message, upload reader, framed send iodata/transport reference | Stream84–114,310–317; Upload22–60,95–155. One ACKed producer; chunk framing overhead<=9 bytes at65536. Sharing/copy and source backing remain explicit. |
| H1 response | OTP delivery, old carry, concatenated carry+delivery, split head/lines/fields, reversed headers, parser events, streamed chunk/message/reader | HTTP1:83–108,235–279; SocketClient1384–1435,1469–1473. Entire event batch is processed before rearm; ACK limits body progression, not head structures or slice backing. |
| Trailers/termination | Initial-header declaration split; validation byte lists, accumulator/reverse list, Headers; finish/trailer/end messages; retained reader response | Trailers, Stream235–240,342–357. One controlled terminal/finish, finite reader ACK/close contract; count response and upload forms separately. |
| Retirement | Public helper/receipt monitors; scope/pool close controls; DOWN and canceled-timer messages; retained unconfirmed resources | Scope188–247, H1Pool70–203. Parent permits one initiation plus one abort escalation helper per scope. Arbitrary public retire/wait spam excluded; finite live state alone is not a backlog proof across churn. |

## Header/trailer allocation units

Request has at most256 fields and65536 charge bytes including32 per field and
path/query (Policy149–157). H1 **response** head cap65536 is not a256-field cap:
`a:\r\n` needs4 wire bytes, so16384 is a safe conservative field count (status
line/separators only lower it). Headers stores the supplied list unchanged
(Headers83–85). A64-bit list cell is2 words and a2-tuple3 words; final skeleton
alone is `16384*5*8 =655360` bytes per response-header representation,
`256*5*8 =10240` request bytes, and `128*5*8 =5120` trailer bytes. These exclude
binary wrappers/backing, Headers struct/map, parser-event and message overhead,
and transient split/reverse lists. They are components, not full conversion.

Trailers permits128 fields and65536 **wire** bytes (name+value+4 per field,
plus2), not65536 ETF bytes. Parsing guards block+4<=65536. Validation builds
byte lists for names/values; split declaration/forbidden-name checks, accumulate
and reverse lists need transient cells charged even for input later rejected.
`String.split` on a response head creates a line list, field split results,
pair tuples and accumulator/reverse lists; those can coexist with head/delivery
backing. Content-Length and complete chunk-size lines can form bignums rather
than64-bit integers. The8192 chunk-line guard only limits unfinished no-CRLF
carry; complete line length is bounded by qualified delivery+carry instead.

`external_size` is ETF wire serialization, not BEAM allocation. For example,
STRING_EXT has3+N bytes for a byte list while list cells need2N words before
heap/allocator overhead. A retained owned-representation charge can use constructor-specific word
formulas for lists/tuples/maps/bignums, distinct binary wrappers and pinned
ETS/message representation overhead. The design excludes total BEAM/RSS, GC
heap slack, allocator fragmentation, kernel buffers and TLS-internal measurement;
these are not prerequisites for that narrower ledger. No
universal `8*external_size` or guessed policy-copy constant is certified here.

## Processes, ETS and control inventory

| Object | Source-derived live component | Remaining hard peak proof |
| --- | --- | --- |
| Scope children | Scope + H1 pool + idle H2 pool + H2 connection supervisor =4 static dependency processes even H1 | Bound scope/child metadata representations; global services and total process heap measurement are excluded as declared by the design. |
| Scope storage |2 ETS tables;32 ingress rows and1 config row; gate+latch =2 atomics | ETS table bucket/row/copy allocation and atomics object bytes; scope maps/keywords. |
| Requests | Tracker, Fetch task, owner, upload stream, response stream, dial worker, send worker, upload writer =8 conservative roles; send/upload are alternatives | `32*8=256` is a role-count component only. Exact phase overlap, stream startup before scope bind, guardian/control metadata still extra; total per-process heaps and OTP global internals are excluded from this ledger. |
| Request monitors/timer | Starter/task/owner/reader/scope/resource monitors as applicable; one owner deadline timer | Finite per-request resource-role formula, demonitor races and terminal/error messages; not one monitor total. |
| Scope admitted trackers | At most32 tracker monitor entries and admission request/monitor maps | Request release requires tracker DOWN. Early/rejected attempts must be externally gated. |
| Connection slots/resources | At most2 slots reserved before dial; resources deduplicated by PID/port with one scope monitor each | Slot count is not exact TLS socket process-list length; all underlying socket/dial/protocol resources stay charged until DOWN. Resource/DOWN peak across churn needs proof. |
| H1 pool | At most2 preparing entries (9 fields each), each owner monitor+1s timer; idle timer on activation | Queued stale canceled-timer/socket/DOWN messages across reuse; Process.info(:messages) makes a temporary local list. |
| Scope reconcile | One next timer scheduled only after consuming current reconcile | Tick/control mailbox allocation and interleaving with lifecycle releases. |
| Retirement helpers | At most one initiation + one abort escalation per scope by Gaoxy design | Helper heaps/messages/receipt monitor costs and finite control-DOWN overlap, including both pools receiving close_idle. |

No repeated informational-head fanout analogous to H2 was found: H1 discards
informational heads (HTTP1:220–222). H1 idle active-once discards/closes on an
unexpected event; streamed data ACK precedes rearm. These support a separate
H1 qualification path. They do not prove zero lifecycle-control backlog under
unlimited turnover or fixed maximum OTP TLS resource processes.

## OTP delivery premises and subtotal

Local readable source is Nix store Erlang28.5.0.5 / SSL11.6.0.4 at the paths
hashed below. flake selects erlang28/elixir1_18; **identity with the parent's
actual qualification VM is not independently established by this report**.
Source plaintext max16384, TLS1.2 ciphertext extra2048 and record header5
suggest the existing18437 component (ssl_record.hrl142–144). SSL internal
active-N default100 is defined in ssl_internal.hrl55; ssl_config132–145 and
2058 onward allow any integer application override without a1..100 clamp.
TLS1.3 internal_active_n435–453 also honors the integer override, with separate
kTLS/distribution paths. The runtime must pin backend, disable/exclude those
paths as applicable, prove effective socket sizes and constrain active-N.

TLS flow parses concatenated decrypted application records from a transport
batch, queues user data and delivers active-once before becoming passive
(tls_gen_connection679–798; ssl_gen_statem933–944,1499–1597,1772–1791).
This is not an independent proof that every raw TCP event is<=8192 or that TLS
backing/queue has at most exactly100 such events plus one record. Effective driver delivery behavior, partial TLS record/ciphertext carry,
decrypted delivery/copy coexistence and backing provenance require the exact
VM/source/profile receipt; total kernel/TLS-internal allocation is excluded.
The legacy ceiling remains **conditional**, not universally proved here:

```text
Q =1048576
D =100*8192 + (16384+2048+5) =837637
F =65536
8*(D+F) =7225384
8*65536 =524288
2*65536 =131072
3*65536 =196608
legacy_request_component =8077352
Q +2*D +32*legacy_request_component =261199114
```

The8 factor is inherited from Gaoxy's old expression; this review has not
proved it as the maximum simultaneous retained copies of these stages.
A complete reservation needs an allocation expression with named terms:

```text
B_H1 = legacy_component_subtotal
     + X_policy_state_ETS_supervisor_prepare_and_serialization
     + X_owned_input_file_PEM_host_CA_and_SSL_normalization_peak
     + X_request_response_header_trailer_structures_and_transients
     + X_upload_response_delivery_backing_and_copy_overlap
     + M_scope_ETS_atomics_and_all_request_connection_processes
     + M_monitors_timers_control_DOWN_and_retirement_peak
     + A_pinned_owned_term_message_binary_ETS_representation_conversion
     + Delta_delivery_and_legacy_window_coverage
```

This is an **unresolved accounting worksheet**, not an additive numeric proof:
terms must be assigned nonoverlapping coverage and a proven conservative
maximum; Delta must correct any unqualified delivery/window premise. Keeping
an old subtotal cannot establish unknown terms are finite or already covered.
If broad public backing inputs remain supported, X has no input-independent
finite bound under these logical caps. Under compact Gaoxy preparation those
terms become separate source/runtime proof obligations; no total is certified.

## Verification and disposition

Read-only source inspection and SHA-256 pinning, arithmetic verification and
owned-report whitespace checks only. Runtime, minimal recipe, leak measurement,
Mix, transport qualification and fixture: **NOT RUN**. Parent-supplied0.21.0
containing tag is `9813c126dc8b48055b9ee941c693fc27fa691489`; installed files
are locally hashed, not publication-verified here. Parent/architect owns the
compact preparation contract, unknown-term disposition and any upstream issue.
No user permission question or architecture redesign is needed from this
reviewer. Review deliverable DONE; numeric H1 gate remains NOT ESTABLISHED; missing derivations are pending
accounting work, not automatically an external blocker or a measured leak.
Sol repair rounds0; received Astra recovery counter0. All reviewer commands
finished; no runtime session/peer process was started or remains.

## Input SHA-256 snapshot

OTP entries use the full Nix store paths. Documentation hashes are this read
snapshot and may change independently under parent ownership.

| Inspected input | SHA-256 |
| --- | --- |
| `deps/http_runtime/lib/http/managed_transport/policy.ex` | `d2164cc922893b9cb626b3886d1fbdc1c4f479f1253446277120df6720df1279` |
| `deps/http_runtime/lib/http/managed_transport.ex` | `92e0cc7649790029cf95b51c09e6d4e845c6183462083ab2272818cf57197c54` |
| `deps/http_runtime/lib/http/managed_transport/scope.ex` | `73fb847f72846aa1d1f3fa0f3e4fc039741f0212b1d7fd4177f63d020e26b57b` |
| `deps/http_runtime/lib/http/http1/pool.ex` | `703edf9b1152889ac9bc6d8d48cedda528affed3b9e1ed41fdd057b42c067fcb` |
| `deps/http_core/lib/http/request_lifecycle.ex` | `81a3b158e33b7291422c009fb47170574b3bf6b7d9ad4023619ca84147fcf01f` |
| `deps/http_fetch/lib/http.ex` | `b86d8cc723cbab453e04dee8cf2a8bd99ca5a08d638c07a1d677ef501a495f7b` |
| `deps/http_fetch/lib/http/socket_client.ex` | `1b6b494264c8eb8620471bdb7b80910cd31db67e951d3f24e14e9cefecb4a3e7` |
| `deps/http_fetch/lib/http/stream.ex` | `552c5951d30c21ce864a77c1a61dc5e8bcda038559040028e4f3282074325d05` |
| `deps/http_fetch/lib/http/http1/upload.ex` | `e55ed4591faf1a0253d2d506dce43d1b3f794f831d48825644045250f3888d65` |
| `deps/http_core/lib/http/http1.ex` | `c84ddf5081b4d61a824789ebb9f606dc4c6d6aa91b69f233bde3b3c5d3997422` |
| `deps/http_core/lib/http/headers.ex` | `490e85607b4e375323945e984b618319a48b3bc4d08148d2e55195e41d427a4a` |
| `deps/http_core/lib/http/trailers.ex` | `440b945822366705f2098804657e8ed07b2a5e6dd29be216730a4c8e753dec75` |
| `deps/http_core/lib/http/request.ex` | `b097ad2d68d3a4d715dad594f02cc9025b6a17a267175b375a4b7d37bc675dcf` |
| `deps/http_fetch/lib/http/fetch_options.ex` | `8e035e1ec4a8c3afb68731ceb325ddf1cd1b5a780bd1b2a063e3f417241b6061` |
| `deps/http_core/lib/http/transport/ssl.ex` | `43f5f1c2d8c8d28b0cafe9e1e7b8764bc5d462214db9960815b35e0de4917636` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex` | `c58065e3e7e1accf355b9bc288fd62473918a88581008af2cb26ad941f2637a0` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex` | `6650ed1169c8284be4e87a08341a747c475994f2bce6194eda48867c2e158615` |
| `flake.nix` | `46a5d573e0915937beec01de4cdf45f7a8f9f5886276b7f6d11415e668a80be9` |
| `docs/designs/m3-upstream-transport.md` | `b71dd745310141eaa52fd7d276e327dd6b6bc1a1b51b7aa44d5f876946767dd4` |
| `docs/acceptance/evidence/m3/upstream-transport/source-api-review.md` | `cd7203e1483d2a13d0accd92846dcc7a08d9457068c60d0d4ea3b244e0a492c1` |
| `docs/acceptance/evidence/m3/upstream-transport/retained-bounds-source.md` | `1e2a4b0e7ad6a56d84b7001a321f63ae0bf7bd8b6ef39559ea1f41b692c71f79` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/independent-bounds-review.md` | `8e91a98e4cc0981b8385ea79ebaaecd9488d2b61be19dc076d4469da0ef3478a` |
| `/nix/store/5y0714j8czhkjbmjb6l6m46n5w5fyr6q-erlang-28.5.0.5/lib/erlang/lib/ssl-11.6.0.4/src/ssl_record.hrl` | `9ece990412395bc6ed2e1c8719d6603a98dc150de3194526007dbcd79bbc468e` |
| `/nix/store/5y0714j8czhkjbmjb6l6m46n5w5fyr6q-erlang-28.5.0.5/lib/erlang/lib/ssl-11.6.0.4/src/ssl_internal.hrl` | `c87f77c20ed2eca9d2fd5181d7fedabee88693b4bb592fa4408df73b29ea0c11` |
| `/nix/store/5y0714j8czhkjbmjb6l6m46n5w5fyr6q-erlang-28.5.0.5/lib/erlang/lib/ssl-11.6.0.4/src/ssl_config.erl` | `08a8cb4605c4057e27b6d7f64ba40f6671745e4aa7ce3a6897ca8ef3ffa7facf` |
| `/nix/store/5y0714j8czhkjbmjb6l6m46n5w5fyr6q-erlang-28.5.0.5/lib/erlang/lib/ssl-11.6.0.4/src/tls_gen_connection.erl` | `c281f3b8cda54b861f80b3136263f1187755ba6f057885c3a2cbab7eebfd4b7b` |
| `/nix/store/5y0714j8czhkjbmjb6l6m46n5w5fyr6q-erlang-28.5.0.5/lib/erlang/lib/ssl-11.6.0.4/src/tls_gen_connection_1_3.erl` | `6d42af182b581872842d6943b1efb56aaf92decca01ad0339ff9e2fe11b8ce5c` |
| `/nix/store/5y0714j8czhkjbmjb6l6m46n5w5fyr6q-erlang-28.5.0.5/lib/erlang/lib/ssl-11.6.0.4/src/tls_dtls_gen_connection.erl` | `05585a4bf5ce646c7a5def69e2f5e66aafadde8583359885e7b0e1648f60fa9d` |
| `/nix/store/5y0714j8czhkjbmjb6l6m46n5w5fyr6q-erlang-28.5.0.5/lib/erlang/lib/ssl-11.6.0.4/src/ssl_gen_statem.erl` | `e96edb9e3e159ff5fbb1c43cdcea288e7e6f6fa0b09581e8974e54b03a64b7c0` |
