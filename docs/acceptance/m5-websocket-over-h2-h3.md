## v0.4.0 publication preparation — 2026-10-19

The later user request explicitly authorizes committing, main integration, push and GitHub v0.4.0 publication after this completed M5 acceptance. Source acceptance remains distinct from fresh portable packaged-byte qualification.

[Release acceptance](release-0.4.0.md) records artifact and publication gates, currently pending. Earlier local-only and capability snapshots below retain their capture-time status. No deployment or specialist testing is part of this release.

# M5 WebSocket over HTTP/2 and HTTP/3 acceptance

Started 2026-10-19 at `4c6f08959e64303ab6ce6cf3280a1035a82c916f`, on local branch
`codex/m5-websocket-over-h2-h3`. **M5 COMPLETE LOCALLY within ordinary
verification scope; independent SPEC and CODE acceptance PASS.**
The [reviewed plan](../plans/m5-websocket-over-h2-h3.md) defines acceptance.

| Gate | Status | Evidence |
| --- | --- | --- |
| G0 dependency/fixture and peer audit | PASS | Baseline 35 tests/0 failures; root and fixture strict compile exit 0; peer API 3/3 and Elixir API 8/8; Chromium launch PASS, actual WS negotiation NOT RUN |
| G1 shared handshake/runtime | PASS | Independent SPEC/CODE PASS after H3 identity repair; parent fresh 22 shared tests and 2 ordinary H1 cases, all passing |
| G2 H2 defaults and WebSocket/h2c | PASS | Independent SPEC/CODE PASS; parent fresh 26 tests plus 2 named contract cases; H2 and h2c each 15/15 ordinary peer cases |
| G3 H3 WebSocket | PASS | Independent SPEC/CODE re-review PASS; fresh H3 cohort 82/0 within G5 scoped run, independent verified H3 peer 15/15 |
| G4 Phoenix/vendor/browser integration | PASS | Source and fixture SPEC/CODE PASS; wrapper 11/0, vendor 3/0, real Phoenix ownership 4/0; final H2/H3/H1 browser profiles each 12/12 |
| G5 compatibility and independent review | PASS | Fresh scoped 136/0, named compatibility and consumers PASS; final whole-stage SPEC then CODE review PASS, no actionable findings |

Only ordinary protocol, finite valid network and browser scenarios are in scope.
Specialist abnormal/disconnect/slow-peer/pressure/load qualification stays in its
dedicated environment. No push, release, deployment or production operation is
authorized by this execution. Current M3 acceptance and historical evidence remain
intact. G0–G5 accept H2-first HTTPS, native H2/h2c/H3 WebSocket and the qualified
Phoenix browser profiles within the scope and client-selection limits below.

Historical counters are inherited from the response-pressure Counter54, recorded
in [its acceptance](m3-native-h1-response-pressure.md): Root734/orchestration617,
native tooling139, native Sol7, failed-green7, production-repair1, valid-RED1.
These categories are separate and are not added together. Astra recovery remains
2/2 exhausted. M5 expected RED and repair attempts are recorded separately without
resetting those counters. No third Astra recovery round is authorized.

G0 peer audit retained two tooling repairs (metadata-shape parsing, then public
module export loading before its build existed); both failed attempts remain in
the audit evidence and the final public API run passed. They are not production
repairs. A parent documentation patch context mismatch was corrected before any
document change. These historical attempts remain preserved.

G0 independent specification and code review passed without actionable findings.
The fixture compile was pending at the review cutoff and subsequently completed
with exit 0. [G0 evidence](evidence/m5/g0/) preserves both strict compilation
receipts, baseline results and independent-peer preparation. Actual WS protocol
negotiation remains assigned to later gates.

G1's independent review found one shared-stream identity mismatch: H3 retains a
four-element transport identity whereas H2 uses three. A private extractor now
supports both unchanged forms; a deterministic H3-shaped push/data/normal-Close
test first failed for that defect and then passed. Independent SPEC and CODE
re-review passed. Fresh parent verification executed 22 shared tests plus two
ordinary H1 network cases in separate commands, all passing.

The earlier G1 32/0 receipt included the existing mixed H1 network file. It is
preserved as historical execution, but its specialist cases are not required M5
acceptance and were excluded from the fresh parent commands. ExUnit location
filters are global: the mixed selector receipt listed 33 tests but executed only
two; the separate shared receipt executed all 22 unit cases.

M5 additions so far: G0 tooling repairs 2; parent patch-context correction 1;
G1 successful production review repair 1. G2's first 26-test run had one new test
contract error: Plug's valid cache-control response header was disallowed by an
over-specific exact-header assertion. The corrected contract requires status 200
and rejects H1 upgrade/framing fields while allowing ordinary response headers,
as the design requires. The failed receipt is retained; no production change was
needed for that correction. Expected feature RED receipts are separate from
unexpected failures. Inherited counters and the exhausted recovery allowance
remain unchanged.

G2's first H2/h2c peer runs each completed 13/15 cases and failed in the Python
peer when an empty DATA/END_STREAM was passed to wsproto after the WebSocket
Close exchange. Empty transport frames now skip only the WebSocket decoder;
H2 flow-control acknowledgments, StreamEnded processing and Close assertions
are unchanged. Independent re-review passed, followed by fresh parent tests and
15/15 cases for each profile. Both profiles recorded wire CONNECT metadata,
two WebSocket streams and HTTP siblings on one connection, server pushes before
client WebSocket bytes, actual post-request-deadline communication and normal
Close/END_STREAM. Runtime shutdown and zero admission/retained/cleanup counts
passed. This adds one peer-fixture repair and two failed profile receipts, with
no H2 production repair. G2 browser/Phoenix acceptance remains G4.

G3 implements native H3 setting 8 opt-in, immutable CONNECT metadata, owner-only
QUIC I/O, deadline adoption in both owner and Operations, independent bounded
input demand, and the shared WebSock engine in the existing worker. Independent
review found one missing activation flag in the actual H3 Exchange. The network
case now uses the real PlugAdapter upgrade; it failed 1/1 before the production
repair and passed 1/0 after it. Re-review passed. The pure-test module-loading
guard repair and its failures also remain preserved.

The first independent H3 peer run failed after 4/15 cases because the fixture
selected its transport using a request cleared by the shared runtime. It now
uses the unchanged transport identity shape. Repaired and fresh post-review
H3 runs passed 15/15, including two WebSocket streams and HTTP siblings on one
verified connection, idle application push, bounded post-request-deadline
communication, normal Close/FIN and zero resource/shutdown checks. Fresh G5
scoped execution contains 82 H3 tests/0 failures. [G3 evidence](evidence/m5/g3/)
retains all initial failures, repairs and independent review. This adds one
production review repair and one peer-fixture repair; no Astra recovery.

## G4 Phoenix and browser results — 2026-10-19

Phoenix explicitly lists exact `websocket_paths`. The wrapper presents GET only
during the Endpoint call for validated, enabled H2/H3 WebSocket CONNECTs;
the immutable Exchange retains CONNECT, version and protocol, and the returned
Conn method is restored. The code-reload wrapper, duplicate-listener guard and
existing Origin/session/CSRF/authentication/early-validation pipeline remain
active. H3 mounts the wrapper externally with Endpoint `server: false`.

The focused wrapper/configuration/upgrade run passed 11/0; the same cases are
included in G5's fresh scoped run below. Fresh real Phoenix ownership checks
passed [4/0](evidence/m5/g4/g4-fixture-ownership-postreview.json), and the isolated
vendor regression passed [3/0](evidence/m5/g4/g4-vendor-postreview.json).
[Vendor provenance](evidence/m5/g4/vendor-provenance/receipt.json) verifies the
canonical patch, reconstruction and source hashes against upstream
`80901f46c8864cb8bd5231c32b7171b9d0e330ce`. The old dispatch-only fork identity
`53ee1c7c9edb39fda9c531a5c79aec17ee081a6c` is historical, not the new snapshot.
The current patch SHA256 is
`8249f142caddf55381905c3e2b24f573ac675a9ae30d87abb0644a7b0ad2acfe`.

| Final browser profile | Executed | Successful native WebSockets | Report |
| --- | --- | --- | --- |
| H2 | 12/12 PASS, exit 0 | CONNECT/websocket, streams 9 and 13 on one H2 connection | [report](evidence/m5/g4/browser-h2/run-1792396605588111196/report.json) |
| H3 | 12/12 PASS, exit 0 | CONNECT/websocket, streams 16 and 24 on one H3 connection | [report](evidence/m5/g4/browser-h3/run-1792396633655454139/report.json) |
| H1 compatibility | 12/12 PASS, exit 0 | GET upgrades for both Phoenix socket paths | [report](evidence/m5/g4/browser-http1/run-1792396633640680341/report.json) |

Each final profile executed LiveView mount/click/upload, Channels join/ping and
server PubSub push, marker-correlated actual WebSocket transport, ordinary
Origin refusal, normal clean Close 1000 for every opened socket, zero active/
retained/cleanup-pending resources and confirmed runtime DOWN. The parent viewed
all three retained screenshots: counter 1 and the 22-byte upload are visible.
The browser observer's status 101 is Plug's upgrade convention; independent
H2/h2c/H3 peers separately verified actual wire status 200.

Chromium 152.0.7977.64 used the generated localhost certificate SPKI and the
recorded feature flags. An ordinary HTTPS navigation precedes the application
flow to prepare startup trust/session state. Clients select WebSocket transport;
an H2 page alone does not guarantee H2 sockets, including after future
certificate updates. H3 initially exposes UDP only with explicit IPv4 resolution
and QUIC selection for that localhost authority. After both accepted sockets
prove H3, a public `Gaoxy.HTTP.service_spec` / `Gaoxy.add` fixture command adds
same-port H1 TLS for the opaque-Origin policy check. That check returned H1 TLS
403 in both multiplexed profiles. It establishes retained Phoenix Origin policy,
without an H2/H3-specific negative claim or automatic H3 selection with TCP
available. Final socket correlation still rejects any H1 fallback.

[All 15 browser attempts](evidence/m5/g4/browser-attempts.json) retain their
original PASS, FAIL and BLOCKED_ENV results. Initial failures covered the build
cohort, opaque-Origin fixture setup, public Phoenix disconnect cleanup, second
H2 connection capacity and H3 IPv4/TCP fallback setup. Simultaneous H3/TCP and
two later H2 attempts selected H1 and remained BLOCKED_ENV. NetLog demonstrated
startup certificate-configuration changes retiring reusable H2 sessions; a
specific PKI callback is a candidate cause, not proven. The bounded startup
navigation repair passed [independent SPEC/CODE review](evidence/m5/g4/g4-review/rereview-browser-startup-navigation.json)
before the three final runs. Assertions, finite deadlines and server protocol
defaults were preserved. Parent fixture repairs followed the recorded local
Sol route; inherited counters and exhausted Astra 2/2 remain unchanged.

## G5 compatibility results — 2026-10-19

| Check | Fresh result | Receipt |
| --- | --- | --- |
| Exact 17-file M5 unit/ordinary-network scope | 54 HTTP + 82 H3 = 136 tests, 0 failures; exit 0 | [scoped run](evidence/m5/g5/g5-scoped-postreview.json) |
| Ordinary H1 proxy policy | 2 executed, 12 excluded, 0 failures | [proxy policy](evidence/m5/g5/g5-proxy-policy.json) |
| Successful verified WSS | 1 executed, 2 excluded, 0 failures | [WSS](evidence/m5/g5/g5-verified-wss.json) |
| Ordinary native H1 WebSock | 2 executed, 9 excluded, 0 failures | [H1](evidence/m5/g5/g5-h1-normal.json) |
| Changed H2 contract selectors | 2 executed, 49 excluded, 0 failures | [contracts](evidence/m5/g5/g5-h2-contract-selectors.json) |
| Independent H2 / h2c / H3 peers | 15/15 each, exit 0 | [H2](evidence/m5/g5/h2/run-1792395394167400737/report.json), [h2c](evidence/m5/g5/h2c/run-1792395395046890959/report.json), [H3](evidence/m5/g3/h3/run-1792395394006128091/report.json) |
| Clean external core / HTTP / H3 consumers | 1/0, 2/0, 2/0; exit 0 | [core](evidence/m5/g5/g5-core-consumer.json), [HTTP](evidence/m5/g5/g5-http-consumer.json), [H3](evidence/m5/g5/g5-h3-consumer-repair1.json) |
| Strict compilation | PASS, exit 0 | [compile](evidence/m5/g5/g5-strict-compile.json) |
| Exact changed Elixir file formatting | 43 paths PASS, exit 0; later browser fixture formatting PASS | [format](evidence/m5/g5/g5-final-format-repair1.json), [fixture](evidence/m5/g4/g4-browser-h3-sequencing-format.json) |

Counts above are separate executions, not an aggregate unique-test total. Mixed
specialist files were selected only by their named ordinary cases. Root scoped
tests do not execute vendored dependency tests; the separate vendor receipt is
required and retained. All peer exchanges include HTTP siblings, unsolicited
application pushes, communication after the original HTTP request deadline and
normal Close/END_STREAM or FIN.

Receipts record exact commands, source/diff/file hashes, environment, nonzero
executed counts and exits. ExUnit ran in the locked environment with Elixir
1.18.5 / OTP 28.5.0.7, `MIX_ENV=test` and `ERL_FLAGS='+S 2:2'`; browser fixtures
used their recorded dev build with `PHOENIX_NATIVE_H3=1`. Python was 3.13.15,
with h2 4.3.0, hpack 4.1.0, hyperframe 6.1.0, aioquic 1.2.0, wsproto 1.2.0 and
Playwright 1.56.0. Final browser receipts are based on
`2c666dd4745a4c7ba5f2c304c4cb5a7ce942ff32` plus recorded task-owned changes;
earlier gate receipts retain their own actual HEAD and dirty-source hashes.
The root lock is unchanged, SHA256
`c93b608b77c457e4324430544c1acc2b384ee21e1a2b8ab528bad248ac666cb6`.
[Source custody](evidence/m5/g5/g5-source-custody.json) confirms 303 application/
vendor source, test and provenance paths are unchanged since the passing scoped
run, and records the final browser report and screenshot hashes.

The first H3 consumer attempt failed dependency selection with zero executed
tests; it remains FAIL, not a passing consumer gate. Its two explicit 0.21.4 pins
were aligned to the already selected 0.21.10 cohort, independently reviewed and
freshly passed 2/0. The initial formatting failure was one extra EOF newline;
the failed receipt and passing repair remain. Expected wrapper/vendor RED runs
and all earlier failures also remain. No production dependency was patched and
no upstream issue-97 proof was reintroduced.

## Independent acceptance and local closeout

Final whole-stage [SPEC review](evidence/m5/g5/g5-review/spec-review.json) passed
first, followed by [CODE and evidence review](evidence/m5/g5/g5-review/code-review.json),
with no actionable findings. The reviewer verified 303 scoped source hashes,
310 final source/configuration/provenance hashes, all three browser profiles'
138 runtime source paths, vendor provenance, separate compatibility/consumer
counts, all 15 historical browser reports and byte-identical evidence copies.
Only final status/static-check and local-commit bookkeeping followed this review;
no implementation repair or additional runtime gate was required.

The initial closeout [documentation-link check](evidence/m5/g5/g5-doc-links-initial.json)
failed one newly written H3 link. It now targets the original retained G3 peer
report; no runtime evidence was changed or duplicated. Raw browser HTML and
command logs retain their original whitespace through evidence-only Git
attributes. Final static-check and local-commit receipts complete custody below.

Final [static verification](evidence/m5/g5/g5-closeout-static.json) passed:
43 exact Elixir formatting paths, browser Python syntax, documentation links,
unchanged scoped/browser source hashes, `git diff --check` and evidence private-key
scan. The final ledger bookkeeping was then checked again before its commit.

[Local source custody](evidence/m5/g5/g5-local-source-commits.json) verifies all
310 reviewed source/configuration/provenance files are committed byte-identically
through `99aa4d3f53706228fc3732ed98f4fc6a89dada9b`. The final documentation/evidence
commit is a descendant of that source snapshot. The closeout source commits are:

| Commit | Change |
| --- | --- |
| `3adaf22` | Phoenix wrapper, native H2/H3 policy-preserving handoff and reviewed vendor provenance |
| `c619c64` | Strict Phoenix H2/H3/H1 browser qualification and fixture |
| `99aa4d3` | Isolated H3 consumer pins aligned with the locked cohort |

Main remains `4c6f08959e64303ab6ce6cf3280a1035a82c916f`; the unrelated untracked
prompt is byte-identical. M5 is complete on the retained local branch/worktree.
Merge, push, release, deployment, production operations and specialist testing
were not part of this execution.
