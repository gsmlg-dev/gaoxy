# Independent overall G1 review resolution

Reviewer `/root/m4_connection_integration`, 2026-10-12. Task
`m4_task2_connection_overall_resolution`, direct independent Sol review. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m4-http3`, branch `codex/m4-http3`,
current HEAD `650a8015832580120688f53e0f4235432cb22a9d`; original M4 baseline
`78de9d0f3bba5a4662717359438eb3d0853a79b4`. Parent authored the Options repair
and regression. This reviewer authored none of the reviewed runtime/test source,
changed only this receipt and ran no Mix/network command during parent's lease.

## Specification verdict: PASS — G1-1 closed

The original whole-Connection review is preserved unchanged at
`connection-overall-independent.md`, including its FAIL verdict and sole P1
finding. Its SHA-256 is
`0ee35f8968a8f2598126446a38fa4f1a165aff121aadcacf77c4491c4ba00e38`.

The one-line guard in `Options.budget/2` now requires
`h3.max_pending_output >= http.max_read_chunk + 32`, exactly matching the fresh
bidi owner's minimum input credit assumed by `Connection.receive_stream/2`.
The check executes after pure normalization with `initialized: true` and before
the subsequent endpoint initialization. Thus inconsistent limits fail with
`{:error, :http3_byte_budget}` before endpoint initialization or service
activation. The generic shared HTTP limit contract and Connection read/FIN/
uncertain-operation behavior are unchanged.

The new Options regression covers both original counterexamples: 16384-byte
pending output with default 16384-byte read chunk, and default output with a
65536-byte read chunk. Both must fail without `:initialized`. It also accepts the
exact 16416-byte boundary, asserts equality to read chunk plus framing allowance,
and observes exactly one endpoint initialization. This proves rejection and the
boundary semantics requested by G1-1 rather than masking the issue by changing
fixture defaults. Parent's expected red log demonstrates the original accepted
16384-byte configuration, then **9 tests / 1 failure**, exit 2. Current recorded
green contains **78 tests / 0 failures**, exit 0.

This resolution closes the only actionable finding from the independently
reviewed whole G1 Connection. Its specification review is therefore PASS for
the bounded fixture profile, subject to the required parent post-review fresh
affected-unit and full independent-peer gate. Those runs remain **NOT RUN** by
this reviewer and are not inferred from the reviewed pre-resolution 47-case run.

## Code-quality verdict: PASS

The repair changes one existing budget predicate and adds one focused regression.
It has no runtime Connection/protocol edits, public signature changes, dependency
changes, private API workaround, assertion weakening or unrelated cleanup.
Rejecting a reservation the current owner cannot support is the smallest
compatible implementation choice and matches the specified inconsistent-budget
validation. Existing output ceilings, framing allowance, input-credit guard,
uncertain-write freeze and absolute deadlines remain intact. No unresolved
actionable findings remain from the whole Connection review or this resolution.

## Exact inputs and evidence checks

Fresh read-only Python verification compared the current repair/lock hashes to
`options-credit/execution.json`, checked SHA-256 of all three execution logs,
parsed actual unit counts **2/0 plus 76/0**, checked the expected red **9/1**, and
confirmed Connection plus both owned tests remain byte-identical to the original
whole review. All checks passed and the original FAIL receipt remains intact.

| Path | SHA-256 |
| --- | --- |
| `apps/gaoxy_http3/lib/gaoxy/http/http3/options.ex` | `00c1832ee7a946c90d42aa82b8abffe7424062a9e078b84884837a9dfb1dcd18` |
| `apps/gaoxy_http3/test/options_test.exs` | `6bc199efc5aeb56f01819a717f94186a415133d6d68692aefd218cef0cc8f1ef` |
| `apps/gaoxy_http3/lib/gaoxy/http/http3/connection.ex` | `81b1d2081aaeb363120d6c68f1a00ab95f4ee54dac8406ba59b8ef104d851008` |
| `apps/gaoxy_http3/test/connection_test.exs` | `63e110336373501259a4b3b2f1ae35a508b0164094bbe969cd78fb1cc647361b` |
| `apps/gaoxy_http3/test/lifecycle_test.exs` | `290d85e877f43c9a1c6f9b36bdb2128e20e5ed714a87ceb498895de5f154422c` |
| `mix.lock` | `16542ddd554f9b78139ddf456288450a12da5781cf3900576edd7e83f159dc25` |

The inspected execution receipt records exact-file `mix format
--check-formatted`, `mix compile --warnings-as-errors`, and `python
scripts/check-tests.py` over Options/protocol/headers/QPACK/service/Connection/
lifecycle and the H3 shared-adapter guard, all exit 0. Logs match their recorded
digests. Recorded runtime is the parent's selected Nix Elixir/OTP environment;
this reviewer performed source/log inspection rather than execution of that
runtime. Full original G1 evidence remains in the original whole-review receipt,
with its FIN/open peer observation explanation and explicit unknown-operation
fault-injection limitation unchanged.

Cumulative Options counters remain **Sol4 / unsuccessful1 / Astra0**; Connection
counters remain **Sol2 / unsuccessful2 / Astra1 / unsuccessful0**. This review
adds no repair round. All reviewer commands completed; no process or Mix/source
lease remains owned. Parent owns post-review fresh verification, commits and
stage progression. G2 runtime changes, browser/proxy/upstream/standalone, hosted
CI, publication, deployment and production acceptance are not qualified here.
No user decision or external permission is needed; no dismissed issue97 proof
was reintroduced.
