# gaoxy-group-generation-browser-stop-spec1

**DONE — PASS (bounded SPEC only).** No actionable findings. Independent CODE and new syntax/browser/full/final gates remain pending.

Direct read-only assignment. /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation; codex/m3-h1-resource-foundation; baseline 8131af39a846c292a022ccbfd32c53376cd57887. No Git operation. Proposal SHA256: 679e0e18ef48467a93a1cf8884fdf97712fbaa13447258c07113dd6138e9a8d7.

## Exact reviewed delta and ownership

Host4 adds only `:ok = GenServer.stop(s.groups, :normal, 5_000)` immediately after successful existing Gaoxy.stop and before unchanged owner/instance join_roles. Runner4 only changes HOST from host3 to host4. No production/test/cohort/collector source changes.

This matches actual ownership: fixture directly starts group owner; owner only monitors instance and returns noreply/draining on instance DOWN, with no automatic normal-stop contract. Existing scoped embedding explicitly stops this independent owner after Gaoxy.stop. Original allzero group/T controls, custodian joins, hooks/trace removal precede the new call. It is finite, unconditional and exactnormal; stop failure remains a failure.

Original groups_monitor/PID/:normal stays registered and required by unchanged join_tracked/mark_joined/loop. No replacement monitor, flush, synthetic DOWN, broadened reason or PID-dead-only substitute. Existing finite5000ms exact join,rebind and loaded before/after identity remain intact.

## Preserved verification contract and source mapping

One-line/path diffs preserve native95/actual P/N/W/B,512MiB Gate/source/baseline/completion/cleanup/failednil,full nativecohort/observer/peer-closed evidence. Actor/CDP exact navigation200/DOM/visible/screenshots/Chromegraceful,physical peer counts/forced0,all deadlines/caps and four H1/H2×h2c/TLS rows/eight images remain byte-identical. No whole-fixture success inferred from preservation.

Runner HOST/inventory now binds host4 and runner4. Host loaded-source identity dynamically binds __ENV__.file,with unchanged source/beam/module/cohort checks. Final inventory4 maps browser-green4/browser-command-green4 and distinct browser-final1/browser-command-final1 to runner4; format uses host4/cohort1,active Python/JS syntax extracts runner4 BROWSER. No stale host3/runner3 reference remains in inventory4.

Required order remains bounded SPEC→CODE→active syntax→fresh browsergreen4 four rows/eight root views→full-stage SPEC/CODE→final inventory4 gates→document/index/blob review/localcommit. Reviewer ran no runtime or syntax checks.

## Historical evidence limits

Bound initial4 classification records93tests/0failures/exit0/warnings0/skips0/exclusions0,stable HTTPdd04/teste805; scoped initial acceptance only. Browsergreen3 remains FAIL: first row's two200/DOM/completion/requestclean/nativecohort/Gate0 observations and Chrome0 are partial; host1/fourpeerforcedTERM and only2root-viewedimages do not pass full row/matrix. Actual final group PID liveness/unmatched DOWN reason remains UNKNOWN. Earlier green2 cause/browserdiag1 rejected field remain UNKNOWN.

## Complete before/after hashes

21 declared inputs plus proposal matched before/after (22). Two supplemental archived diagnosis files were created after manifest freeze; separately hashed/rechecked,not claimed as manifest entries (24 pairs total).

| Input | Before SHA256 | After SHA256 |
| --- | --- | --- |
| apps/gaoxy/lib/gaoxy.ex | f996f20926086b80f79aa66c82253164430616ffac15118f87bd8a88bc00fa5e | f996f20926086b80f79aa66c82253164430616ffac15118f87bd8a88bc00fa5e |
| apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex | dd04efd4b255f7b03a4f68d23ac6cabcca3b9be0fb1a9a431cd24df960b11c31 | dd04efd4b255f7b03a4f68d23ac6cabcca3b9be0fb1a9a431cd24df960b11c31 |
| apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex | e98dea5d0769258838c0c53b397da4740d0b6f303c02d1c13cf712cb32a645c9 | e98dea5d0769258838c0c53b397da4740d0b6f303c02d1c13cf712cb32a645c9 |
| apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex | 877bb6e4c891ee3f8c93a425a67b10f390137fcead2eeb52ccd9b78d9b2b1f51 | 877bb6e4c891ee3f8c93a425a67b10f390137fcead2eeb52ccd9b78d9b2b1f51 |
| apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs | e80503bb68521d29fa3423a3c93c9059598d0602eec1858cd1c751aba759a2fa | e80503bb68521d29fa3423a3c93c9059598d0602eec1858cd1c751aba759a2fa |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-command-collector3.py | 008687f0d21470e8fcb4fcf6cca3f46b86b9e3cec394ead06a14106899f9a0c5 | 008687f0d21470e8fcb4fcf6cca3f46b86b9e3cec394ead06a14106899f9a0c5 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-command-green3.json | 153e12e0026a984bd2ce6ac19f5b0355233ccf6287e69dcfa8afd5f6d0770358 | 153e12e0026a984bd2ce6ac19f5b0355233ccf6287e69dcfa8afd5f6d0770358 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-green3-classification.json | ddfd85df5909c9eacde7851f6e00ab3ba2d12cd1d97dc13d1303f731d6c07b2e | ddfd85df5909c9eacde7851f6e00ab3ba2d12cd1d97dc13d1303f731d6c07b2e |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-green3/h2-h2c/host.log | eab74ec8e5af3b9c2fe8c44115bc4101d7abd396569ddc4e9f07c01df5a23ed3 | eab74ec8e5af3b9c2fe8c44115bc4101d7abd396569ddc4e9f07c01df5a23ed3 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-green3/qualification.json | 1bf70fe99997b439f129a43cfe8f80f1f2ff5da2e0726e5fa187c974e1596204 | 1bf70fe99997b439f129a43cfe8f80f1f2ff5da2e0726e5fa187c974e1596204 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-stop-design1.md | a65deeca1684ea7c683b73f67db357f2a43bfbc23e704504e8a83c51cb1b45f1 | a65deeca1684ea7c683b73f67db357f2a43bfbc23e704504e8a83c51cb1b45f1 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-stop-owner-diagnosis1.json | 5185044a898cec9e686116c2b492af86bc47ba029050359aaff0015a4635deb9 | 5185044a898cec9e686116c2b492af86bc47ba029050359aaff0015a4635deb9 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-stop-owner-diagnosis1.md | ca3cfde00efeaee7cfc86b423c6b130f084ac9c881a6b8d590782292ced71a12 | ca3cfde00efeaee7cfc86b423c6b130f084ac9c881a6b8d590782292ced71a12 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-stop-proposal1.json | 679e0e18ef48467a93a1cf8884fdf97712fbaa13447258c07113dd6138e9a8d7 | 679e0e18ef48467a93a1cf8884fdf97712fbaa13447258c07113dd6138e9a8d7 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/command-collector3.py | aeff8b310f5f0a296ed79d915d9f8beb4f57b2e2d782a857de85779c298d27ee | aeff8b310f5f0a296ed79d915d9f8beb4f57b2e2d782a857de85779c298d27ee |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/final-gate-command-inventory4.json | 37fa14a626d239ebafc6cf2613983e8fbb48d06380fc55044890eb5e1efc6cb6 | 37fa14a626d239ebafc6cf2613983e8fbb48d06380fc55044890eb5e1efc6cb6 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/group-generation-browser-cohort1.exs | 7b758fd2d105e4a9c06dafbad4b2e3687b29d3d0f5abfd4f7f630f887dcb5078 | 7b758fd2d105e4a9c06dafbad4b2e3687b29d3d0f5abfd4f7f630f887dcb5078 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/group-generation-browser-host3.exs | a3dd5731a954f509ed724fa77910eb9ab377466f0c03d7434cf3444997eb51a4 | a3dd5731a954f509ed724fa77910eb9ab377466f0c03d7434cf3444997eb51a4 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/group-generation-browser-host4.exs | cf96df4fc521afbcd6308fb5e045fadbb32850bce8f36c464e91593bb45b93a6 | cf96df4fc521afbcd6308fb5e045fadbb32850bce8f36c464e91593bb45b93a6 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/group-generation-browser-runner3.py | 7739650e7b07f0b25448bf32a5f2c36e875f4efbd136645747429d94a3038757 | 7739650e7b07f0b25448bf32a5f2c36e875f4efbd136645747429d94a3038757 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/group-generation-browser-runner4.py | ce0f8c353fa1630b627afae44e6bdd6be67a9e835c2bc7b3b616707a7f199427 | ce0f8c353fa1630b627afae44e6bdd6be67a9e835c2bc7b3b616707a7f199427 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/scoped-initial4-classification.json | 3f8333f79d27e42fdfb1c4486c842140d41b9610b531344e1725e3e7334e21ea | 3f8333f79d27e42fdfb1c4486c842140d41b9610b531344e1725e3e7334e21ea |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-stop-diagnosis1.json | 00021fe39f1468ca2f929d56d428232312878b9ff8d3c38fbadca9c13fbf9d0b | 00021fe39f1468ca2f929d56d428232312878b9ff8d3c38fbadca9c13fbf9d0b |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-stop-diagnosis1.md | b04d5490271189dfc197d38cc57a22c994f2c358bda1542cbf68dca8073b8b40 | b04d5490271189dfc197d38cc57a22c994f2c358bda1542cbf68dca8073b8b40 |

## Counters and shutdown

Received: group52/root107/orchestration36/stagefailed7/production2/fixture10/stageorchestration29/invalidRED1/validRED1/Astra2of2. Reviewer repair rounds0; no reset.

Only assigned /tmp MD/JSON written. Scoped json/hashlib/difflib/sed/rg commands all exited0 and ended synchronously. No runtime/build/tests/browser/Git/network/agents/repository/evidence writes or live commands/processes. No full-stage/Task5/M3/publication/deployment acceptance; no new product decision needed.
