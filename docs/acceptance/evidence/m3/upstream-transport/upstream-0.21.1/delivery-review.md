# M3 0.21.1 independent delivery review

Date: 2026-10-11 Asia/Shanghai. Task `m3_patch_delivery_review`, direct
independent Sol assignment. **DONE: PASS for this bounded patch delivery.**
No actionable finding remains. This verdict covers the coordinated published
cohort upgrade, preserved failure history, compatibility, exact cleartext
contract and status documentation. Full M3, TLS, memory accounting and managed
activation are not qualified by this review. The parent owns the local commit.

## Candidate identity and ownership

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `a6a210c720d4a0fa9b8fa5f485e5c07a825ad03c`.
The parent's frozen candidate `.audit/m3-upstream-0.21.1-delivery-freeze.json`
has SHA256 `aeed67e23d2b779e645c6a75d919c31ebb53a2b6f6ada19badc9ab05a9705120`.
All **79 patch-owned file hashes** and **429 current input hashes** match their
actual bytes. The current map equals
[final-checks-repair1-source-after.json](final-checks-repair1-source-after.json),
whose SHA256 is
`ae5d5cbaf296a3cfcb36fc956ea4844a61c339689d36136317797b086b61a3e7`.
All 17 tracked modified paths and all new patch artifacts are accounted for.
This report is the sole reviewer-owned addition, outside the 79-file freeze.
The parent's staged set contains exactly those 79 files plus this report:
80 paths, with no excluded next-stage file. All 79 staged candidate byte
sequences match the frozen working-tree bytes. The parent must restage this
report after its staged-whitespace audit amendment.

The accounting-frontier memo, its review and
`docs/plans/m3-h1-qualification-model.md` are explicitly excluded from this
review and patch commit. They belong to a later delivery. Concurrent writers'
changes were preserved. The root checkout still preserves untracked
`gaoxy-m1.1-fix-prompt.md`, SHA256
`7982874aacafe8bc4f4814740f25d1bd1e5bb35cbdc3938338ab132f2cdf9f1f`.
No historical0.21.0 evidence file appears in the tracked patch diff.

## Source, installation and assertion review

Independent Python extraction of the actual seven cached archives verifies
all **196 shipped files** against installed bytes and provenance SHA256s, and
all **175 runtime files** against actual tagged Git blob identities. Each
archive's inner SHA256 of `VERSION || metadata.config || contents.tar.gz`
matches its CHECKSUM and lock inner digest; its complete outer SHA256 matches
Hex metadata, the GitHub asset digest and the lock outer digest. Installed
`.hex` identities and the independently reviewed executable hash maps remain
unchanged. This independently corroborates the
[installed-cohort receipt](installed-cohort-verification.json) and
[source/API receipt](source-api-review.json), rather than relying on their
PASS labels.

Both existing direct pins are exactly `== 0.21.1`. Exactly seven lock entries
change and all 17 unrelated entries retain identical text. The actual tag is
`bdf849adf119039ed679d24d5fbb0a321f5e578a`, tree
`2188645d94575d7cb452e41eab156e80d38a26ef`. All 196 preserved0.21.0 counterparts
still match their historical hashes. Archive collection's old installed-cohort
and pending-review fields remain timestamped history, not current installation
claims. The incomplete clone is retained as
[BLOCKED_ENV acquisition evidence](source-clone-initial.json); the verified
archive/tree identities establish source identity independently of that clone.

Installed source confirms the reported86–89 paths: informational admission and
capacity snapshot acknowledgement, owned request/policy binaries and the managed
canonical connection-capacity tuple. The unchanged RequestLifecycle tracker
still accepts only the old three-element TLS tuple. Thus95's containing fix is
absent in installed0.21.1. [Refresh4](upstream-status-refresh4.json) records95
closed, while latest GitHub/Hex remains0.21.1; issue closure changes no artifact
or runtime gate.

The scoped product diff changes accounting cohort identity and its exact test
together, retaining every unqualified P0–P6 obligation and activation refusal.
Every noncomment adapter line is identical to baseline; reuse stays disabled
and dedicated H1 remains selected. The probe adds only exact `--cleartext`
selection, preserves the default39-case count and rejects unsupported arguments
before application or peer startup. The old capacity assertion moves after
finite held-request completion, no-request-byte checks, replacement and both
retirement assertions, then becomes an exact canonical tuple match. No cleanup,
wire-byte, no-replay, deadline, scope or expected-abnormal-completion assertion
is weakened. Current docs distinguish the historical cohort and new copying
obligations without relabeling old formulas or runtime proofs.

## Raw runtime evidence audit

All referenced raw log hashes match their receipts. Counts below were checked
against actual logs and before/after input maps; successful peer cleanups retain
exact per-completion expectations, including pre-existing explicitly expected
abnormal completions.

| Gate | Verified result |
| --- | --- |
| Cohort expected red | 4 tests / 1 exact provenance failure, exit2; separate collector-start failure retained |
| Compatibility | 486 tests / 0 failures, seed21111026, exit0; strict global/probe format and compile; 429 stable inputs |
| Unsupported CLI | Expected exit1, no profile/case/cleanup startup markers; not a zero-test suite PASS |
| Initial cleartext red | **FAIL**: 16 cases,17 joined peers,16 successful cleanups; obsolete exact match plus cleanup failure |
| Repaired cleartext red | Expected exit1; same exact mismatch after normal completion;16 cases,17 successful joined cleanups |
| Canonical cleartext green | 24 distinct cases:9 H1,15 h2c;24 successful joined cleanups; exact canonical MATCH; exit0;429 stable inputs; no owned peer remains |
| Initial final checks | **FAIL**:44 tests /18 failures, exit2; required supervisors absent under mixed-suite `--no-start` |
| Repaired fresh final checks | **PASS**:44 tests /0 failures, exit0; strict global/probe format and compile;429 stable inputs; no owned peer remains |

The [green raw receipt](cleartext-green.json) binds log SHA256
`d859749f0d020186f16231925d582b03a334ae5b2f7d8b678ab32420c2a399d7`.
The [fresh final receipt](final-checks-repair1.json) binds log SHA256
`9c2e7e39f6e1757922d7aaa1d173a837a54636469ec7f681e308fa300a3ea917`.
Its command runs `nix develop --command bash -c`, sequential global format,
probe format, `mix compile --warnings-as-errors`, then
`mix test --warnings-as-errors --max-cases 1 --seed 21111026` for the four
Fetch-contract, Fetch-completion, H1-preparation and H1-accounting test files.
The [diagnosis](final-checks-diagnosis.json) and
[repair analysis](final-checks-repair1-analysis.json) preserve the failed command;
repair removes only `--no-start`, changing no implementation or assertion.

The final429 map differs from the peer-green429 map only in adapter comments
and the managed README's current status text. Both deltas were inspected and
are explicit in the parent freeze. All executable logic and fixture assertions
are unchanged after the peer-green run. A preliminary audit expecting only the
adapter delta was corrected to include the documented README update; this was
an audit assumption, not a product or test repair.

## Verification and remaining gates

Fresh reviewer commands: read-only Git status/HEAD/branch/diff inspection;
Python archive extraction, SHA256/Git-blob, lock-line, historical-copy,
receipt/log, raw count, source-map and JSON audits; Markdown local-link and
whitespace audits; `git diff --check`. These checks exit0 after the documented
audit-assumption correction. All **201 candidate local Markdown links** resolve
and candidate JSON parses. The earlier `git diff --check` covered the tracked
working-tree diff; it did not check newly staged evidence. The subsequent full
`git diff --cached --check` exits2 solely for
`deps-get-initial.log:8: new blank line at EOF.`

The raw failure log intentionally retains its original terminal blank line,
ANSI bytes and SHA256
`14078aa05b8ce864ed41bef31a2cb80b0f354a8c0df4a871d0c837fe73497136`.
Raw `*.log` evidence is exempt from whitespace normalization so receipt/hash
bindings remain intact. The scoped staged command
`git diff --cached --check -- . ':!*.log'` exits0. All frozen raw-log bytes
match the index, and all ten explicit raw receipt/log SHA256 bindings pass.
This is an explicit raw-evidence exemption, not a claim that the unrestricted
staged check passes. Source/docs whitespace remains checked. The report's own
links, whitespace and all 79/429 frozen identities are rechecked before handoff.

**BLOCKED:** installed95 fix absent, hence TLS/full39, TLS turnover and
whole-generation retirement qualification. **NOT RUN / UNQUALIFIED:** complete86
adversarial backlog, held upstream preparing/connecting saturation, complete
P0–P6 and retained-byte ledger/composition. **DISABLED / INCOMPLETE:** managed
product integration, Tasks4–8, full M3 and M4 progression. Production, hosted CI,
release E2E, push/publication and deployment are not acceptance results here.
No Vault, production-data or operational-certificate changes are included.

Counters remain separate: this review Sol0/Astra0; new cleartext harness initial
runtime failure1, successful Sol repair1, unsuccessful0, Astra0; final-command
chain initial environment failure1, successful Sol repair1, unsuccessful0,
Astra0. Fetch and collector each preserve their successful repair1 histories;
expected reds are not unsuccessful implementation repairs. Historical0.21.0
Sol/Astra counters remain unchanged. No escalation gate or new design decision
is needed for this bounded delivery.

All own commands have finished; no own VM, Mix, network, compiler, peer,
background process, child agent or Git mutation was launched. Only this report
was written. Local commit and final stage ownership are parent responsibilities;
no push, publication, deployment or activation is authorized by this verdict.
