# Gaoxy 0.9.0 release acceptance

Date: 2026-10-22, Asia/Shanghai. Work starts directly on `main` at
`32933790457bcfa3533e40dc2ae4d51ad91aa86d`. The user requests all eligible open
`internal request` fixes and publication of the next version. The initial three
requests were supplemented by four newly opened requests during execution.

Status: **Implementation committed and pushed; local qualification PASS;
final hosted verification and publication pending.** See the
[release plan](../plans/release-0.9.0.md).

## Implemented requests

| Request | Result and scope | Evidence |
|---|---|---|
| #3/#7: active SSE lifetime | Public listener/route stream policy supports `:request`, positive milliseconds and `:infinity` on H1/H2, after request-body EOF. Header/body acquisition, individual I/O, admission and shutdown remain finite. H2 policy is stream-local; H3 rejects the opt-in explicitly. | H1 10, independent H2 2, public contract 3, Generation cleanup 9, H3 boundary 1, real Phoenix 2; independent review PASS |
| #5: verified client certificates | Optional/required client presence with trusted-CA verification, trusted DER propagation to actual Phoenix HTTP/WebSocket peer data, untrusted-client rejection and forged-header isolation under TLS 1.2/1.3. | Core configuration 4, Phoenix configuration 2, real TLS 4; nearby author regressions 27; independent review PASS |
| #6/#9: WebSocket and LiveView capacity | Omitted message ceiling follows configured frame ceiling. Explicit message limits, fragmented totals and service-budget clamps remain authoritative. Actual escaped 300 KiB LiveView form input survives rendering, retained application state, HTTP reload and WebSocket rejoin. | Configured limits 6, actual Phoenix channel 6; LiveView 4 including frame/aggregate rejection; independent review PASS |
| #8: valid Phoenix transport options | Accept Phoenix-owned `log` and `code_reloader` options while keeping wire-engine validation strict. | Direct options 2 and actual H1 upgrade/channel exchange 1; independent review PASS |
| #10: supervised shutdown allowance | HTTP/H3 wrappers share the pure validated core-limit shutdown budget. User initialization remains deferred until startup. Actual supervised active H1 uploads drain and release owned runtime/socket resources with default 5000 ms and configured 5500 ms drain limits. | HTTP 5, H3 budget/initialization contract 2; nearby author regressions 18; independent review PASS |

The final combined issue gate executes **46 root tests and 17 real Phoenix
tests**, with zero failures, exclusions or skips. The HTTP/3 shutdown evidence
is a budget/initialization contract; actual supervised active-upload evidence
uses H1. Manifold, SecretHub, Sigma, Backplane and other requesting applications
still own their downstream migration/production acceptance.

## Final source qualification

Environment: Linux x86_64, Elixir/Mix 1.18.5, Nix OTP 28.5.0.7
(ERTS 16.4.0.6), `ELIXIR_ERL_OPTIONS='+S 2:2'`. Python drivers use 3.13.15;
independent peers use Python 3.12.13, h2 4.3.0 and aioquic 1.2.0.
Browser qualification uses Playwright 1.56.0 and installed Chromium.

Source manifest: `source-files.json.gz` in the evidence directory; its sorted
JSON content fingerprint is
`83787ae55fa912c87d19b7c252117bd4144c5e64e67fcbc83a64b5fe152f2be5`.
It records runtime, tests, workflows, fixtures, manifests and dependency locks
on the uncommitted candidate. No source file changed during final verification;
the unified browser test restored its temporary source edit.

| Gate | Command/evidence | Result |
|---|---|---|
| Issue-specific root regressions | Eleven files selected explicitly by `scripts/check-tests.py`, seed 0, max cases 1 | PASS: 46/0, exit 0 |
| Real Phoenix issue regressions | Four issue files in `examples/phoenix_native`, same wrapper/seed | PASS: 17/0, exit 0 |
| Ordinary compatibility | `python3 scripts/check-repairs.py all` | PASS: exactly 265/0, zero excluded/skipped, exit 0 |
| Canonical format and strict production compile | `mix format --check-formatted`; `MIX_ENV=prod mix compile --warnings-as-errors` | PASS: both exit 0 |
| Standalone assembly | `MIX_ENV=prod mix release gaoxy --overwrite` | PASS: exit 0 |
| Packaging-tool regressions | `python3 scripts/test-stage-hex-packages.py` | PASS: 9/0, exit 0 |
| Five actual Hex archives | Staging, `mix hex.build`, independent metadata/payload inspection | PASS: all 0.9.0; exact runtime/source payloads, Hex-only dependency metadata, unchanged vendor provenance, MIT licenses; exit 0 |
| Five isolated source consumers | Existing core, HTTP, H3, Gateway and H3 Gateway scripts | PASS: 9/0 across five isolated source consumers, exits 0 |
| Unified Endpoint browser/peer acceptance | `integration/phoenix_native/unified.py` | PASS: 8 checks, H1/H2/H3, Channels/LiveView, reload/restore and shutdown; exit 0 |
| Local standalone runtime | Sequential core, Gateway and H3 smoke scripts | PASS: 3 transports + 7 exchanges + 3 H3 checks; exits 0 |
| Workflow lint and whitespace | `nix shell nixpkgs#actionlint --command actionlint ...`; `git diff --check` | PASS: exits 0 |
| Independent specification/code and final release-source review | Reports in `evidence/internal-requests/` | PASS: no unresolved findings |

The package cohort is `gaoxy_websock_adapter`, `gaoxy`, `gaoxy_http`,
`gaoxy_http3`, and `gaoxy_proxy`. Six own application/umbrella manifests are
0.9.0; `gaoxy_server` ships inside the standalone application. Vendored upstream
metadata remains 0.6.0; staging gives its Gaoxy distribution version 0.9.0.
Dependency locks and vendor source/provenance remain unchanged.

## Preserved failed and unexecuted attempts

Expected red tests, unsuccessful fixtures and review findings retain their real
status in the archived audit evidence; none is relabeled passing.

- A combined streaming candidate failed its exact HTTP500 assertion under an
  unrelated 120 ms deadline (seed 58592). An unchanged isolated rerun passed.
  Only that new rejection test now uses 1000 ms; actual expiry cases keep 120 ms.
- Independent review reproduced an infinite H2 body-read owner wait. The owner
  wait is now finite, with its deterministic regression retained.
- Extended streaming exposed Generation capture cleanup after the original
  deadline plus one second. The repair gives confirmed transitioned streams a
  fresh finite cleanup allowance and preserves ordinary/acquisition deadlines.
- The first ordinary compatibility run found six exact worker-constructor
  accounting failures: the numeric H2 model omitted the new Exchange field and
  undercharged its initial map by 21 bytes. The model includes it; all original
  independently constructed complete-Exchange assertions remain unchanged and
  the fresh 265-case ordinary gate passes.
- The first #10 implementation invoked user initialization while constructing
  a child spec. Independent probes and two failing initialization regressions
  established the defect. One successful Sol repair uses the pure common budget
  helper; fresh default/non-default active drain and initialization tests pass.
- Early test fixtures had an HPAX tuple shape error, an incorrect assumption
  about WebSockAdapter's frame default, and a wrong resource snapshot owner.
  Their failed evidence remains preserved alongside the corrected fixtures.
- Parent environment attempts found missing pip, unavailable direct actionlint,
  and an unfetched optional H3 Phoenix dependency. No test was executed by the
  failed dependency attempt. The prepared environment and actual lint/test
  reruns pass. A temporary archive verifier initially expected the fixture's
  Apache license; actual source/package licenses are MIT, verified explicitly.

Specialist abnormal/disconnect/pressure/load suites retain their historical
statuses and remain assigned to their dedicated environment. Deployment,
production operations/data/certificates, Vault, public management and the disabled
release-artifact E2E workflow remain outside this acceptance.

## Publication and public verification

The qualified implementation was committed and pushed as
`044e1cd90ddf4cc1550df99411f2906209387f5f`. Hosted static/build and Ubuntu unit
gates passed. Foundation native HTTP exposed an incorrect new shutdown-test
premise: the documented single-service pending aggregate can win the caller
deadline race. Its failed result is preserved; a bounded real-H2 reproduction,
narrow test-contract correction, stronger instance-termination assertions,
independent review and fresh 46/0 issue gate are recorded in the
[repair evidence](evidence/internal-requests/hosted-h2-contract-repair.md).
Only two test files changed from the original 557-entry source manifest;
runtime and package payloads remain unchanged. The original qualification
fingerprint and evidence above retain their historical identity.

Required hosted workflows on the repaired final SHA, release dispatch,
tag/GitHub/Hex publication, public checksums/payloads, clean public-Hex consumers
and downloaded standalone execution remain pending. They must be recorded
after the exact committed SHA is validated and published.
