# Independent final public-consumer audit

Status: PASS. No actionable inconsistency found.
Task: review_compiler_ci / final-public-consumers; direct independent review.
Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/standalone-ci-followup`,
branch `codex/standalone-ci-followup`.
Prepared and execution source both identify
`d5e0a6c50fdaa5a3cfbff548069005029c41960e`, version `0.5.4`.
Historical task baseline: `581bea7d27b9d86c7dd0e63a1d49fcbca3adc3dd`.
Implementation and fixture sources were read only. Parent owns concurrent docs
closeout; no parent changes were overwritten.

## Completed evidence

Audited the completed immutable run at
`.audit/standalone-followup/public-consumers/run-1792520179026749897/`.
`result.json` SHA256 independently matches
`9dd9ad50086859daad8fbd2a21be02d8fe6df1bd33d8f0ce36e4cc27533bef4e`.
All 16 recorded commands exited zero; every raw log hash matches. Each consumer
executed dependency resolution, unused-lock trimming, strict compilation,
resolved-origin assertions and its tests. Exact test summaries contain no
exclusions or skips:

| Consumer | Executed tests | Failures | Final lock SHA256 |
| --- | ---: | ---: | --- |
| core | 1 | 0 | `b8e0afb24307a59835446858dbccc004acb0220c2ddc73573471b868694eaf75` |
| HTTP | 3 | 0 | `8356fcc2076f73e7cdb085aad0d1a1bb5dfb4f1ac79d91593111fed224a9bd1f` |
| Phoenix | 5 | 0 | `cc35ff783ab1e4bbe48aeffa3742c709c5c5b360c818ab791f336ef7ed600901` |

The HTTP count is three tests for the H1/H2 consumer; it is not HTTP/3 protocol
acceptance. Core exercises TCP/UDP and optional-app isolation. HTTP exercises
large JSON/form bodies, optional-app isolation and native H1/H2 traffic. Phoenix
exercises a real Endpoint with large bodies plus listener ownership and wrapper/
code-reload composition. Test files/assertions/deadlines remain byte-identical to
the reviewed commit. Browser acceptance is separate from these nine tests.

## Public sourcing and isolation

Independently inspected `public-consumers/verify.py`, generated manifests,
repository log, resolved logs, final locks and cached package bytes. Manifests use
public Hex version requirements, with no Git/path/in-umbrella dependencies. The
WebSock adapter uses the published `gaoxy_websock_adapter` package with app
`websock_adapter`. Public Gaoxy dependencies resolve to exactly `0.5.4`.

The harness removes inherited `HEX_*` and dependency/build/lock/Mix-path overrides,
then assigns run-local Hex/cache homes and per-consumer dependency/build paths.
Preparation requires an initially absent dependency/build tree. The repository
log lists only `hexpm` at `https://repo.hex.pm`, with its public key and no auth
key. Successful resolved-origin commands assert every dependency uses `Hex.SCM`,
`hexpm`, and the consumer's own dependency directory, and the loaded Gaoxy BEAM
comes from its isolated build directory. Final locks independently contain only
public Hex tuples: core 13 entries, HTTP 20, Phoenix 25. No local mirror or Git
resolution is evidenced.

The three used Gaoxy package archives in the isolated Hex cache are byte-identical
to the previously audited public Hex/GitHub release assets:

- `gaoxy`: `21199df325b3932a1ddcbe63586933311c01122fc79ab64fe7ec934b0fe04eda`
- `gaoxy_http`: `adf33657e0a56efef289f8d165015c13637a083afa25aeceb55f55918fe4e456`
- `gaoxy_websock_adapter`: `8ae7ee1bb29a243db90ee7604f44b793af24d4d0803a3b2232e986fab99d43f7`

Independently compared every archived payload file with each corresponding
resolved consumer dependency directory; all match and those directories are not
symlinks. The three consumer types do not claim clean-consumer execution of the
separate `gaoxy_http3` or `gaoxy_proxy` packages.

## Fixture and lock preservation

Recomputed every original fixture hash against both current source bytes and
`git show d5e0a6c5:<path>`, then compared copied consumer fixtures. All 16 files
match. All prepared non-lock source hashes remain unchanged. Prepared lock hashes
identify the accepted upstream snapshot; final locks correctly differ after
public Gaoxy resolution and pruning unused entries, and match their final hashes.

Independently rebuilt the accepted lock map in memory from the recorded root and
Phoenix locks, excluding own packages and non-Hex entries; all 27 accepted entries
match `accepted-upstream.lock`. Every surviving non-own final lock entry is exactly
the accepted tuple. The only newly allowed upstream tuples are `hell 0.1.2` and
`abyss 0.7.0`, as explicitly checked by the recorded origin command. No accepted
upstream version or checksum was silently refreshed.

Recorded source lock hashes still match:

- root `mix.lock`: `9f04f56f7b3389e217803614537133cda21a6bc176d2499fdcee6128292f0777`
- Phoenix fixture lock: `7059476a6e745020b89f610a54bd908d2c26181e88cac3ee511d61390f8bfda1`
- accepted upstream snapshot: `106f4d93b5232745f7eb88194127064035039834fc2353f3399b2853d570f9cd`

## Scope and handoff

Fresh review commands used read-only Python hash/archive/assertion checks and
Elixir evaluation of lock data; all completed with exit zero. No builds/tests,
network resolution, publication or implementation/fixture edits were performed.
Only this assigned report was written for this followup. The separate
`final-publication.md` report remains intact with its publication-only scope and
historical pending-consumer note; this report supplies the later completed
consumer audit without rewriting history.

DONE for this audit. Public consumers PASS within the nine executed tests above.
No deployment, production, specialist pressure/disconnect/soak, certificates,
Vault, public-management or disabled release-artifact E2E acceptance is implied.
Reviewer adds zero repair rounds; received prior counters remain A Sol 2 / Astra 0
and B Sol 2 / Astra 0. New fixture author's counter was not supplied. No decision
needed. All reviewer commands finished safely.
