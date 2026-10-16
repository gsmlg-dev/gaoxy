# consumer_local_git_diagnosis — DONE (diagnosis only)

Direct bounded assignment. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, baseline `e189894882bb6a530f2c38538be4efaf384be261`, branch `codex/m3-h1-resource-foundation`. Existing tracked/untracked task changes were observed and left untouched. No repository, dependency, Git global settings, or external service mutations. No Mix/Nix/Elixir/server/browser commands; no external network.

## Root cause and evidence

The qualified dependency checkout is non-shallow and contains locked commit `6146e1bfdd1a85c5c16c3c92ad98ff5f11066820` and tree `39d3fbd253466e5f0000bfd9b64c24890abb48e5`. All 2590 reachable objects enumerated successfully, with 0 missing objects. Its HEAD is detached; it has **zero `refs/heads/*`**. The corresponding commit is available through remote-tracking refs/HEAD, which the default branch refspec does not fetch into a fresh client.

In a fresh scratch repository, `git remote add origin https://github.com/mtrudel/thousand_island.git`, the original per-process URL rewrite, and `git fetch --quiet --tags origin` returned 0; the exact locked checkout command `git --git-dir=.git checkout --force --quiet 6146e1bfdd1a85c5c16c3c92ad98ff5f11066820` returned 128 with the original `fatal: unable to read tree (...)`. `git cat-file -e '<lock>^{tree}'` also returned 128. This independently reproduces the transport failure without consumer/runtime execution.

## Qualified temporary local source

Preserved local bare source: `/tmp/gaoxy-consumer-local-git-diagnosis1-f2s_326d/locked-source.git`.

It was built without changing the dependency repository:

```sh
git init --bare --quiet '/tmp/gaoxy-consumer-local-git-diagnosis1-f2s_326d/locked-source.git'
git --git-dir='/tmp/gaoxy-consumer-local-git-diagnosis1-f2s_326d/locked-source.git' fetch --quiet --no-tags \
  'file:///home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/deps/thousand_island/.git' \
  '6146e1bfdd1a85c5c16c3c92ad98ff5f11066820:refs/heads/gaoxy-locked-source'
git --git-dir='/tmp/gaoxy-consumer-local-git-diagnosis1-f2s_326d/locked-source.git' symbolic-ref HEAD refs/heads/gaoxy-locked-source
git --git-dir='/tmp/gaoxy-consumer-local-git-diagnosis1-f2s_326d/locked-source.git' fsck --full --strict
```

All returned 0. Mirror advertises locked commit at HEAD and `refs/heads/gaoxy-locked-source`. A second fresh Git client configured with the same original upstream URL and rewritten only to this mirror fetched and checked out the exact lock successfully. `rev-parse HEAD HEAD^{tree}` matched the source identities; `git status --porcelain=v1` was empty; fresh checkout `fsck --full --strict` returned 0. Original `remote.origin.url` remains `https://github.com/mtrudel/thousand_island.git`.

## Recommended collector environment change

Change only the root-owned collector's consumer child environment route to:

```text
GIT_CONFIG_COUNT=1
GIT_CONFIG_KEY_0=url.file:///tmp/gaoxy-consumer-local-git-diagnosis1-f2s_326d/locked-source.git.insteadOf
GIT_CONFIG_VALUE_0=https://github.com/mtrudel/thousand_island.git
```

Preserve scripts and `mix.lock`; lock SHA-256 is `c93b608b77c457e4324430544c1acc2b384ee21e1a2b8ab528bad248ac666cb6`. Keep original failed receipts immutable. Root must now run its unchanged isolated core and HTTP consumer scripts to establish actual dependency resolution, compile and nonzero test results. The Git-only probe establishes transport suitability, not consumer acceptance.

## Scope, counters, shutdown, risks

Only `/tmp/gaoxy-consumer-local-git-diagnosis1.json`, this Markdown report, and task scratch `/tmp/gaoxy-consumer-local-git-diagnosis1-f2s_326d` were written. JSON records every command, result and full output. All diagnostic subprocesses finished within finite timeouts; process inspection found zero own residual Git processes. Sol repair rounds: 0 (environment diagnosis, no application repair); received Astra counter: not supplied; no escalation gate. Actual consumer tests: **NOT RUN**, root-owned and pending. No design decisions needed. Temporary local transport does not prove upstream network, hosted CI, publication or deployment.
