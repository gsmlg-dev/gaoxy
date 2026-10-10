# Independent turnover, TLS evidence and local delivery review

Date: 2026-10-11 Asia/Shanghai. Task: `m3_h1_new_evidence_review/turnover-delivery`.
Assignment: direct independent Sol review; source/specification first, followed
by documentation/code-quality review. Status: **DONE**.

**Source/specification PASS** for the bounded conditional control-turnover
investigation, source-confirmed TLS tracking mismatch and accurately scoped
diagnostic/issue evidence. **Documentation/code-quality PASS** for the exact
parent documentation and comment-only adapter snapshot below. There are no
actionable findings within these scopes. These verdicts do not qualify managed
transport activation or complete P5.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`; baseline/observed HEAD
`dcf2449c237914f94c041bddfcfb0a0a6e58c12f`. This reviewer owns only this report.
Other writers' files and processes are preserved. The concurrent
`h1-request-wire-proof.md/.json` assignment is entirely excluded. Prior independent
source/implementation/functional reviews are trusted within their recorded
scope. The reviewer's own earlier String report was **not self-reviewed**;
only its stored hash and the parent's reference/status were checked.

## Source/specification assessment

The turnover report distinguishes component emission counts from arbitrary
history ceilings. Its potential `outstanding = emitted - consumed_or_flushed`
preserves queued/in-flight/native control objects and uncertain/rejected
attempts. `G`, public retry producers, native cancellation windows and mailbox
snapshot overlap remain unqualified; a finite R ledger, synchronous call or
timer duration is not substituted for a release barrier.

Direct inspection of fixed H1 source paths supports the conditional ceilings:
six base registered roles, two PID-upload roles and at most one controlled
producer give κ≤9, excluding the blocked independent TLS registrations.
Tracker calls are bounded by κ+8≤17; pool calls by three per attempt. Internal
abort sources are bounded by 8 under the specified controlled producer premise.
Cancellation invocations κ*(8+a+6)+2 give128 at κ9/a0, including repeated fanout,
incomplete-role DOWN, scope DOWN and late registration/stream-ready paths.
Controlled retirement seeds are two calls plus creator DOWN and three child
DOWN, giving six settle/close-idle emissions. Resource-close invocations are
at most two per registration occurrence. These are conditional per-attempt or
controlled-seed ceilings, not complete mailbox or scope-byte budgets.

Connection slot pruning checks done, nil socket, empty dials and absence of
associated registered resource metadata. Request tracker DOWN frees ingress
without thereby consuming every old scope resource DOWN. Deduplicated scope
resource registrations and separate monitor occurrences are distinguished.
ACK progress does not imply a body-length emission ceiling. Pool checkout's
recursive discard path can construct at most C mailbox snapshots, but snapshot
payload/cardinality and simultaneous roots remain open.

The OTP timer and monitor distinctions are accurate. Native timer timeout
changes ACTIVE to TIMED_OUT before enqueue, so cancellation can return false
before arrival/consumption. Default timer cancellation does not flush an emitted
expiry. Demonitor prevents future matching DOWN queue placement and [:flush]
removes an already queued match; deferred target-side native metadata remains
separate. The generic gen_server receive does not selectively skip already
queued old expiries, but this is not a bound on pre-enqueue/native races or
queued timed-out calls during a blocked callback. The report supplies no
unsupported native-retention counterexample or scheduler-fairness quota.

## TLS mismatch and upstream routing

Installed `HTTP.RequestLifecycle.track_tls/2` matches only the three-element
`{:sslsocket, _, processes}` tuple with a list; its fallback returns :ok.
Pinned OTP `ssl_api.hrl` has seven record fields, and `tls_socket:socket/6`
constructs the eight-element returned tuple with distinct receiver and sender.
The source chain from transport connect through track_independent/track_scope
therefore skips these independent TLS resources in the installed cohort.

Scope resource and slot barriers cover registered resources. `ssl_gen_statem`
does invoke transport termination before returning stop_and_reply, but this
does **not** establish both independent worker DOWN barriers: gen_statem emits
the reply before final process termination; receiver and sender are separate
supervised workers, and sender shutdown follows supervision. Raw cancellation
closes TCP independently. No measured leak, arbitrary-repeat growth, executed
false retirement success or whole-resource termination claim follows from this
source mismatch or a successful public close.

The initial diagnostic retains exit0 and confirmed shape while explicitly
recording **PARTIAL_SHAPE_CONFIRMED_PEER_ALPN_FAILURE** and failed complete peer
protocol. Its log alone cannot supply peer success. Repair1 adds explicit h2
ALPN, confirms public negotiated h2/TLS1.3 and the legacy predicate's false
result, closes publicly, joins the peer and records zero live peer threads.
This is a public socket-shape diagnostic, not H1/H2 lifecycle qualification.
Identical log bytes across the runs are consistent with their recorded program
and the different peer outcomes captured in JSON; they are not silently
treated as two fully successful peer runs.

Bug95's REST receipt and local request agree on exact body, requesting
`gsmlg-opt/gaoxy`/`codex/m3-gateway`, typed Bug, `internal request`, blocker
severity, minimal executed reproduction and required deterministic lifecycle
regressions. The required adapter TODO links95. No workaround, private tracking,
quota, dependency patch or weaker termination obligation was introduced.
**TLS BLOCKED_UPSTREAM95; full P5 NOT ESTABLISHED.** Resume the TLS-dependent
qualification only after containing artifacts are published, installed and
requalified with the required independent release barriers.

The refreshed remote receipt records86–89 CLOSED,95 OPEN and latest published
release/installed cohort0.21.0. The original open-state receipt and the refresh
collector's schema failure remain historical. Issue closure is correctly
distinguished from containing-artifact or runtime acceptance.

## Documentation and code-quality assessment

The reviewed pure Task5 and Task3a completion refers only to local commit
`56fd518`, canonical formatting, two independent implementation reviews and
the fresh26/0 final run of their exact four code/test hashes. This review checked
those files against both reviews, the429-entry final maps and committed blobs;
no current source or frozen test evidence was silently replaced.

The managed receipt/log retain39 cases,39 joined cleanup records,425 equal
before/after source identities, focused preflight18/0 and finite functional
scope. Both verified TLS H2/h2c canonical capacity errors remain **MISMATCH**;
the evidence does not call successful resource-property checks canonical
contract conformance. Earlier runtime, fixture dispatch and formatter failures
remain separate, with two unsuccessful Sol repair validations and bounded
Astra recovery1/2. Nothing in Bug95 reclassifies those finite observations as
proof of termination for skipped TLS resources.

The Task3 checklist retains a distinct unchecked actual OTP28 TLS-process
tracking/release requirement. Held preparing/connecting saturation remains
NOT RUN and separately unchecked before activation. Complete P0–P6 accounting,
managed integration, network/version matrix, adversarial controls and both
≥600-second managed load profiles remain required. Conditional proof PASS,
pure preparation completion and local commits do not mark M3 complete or
authorize M4 progression. Vault, publication/deployment, production and
release-artifact E2E restrictions remain intact.

The adapter delta contains comments only: every noncomment line equals HEAD.
Explicit dedicated HTTP/1, reuse false and original options remain unchanged.
The sole new whitespace attribute beyond the pre-existing vendor patch applies
to the exact historical failed runtime collector log; it preserves raw evidence
bytes rather than suppressing authored-source checks. Historical review/worksheet
receipts remain dated snapshots with separate current supplements.

## Independent checks and shutdown

Fresh read-only Python checks passed:

- All47 turnover input identities and its worksheet hash match; κ/call/fanout/
  retirement arithmetic recomputes exactly.
- All three diagnostic/format before/after pairs have429 identical entries.
  Between final shape and post-comment maps, exactly one entry changes: the
  adapter comment delta. Its historical/current hashes match the delta receipt.
- Both shape logs match their recorded hashes. Repair1's peer events contain
  h2 negotiation, joined peer and zero remaining threads; initial failure is
  retained. Global post-comment format receipt records exit0 and stable429 maps.
- Issue86/87/88 wrapper body digests and local request text match;95's raw REST
  body matches its local request and refreshed body digest. Type, label, severity,
  observed states and release/cohort fields agree.
- Pure final429 maps agree, four source/test identities agree with reviews and
  commit56fd518, and the log records26 tests/0 failures at seed21108026.
- Managed final425 maps agree; its log has39 MANAGED_CASE,39 MANAGED_CLEANUP,
  two capacity-contract records and the final finite PASS marker.
- All scoped JSON parses;133 relative Markdown links resolve. `git diff --check`
  exits0. Only historical snapshots are expected to differ from later authored
  documentation/comment status; current reviewed identities are pinned below.
- Stored String-review SHA256 remains
  `be5377598260cdd1f6db3f1ac2d57e6485dca6d533bdfd21dfcf4e83209a1346`.

No VM, Mix, formatter execution, network, upstream mutation, commit, staging or
process-control command was run. The review recorded parent-run checks rather
than claiming to rerun them. One initial read attempted the historical worksheet
under an extra `upstream-0.21` directory and returned file-not-found; the actual
parent-directory worksheet was then read. This was an inspection-path error,
not a failed acceptance validation or a source repair.

Review Sol repair rounds0; unsuccessful validations0; Astra0; no escalation
gate. Turnover investigation counters remain Sol0/unsuccessful0/Astra0. Parent
TLS diagnostic retains initial peer failure1/successful repair1/unsuccessful0;
status collector retains initial failure1/successful repair1/unsuccessful0.
All owned commands finished and no background process was created. Decisions
needed: none for this bounded review. Remaining qualification obligations and
the upstream95 blocker remain with the parent.

## Exact reviewed parent snapshot

The following46 identities comprise13 tracked deltas and33 completed untracked
artifacts/requests. The active request-wire proof and this newly authored review
are excluded. Earlier trusted review/input identities are additionally pinned
by their respective receipts; the new turnover receipt records all47 source
and evidence inputs.

| Reviewed path relative to worktree | SHA256 |
| --- | --- |
| `README.md` | `9fefed2ce2f39dae0287917f1ef05f42a668b204f535775a2508cb3c08081dbc` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex` | `e39287a11a7f7cff6604258457136db811d69288bcc938f1f572ca159f8effc7` |
| `docs/acceptance/evidence/m3/upstream-transport/retained-bounds-source.md` | `1e2a4b0e7ad6a56d84b7001a321f63ae0bf7bd8b6ef39559ea1f41b692c71f79` |
| `docs/acceptance/evidence/m3/upstream-transport/source-api-review.md` | `cd7203e1483d2a13d0accd92846dcc7a08d9457068c60d0d4ea3b244e0a492c1` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/current-docs-review.md` | `bdc0235605d30d356a957594d97582035c93bcdef51fc83d643e5c34b6420b84` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-control-turnover-proof.json` | `5ff190653dc5286786ba07d3f33bc980879d7992133e0cdd0f4520e962ef52a8` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-control-turnover-proof.md` | `613cf2ed23571f36eb527727b8d574b745fa6cc075b3e8b59e1c42fa7b565604` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/header-control-issue.json` | `593bd7571d1228c3d23458cd6254395dab92a846ad4fd4bb72c35061bea0fe9c` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/independent-bounds-review.md` | `8e91a98e4cc0981b8385ea79ebaaecd9488d2b61be19dc076d4469da0ef3478a` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/otp28-tls-tracking-issue.json` | `633088898f600d420adce56a8a8082120d1211a3f98fe8ab8d253da578738d33` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/post-comment-format-check.json` | `c2166c7c0d3413a59b8bd6e656ccddc66c04418eeaae3bb8b55ee5dc24991845` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/post-comment-format-check.log` | `616af94fce86ec2d5e5daed733a760890594fc5f3d792403112eb694ee7b1ae7` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/post-comment-format-source-after.json` | `155539a9a0e7cb880d636a618882b2df7f910dc156e4bdeae6892b06b7f57553` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/post-comment-format-source-before.json` | `155539a9a0e7cb880d636a618882b2df7f910dc156e4bdeae6892b06b7f57553` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/precommit-identity-recheck.json` | `6eaca5d6a9cdf3bd237b98b47a0e5f63fb27e51541a603ca06f3a1abab944046` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/qualification-notes.md` | `5f2c574b79505b841af65de85f86e0782b2ccb1375b93e6dc24e2bd672baebf4` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/request-input-charge-issue.json` | `f4201c2bf9c8967b37095c2df992830f0f014557d8462806a12dce3b1bc8a034` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/tls-policy-backing-issue.json` | `8f20e017f25fb9810573a7886143a47f7359673e1325702bf0f362bd92cb071f` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/tls-socket-shape-probe.json` | `dd7aacda299741373840a885bed77011980e907266b577246bcf4de8554eda34` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/tls-socket-shape-probe.log` | `ef140e6738f239a8a1637947599f7214a9fc3e74a36d221c7b521b9cecd2f5e2` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/tls-socket-shape-repair1-source-after.json` | `d16e5e845629f97f86fd6327f26f3b259736ca335f26ea72b3fa945917e03411` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/tls-socket-shape-repair1-source-before.json` | `d16e5e845629f97f86fd6327f26f3b259736ca335f26ea72b3fa945917e03411` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/tls-socket-shape-repair1.json` | `27a13f4fb44df7c69b6b07c918a2dd2c40ee94b483cec02623e5c55455681881` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/tls-socket-shape-repair1.log` | `ef140e6738f239a8a1637947599f7214a9fc3e74a36d221c7b521b9cecd2f5e2` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/tls-socket-shape-source-after.json` | `d16e5e845629f97f86fd6327f26f3b259736ca335f26ea72b3fa945917e03411` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/tls-socket-shape-source-before.json` | `d16e5e845629f97f86fd6327f26f3b259736ca335f26ea72b3fa945917e03411` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/upstream-status-current.json` | `d922f5a90368058423f30d93e84fb7f57713d39899fc943665132a16809cfc15` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/upstream-status-refresh1-initial.json` | `3155e922eb72c82ae4a74b57f667ae4c59d643d3abf9ce7f93710fde23edca9a` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/upstream-status-refresh1.json` | `f48d0ce1594f2c2b41736875ed4d6817cd2b6911071b2d936167d2a78e723751` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/upstream95-comment-delta.json` | `3ceb696a93be89e78bed9e79a8569acbdd81183c614595c32d8d222396fd07a9` |
| `docs/acceptance/m3.md` | `988d26e063b5fcad4ee035f2891c78f7d764390ed941453389bf370624810baa` |
| `docs/dependency-followups.md` | `2e9bc11831cc429d230b23617fe46aa8cf793b41db639b88b1188ea38be2b190` |
| `docs/dependency-requests/http-fetch-h2-header-control-bounds.md` | `3486097b1d3414bc0ad0a63d51c4c9a321026793daaf4b1b5114e5f228b76746` |
| `docs/dependency-requests/http-fetch-managed-capacity-error.md` | `186aeb362b65c81b6a3c039f94c54389f6bd106aac25559359dc032c0754c0a7` |
| `docs/dependency-requests/http-fetch-managed-request-inputs.md` | `9135d0ef1d1f371fc12b8d6492b1d626a0ea01be462fff4c4f8dbcd63c44be1a` |
| `docs/dependency-requests/http-fetch-managed-tls-backing.md` | `8410d09cd0f1ea952ddf21aa7d3b39ad0c1d1d69b801a21a95fe11c6bf6f7cd9` |
| `docs/dependency-requests/http-fetch-otp28-tls-tracking.md` | `a1e4801583e630d2156a40c363b6f84ba28483672da828cf4c66fd2a8eaf8505` |
| `docs/designs/m3-gateway.md` | `708020bc3e1954b63d507936466b3d9b066d969c7c2277db69b238cafa78b883` |
| `docs/designs/m3-managed-h1-preparation.md` | `ef33fb557977a9c07ea31d5ba280409ccefc0e174163412daa9840c5ab2806c2` |
| `docs/designs/m3-upstream-transport.md` | `6210322d83ad1a0d7a6b13fc53aadc01786b5c3f615af8964dfd89d46d5aefe1` |
| `docs/gateway.md` | `afc7a383baddb55911fe5786507c73308a912423ce8d1ec97ea58c030f1e5bfd` |
| `docs/http-proxy.md` | `67b9d7f75d8ae5fff97469c0406ebe50bc519f05c2a57bed17e5a61f697b426b` |
| `docs/implementation-status.md` | `86dd2f292a3daaf9cd9f73f325a8cd866b8aed834660cb87a45174e79b38bf0c` |
| `docs/plans/m3-gateway.md` | `24550d361a1ed0fd1e3a1fee3184004b4ba96db995f0ef5318610700ebf36e42` |
| `docs/plans/m3-managed-h1-preparation.md` | `1b6333c69c893e45b8ffd05858633a905c64ef27f8047891f692d242f1c7b52a` |
| `docs/plans/m3-upstream-transport.md` | `88f97743a71e09e1f0c137eac89ece2cd82532111349fb4ec74a5c6c13d9b36b` |
