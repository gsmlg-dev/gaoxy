# Gaoxy 0.13.0 release acceptance

Date: 2026-10-26, Asia/Shanghai. Publication source:
`bd325eb408d4566b807bcef9fdaf1a2b1ad83a2d` on `main`.
**PASS:** ordinary local and exact-source hosted qualification, stable GitHub
and Hex publication, independent public-artifact verification, fresh Hex-only
issue regressions and downloaded standalone checks. Evidence-only main commits
after publication do not move the release tag.

## Delivered behavior

[#16](https://github.com/gsmlg-dev/gaoxy/issues/16) removes implicit native
WebSock frame/message-size, fragment-count, callback-batch, inactivity and
absolute-lifetime ceilings. Generic service byte/state budgets no longer impose
a hidden message or callback-state ceiling. H1/H2/H3 preserve upgraded
connections, including H2 owner-idle restoration after its final WebSocket and
H3 keepalive below a finite peer idle period. Explicit application limits,
protocol validation, reusable finite staging/queues/windows and separate finite
operation deadlines remain effective. The complete-message WebSock API still
uses memory proportional to retained messages, state and pending output.

Phoenix socket declarations require `websocket: [timeout: :infinity]` for
persistence. Application authentication, heartbeats and deliberate close policy
remain application decisions. The separately configured message-level proxy
bridge retains its own policy. See the [configuration guide](../websocket-limits.md),
[#16 implementation evidence](internal-16-default-capacity.md) and
[release notes](../releases/0.13.0.md).

[#17](https://github.com/gsmlg-dev/gaoxy/issues/17) classifies confirmed peer
closure during H2 TCP/TLS receive-option setup as an orderly stop before
admission/writer allocation. Bare and SSL-wrapped candidates use the supported
socket API to confirm closure. Live-peer option failures retain their original
error. See the [focused evidence](internal-17-startup-peer-close.md).

The published cohort uses Hell 0.1.3, Abyss 0.10.0, HTTP/TLS/QUIC 0.21.17 and
Plug.Crypto 2.2.1. All six Hex distributions and the standalone application
report 0.13.0. Released upstream APIs resolve the previously recorded gates.

## Local qualification and independent clients

Retained evidence is under [release-0.13.0](evidence/release-0.13.0/).
Local Linux runs use Elixir 1.18.5, OTP 28 and bounded BEAM schedulers; exact
commands, durations and exits remain in the receipts. All **418 tracked Elixir
product/test files** match both canonical and prepublication fingerprints and
the publication source; `source-bridge.json` preserves that comparison. Later
test-client and optional-consumer lock changes were requalified on the exact
source by hosted workflows and the release job.

| Gate | Result |
| --- | --- |
| Canonical ordinary suites | PASS: unit 254, component 181, protocol 133; **568 executed**, zero failures/excluded/skipped |
| Inventory, formatter and strict compilation | PASS; 98 active files, 145 retained files |
| Package staging | PASS: 12 tests |
| Final built-package consumers | PASS: base 3, H3 2, HTTPFetch 2, plus production/release isolation |
| Isolated source H3 consumer | PASS: 2 tests |
| Optional QUIC consumer after lock update | PASS: 4 tests, locked resolution and strict compile |
| Final unified independent clients | PASS: 8/8 checks, fixture exit 0 and source restored |
| Final packaged H3 peer | PASS: 3/3 checks, child exits 0 and endpoints reusable |
| Independent specification/code and public-verification reviews | APPROVED, no remaining actionable findings |

The user selected conforming independent H3 clients after the pinned and latest
aioquic clients mishandled QUIC's zero peer idle timeout. The shared Quinn peer
now covers ordinary H3 requests and the original 73,728-byte consumer upload;
quic-go covers the remaining H3 extended-CONNECT Channels exchange. Original
CA/hostname, ALPN, byte, status, FIN/EOF, close, cleanup and finite-deadline
assertions remain. This client replacement changes no server idle policy.
The detailed diagnosis, rejected attempts and final peer review remain in
#16's implementation evidence and the archived historical receipts.

## Exact-source hosted workflows and release

All five source workflows passed on the publication SHA: **10 successful
required jobs**. The separate manual released-server client job was skipped
under its existing gate. `source-ci.json` and `source-ci-details.json` retain
the exact source and job dispositions.

| Workflow | Successful run |
| --- | --- |
| Static checks and build | [40211994878](https://github.com/gsmlg-dev/gaoxy/actions/runs/40211994878) |
| Unit tests | [40211994921](https://github.com/gsmlg-dev/gaoxy/actions/runs/40211994921) |
| Integration and end-to-end tests | [40211994959](https://github.com/gsmlg-dev/gaoxy/actions/runs/40211994959) |
| Portable HTTP smoke | [40211994927](https://github.com/gsmlg-dev/gaoxy/actions/runs/40211994927) |
| Package and consumer qualification | [40211994923](https://github.com/gsmlg-dev/gaoxy/actions/runs/40211994923) |

Portable checks cover Linux/macOS start, one HTTP `/health` response requiring
200 and `ok`, and successful stop. Source integration owns real protocol tests.

The guarded [release run 40212587939](https://github.com/gsmlg-dev/gaoxy/actions/runs/40212587939)
completed successfully with version 0.13.0, ref main and the full expected SHA.
It repeats **568** ordinary cases, **9** isolated source-consumer cases,
**7** built-package consumer cases, **19** Phoenix regressions, unified clients
and standalone smokes. After publication, fresh Hex-only built consumers pass
another **7** cases plus production/release isolation. `release.log.gz` and
`qualification-counts.json` retain the executed counts and source identity.

## Independent public verification

The stable, non-draft [v0.13.0 release](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.13.0)
passed independent read-back:

- **8 GitHub assets** match their sizes/digests and the successful Actions
  artifact byte for byte; all **7 payload checksums** match.
- **6 public Hex releases** are unretired and match the GitHub package bytes,
  checksums, exact dependency requirements and source. All **136 packaged `.ex`
  files** match the commit: core 23, HTTP 45, H3 10, proxy 42, test helper 12,
  adapter 4. Runtime versions and HPAX absence pass.
- Remote tag read-backs before and after verification resolve to the full
  publication SHA. Actions metadata and matching bytes establish the recorded
  build relationship; cryptographic build attestation was **NOT VERIFIED**.
- Fresh native and Phoenix consumers resolve exact public 0.13.0 packages
  without source overrides, strictly compile and execute **23 tests, 0
  failures/excluded/skipped**. These comprise native defaults 5, H2 persistence
  4, real TLS startup-close 1, Phoenix default capacity 1, configured limits 6
  and compatibility 6. Their **72 packaged source files per consumer** match the
  commit. Commands, locks, manifests and logs are retained in
  `public-issue-regressions.json` and `public-issues/`.
- The downloaded Ubuntu standalone archive passes **13/13 checks**: core 3,
  gateway 7, H3 3. Every command and child exits 0; owned process groups are gone
  and H3 endpoints are reusable. Its SHA-256 is
  `2067b30f6d31e5a1d120b74459da7f34e4488a62b758c30b7f07b43ce66229e3`.
  Nix host library compatibility settings are process-local and recorded in
  `downloaded-runtime-receipt.json`; this is downloaded Ubuntu runtime evidence.

Initial public checks failed during Python CA setup and dependency installation,
before the affected package/test checks. The reruns use the verified system CA
with TLS verification intact. A separate artifact-verifier failure rejected
Elixir's canonical `hell: "== 0.1.3"` keyword rendering because it recognized
only the equivalent tuple syntax. The original verifier remains unchanged.
An audit-only copy accepts both exact Hell/Abyss forms; independent Hex metadata,
source, checksum and requirement comparisons still execute. Its **5 controls**
pass: actual canonical package/source and wrong/missing pins for each dependency.
Two parser repair rounds and the first failed positive control remain recorded.
Independent review approves this bounded audit fix and the final artifact/runtime
receipts without claiming a reviewer rerun.

`evidence-manifest.json` and `closeout-evidence-manifest.json` record original
and archived hashes for retained
receipts and byte-preserving compressed logs. The helpers are archived at their
original content and expect the `.audit/release-0.13.0/` paths recorded in the
manifest when rerun. The first hosted package failure at `e7d294d0`, aioquic
failures, stale optional-consumer lock and local setup failures remain distinct
from the final exact-source PASS.

## Issue closeout and scope

After qualified publication and public regressions, both issues were labeled
`internal request fixed`, evidence-commented and closed as completed:
[#16 completion](https://github.com/gsmlg-dev/gaoxy/issues/16#issuecomment-6400631627)
and [#17 completion](https://github.com/gsmlg-dev/gaoxy/issues/17#issuecomment-6400633151).
Fresh GitHub MCP search and paginated REST discovery both return **0 open
issues** labeled `internal request`. `issue-closeout.json`, the two final
issue/comment snapshots and `final-github-mcp-issue-audit.json` /
`final-rest-issue-audit.json` retain that read-back. No further release is needed.

Historical specialist abnormal/disconnect, slow-peer, pressure and sustained-load
evidence retains its actual disposition. The separately gated released-server
suite, deployment, production data/certificates, Vault and public-management
acceptance are outside this release qualification.
