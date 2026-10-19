# Gaoxy v0.4.0 Release Implementation Plan

> **For agentic workers:** Use `subagent-driven-development` or `executing-plans`
> task by task. The parent owns Git/publication; independent Sol review precedes
> execution and final publication. Serialize builds and live verification.

**Goal:** publish the accepted M3/M5 source and a freshly qualified standalone
Linux x86_64 artifact as GitHub v0.4.0 under the user's explicit authorization.

**Architecture:** [ordinary portable design](../designs/release-0.4.0-portable.md).
Reuse the reviewed v0.3.0 build/runtime recipe in a new version directory, with
explicit ordinary-only selectors and packaged embedded WebSocket verification.
Keep source, hosted CI, portable bytes, publication and deployment distinct.

**Tech stack:** Elixir 1.18.5 / OTP 28, locked HTTP/QUIC 0.21.10, existing pinned
Debian/glibc amd64 Docker recipe, separate independent H2/H3 and M5 Python peers,
Git and GitHub CLI. Work stays in `.trees/m5-websocket-over-h2-h3`.

## Task 1 — establish candidate and version

Files: root `mix.exs`, five `apps/*/mix.exs`, this plan, release design,
`docs/releases/0.4.0.md`, `docs/acceptance/release-0.4.0.md`, current capability
headers in README/native-http/http3/http-proxy/gateway/capabilities/status,
`implement-plan.md` and the M3/M5 acceptance followups. Preserve historical tails.

- [x] Fetch origin and inspect refs. Live latest release is v0.3.0; v0.4.0 is
  absent. Remote main is an ancestor of M5 (0 remote-only, 60 local commits).
  Preserve the unrelated untracked prompt and existing worktrees.
- [x] Change exactly six own version declarations from 0.3.0 to 0.4.0. Keep
  root lock SHA256 `c93b608b77c457e4324430544c1acc2b384ee21e1a2b8ab528bad248ac666cb6`.
- [x] Document embedded managed H1/H2 versus JSON H1/H3 origins, H2-first HTTPS,
  explicit h2c, independent WS opt-in, Phoenix paths and browser-selection limits.
  Keep artifact/publication gates pending until actual execution.

## Task 2 — prepare and independently review ordinary portable recipes

Files: new `docs/acceptance/evidence/release-0.4.0/portable/recipe/` seven copied
recipes plus `ordinary-scope.json`; `integration/websocket_multiplexed/run.py`
and its README for optional paired `--release` / `--source-identity` arguments.

- [x] Retain immutable toolchain pins, source/archive/lock checks, safe inventory,
  package metadata and checksums. Use 0.4.0 names; preserve every old recipe.
- [ ] Run the exact M5 136-case scope and accepted M3 ordinary 62-case selectors;
  retain nonzero/zero-failure assertions and record exclusions separately.
- [ ] Keep peer environments separate. Run existing core/gateway/H3 smokes and
  H2/h2c/H3 packaged WS profiles with unchanged 15-case assertions, both in the
  builder and fresh offline runtime. No Mix/development beams in package runs.
- [x] Complete independent SPEC then CODE review of source, recipes, scope and
  candidate notes. Resolve findings before building. Record every failed attempt.

## Task 3 — commit, integrate and qualify exact source bytes

- [ ] Commit task-owned source/docs with conventional messages; final release
  source commit includes `[skip ci]` to keep excluded automatic specialist jobs
  unexecuted. Fast-forward main, preserving the unrelated prompt byte-for-byte.
- [ ] Create a unique `.audit/release-0.4.0/portable-<id>/context` directory. Copy
  the reviewed recipe there. Archive committed main with `git archive --format=tar
  HEAD`; write `source-identity.json` containing source_sha, archive/lock SHA256,
  and exact changed Elixir paths from `git diff --name-only v0.3.0 HEAD`.
- [x] Retain the first failed formatter receipt. Partition the full changed path
  list only at `docs/acceptance/evidence/`: format every current changed Elixir
  file, preserve immutable historical snapshots, record both sets/counts and
  keep the unchanged-byte custody check over all archived regular files. Obtain
  fresh independent SPEC then CODE review before the repaired build.
- [ ] Verify archive bytes against committed source and recipe hashes, then run:

```sh
docker buildx build --platform linux/amd64 --progress plain --target artifact \
  --output type=local,dest=ARTIFACTS CONTEXT
python CONTEXT/finalize.py ARTIFACTS
python CONTEXT/qualify_runtime.py RUN_DIRECTORY
```

  `CONTEXT`, `ARTIFACTS` and `RUN_DIRECTORY` are the unique recorded absolute
  execution paths; retain exact expanded commands and exits in receipts.
- [ ] Require scoped ordinary test/format/strict compile PASS, unchanged archived
  sources, all five packaged versions 0.4.0, two checksums, valid inventory and
  nonzero ELF inspection without missing/Nix dependencies. Require normal child
  exit/removal/observed absence, all three packaged WS profiles and existing
  smoke exchanges in the fresh network-disabled runtime.
- [ ] Review actual artifact/runtime/source identity and final release notes
  independently. Freeze release source throughout qualification; repair sources
  require fresh affected qualification. Never reuse old binary acceptance.

## Task 4 — publish and verify downloads

- [ ] Push reviewed main; verify `git ls-remote origin refs/heads/main` matches
  the frozen candidate. Do not dispatch release.yml or alter account/settings.
- [ ] Create annotated `v0.4.0` at that SHA, push its tag, and verify the peeled
  remote tag. Create the release with `gh release create v0.4.0 --verify-tag
  --title 'Gaoxy v0.4.0' --notes-file REVIEWED_NOTES` and exactly the archive,
  build-info.json and SHA256SUMS. No replacement/force of an existing tag.
- [ ] Download all three assets to a fresh directory with `gh release download`;
  compare exact bytes/hashes to qualified artifacts, parse sums/versions/source
  and inventory, and verify GitHub release flags and remote refs.
- [ ] Independently review publication/download evidence. Commit and push final
  notes/acceptance/current headers and evidence with `[skip ci]`, verify remote
  main and clean task worktree, preserving the unrelated prompt.

Stop when these gates complete. No deployment, production data/certificates,
Vault/public management, specialist test execution, Hex/OCI publishing or enabling
the disabled release-artifact E2E workflow is part of this release. Existing
M3/M4/M5 assertions and historical failures remain unchanged; no third Astra.
