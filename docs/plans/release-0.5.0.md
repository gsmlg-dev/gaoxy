# Gaoxy v0.5.0 Release Implementation Plan

> **For agentic workers:** Use `subagent-driven-development` task by task.
> Independent specification then code review precede execution and publication.
> The parent owns Git integration, serialized builds and publication.

**Goal:** publish the accepted Hell migration as GitHub v0.5.0 with a newly
qualified portable Linux x86_64 standalone archive.

**Architecture:** [ordinary portable design](../designs/release-0.5.0-portable.md).
Reuse versioned v0.4.0 recipes and add explicit Hell package/runtime checks.
Preserve accepted product scope and historical evidence.

**Tech Stack:** pinned Elixir 1.18.5 / OTP 28 Debian/glibc amd64 Docker builder,
Hell 0.1.2, existing locked HTTP/QUIC dependencies, Python peers, Git and GitHub CLI.

## Task 1 — isolate and prepare the source

Files: root `mix.exs`, five `apps/*/mix.exs`, this plan/design,
`docs/releases/0.5.0.md`, `docs/acceptance/release-0.5.0.md` and current
release/backend notices in README and protocol/capability/status documentation.

- [x] Inspect current main, origin and releases. Latest is v0.4.0; v0.5.0 is
  absent, main has the two local Hell commits and no remote-only commits.
- [x] Capture tracked/untracked and unrelated-file state plus the 429 verified
  functional hashes. Fetch main and create `.trees/release-0.5.0` on
  `codex/release-0.5.0`; keep other worktrees unchanged.
- [x] Change exactly six own version declarations from 0.4.0 to 0.5.0; preserve
  all lockfiles and dependencies. Document Hell provenance and release scope
  with artifact/publication verification explicitly pending.

## Task 2 — prepare and review the portable recipes

Files: eight new files under
`docs/acceptance/evidence/release-0.5.0/portable/recipe/` copied from v0.4.0.

- [x] Update copied version and owned-container/image names to 0.5.0/050.
  Retain source custody, pins, bounds, safe inventory and all existing assertions.
- [x] Add the exact accepted native ordinary batch from migration evidence to
  existing suites: 210 total executions, 144 excluded, zero failures/skips.
- [x] Add archive Hell 0.1.2/presence, Gaoxy dependency and old application
  absence checks, plus public packaged-release Hell startup/version checks.
  Bind Hell provenance in metadata and verify it during finalization/runtime.
- [x] Independently review specification and then code, resolve findings and
  record reviewed file hashes before executing any build.

## Task 3 — freeze and qualify exact committed source

- [x] Commit only task-owned files with a conventional `[skip ci]` message.
  Fast-forward local main and preserve its captured unrelated-file state.
- [x] Create unique `.audit/release-0.5.0/portable-<id>/context` and `artifacts`
  paths. Copy the eight recipes; archive the committed source with `git archive`.
  Write source identity with version, source SHA, archive/lock hashes and exact
  changed Elixir paths from `git diff --name-only v0.4.0 HEAD`.
- [x] Verify context/recipe/archive identity and execute these commands, storing
  the actual absolute arguments, environment, times, exits and logs:

```sh
docker buildx build --platform linux/amd64 --progress plain --target artifact \
  --output type=local,dest=ARTIFACTS CONTEXT
python3 CONTEXT/finalize.py ARTIFACTS
python3 CONTEXT/qualify_runtime.py RUN_DIRECTORY
```

  `CONTEXT=RUN_DIRECTORY/context` and `ARTIFACTS=RUN_DIRECTORY/artifacts` are
  resolved to the unique captured absolute execution paths before launch.
- [x] Require canonical/current changed-file formatting, strict compilation,
  210 ordinary executions with zero failures/skips, 144 exclusions, source
  custody, five own versions 0.5.0 and Hell 0.1.2 with the old application absent.
- [x] Require core/gateway/H3 smoke exchanges and packaged WebSocket 15/15 for
  H2/h2c/H3 in both builder and offline runtime, nonzero ELF linkage inspection,
  checksums, normal exit and owned-container removal/observed absence.
- [x] Independently review actual source/artifact/runtime receipts and final
  release notes. Freeze source until publication; repaired source requires
  fresh affected qualification. Keep failed attempts immutable and visible.

## Task 4 — publish and verify

- [x] Push main and verify its remote SHA equals the qualified source. Create
  an annotated v0.5.0 tag at that source, push and verify the peeled remote tag.
  Never overwrite an existing tag or dispatch the automatic release workflow.
- [x] Publish exactly the archive, build-info.json and SHA256SUMS with
  `gh release create v0.5.0 --verify-tag --title 'Gaoxy v0.5.0' --notes-file`
  using the independently reviewed release notes.
- [x] Fresh-download all three assets. Verify exact bytes/hashes, sums,
  source/version/Hell metadata and safe inventory, release flags and remote refs.
- [x] Independently review publication/download evidence. Archive exact evidence
  without keys/dependency checkouts or modifying previous records; update the
  current release notices, plan and acceptance to the actual results.
The separate documentation closeout requires independent review before a
`[skip ci]` commit. The parent then fast-forwards main, pushes and verifies
main/tag, functional-source custody, clean tracked state and preservation of
unrelated files. These final Git checks run after committing this reviewed
record and remain separate from the immutable release-source qualification.

Stop after publication/download and closeout verification. No specialist tests,
deployment, production operations, Hex/OCI publication or E2E enablement.

## Execution result — 2026-10-20 (Asia/Shanghai)

[GitHub v0.5.0](https://github.com/gsmlg-opt/gaoxy/releases/tag/v0.5.0) is
published from frozen `b0e1531b9d2ac682e4af19d4616ad4461e3ca6f2` with exactly
three qualified assets. Fresh builder ordinary suites passed 210 executions /
0 failures / 144 excluded / 0 skipped; builder and offline packaged WebSocket
passed H2/h2c/H3 15/15 each, with 21 ELF objects and normal runtime cleanup.
Independent source/recipe, artifact/runtime/notes and publication/download
reviews passed. The original repaired static CODE finding remains preserved.
The lossless evidence archive contains 128 byte-verified files. See
[release acceptance](../acceptance/release-0.5.0.md) for actual hashes, commands,
source/platform limits and retained exclusions. The documentation
closeout has its own independent review and commit; final Git verification
follows that commit as described above.
