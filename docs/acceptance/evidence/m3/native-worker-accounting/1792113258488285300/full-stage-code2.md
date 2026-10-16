# Full-stage native worker CODE review2

**PASS — no actionable CODE findings.** The independent read-only full-stage CODE review is DONE for frozen candidate2 after full-stage SPEC2 PASS. This is a code-review verdict; Task7 final runtime gates and whole M3 completion remain OPEN.

Task `native_worker_full_code2`, direct independent assignment. Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, baseline HEAD `58307a7084298db309a93697b9102b2cc4c87eda`. Existing dirty/untracked task changes were preserved. Root owns execution, evidence integration and Git. Reviewer writes are limited to `/tmp/gaoxy-native-worker-full-code2.md` and `.json`.

## Frozen binding and final static verification

Candidate `full-stage-candidate2.json`: `5636329b6df387b33cf5277633210e81f261c1f6bb8a13ac2377ad410a3343ca`.

- All245 source entries, 3,892,900 bytes, match SHA256 and byte count. Canonical manifest digest `6e1e6d0808fa8f75c2be20b6e9940a30ec780a9459a7411172d951e3bcc8120e`.
- All430 evidence entries, 13,773,900 bytes, match SHA256 and byte count. Canonical manifest digest `6d0dfd17b2cc77a341d228d353261d0a62df147a05af525562ed0bc0ea63c029`.
- Canonical digests use Python `json.dumps(manifest, sort_keys=True)` with default separators, matching the freezer.
- `full-stage-spec2.md`: `05d8056aa6c027909535469bbaefd06c9b4ae7d1d15218073e87bbb9befded43`; `.json`: `2f88b7abcd3263be68e0675d21df2f1c0ff7fcd626c413b087380c5cd7169889`.
- Worktree `codex-prompt.md`: `87112f8eb621966e0062c8611054bda49af0508693c46fa621de87a2b774038c`; main-root `gaoxy-m1.1-fix-prompt.md`: `7982874aacafe8bc4f4814740f25d1bd1e5bb35cbdc3938338ab132f2cdf9f1f`.
- The final independent Python byte/hash/canonical-digest/protected-file/HEAD/branch assertions executed successfully, exit0. These bindings also matched before the substantive review. Additional root orchestration evidence outside the frozen manifest is identified separately below.

Static review used source reads, scoped diffs, `rg`, Python artifact/worksheet checks, Git status/identity reads and viewing existing H1/H2 PNG artifacts. Exploratory nonexistent-file/no-match probes were corrected and are not test failures. No build, test, formatter, runtime actor, browser session, network request or Git mutation was performed by this reviewer.

## Production lifecycle and authority

Reviewed complete changed Admission, WorkerBootstrap, HTTP2.Connection, Stream, WorkerAccounting, HTTP2.Transport and outer HTTP.Connection; traced relevant unchanged Generation, Exchange, Session, writer, lifecycle and service consumers.

`apps/gaoxy/lib/gaoxy/admission.ex:75` validates the live local original parent owner, unique token, scalar MFA, ready mode, original signed absolute deadline and existing active/byte limits. Numeric W+slot reservation precedes the public immediate atomic `:erlang.spawn_opt(..., [:link, :monitor])` at line110. The callback knows the child immediately, installs its complete ordinary lease and correlation, and commits state before the separate self-continuation. Activation at line486 rechecks owner, parent, child, mode and original D before privately permitting the child and replying.

`apps/gaoxy/lib/gaoxy/admission/worker_bootstrap.ex:5` retains the private activation reference, owner link and owner/Gate monitors; checks liveness/deadline and prepends the admitted lease to the scalar target arguments. Core imports no optional HTTP app. HTTP2.Connection authenticates the original public `:gen_server.check_response` at line1168 plus token/parent/D/local live child before constructing the full Exchange and initialized endpoint dispatch. `stream.ex:7` requires the complete dispatch identity; there is no second acquire/begin or replacement lease.

Admission EXIT/DOWN handling at lines525/552 retains the same current ordinary W+B until both genuine matching child monitor DOWN and linked EXIT arrive, in either order. Paired settlement subtracts current lease.bytes once. Parent DOWN first kills exact owner+parent correlated children before refunding the parent. Reverse child failure is isolated; Gatekill propagation uses the atomic link. The actual OTP parent EXIT interception and controlled stop are supported by qualified source and tests. Hostile callbacks changing lifecycle flags are outside the explicitly accepted profile.

The writer remains on its public Task-supervised path; no fake Task membership/$ancestors or Lifecycle.resources widening appears. The integration H2 fixture obtains worker identity explicitly from the endpoint's `{:owned, [self(), connection, gate]}` notification, so its Task enumeration does not misidentify the newly admitted worker.

## Constructor and retained-byte accounting

Reviewed the complete production calculator and complete constructor test, 95 actual role constructors and their independently instantiated archived ETF counterparts. Fresh static Python comparisons verified all12 reports and1,140 ordered role/metadata/subtotal entries, every whole equation and recorded iteration. The constructor tests instantiate complete terms rather than calling the same production sum twice.

There are88 startup and7 dispatch roles. P stays `2*max_header_bytes + 4*max_read_chunk + 65536`; `N=P+A+J`; `W=N+2*head`. Default public operands yield A11198/J5794/N213600/W213728; valid large initialized endpoint yields A11213/J399226/N607047/W607175. Signed D is measured independently. Complete original endpoint/request/certificate/metadata/default terms are included. Numeric preflight does not construct Exchange, full MFA or diagnostic role rows and introduces no configuration ceilings. The whole monotone fixed point has finite64-iteration refusal.

Future PID/ref caps E(node())+13/+27 are bound to selected OTP source. All four installed hashes in `pid-reference-premises-rebind1.json` matched. The actual `gen.erl` improper alias send_request/receive_response/check_response constructors and `gen_server.erl:2373` actual-parent EXIT handling were inspected. Existing constructor SPEC2 → CODE1 → fresh9 executed/32 explicitly excluded runtime/0 failures checkpoint precedes changed-W runtime. No constructor tests were run in this review.

88/90 production identities match constructor freeze2. The two differences are outer HTTP.Connection pre-admission metadata-close handling and HTTP2.Transport returned-trailer retention. Neither changes startup constructors, lifetimes, multiplicities or equations. Metadata-close handles closed/einval/enotconn using original context before admission and preserves other errors. Trailer handling charges the actual progressed body before successful return, propagates pending/final admission refusal and preserves the primary operation error. Session Exchange/B/lease custody and derived T8/cleanup are unchanged; constants9,444,956/16,478,862/5,963,776 remain. The allowance is serialized source-role accounting, not a total physical-memory proof.

## Behavioral and prior SPEC finding coverage

Reviewed the new core admitted-spawn and native worker startup/accounting tests, exact stale-start/proxy fixture changes and substantive fixtures/barriers. SPEC1 F1–F3 are resolved in source:

- Genuine original Gate success is held after activation but before native consumption; real Stream.run/7, empty mailbox and exact original lease are asserted. Real RST3 retains current5/queued7; the same authentic old success is replayed unchanged, complete current/queued rows and accepted/writer/parent identities remain equal, the real canceled child is killed and exact5/7 responses follow. Activated native owner normal/kill death joins worker/writer/Gate0. Core also consumes authentic public success before owner death while preserving a sibling.
- Genuine committed children and original continuations are held across real pause/drain calls queued first. Refusal, real child DOWN, no callback and exact refund are required. Original bootstrap D expires while the real continuation is held, before revalidation; no replacement deadline or activation occurs. Actual paired terminal ordering retains grown current W+B and refunds once.
- Three real Gaoxy.stop cases cover pending, dispatch-waiting and endpoint-blocked workers. They require same-callback public Gate status+state zero, completed drain telemetry, stop:ok, actual non-noproc original actor joins, original ports gone and exact listener address rebind. The strict pre-drain empty cut is retained; dispatch wait separately accepts exactly one authenticated post-drain message, then client RST. The blocked endpoint returns its original complete200 after drain. This qualifies cooperative shutdown without claiming uncooperative graceful completion.

The exact-preservation audit `/tmp/gaoxy-native-worker-original-tests-audit1.json` reconstructs original candidate1 core/native tests byte-for-byte; all90 production and409 original evidence identities remain candidate1→2. Additions were also reviewed semantically. Proxy probe_bytes1 is confined to constructor/no-dispatch coverage; default behavior and original assertions remain.

## Browser, collectors and consumers

Reviewed cohort3, host6, runner8, browser-command collector3, scoped collector4 and freezer4 sources plus archived qualification artifacts. Direct actual Chrome TLS/h2 and H1 require protocol/status, visible DOM/title/text and screenshot; both existing PNGs visibly display “Gaoxy checked Generation browser capture”. This was artifact viewing only.

The collector binds atomic public status to exact same-callback state via alias/OTP debug, all-ever acquisitions, native-start ancestry, writer-ready and per-PID trace-delivered barriers, authenticated terminal subtraction, complete lease/spawn/cleanup keysets and independent ordinary reservations. Exact95/W+B and real G7/T8 effect cuts, distinct native/Session holders, actual cleanup attachment and unmodified custody are required. Request/Session/worker cleanup precedes the strict live target connection/writer browser-close cut; final genuine native joins and global0 are mandatory.

Runner subreaping distinguishes adopted Chrome children from live Actor Popen waits. Actor exit0/nonforced/reader-joined/group-absent is required. Outer timeout/exit-race/detached-descendant cleanup and status recovery preserve FAIL for forcing, timeout or unjoined actors. Raw H1 peer requires exact HEAD/GET and complete responses, permitting reset only while idle after completion. Initial archived browser5 is2/2 PASS: six Actors0/nonforced, separately14 adopted waits (12exit0/two signal10), none remaining. BrowserGREEN1–4 remain FAIL; GREEN2 initiating cause remains UNKNOWN.

Core/HTTP external consumers use fresh copied projects and locked dependencies with explicit optional-app isolation and actual TCP/UDP/H1/H2 behavior. The process-only Git URL rewrite uses the fsck-qualified same locked commit/tree; it does not alter locks/global settings. Independent Python h2 TCP and TLS/ALPN require the pinned peer with no skip fallback. H3 cases qualify Admission compatibility only.

## Archived execution, final gates and counters

Archived receipts/log hashes, exits, joins, source stability and absence of shutdown_actions/unexpected warnings/skips/exclusions were checked statically. Initial cutoffs are core73/0, native100/0, HTTP preservation230/0, compatibility161/0, metadata-close13/0 (already within native100), isolated core consumer1/0 and HTTP consumer2/0. Initial compile and formatting record actual exit0 with no test claim. These are archived execution results, not newly executed or final-current acceptance.

Task7 remains OPEN: fresh affected union **expected561 tests/30 unique files, NOT RUN** (73+100+230+161−3 duplicated cases), strict compile/format, both real browser modes, both isolated consumers, final documentation and committed-blob custody, local conventional commit and next bounded preparation. Full SPEC2 and this CODE2 review are PASS; whole M3 remains incomplete. No publication or deployment is implied.

Candidate root53 stays immutable historical cutoff. New root orchestration artifact `root-verification-script-failure1.json`, outside the430 frozen evidence entries, preserves root54: `TypeError: string indices must be integers, not str` from treating protected scalar SHA strings as manifest rows. Corrected static assertions passed, with no source/runtime change. Current group failed GREEN41/stage failed GREEN11 remain; production repairs3/completed fixture repairs7/test-coverage repair1/diagnostic failures4/full-stage failed SPEC1 remain. Astra2/2 is exhausted; no third recovery. Reviewer adds0 runtime attempts,0 Sol repair rounds,0 Astra recoveries; astra_gate none. Cumulative broader Sol-round total was not supplied and is not reset.

All reviewer commands finished. No actor/runtime/trace/suspension or background command was started. Only the two assigned report files were written; repository task diff is unchanged. No decisions needed. Remaining risk is the explicitly open fresh verification/stage closure, plus the accepted serialized-allowance and cooperative-lifecycle scope limits above.
