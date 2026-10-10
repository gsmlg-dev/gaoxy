# Independent M3 delivery and evidence audit

Task: `m3_evidence_audit`; direct assignment. Audit ownership is this document
only. Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`; starting HEAD
`22b76e8051ddaf09e36797cb781b9b119870a9d4`, with shared uncommitted M3 changes.

**Delivery verdict: PASS for the locally committed implemented scope.**
No actionable evidence or documentation inconsistency remains in the completed
local gate bundle. This audit is separate from runtime specification and quality
review, and does not mark full M3 complete. No Mix, fixture, test, network,
commit or push command is run by this auditor; root owns those operations.

## Canonical and recovery provenance

- `canonical-s5-final.json` records strict format/compile and four-app execution
  with exit 0: core 90/0, HTTP 196/0, proxy 156/0 and server 18/0, total 460/0 at
  seed 49315. The retained log contains those four counts and matching seeds.
- Canonical before/after SHA256 maps are identical across 197 files. Every
  changed runtime/test/fixture/workflow file is covered by that canonical map.
  All 90 source hashes in `h2-rfc-s5-final/results.json` agree with it.
- The selected RFC report records 40 completed PASS cases, exit 0, and zero
  active/retained-byte/cleanup-pending reservations plus no cleanup failure for
  every case. Its gateway log confirms runtime DOWN and same-port rebind.
  This is selected RFC evidence, not full conformance or production acceptance.
- S5 recovery logs preserve Astra round 1 format failure and round 2 strict
  formatting/compile plus scoped 26/0 and full proxy 156/0 at seed 107342.
  Historical production, fixture and deliberately red logs remain in place;
  no historical failure is promoted to PASS.

## Final local receipts and source identity

`final-gates.json` agrees exactly with all 199 frozen current-source hashes and
all 178 listed static artifact hashes. Its sorted compact source-map digest is
`6f8cb7c032c0f21ceb3bcdb1df9f8e401b1e847c6f6f26a5beb72cd44c021237`.
The three mutable closure documents (`final-gates.json`, `final-spec-review.md`
and this audit) are outside that static artifact map and remain separately
reviewed packaging material.

The only changed member of the 197-file canonical map is the Phoenix fixture
lock's HPAX 1.1.0 tuple, identical to the root tuple. Fixture strict compile,
locked resolution and 2/0 tests at seed 805388 are recorded with actual exit 0.
The separately added Linux `flake.nix` library-path qualification has its default
import receipt, exact flake/lock hashes and separate independent review. The
initial browser import failure is retained as FAIL before any checks ran.
Runtime, tests and root lock remain identical to the canonical checkpoint.

Browser evidence contains exactly all 15 expected PASS checks, exit 0, normal
process exit and source restoration. Its 102-file before/after maps are identical
and match current files and their frozen-source overlap. Reverse-example evidence
contains exactly all six expected PASS checks, exit 0, and 85 exact current-source
hashes. Browser and reverse receipts retain independent peer, verified TLS,
Chromium H2, reload/restoration and listener cleanup boundaries.

The qualified soak records 600.0001466 seconds of offered load, 32 concurrent
streams and 131072-byte bodies: 4064 offered equals 3872 exact completions plus
192 expected progress resets; local 1959 plus fixed-proxy 1913 equals the
completion total. It records zero unexpected errors and 299 route reloads.
All 91 soak hashes match frozen/current files. The raw gateway log's 600 sample
counter records, 299 reload receipts and stopped receipt exactly match JSON.
Independent recomputation confirms maximum RSS growth 9940992 bytes, process
growth 132, per-owned-process mailbox 6, active admission 34 and retained/high-water
371570471 bytes within the frozen ceilings. The 7 ms stopped receipt confirms
6082 captured/6082 DOWN, no live captured processes, zero owned reservations,
HTTP tasks and guardians, runtime DOWN and same-port rebind. This fixed-proxy
profile does not qualify a sustained groups/probes profile or unsampled peaks.

## Documentation and progression

Reviewed relative links in README, acceptance, capabilities, implementation
status, native HTTP, gateway, HTTP proxy, M3 plans and integration READMEs resolve.
The earlier stale Round 11/S5 status, group repair wording and format-command
explanation are corrected in current documents. Pending local commit checkboxes
remain intentionally unmarked until packaging finishes.

The final upstream snapshot records both #66 and #67 CLOSED, with installed and
latest GitHub/Hex HTTP Fetch still 0.19.1, published before both fixes. Current
acceptance/capability/implementation documents preserve the containing-release,
dependency-update and cleanup/trailer/version-matrix qualification prerequisite.
**Full M3 remains BLOCKED; M4 cannot start.** Hosted CI, publication, deployment,
production acceptance, public management, Vault changes and release-artifact E2E
remain outside these local PASS claims.

## Artifact exclusion and unrelated workspace preservation

A fresh read-only scan of tracked plus untracked nonignored files finds no
private-key PEM markers. The M3 evidence directory contains no generated keys,
certificate/CSR/serial files, bytecode, compiled BEAM files or archives. The
browser package includes only manifest/results/logs and the requested screenshot;
generated fixture keys remain in ignored runtime material. Existing ignored
build, dependency, temporary and browser-environment directories are excluded.

Root-main remains `71f1b02032b440c5626263bd48aa4f622260e70a`; the unrelated
root `gaoxy-m1.1-fix-prompt.md` exists with its recorded SHA256 unchanged.
The auditor has not changed either checkout or user file.

## Execution and remaining packaging check

Read-only verification used git status/history/diff/ls-files, relative-link
resolution, JSON/log count and seed comparison, SHA256 comparisons, raw receipt
and sample comparison, and private-key-marker/artifact-name checks.
The full staged `git diff --check` returns exit 2: 28 trailing-whitespace or
new-blank-line-at-EOF findings occur only in seven preserved raw `.log` files
under M3 evidence. Their bytes and recorded hashes remain intact. The separate
staged authored non-log check passes with exit 0 across 65 files; the owned
audit document's check also passes. This scoped authored PASS does not relabel
the full raw-log check as green. All auditor commands completed; no auditor
child process remains active. Auditor Sol repair rounds: 0; received Task 5 Astra
recovery counter: 2 with one format failure, not an auditor repair.
No design decision, scope expansion or repair is requested.

## Final committed packaging conclusion

**Delivery PASS at `a5f639946b024fabdc0429b2c5bfd943126c3739`.** Independent
read-only comparison confirms all 199 committed source blobs and all 178 static
artifact blobs exactly match the accepted manifest. All 181 M3 evidence files
are committed: the static map plus the three explicitly excluded closure
reports. Documentation and evidence are covered by the 189-file M3 record
commit; no required implementation, tool, fixture or evidence file is omitted.

Seven local commits divide the delivered scope without mixing unrelated work:

| Commit | Scope | Changed files |
| --- | --- | ---: |
| `25d68da` | Bounded UDP dispatcher and relay associations | 11 |
| `050fc85` | Native HTTP/2, HTTP operations and generations | 38 |
| `6d92298` | Destination policy, relays and upstream groups | 26 |
| `6786d8f` | Strict standalone HTTP route reloads | 10 |
| `8e89470` | Independent peers/browser/soak and local environment | 13 |
| `9eda1ca` | GitHub Actions integration | 2 |
| `a5f6399` | Current documentation and preserved evidence | 189 |

Their commit subjects are conventional and contain no generated-by or Claude
co-author trailers. Committed release-artifact E2E/release workflows remain
unchanged by these seven delivery commits. No ignored build/dependency/browser
runtime files, generated credentials or private-key PEM markers are tracked.
Root-main HEAD and the unrelated user prompt remain exact.

Committed full-scope whitespace verification returns exit 2 with the same 28
preserved raw-log findings in seven evidence logs. Committed authored non-log
verification returns exit 0 across 165 changed files. These actual outcomes
remain distinct; this delivery verdict does not claim a green full whitespace
check or rewrite the raw evidence.

Parent's final seal may refresh only closure documentation, manifest receipts
and checklist bookkeeping. At audit completion the already observed changes
are the upstream snapshot read timestamp and Task 7's local delivery checkbox;
the latest/installed dependency remains 0.19.1 and the blocker is unchanged.
The parent must refresh affected artifact hashes when sealing those records.
The auditor changes only this report, launches no runtime command and creates
no commit. All auditor commands have finished; repair counters remain zero.

Full M3 is still BLOCKED on the containing upstream release/update and required
qualification. No M4 progression, remote publication, deployment or production
acceptance follows from this local delivery PASS.
