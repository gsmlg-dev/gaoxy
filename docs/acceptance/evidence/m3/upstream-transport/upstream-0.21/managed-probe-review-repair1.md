# Managed 0.21 probe repair1 independent review

Task: `m3_final_review`, Task3 frozen managed-probe repair1; direct independent
Sol specification and code-quality review. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, HEAD `4cc7a1a967d1b90a62d42db438316b10a03a1e16`.
Reviewed 2026-10-11 Asia/Shanghai. Fixture author is the separate public-client
worker; this reviewer authored neither fixture. Own only this new receipt;
original changes-requested report and other writers' edits are preserved.

## Verdict

**PASS for independent source specification and code-quality readiness of the
39-case repaired functional probe.** All five original actionable findings are
resolved in the frozen sources; no new actionable fixture finding was found.
Parent may execute this exact fixture under its serialized source freeze.
This verdict approves fixture readiness, **not complete Task3, H1/H2 numeric
accounting, Gaoxy integration or M3 acceptance**. Runtime is **NOT RUN** by this
reviewer; only final39-case marker, successful cleanup and process exit0 can
establish a runtime resource-property PASS. Canonical H2 capacity-error contract
remains a separately reported **MISMATCH**, never a canonical contract PASS.

## Original findings and repaired evidence

| Original finding | Frozen repair1 evidence | Disposition |
| --- | --- | --- |
| Unequal deadlines only exercised fast reuse | Probe470–515: actual5500ms held request plus700ms pre-header request; exact `{:error,:request_timeout}` in650–1700ms; original short completion confirms; peer observes H1 closure or H2 reset. Long original completion stays cleanup_pending, public snapshot remains one live request/connection; exact `abcdefgh` completes and further unequal-budget request reuses long cid. H1 uses another allowed connection; H2 multiplexes same cid. Original fast unequal-total/connect reuse case remains. | RESOLVED for actual total-deadline isolation; bounded connect-budget reuse remains functional reuse evidence, not a separate stalled-connect expiry test. |
| Complete-request lists missed partial rejected bytes | Peer74–165: every H1 recv increments raw byte count and tracks partial header progress; H2 observes HEADERS/CONTINUATION headers/payload before Python h2 decoding, counts incomplete payloads, exposes unidentified short prefixes. Listener must actually time out after draining accepts; each reader must time out after draining recv or confirm closure, all under one2s control deadline. Probe258–266 compares full counter maps; rejected policy, retired, request and connection capacity cases retain strict completed-request assertions. | RESOLVED; H2 non-request control ACKs excluded correctly. This is an observation barrier after operation completion, not proof against arbitrary future unrelated writes. |
| Request saturation lacked no-extra-accept | Probe341–365 pins before accepts1, equal raw counter/accept snapshots after rejection and retirement, final exactly1 peer accept and exactly the held request. | RESOLVED for H1/TLS H2/h2c. |
| Shared-fragment replacement lacked identity/public release | Probe725–788 pins offender+sibling to failed cid and independent request to distinct cid; original cleanup_unconfirmed stays explicit. Public requests/preparing/connections/resources must all be zero before replacement; replacement cid3 differs from both prior cids. Final accept3, exact path/cid mapping, header-frame count4, continuation count0 and no partial prefix confirm no extra request/replay. | RESOLVED. Peer closure alone is no longer the release barrier. |
| GOAWAY PING overstated pool synchronization | Peer268–269 and README describe ACK as owner-side GOAWAY wire processing only. Probe581–654 separately asserts actual admission error, no bytes/accept increase, occupied scope snapshot, independent progress and replacement only after public zero counts. | RESOLVED; asynchronous pool-cast consumption is not inferred from PING ACK. |

Additional requested isolation is present (Probe393–426): scopeB has an active
held response on a distinct connection before scopeA force retirement. After A
receipt+completion+peer closure, B remains `lifecycle: :open` with one active
request/connection and pending original completion; B finishes exact body,
confirms completion and retires independently. This strengthens the prior
idle-B isolation case without replacing it.

## Task3 specification coverage

| Requirement | Review evidence / limit |
| --- | --- |
| Supported public resource API and no fallback | Scope/options passed through public ManagedTransport and HTTP.fetch; opaque values never destructured or sent to private owners/pools. Same-origin scopes pin distinct cids; conflicting route/retired admission fails with no raw request bytes or accepts. |
| Finite active/idle/connecting/request/pending behavior | C/R/P configured finite; held R1 rejection and H1 C1/R2 rejection are separate. H2 GOAWAY occupies C1 while R capacity remains; zero pending asserted. Fast reuse distinguishes idle generation resource lifetime from completed request. This is sampled functional capacity evidence, not exhaustive accounting of every connection state. |
| Deadline isolation with reuse | Three new actual total-expiry cases plus three original unequal total/connect-budget reuse cases. Exact short result and elapsed window prevent treating completion-pending as deadline exercise. Long request survival/body/further reuse pins isolation. |
| Retirement, late checkin, creator death | Graceful pending receipt and late rejected admission; held response completion then socket closure; abort during stall preserves live B; creator normal DOWN escalates a previously pending graceful receipt; repeated and concurrent terminal receipt waits are checked. |
| Fragment cap and connection-wide failure | Both256-frame empty/bounded-body successes remain; four257th variants empty/nonempty x final/nonfinal remain. Exact header_block_too_fragmented errors and peer connection closure required; same-owner sibling gets exact failure, independent scope progresses. |
| Public cleanup and conservative uncertainty | Every original completion captured before Promise.await. Fragment completions must first return exact cleanup_unconfirmed before registry expectations change; separate generation retirement must confirm. No uncertainty is rewritten to ok. |
| Source numeric retained bound / slow-control/soak / integration | NOT QUALIFIED by this functional fixture; accounting reports and the complete plan retain their own outstanding gates. |

Static case count: `3*(6 common+1 deadline)+2 H1 extras+
2*(1 GOAWAY+2 positive fragments+4 negative fragments+1 shared failure)=39`.
All original36 categories remain, including the fast unequal-budget reuse cases;
new assertions strengthen capacity/isolation/identity checks. Existing H1 POST
failure accepts an error variant but still demands exact POST body, one accept
and no replay; that pre-existing assertion was not widened. All fragment and
capacity/deadline error matches remain strict.

## Code quality, barriers and finite shutdown

Raw H2 observation is a small incremental parser independent of Python h2's
complete-event decoding. It accounts a request frame's9-byte header once,
counts received payload before completion, preserves incomplete payload state,
and reports shorter unclassified prefixes. H1 byte counters include request
bodies; clearing completed header-progress does not clear total bytes. Counter
comparison therefore catches partial rejected request traffic, while H2 ACK
traffic does not create false request counts.

Barriers use reader/listener observations rather than a caller sleep. Socket
readers have0.1s recv timeouts; listener has0.1s accept timeout. Snapshot sends
waiters, waits once under an absolute2s deadline and then reads counters under
locks; state-lock holders record events through the separate peer lock, while
snapshot releases that peer lock before taking any state lock. No reverse
nested locking or barrier wait while holding the relevant lock was found.
EOF/serve-finally releases reader waiters. A stalled TLS handshake cannot
silently pass the drain barrier: it produces a bounded barrier failure instead.

Peer control lifetime is45s after readiness, control lines65536, socket/body
inputs are bounded in the prepared cases, and TLS setup commands have10s
limits. Original Promise, stream, completion, snapshot and retirement waits are
finite. Polling for public zero state uses an absolute3s deadline; held-request
snapshot polling uses2s. Two terminal receipt waiters and completion helper
processes are monitored and require normal DOWN. Creator is monitored and
requires normal DOWN. No fixture helper survives a successful case.

Cleanup runs in `after`, captures each scope abort/retirement and every original
completion abort-and-await separately, then attempts peer stop even if previous
captures failed. It requires every scope result ok, each completion's registered
exact expected result (ok or already confirmed cleanup_unconfirmed), stopped
receipt live_threads0, and subprocess exit0. Historical Peer.stop joins its
acceptor and every reader with finite2s joins and asserts none remain alive;
temporary TLS files are then removed. Parent execution must retain all39
case receipts **and39 cleanup receipts** plus final marker and exit0; an early
case receipt does not imply that enclosing cleanup succeeded.

Canonical mismatch reporting remains precise: GOAWAY capacity log records
canonical tuple, exact source-expected pending_capacity and actual result;
strict assertion requires the source result while case/final receipts label
canonical contract MISMATCH. Root owns runtime verification and upstream
routing. No upstream actions or dependency patches were performed here.

## Fresh checks and source identity

Reviewer ran Python AST parsing of managed/historical peers without importing
or executing them, exact frozen SHA-256 comparison, static39-case arithmetic,
required-assertion checks, and report whitespace/source-hash stability checks.
All completed with exit0. No Mix, Elixir fixture, network, port, application,
private process inspection, commit or upstream mutation ran. Parent preflight
format/compile and18/0 focused adapter results are parent-supplied evidence,
not rerun or inferred into managed runtime acceptance here.

Task report: DONE for this direct independent review. Reviewer Sol repair
rounds0; fixture source repair1 is author-owned, runtime repair counter0;
received Astra recovery counter0. All reviewer commands finished; no reviewer
runtime session/process was started or remains. No design or user decision
is needed to execute the frozen functional fixture. Remaining limitations are
the separately recorded accounting/soak/integration gates and canonical error
contract mismatch.

| Reviewed input | SHA-256 |
| --- | --- |
| `integration/http_fetch_contract/managed_peer.py` | `319e9c9f2832ddf2ab9cc84aedd519bfe33f36e2152d24bb47bf5fcde8169d79` |
| `integration/http_fetch_contract/managed_transport_probe.exs` | `ce9c9c23417e9acb2062846c27fe3a98788f7f2f8e1a846970badd63620e1ab7` |
| `integration/http_fetch_contract/MANAGED_README.md` | `8ded25f14c7bfa3c4939817b82fa9134a8fb016bc6d656358803a1c5c0630b44` |
| `integration/http_fetch_contract/pooled_completion_probe.exs` | `f681723ff58754cb6169d0b42fb681a8439eeaa6c7ec7e94c752894405ce1e30` |
| `integration/http_fetch_contract/upstream_peer.py` | `f2e40b0e72362f06b4c933b14f45d49e768b2133bee4281c4241bbd122d9b95f` |
| `docs/plans/m3-upstream-transport.md` | `a072dcb4815882e46cfb8931f088621448067300ed12685d9b13f16da95c6da8` |
| `docs/designs/m3-upstream-transport.md` | `b71dd745310141eaa52fd7d276e327dd6b6bc1a1b51b7aa44d5f876946767dd4` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/managed-probe-review.md` | `946a4c325c5d59c65d3bc590624f9542302684d4a45b6902847dc893272367fc` |
