# Native-worker near-H peer diagnosis1

Status: DONE (direct read-only diagnosis). Source proposal accepted; implementation and fresh runtime validation NOT RUN.

Repository: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; baseline from parent receipt: `58307a7084298db309a93697b9102b2cc4c87eda`.

## Evidence and cause

`native-green3` executed91 tests: HTTP62/0, proxy29/1, exit2; joined/source-stable. An expected Nix dirty-tree warning exists; compiler warnings/skips/exclusions are absent. The failed near-H constructor test timed out waiting5000ms for peer normal join. The worker crashed at `serve_peer/3:1711` because a complete `HEAD /health` response send returned `{:error, :closed}`. This is an incomplete response, not an idle close; preserve the strict send and join assertions.

Production `reconcile_unanchored` cancels live probes when the final preparation/baseline anchor is released. The sample preparation is released immediately after measurement, and final store shutdown releases the real groups' baselines. Either retirement can race the fixture's health response. The log establishes the full-head/send failure but does not identify which group's cancellation initiated it.

## Bounded recommendation

Configure supported public owner `limits.probe_bytes=1` at fixture creation for THIS no-dispatch near-H manifest constructor test only. Keep default native/healthy fixtures unchanged. `Options.owner/1` accepts positive integer1; `max_probes=0` is invalid. `HTTPFetchClient.reservation/3` has fixed base `8 * (100*8192 + 18437 + 65536) = 7,225,384`, plus positive chunk/ETF terms. H1 probe admission checks `state.probe_bytes + reserve <= state.limits.probe_bytes` before starting the real Probe worker. Therefore budget1 deterministically prevents unrelated health network activity without changing production or response handling.

Retain real public G7/T8/group and transport preparation, exact near-H manifest, singleton above-Q and source bound, checked preflight rejection, exact original correlation/arguments, real cancellation, pins and all cleanup/join assertions. Corroborate configured limit/reservation and public probes0/probe_bytes0; audit peer health requests/accepted connections without allowing response-send failures. Groups-only process tracing cannot prove no supervisor-owned spawn; use the actual supervisor/peer when tracing. An all-initial-health-responses barrier is possible but costly across64 groups and up to32 members, and must cover the sample before its release.

## Scope and verification

Only the two assigned `/tmp` reports were written. All repository/evidence files remained read-only. Commands only read source/logs, parsed JSON, hashed files and evaluated arithmetic; no live tests, builds, formatters, Git, network or browser commands ran. All own commands finished synchronously, with no background process.

Counters preserved from parent: group35/root40; stage5 failed GREENs; Astra2/2 exhausted; no repair round performed in this diagnosis. No new product decision is required. Parent owns implementation, independent review and fresh required runtime gates. Source hashes, receipt/log hashes and verification limits are recorded in the JSON report.
