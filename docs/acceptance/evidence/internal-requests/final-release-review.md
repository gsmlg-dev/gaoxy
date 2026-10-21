# Independent final release source and documentation review

Reviewer: Sol `tls_client_cert`. Assignment: read-only review of the integrated
0.9.0 source, all seven eligible requests, public documentation, package metadata
and CI filenames. Only this review document is written by this assignment.
Checkout: `/home/gao/Workspace/gsmlg-opt/gaoxy`, `main`, baseline
`32933790457bcfa3533e40dc2ae4d51ad91aa86d`, integrated uncommitted candidate.

**Verdict: PASS for source/documentation/CI consistency. No unresolved source
findings.** This verdict does not mark the parent acceptance draft complete or
certify publication, downloaded artifacts or downstream product acceptance.
No additional tests were run for this final read-only assignment.

## Request coverage

| Requests | Reviewed result |
|---|---|
| #3/#7 | Explicit per-route or listener `stream_timeout` for H1/H2 streaming responses; body-EOF transition; ordinary request, header, upload and I/O protections retained; selected H2 stream isolation; public poll/cancel path; finite drain and checked Generation cleanup; explicit H3 rejection |
| #5 | Verified optional/required OTP TLS client certificates; strict configuration; listener/Phoenix propagation to real peer data; forwarded headers cannot create TLS identity; H3 client-certificate support remains outside this interface |
| #6/#9 | Omitted message ceiling follows supported configured frame ceiling; direct explicit message override and service clamp remain; actual LiveView form input, escaped output, exact test-store bytes, reload/rejoin and fragmented/oversize cases |
| #8 | Only Phoenix-owned log/code_reloader keys added to application-policy allowlist; wire validation remains strict |
| #10 | Pure shared Config budget calculation from validated limits, reused by core and both HTTP wrappers; no endpoint initialization during child-spec construction; original startup and restart semantics; default/nondefault supervised HTTP cleanup |

Earlier independent issue reviews are preserved as `issue-3-review.md`,
`issue-5-review.md`, `issue-6-review.md`, and `issue-8-9-review.md` beside this file.
The initial #10 review correctly found premature endpoint initialization; the
pure helper and counting/raising regressions resolve that source defect. The
new Exchange `stream_timeout` field is now included in the numeric-only H2
worker constructor accounting, matching the actual struct without weakening
its existing constructor assertions. Its seven-test ordinary gate remains in
`scripts/check-repairs.py`.

## CI coverage and package identity

The same eleven root files appear in unit, Foundation and release issue gates:

- `apps/gaoxy/test/client_certificate_config_test.exs`
- `apps/gaoxy_http/test/phoenix_client_certificate_config_test.exs`
- `apps/gaoxy_http/test/websocket_configured_limits_test.exs`
- `apps/gaoxy_http/test/websocket_application_options_test.exs`
- `apps/gaoxy_http/test/stream_lifetime_test.exs`
- `apps/gaoxy_http/test/stream_lifetime_h2_test.exs`
- `apps/gaoxy_http/test/stream_lifetime_contract_test.exs`
- `apps/gaoxy_http/test/stream_lifetime_generation_test.exs`
- `apps/gaoxy_http3/test/stream_lifetime_boundary_test.exs`
- `apps/gaoxy_http/test/supervised_shutdown_budget_test.exs`
- `apps/gaoxy_http3/test/supervised_shutdown_budget_test.exs`

All paths exist. Release explicitly runs these under `MIX_ENV=test` despite its
production default. Pinned independent H2 peers are installed first. The
nonempty-test wrapper also enables warnings-as-errors. Foundation runs the
complete Phoenix example suite; release names these four example files:

- `test/client_certificate_test.exs`
- `test/websocket_configured_limits_test.exs`
- `test/stream_lifetime_test.exs`
- `test/websocket_phoenix_compatibility_test.exs`

All four paths exist under `examples/phoenix_native`. Existing ordinary,
isolated-consumer, unified browser/peer and standalone smoke gates remain.
The disabled specialist load stage and release-artifact E2E boundary are retained.

Root plus all five own application manifests read `0.9.0`. The five published
package names are `gaoxy_websock_adapter`, `gaoxy`, `gaoxy_http`, `gaoxy_http3`
and `gaoxy_proxy`; `gaoxy_server` belongs to the standalone distribution. The
vendored upstream application remains `websock_adapter` version `0.6.0`;
staging supplies coordinated distribution metadata without modifying provenance.
Dependency locks, upstream vendor manifest and SOURCE metadata have no diff.
Current README installation examples and release notes use the coordinated
0.9.0 cohort and correctly distinguish application authorization, consumer
persistence, H3 and streaming capability boundaries.

## Evidence and remaining release gates

Read existing final root log: 4 core + 39 HTTP + 3 H3 = 46 tests, zero failures.
Read final Phoenix log: 17 tests, zero failures. Read ordinary final log:
`REPAIR_PASS 265 executed, 0 failures, 0 excluded, 0 skipped`. Read package build
log and receipt: all five archives at 0.9.0, exact source payload/staged-file
checks marked PASS. These are reviewed existing records, not tests rerun here.
The actionlint record preserves the initially unavailable direct binary and
subsequent Nix invocation; its actual final exit is for the parent gate record.

The parent acceptance draft still marks final qualification/publication pending.
Before committing it, replace interim counts and IN PROGRESS entries with final
actual receipts, retain failed setup/initialization evidence separately, and
keep commit/push/hosted checks/publication/public-Hex/standalone/consumer states
truthful. Source review gives no authority to infer any unexecuted gate passed.
No deployment, production data/certificates, Vault, public management or
specialist pressure/load acceptance is added.

All reviewer commands finished; no production/test/workflow edits or publication
were performed in this assignment. #10 cumulative Sol repair rounds: 1
(successful); Astra rounds: 0. No new architectural or product decision needed.
