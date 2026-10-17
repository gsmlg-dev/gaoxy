# Managed H2 positive response prefix — draft design1

Status: PREPARATION ONLY. No implementation, execution or acceptance. Execute only after the current group reload slice actually closes through its required gates, document review and local custody. Continuing authorization permits the next bounded slice; no new routine approval is needed. Root owns all repository/runtime/Git work. This proposal changes no product architecture.

## Goal and exact boundary

Prove that a successful managed-H2 response reaches the native downstream before upstream END_STREAM, then completes with exact bytes and ordered duplicate safe trailers. Add eight individually named cases:

| Mount | Downstream | Upstream |
|---|---|---|
| fixed | native H1 | h2c |
| fixed | native H1 | TLS H2 |
| fixed | native H2 | h2c |
| fixed | native H2 | TLS H2 |
| single-member group | native H1 | h2c |
| single-member group | native H1 | TLS H2 |
| single-member group | native H2 | h2c |
| single-member group | native H2 | TLS H2 |

This is positive response progress, not a complete Task6/full streaming matrix claim. Request preEOF, ordinary trailer semantics, early final and peer-reset sibling coverage already exist. Upstream-credit exhaustion, unsent-trailer cancellation, downstreamRST/live sibling, H1 upstreams, multi-owner, selected-A saturation, standalone, reload/load and H3 gates remain separate. No dependency proof equivalent to dismissed http_fetch#97 is introduced.

## Source evidence and minimal approach

The planned Task6 file `apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs` does not yet exist. Create it after stage entry; the assignment's description of it as existing was corrected by root.

The existing independent Python peer already provides the complete control barrier. `managed_h2_fixed_peer.py:425-473` accepts `respond` with `body64` and `ended:false`, then `data` with a suffix, duplicate trailers and `ended:true`. `respond:397-402` retains an unended response; `flush:404-423` writes only available body and emits final HEADERS/END_STREAM only when ended is true. The command acknowledgement is emitted after the actual flush. No peer, Python client, production or dependency modification is needed.

Use `F.fixture(upstream, downstream, ["--manual"])` or `G.fixture(...)`, followed by `F.hold/G.hold`. The group fixture completes its own genuine HEAD health request before the application GET. Reuse the actual request's connection/stream in both response commands; do not fabricate an upstream ID.

Recommended: add an optional body-progress callback to the existing test fixture `F.response`. Its default is nil and existing response/2, /3 and /4 behavior remains identical. Extend only the existing H1 chunk accumulator and H2 DATA accumulator. This keeps one accepted parser, preserves trailer/HPACK/control handling, runs in the same socket-reading test process and needs no new task/socket owner. Rejected alternatives are a second private wire parser (duplicated framing/HPACK logic) and a new Python client mode (unnecessary shared harness changes).

`F.response:360-371`, `h1_response:394-434`, `h1_chunks:436-447`, and `h2_response:483-539` are the exact seams. Carry a callback argument through existing recursion without changing any existing assertions, frame handling, sizes or timeout. Invoke only after a nonempty body fragment is actually received and appended. H1 chunk callbacks report ended:false because a positive chunk is nonterminal; H2 callbacks report the actual DATA END_STREAM bit. Do not call on empty DATA, avoiding duplicate callbacks for the same accumulated prefix. Existing unsupported/nonchunked observer paths need no generalized new behavior: these eight trailer-bearing cases deliberately exercise chunked H1 and H2 DATA.

## Deterministic transaction

Use prefix `<<0, "managed-h2-prefix", 255>>`, nonempty suffix `<<128, "|suffix", 0>>`, fields `content-type: application/octet-stream` and `trailer: x-check`, and terminal trailers `x-check:first`, `x-check:second` in that exact order. No Content-Length is set; H1 must use the existing chunked renderer. The payload is deliberately small and binary; it neither exhausts a window nor tests buffering limits.

1. Start the manual real peer and fixed/group fixture. Capture the original GET using hold, assert exact target/method and consume its matching upload_end with total_bytes0. Keep the authentic guardian and public RequestCompletion.
2. Before responding, capture actual T token ref/guardian/completion and, for group, actual G token ref and original selection. Confirm Session's supported existing test observations match the same original request/completion, selected public handle and request transport pins. Use only Gaoxy state already inspected by existing tests; never native Fetch processes or opaque completion internals.
3. Send `respond` with status200, the fields above, body=prefix and ended:false. Wait for its existing command ACK. Do not queue suffix/trailers anywhere yet.
4. Read through `F.response(..., progress)`. For each pre-prefix callback require accumulated bytes equal the corresponding prefix slice and actual ended:false. Fragmentation/chunk boundaries are unconstrained.
5. At exact prefix equality, assert actual `HTTP.RequestCompletion.await(original,0) == {:error,:cleanup_pending}`; assert the same authentic T token and original guardian/completion are still installed. For group also require the same G token/selection, inflight1 and unchanged supported exact-control/cleanup reserve checks. Verify original request pins remain held by that guardian. No full mutable-token-map equality or invented synthetic resource charge is needed.
6. Record a test-local observation tag only after those real reads/assertions. It is an observation, not a public completion receipt. Synchronously issue `data` on the exact same upstream connection/stream with only suffix, ordered trailers and ended:true, then require the existing ACK. This command cannot execute before the actual downstream prefix observation because it exists solely inside that callback.
7. Continue the same parser/HPAX state. Require status200, body exactly prefix<>suffix, ordered trailers exactly [{"x-check","first"},{"x-check","second"}], expected content-type and one actual prefix-observation tag. Any END_STREAM before prefix, premature full response, wrong bytes/trailer order or callback absence fails. No arbitrary sleep or no-event timing interval is used as phase proof.
8. After exact terminal response assertions, close the downstream socket, call existing F.clean/G.clean, require original public completion await(...,0) == :ok, then call F.close/G.close. This preserves the successful endpoint tests’ existing close/clean/completion order. Preserve existing cleanup/service/owner/group/pin/byte and physical termination/peer joined0/nonforced checks. The group gate's existing :killed reason and fixture-specific accepted monitor reasons remain unchanged; do not force all actors to :normal. Cleanup failure remains FAIL.

Use existing `F.response` 5000ms socket waits, ExUnit default timeout, fixture TLS preparation/peer lifetime and request/capacity budgets. No timeout override, enlarged limit, fresh phase window substituted for an original deadline, skip/filter, no-op callback success or early suffix release. A real buffering regression fails while the peer still withholds suffix/EOF.

## Evidence and production expectation

The production expectation is already the streaming contract: native H1/H2 forwards a body fragment before upstream END_STREAM, preserves bytes/trailers and retains the original request ownership until completion. No production change is planned or justified by this draft. A real failure requires preserved evidence and bounded diagnosis with unchanged assertions/counters; route a required listed-org dependency bug upstream and stop that blocked task, never patch deps.

Each case uses real sockets and the independent existing Python H2 server; TLS cases retain copied public trust and ALPN assertions. Eight actual tests, not source enumeration alone, establish the matrix. Keep source/helper/peer hashes, exact commands and actual counts/exits. Preserve source-attested ownership operations separately from emitted observation data. Public RequestCompletion is awaited directly and never serialized/traversed.

Before first runtime require independent draft SPEC then CODE, implementation self-review, exact source freeze and independent complete source SPEC then CODE. After first genuine qualification require full implementation SPEC then CODE and fresh relevant scoped/static/consumer/peer/browser gates, final factual document review and local conventional commit/custody. No artificial RED is required to qualify existing production behavior. Browser checks the current native/group boundary and does not substitute for the eight temporal tests. Final source/count maps must be recomputed for the new file; do not blindly carry the previous401 count.

No push/release/deployment, production data/certificates, Vault/public management/account changes or disabled release-artifact E2E activation follows. Astra2/2 remains exhausted; counters carry forward. This document is an implementation-ready draft, not current stage closure or next-stage execution authorization by itself.
