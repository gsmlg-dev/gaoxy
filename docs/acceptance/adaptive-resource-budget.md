# Adaptive resource budget acceptance

Status: CORE repair14 and its independent review are accepted. All35 fresh
final-source gates passed, including **900 canonical cases**, with zero
failures, exclusions or skips and682 unchanged source inputs. Package/isolation,
Phoenix, independent clients, standalone and optional QUIC checks also passed.
Independent final12DoD/20-verification review accepts the source for authorized
delivery. Commit, push, publication and public-artifact/runtime acceptance remain open.
Earlier results below describe their own source checkpoints, including both
preserved optional QUIC failures and the accepted scoped repair.
The objective is the complete adaptive budget, dynamic H1/H2/H3 ownership,
Phoenix integration and coordinated release.
Design and remaining tasks are recorded in
[the design](../designs/adaptive-resource-budget.md) and
[implementation plan](../plans/adaptive-resource-budget.md).

On 2026-10-29 the user explicitly replaced numerical failure limits with a
twelve-hour execution quota, **2026-10-29 22:09:44 through 2026-10-30 10:09:44
Asia/Shanghai**. The pending additional-repair request is therefore resolved.
CORE, H1/H2 and H3 resume Astra recovery within that window, preserving all
cumulative counts and historical failed/blocked checkpoints below. This grant
does not accept the frozen candidate or waive any verification/release gate.

On 2026-10-30 the user adds **24 hours** to that quota. The new fixed deadline
is **2026-10-31 10:09:44 Asia/Shanghai** (UTC2026-10-31T02:09:44Z), preserving
the original start and a total36-hour allowance. The earlier expiry and selected
model-capacity interruption remain historical; no failure counter is reset.

## Final source qualification — 2026-10-30

`final014-all` freshly passed **900/0/0 excluded/0 skipped** across121 active
files:390 unit,323 component and187 protocol cases. The407-second command used
the protocol workflow's pinned `hpack4.2.0` environment. All682 tested input
hashes match the reviewed CORE14 source and remained unchanged during execution.
Final inventory, formatting, strict compilation, workflow lint and12 staging
regressions passed. Built-package consumers passed7 cases plus production/
release isolation; all five isolated source-consumer commands passed their
9 cases. Four independent Python harness scripts passed36/0.

The final Phoenix example passed27/0; independent clients passed10 checks and
unified H1/H2/H3 passed8 checks with source restored. Independent selected H2
RFC cases passed40/0 and reverse-proxy checks passed6/0. Strict production
compilation and a rebuilt release passed unchanged core3/Gateway7/H3-3 smokes.
Linux portable smoke passed exactly one native start, GET `/health` requiring
200 and `ok`, and stop. The unchanged optional QUIC consumer freshly passed4/0.
All35 receipts are terminal PASS, with identical682-input maps, empty source-
change arrays and matching raw-log hashes. The
[final source archive](evidence/adaptive-resource-budget/final014/archive-manifest.json)
preserves81 originals, commands, environments, counts and hashes.

The [independent final integration review](evidence/adaptive-resource-budget/final-review/integrated14/archive-manifest.json)
verifies all35 actual command receipts,
all682 current input hashes, all81 archived originals and the900 positive test
summaries. Its12 Definition-of-Done and20 verification rows accept the ordinary
implemented/source scope with no actionable finding, while explicitly leaving
publication and public-runtime acceptance open. The remaining current-design
status wording finding was resolved without changing any executable input.
The scoped executable/current-document whitespace check exits0. The complete
archived-diff check retains exit2 for immutable raw patch/log whitespace;
archive contents and line endings are preserved rather than rewritten.

Live read-back confirms0.14.0 unused in all six Hex distributions, the GitHub
tag and release. All seven own manifests and staged packages target0.14.0.
No source, publication or runtime result is inferred from version availability.
The final commit/source bridge, push, exact-source hosted jobs, guarded release
and independent public-artifact/downloaded-runtime checks remain pending.

## Extended-window qualification — 2026-10-30

The repair12 source, including the reviewed README overlay, passed **898/0**:
unit390, component321 and protocol187 across121 active files, with zero
exclusions/skips. All682 input hashes stayed unchanged during the430-second
command. Formatting, strict test/prod compilation, workflow lint, locked
dependencies, inventory,12 staging cases,7 built-consumer cases and all five
source-consumer commands also passed. Four Python harness checks passed36/0.
Phoenix passed27 example cases,10 independent client checks and8 unified
H1/H2/H3 checks with source restoration. Selected independent H2 RFC cases
passed40/0 and reverse-proxy checks passed6/0.

The rebuilt source release passed the unchanged core3, Gateway7 and H3-3
smokes. Linux portable smoke passed one native start, GET `/health` with200
and `ok`, and stop. The optional QUIC consumer compiled strictly but then ran
**4 tests with1 failure**, exit2: its verified echo peer timed out after the
server terminated with `:byte_limit` during the existing bounded large-stream
exchange. The explicit262144-byte cap, peer and assertions are unchanged.
This failing gate is not accepted, and no cause or successful repair is claimed
at this checkpoint. Its original receipt/log and preceding passing commands
remain under `.audit/adaptive-resource-budget/qualification/ext24h014-*`, with
byte-preserving copies and hashes in the
[extended-window archive](evidence/adaptive-resource-budget/extended-window-before-quic/archive-manifest.json).
CORE continues its existing Astra route as repair13 within the extended window.
Commit, push, publication and public artifact/runtime checks remain NOT RUN.

Repair13's public-profile regressions passed5/0. The unchanged consumer then
passed flow-control/FIN, isolation and directional-control checks, reaching the
later listener-removal case. The full command remains **FAIL4/1**, exit2:
removal returned in9ms, but the independent peer timed out awaiting closure at
its original10-second deadline. The old byte-cap failure and this later failure
remain separate evidence. Neither the successful large exchange nor removal
latency establishes complete shutdown compatibility. No closure cause or fix is
claimed at this checkpoint; source, diagnostic receipts and original peer
hashes remain under `.audit/adaptive-resource-budget/core/time-quota/optional-quic13/`.

## Accepted CORE repair14 — 2026-10-30

Raw QUIC receive credit now follows one bounded facade read quantum:
`min(native_capacity, max_packet, 16384)`. Consumption replenishes it. Native
buffer/writer safety ceilings, durable operation history, explicit service caps
and the H3 transport profile are preserved. Two additive component controls
verify explicit/default/small-cap raw profiles and the unchanged H3 profile.
They pass5/0, and inventory now expects900 cases:390 unit/323 component/187
protocol across121 active files. This inventory is not a full900-case result.

The second failure was local drain ordering: Admission became draining before
the host delivered its shutdown event, allowing the callback to exit before the
host requested a native close. On exactly `:draining`, QUICBridge now requests
public close code0 before callback termination, including handlers without an
optional terminate callback. The existing host callback watch, Service drain
deadline and native guardian proof remain effective; a close reply never
authorizes a refund.

The unchanged optional consumer passed4/0, with a separate audit-only traced
repeat4/0. Both complete344064-byte stream exchanges and preserve listener
close, healthy sibling and port-reuse assertions. The traced full exchange
observed ready4096 bytes, cached operation results92583 bytes, the unchanged
256-operation history, native total96679 bytes and QUIC retained high water
101507 within the original262144 cap. Listener removal took11ms and the peer
observed close code0. The tracer's separate905139-byte admission observation
belongs to the TCP sibling; it is not a QUIC measurement.

Scoped CORE123/0, H3 network13/0, strict test/prod compilation, formatting,
inventory and owned whitespace checks passed. Independent review accepted the
four frozen changed inputs, resolved the public-guide finding and verified
all scoped receipt/log hashes, unchanged consumer inputs and original
deadline/cleanup semantics. Cumulative CORE counts are Sol2/Astra14. The two
initial diagnostic4/1 commands, profile-fixture setup failure, intended RED,
and repair13's later4/1 remain failed evidence. The
[repair archive](evidence/adaptive-resource-budget/core-time-quota/astra14-optional-quic/archive-manifest.json)
preserves43 original files byte for byte. Final parent qualification and
publication remain separate pending gates.

## Accepted CORE repair12 — 2026-10-30

The actual returned-state/output backing failures are resolved. The final
candidate passed30 raw TCP/TLS cases and72 native/isolation/Admission
compatibility cases, strict test/prod compilation, owned formatting and
inventory. A rebuilt source release passed the unchanged original three-
transport smoke, including admitted TCP/TLS replies after the SIGTERM admission
barrier, VM exit and UDP endpoint reuse. Independent Sol review accepted the
frozen candidate and all three prior findings as resolved; CORE is now
Sol2/Astra12, without resetting prior counts.

Ordinary uncompressed ETF preserves exact accepted app-state identity while
detaching binary backing; failed normalization retains original state only for
terminal cleanup. The actual send boundary receives independent65/67-byte
binaries for borrowed binary/nested iodata output. The paid formula is
`2 * D + 4 * max_state + 3 * max_output`, default905139 bytes. This bounds
bridge-owned state/copies/send values, not arbitrary callback/NIF allocation or
total BEAM RSS. Resource handles remain usable in the actual passing cases.
All callback/drain deadlines and original smoke assertions are preserved.

The [repair and independent review archive](evidence/adaptive-resource-budget/core-time-quota/astra12/)
contains immutable commands, source hashes, raw logs and reports. The parent
verified all682 candidate input hashes before the reviewed README-only905139
overlay. The expected full manifest is now898 cases (390unit/321component/
187protocol),121 active files; this paragraph does not claim that full run.
Final qualification binds the complete current source freshly. Publication
and public artifact/runtime qualification remain NOT RUN.

## Recovery kickoff — 2026-10-30

Astra11 corrected the unsupported16KiB raw buffer restriction and passed14 raw
compatibility cases plus72 related cases, with strict compile/format/inventory.
The retained-state diagnostic then executed16 cases with2 failures: actual TCP
and verified TLS each observed a65-byte application slice retaining8192 bytes
of backing. No backing repair is implemented or accepted at this checkpoint.
Ordinary same-VM ETF diagnostics preserve representative resource usability and
detach binary slices; the attempted local ETF closure profile failed decoding
and is not adopted. CORE remains Sol2/Astra11; repair12 resumes under the new
time allowance with independent review and fresh whole-source gates required.
The current884-case inventory is arithmetic, not a passing full execution.
The protected standalone smoke last passed on the earlier Astra9 source.
Commit, push, release and public read-back for the current integration are
NOT RUN. Frozen reports, exact receipts, patches and diagnostic scripts are
preserved in the [raw recovery archive](evidence/adaptive-resource-budget/core-time-quota/astra11-raw/),
with byte-preserving hashes in its archive manifest.

## Versioned checkpoint before raw-stream recovery — 2026-10-30

The versioned0.14.0 candidate passed a complete **868/0** canonical run with
the protocol workflow's exact `hpack4.2.0` peers, all120 files, zero exclusions/
skips and681 stable source inputs. The Phoenix workflow intentionally pins
`hpack4.1.0`; its separate environment passed27 example tests,10 independent
client checks and8 unified H1/H2/H3 checks with source restored. Selected H2 RFC
checks passed40/0 with4.2.0. Both environments' actual imports and distribution
versions are recorded; no requirements were changed. The earlier full4.1.0
canonical868/0 remains supplemental evidence, rather than being relabeled as
the protocol-pinned run. Package staging12/0, built consumers7/0 with isolation,
all five source-consumer commands, formatting, strict compile and workflow lint
also passed. Evidence is under
[`versioned-0.14.0/`](evidence/adaptive-resource-budget/versioned-0.14.0/).

Production strict compilation and the source-built0.14.0 release build then
passed. The unchanged core standalone smoke **FAILED, exit1**: initial TCP/TLS/
UDP traffic and the SIGTERM admission barrier succeeded, but the admitted TCP
connection closed before its required post-barrier response. This is an actual
ordinary compatibility failure. The logged new connection's `:draining` error
alone does not identify why the admitted connection closed. The failed receipt
and log are preserved in the same archive. CORE continues its already-escalated
recovery with cumulative Sol2/Astra6 and active Astra7 under the existing fixed
time allowance. No release-script assertion, payload or deadline is waived.
Later standalone gateway/H3, portable and optional-QUIC commands were **NOT RUN**
after that fail-fast stop. Commit, push, publication and public-artifact checks
remain **NOT RUN**.

After the accepted CORE6, H1/H2-16 and H3-12 recoveries, independent source
reviews and finite connection-churn integration, the parent ran the complete
canonical `python3 scripts/check-repairs.py all` gate. It passed **868 executed,
0 failures, 0 exclusions, 0 skips**, covering all120 active files: unit390,
component321 and protocol157. All681 input hashes stayed unchanged throughout
the418-second command. Formatter, strict compile, inventory and all36 Python
gate-regression tests separately passed on the same inputs. Terminal receipts
and original logs are archived under
[`final-integration/`](evidence/adaptive-resource-budget/final-integration/).

The new three-protocol churn regression reopens a fresh connection three times
per protocol on the same instance, generation, address and listener port. Every
round observes live request accounting, an exact successful response, request
completion before close, and zero terminal ownership/cleanup before reuse. The
scoped16/0 run and all nine rounds are retained under
[`churn/`](evidence/adaptive-resource-budget/churn/), including the original
16/1 H1 idle-byte fixture-contract failure and its bounded test correction.
The complete868-case gate includes all three new churn cases and the13 promoted
controlled H3 ConnectionTest cases.

The earlier H3 native-lifetime, persistent SSE/WebSocket and deadline findings
are resolved in the independently reviewed H3-12 candidate and now pass within
the complete integrated gate. Earlier failed receipts below remain historical
evidence, including frozen816/16 and Phoenix3/1; they are not rewritten as
passing runs. Native macOS/Windows execution and dedicated specialist pressure,
slow-peer and sustained-load qualification remain **NOT RUN**.

Live GitHub/tag and all six Hex queries found0.14.0 unused, with latest0.13.1.
Seven own version manifests, current installation documentation and release
notes now target0.14.0. That metadata change requires the separate final
versioned-source package/Phoenix/protocol/standalone gates, which are running.
Commit, push, release and new public artifact/runtime acceptance remain
**NOT RUN** at this checkpoint.

## Time-quota recovery checkpoints

CORE Astra4 adds explicit `ResourceBudget.repartition/6` and
`Admission.repartition_until/5`, preserving scalar compatibility, funded totals,
ownership, deadlines, operation identity and canonical/local transport caps.
Gate registration now precedes blocking dispatcher preparation. Its candidate
and independent fresh regression both passed **268/0**, zero exclusions/skips;
strict compile, scoped format and whitespace passed. Independent review accepted
the scoped contract and existing preparation-failure cleanup coverage. All 679
inputs were stable during its fresh run. Historical CORE counts are Sol 2 /
Astra 4 at that checkpoint; raw candidate/review evidence is retained under
[`core-time-quota/astra4/`](evidence/adaptive-resource-budget/core-time-quota/astra4/).
The measured manifest updates are Admission 44 / OWNER 56, yielding unit 377 /
component 298 / protocol 149. This inventory is not a full passing execution.

CORE Astra6 adds optional `Admission.spawn_request/8` phase receipts for exact,
authenticated expiry before reservation. Legacy replies and all ambiguous or
post-reserve errors retain their original shape and ownership. Status and work
telemetry now distinguish retained bytes, temporary credit and total `usage`,
with separate high waters; total charges and administrator caps remain intact.
The candidate and fresh independent regression both passed **274/0**, without
exclusions, skips or source changes. Review, strict compile, scoped formatting,
whitespace and updated inventory passed. The six added Admission cases raise
the current manifest to unit 377 / component 304 / protocol 149; this is not a
full passing execution. Cumulative CORE counts are Sol 2 / Astra 6. Evidence,
including the retained Astra5 50/1 fixture-order failure, is archived under
[`core-time-quota/astra6/`](evidence/adaptive-resource-budget/core-time-quota/astra6/).

H1/H2 Astra16 implements explicit funded-credit repartition, measured TCP receive
backing, separate WebSocket transport credit, authenticated expired-start
retirement and writer/parent terminal proofs. Its frozen candidate passed
**340/0 + 38/0 = 378/0**, with no exclusions, skips or changed inputs. Scoped
formatting, strict compilation and whitespace passed. Independent source review
accepted all 25 unchanged inputs and the resolved final-write deadline finding.

The parent freshly passed **340/0** HTTP compatibility and **22/0** HTTP budget,
default-TLS and constructor cases. The shared helper file then executed **16/1**:
the H3 persistent SSE close again reported `session_terminated` with `:killed`.
That fresh failure remains open under H3; the candidate's earlier helper16/0 is
not a whole-source passing claim. Native H1/H2 ordinary verification is scoped
to those passing HTTP results. Unconfirmed writer termination at the original
close deadline retains its charge; forced-writer/slow-peer qualification remains
unrun. Cumulative H1/H2 counts are Sol 2 / Astra 16. Raw candidate, selected
failed history, independent review and parent receipts are archived under
[`h1h2-time-quota/astra16/`](evidence/adaptive-resource-budget/h1h2-time-quota/astra16/).

The manifest now records H2 budget10, H2 idle8 and WebSocket stream23: unit377,
component307 and protocol154 across118 active files. This adds three component
and five protocol cases, and is not a full passing execution. Before caller
migration, H1 wire acceptance was **13/3**; its prior Sol 2 / Astra 2 failed
checkpoints and later recovery failures remain preserved. Original timeout
errors alone cannot serve as absence proof.

The four Python gate-regression scripts separately passed **36/0**, with zero
skips/exclusions and unchanged tested script/manifest hashes. They use fake Mix,
temporary inventories and mocked socket/process observations; these are harness
checks, not extra app or protocol acceptance. Receipts and logs are under
[`meta-validation/`](evidence/adaptive-resource-budget/meta-validation/).

Next-release public artifact/runtime verifier copies are prepared with required
version, full source SHA and a reviewed helper digest. Independent parent
Python-only controls passed **80/0** (4 identity,47 artifact,29 runtime guards),
with unchanged helper sources. Exact packaged lib/priv contents, application/
sibling versions and safe extraction remain checked. These are offline harness
checks using historical/synthetic fixtures; actual new-release artifacts,
downloaded runtime and published consumers remain **NOT RUN**. Evidence and
reviewable helper copies are under
[`release-verifier-preparation/`](evidence/adaptive-resource-budget/release-verifier-preparation/).

The actual Phoenix example has a third adaptive-default mixed HTTP H1 / TLS H2 /
QUIC H3 acceptance case. Its first execution was **3/1**: both previous cases
passed, while the independent H3 peer closed with code `0x1` awaiting SETTINGS
before any held request began. That failed evidence and every original assertion
remain preserved; no production cause was established by that log.

After installing bounded public close/status diagnostics and formatting the
example, the parent freshly passed **3/0** focused cases and **19/0** combined
budget/body/stream/LiveView/WebSocket compatibility cases. Mixed responses and
SETTINGS barriers passed without changed inputs. This is ordinary example
qualification; it neither erases the original failure nor establishes its cause,
and final integrated/source-built publication gates remain outstanding. These
fresh receipts are in the parent evidence within
[`h1h2-time-quota/astra16/`](evidence/adaptive-resource-budget/h1h2-time-quota/astra16/).

Read-only H3 preflight confirms that existing request-only cleanup attachment
cannot directly retain a connection lease: a typed CORE connection-cleanup seam
is required to preserve native bytes and the actual connection quota after
callback termination. This is a local ownership dependency; public exact engine
terminal proof exists. No native-lifetime runtime reproduction or H3 repair is
claimed by the [preflight map](evidence/adaptive-resource-budget/h3-time-quota/preflight/handoff.md).
H3 Astra3 continuation now owns the necessary typed CORE connection-cleanup
extension and serialized validation, retaining H3 Sol2/Astra2 history and the
fresh parent SSE helper failure. No native-lifetime repair acceptance is claimed
at kickoff.

The controlled native-lifetime regression subsequently reproduced early refund
with **3/1**, then passed **3/0** after typed reservation/cleanup integration.
Native/OWNER/Admission checks passed **115/0**, and exact native-proof negatives
with canonical split deduplication passed **60/0**. These are provisional recovery
checkpoints; independent source review and original H3 SSE/WebSocket compatibility
remain open. Cumulative H3 counts are Sol2/Astra5, with no numerical stop inside
the fixed time window.

The independent [requirement audit](evidence/adaptive-resource-budget/acceptance-audit/report.md)
mapped all twelve Definition-of-Done items and twenty verification requirements.
It identified an additional ordinary evidence gap: finite same-instance
connection close/reopen with public zero usage/counters/cleanup between rounds.
That coverage and the final integrated/publication gates remain outstanding.

H3's final Astra12 candidate subsequently passed **99/0** in the original
eighteen-file H3 selection and **134/0** in disjoint Admission/OWNER/helper
checks, for **233 executed cases** without exclusions or skips. Strict compile,
owned formatting and source whitespace passed on the same 680 input hashes.
Independent final review resolved the native-lifetime P1 and cleanup-deadline P2,
and accepted the typed ownership, bounded progress and partial-init contracts.
The reviewer also checked the preserved WebSocket payloads/deadlines and the
small callback-window regression. These scoped results and original failed
checkpoints are archived under
[`h3-time-quota/astra12/`](evidence/adaptive-resource-budget/h3-time-quota/astra12/).

The finite H1/H2/H3 churn test is now installed with three protocol cases and
three fresh connection rounds per case. Its first **16/1** combined execution
identified a new-fixture assumption: an idle H1 connection can legitimately
retain its quota with zero carried bytes. A narrowly corrected H1 idle assertion
preserves positive active-request accounting and every post-close zero/cleanup
and same-listener re-admission assertion. The fresh run passed **16/0** (thirteen
controlled connection cases plus three churn cases). Final strict/static handoff
and whole-source qualification are still pending. ARB-CHURN is Sol1/Astra0.

The controlled H3 ConnectionTest is promoted from unscheduled coverage into the
unit suite with its thirteen cases and a matching `@moduletag :unit`; it opens
no real network resources. Together with the measured H3 count updates and the
new churn file, inventory passes **unit390/component321/protocol157**, 120 active
files and **868 scheduled cases**. This inventory is not a passing full-suite run.

## Qualified foundation checkpoint

Source: local `main` commit `a0a05efe`, following memory foundation
`bf2b2865944d85c18917d00854a5c503ce3b443d`. Neither checkpoint has been pushed
or released as part of this objective.

The memory foundation passed 53 focused cases and a fresh qualification of
636 ordinary, 12 packaging and seven clean-consumer tests. The standalone
canonical owners and pure configuration then passed 120 recovery cases and a
fresh combined OWNER/MEM/CONFIG run of **147 tests, zero failures, exclusions
or skips**. Strict compilation, owned formatting and inventory checks passed.
The active inventory at that checkpoint is unit 351, component 242, protocol
137; these inventory counts are not a claim that all 730 tests were rerun after
the OWNER/CONFIG change.

Independent specification/code reviews accepted memory detection, policy,
standalone owners and normalized configuration after the recorded repairs.
The architecture review accepted the documented shared ownership, deadline,
deduplication, overlapping membership and safety-sampling contracts. Production
lifecycle and protocol code still require their own review and verification.

Evidence is retained under
[`evidence/adaptive-resource-budget/`](evidence/adaptive-resource-budget/).
Original failed runs and the passing candidate that subsequently received
review findings remain historical evidence. The OWNER final recovery and
147-case combined run are under `owner-final/`; they do not overwrite the
earlier candidate receipt. The staged checkpoint whitespace check reported an
extra terminal blank line in the immutable `owner-candidate/initial-green.log`;
the raw log was preserved byte-for-byte. Source whitespace checks passed.

## Requirement-to-evidence boundary

The next local checkpoint integrates production Service/Instance registration,
canonical Admission mutations, pre-spawn credit and activation, terminal pairs,
authenticated cleanup guardians and `Gaoxy.resource_budget(instance)`. CORE's
bounded recovery passed 241/0; independent parent review and a fresh combined
run passed **312 tests, zero failures, exclusions or skips**, with strict compile,
formatting, inventory and source whitespace checks. The combined run includes
CORE 241, configuration 45, Phoenix pure 11 and outer compatibility 15.

ListenerSet/Phoenix and Gateway now propagate one normalized top-level instance
policy. Gateway rejects explicit instance policies inside embedded ListenerSets.
Standalone JSON accepts the two public thresholds and three independent quotas
through fixed allowlists. These pure configuration paths passed review and the
combined run. The two prepared real Phoenix/ListenerSet cases were initially
**NOT RUN** pending H1 connection metadata; their subsequent executions are
recorded below. H1/H2/H3 dynamic integration remains in progress.
Receipts and immutable logs are under `core-candidate/`, `core-final/` and `entry/`.
The whole staged whitespace check reports the one-space context markers inside
archived raw unified diffs (exit 2); those evidence files remain byte-preserved.
The staged source/documentation check excluding raw evidence passes (exit 0).

## Protocol integration checkpoint: acceptance blocked

Current local `main` is `bc8a5ef5199293ada3b432c2e2741070d3b2d115`, with
uncommitted protocol integration and documentation. CORE's final bounded
recovery passed **249/0**, including all forty canonical Admission cases.
Independent parent review accepted its authenticated token-addressed resource
proof. Its later forty-case run passed before an example-placement compile
failure in the HTTP test host. The actual Phoenix test now lives in the existing
Phoenix example; no new Phoenix dependency was added to `gaoxy_http`.

H1's three new cases and native ListenerSet case passed **4/0**, and the real
two-Endpoint Phoenix HTTP/HTTPS case passed **1/0**. H1/H2's subsequent focused
run passed **17/0**, including five new H2 cases, the promoted independent TLS
connection regression and eight exact WorkerAccounting cases. The broader
active HTTP compatibility run then failed **337 tests / 19 failures**: six
controlled H2 fixture gaps, six retained-versus-temporary metric assertions,
four trace/dead-gate expectations and three actual shutdown wire regressions.
These failures remain visible. H1/H2 entered bounded Astra recovery with
inherited Sol 2/Astra 0; its passing focused candidate was not accepted integration.

The two Astra rounds subsequently corrected only the controlled idle fixture
and proxy trace/dead-gate tests. Independent review accepted those changes with
all ordinary assertions preserved. Fresh targeted evidence passed **27/0** and
the focused protocol cases passed **17/0**; the original broader command now
executes **337 tests / 9 failures**, exactly six PollBoundary accounting
assertions and three shutdown wire regressions. Runtime tracing confirms
`{:error, :draining}` immediately before the erroneous success terminator and
both upload HTTP 500 responses. The selected stream diagnosis executed one
failing case with twelve filtered; the upload diagnosis executed 4/2. Neither
diagnostic run is a passing gate. Correct prepaid completion-credit reuse
requires CORE compatibility with truthful retained/temporary classification
and conserved pressure-sample debit. No protocol workaround or relaxed metric
assertion was introduced. H1/H2 is now also exhausted at Sol 2/Astra 2.

H3's final frozen run passed **96/0** (CORE QUIC 2, H3 94), plus strict compile,
owned formatting, inventory and source whitespace checks. Independent review
still found one **P1 / BLOCKED_IMPLEMENTATION**: native QUIC byte charges and
connection quota can refund on callback-worker DOWN/EXIT before the separate
QUIC engine has terminated. The finding is source-confirmed; its dedicated
runtime reproduction is **NOT RUN**. Exact public `QUIC.info(handle)` returning
`{:error, :closed}` can establish engine termination; current ownership does
not compose that proof. No upstream missing-API blocker has been confirmed.

H3 and CORE have exhausted Sol 2/Astra 2. Additional bounded repair authorization
has been requested, with the completion-credit evidence added to its scope, and
remains pending. No further affected implementation is authorized while pending.
Final protocol acceptance, final qualification and release remain blocked.

The actual Phoenix adaptive-default regression now passes **2/0** in its focused
file and **18/0** with body parsing, SSE/lifetime, actual LiveView, WebSocket
compatibility and configured-limit cases. It holds three requests/streams across
two independent TLS H2 connections, checks exact public counts and response
payloads, reuses both connections, then confirms zero usage/counters/cleanup.
The separate explicit-policy mixed HTTP/HTTPS case remains intact. Independent
review verified the source, receipt, unchanged lockfile, six raw logs and all
93 context hashes and accepted this scoped candidate. These results do not
accept the blocked CORE/H3 ownership behavior or establish final mixed-H3
qualification. A stale implicit-cap statement in `Proxy.HTTP`'s moduledoc was
also corrected and independently re-reviewed; the change is documentation only.

Frozen hashes and raw historical commands/logs are preserved byte-for-byte in
[`h3-blocked/`](evidence/adaptive-resource-budget/h3-blocked/),
[`h1h2-sol-handoff/`](evidence/adaptive-resource-budget/h1h2-sol-handoff/) and
the [archive index](evidence/adaptive-resource-budget/protocol-handoff-archive.json).
The parent verified H3's nine source, five context and thirteen log hashes;
H1/H2's fourteen source and twelve evidence hashes were verified before handoff.
The then-current inventory was unit 377 / component 290 / protocol 149; inventory
counts are not evidence that the complete suite passed.

The later frozen recovery and Phoenix receipts/logs are in
[`h1h2-blocked/`](evidence/adaptive-resource-budget/h1h2-blocked/),
[`phoenix-h2/`](evidence/adaptive-resource-budget/phoenix-h2/) and their
[archive index](evidence/adaptive-resource-budget/protocol-recovery-archive.json).
Parent and reviewer verified H1/H2's sixteen source, five protected and
twenty-three evidence hashes; the original fourteen source hashes are unchanged.
The Python execution/inventory guards additionally passed **9 + 14 tests**, and
the current inventory check passed with the counts above.

After independent review, parent verification freshly passed **27/0** for the
two H1/H2 compatibility files and **2/0** for actual Phoenix budgeting, plus
strict compilation, owned formatting and tracked/untracked source whitespace.
All recorded command fingerprints show no source mutation. The separate
package-staging regression command passed **12 tests**. All three built-package
consumers passed **7 ExUnit cases** (base 3, H3 2, HTTP Fetch 2), plus manual-mode,
production-isolation and source-built consumer release-isolation checks. The
command exited zero without source mutation. These use local rebuilt 0.13.1
tarballs and establish no new public package or standalone release. They are
prequalification of the frozen local candidate,
not final publication-source acceptance. The full H1/H2 production review is
also continuing read-only while implementation remains frozen. Current receipts
are under [`post-review/`](evidence/adaptive-resource-budget/post-review/).

The subsequent independent H1/H2 production trace requests one additional
**P2** repair: an expired worker startup can be definitively rejected before
Admission creates a reservation/child, yet H2 retains its spawn-addressed
retirement record. The missing token makes the proof return
`:stale_generation`; the definitive-rejection classification omits that
pre-reserve deadline outcome. The row then consumes a stream slot and retries
every 10 ms until connection closure. This is source-confirmed; dedicated
runtime reproduction and a same-connection recovery regression are **NOT RUN**.
Ambiguous deadline outcomes still require real ownership proof. This finding
does not consume or reset the exhausted implementation counters; repair remains
pending additional authorization.

The same review quantified H2's default connection credit: the removed fixed
decoder allowance reduces 30,359,591 bytes to **13,516,840 bytes** of temporary
connection credit, plus measured retained state and a separate 66,560-byte
writer allowance. Idle decoder credit is zero. The remaining formula is
`4 * 65,536 + 8 * (100 * 16,384 + 18,437)` and remains constant across TCP/TLS
and supported SSL `internal_active_n` profiles. Active-once has a real receive
obligation, but necessity of eight maximum TLS100 delivery/copy envelopes for
every profile is **not established** by the bounded review. The controlled idle
fixture funds this arithmetic; it does not prove real receive obligations.
Reduction and decoder-lifetime behavior are evidenced. Final compliance with
the no-unnecessary-idle-reservation requirement remains open, rather than
being inferred from the passing concurrency cases.

The final consolidated request asks for up to two additional Astra rounds per
affected task (CORE, H1/H2, H3), preserving each cumulative Sol 2/Astra 2 record.
It supersedes the earlier pending requests and has not been approved. Affected
implementation and validation are stopped. No new commit, version bump, push
or release was performed at this checkpoint. Remote `main` was read back as
`a6a35438c0a153cd53c87c6a55c19a70a11fb75a`; latest public release was v0.13.1.

## Frozen-source qualification: 816 cases, 16 failures

The subsequent ordinary qualification kept implementation frozen. The complete
unit gate passed; component and protocol gates stopped at their first failing
file. A task-local runner then executed each unattempted canonical suffix file
separately, continuing independent files after failure. It imports
`scripts/check-repairs.py`, verifies that the attempted files form its exact
prefix, and checks every remaining file's positive executed count. No assertion,
active manifest entry, skip or exclusion was changed.

| Command | Executed / failures | Files | Exit |
| --- | --- | --- | --- |
| `python3 scripts/check-repairs.py unit` | 377 / 0 | 53 | 0 |
| `python3 scripts/check-repairs.py component` | 224 / 3 | 17 | 1 |
| Supplemental component suffix | 66 / 5 | 11 | 2 |
| `python3 scripts/check-repairs.py protocol` | 51 / 6 | 15 | 1 |
| Supplemental protocol suffix | 98 / 2 | 22 | 2 |

Combined file coverage is **unit 377/0, component 290/8, protocol 149/8**:
all 118 active files and **816 cases / 16 failures**, with zero exclusions or
skips. This is complete frozen-candidate file coverage across separate commands,
not a passing `check-repairs.py all` gate. All five commands are terminal, all
679 source fingerprints agree across receipts and match the current candidate,
and no source mutation occurred. HEAD remains `bc8a5ef5` plus the recorded
uncommitted integration. Raw logs, original failed gate receipts, exact suffix
results and runners are retained under
[`frozen-qualification/`](evidence/adaptive-resource-budget/frozen-qualification/).

The original nine broader-HTTP failures remain. Seven additional failures were
observed in unchanged test files, each with passing immutable baseline evidence:

- `apps/gaoxy_test/test/helper_test.exs`: **16/3**, baseline **16/0**. H2 persistent SSE
  close exceeds cleanup deadline; H3 persistent SSE records a killed session;
  H1 WebSocket finalization sees a closed socket before its expected close frame.
- `apps/gaoxy/test/staged_activation_test.exs`: **11/2**, baseline **11/0**. Both late
  dispatcher/rollback ordering cases fail. Read-only tracing identifies a CORE
  ordering regression: stop drains the budget before blocked preparation
  returns, so late Admission registration receives `:draining` and service init
  exits before dispatcher startup and the activation cancellation check. Preserve
  the startup/rollback/participant-order/`:stopping` assertions and Ledger's drain
  guard during recovery.
- `apps/gaoxy_http3/test/websocket_network_test.exs`: **2/1**, baseline **2/0**. The persistent
  WebSocket case reports 5,056,787 of 5,242,890 expected response bytes, then a
  30-second timeout. The later normal close can result from client context
  cleanup; it does not establish a server-initiated close or the stall's cause.
- `apps/gaoxy_http/test/stream_lifetime_h2_test.exs`: **2/1**, baseline **2/0**. The independent
  peer observes an unexpected connection close during the initial finite-stream
  reset/infinite-sibling progress check, before shutdown and later scenarios.
  Its cause is not established by that log.

Helper diagnosis links the H1 WebSocket symptom to possible drain-time accounting
rejection, but the executed branch lacks runtime traces. H2 SSE cleanup state
and the H3 worker-kill caller remain unobserved; neither is automatically equated
with the existing completion-credit or native-lifetime finding. Diagnosis and
required future observations are recorded in the evidence directory. No fixture
relaxation is justified. These findings remain within the same affected tasks;
CORE, H1/H2 and H3 each retain exhausted Sol 2/Astra 2 counters and the pending
additional-round request. No repair, commit, push or release followed this run.
Independent read-only review confirmed the counts, canonical-prefix/suffix
selection, baseline comparisons and retained failure/authorization dispositions.

| Requirement | Current evidence | Disposition |
| --- | --- | --- |
| Effective physical/cgroup capacity; nested v1/v2, unlimited, malformed and overflow handling | Focused SystemMemory tests, Linux execution | PASS for implemented detection; native macOS/Windows execution NOT RUN |
| Platform native probe ownership and bounded cancellation | Injected native facility and worker lifetime tests | PASS controlled cases; actual macOS/Windows native paths NOT RUN |
| 50% default, 256/512 MiB fallback, exact 100%/200% thresholds | Pure Policy and standalone OWNER boundary tests | PASS standalone |
| Shared VM and instance memory without listener multiplication | Canonical OWNER tests, native ListenerSet and actual two-Endpoint HTTP/HTTPS cases | PASS focused; final mixed-protocol integration outstanding |
| Atomic projected admission, release/recovery, refresh shrink | OWNER controlled concurrency/capacity and CORE Admission tests | PASS focused; final protocol integration outstanding |
| OOM headroom, process credits, stale/missing samples | Safety and OWNER tests | PASS standalone; production use NOT RUN |
| Authority recovery, permanent ledger-loss fencing | OWNER crash and reconstruction tests | PASS standalone |
| Explicit undoubled legacy caps, independent quotas, omission provenance | CONFIG/activation/provider, OWNER, focused protocol and explicit H3 cap64 cases | PASS focused; final compatibility outstanding |
| Authenticated cleanup receipts and gate-loss reconciliation | Canonical CORE integration and terminal-order cases | PASS controlled; H3 native terminal P1 BLOCKED |
| Dynamic H1 accounting, independent connections and keep-alive request completion | Three new H1 protocol cases | PASS focused; broader shutdown regressions FAIL |
| Dynamic H2 retained state, prepaid decoder peaks and independent connections/streams | Five new H2 cases, TLS default-concurrency, WorkerAccounting and 27/0 fixture/proxy cases | PASS focused; Poll/shutdown FAIL; remaining fixed idle envelope necessity unproven |
| H2 local refusal with HPACK continuity and live siblings | Focused H2 protocol cases; frozen lifetime peer 2/1 | Focused PASS; lifetime FAIL; expired-start retirement P2 outstanding |
| H3 admitted spawn, QUIC/operation/stream ownership and local rejection | Combined 96/0, independent review and frozen WebSocket 2/1 | Focused PASS; WebSocket FAIL; native lifetime P1 BLOCKED |
| Phoenix LiveView/WebSockets and multiple Endpoint ownership | Actual adaptive H2 and two-Endpoint cases 2/0, combined Phoenix 18/0 | PASS scoped and independently reviewed; final mixed-protocol qualification outstanding |
| Mixed ListenerSet HTTP/HTTPS/H3 policy and lifecycle | Focused native HTTP/HTTPS sharing; existing H3 checks in 96/0 | Final mixed-protocol acceptance outstanding |
| SSE, streaming responses and overlapping ordinary uploads | Phoenix SSE in 18/0, focused uploads, frozen helper 16/3 and shutdown/lifetime peers | Ordinary focused cases PASS; cleanup/shutdown/lifetime FAIL; final clients outstanding |
| Ordinary churn, cancellation and drain | Focused CORE/H3 lifecycle cases; frozen staged activation 11/2, shutdown checks and production review | Mixed PASS/FAIL; CORE startup ordering, H2 expired-start P2 and final integrated acceptance outstanding |
| Numeric telemetry, rate-limited warnings and public inspection | OWNER telemetry/warning, CORE integration and public runtime snapshots | PASS focused; final integration outstanding |
| Exact-source package/consumer/runtime qualification | Local prequalification: staging 12/0, built consumers 7/0 plus manual/production/release isolation | PASS local candidate only; final publication-source qualification NOT RUN |
| Coordinated commit, push, release and public artifact verification | Local foundation commits only | Push/release NOT RUN |

The retained specialist pressure, slow-peer, sustained-load and historical
blocked-upload slices keep their existing disposition. This objective does
not reopen those slices or `http_fetch#97`. Ordinary concurrent protocol and
Phoenix cases remain required. Browser automation, deployment, production
data, operational certificates, Vault and public management are outside scope.

## Release boundary

The final version is selected only after checking current remote releases.
All affected public packages must use one version. The existing release
workflow takes the full already-versioned `expected_sha`, repeats qualification,
publishes six Hex packages, verifies public tarball bytes, tags that source and
creates the GitHub release. Final acceptance requires the actual workflow and
public consumer/artifact results; a prepared package or local commit alone
does not satisfy publication.
