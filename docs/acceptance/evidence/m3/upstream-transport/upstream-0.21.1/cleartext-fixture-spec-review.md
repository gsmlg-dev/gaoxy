# Cleartext fixture specification review

Date: 2026-10-11. Task: bounded pre-implementation fixture specification review.
Assignment: direct Sol independent review. Verdict: **PASS for the specification
only**, with the implementation acceptance requirements below. No blocking
specification finding was identified. Fixture implementation, final code review
and runtime acceptance are **NOT RUN** by this reviewer.

## Scope and reviewed identity

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`.
Branch: `codex/m3-gateway`.
Baseline HEAD: `a6a210c720d4a0fa9b8fa5f485e5c07a825ad03c`.
Ownership is this new report only. The concurrent dependency-file edit and all
other new-cohort evidence are preserved. No authored plan, fixture, helper,
dependency or historical receipt was changed.

Reviewed the [cleartext plan](../../../../../plans/m3-upstream-0.21.1-cleartext.md),
the [containing qualification plan](../../../../../plans/m3-upstream-0.21.1-qualification.md),
and the concrete driver, helper and peer sources. The following hashes identify
the pre-implementation fixture inputs; they are not a future executable freeze.

| Input, relative to the worktree | SHA256 |
| --- | --- |
| `docs/plans/m3-upstream-0.21.1-cleartext.md` | `eeb4effe566dc33a9f099dc89552a511928932a248bb1fad8795389640287c0d` |
| `integration/http_fetch_contract/managed_transport_probe.exs` | `82c066013c24d29da469f1ec5b24be8321d17810f85b41ea37c8a274eb7547d2` |
| `integration/http_fetch_contract/README.md` | `747a89e0d9c745c278f678b60bf3aa425b6f698e37e6c4adfaf4268eb11676f7` |
| `integration/http_fetch_contract/MANAGED_README.md` | `637ec5f07d4cdcc1ac529f353d8f3878e3817086c84f99e1c75cf7cf2062425d` |
| `integration/http_fetch_contract/pooled_completion_probe.exs` | `f681723ff58754cb6169d0b42fb681a8439eeaa6c7ec7e94c752894405ce1e30` |
| `integration/http_fetch_contract/managed_peer.py` | `319e9c9f2832ddf2ab9cc84aedd519bfe33f36e2152d24bb47bf5fcde8169d79` |
| `integration/http_fetch_contract/upstream_peer.py` | `f2e40b0e72362f06b4c933b14f45d49e768b2133bee4281c4241bbd122d9b95f` |

## Profile and case-count assessment

The proposed selection reuses complete existing cases. Independent static
enumeration gives these counts:

| Existing group | Cases per selected protocol | Cleartext protocols | Default protocols |
| --- | ---: | --- | --- |
| `common` | 6 | H1, h2c | H1, TLS, h2c |
| `deadline` | 1 | H1, h2c | H1, TLS, h2c |
| `h1_extra` | 2 total | H1 | H1 |
| `h2_capacity` | 1 | h2c | TLS, h2c |
| `fragments` | 7 | h2c | TLS, h2c |

Fragments comprise two positive body variants, four negative nonempty/final
variants, and one shared-owner/sibling/independent/no-replay case. Therefore
cleartext is `2 * (6 + 1) + 2 + (1 + 7) = 24`; full is
`3 * (6 + 1) + 2 + 2 * (1 + 7) = 39`. These are static counts, not executed
test results.

Implementation must dispatch exactly `[]` to the default full driver and exactly
`["--cleartext"]` to the cleartext driver. Reject every other argument list,
including repeated or combined flags, before `Peer.start_apps()` or peer
creation. Share the driver body through a private helper, retaining the exact
39 and 24 completion assertions. Do not expose arbitrary protocol selection.
Report the selected profile and coverage explicitly.

Helper loading currently suppresses the historical helper runner with
`HTTP_FETCH_PROBE_LIBRARY`; retain its prior-environment restoration. Requiring
the helper does not call `Peer.start_apps()`. Inherited peer certificate/OpenSSL
and SSL-context creation is conditional on `protocol == "tls"`; selecting only
H1/h2c does not create a TLS peer. This is a static isolation assessment, not
proof of a runtime dependency fix.

## Assertion boundaries to retain

Every selected case keeps its existing wire counters, accepted-connection and
request counts, exact body bytes, no replay, deadline and retirement assertions.
Retain the GOAWAY/PING acknowledgement barrier, held admitted stream,
independent-scope progress, zero pending queue, and replacement only after the
public aggregate connection/request/preparing/resource ledger reaches zero.
Do not use private pool access or a timing-only substitute for these barriers.

`with_peer/2` currently records primary failures, attempts joined cleanup, and
rethrows the primary failure even if cleanup also fails. Cleanup attempts every
remembered scope and completion, pins each observed completion to its recorded
expected result, and requires peer `live_threads == 0` and exit status zero.
Retain both primary and cleanup diagnostics; a primary expected failure cannot
hide a cleanup failure.

Normal, deadline and graceful completion remain exactly `:ok`. Abnormal
abort/creator-death cases permit only `:ok` for H1, and only `:ok` or
`{:error, :cleanup_unconfirmed}` for TLS/h2c as already encoded. Concurrent and
repeated waits must return the identical recorded outcome. Fragment owner loss
requires exactly `{:error, :cleanup_unconfirmed}`. The cleanup aggregate's
allowed-result list is not permission to widen individual expected results.

## Required red and green evidence

First implement profile selection only, retaining the existing hard expectation
`{:error, :pending_capacity}`. Parent must freeze that revision and the installed
0.21.1 cohort before execution. The expected red result is the precise failure
of that old hard match after observing
`{:error, {:transport_scope_capacity, :connections}}`, with joined cleanup
confirmed. An earlier failure, arbitrary error or failed cleanup does not meet
this red acceptance condition.

If driver order is retained and every earlier case passes, static enumeration
predicts 16 completed cases before the h2c capacity failure and 17 peer cleanup
attempts including the failing case. This prediction is not a runtime receipt.
The incomplete red run must never be reported as a 24-case pass.

Then change only the obsolete capacity expectation and its current diagnostic
and report wording: hard-match the exact canonical tuple and require/record
MATCH. Remove the obsolete local workaround while retaining historical
MISMATCH receipts. Preserve rejection completion, no-request-byte observations,
independent raw-wire observations and progress, exact accepts/requests, held
body consumption, closed old connection and public zero-ledger replacement
checks. Green acceptance requires 24 completed cases, 24 successful joined
cleanups and exact canonical MATCH on the frozen installed cohort.

The implementer owns the probe and README's current invocation/status paragraph
only. That paragraph must distinguish historical 0.21.0 full-39 PASS/MISMATCH
receipts from the new 0.21.1 cleartext evidence and the TLS block. Do not relabel
historical `MANAGED_README.md` narratives or receipts.

## Freeze, limitations and verification

Parent serializes dependency mutation and runtime execution. Each red/green
freeze must identify the actual probe, `managed_peer.py`,
`pooled_completion_probe.exs`, inherited `upstream_peer.py`, installed seven-package
cohort and lock, runtime identities, Python h2 identity, profile, exact command,
exit, case count and cleanup results. This report does not establish artifact
containment or review the concurrent provenance reports.

TLS/full-39 qualification remains **BLOCKED on upstream #95** under the supplied
plan. A cleartext pass does not qualify complete M3, activate managed integration
or memory budgets, prove the memory ledger, qualify held preparing/connecting
saturation, or complete the #86 adversarial-backlog gate. Those obligations stay
separate even if all 24 selected cases pass.

Review verification is limited to source reads, independent static case
enumeration, SHA256 identity, report link/fence/whitespace checks and Git state.
No VM, Mix, compiler, network peer, dependency mutation, staging or commit was
performed. All reviewer commands completed; no reviewer background process
remains. Earlier no-match/wrong-path read selectors were corrected and are
selector diagnostics, not implementation repair failures. Cumulative Sol repair
rounds for this assignment: 0. Received Astra repair counter: none. No escalation
gate applies. No additional design decision is needed for this bounded change.
