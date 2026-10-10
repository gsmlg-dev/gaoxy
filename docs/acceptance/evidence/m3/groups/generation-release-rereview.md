# Generation post-publication release re-review

Reviewer `/root/upstream_cleanup`, 2026-10-10. Direct read-only assignment to
independently review the parent's Generation receipt/reconciliation repair.
Worktree `.trees/m3-gateway`, branch `codex/m3-gateway`, baseline
`22b76e8051ddaf09e36797cb781b9b119870a9d4`, with preserved shared M3 changes.
No production/test edits, Mix commands, commits or publication by this reviewer.
Only worker-owned evidence/checklist documents are writable for this assignment.

## Specification review

No actionable finding in the narrow repair. The old implementation published a
router then synchronously released all old baseline pins before replying. Up to
64 bounded provider calls could therefore consume the caller's receipt budget
after the compare-and-swap had already committed.

The current `Generation.Store.handle_call/3` checks the absolute deadline, CAS,
empty retired sidecar and compiled bounds before acquiring candidate baseline
pins. It rechecks the deadline immediately before publication. On success it
publishes the router, records the old pins and returns the activation reply
without invoking a provider release. A late-acquired candidate remains
unpublished and its pins enter the same bounded retired queue.

One `:reconcile_resources` dispatch releases one pin. Confirmed release removes
it; an uncertain release rotates it to the tail with a 100 ms retry delay.
Further activation still returns `:resource_release_pending` while any retired
pin remains. Only the current router and at most one old bounded sidecar are
retained. Existing request pins continue protecting admitted old snapshots.
This matches `docs/designs/m3-upstream-groups.md`'s receipt and reconciliation
policy; it adds no pooling, upstream H2 or dependency-private operations.

## Quality review

The repair uses the existing owner and generic provider boundary. The GenServer
returns `{:reply, ...}` before handling the scheduled reconciliation message,
so provider latency cannot delay that committed reply. Scheduling begins only
when a nonempty retired queue is created; each subsequent dispatch schedules
one continuation while work remains. The queue is not discarded on callback
failure. Shutdown still attempts to release both baseline and retired pins.

The new regression holds the old provider release while requiring
`Generation.activate(..., 50)` to return the new generation. It then unblocks
release and verifies the published snapshot and zero remaining pins. The
controlled provider barrier establishes ordering without an arbitrary sleep.

Two existing fixtures previously asserted metadata release immediately after
the activation receipt. The parent changed only those synchronization points
to the existing finite one-second `eventually` helper: late-acquired candidate
pin count must still become exactly zero, and the old group must still become
exactly `:retiring` before the paused old request proceeds. Exact old/new peer,
stale-group, pin and router assertions remain intact. These are asynchronous
contract updates, not weaker lifecycle expectations.

## Actual evidence

Freshly read logs/artifacts, rather than inferred success:

| Evidence | Outcome |
| --- | --- |
| `activation-release-deadline-red.log` | Expected TDD red: 1 executed/1 failure, seed 1281; caller received `:generation_unavailable` while the old release was held |
| `activation-release-repair1.log` | FAIL overall: HTTP 22/1, proxy 20/1, server 18/0, seed 618354. New receipt regression passes; immediate-release fixture assumptions fail |
| `activation-release-fixture1-rfc.log` | PASS for Generation/group/server scope: HTTP 22/0, proxy 20/0, server 18/0, seed 806307; enclosing parent command exit 0. Followed by 39 historical RFC tool PASS records |
| `../h2-rfc-fixture1/results.json` | Historical selected RFC tool checkpoint: 39 executed, exit 0; `runtime_down: true`, `port_rebound: true`; Generation source hash matches this review. Subsequent independent review found a wrong PRIORITY-length expectation, so this is not final RFC acceptance |
| Reviewer `git diff --check` | Exit 0 |

Parent confirmed validation session `23961` exited 0. The command scope was
formatting the two changed resource/group proxy fixtures, strict compilation,
then `mix test --warnings-as-errors --max-cases 1` for
`apps/gaoxy_http/test/generation_test.exs`, `generation_resources_test.exs`,
`generation_loader_test.exs`, `generation_release_deadline_test.exs`,
`apps/gaoxy_server/test`, and the four `apps/gaoxy_proxy/test/upstream_group*`
files. It then invoked `python3 integration/h2_rfc/run.py --evidence
docs/acceptance/evidence/m3/h2-rfc-fixture1`. Environment was the pinned
`nix develop` shell with `MIX_ENV=test` and `ERL_FLAGS='+S 2:2'`. The complete
shell spelling is not embedded in the log; these are the confirmed command
scope and flags, rather than a claimed byte-for-byte transcript.

The independent final reviewer's RFC PRIORITY-length correction needs its new
40-case run. It does not reopen this Generation receipt finding. Parent owns
the subsequent exclusive Mix window; the reviewer did not poll, stop or alter
parent command sessions.

Reviewed source/test SHA-256:

```text
b4318cda8dc312984fbcc61b6d148727ed4ed98af8c9e9a22d34904be2a33f2a  apps/gaoxy_http/lib/gaoxy/http/generation.ex
e31674b1703f566c23fbea31ba185144e910cc730fde780b3061498048e56225  apps/gaoxy_http/test/generation_release_deadline_test.exs
8153e748b1815e7984401408d5705c197af9cecde1c2e40dd19418e6d88a2444  apps/gaoxy_http/test/generation_resources_test.exs
9b94462d2c541e476db45dd793e6809aadab39d87f720894b0dc63e0da575f11  apps/gaoxy_proxy/test/upstream_group_proxy_test.exs
```

Counters remain separate: worker cumulative Sol repair/validation rounds 2,
both successful; worker unexpected production behavioral repairs 0; Astra 0.
Parent release work comprises production repair 1 and fixture contract update
1; the initial failing validation is preserved above. No third worker repair
was performed or authorized.

Status: PASS for this narrow Generation receipt specification and quality
re-review, supported by the new regression and passing scoped command. The
separate final independent Task 5 review
remains open; this document is not full Groups/M3, hosted CI, publication,
deployment or pooling/upstream-H2 acceptance. All reviewer commands finished.
