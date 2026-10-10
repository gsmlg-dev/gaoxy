# Task3 managed fixture: Astra recovery1 handoff

Date: 2026-10-11 Asia/Shanghai. Task ID: M3 Task3 managed fixture recovery1.
Mode: **implementation**. Gate: **SOL_REPEATED_FAILURE**, explicitly confirmed
by the parent after the initial routing-field clarification. Status: **DONE for
the bounded formatting recovery and handoff only**; full fixture runtime remains
unverified. No managed activation or M3 acceptance follows.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline/HEAD `4cc7a1a967d1b90a62d42db438316b10a03a1e16`.
Parent confirmed predecessor ownership had ended and no Mix/network job was
running before granting the serialized slot. Incoming probe and README hashes
matched the handoff. The existing dirty tracked adapter/dependency/documentation
changes and untracked fixture/evidence files were inspected and preserved.

## Gate evidence and root cause

The parent-established received Task3 counter is **two unsuccessful Sol repair
validations**, specifically one full runtime failure and one formatter-preflight
failure. They are not two full runtime failures. Initial FAIL1 and diagnostic
FAIL1 are recorded separately and do not inflate that repair counter.

| Evidence | Actual outcome |
| --- | --- |
| `managed-probes-initial.json` | Initial runtime FAIL, exit1, 11 case and12 cleanup receipts; no final marker; all425 frozen hashes unchanged. |
| `managed-probes-diagnostic1.json` | Diagnostic runtime FAIL, exit1, 11 case and12 cleanup receipts; unchanged exact assertions with improved primary/cleanup reporting; all425 hashes unchanged. |
| `managed-probes-contract1.json` and `.log` | First actual Sol repair full runtime FAIL, exit1, 24 cases and25 successful cleanups, no final marker, all425 hashes unchanged, no owned peer remaining. Abnormal-retirement and actual-deadline cases passed before the new failure. |
| `managed-preflight-repair2.json` and `.log` | Second actual Sol repair validation FAIL, exit1, zero tests. `set -e` stopped on the explicit fixture format check before compile/tests; no repair2 runtime was executed. All425 hashes unchanged. |

The runtime failure was `ArgumentError: 1st argument: invalid destination` at
`:erlang.send("", {:read_chunk, ..., :ack})` in the unchanged historical
`HTTPFetchPublicProbe.consume/3:180`. Positive256 HEADERS END_STREAM produces
the documented empty binary response; the previous fixture sent it to a PID-only
helper. Sol repair2 had already corrected dispatch: exact status200/body `""`
for the empty variant, exact status200/stream PID and `bounded` content for the
nonempty variant, followed by unchanged exact-ok original completion.

The remaining failure was precisely the missing blank line between that local
`if body ... end` and `Peer.complete(completion)`. The recorded formatter diff
adds line816 only. This recovery used the authorized formatter to add that blank
line; it did not modify dispatch or assertions. Removing the one added blank
line reproduces incoming probe SHA-256
`f6a6f92a06fa84a95f83574e531256e5623f26236528f0a27922f5aa200b65c7`
exactly. This is stronger preservation evidence than selectively checking a few
assertion strings.

## Preserved specification and task diff

The complete probe outside that one blank line is byte-identical to the incoming
independently reviewed fixture. Thus the39-case runner, positive256 exact empty
versus bounded-stream responses, four exact257 fragment-loss variants per H2
profile, sibling/independent-scope behavior, deadline bounds, raw-wire barriers,
capacity/no-extra-accept, zero-ledger replacement and no-replay assertions remain.
Normal/deadline/graceful completions still require exact `:ok`. H1 abnormal
completion remains exact `:ok`; H2 scope-abort/creator-death permits only the
documented `:ok` or `{:error, :cleanup_unconfirmed}`, with concurrent/repeated
waits and cleanup required to preserve the exact observed outcome. Fragment
owner-loss completion remains exact unconfirmed. No expectation was weakened.

The existing canonical capacity error `MISMATCH` and issue#89 TODO/WORKAROUND
comments remain separate from resource-property results. TLS mismatch was
confirmed by contract1; h2c was not reached. Parent routing evidence is
`docs/dependency-requests/http-fetch-managed-capacity-error.md`; this recovery
performed no upstream action or network verification.

Only three files were written:

* `integration/http_fetch_contract/managed_transport_probe.exs`: one blank line.
* `integration/http_fetch_contract/MANAGED_README.md`: current formatter/runtime
  distinction and counters, pending full verification, and correction of stale
  "source observation only / issue routing pending" wording for parent-routed#89.
* This new handoff.

Neither the peer nor historical helpers needed editing. The423 other entries
in the425-file repair2 source map remain hash-identical; only the owned probe
and README differ. The prior H1 architecture memo remains hash-identical.
A first README patch had an unmatched context and made no change; a corrected
context applied the documentation update. This was not an additional executable
repair or validation round.

## Executed checks and limits

The only Mix commands executed, in sequence in the granted slot, were:

```sh
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; unbuffer mix format integration/http_fetch_contract/managed_transport_probe.exs'
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; unbuffer mix format --check-formatted integration/http_fetch_contract/managed_transport_probe.exs'
```

Both **PASS, exit0**. Each emitted only the expected Nix warning that this
worktree is dirty. Formatter session3659 and check session67330 both completed;
neither remains running. No peer or application runtime was started.

Python standard-library static checks **PASS, exit0**:

1. Remove exactly the single blank line, reconstruct the incoming hash and
   retain the exact `39 = Process.get(:managed_case_count)` runner assertion.
2. Verify unchanged `managed_peer.py` and `pooled_completion_probe.exs` against
   the independent repair2 review's hashes.
3. Compare all425 repair2 frozen source entries: exactly the two owned existing
   files changed, all423 other entries unchanged; verify prior H1 architecture.
4. Validate final document whitespace, local evidence references and hashes
   during final handoff checking.

Compile, unit tests, complete strict preflight, full39-case network runtime,
soaks and activation: **NOT RUN in this recovery**, per the assigned boundary.
Formatter PASS does not turn any historical FAIL into PASS. Parent must obtain
a renewed source freeze and independent Sol delta review, run the complete
strict preflight, then the serialized fixture. Runtime acceptance still requires
39 case receipts,39 successful cleanup receipts, final marker, exit0, stable
before/after source hashes and no owned peer left. Canonical#89 compliance and
H2#86/retained-byte qualification remain separate gates.

## Provenance, counters and return

Installed coordinated seven-package cohort0.21.0, containing tag
`9813c126dc8b48055b9ee941c693fc27fa691489`. Parent receipts
`release-provenance.json` and `installed-provenance.json` record matching196
artifact files and175 runtime Git blobs. The prior independent readiness review
`managed-probe-review-repair2.md` passed source specification/code review, not
the later formatter preflight or full runtime. Its reviewed hashes matched the
incoming files; its historical counter statements are not rewritten.

Task3 cumulative counters now: received Sol unsuccessful repair validations2
(full runtime1, formatter-preflight1); Astra recovery rounds completed1 of2,
authorized formatting/static validation PASS, Astra unsuccessful rounds0.
Initial runtime FAIL1 and diagnostic runtime FAIL1 remain separate. Task1 Sol2
failed/Astra1 PASS and Task5 Sol4 total with2 unsuccessful/Astra2 total with1
unsuccessful are unchanged. This handoff does not reset or grant repair budget.

All recovery commands have finished; no process shutdown or intervention was
needed. No compile/test/network/runtime command, dependency/lock edit, private
API, upstream mutation, product integration, commit or publication occurred.
The writer stops here. Parent/Sol owns fresh independent review and verification;
any newly exposed runtime defect must preserve these cumulative counters and
be routed within the remaining authorized recovery budget. No user decision is
required for this completed bounded formatting correction.

| Evidence/file | SHA-256 |
| --- | --- |
| Probe before | `f6a6f92a06fa84a95f83574e531256e5623f26236528f0a27922f5aa200b65c7` |
| Probe after | `82c066013c24d29da469f1ec5b24be8321d17810f85b41ea37c8a274eb7547d2` |
| README before | `8ead3963a5172186f2e36885bd611cbe16f4c46b57bd821517da05dcb147fef9` |
| README after | `2331ea0d00d804649e23363741412be796838047151ad81f4fdf541931008157` |
| `managed-probe-review-repair2.md` | `becce4c99a245438e008a1887df9f0cced955f572251bf73d7b5c02ad3837f2a` |
| `managed-preflight-repair2.log` | `bc06c3ec887017698e8f053248ae1b8859b0d402ee9c8c580ac45f7c58a6f7c6` |
| `managed-preflight-repair2.json` | `e7ea33ef5df46ecd8cb31461b6fa7d5709f31d340c8c4d860484fd1d47866d24` |
| `managed-probes-contract1.json` | `7f9b3e112c43a9b4cc311661e3a78143f580813e81cacb473dc9e1aa07f5fc20` |
| `installed-provenance.json` | `9093ec0c1dda7bdf22f46ddd7546fe6e337a6dfbfe444a501638c8ec8233918c` |
| `release-provenance.json` | `49a3260c9f3d1c19a92d016941feb7ba768c9e6466a2513382b651451f3c6148` |
| `h1-accounting-architecture.md` unchanged | `6ac9a051172e761717da3be3861566740724ff5507601314ea332e1a36bebe81` |
