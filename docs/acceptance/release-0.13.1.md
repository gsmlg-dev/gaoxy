# Gaoxy 0.13.1 release acceptance

Date: 2026-10-29, Asia/Shanghai. Publication source:
`84c7ff76461ada8aebaa34c567c61206bc963d83` on `main`, from baseline
`9f272f9284e1526838d518b294e08f62511191c6`.
**PASS:** local qualification, exact-source hosted workflows, stable GitHub/Hex
publication, independent public artifacts, public issue regressions and
downloaded standalone checks. Issue #18 is closed as completed; both final
discovery methods find zero open internal requests. Later documentation/evidence
commits advance main without moving the publication tag.

## Repair and scope

[#18](https://github.com/gsmlg-dev/gaoxy/issues/18) reports Plug SSE responses
becoming HTTP 500 when middleware supplies `Connection: keep-alive` and the
transport switches to HTTP/2. The compatibility repair is a private pure
function at `Gaoxy.PlugAdapter`, called by buffered, file, chunked and
informational response operations before native serialization.

For H2/H3 it removes connection-specific response fields, including response
`te`, and all fields nominated by any `Connection` field. Names and nominations
are case-insensitive; ordinary field order and duplicates remain. Original
field count and retained bytes are checked before tokenization/filtering, so
stripping headers cannot bypass resource ceilings. Invalid collections pass
unchanged to the existing strict response validator. Native response/header
validation, unrelated malformed fields, content-length and streaming framing
errors remain effective. H1, request headers and WebSocket upgrade paths keep
their existing behavior. No dependency or vendor-provenance change is needed.

All seven own manifests target 0.13.1, and staging synchronizes all six public
Hex distributions including `gaoxy_websock_adapter`. Its vendored upstream
version remains 0.6.0. Current installation examples and
[release notes](../releases/0.13.1.md) follow the new version. See the
[design and execution plan](../plans/issue-18-plug-response-headers.md).

## Executed regression evidence

The initial fixture setup used an unsupported protocol order and failed before
the intended semantic reproduction; that output remains separate. The corrected
baseline execution then ran **14 tests, 9 failures**, exit 2, before production
changes. Both H1 transport cases passed; H2 MCP POST SSE and held GET
notifications returned 500, and the controlled compatibility cases failed.

An expanded RED run with the added raw-budget control records **15 tests,
9 failures**, exit 2. After the adapter repair, the first GREEN
attempt ran **15 tests, 1 failure**, exit 2: a controlled test exchange omitted
trailer-limit fields used by the unchanged fixed-stream validator. The fixture
was corrected without changing those assertions. The fresh focused run passes
**15 tests, 0 failures**, exit 0: **11** pure/controlled unit cases and **4**
real H1/H2 protocol cases. This required one successful Sol fixture repair;
no Astra recovery occurred.

Controlled cases cover all four public adapter operations, H3 shared-boundary
parity, H1 exact header-list preservation, mixed case/repeated Connection
nominations, duplicate ordinary headers, file ranges, informational status,
malformed fields, fixed-stream framing, native strict rejection and raw budgets.
Independent Python h2 and HTTP/1 clients exercise buffered/file/informational
responses, MCP-shaped POST SSE, a synchronized held GET SSE stream with later
data, normal completion, healthy follow-up, admission cleanup and endpoint reuse.
No browser, real external service or specialist pressure slice is involved.

Focused formatting, inventory and whitespace checks pass. The canonical manifest
now schedules unit **265**, component **181**, protocol **137**: **583** cases
across 100 active files, with the same 145 retained paths.

## Fresh local publication qualification

Independent specification/code review approved all 23 frozen task files without
remaining findings. The parent then qualified the integrated versioned source on
Linux with Elixir/Mix 1.18.5, OTP 28 (ERTS 16.4.0.5), Python 3.13.15 and
`ELIXIR_ERL_OPTIONS='+S 2:2'`. Every command exits 0:

| Gate | Result |
| --- | --- |
| Inventory, formatter, strict compile | PASS |
| `python3 scripts/check-repairs.py all` | PASS: unit 265, component 181, protocol 137; **583 executed**, zero failures/excluded/skipped |
| `python3 scripts/test-stage-hex-packages.py` | PASS: **12 tests** |
| `python3 scripts/test-consumers.py` | PASS: base 3, H3 2, HTTPFetch 2; **7 tests**, plus production/release isolation |

The [local receipt](evidence/release-0.13.1/local/receipt.json) retains commands,
environment, timestamps, exits, log hashes and all **620** input fingerprints.
Its final check confirms those files did not change during qualification.
[source-bridge.json](evidence/release-0.13.1/source-bridge.json) then compares
every fingerprint with the publication commit and working tree. Root README
and documentation are separately covered by the frozen-file review. Independent
local source and archive reviews approve the retained evidence; earlier
RED/fixture failures remain separate.

## Publication and independent verification

All five source workflows passed on the publication commit: **10 successful
required jobs**, with the separate manual `release-clients` job skipped under
its existing gate. The [CI summary](evidence/release-0.13.1/source-ci.json.gz) and
[job details](evidence/release-0.13.1/source-ci-details.json.gz) retain every status.

| Workflow | Successful run |
| --- | --- |
| Static checks and build | [40727342441](https://github.com/gsmlg-dev/gaoxy/actions/runs/40727342441) |
| Unit tests | [40727342463](https://github.com/gsmlg-dev/gaoxy/actions/runs/40727342463) |
| Integration and end-to-end tests | [40727342522](https://github.com/gsmlg-dev/gaoxy/actions/runs/40727342522) |
| Portable HTTP smoke | [40727342580](https://github.com/gsmlg-dev/gaoxy/actions/runs/40727342580) |
| Package and consumer qualification | [40727342467](https://github.com/gsmlg-dev/gaoxy/actions/runs/40727342467) |

The guarded [release run 40728588011](https://github.com/gsmlg-dev/gaoxy/actions/runs/40728588011)
passed with version 0.13.1, ref main and the full expected SHA. It repeated
**583** ordinary cases, **12** staging cases, **9** isolated source-consumer
cases, **7** built-package consumer cases, **19** Phoenix regressions, unified
clients and standalone smokes before publication. Fresh public Hex consumers
then passed another **7** cases plus production/release isolation.
[release-qualification-counts.json](evidence/release-0.13.1/release-qualification-counts.json)
and the compressed raw release log retain the executed counts and source.
Portable coverage remains one native HTTP start, `/health` requiring 200 and
`ok`, and stop on Linux/macOS.

The stable, non-draft [v0.13.1 release](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.13.1)
passed independent verification:

- **8 GitHub assets** match sizes/digests and the successful Actions artifact
  byte for byte; all **7 payload checksums** match.
- **6 public Hex packages** are unretired and match the GitHub bytes, checksums,
  exact dependency pins/optionality and commit. All **136 packaged `.ex` files**
  match: core 23, HTTP 45, H3 10, proxy 42, test helper 12 and adapter 4. Runtime
  versions and HPAX absence also pass. The tag resolves to the publication SHA.
  Cryptographic build attestation was **NOT VERIFIED**.
- A separate fresh Hex-only 0.13.1 consumer strictly compiles and passes
  **15 tests, 0 failures/excluded/skipped**: 11 controlled adapter cases and
  4 real H1/H2 cases, including POST SSE and later GET notifications on the
  same stream. Its **72 packaged source files** match the commit without source
  overrides. Tag read-backs before/after agree; all owned processes stop.
- The downloaded standalone archive passes **13/13 checks**: core 3, gateway 7,
  H3 3. All commands/children exit 0, three owned process groups stop naturally
  and H3 endpoints are reusable. Its SHA-256 is
  `385e84867a7f724507b401b1c0b6c760cb0bb0e073cdfe641ead83cb05a1a748`.
  Nix library compatibility settings remain process-local; system CA and hostname
  verification remain enabled. This is downloaded Ubuntu runtime evidence.

The [artifact receipt](evidence/release-0.13.1/public-artifacts/receipt.json),
[public issue receipt](evidence/release-0.13.1/public-issues/receipt.json) and
[runtime receipt](evidence/release-0.13.1/downloaded-runtime/receipt.json) retain
commands, source identities, hashes, counts and cleanup evidence. There were
no failures or retries in these public runs. Independent
[public qualification review](evidence/release-0.13.1/issue-18/public-qualification-review.json)
approves the actual receipts and raw evidence without claiming a reviewer rerun.

Preparation controls remain separate: issue harness 6, artifact verifier 20,
runtime guards 23. The reviewed explicit pre-import checksum guard rejects an
altered reused helper with ordinary and optimized Python. Frozen public helpers
remain unchanged during acceptance. These controls supplement the actual public
runs; their synthetic fixtures are not release/runtime evidence.

## Issue closeout and evidence

After publication, public checks and independent review, #18 was labeled
`internal request fixed`, [evidence-commented](https://github.com/gsmlg-dev/gaoxy/issues/18#issuecomment-6475513940)
and closed as completed. Fresh [GitHub MCP discovery](evidence/release-0.13.1/final-github-mcp-issue-audit.json.gz)
and [paginated REST discovery](evidence/release-0.13.1/final-rest-issue-audit.json)
both return **0 open issues** labeled `internal request`. No further release is
needed.

[evidence-manifest.json](evidence/release-0.13.1/evidence-manifest.json) records
original/archive hashes and sizes for the retained receipts, source bridge,
reviews, metadata and byte-preserving compressed logs. Helpers are archived
unchanged and expect their original `.audit/release-0.13.1/` paths recorded in
the manifest. Earlier review reports retain their actual checkpoint status;
the final public review records completed qualification. The implementation
used one successful Sol fixture repair and no Astra recovery.

The final Git whitespace check initially rejected whitespace retained inside
the raw diff and three JSON receipts. Those four originals are now gzip copies;
their decoded bytes and original hashes remain unchanged. The initial failure
and compression mapping are retained in the evidence archive.

Earlier release evidence and historical specialist abnormal/disconnect,
slow-peer, pressure and sustained-load dispositions remain unchanged.
Deployment, production data/certificates, Vault, public management and the
separately gated released-server E2E suite are outside this work.
