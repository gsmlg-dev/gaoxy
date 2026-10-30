# ARB-CORE release drain recovery

DONE for the bounded implementation candidate. Independent candidate review,
fresh whole-goal qualification and delivery remain parent-owned.

Mode: implementation recovery. Gate SOL_REPEATED_FAILURE (documented Sol2 and
accepted Astra6 predecessor); cumulative counters now Sol2/Astra9. The user
explicitly authorizes additional repair rounds until 2026-10-30T02:09:44Z.
Repo existing main, HEAD bc8a5ef5199293ada3b432c2e2741070d3b2d115. Large pre-existing
adaptive integration preserved; task-only patch and before snapshots accompany
this report. No dependency, common Admission/Ledger, HTTP/H3, workflow/version,
protected smoke, retained inventory, or Git mutation was made.

## Root cause and repair

`red-stream.log` reproduces both actual admitted TCP and verified-TLS owners
terminating with `:draining` on `admitted-after-drain`, after positive initial
echo and listener-refusal barrier. StreamBridge's scalar begin grew the idle
app-state-only allocation; canonical growth correctly refused during drain.
The separate readiness-probe handle_connection failure was not the diagnosis.

StreamBridge reserves a typed connection with bounded completion funding before
handler init. Service establishes default raw receive buffer/recbuf2048 before
accept/handshake; explicit supported transport options take priority. Native
handlers, HTTP, UDP and QUIC setup are untouched. Effective buffer is read via
public Hell.Socket.getopts and must be positive and at most16384, matching the
existing qualified maximum native profile; otherwise :receive_buffer_limit.

For effective buffer B, delivery D=100*B+18437 and funding
F=2*D+2*max_state+max_output. Default F=643053 bytes. D covers the qualified
OTP active-once batching plus one maximum TLS1.2 record. Two delivery obligations
cover current backing and receive/copy overlap; old/new app-state and one output
can coexist. Incoming delivery is checked before dispatch; max_packet still
chunks arbitrary ordered deliveries. Full delivery backing stays charged through
the chunk loop. Repartition materializes retained input/state/output from paid
credit and restores reusable temporary credit after each callback/send. At the
maximal input+old/new state+output peak, at least D remains prepaid. Scalar
begin/retain receive the unchanged funded total, preserving callback watchdog
and scalar temporary-credit semantics. No common draining-growth bypass exists.

Explicit max_bytes remains an undoubled hard transport cap. An explicit cap
below the required floor now refuses the raw connection with :byte_limit; this
is a necessary migration note, not behavior-identical low-cap admission. Higher
explicit buffer settings up to16384 increase actual funding; unsupported larger
effective profiles are rejected rather than silently clamped. max_active1
still prevents a second admitted owner. Existing ordinary state/output bounds
and native scalar-gate compatibility pass unchanged tests.

## Verification

All commands exited and all source fingerprints were stable during each run.
Receipts and exact commands/environment/source hashes are sibling JSON files.

- red-stream: FAIL2/2, exact new TCP/TLS postbarrier reproduction.
- round7-stream: FAIL2/2 after postbarrier assertions passed; new fixture expected
  :normal but Hell.Handler:471 explicitly uses {:shutdown,:peer_closed}. Fixed
  exact expectation; original failed evidence retained.
- round8-stream: FAIL10/3; new fixture sampled accounting before post-send retain
  finished (35 versus29), and TLS at backend max_active cap timed out during
  second handshake. Corrected state synchronization and finite TLS-cap outcome;
  below-floor tests still require closure. No historical assertion was weakened.
- round9-stream: PASS10/0. Both transports cover postbarrier repeated echoes,
  terminal zero accounting, exact explicit floor/max_active, below-floor refusal,
  preserved4096 buffer tuning, and original200ms forced drain.
- round9-release: PASS `MIX_ENV=prod mix compile --warnings-as-errors`,
  `mix release gaoxy --overwrite`, then unchanged `python3 scripts/release-smoke.py`.
  All3 transports pass including admitted TCP/TLS replies after SIGTERM barrier,
  VM exit0, UDP endpoint reuse and no listeners leaked.
- scoped-compat: PASS72/0 via `mix test` on native_stream_test.exs,
  stream_isolation_test.exs and resource_budget_admission_test.exs. Historical
  native/stream files were not promoted to scheduled inventory.
- final-scoped: PASS scoped mix format --check-formatted, strict test compile,
  check-test-inventory.py, then check-tests.py for new file with seed0/max-cases1:
  PASS10/0. Inventory unit390/component321/protocol167,121 active files and143
  retained files. This is inventory arithmetic, not a claim the full878 ran here.

Task changes are only StreamBridge, the narrow Service profile default, the new
10-case protocol test file and one additive check-repairs.py entry. Existing
678 protected inputs are unchanged, including scripts/release-smoke.py and
scripts/test-inventory.json. `candidate-task-hashes.json` and `handoff.json`
record identities; task patch SHA256 is in the latter.

All task commands and temporary runtimes are terminal. Source/test/manifest
writing and shared build ownership are released to the parent. No further
writing after handoff. No commit/push/publication/deployment was performed.
