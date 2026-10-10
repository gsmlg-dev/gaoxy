# Managed 0.21 recovery1 independent delta review

Task: `m3_managed_contract_review`, bounded independent Sol review of completed
Astra recovery1. Reviewed 2026-10-11 Asia/Shanghai in
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline/HEAD
`4cc7a1a967d1b90a62d42db438316b10a03a1e16`. This reviewer authored neither
executable fixture nor recovery. Own only this new report; prior reviews,
handoff and all other writers' changes remain preserved.

## Specification delta verdict

**PASS for recovered fixture/documentation readiness.** Fresh SHA-256 checks
match all supplied final identities. The entire executable delta from the
independently reviewed repair2 probe is one blank line at Probe816, following
the positive-fragment `if body` branch and preceding exact request completion.
Removing only that blank line reproduces the incoming SHA-256
`f6a6f92a06fa84a95f83574e531256e5623f26236528f0a27922f5aa200b65c7`.
Every executable byte outside that line is unchanged. This resolves the exact
formatter diff recorded in `managed-preflight-repair2.log`; it changes no behavior.

The prior `managed-probe-review-repair2.md` specification/code-readiness verdict
remains applicable to the unchanged functional assertions. Status200/exact
empty binary and status200/PID/exact bounded stream still converge on exact-ok
request completion and strict generation/peer cleanup. The39-case runner,
four257th-frame variants per H2 profile, exact unconfirmed fragment completion,
scope/sibling isolation, public zero-ledger replacement, no replay, raw partial
request-byte barriers, no-extra-accept, deadline windows and exact original
completion cleanup equality remain byte-identical. Abnormal H1 completion stays
exact ok; H2 abort/creator-death stays restricted to exactly ok or unconfirmed,
with concurrent/repeated/cleanup waits pinned to the original observed outcome.
The canonical H2 capacity MISMATCH and issue89 comments remain unchanged.

Fresh comparison against `managed-source-before-repair2.json` covers all425
entries: only probe and README differ; all423 others match. Managed peer and
historical completion-helper hashes separately match the prior independent
review. No broad dependency/source investigation was repeated for this delta.

README3–6/31–34/185–194 accurately distinguishes contract repair1 runtime FAIL
from repair2 formatter-preflight FAIL before compile/tests/runtime, and limited
Astra formatting/static PASS from full verification pending. It records Sol
unsuccessful repair validations2, comprising runtime1 and formatter-preflight1;
initial FAIL1 and diagnostic FAIL1 remain separate. Astra recovery1 of2 is
completed with full runtime pending. README22 retains the correct public source
function name. README99–106 correctly records parent-routed TLS Bug89 mismatch
as runtime-confirmed, with h2c not reached/unverified in that failed run. Failed
receipts and prior readiness reports remain historical evidence, not rewritten
success claims. No actionable specification/reporting finding remains.

## Separate code-quality delta verdict

**PASS.** The one-line formatting correction is exactly the recorded canonical
formatter requirement and introduces no executable change, new abstraction,
dependency or process. Documentation now keeps actual failures, limited checks,
pending runtime and cumulative counters explicit. No new actionable quality
finding was found.

**Runtime NOT RUN by this reviewer.** The handoff reports canonical scoped
formatter and format-check exit0; this reviewer did not rerun Mix. Complete
strict preflight,39-case runtime, retained-byte accounting, soaks, Gaoxy
activation/integration and full M3 acceptance remain unqualified by this review.
Prior shutdown/reporting limits are unchanged: individual waits are finite,
not a single global watchdog; a helper assertion can precede joining; failed
peer stop does not independently force-kill the subprocess. Root must obtain
39 case receipts,39 successful cleanup receipts, final marker, overall exit0,
stable frozen before/after hashes and no owned peer remaining under bounded
serialized execution. A case receipt alone cannot qualify its enclosing cleanup.
Canonical issue89 compliance and H2 issue86 remain separate gates.

## Fresh checks and handoff

Python standard-library validation exited0: six exact input hashes; single
blank-line816 reconstruction; entire425-file map comparison; exact39 runner
and MISMATCH retention; README status/counter checks. Read the immutable-hash
recovery handoff and formatter-preflight receipt/log; report whitespace and
final source stability were checked before handoff. No Mix, network, fixture,
application, executable/dependency/lock edit, commit or upstream action ran.

Task status **DONE for independent readiness review**. Reviewer Sol repair
rounds0; cumulative Task3 unsuccessful Sol validations2 (runtime1/formatter1),
received Astra recovery1 of2 completed, Astra unsuccessful recovery0; full runtime
pending. No new escalation gate, design decision or user permission is needed.
All reviewer commands finished; no reviewer runtime session/process was started
or remains. Task diff is only this new report. Root owns renewed freeze,
complete preflight and serialized execution with preserved cumulative counters.

| Reviewed input | SHA-256 |
| --- | --- |
| `integration/http_fetch_contract/managed_transport_probe.exs` | `82c066013c24d29da469f1ec5b24be8321d17810f85b41ea37c8a274eb7547d2` |
| `integration/http_fetch_contract/MANAGED_README.md` | `2331ea0d00d804649e23363741412be796838047151ad81f4fdf541931008157` |
| `integration/http_fetch_contract/managed_peer.py` | `319e9c9f2832ddf2ab9cc84aedd519bfe33f36e2152d24bb47bf5fcde8169d79` |
| `integration/http_fetch_contract/pooled_completion_probe.exs` | `f681723ff58754cb6169d0b42fb681a8439eeaa6c7ec7e94c752894405ce1e30` |
| `managed-recovery1-handoff.md` | `61a50d703d516eb12c1ea5c3974039803f0b5d8db88bf9fd770cc7fa3c034d6c` |
| Prior `managed-probe-review-repair2.md` | `becce4c99a245438e008a1887df9f0cced955f572251bf73d7b5c02ad3837f2a` |
