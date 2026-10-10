# Managed 0.21 contract repair1 independent review

Task: `m3_managed_contract_review`; direct independent Sol review. Reviewed
2026-10-11 Asia/Shanghai in
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline/HEAD
`4cc7a1a967d1b90a62d42db438316b10a03a1e16`. The reviewer authored neither
fixture and owns only this new report. Existing tracked/untracked changes and
prior review/failure evidence are preserved.

## Verdict

**Specification review PASS, followed separately by code-quality review PASS
for readiness of this exact 39-case functional fixture.** No actionable blocker
was found in the actual managed public test-contract repair. The abnormal H2
completion correction follows the published contract and preserves both exact
request evidence and independent generation cleanup proof.

**Runtime NOT RUN by this reviewer.** This approves root's renewed source
freeze, preflight and serialized full functional execution under existing
authorization. It does not establish functional runtime PASS, complete Task3,
H1/H2 retained-byte qualification, Gaoxy activation/integration or M3 acceptance.
Canonical H2 capacity error compliance remains separately **MISMATCH**.

## Specification review and failure attribution

Reviewed the prior `managed-probe-review-repair1.md`, current plan Task3,
design's separate request/generation barriers, containing-tag documentation and
provenance, initial and diagnostic1 receipts/logs, new probe/README/peer, and
installed public facade, scope, SocketClient and request lifecycle paths.

Containing tag `9813c126dc8b48055b9ee941c693fc27fa691489` documentation
`.audit/m3-transport/upstream-managed-transports-0.21.md:120–126` requires all
monitored generation resources and coordinator termination for retirement
`:ok`; lines135–138 explicitly allow conservative individual request evidence
after abnormal termination. The immutable document provenance records Git blob
`59da32e061f86b4cbac081dccfeaeadebe2f5267`; its SHA-256 was freshly checked.
Parent's full196 installed/archive and175 runtime-tag-file provenance PASS is
existing evidence, not a newly rerun network provenance claim. The four critical
installed facade/policy/scope/frame-owner hashes were freshly matched here.

Initial and diagnostic1 each exited1 after11 case receipts and12 cleanup
receipts, with425 frozen hashes unchanged and no final39 marker. Diagnostic1
log299–325 preserves the primary A completion failure before cleanup:
`{:error, :cleanup_unconfirmed}` at historical `Peer.complete/1`'s exact-ok
assertion. Before cleanup, B's public state is open, active_requests1,
preparing_requests0, connections1, resources4, pending0 and its original
completion is cleanup_pending. Cleanup subsequently aborts both remembered
scopes and obtains two unconfirmed outcomes (log327–339). B's later forced
cleanup result cannot be attributed to A's retirement; neither run demonstrates
an isolation defect. The initial run masked the primary exception; diagnostic1
keeps primary and cleanup failures distinct.

Installed Scope188–200 sends ingress cancellation and immediately closes tracked
resources; Scope330–338 sends the lifecycle abort, while383 exits the shared H2
connection owner with shutdown. SocketClient1304–1317 attempts shared-owner
stream and pool reservation release;1345–1348 records uncertainty when release
confirmation exits. RequestLifecycle237/262–291 preserves uncertainty in its
terminal latch; public RequestCompletion102–129 returns it distinctly. Owner
shutdown and request-side release confirmation run in independently scheduled
processes. A later generation receipt or peer closure cannot reconstruct which
won. Requiring exact unconfirmed is therefore also stronger than the documented
race permits; allowing exactly ok or unconfirmed is justified for these two
abnormal H2 paths.

| Contract property | Current source evidence |
| --- | --- |
| Narrow corrected result set | Probe233–280: H1 only exact ok; verified TLS H2/h2c exactly ok or cleanup_unconfirmed. Helper has only two callsites,520/579, for scope abort and creator death. Pending, unsupported completion and arbitrary errors still fail. |
| Original request evidence preserved | Probe250–280 logs exact observed result, requires concurrent waiter equality and normal DOWN, repeats zero-wait equality, then saves that exact outcome for the original completion. Case receipts535–538/582–585 retain request outcome separately from generation_retirement ok. No result is converted to ok. |
| Generation proof stays strict | Abort503–505 and creator576–578 require retirement ok, peer closure and retired snapshot before observing request completion. `retire/2` helper306–309 still requires exact public await_retired ok. Repeated/concurrent receipt checks remain strict312–337. Retired snapshot alone is never substituted for the receipt. |
| Live B survives A | Abort498–519 establishes distinct B connection and, after A's confirmed retirement but before A completion observation, B pending plus public open/live request, one connection and positive resources. After A completion and repeated receipt waits,522 pins B pending again;523–527 then requires exact abcdefgh body, exact-ok request completion, independent retirement and closure. The exact body proves continuing progress; no second public snapshot is claimed after A completion. |
| Cleanup still checks exact evidence | Probe113–124 records expected versus observed abort_and_await and pins equality before accepting a registered terminal result. Aggregate membership148 does not replace that exact check. Every scope result still must be ok147; peer stopped/live_threads0 and subprocess exit0 are mandatory127–149. |
| Normal/graceful/deadline stay exact | Ordinary drain283–287, graceful483 and deadline602/615 still use historical exact-ok `Peer.complete/1`. Deadline599–601 still requires exact request_timeout in650–1700ms; held longer request/body/reuse and connection identities remain608–627. |
| Fragment loss stays exact | `unconfirmed/2`221–230 requires exact cleanup_unconfirmed; four257th variants831–841 and shared loss868–905 retain exact failure, sibling error, independent body/completion, public zero ledger before replacement, distinct replacement cid3, accept3, header-frame4/no continuation/partial-prefix and exact no-replay request list. |
| Negative wire and capacity checks stay strict | Raw map equality363–365 retains accepts and partial-byte observations; retired/policy409–438, request saturation441–465 and H1 connection saturation652–674 retain no-extra-accept and exact request lists. GOAWAY733 requires exact source pending_capacity and719–731/769–772 report canonical mismatch separately. |

Case arithmetic remains `3*(6 common+1 deadline)+2 H1 extras+
2*(1 GOAWAY+2 positive fragments+4 negative fragments+1 shared failure)=39`.
Runner927–930 requires exact39 and labels the final resource-property marker
with canonical H2 capacity MISMATCH. No case was removed or skipped. The
pre-existing H1 POST error wildcard680 was not widened; exact POST body, single
accept and no replay remain687–688.

## Separate code-quality review

No new actionable code-quality finding. The small forced-completion helper
matches historical completion-helper conventions while making its narrow
protocol/result policy explicit. PID-pinned concurrent messages, monitored
normal DOWN and exact repeated result prevent different terminal evidence from
silently passing. Cleanup registration changes only after those checks succeed.
The retained primary/pre-cleanup diagnostics are read-only public observations;
primary exceptions retain their kind/reason/stacktrace even when cleanup fails
(Probe32–91). No opaque scope/receipt destructuring, private process inspection,
dependency patch, replay or global transport fallback was introduced.

Finite waits remain: scope open/retire fixed5s public calls, snapshot100ms,
generation retirement3s, completion2s, waiter/peer event6s, public ledger polling
under absolute2/3s deadlines. Completion waiters terminate normally on successful
paths and cannot block indefinitely inside await. Peer raw observation uses an
absolute2s listener/reader drain barrier (managed_peer131–165); listener/reader
socket timeouts are0.1s after TLS handshake. EOF/finally releases reader waiters.
Peer control lifetime is45s after preparation, TLS setup subprocesses have10s
limits, and TLS handshake has5s. Historical peer stop309–324 closes sockets,
joins acceptor/readers with2s per-thread limits, requires no live thread and
removes temporary TLS files before its stopped receipt. Locks are released
before barrier waits; no reverse nested state/peer lock order was found.

These are finite operation waits and a cooperative peer lifetime, not a single
fixture-wide deadline or proof of forced shutdown after arbitrary runtime
failure. An assertion can interrupt helper joining; its finite await still
expires. Peer stop failure is recorded and fails the case, but the Elixir cleanup
does not independently force-close a failed Python subprocess. Root's bounded
execution wrapper and post-run owned-process check remain necessary. A case
receipt precedes its enclosing cleanup and is insufficient for runtime success:
require all39 case receipts,39 successful cleanup receipts, final marker,
subprocess/process shutdown and overall exit0 with source hashes unchanged.
Fresh byte accounting, slow-control/soak and Gaoxy integration remain separate
unqualified gates. Neither retirement nor completion proves remote application
receipt of bytes.

## Fresh verification and handoff

Reviewer commands completed with exit0: Python standard-library SHA-256 identity
checks for the three assigned frozen inputs and containing-tag documentation;
`ast.parse` of managed and historical Python peers without import/execution;
static39-case arithmetic and retained assertion checks; two-callsite restriction
for forced completion; four critical installed-source hash comparisons; report
whitespace and final source-hash stability checks. No Mix, application/fixture,
network, dependency/lock mutation, commit or upstream action was run.

Task status **DONE for independent readiness review**. Task diff consists only
of this new report. Reviewer Sol repair rounds0; received unsuccessful actual
fixture repair rounds0, initial runtime FAIL1, diagnostic FAIL1, Astra recovery0.
No escalation gate or design/user decision is needed. All reviewer commands
finished; no reviewer runtime process/session was started or remains. Root owns
renewed freeze/preflight/full runtime and its actual result/counter updates.

| Reviewed frozen input | SHA-256 |
| --- | --- |
| `integration/http_fetch_contract/managed_transport_probe.exs` | `108ffd70741a02e66fa18a8cb3e80dd18c7fd67b175c0eee0a853bf67b5472b1` |
| `integration/http_fetch_contract/MANAGED_README.md` | `e72fad78bc96a61a4d594d3cd6c8de7eac12748838543fa9abe9a2ff3eaf5ef1` |
| `integration/http_fetch_contract/managed_peer.py` | `319e9c9f2832ddf2ab9cc84aedd519bfe33f36e2152d24bb47bf5fcde8169d79` |
| `.audit/m3-transport/upstream-managed-transports-0.21.md` | `e25aba6fccf5bd9bd86fba810a7c7e818d15ab9401533643cedfe7173e63242e` |
