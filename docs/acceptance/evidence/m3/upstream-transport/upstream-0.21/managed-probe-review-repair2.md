# Managed 0.21 fixture repair2 independent delta review

Task: `m3_managed_contract_review`, direct independent Sol delta review, reviewed
2026-10-11 Asia/Shanghai. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline/HEAD
`4cc7a1a967d1b90a62d42db438316b10a03a1e16`. Root authored this repair; this
reviewer authored neither executable fixture. Own only this new report and
preserve prior reviews and every other writer's edits.

## Specification verdict

**PASS for repair2 fixture and documentation readiness.** The local positive-fragment
dispatch corrects a fixture mismatch with the public response-body contract.
It retains exact status/body checks and exact request completion. **Repair2
runtime NOT RUN by this reviewer.** No full39-case runtime, Task3, retained-byte,
Gaoxy integration/activation or M3 acceptance PASS follows.

Prior `managed-probe-review-contract1.md` remains historical source-readiness
evidence; its runtime-NOT-RUN wording is not overwritten. Root's subsequent
`managed-probes-contract1.json` records FAIL:24 case receipts,25 successful
cleanup receipts,425 frozen hashes unchanged, exit1, no final marker, no owned
peer left. The log confirms every abnormal-retirement and actual-deadline case
passed. Its new failure632–659 is the first TLS H2 positive256 empty-response
case: `:erlang.send("", {:read_chunk, ...})` raises `invalid destination` in
unchanged historical `HTTPFetchPublicProbe.consume/3:180`. Before cleanup,
the original request completion was already exactly ok, with no active or
preparing request; cleanup confirmed its exact-ok result, generation retirement
and joined peer shutdown. This is fixture dispatch failure, not a demonstrated
upstream empty-response defect.

The unchanged peer's positive empty variant (managed_peer280–286) sends
HEADERS END_STREAM followed by continuations totaling256 frames and final
END_HEADERS. Installed SocketClient1086–1121 constructs the final response and
handles END_STREAM through `Response.with_buffered_body(response, "")` before
the streamed-response branch1123 onward. Public Response documentation17
permits binary body or stream PID. The old local `Peer.response/3` invocation
assumed a PID for both variants; historical helper174–181 unconditionally
passes its body to `send/2`.

New Probe809–815 follows those two concrete cases: the bounded-body variant
requires Response status200 and a PID before acknowledged exact `bounded`
consumption; the empty variant requires Response status200 and exact binary
`""`. Wrong status, nonempty binary, error result and unexpected body form
still fail. Probe816–820 retains exact-ok original completion, confirmed
generation retirement, observed peer closure and exact single request before
the case receipt. Original public completion was still captured before await.
This correction neither changes wire injection nor broadens fragment limits.

Fresh SHA-256 reconstruction proves the entire functional delta is exactly
one replacement: removing the two new issue89 comments and replacing the new
seven-line local if-body dispatch with the
old `Peer.response(promise, if(body, do: "bounded", else: ""))` reproduces the
contract1 probe hash `108ffd70741a02e66fa18a8cb3e80dd18c7fd67b175c0eee0a853bf67b5472b1`.
Thus every previously reviewed deadline, abnormal-result restriction,
concurrent/repeated wait, exact cleanup expectation, negative raw-wire barrier,
no-extra-accept, policy/capacity rejection, fragment257 variant, connection-wide
failure, public zero-ledger replacement and no-replay assertion is byte-identical
outside this dispatch. The two comments721–722 reference the needed upstream
error-shape issue and preserve explicit canonical MISMATCH; they change no
assertion. All39 cases remain; runner935–938 requires exact39 and
the resource-property final marker.

TLS GOAWAY canonical error **MISMATCH is now runtime-confirmed** by contract1
log594–627: actual/source `{:error, :pending_capacity}` versus documented
`{:error, {:transport_scope_capacity, :connections}}`. The finite functional
case passed and preserves its separate mismatch label. h2c GOAWAY capacity was
not reached by that failed run; it remains NOT RUN in that evidence. Root reports
creating and verifying [upstream Bug89](https://github.com/gsmlg-dev/http_fetch/issues/89)
with internal request/open/needed status. This reviewer inspected the two probe
TODO/WORKAROUND comments and adapter TODO61, but performed no network issue
verification or routing. No canonical compliance is inferred here.

## Separate code-quality verdict and reporting limits

**PASS for executable delta quality.** A local branch is the smallest correction
and leaves read-only historical helpers intact. It adds no general response
abstraction, private dependency API, new dependency, replay or process. The
streamed branch checks the PID before invoking the existing acknowledged body
helper. Both paths converge on unchanged strict completion/retirement/cleanup.
No new actionable executable finding was found.

One documentation consistency finding was sent to root: README180–181 retained
the old claim that the actual repair had not run and unsuccessful repair count
was0, contradicting its new top-level repair1 FAIL/count1 evidence. **RESOLVED**
in final README180–183: abnormal repair1 cases passed, the full run failed on
the empty-response helper, repair2 is pending and cumulative unsuccessful runs1,
Astra0. README20's source function name is now correctly `with_buffered_body`.
These reporting corrections preserve failed receipts. No actionable finding
remains in the final frozen input.

Finite-operation and shutdown limitations from contract1 review remain: waits
are bounded individually, not by one global fixture deadline; a failed helper
assertion can precede its join; failed peer stop does not independently force-kill
the subprocess. Root must use bounded serialized execution, final owned-process
verification and unchanged before/after frozen hashes. Runtime success requires
all39 case receipts **and39 successful cleanup receipts**, final marker, joined
peer shutdown and overall exit0. An earlier case receipt is insufficient.
Retained-byte accounting, slow/control/soak and Gaoxy integration remain separate
unqualified gates.

## Fresh checks and handoff

Python standard-library checks exited0: exact final probe/README and peer SHA-256;
reverse dispatch/comment reconstruction of contract1 hash; unchanged historical completion
helper hash; installed SocketClient/Response/helper/peer hashes matched to
contract1's frozen map; FAIL24/cleanup25/425-stable/no-peer receipt assertions.
No Mix, fixture/application, network, source/dependency/lock mutation, commit or
upstream action ran. Report whitespace and final hash stability are checked
before handoff. This reviewer changed only this new report.

Reviewer Sol repair rounds0. Received initial FAIL1, diagnostic FAIL1, actual
repair1 unsuccessful full runtime1; repair2 prepared/pending, Astra recovery0.
Task status **DONE for independent readiness review**. No escalation gate or
design/user decision is needed for the executable delta.
All reviewer commands finished; no runtime session/process was started or
remains. Root owns renewed freeze/preflight, upstream routing and the full
repair2 runtime result/counter update.

| Reviewed input | SHA-256 |
| --- | --- |
| `integration/http_fetch_contract/managed_transport_probe.exs` | `f6a6f92a06fa84a95f83574e531256e5623f26236528f0a27922f5aa200b65c7` |
| `integration/http_fetch_contract/MANAGED_README.md` | `8ead3963a5172186f2e36885bd611cbe16f4c46b57bd821517da05dcb147fef9` |
| `integration/http_fetch_contract/managed_peer.py` | `319e9c9f2832ddf2ab9cc84aedd519bfe33f36e2152d24bb47bf5fcde8169d79` |
| `integration/http_fetch_contract/pooled_completion_probe.exs` | `f681723ff58754cb6169d0b42fb681a8439eeaa6c7ec7e94c752894405ce1e30` |
