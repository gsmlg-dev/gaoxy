# R1 execution plan

1. Capture the existing single-piece Plug failure with buffered H1 and deterministic
   transport regressions. Check options, exact/unknown boundaries, cumulative
   limits, finite waits, no progress and admission ownership.
2. Aggregate only in PlugAdapter, adding the Exchange accounting field and an
   additive per-socket timing mode while preserving native bounded readers.
3. Exercise real Plug.Parsers JSON/form bodies above 16 KiB over ordinary H1/H2/H3
   listeners, parser length rejection, and chunked H1 followed by another request.
4. Run focused existing native/body/accounting compatibility tests, scoped format
   and strict compilation. Record exact counts/exits in bounded audit logs.
5. Submit the final source and evidence to the integrator for independent review.

Baseline: `4f90967e06b906f3a862ec1541b1c4dd79bee83a`, worktree
`.trees/correctness-patch`, Elixir 1.18.5 / OTP 28.5. Initial regressions executed
16 tests with 11 expected failures; the first implementation executes the same
16 tests with zero failures. Logs: `.audit/review-repairs/track-a/red.log` and
`green1.log`. Native socket/deadline and real protocol verification follow.


## Final worker verification

Source base at kickoff: `4f90967e06b906f3a862ec1541b1c4dd79bee83a`. Shared
integration base at final verification: `4e0f4c0a7cf1b228af1cb1e6d25df58973255247`
plus task-owned working changes; other tracks' edits are preserved.

- `red.log`: 16 deterministic tests, 11 failures, original adapter behavior.
- `green1.log`: same 16 tests, 0 failures after aggregation.
- `network1.log`: real H1/H2 parser checks passed, H3 1/0; deterministic fixture
  teardown races failed after assertions. New fixture uses ExUnit supervision.
- `network2.log`: 23 HTTP tests, one newly captured unsupported-tunnel regression;
  H3 1/0. The additive timing mode now retains the original tunnel guard.
- `compatibility.log`: HTTP 66/6, complete H2 constructor-envelope assertions
  exposed the new field's missing numeric accounting; H3 14/0. Adding exactly
  `adapter_body_bytes: e(0)` repaired production accounting; tests unchanged.
- `compatibility2.log`: HTTP 66/2, only pre-existing teardown races in
  ConnectionPollTest and NativeProxySeamsTest; H3 14/0.
- `review-red.log`: 22/3, review lifecycle findings captured before repair.
  The stopped-gate fixture was corrected to avoid terminating an admitted owner.
- `review-green.log`: 22/0, structured stale/closed errors and bounded adapter
  admission waits, including deferred restoration after gate resume.
- `native-deadline-red.log`: 23/1, confirmed a delayed native retention update
  after adapter reservation still used the old 5-second call timeout.
- `review-final.log`: HTTP 70/2, only existing teardown races (dead gate stop and
  dead PID trace); H3 14/0. All new tests passed. Parent owns fixture repairs.
- `task-final.log`: PASS, HTTP 27/0 (23 deterministic + 4 network), H3 1/0.
  H2/H3 peers each executed JSON and form acceptance plus actual parser length
  rejection. `format-final.log`: PASS, scoped canonical formatting, exit 0.

All commands use `ELIXIR_ERL_OPTIONS='+S 4:4'`, the qualified `unbuffer`, and
`flock .audit/review-repairs/mix.lock`. Final tests use `--seed 0 --max-cases 1`;
H3 uses the provisioned `.audit/h2peer/bin/python` via `GAOXY_QUIC_PYTHON`.
Exact final test argv: `mix test apps/gaoxy_http/test/plug_body_test.exs
apps/gaoxy_http/test/plug_body_network_test.exs
apps/gaoxy_http3/test/plug_body_network_test.exs --seed 0 --max-cases 1`.

Repair history remains cumulative: initial expected TDD failures; fixture
ownership correction; tunnel compatibility guard; production complete-ETF
constructor repair; independent-review stale/dead gate and adapter admission
repair; native body admission deadline repair. No failed assertion was removed,
no existing compatibility fixture edited by this worker, no Astra recovery used,
and no commands remain running. Independent re-review and parent's fresh shared
compatibility checks are the remaining integration steps; no commit performed.

The final H2 read-owner follow-up is recorded in `h2-deadline-red.log` (24
regressions, 1 failure: suspended owner returned `closed` after the old extra
100ms) and `task-final2.log` (PASS: HTTP 28/0, H3 1/0). Only H2 `{:read, _, _}`
operations now use the immutable deadline directly and report `timeout`;
send/poll operation behavior is unchanged. `format-final2.log` is PASS, exit 0.
The required deterministic file count is now 24 (plus network 4 and 1). The
parent owns the two existing compatibility fixture teardown repairs and their
fresh checks; this worker did not edit either shared fixture file.

## Read-triggered Continue follow-up

Independent final review reopened ordinary Expect input: H1's old Continue
sender entered generic 5-second Admission calls and H2's informational head kept
the extra call slack. `continue-red.log` captured 26/2 failures; the first narrow
fix passed 26/0 in `continue-green.log`. The known-token late-registration test
then verifies exact-token cleanup and a known `not_submitted` outcome.

A configured write cap must still apply to Continue. The first tiny-cap fixture
had a Kernel.send import compile error (`continue-cap-red.log`); fixing only the
fixture produced the intended 25>4 regression (`continue-cap-red2.log`, 28/1).
The Continue-specific sender now emits per-cap pieces with per-piece Admission
operations. Generic response and poll policies are unchanged.

`continue-final2.log`: PASS, HTTP 75/0 and H3 14/0 (89 tests), including all
28 deterministic Plug tests and ordinary H1/H2/H3 parser rows. The parent-owned
compatibility fixture teardown repairs are included in this fresh passing run.
`continue-format.log`: scoped formatting PASS, exit 0; scoped diff check PASS.
The parent should use deterministic file count 28 in its final repair gate.
This follow-up used no Astra recovery, dependency change, or specialist suite.
