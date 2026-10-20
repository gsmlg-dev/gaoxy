# Independent final integration/source-readiness review

Task: review_compiler_ci / final-source. Direct read-only review. Status: DONE, PASS for final committed integration and source readiness; no actionable finding. This is not publication approval or a claim that pending qualification passed.

Repository/worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/standalone-ci-followup`. Reviewed source: `ba89895887ac8509a091c1444b1699f6b7cd5631`; original task baseline `581bea7d27b9d86c7dd0e63a1d49fcbca3adc3dd`. HEAD was verified before/after, with no staged, unstaged or untracked source changes. Source archive SHA256: `aa310710a9c436a98dd55be82bca5c4324771d6c3e936542f2d2942a03c408b3`.

## Specification and integration review

Recomputed all20 B compiler-import source hashes: all match the independently reviewed snapshot. Recomputed the9 A/gate/design/README hashes from initial recovery.md with the two approved recovery-followup.md replacements: all match. The generation fallback and extended recovery test match the approved expired-activation repair; no other A source changed. C/workflow, repair/test wrapper, unit/build/release matrix, QUIC fixture/peer/requirements and lock hashes match the prior B/C review.

The manifest preserves every baseline file/count and adds only the2 recovery cases. Unit141 + ordinary protocol19 =160. Existing R1-R4 production repairs remain, with original test additions preserved. Among all preexisting application test files, only plug_body_network_test.exs (one line) and protocol_test.exs (five lines) differ, each solely by the reviewed external-size pin. All assertions, test bodies, certificate checks and deadlines remain unchanged. The new standalone recovery file matches the independently approved hash. No dependency/matrix changes, assertion weakening, quiet exclusions or protocol work were found.

The last commit changes exactly six version declarations, each0.5.3 to0.5.4: root plus five own umbrella apps. There is no other change to those project manifests. The unchanged stage-hex-packages.exs reads the committed root version, validates own package versions, pins own interpackage dependencies to it and assigns that version to the staged gaoxy_websock_adapter distribution while preserving the vendor's upstream source version. It stages all5 public packages without publishing. Existing supported dependency conversions and source/provenance metadata are unchanged. The unchanged source-bound release workflow validates the full expected_sha, committed own-app versions and absent tag, reruns all160 repairs before publication, builds packages, and rechecks checkout/remote branch before uploads. Publication still requires current tag/package availability and successful final gates.

## Documents and evidence

Read the committed acceptance, release notes, task plan, initial evidence README, B notes/summary, hosted/QUIC receipts and both lifecycle reviews. The initial REQUEST_CHANGES recovery.md export remains byte-identical, SHA256 `dd98788cd4cfadfa99601d1e0c891c9208bba21c78cb33e560d75b2a32ed3df0`; recovery-followup.md resolves its actual P2 and remains separate. All4 review exports match their original local review bytes. Pre-fix runtime failures, initial monitor race, expired-activation red, original peer :enoent and hosted strict failure retain their actual failure statuses. The earlier intermediate log losses remain explicitly NOT_RETAINED_OVERWRITTEN. The prior October20 acceptance document is unchanged.

Recomputed exported hosted-baseline and QUIC receipt file hashes: every digest matches. Recomputed3 precommit-integrated raw-log hashes: all match. Their source identities/diffs distinguish earlier uncommitted evidence from final committed qualification. The new acceptance record accurately describes approved functionality and ordinary scope and leaves final-source/exact-hosted/publication results pending at its commit. As the current local phases complete, the parent will append their final evidence; this review does not rewrite that historical checkpoint. The release note adds no claim of deployment, production or excluded specialist acceptance.

All specialist/disconnect/pressure/soak exclusions, dismissed issue97, no new H2/H3 WebSocket bridging, and no deployment/production certificate/public-management/Vault/release-artifactE2E permissions remain intact.

## Completed final-source evidence inspected

Parent local qualification, not reviewer reruns: completed final/checks and final/standalone receipts both identify the exact reviewed SHA and0.5.4. Recomputed every listed log hash and confirmed all check exits0.

- checks: actual runtime Elixir1.18.5 / OTP28 / ERTS16.4.0.5; strict forced warnings-as-errors compile, canonical format and actionlint pass. Wrapper/gate/smoke/package helper tests execute8/6/5/8 cases. Repair manifest executes160 with0 failures/exclusions/skips. Ordinary portable tests execute8/0. The separate fragmented-TCP selector reports8 total,7 intentionally excluded,1 executed/0 failures; it is not counted as8 executed and is distinct from the exact-count manifest.
- standalone: existing generation/configuration/activation/rollback/lifecycle plus recovery files execute87 HTTP +33 server =120 tests,0 failures. Source remains unchanged.

Other phase status is only a point-in-time snapshot below; this reviewer did not wait for completion or read actively written logs. Pending exact macOS Elixir1.20.1/OTP29.0.2 strict+unit, other local phases, repaired hosted optional-QUIC job, integration/push and publication/public-consumer verification remain separate parent-owned gates. The fresh failed published-source macOS baseline is not substituted for successful repaired-source qualification.

## Verification limits and command shutdown

Fresh reviewer checks: read-only Git/source/diff inspection, hash/AST/version/test-change checks, log digest validation and source archive hashing. `git diff --check 581bea7d HEAD` exits2 solely on untouched raw hosted-log trailing whitespace and literal diff-context spaces in exported repair.patch. These evidence bytes are intentionally preserved. The same check excluding archived evidence exits0 for authored source/docs. No build, dependency mutation, test rerun, publication or tracked edit was performed. All reviewer commands finished; process inspection found no outstanding reviewer archive/diff/Python command. Only this new review artifact was created.

Cumulative received counters remain A Sol2/Astra0 and B Sol2/Astra0; reviewer adds0 repair rounds. astra_gate: not applicable. Decisions needed: none for reviewed integration. Material remaining limitation: release completion still depends on pending final qualification and actual publication verification.

## Phase status snapshot

Snapshot UTC: 2026-10-20T17:52:38.921039+00:00

```json
{
  "checks": {
    "status": "PASS",
    "source_sha": "ba89895887ac8509a091c1444b1699f6b7cd5631",
    "version": "0.5.4"
  },
  "standalone": {
    "status": "PASS",
    "source_sha": "ba89895887ac8509a091c1444b1699f6b7cd5631",
    "version": "0.5.4"
  },
  "quic": {
    "status": "RUNNING",
    "source_sha": "ba89895887ac8509a091c1444b1699f6b7cd5631",
    "version": "0.5.4"
  },
  "core": {
    "status": "NOT_PRESENT"
  },
  "http": {
    "status": "NOT_PRESENT"
  },
  "phoenix": {
    "status": "NOT_PRESENT"
  },
  "build": {
    "status": "NOT_PRESENT"
  }
}
```

## Final source hashes

- `mix.exs`: `689856ee6017d6075b34e66e8decf3a7b05ebccd39516c6e4c75f0b7ae096131`
- `apps/gaoxy/mix.exs`: `43549309046bfdb69e64d1a555d2d8e1008fa05aa2d2361d3503111c97bb1c27`
- `apps/gaoxy_http/mix.exs`: `64aa866016de7c6a11a8de71955f5dd243105b51c3bed48eb50e9c8571a2ba1b`
- `apps/gaoxy_http3/mix.exs`: `fb8f6cc249efc30b870a15b0020247c66de572112200ca85c57e9fef79627d26`
- `apps/gaoxy_proxy/mix.exs`: `60bb3cc840c395b2fd8b1c31cf97b250b312a68bb63870d2ce7bf835958317ab`
- `apps/gaoxy_server/mix.exs`: `a7a7de1292de6616bb4c2f6dcbe2b6fb76209c342cdae33dde1a99038092382f`
- `scripts/check-repairs.py`: `072f3d24312c67fdbaeb8d16366312610af41e150ea429fd205be9890b5c55c9`
- `scripts/stage-hex-packages.exs`: `7ca867a836be6ba16f7dfca94cb00a141a9feba5888f3271fed8f792097eecb2`
- `.github/workflows/release.yml`: `5944fbbe54dadb0bb21d18468ff9b6e454276d7841b8bc65bcd7094e77c7ab0b`
- `docs/acceptance/standalone-ci-followup-2026-10-21.md`: `10d12d720102cfc4c05659e4e858ab96e01397dfcb2c4b00bf0fd30f2b4c8993`
- `docs/releases/0.5.4.md`: `88ac010d72fc42f6cf694368959ea0f1c034f9de27be95c47c540b910514b45f`
