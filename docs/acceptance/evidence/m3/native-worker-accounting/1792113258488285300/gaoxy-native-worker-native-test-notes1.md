# Native downstream-H2 extended test proposal 1

Task `native-worker-native-test-proposal1`: DONE SOURCE-ONLY PREPARATION, direct assignment. Only the paired proposal, these notes and the JSON companion under `/tmp` are assignment-owned. No repository edit, parser, formatter, compiler, application, test, network operation or Git mutation was performed. Expected cases: 8; executed cases: 0. Source review and document/hash readback are the only completed checks. This is not a runtime PASS.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, baseline HEAD `58307a7084298db309a93697b9102b2cc4c87eda`, baseline tree `a038b7d0d24f662a75b9786ee15866957b53abf0`. Parent alone owns repository/runtime/evidence/Git, and is concurrently implementing production and root test changes. The JSON binds individual observed file bytes at its capture time; it does not claim the worktree is frozen or unchanged after capture. Parent changes were read and preserved. Counters remain group Sol30/root Sol35/Astra2/2; this preparation adds 0 runtime/repair attempts.

## Preservation and intended adoption

The separate module `Gaoxy.HTTP2WorkerStartupExtendedTest` extends the parent's existing `Gaoxy.HTTP2WorkerStartupTest`. Do not replace or weaken the parent's regression, whose complete initialized payload is 131076 bytes, actual worker lease must equal `Exchange.retained_bytes(exchange)`, protocol allowance must exceed old P plus complete endpoint size, full response must succeed, and actual worker DOWN/zero accounting must be observed. Existing stale-start, capacity, terminal-trailer, independent-peer, network and browser gates also remain required. Parent chooses repository adoption/file layout and performs formatter/compiler/runtime validation.

Native stream startup contract is `%{request: reqid,timer: timer,token: token,parent_lease: parent_ref,protocol_bytes: N,bytes: W,deadline: D}`, with worker/monitor/lease nil while queued. `WorkerAccounting.reservation(state,stream)` returns `{:ok,{:native_http2_worker_v1,N,W}}`. Only an authenticated public async success permits endpoint/Exchange dispatch. D is a signed absolute monotonic integer; live validation uses remaining(D)>0, never D>0.

## Eight proposed cases

1. Real configured W-1/exact-W: start an ample-budget service, observe a genuine pending stream while Gate is suspended, derive actual N/W from that actual stream and calculator, and derive baseline from actual connection/writer lease PIDs and source reserves. Cancel calibration and cleanly stop. Start fresh services with genuine max_bytes=baseline+W-1 and baseline+W. Assert fresh actual N/W equal calibration. W-1 must refuse on wire with no Gate spawn trace and no endpoint. Exact W must enter the endpoint with the exact actual ordinary owned lease; peer RST must join the worker and return baseline. No Admission state replacement or guessed counters are used. The long valid target path reserves more startup than the small seed path, allowing the seed response to establish context under the final configured budget. Exact-W success qualifies startup only: later response/read operations have separate transient existing reservations. Ample-budget cases below require full responses.
2. Suspended Gate: actual pending startup fields and nil prelease worker/monitor/lease, native PING parsing/ACK enqueue and RST, canceled stream3 removed and sibling5 current. The trace observes the actual native owner send to the actual writer with the real encoded ACK, then actual wire ACK is required after Gate resumes. Sibling response completes.
3. Stale async failure: capture real old request-id3, reset3, establish current5/queued7, deliver a controlled delayed failure bearing the real old public async identity, and assert starter/token/startup/current/queued state unchanged. Both5/7 complete normal responses. This is deterministic receipt scheduling, not a claim that a natural wire race was observed.
4. Duplicate terminal trailers before admission: real POST HEADERS plus terminal trailer HEADERS are parsed while Gate is suspended. Endpoint initially sees incomplete body/no consumed trailers; explicit read returns both duplicate trailers in order, exact trailer byte count, complete body, unchanged N, and actual lease bytes exactly equal returned Exchange retained bytes. Poll and normal full response preserve exact charge.
5. Body/read/poll/validation error: real hello DATA, explicit read, poll, invalid read error and normal full response preserve N and exact actual owned lease bytes; invalid read returns the same Exchange.
6. Chunked endpoint error: actual partial200 response, blocked fixture inspection of exact N/current lease, then endpoint error. Wire must send RST cancel without a successful END_STREAM, actual worker must exit, accounting returns baseline and a sibling still completes.
7. Endpoint blocked with running Gate: actual finite wire PING ACK plus full sibling response while original worker is still alive; peer RST then joins original worker and returns exact baseline.
8. Peer closes with queued startup and suspended Gate: connection and idle writer actual DOWN must precede Gate resume; after resume no late Gate worker spawn/endpoint, exact zero accounting, and clean normal runtime stop.

## Limits and source findings

The native calculator is used to select a candidate W for a genuine runtime limit. This does not independently establish the correctness of its equation. Separate exact constructor/pure/source checks must substantiate P=2*max_header_bytes+4*max_read_chunk+65536, N=P+A+J and W=N+2*request.head_bytes. The constructor SPEC then CODE source gate and fresh nonzero pure checks must pass before first changed-W runtime. No new caps, dependency changes, writer redesign, Session/B migration, upstream-H2 Generation activation or H3 accounting are introduced by this proposal.

Existing writer calls synchronous Admission.start_send before socket writes. A paused Gate cannot complete a wire PING ACK. Accordingly case2 asserts real owner processing/enqueue during suspension and wire ACK after resume. Case7 requires wire ACK while the endpoint is stalled and Gate runs. This distinction was explicitly settled with the parent and is reflected in the canonical plan.

Source audit found HTTP2.Transport.read_body_step restores Admission bytes using the old Exchange before constructing the returned body with trailer_bytes. The exact trailer assertions intentionally expose that potential compatibility gap; do not weaken/drop them. This was a source finding, not an observed runtime failure. Parent owns diagnosis and any necessary compatibility repair. Existing independent-review trailer-before-worker assertions must also remain intact.

Fixture Endpoint receives the complete initialized binary unchanged and reports actual worker/Exchange/payload. It blocks on explicit commands. Normal send_resp and endpoint-error paths wait for :return, allowing exact live-lease inspection before genuine DOWN. Failure-only cleanup may stop/kill fixtures and never counts as product acceptance. Public source state/status polling and trace_delivered provide finite synchronization without arbitrary sleeps, synthetic streams, state mutation, mocked Admission totals or production hooks.

Wire collectors share an original absolute3000ms deadline across recursive SETTINGS/WINDOW_UPDATE/control/data reads; state/status polling also propagates one original deadline and bounded sys/GenServer calls. Endpoint barriers have finite5000ms bounds; request deadline is15000ms. Frame readers fail on unexpected frames; the error collector rejects successful END_STREAM. Clean closure monitors actual connection/writer, checks Gate zero including cleanup_pending, invokes Gaoxy.stop and observes the runtime's actual normal DOWN. No actor was started by this source-only work.

## Remaining checks owned by parent

- Review/adopt the proposal while retaining the parent's root old-source regression and all existing assertions.
- Compiler/formatter validation; source review is not Elixir parsing and cannot certify syntax or fixture execution.
- Independent actual-source constructor SPEC then CODE checkpoint, fresh pure nonzero tests, then real native test execution and repairs with unchanged assertions.
- Existing scoped compatibility suites, independent TCP/TLS peers, Chrome negotiated-H2 and H1 cases, consumers, final independent SPEC/CODE and fresh verification under the canonical plan.

Planned command (NOT RUN), assuming parent appends this distinct module to its existing startup test file:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_http/test/http2_worker_startup_test.exs
```

With the current one root test preserved plus these8, expected source-derived count is9. Real ExUnit counts, warnings/skips/exclusions, exits and source bindings must be recorded separately. All source-read/document-write commands are finished; no runtime or helper actor needs shutdown. No external permission or product decision is needed for this source preparation handoff.
