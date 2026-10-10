# Installed HTTP 0.21.1 cohort verification

Date: 2026-10-11 Asia/Shanghai. Direct independent Sol task
`m3_h1_preparation_spec_review/installed-0.21.1-cohort`.

**PASS: installed source, direct pins, lockfile and archive identity.** This
receipt establishes the installed seven-package cohort at0.21.1. Runtime
compatibility, compiled/loaded identity and public regressions were not executed
by this reviewer. TLS95 remains blocked; complete P0–P6 is unqualified and
managed activation stays disabled.

The [JSON receipt](installed-cohort-verification.json) contains205 frozen
executable input hashes, seven archive hashes, ten review-input hashes and the
exact baseline/current lock entries. Worktree is
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `a6a210c720d4a0fa9b8fa5f485e5c07a825ad03c`.
Parent and another worker own simultaneous accounting/probe/README changes;
only these two new verification reports are owned by this assignment.

## Installed package and lock checks

Using actual cached archive bytes and the frozen
[release provenance](release-provenance.json), Python independently verified:

| Package | Installed shipped files | Runtime `lib/` files | Identity checks |
| --- | --- | --- | --- |
| `elixir_quic` | 26 | 23 | PASS |
| `elixir_quic_http3` | 16 | 13 | PASS |
| `ex_ssl` | 63 | 58 | PASS |
| `http_core` | 34 | 32 | PASS |
| `http_fetch` | 21 | 17 | PASS |
| `http_runtime` | 24 | 22 | PASS |
| `http_web_socket` | 12 | 10 | PASS |
| **Total** | **196** | **175** | **PASS** |

For every shipped source/document/manifest path, the installed byte sequence
matches its actual `contents.tar.gz` member and its release-provenance SHA256.
All196 also match the containing published inputs frozen by the completed
[source/API review](source-api-review.md). No dependency source patch or silent
upstream workaround is present in these shipped files.

For each of seven packages, the independent check:

1. Computes SHA256 of raw `VERSION || metadata.config || contents.tar.gz`.
   All archives have format version3. The result equals the archive's actual
   uppercase `CHECKSUM` after case normalization and the lock's inner checksum.
2. Computes SHA256 of the complete published `.tar` file. It equals the frozen
   Hex release checksum and the lock's outer checksum.
3. Checks actual archive metadata name/version and requirements against the
   release map; compares all lock requirements. Exact internal constraints
   `== 0.21.1` appear as normalized `0.21.1` in the lock. Telemetry constraints
   remain `~> 1.0`.
4. Decodes the finite on-disk `.hex` ETF using Python without an Erlang VM.
   Package name, version0.21.1, `hexpm`, Mix manager and both checksums all agree
   with the actual archive and lock.

Seven package versions and seven inner/outer checksum pairs passed. The receipt
records all actual checksums and the SHA256 of each archive member used to
compute the inner digest. Additional installed `.hex` files are hashed
separately from the196 shipped paths.

The root lock has24 entries. Comparing its full line entries with
`git show a6a210c720d4a0fa9b8fa5f485e5c07a825ad03c:mix.lock` shows exactly the
seven HTTP cohort entries changed; all17 unrelated entries remain byte-identical
as entry text, with no added or removed package. The receipt pins the baseline
lock SHA256 and preserves exact before/after entries.

Both existing direct dependencies in `apps/gaoxy_proxy/mix.exs` are exactly
`== 0.21.1`: Fetch and WebSocket. The manifest is otherwise byte-identical to
its baseline after replacing the two original `== 0.21.0` strings. Its current
and baseline hashes are recorded.

## Fetch failure and successful repair

The parent's [initial fetch receipt](deps-get-initial.json) and log show exit1:
Fetch0.21.1 requires Runtime0.21.1, while the existing exact WebSocket0.21.0
pin requires Runtime0.21.0. The resolver reported
`** (Mix) Hex dependency resolution failed`. The initial receipt records no
lock change. This is a project pin conflict, not a new upstream defect.

The parent aligned both existing direct pins and reran
`nix develop --command unbuffer mix deps.get`, with `MIX_ENV=test` and
`ERL_FLAGS=+S 2:2`. [Repair1](deps-get-repair1.json) records exit0 in14.384s;
its log hash was independently checked. The log lists all seven upgrades and
unchanged unrelated packages. This reviewer did not execute Mix or repeat the
fetch. Recorded cumulative cohort-fetch counters are Sol repair1,
unsuccessful repair0, Astra0. This source/lock verification needed no repair.

## Historical preservation and remaining qualification

All196 preserved0.21.0 counterparts were rehashed against the earlier source
review freeze and still match. The old source proofs and failure history remain
historical0.21.0 evidence; none was edited or relabeled. Published tag/source
containment was already independently reviewed and is not repeated here.
Its source changes require fresh admission/copy/accounting checks, while the
unchanged TLS tracker still lacks the95 fix.

Fresh Python validation exited0 for installed/archive bytes, metadata,
checksums, `.hex` identities, two direct pins, seven changed/17 unchanged lock
entries and historical preservation. Final verification rechecks the205
executable hashes, seven archives, ten review inputs, JSON, local Markdown
links, whitespace and `git diff --check`.

Compilation, loaded BEAM identity, scoped runtime compatibility and public peer
regressions remain separate parent-owned serialized gates. This identity PASS
does not certify finite resource accounting, lifecycle/retirement acceptance,
production integration, managed activation or M3 completion.

No VM, Mix, network command, dependency mutation, fixture/product edit, commit
or child agent was launched by this reviewer. All own commands finished; no
own background process remains. No escalation gate or new product decision
applies. Remaining external blocker: upstream
[HTTP95](https://github.com/gsmlg-dev/http_fetch/issues/95) for TLS qualification.
