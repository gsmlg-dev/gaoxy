## v0.4.0 publication preparation — 2026-10-19

The later user request explicitly authorizes committing, main integration, push and GitHub v0.4.0 publication. Accepted M3 implementation/ordinary verification and the specialist-test handoff remain unchanged.

[Release acceptance](release-0.4.0.md) records artifact and publication gates, currently pending. Earlier local-only and capability snapshots below retain their capture-time status. No deployment or specialist testing is part of this release.

# M3 completion and local integration — 2026-10-19

**Product status: ACCEPTED COMPLETE in the current user-approved scope.**
**Fresh ordinary candidate and main verification: PASS (62 executed tests each, 0 failures). Local main merge: PASS.**

The user accepts the existing M3 product implementation and ordinary verification
as complete and authorizes a local merge into `main`. Exceptional/disconnect,
slow-peer, pressure, sustained-load and combined qualification is assigned to a
dedicated specialist test environment and is outside this integration. Stop
executing or extending those slices here. This scope decision supersedes older
whole-M3/Task5/Task6 OPEN dispositions for this merge; it does not turn failed or
unexecuted verification into PASS or implement an absent capability.

## Delivered functionality and retained evidence

The local implementation through `88799ae316e7195ae42656b228edfea2aaa115ed`
contains the H1 resource foundation (ledgers/custodians, metadata pins and request
tokens), managed H1/H2 fixed/group upstreams and probes, checked Generation and
reload integration, native worker startup accounting and the implemented
streaming compatibility. The public HTTPFetch cohort is 0.21.10. Each linked
acceptance defines its delivered subset and limits; these are not universal
memory, protocol-conformance or production-capacity claims.

| Implemented area | Historical actual evidence |
| --- | --- |
| [H1 resource foundation](m3-h1-resource-foundation.md) | Fresh proxy 77/0; independent TCP/TLS 8/0; strict compile/format PASS |
| [Managed H1 fixed endpoints](m3-managed-h1-fixed-endpoint.md), [groups/probes](m3-managed-h1-groups.md), [Generation](m3-managed-h1-generation.md) | Fresh scoped 178/0, 168/0 and 341/0 respectively; independent reviews PASS |
| [Managed H2 fixed endpoints](m3-managed-h2-fixed-endpoint.md) | Fresh compatibility 853/0, public 63 and independent matrix 135 PASS within the recorded bounded profile |
| [Native worker startup accounting](m3-native-worker-startup-accounting.md) | Fresh 561/0 and independent SPEC/CODE PASS within its source-bound native-worker scope |
| [Managed H2 group Generation](m3-managed-h2-group-generation.md) | Fresh 239 + 170 + 475 = 884 scoped invocations/0 failures; browser 4/4; independent reviews PASS |
| [Managed H1 streaming matrix](m3-managed-h1-matrix.md) | Fresh related 96/0; standalone 16/0; ordinary browser 2 rows; local commit `deef3b0` |
| [H2 slow-peer slice](m3-managed-h2-slow-peer.md), already executed | Fresh related 94/0; Python 11 methods; ordinary browser 2 rows; local commit `fb7d0fd` |
| [Native H1 response-pressure repair](m3-native-h1-response-pressure.md), already executed | Regression 1/0; pressure 4/0 within related 52/0; standalone 16/0; ordinary browser 2 rows; local commit `88799ae` |

Counts describe their original commands and overlap across suites/stages; do not
sum them as unique cases or call them fresh merge verification. Existing failed
runs, uncertain cleanup outcomes, assertions, deadlines, source pins and repair
counters remain unchanged in their historical records.

## Specialist-test handoff and paused slice

Remaining exceptional/disconnect, slow-peer, true upstream write pressure,
native downstream TLS pressure, standalone pressure/load, controlled browser
slow consumption, sustained-load and combined validation requires a dedicated
specialist test environment. Existing FAIL/BLOCKED/NOT RUN outcomes retain those
statuses. They are excluded from this local merge's acceptance gate by the
user's scope decision, with no new execution authorized in this task.

The sole-native-H1 blocked-upload disconnect hypothesis has **not established a
product defect**. Its first attempt executed zero tests during environment
preparation timeout. The next attempt executed one test/one failure because the
fixture module was not loaded; no request was created. The subsequent test-only
`Code.require_file` fix has not been rerun. Preserve the test draft and evidence
outside this accepted implementation; do not continue the reproducer or its
conditional helper repair here. The unmerged test draft, slice documents,
setup diagnosis and test-fix source review remain preserved in the original
`.trees/m3-h1-resource-foundation` worktree and are excluded from this merge.
Their older NOT RUN checkpoint must be read with this later factual disposition.

## Fresh ordinary integration ledger

| Gate | Current status | Evidence |
| --- | --- | --- |
| Fresh ordinary scoped verification of the merge candidate | PASS; strict compile, 38 ordinary unit/configuration tests + 24 positive network tests, 0 failures | [Exact commands and exits](evidence/m3/local-merge-2026-10-19/premerge.json); source `88799ae`, Nix Elixir 1.18/OTP 28, seed 0/max-cases 1 |
| Independent review of accepted integration and current scope documentation | PASS; no unresolved findings | [Independent scope/source/document review](evidence/m3/local-merge-2026-10-19/independent-review.json) |
| Local main integration | PASS; fast-forward from `449a4c4` to `743297a` | [Actual integration receipt](evidence/m3/local-merge-2026-10-19/integration.json); implementation source remains `88799ae`; this documentation-only closeout follows |
| Fresh verification on merged main | PASS; strict compile, 38 ordinary unit/configuration + 24 positive network cases, 0 failures | [Main commands, environment, counts and exits](evidence/m3/local-merge-2026-10-19/postmerge.json); same scoped selection as the candidate |

The positive network command selected existing test locations for fixed/group H1 and H2 upstreams, TCP/TLS or h2c/TLS-H2, exact targets, connection reuse, duplicate fields and trailers. It executed 24 of 114 defined cases; 90 other cases were deliberately deselected. They are not 114 executed tests. No exceptional/disconnect, slow-peer, pressure or load case was executed. Pure headers/options and route configuration executed 30 + 8 cases without exclusions. Candidate and merged-main runs each executed 62 cases; the repeated runs are not 124 unique tests. Main verification used the explicit dependency/build paths in its receipt. Original untracked files and the unfinished specialist slice remain preserved in the original worktree.

## Authorization and publication boundary

The new authorization covers local integration into `main`. It grants no new
push, tag, release, package/image publication or deployment permission. The
already published [v0.3.0 release](release-0.3.0.md) remains a separate historical
source/artifact cohort and does not contain this new local M3 work by inference.
Production data, operational certificates, Vault, public management and the
disabled release-artifact E2E restrictions remain intact.
