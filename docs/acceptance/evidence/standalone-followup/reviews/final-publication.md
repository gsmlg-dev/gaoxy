# Independent final hosted CI and publication audit

Status: PASS. No actionable inconsistency found within this audit scope.
Task: review_compiler_ci / final-publication; direct independent review.
Source: `d5e0a6c50fdaa5a3cfbff548069005029c41960e`, version `0.5.4`.
Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/standalone-ci-followup`,
branch `codex/standalone-ci-followup`. HEAD matched that source; tracked worktree
was clean before review. Historical task baseline:
`581bea7d27b9d86c7dd0e63a1d49fcbca3adc3dd`.
All evidence paths below are relative to `.audit/standalone-followup/`.

## Hosted CI

Independently checked `hosted-candidate2/final/receipt.json`, all completed
run/job/step records and each raw log hash. Three runs on the reviewed SHA contain
ten successful jobs total:

| Run | Verified evidence |
| --- | --- |
| `39473581131` Static checks and build | Formatter/counter regressions; separate successful `mix compile --warnings-as-errors` jobs on Linux Elixir 1.18.5 / OTP 28.5 and macOS Elixir 1.20.1 / OTP 29.0.2. Raw logs confirm runtimes. |
| `39473581106` Unit tests | Both profiles execute 141 tests. Independently summed all 13 suite summaries per job: Linux uses `tests, failures`, macOS uses `Result: N passed`. Both have matching `REPAIR_PASS 141 executed, 0 failures, 0 excluded, 0 skipped`. |
| `39473581344` Foundation integration tests | All five jobs successful: isolated-network, both portable profiles, optional-quic and native_http. Four optional QUIC tests; native_http records `REPAIR_PASS 160 executed, 0 failures, 0 excluded, 0 skipped`. Required integration/consumer/release/Phoenix/browser/peer steps succeeded. |

Unit success does not substitute for strict compilation. Portable/network jobs
retain scoped selection/exclusion output; the exact repair counts above do not
imply that every foundation test command had no exclusions.

Receipt SHA256:
`e06add648e27dcf7556dface63568e17179b5f30bfa9b43f6d1ba3bb46583cf4`.
Raw log hashes, in the table's order:

- `e422d27cb50cc3436fa0248303ddab1f45c9796674ac10a1d5f8275202be1069`
- `28d39cbf107fb843f031dc2bcaf92860d87ab2fba13cf77768926f5fdb8dda01`
- `13a4d89ac83ff5ba90f830bad2ea6480190bc5f8a0be46e33c1b23afc26ae463`

## Publication

Release run `39476108334`, job `118812377535`, completed successfully on the
reviewed source. Captured API records and raw log confirm successful executed
steps for exact checkout/SemVer/all-app-version guards, remote-main/clean-diff
recheck before upload, 160 ordinary repair tests with zero failures/exclusions/
skips, strict compilation, package regressions, release construction, core/gateway/
H3 smoke commands, package construction, artifact upload, all five Hex publishes
and public-byte comparisons, tag creation and GitHub release creation. No required
step was skipped. Workflow guard logic was compared with the executed log.

The log records portable three-transport smoke PASS, dedicated-H1 gateway smoke
PASS, and H3 `PASS` with three checks. The captured `v0.5.4` tag points directly
to the reviewed commit. The release is published, stable and not a draft:
<https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.5.4>.

Independently recomputed all seven downloaded asset sizes/digests, matching the API
and receipt; all six unique `SHA256SUMS` entries cover exactly the application
archive and five package archives.

| Asset | SHA256 |
| --- | --- |
| `gaoxy-0.5.4-linux-x86_64.tar.gz` | `496d9621b03c826af4908aa9437b72d608d4896f37424850461afe501e39a031` |
| `gaoxy-0.5.4.tar` | `21199df325b3932a1ddcbe63586933311c01122fc79ab64fe7ec934b0fe04eda` |
| `gaoxy_http-0.5.4.tar` | `adf33657e0a56efef289f8d165015c13637a083afa25aeceb55f55918fe4e456` |
| `gaoxy_http3-0.5.4.tar` | `742bb70408ffc203b1c87b27704f5e4379c1e1652a2b167850444515e32aa449` |
| `gaoxy_proxy-0.5.4.tar` | `fe89bea3f33edf5767fdebfe9df62f9e411253f8e0368c1dd1b1916c155fb91c` |
| `gaoxy_websock_adapter-0.5.4.tar` | `8ae7ee1bb29a243db90ee7604f44b793af24d4d0803a3b2232e986fab99d43f7` |
| `SHA256SUMS` | `14e03ee11786626ffd05c69b439f691e8bf1d23adda90f8311816dfe6ad7c289` |

All 15 captured read/download outputs match their recorded hashes and successful
command exits/HTTP 200 statuses. Each Hex release has the expected version,
non-retirement, checksum, app alias and dependency requirements.

## Qualified local package comparison

For all five packages, downloaded GitHub and public Hex archives are byte-identical.
**All five local raw tar archives differ from the published raw tar archives.**
Local raw archives are not claimed identical. Nested payload file sets, bytes and
permission modes match exactly between qualified and public packages. Independently
consulted/normalized actual archive metadata after verifying captured `.config`
bytes equal archive members: parsed metadata matches the qualified packages and
receipt. Every payload file also matches qualified staged source bytes.

| Package | Payload files verified |
| --- | ---: |
| `gaoxy_websock_adapter` (app `websock_adapter`) | 13 |
| `gaoxy` | 23 |
| `gaoxy_http` | 41 |
| `gaoxy_http3` | 12 |
| `gaoxy_proxy` | 39 |

Comparison source is `final-candidate2/build`. Its receipt source/version/PASS
and hash match the publication linkage:
`637e6b68fe6e0e8d6270c9396ebb0439b82eac5c4e1d62346e9fae14a3308023`.
Previously audited aggregate qualification receipt hash remains
`d6c8cf32ba14b2e0d7db4843a3566ffb10ff6596ced20950e6bade83e3f8d10a`.
This audit compares publication artifacts against qualified local artifacts; it
does not rerun their builds/tests.

## Integrity and limits

Publication evidence: `publication/final-d5e0a6c5/`.
Publication review receipt hash:
`450d1f142b66f27e35af7a230c0a65601aa4a5a23f3409f062d3a23fda51b4af`.
`publication/release-execution.json` hash:
`f749279feb2b5810441db737d225a1e462e92e9c65d101098ab31ae6624a6efb`.
Its linked raw log hash:
`bdcb15e5d9462ee94d8b7d09960ab18cee37510b617b29a8340c37c56f1962ab`
identifies the log, not the JSON.

Both successful absence snapshots remain intact:
`publication/preflight.json` hash
`eb39823a549666b23a40453645b46fad3c99843bee2865b0975864dfafeb6879`,
and `publication/preflight-before-dispatch.json` hash
`6824dafd6d01124d553b1245fa53da5f31aea64e9cb1fa6970901a04349934af`.
Each records the exact remote main, five Hex 404s and GitHub release 404 before
publication. Historical `reviews/recovery.md` REQUEST_CHANGES, its resolved
followup, the old macOS baseline FAIL and candidate macOS unit failure metadata/log
remain preserved. This PASS does not rewrite their outcomes.

Fresh review verification used read-only Python assertions/hashes/archive checks,
Elixir `:file.consult`, and source/workflow/log inspection. An initial review-only
counter parser expected Linux-style summaries on macOS and exited 1 before any
report write; inspection identified macOS `Result: N passed` output, and corrected
parsing verified both totals with exit 0. This was an audit parser assumption,
not a product/test failure. All reviewer commands have now finished safely.

No builds/tests, new downloads, publication, implementation edits or consumer
inspection were performed. The only reviewer write is this assigned report.
Public-consumer verification remains **PENDING / separate audit**; actively written
consumer evidence was untouched. No specialist pressure/disconnect/soak,
deployment, production, certificate, Vault, public-management or disabled
release-artifact E2E acceptance is implied.

Reviewer adds zero Sol/Astra repair rounds. Received prior counters: A Sol 2 /
Astra 0; B Sol 2 / Astra 0. New fixture author's counter was not supplied.
DONE for this audit; no decision needed. Remaining public-consumer acceptance
belongs to the parent and its separately assigned audit.
