# Task 5 S5 bounded recovery

Status: DONE for bounded recovery; parent independent specification/quality gates remain pending.
Mode: implementation, authorized execution. Gate: SOL_REPEATED_FAILURE.
Repository/worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`.
Branch: `codex/m3-gateway`.
Baseline HEAD: `22b76e8051ddaf09e36797cb781b9b119870a9d4`.

## Handoff and preserved state

Read `member-limits-handoff.md`, both failed production logs, current source/tests,
the group design, and the independent S5 fixture adjudication in
`../final-spec-review.md`. The three source/test SHA256 values exactly matched
the frozen handoff before edits. The parent confirmed exclusive ownership of
the assigned three files and the serialized Mix window; the predecessor's
commands had finished. The checkout already contained extensive tracked and
untracked M3 work. All unrelated edits and historical evidence were preserved.

Received counters: cumulative Task 5 Sol 4 validations, 2 unsuccessful; Astra 0.
S5 Sol failure 1: compile collision, private/public `cancel/1`, exit 1, zero tests.
S5 Sol failure 2: 26 tests / 2 failures, exit 2, seed 107342.

## Root cause and bounded change

Both remaining failures were incorrect fixture expectations. No production file
was changed by Astra.

- `HTTP.Session.apply_limits/2` intersects member/common limits, anchors lifetime
  to the original `started_at`, and anchors opening to cleanup activation.
  The selected limits and absolute deadline reach the pump in `:ready`.
- `HTTP.dispatch/2` clips Exchange lifetime and write timeout. Upload writes use
  effective limits; downstream `Exchange.send_window/2` rejects sends once the
  absolute deadline has expired. Therefore the 80 ms lifetime test must require
  exact empty response followed by EOF within its existing 500 ms bound. A late
  504 would violate the accepted deadline. Opening expiry still requires 504
  because its independent 2000 ms total budget remains live.
- The write fixture peer sends `Content-Length: 5`. Its wire assertion now
  requires exactly `HTTP/1.1 200 OK`, `connection: close`, `content-length: 5`,
  and `hello`, with no extra bytes, chunks or trailers.
- `Session.upstream_fail/2` treats expired total/request timeout as cancellation;
  `mark_cancelled/1` preserves an already-recorded failure. Public client cleanup
  precedes selection finish and Service completion.

Only the two wire assertions and formatter-required surrounding blank lines
changed in `upstream_group_member_limits_test.exs`. Preserved assertions verify
peer EOF, actual socket `send_timeout: 80`, effective ready metadata/deadline,
opening failure health, intentional lifetime/idle health, group inflight zero,
Service active/retained bytes/cleanup pending zero, and final resource release.
Health checks still use `failure_threshold: 1`; no timeout bounds increased.

## Verification

All commands ran through pinned `nix develop --command bash`, with
`MIX_ENV=test`, `ERL_FLAGS='+S 2:2'`, `set -euo pipefail`, and `unbuffer mix`.
Outer pipelines used `bash -o pipefail`, `tee`, and recorded `VALIDATION_EXIT`.
Environment: Elixir 1.18.5, Erlang/OTP 28, ERTS 16.4.0.6.

1. Astra round 1, `member-limits-astra1-scoped.log`: FAIL, exit 1, zero tests.
   `mix format --check-formatted` required two blank lines around the new
   multiline assertion. Strict compile/tests were NOT RUN in this attempt.
   Conservatively counted as an unsuccessful repair-and-validation round.
2. Astra round 2, `member-limits-astra2-scoped.log`: PASS, exit 0.
   Formatted only the owned test; format check passed on all three owned files.
   `mix compile --warnings-as-errors` passed.
   `mix test apps/gaoxy_proxy/test/upstream_group_member_limits_test.exs
   apps/gaoxy_proxy/test/http_proxy_runtime_test.exs
   apps/gaoxy_proxy/test/upstream_group_proxy_test.exs
   --warnings-as-errors --max-cases 1 --seed 107342` passed:
   **26 tests, 0 failures**, including all four new member regressions.
3. Same round 2 compatibility validation, `member-limits-astra2-proxy.log`:
   `mix test apps/gaoxy_proxy/test --warnings-as-errors --max-cases 1 --seed 107342`
   passed: **156 tests, 0 failures**, exit 0, 26.4 seconds.
   Relevant existing pump, wire, group, TLS, completion and probe tests ran.
   `git diff --check` on both owned production files passed.

Final SHA256:

```text
6650ed1169c8284be4e87a08341a747c475994f2bce6194eda48867c2e158615  apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex
c1e123186e089adfc8a86490227cb72d1545c1c7d169a1686549ba0fdb1c4375  apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex
8baf673c888b6f6c0c618f8b6ce73c632753d53107852a0e7efc666513855c62  apps/gaoxy_proxy/test/upstream_group_member_limits_test.exs
```

## Frozen return

Cumulative Astra rounds: 2, of which 1 unsuccessful formatting gate and 1
successful validation round. Received Sol counters remain 4 total / 2
unsuccessful. No further recovery edits are authorized within this budget.
All command sessions (38852, 26997, 12202) finished, exits 1, 0, 0; no owned
command remains running. File ownership and the Mix window return to the parent.

No unresolved S5 finding was observed in this bounded trace and validation.
Independent final reviews and canonical whole-M3 acceptance are parent-owned
and NOT RUN here. No commit, push, publication, deployment, dependency change,
or production acceptance claim was made.
