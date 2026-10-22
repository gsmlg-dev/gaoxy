# Gaoxy.Test acceptance evidence

## Current disposition

**INCOMPLETE / final integration verification**, resumed 2026-10-22 (Asia/Shanghai).
The complete target remains Phases 0–5 of `../plans/gaoxy-test.md`. Initial
contracts are in `../testing/gaoxy-test-design.md`. Package, protocol helpers,
external consumers, packaging and CI changes are present in the uncommitted
development snapshot. Staged consumers and integrated local lifecycle checks pass.
Required hosted release verification and publication remain incomplete.
Independent contract/code review accepted the fixes; the versioned target is
0.10.0. Authorized Astra round3 passed the canonical119 aggregate, exact69 helper
gate and unchanged browser8 checks with explicit Chrome156 selection. Actual
standalone isolation and13 smoke checks also passed after final reconciliation;
fresh hosted/publication checks remain pending.

Final canonical execution exposed an additional required-gate failure after the
original recovery budget was exhausted. On 2026-10-22 the user explicitly extended
the cumulative Astra limit to four rounds. Recovery resumes with Sol2/Astra2 used
and two Astra rounds remaining, without resetting the task or counters. No commit,
push, merge request, tag or publication was made.

## Source and environment

- Local HEAD: `656dbf5bb84564adc6a4d68247c0ad2fe52c2625`, branch `main`,
  source version 0.7.0 at kickoff. On 2026-10-22 the checkout was fast-forwarded
  to `32933790457bcfa3533e40dc2ae4d51ad91aa86d` (0.8.0), preserving all task
  changes and newer remote fixes. No reset, stash or worktree creation.
- Current integration baseline: `044e1cd90ddf4cc1550df99411f2906209387f5f`
  (remote 0.9.0), safely fast-forwarded after Astra stopped all writes/commands.
  Task patches and file copies were saved before reconciliation; all untracked
  task files survived and both upstream/new CI gates remain. Root/application
  versions and published-package examples now align at 0.10.0. Current task source
  remains uncommitted; earlier 0.8.0 results are historical evidence only.
- Final reconciliation baseline: `6c82d5be5dd10a1cf96343113addbc926bfacb5c`.
  After Astra round3 released all writes and commands, a collision check found
  zero overlap between incoming paths and task changes/untracked files. A direct
  fast-forward preserved all task changes. Incoming changes are two documented
  stream-shutdown test-contract corrections and 0.9.0 publication evidence; no
  runtime, manifest or workflow payload changed. The affected issue gate is rerun.
- Before work: only `docs/plans/gaoxy-test.md` was untracked; no tracked edits.
- Remote main readback: `gh api repos/gsmlg-dev/gaoxy/commits/main --jq .sha`
  returned that same full SHA, exit 0.
- `gh release list --repo gsmlg-dev/gaoxy --limit 3`, exit 0: most recent
  release `v0.7.0`, published `2026-10-21T06:24:59Z`. This is historical baseline
  publication, not publication of `gaoxy_test`.
- Local tools: Elixir 1.20.1, Erlang/OTP 29 (erts 17.0.2), Python 3.15.0.
  Existing workflow canonical release toolchain remains Elixir 1.18.5/OTP 28.5;
  no matrix configuration has been changed.

## Executed checks

| Command/check | Source scope | Result | Executed |
| --- | --- | --- | --- |
| `python3 scripts/test-stage-hex-packages.py` | Unchanged existing staging tool/tests at baseline HEAD | PASS, exit 0, 8.360 seconds | 9 tests, 0 failures |
| `python3 scripts/test-stage-hex-packages.py` | Integrated 0.8.0 checkout plus new staging converter/tests | PASS, exit 0, 8.056 seconds | 10 tests, 0 failures |
| `git diff --exit-code` | Existing tracked checkout, before adding these new documents | PASS, exit 0 | Not a test suite |
| Current checkout/source/manifests/gate audit | Baseline source plus user plan | Complete inspection | Not behavior verification |
| `ELIXIR_ERL_OPTIONS='+S 2:2' python3 scripts/test-consumers.py --kind base` | Built/extracted six-package 0.8.0 development snapshot, explicit local sibling overrides only | PASS, exit 0 | 3 ExUnit tests plus manual, production dependency and real release isolation checks |
| `ELIXIR_ERL_OPTIONS='+S 2:2' python3 scripts/test-consumers.py --kind http_fetch` | Built/extracted development snapshot and published HTTPFetch 0.21.14 | PASS, exit 0 | 2 ExUnit tests, including real H1/h2c and callback assertion propagation |
| `ELIXIR_ERL_OPTIONS='+S 2:2' python3 scripts/test-consumers.py --kind h3` | Built/extracted development snapshot and independent verifying aioquic peer | PASS, exit 0 | 2 ExUnit tests, real H3/body/trust and UDP listener reuse |
| `python3 scripts/test-check-tests.py` | Existing nonzero test wrapper | PASS, exit 0 | 8 tests |
| `python3 scripts/test-check-repairs.py` | Curated gate accounting | PASS, exit 0 | 6 tests |
| `python3 scripts/test-release-smoke.py` | Existing release readiness/barrier wrapper | PASS, exit 0 | 5 tests |
| `GAOXY_QUIC_PYTHON="$PWD/.audit/h2peer/bin/python" ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix test apps/gaoxy_test/test/protocol_test.exs apps/gaoxy_test/test/helper_test.exs` | Initial package protocol/helper validation | FAIL, exit 2 | 21/26 passed, 5 failed |
| Six-file package aggregate, Sol repair round 1 | `.audit/gaoxy-test/core-repair1.log`, seed 976307 | FAIL, exit 2 | 60/61 passed; secondary setup/on_exit report proof failed |
| Six-file package aggregate, Sol repair round 2 | `.audit/gaoxy-test/core-repair2.log`, seed 457284 | FAIL, exit 2 | 60/61 passed; H2 coordinator-loss socket cleanup timed out |
| `ELIXIR_ERL_OPTIONS='+S 2:2' python3 scripts/test-consumers.py --kind base` | Review correction: explicit missing-H3 startup allocation comparison | PASS, exit 0 | 3 ExUnit tests plus manual and actual production release isolation |
| `python3 scripts/test-consumers.py --version 9.9.9 --kind base` | Review correction: reject local version/source mismatch before staging | Expected rejection, exit 2 | No behavioral tests executed |
| Astra round2 aggregate package | Archived `astra-repair2-package.log`, 0.8.0 baseline, seed457284 | PASS, exit0 | 69 tests |
| Astra round2 scoped production lifecycle | Archived `astra-repair2-production.log`, 0.8.0 baseline, OpenSSL3 | PASS, exit0 | 47 tests |
| `python3 scripts/test-stage-hex-packages.py` | Integrated 0.10.0 source over `044e1cd9` | PASS, exit0 | 10 tests |
| `python3 scripts/test-consumers.py` | All six built/extracted 0.10.0 package tarballs | PASS, exit0 | 3 base +2 H3 +2 HTTPFetch tests; manual/prod dependency/actual release isolation |
| `python3 scripts/check-repairs.py all` | Integrated 0.10.0, local Elixir1.20.1/OTP29 | FAIL, exit1 | All69 helper tests and190 unit cases passed; old Linux-specific alternate-loopback TLS case failed |
| Existing eleven-file internal-request gate | Integrated 0.10.0, seed0, max-cases1 | PASS, exit0 | 46 tests across core/HTTP/H3 |
| `python3 scripts/check-repairs.py composition` | Integrated 0.10.0, local Elixir1.20.1 | FAIL, exit1 | Gateway lifecycle13/13 passed, but an unchanged test emits a type warning after upstream shutdown became `:infinity` |
| `python3 scripts/check-repairs.py composition` | Canonical Elixir1.18.5 on local OTP29, after provisioning its version-specific rebar3 | PASS, exit0 | 58 tests, 0 skipped/excluded |
| `mix format --check-formatted` | PATH explicitly selects canonical Elixir1.18.5, integrated 0.10.0 | PASS, exit0 | Formatting check, not behavioral tests |
| Canonical package/production/remainder aggregate | Elixir1.18.5/OTP29, integrated0.10.0, seed0 | FAIL, exit1 | All119 tests passed, but new protocol test constant-type warnings trigger `--warnings-as-errors` |
| `integration/phoenix_native/unified.py` | Existing release suite, Playwright1.56/Chromium141 macOS, integrated0.10.0 | FAIL, exit1 | Independent H1/H2/H3, H2 browser and H2 reload checks passed; H3 LiveView connected locator missing |
| Existing five isolated source-consumer scripts | Canonical Elixir1.18.5/OTP29, 0.10.0 runtime source over `044e1cd9` | PASS, all exit0 | Core1, HTTP4, H3 2, Gateway1, H3 Gateway1: 9 tests |
| Reconciled upstream internal-request gate | Canonical Elixir1.18.5/OTP29, 0.10.0 over `6c82d5be` | PASS, exit0 | 46 tests |
| Reconciled canonical formatter and strict production compilation | Same final runtime/package source | PASS, both exit0 | Build/format checks, not behavioral tests |
| `MIX_ENV=prod mix release gaoxy` and three standalone smoke scripts | Actual local 0.10.0 release over `6c82d5be` | PASS, all exit0 | Core3 transports +Gateway7 exchanges +H3 3 checks; helper/ExUnit absent |
| Final staging and all extracted-tarball consumers | Reviewed 0.10.0 payload including final package guide, runtime repair `157c0fc5` | PASS, both exit0 | Staging10; base3 +H3 2 +HTTPFetch2, manual/no-ExUnit and actual production release isolation |

The five source consumers use temporary projects and independent builds. Their
logs are `.audit/gaoxy-test/release-source-canonical-{external,http}-consumer.log`
and `release-source-ready-{h3,gateway,h3-gateway}-consumer.log`. The initial core
attempt stopped before tests because a global Hex beam compiled with newer
Elixir called unavailable `Enum.__in__/2`. Installing canonical Hex 2.5.4 under
the isolated `MIX_ARCHIVES=.audit/gaoxy-test-canonical-archives` resolved that
tool mismatch without changing global archives. The first H3 attempt compiled
successfully but stopped before tests because `python` was absent from PATH;
putting the existing pinned peer venv on PATH resolved it. Both failed logs remain
under `.audit/gaoxy-test/`; neither was an implementation repair.

The initial nine staging regressions cover only the historical five-package
path. The new ten-test run builds six package metadata tarballs, preserves the
optional H3 edge and assets, and rejects unsupported optional/internal option
combinations. It does not establish runtime API behavior or publication.

Dependency setup `ELIXIR_ERL_OPTIONS='+S 2:2' mix deps.get --check-locked` and
`ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix deps.compile` both exited 0.
Pinned independent peers were installed with `uv venv .audit/h2peer --python
3.12` and `uv pip install --python .audit/h2peer/bin/python -r
apps/gaoxy_http/test/support/h2-requirements.txt -r integration/http3/requirements.txt`.
The official Elixir 1.18.5 OTP27 archive was downloaded for canonical formatting;
SHA256 `56a065fa2bc609f49a4a3950d509a6a9aa9a827e8610b717e6cfca74a9090580`
matches the release checksum. It runs locally on OTP29; this does not claim a
local OTP28 matrix execution. New integration sources pass Python syntax and
canonical formatting checks; runtime consumer acceptance remains pending.
The initial tarball consumer commands above subsequently passed; logs live at
`.audit/gaoxy-test/consumer-{base,http-fetch,h3}-initial.log`. These are initial
development-snapshot checks; final code, dependency, packaging or version edits
require focused fresh reruns. No published `gaoxy_test` is claimed.

The initial 26-case protocol/helper run retained its failures in
`.audit/gaoxy-test/protocol-helper-initial.log`. Three failures identify normal
session teardown `{:shutdown, :local_closed}` being recorded as an additional
verification failure (including obscuring the useful single SSE timeout
exception). Core Sol repair round 1 is assigned to normalize normal public
shutdown while preserving callback failures. Two TLS cleanup peer tests expected
immediate raw TCP EOF but received TLS alert records first; protocol Sol repair
round 1 must drain those records within the same finite deadline and still prove
socket closure. No assertion is relaxed and no failed result is reclassified.
The workspace emits Mix's warning that `optional` is unsupported on an
`in_umbrella` dependency; extracted standalone manifests retain actual optional
Hex metadata and the clean H3-absent consumer already passed. This warning does
not imply standalone optional compilation failed.

## Reproducible environment blocker

**Historical; resolved 2026-10-22.** Both original named `sol_worker` assignments
now start successfully without model overrides. Their IDs and ownership are in
the design execution record. All original tool errors below are retained as
historical evidence; they no longer prevent implementation.

Required assignment: `multi_agent_v1.spawn_agent(agent_type="sol_worker", ...)`.
The tool returned:

```text
Unknown model `gpt-6.1-sol` for spawn_agent. Available models: gpt-6-astra, gpt-6-sol, gpt-6-luna, gpt-5.6-sol, gpt-5.6-terra
```

At the time no worker ID was allocated, and no implementation writer/command was live. An
earlier full-history fork attempt was also rejected because named agent types
cannot be combined with `fork_context: true`; retrying without that flag exposed
the actual model-availability blocker. Neither tool rejection is an
implementation regression. Sol/Astra repair counts remain 0; no escalation gate
is satisfied. Required action: restore the configured named-worker runtime or
provide an explicit permitted alternate routing decision. Do not silently use a
different model or bypass required delegation with coordinator implementation.

## Review and recovery state

The independent integration review found two actionable issues: a supplied local
version could mislabel the tested source, and the absent-H3 consumer lacked an
allocation leak assertion. Both are corrected; the revised base consumer passed
in `.audit/gaoxy-test/consumer-base-review1.log`.

Core Sol completed two repair/validation rounds. All 35 core tests passed in the
second run, but the aggregate still failed 60/61. The remaining HTTP/2 abrupt
coordinator-loss test returned `:timeout` while draining the socket, rather than
proving closure within its deadline. This remains a failure, not an expected
environment result. Astra recovery was admitted with
`astra_gate=SOL_REPEATED_FAILURE`; its repair counter was zero at dispatch. The
predecessor stopped all writes and commands before handoff. Independent review
also established a report-freezing race, WebSocket lifetime and abrupt-EOF
misclassification, and an SSE queued-message absolute-deadline bypass. The review
reproductions and their limits are recorded in the design. All actionable findings
were passed to the same bounded Astra recovery; no successful aggregate or final
acceptance is claimed. Unchanged historical failure/probe logs and SHA256 values
are archived in `evidence/gaoxy-test/`.

Recovery and final source-reconciliation review subsequently accepted all four
findings and the narrow own-Gaoxy late-handler ownership fix. Astra round2 passed
69/69 package and47/47 production tests, then stopped writes and commands and was
closed. Counters remain Sol2/Astra2, with no reset after remote reconciliation.

The new 0.10.0 source passes the dedicated helper cases, staging and all three
isolated consumers. The full local curated gate retains a Linux-specific old WSS
failure: `127.0.0.2` cannot reach even a plain wildcard TCP listener on this macOS
host (direct probe: `.1` accepted, `.2` errno35 with no accept). No network setting
or test assertion was changed. Required Linux validation remains pending.
The separate Elixir1.20 gateway type-warning failure is also retained; canonical
1.18.5 composition passes. The first formatter invocation used system Elixir via
the Mix shebang; explicitly selecting canonical PATH passed without editing old
files. These environment/toolchain results are not new recovery rounds.

## Final canonical gate and required handoff

The subsequent canonical command executed44 core,5 HTTP,1 H3 and69 fixture tests
with zero assertion failures, but exited1 because the newly added generated
profile tests compare literal module attributes against lists at
`apps/gaoxy_test/test/protocol_test.exs:169`, `:186`, and `:201`. Elixir1.18.5
emits distinct-type comparison warnings. This is a task-owned test compatibility
failure, not a passing gate, an unrelated baseline warning, or an agreed TDD red
case. Preserve all assertions and warning enforcement. The bounded correction is
to express those three profile predicates through dynamic private helpers while
keeping the same profile matrix, assertions and deadlines, then rerun the exact
canonical and curated gates.

The existing browser release suite separately failed before H3 LiveView became
connected. Its independent H3 request passed, as did H2 LiveView/channel and
reload. The cause of the H3 browser failure is not established; do not label it
an environment or product defect without diagnosis. Cleanup reported process
exit0 and restored source. The raw report is preserved as
`evidence/gaoxy-test/final-unified-browser-report.json`.

Cumulative recovery counters are Sol2/Astra2. After this handoff the user explicitly
authorized up to four cumulative Astra rounds: “不行可以使用 astra worker, 最多4轮”.
Two Astra rounds remain for the same GT-CORE recovery, covering canonical test
compatibility and bounded H3 browser diagnosis with unchanged assertions. The
original `SOL_REPEATED_FAILURE` gate and all historical results remain intact.
Before resumption all predecessor threads were closed and validation commands
finished; the resumed Astra receives exclusive recovery writes and root Mix build
ownership. Current source remains uncommitted; no publication is claimed.

## Authorized round3 outcome

The user-authorized extension was used for one additional round. Cumulative
counters are now **Sol2/Astra3 of maximum4**; round4 has not started. The same
worker completed all commands, released recovery writes/root Mix ownership and
was closed. No production source changed in this round.

Dynamic private profile predicates replace four generated-test literal membership
expressions, preserving every profile set, assertion and deadline. Canonical
Elixir1.18.5/OTP29 strict aggregate passed119/119, expanded lifecycle aggregate
passed126/126, exact per-file helper gate passed69/69 and canonical formatting
exited0. Commands and per-file counts are archived in
`evidence/gaoxy-test/round3-handoff.md`.

Chromium141 macOS NetLog records QUIC document requests but TCP WebSocket jobs;
the UDP-only H3 endpoint therefore receives no matching WebSocket request and
the browser reports connection refusal. Selecting installed Chrome156.0.8078.48
passes the same eight checks, including native H3 LiveView and Channel upgrade
receipts, reload/restoration and endpoint shutdown. The final established suite
exited0 with process_exit0/source_restored=true. A bounded optional
`GAOXY_CHROMIUM_EXECUTABLE` override and actual browser identity are now documented
and recorded; default discovery is unchanged. This comparison establishes the
observed browser difference, not a general browser/platform limitation.

Independent Sol specification review accepted the Phase0 contract and A01–A20
mapping with no new actionable finding. Its AST comparison verified all15 browser
assertions unchanged; counters were not reset. This local success preserves every
historical failure and does not claim hosted or published acceptance.

## Acceptance ledger

| IDs | Required proof | Current state |
| --- | --- | --- |
| A01 | External H1/HTTPS and verified packaged trust | PASS, extracted0.10.0 base consumer |
| A02–A03 | Expected-failing ExUnit subprocesses and original callback stacks | PASS, integrated0.10.0 dedicated helper gate |
| A04–A05 | Independent fixtures and atomic concurrent exact-once reservation | PASS, integrated helper/protocol cases |
| A06–A09 | Teardown survival, owner/coordinator loss, bounded callback drain and close races | PASS, integrated helper/recovery cases; historical failures preserved |
| A10 | Manual mode without ExUnit startup and owner cleanup | PASS, integrated cases and staged manual no-ExUnit proof |
| A11 | Actual independent-peer H2, multiplexed callbacks and count semantics | PASS, integrated network cases and extracted consumer |
| A12 | Finite streaming/SSE and established-only persistent cancellation | PASS, integrated helpers, including queued-deadline regression; independent review accepted |
| A13–A14 | Clean H3 absence and trusted actual H3 request/body/stream/cleanup | PASS, integrated cases plus clean base and trusted H3 extracted consumers |
| A15 | H1 WebSocket upgrade, interaction, observation and cleanup | PASS, including lifetime/EOF/peer-close regressions; independent review accepted |
| A16 | Bounded journal/body capture independent of verification accounting | PASS, integrated helper gate |
| A17 | Isolated public HTTPFetch consumer | PASS, extracted0.10.0 with public HTTPFetch0.21.14, 2 tests |
| A18 | New package metadata/assets/version and production release isolation | Staging10, external actual release exclusion and standalone exclusion/smokes PASS on0.10.0 |
| A19 | Dedicated nonempty tests in CI and required release verification | IMPLEMENTED; fresh canonical119/helper69 and browser8 PASS locally; hosted execution NOT RUN |
| A20 | Fresh published Hex-only consumer | NOT RUN; new package not published |

## Integration changes awaiting final-source verification

- Added the package/description to `scripts/stage-hex-packages.exs`, narrowly
  preserved `optional: true` on the internal H3 edge, and extended unsupported-option
  and metadata/assets regressions. No existing dependency options are loosened.
- The unit workflow uses `scripts/check-repairs.py unit`; adding test files alone
  will not execute them. Explicit nonzero package/consumer gates are now configured
  there and in required release verification with `MIX_ENV=test`.
- Both package arrays in `.github/workflows/release.yml` now include the new
  package after its dependencies, preserving exact-SHA/version/checksum gates.
- Root release applications specify `gaoxy_server: :permanent` only. The actual
  final local production release excludes both `gaoxy_test` and `ex_unit`; its
  unchanged portable/native-H1/H2/H3 smoke assertions pass.
- Packaged dedicated test-only TLS assets use the existing SAN/trust model and
  application-relative resolution, with leaf validity through October 2046;
  the CA private key is excluded. Staged trusted HTTPS and H3 passed.
- Preserve raw/negative peers and independent interoperability suites. Keep
  HTTPFetch exclusively in `integration/http_fetch_test_consumer` dependencies.

## Delivery identities

This source-preparation snapshot precedes task commits, push, hosted verification,
tag and publication. Their exact identities and fresh Hex-only consumer results
must be recorded after execution; no publication is claimed here. Installation,
manual ownership and protocol/helper examples are in the package guide; downstream
migration candidates and preserved raw-peer boundaries are in the integration
guide. No production deployment, operational certificates, data, settings or
credentials changed.
