# Gaoxy 0.13.1 release qualification

Baseline: `9f272f9284e1526838d518b294e08f62511191c6` on `main`.
Status at this checkpoint: **focused implementation and full local qualification
PASS**; exact-source hosted workflows, publication and public checks are
**NOT RUN**. Issue #18 stays open until qualified publication and public
verification. The final publication source and closeout will be recorded below.

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

After the adapter repair and an added raw-budget control, the first GREEN
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

The immutable local receipt is
`.audit/release-0.13.1/local-qualification-dwo5hmgr/receipt.json`; it retains
commands, environment, timestamps, exits, log hashes and all source fingerprints.
Its final check confirms those files did not change during qualification. The
commit bridge and archived receipts will identify the publication source after
the main commit is created. Earlier RED/fixture failures remain separate.

## Publication and independent verification

**NOT RUN at this checkpoint.** Release must pass all five exact-source hosted
workflows before dispatching guarded `release.yml` with the full expected SHA.
Independent public verification will require six Hex packages, eight assets,
seven payload checksums, package/source/dependency equality, a fresh Hex-only
execution of the 15 issue regressions and 13 downloaded standalone checks.

The public artifact and runtime helpers preserve the previously qualified
verification contracts. Preparation controls and actual network/runtime
acceptance remain separate. Earlier release evidence and historical specialist
abnormal/disconnect, slow-peer, pressure and sustained-load dispositions remain
unchanged. Deployment, production data/certificates, Vault, public management
and the separately gated released-server E2E suite are outside this work.
