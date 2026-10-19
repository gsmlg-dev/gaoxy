# M5 WebSocket over HTTP/2 and HTTP/3 acceptance

Started 2026-10-19 at `4c6f08959e64303ab6ce6cf3280a1035a82c916f`, on local branch
`codex/m5-websocket-over-h2-h3`. **Implementation IN PROGRESS.**
The [reviewed plan](../plans/m5-websocket-over-h2-h3.md) defines acceptance.

| Gate | Status | Evidence |
| --- | --- | --- |
| G0 dependency/fixture and peer audit | PASS | Baseline 35 tests/0 failures; root and fixture strict compile exit 0; peer API 3/3 and Elixir API 8/8; Chromium launch PASS, actual WS negotiation NOT RUN |
| G1 shared handshake/runtime | PASS | Independent SPEC/CODE PASS after H3 identity repair; parent fresh 22 shared tests and 2 ordinary H1 cases, all passing |
| G2 H2 defaults and WebSocket/h2c | IN PROGRESS | Default HTTPS/H1 negotiation checked; native H2/h2c peer acceptance pending |
| G3 H3 WebSocket | IN PROGRESS | Pure preparation 64 tests/0 failures; runtime and independent review pending |
| G4 Phoenix/vendor/browser integration | NOT RUN | No feature acceptance claimed |
| G5 compatibility and independent review | NOT RUN | No feature acceptance claimed |

Only ordinary protocol, finite valid network and browser scenarios are in scope.
Specialist abnormal/disconnect/slow-peer/pressure/load qualification stays in its
dedicated environment. No push, release, deployment or production operation is
authorized by this execution. Current M3 acceptance and historical evidence remain
intact. H2-first HTTPS defaults and H2/H3 WebSocket remain unaccepted until their
corresponding implementation gates pass.

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
