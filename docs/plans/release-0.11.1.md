# Gaoxy 0.11.1 release plan

Date: 2026-10-22, Asia/Shanghai. User request: fix eligible open GitHub
`internal request` issues, commit directly on `main`, and publish the next patch.
Baseline: `6201d4270a5805993359868973f0fb019c1c1fe0`, clean and equal to remote
`main`; latest public release `v0.11.0`. No worktree or PR is needed.

1. Fix [#11](https://github.com/gsmlg-dev/gaoxy/issues/11): preserve inclusive
   H1 poll-buffer capacity, bounded excess-input detection, and peer closure.
   Verify public Plug/TCP keep-alive flows with delayed and coalesced pipeline
   input, plus resource/deadline and existing H2 compatibility. Preserve red
   evidence. See the issue-specific design and implementation plan.
2. Obtain independent specification/code review and resolve actionable findings.
   Run fresh scoped tests, canonical formatting, strict compilation, package
   regressions and the ordinary repair gate. Add the new regression suite to
   that mandatory gate without removing existing cases.
3. Advance root/application manifests and current install examples to `0.11.1`.
   Preserve dependency pins and vendored upstream version/provenance. Stage and
   validate packages through the existing publication mechanism.
4. Commit qualified changes on `main` with `fixes #11`, push, and verify exact
   remote source identity and all ten prerequisite hosted jobs.
5. Dispatch `release.yml` with `version=0.11.1`, `git_ref=main` and the full
   `expected_sha`. Do not precreate the tag. Require its existing source,
   package, browser, ordinary and standalone checks before publication.
6. Read back the tag, GitHub release/assets/checksums and all six Hex package
   versions/bytes. Run fresh public-package consumers and the issue-specific
   public-package regression. Verify #11's commit-driven closure and record the
   published compatible version on the issue.

Task routing: `issue11` implementation uses Sol; independent review uses a
separate Sol contributor. Initial Sol/Astra repair counters are zero; preserve
cumulative counters and failed attempts. Parent owns integration/publication.

Deployment, operational data/certificates, Vault, public management, specialist
pressure/load/disconnect qualification and disabled release-artifact E2E remain
outside scope. Local, hosted and public checks retain distinct statuses.
