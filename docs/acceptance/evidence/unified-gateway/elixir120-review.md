# Independent Elixir 1.20 compiler compatibility review

Task: unified-listeners-embedded-gateway / core_lifecycle compiler followup.
Assignment: direct read-only review; this audit file is the only edit.
Worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/unified-gateway
Branch: codex/unified-gateway
Patch baseline: 14c5fd9125a511e7f664b4761323387d9783b633.

## Verdict

PASS, no actionable findings. Removing the two unreachable outer with-else clauses preserves all reachable reload results and addresses the evidenced compiler diagnostic without suppressing warnings or changing tests.

## Root cause and complete failure-shape analysis

.audit/unified-pr-static-failure.log records the actual PR4 macos-15-intel / Elixir 1.20.1 / OTP 29.0.2 strict compilation failure. The compiler identifies the outer nil clause as never matching and the later catch-all as redundant, then exits 1 under unchanged --warnings-as-errors.

Reviewed every outer generator of Gaoxy.Proxy.Gateway.do_reload_routes/4:

- timeout validation evaluates to true or {:error, :invalid_reload_timeout}.
- absolute deadline validation evaluates to true or {:error, :invalid_reload_deadline}.
- deadline = min(relative, supplied) is an ordinary variable binding, not a failing pattern. Earlier validations ensure both selected deadline inputs are integers.
- remaining-time validation evaluates to true or {:error, :reload_timeout}.
- expected revision validation evaluates to true or {:error, :expected_revision_required}.
- operation identity validation evaluates to true or {:error, :invalid_operation_id}.
- Declaration.routes/1 returns {:ok, routes} or {:error, :invalid_route_declaration}; its list and fallback clauses normalize all failed declaration checks to that error shape.
- control/1 returns {:ok, control} or {:error, :gateway_unavailable}; registry lookup mismatch and caught exits use that error shape.

Therefore every ordinary outer mismatch is a two-element {:error, reason} tuple, fully handled by the retained {:error, _} clause. Unexpected exceptions were never handled by nil/catch-all with-else branches and are unaffected. A successful {:ok, nil} control result, if authority disappears during lookup, follows the existing owned submission path and is also unaffected.

The actual missing ListenerSet lookup occurs inside the owned task. Its guarded store <- context.stores[set_id] remains paired with the inner nil -> {:error, :unknown_listener_set} branch. The public reload_routes/4 malformed/duplicate/unknown-options guard and :invalid_reload_options response remain unchanged. No reachable unknown-set or invalid-option path was removed.

## Diff and evidence

The production diff contains exactly two deletions in apps/gaoxy_proxy/lib/gaoxy/proxy/gateway.ex: outer nil and outer catch-all clauses. No tests, assertions, warning options, build flags, type suppression, dependencies or public signatures changed.

Commands actually performed: read git HEAD/status/current diff; inspect do_reload_routes, Declaration.routes, control and existing validation tests; read original hosted compiler failure and fresh local verification log; scoped git diff --check, exit 0.

.audit/unified-elixir120-compat.log contains fresh strict compilation of the changed Proxy source and Gateway/lifecycle execution: 20 tests, 0 failures, seed 0/max_cases 1. This is local evidence under the parent's environment, not a claimed fresh Elixir 1.20/macOS success. Parent will establish the new hosted outcome and refresh source/package receipts while retaining the failed run.

## Status and limits

DONE for the bounded independent source review. No root Mix commands or production edits performed by reviewer; all reviewer commands finished. Sol repair increment 0 for this review; parent owns the implementation repair and cumulative counters. No Astra gate/counter used. Remaining external verification: updated exact source on the previously failing hosted compiler job. No additional design decision needed.
