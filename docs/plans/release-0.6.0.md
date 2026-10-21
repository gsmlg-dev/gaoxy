# Gaoxy 0.6.0 release plan

Date: 2026-10-21, Asia/Shanghai. The user requests the next minor release after
`0.5.5`, authorizing commit, push, tag, GitHub Release and all five Hex packages.
Develop directly on `main`, without creating a worktree. Base:
`ec1fead80884804de9ab662e311ebb9c1cfdaf60`.

1. Synchronize the root and five own application versions to `0.6.0`, update
   current installation guides and write release notes. Preserve all three
   resolved locks, runtime source, vendored upstream provenance and historical
   evidence. The adapter distribution's published version comes from staging.
2. Capture source hashes before verification. Run the nine existing packaging
   regressions, build and inspect all five actual `0.6.0` archives, canonical
   formatting and strict production compilation against the locked real Hex
   dependencies. Complete independent specification/code/artifact review.
3. Commit and push the qualified versioned source; verify remote identity. Await
   Static checks/build, Unit tests and Foundation integration workflows on that
   exact commit. A failing required gate blocks publication.
4. Dispatch the existing `release.yml` with `version=0.6.0`, `git_ref=main` and
   the full `expected_sha`. The workflow runs the exact ordinary 160-case gate,
   production assembly and sequential core/H1-H2/H3 release smokes, builds the
   standalone application and all five packages, publishes packages in dependency
   order and compares public bytes before it creates the tag and GitHub Release.
   Do not precreate the tag or use a root `mix hex.publish`.
5. Download all released assets and actual public Hex packages. Independently
   verify tag/source identity, checksums, payloads and exact dependency metadata,
   including `abyss == 0.9.0` and the `0.21.14` cohort. Run clean public-Hex
   consumers with existing assertions, then record review and publication
   closeout in [acceptance](../acceptance/release-0.6.0.md).

The Hex API key remains in Actions. Preserve hosted failures or no-starts with
their actual status; do not change account spending, secrets or repository
settings. Specialist disconnect/blocked-upload/pressure/load suites, production
operations, deployment, Vault, public management and disabled release-artifact
E2E remain outside this release. Hosted Ubuntu qualification adds no new Debian,
Alpine or architecture portability claim.
