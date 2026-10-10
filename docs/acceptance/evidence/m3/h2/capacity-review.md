# H2 capacity-bound independent regressions

Task `/root/upstream_cleanup`, direct independent S4 red-test assignment,
2026-10-10. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`,
branch `codex/m3-gateway`, baseline
`22b76e8051ddaf09e36797cb781b9b119870a9d4` plus preserved shared M3 changes.
Owned changes: new `apps/gaoxy_http/test/http2_capacity_test.exs`, this review
and its `capacity-red.log`. No production or existing test edits, commits or
publication. Parent granted the exclusive Mix window after S3 repair validation
and kept production frozen during this red run.

## Independent contracts

The seven tests cover the parent's qualified hard control ceilings and capacity
profile without reproducing its reservation formula:

- `control_rate: 4097` and `control_turn: 129` must return exactly
  `{:error, :invalid_http2_limits}` from startup before binding; a selected
  nonzero fixed port must remain rebindable.
- Maximum supported `control_rate: 4096`, `control_turn: 128` must remain accepted
  and return a real loopback H2 endpoint's exact 200/`hello` response.
- A 256 MiB service budget must serve an exact default-ingress endpoint response
  but reject a 256 MiB configured carry buffer with `:http2_byte_budget`. Carry
  alone consumes that entire budget; decoder, writer and stream obligations
  need additional room regardless of their implementation formula. The same
  fixed port is rebound after both the valid server and attempted invalid start.
- `max_read_chunk: 65536`, `max_buffer_bytes: 131072`, and endpoint body credit
  65536 must preserve the exact payload. Public
  `ThousandIsland.Socket.getopts/2` must report the same native `buffer`/`recbuf`
  as the default profile; the native buffer must remain 16384. Comparing actual
  profiles accounts for host kernel receive-buffer rounding without assuming
  its value equals the requested socket option.
- Pure prebind validation must reject non-`:inet` native TCP hosts and OTP TLS
  `internal_active_n` outside the qualified integer range 1..100. Supported
  boundary TLS profiles 1 and 100 are checked first. TLS credential names are
  symbolic pure-spec input; these are not certificate or TLS network tests.

The fixture is synchronous because host-profile tests temporarily set global
application environment. Each override restores the exact previous value or
absence in an `after` block. Real loopback requests require nonzero listener
ports, exact response status/body, finite waits, rejection of unexpected H2
frames, and zero public active/byte/cleanup reservations after client close.
The local native owner's `:sys.get_state` is used only to obtain its public
socket wrapper, not a private upstream client/pool API.

## Actual first red run

```sh
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' sh -c 'mix format apps/gaoxy_http/test/http2_capacity_test.exs && unbuffer mix test apps/gaoxy_http/test/http2_capacity_test.exs --warnings-as-errors --max-cases 1' > docs/acceptance/evidence/m3/h2/capacity-red.log 2>&1
```

Expected TDD RED: 7 tests executed, 6 failures, seed 325816, command exit 2.
All failures reached the intended behavioral assertions; fixture corrections 0.

| Contract | Actual result |
| --- | --- |
| Rate 4097 rejection | FAIL: startup returns `{:ok, server}` |
| Turn 129 rejection | FAIL: startup returns `{:ok, server}` |
| Maximum 4096/128 exact endpoint | PASS |
| 256 MiB carry within 256 MiB total budget | FAIL: startup returns `{:ok, server}` after the default-budget endpoint succeeds |
| Large-credit fixed ingress | FAIL: exact 200/`hello` replies succeed; native default `[buffer: 16384, recbuf: 32768]` becomes `[buffer: 65536, recbuf: 131072]` |
| TCP backend `:socket` | FAIL: pure service spec returns `{:ok, spec}` |
| TLS delivery profile 101 | FAIL: pure service spec returns `{:ok, spec}`; supported profiles 1/100 passed first |

Every erroneous startup is synchronously stopped before the test asserts its
return value. Fixed-port rebind assertions therefore execute even in this red
checkpoint, proving cleanup rather than claiming the rejection already occurs.
No endpoint, cleanup, port or environment restoration fixture failure appeared.
TLS profile 0/`:infinity` checks follow 101 and are NOT RUN in this red checkpoint;
they remain mandatory assertions in the future green run.

Command session `14496` finished with exit 2; the parent was notified and its
Mix window returned before this report. Reviewer `git diff --check` passed.

SHA-256 at red checkpoint:

```text
73f55be4aa194647467b386fde54dfcfc8afb4e48afdfe3f24a8ed1693914c28  apps/gaoxy_http/test/http2_capacity_test.exs
7b697780bf886565cf9a84387bb0f70971aa21624c580e47e62e4e04471ccd98  apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex
513c774a5e45a06c44a516274bec2f7bd3dbc1a25d273b3df7499eff69bdfb24  apps/gaoxy_http/lib/gaoxy/http/http2/limits.ex
3c1a68f1bf58d4f205958b82230e6d28665b719c7b64923593992decdcafdb90  apps/gaoxy_http/lib/gaoxy/http/options.ex
d84bad42a51af1c07b84ad26e7c6b6e10883aeda48f9794376dfab8ca511a1d3  apps/gaoxy_http/lib/gaoxy/http.ex
```

## Source finding and handoff

The current pure limit validator lacks control-rate/turn ceilings. Its
reservation ignores configured `max_buffer_bytes`, and its connection startup
sets native `buffer`/`recbuf` from freely configurable `max_read_chunk`.
`HTTP.service_spec/1` has no H2 host-profile guard. These source paths match the
observed red results. This demonstrates missing bounds/qualification checks,
not an executed memory overrun or total BEAM-memory measurement.

Parent and the separate independent reviewer agreed the pending repair retains
the fixed 16 MiB state/control allowance, bounds control rate/turn, explicitly
reserves carry plus a fixed OTP SSL delivery/copy allowance, and fixes native
H2 ingress options at 16 KiB independently of body credit. ThousandIsland's
frontend uses active-once delivery; it is not passive. The finite audited OTP
SSL internal-delivery profile still needs its explicit guard and allowance.
This reviewer did not implement or qualify the pending production formula.

Status: DONE for independent S4 red regression/source evidence; parent-owned
production repair, fresh green verification, source re-review and wider H2/RFC
acceptance remain pending. No new product decision is needed. Worker Task 5
cumulative Sol rounds remain 2 successful, behavioral repairs 0, Astra 0.
S3 fixture corrections remain 0; this independent S4 fixture has 0 correction
and 0 production repair rounds. All reviewer commands are finished.

## Parent repair 11 narrow specification re-review

The historical red checkpoint above is preserved. The finalized parent source
implements the agreed qualified profile:

- Pure H2 normalization retains positive-integer validation and caps control
  rate at 4096 and per-turn parsing at 128. This bounds the existing control
  queue/count relationship instead of accepting an arbitrary positive rate.
- Connection reservation retains the existing decoder and 16 MiB state/control
  allowances, adds four configured parser-carry windows and eight fixed
  qualified delivery/copy windows. Each delivery window is based on a fixed
  16384-byte native buffer, up to 100 internal OTP SSL buffers, and one maximum
  TLS 1.2 record allowance. Stream and writer reservations remain separately
  additive in the same service total.
- Connection receive allowance is the fixed 65535-byte connection window. It
  does not shrink when an operator lowers the advertised per-stream window;
  runtime connection `recv_window` is itself initialized to 65535.
- Connection startup sets native `buffer` and `recbuf` from the single fixed
  16384-byte constant, independently of endpoint `max_read_chunk`. The existing
  semantic read-credit clamping remains, preserving the 65536-byte configuration
  and endpoint-credit compatibility contract.
- Public `HTTP.service_spec/1` validates host support and total byte budget
  before `HTTP.start_link/1` starts the Gaoxy listener. Host checks are restricted
  to H2-capable profiles: TCP/TLS require `:inet`, and TLS also requires integer
  `internal_active_n` in 1..100. H1-only service specs do not invoke this host
  guard. H2 runtime repeats host qualification before acquiring a connection
  lease or starting its writer, covering a changed host profile after prebind.

Specification verdict: PASS for the narrow S4 production repair. These are
finite qualified payload/copy reservations, not a total process/RSS/kernel
memory guarantee. The source correctly describes TI's active-once frontend.
The prebind/host tests are independent behavioral contracts; they do not copy
the reservation equation. No architecture, dependency or core callback
expansion was introduced by this repair.

## Quality review and current verification boundary

Quality verdict: PASS for the narrow repair, no actionable finding. The receive
buffer constant is shared by the socket setter and delivery accounting, reducing
qualification drift. Host validation uses the normalized service transport at
prebind and the actual socket security state at runtime. Failed qualification
does not create an admission lease/writer. The configurable carry bound remains
in normal HTTP options, while native receive delivery is qualified separately;
the repair does not conflate body API credit with socket buffering.

Freshly inspected `capacity-repair11.log`: strict compilation followed by the
HTTP scope executes 52 tests with 0 failures, server scope 18 with 0 failures,
seed 655300; 40 corrected selected RFC cases also pass. Parent confirmed the
enclosing command exited 0. The unchanged seven-case capacity fixture is in
that passing scope, so its formerly unreachable TLS 0/`:infinity` cases, exact
endpoint compatibility, native socket-option equality and fixed-port rejection
checks now execute successfully. `h2-rfc-round11/results.json` separately
reports 40 executed, exit 0, runtime stopped and port rebound.

That first green checkpoint precedes the final correction from configurable
stream `receive_window` to fixed connection 65535 in reservation accounting.
Its RFC artifact's Limits hash is
`8b969694077be3e6db25291fca2b26712c510f601bde0ce5267c246f8cbfa16d`,
so it must not be represented as verification of the finalized hash below.
Parent owns final canonical verification session `89149`; this reviewer did
not poll, stop or invoke Mix/fixtures during that exclusive window. Final
current-source runtime/canonical acceptance remains pending its actual receipt.

Finalized source independently read for this narrow review:

```text
73f55be4aa194647467b386fde54dfcfc8afb4e48afdfe3f24a8ed1693914c28  apps/gaoxy_http/test/http2_capacity_test.exs
f8d922deee2f7a45ecf3070498a3f82a50af47b5fbe0007545ab11bf3cf831ab  apps/gaoxy_http/lib/gaoxy/http/http2/limits.ex
3e604e41244d64a0dba8cc6f5b87655bf1f6c60e2944f6c37d5dc979d846735b  apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex
e08385455d89ab422e4d3b8e4d68c0d555343986e32c59faff5dbcef5cef489c  apps/gaoxy_http/lib/gaoxy/http.ex
3c1a68f1bf58d4f205958b82230e6d28665b719c7b64923593992decdcafdb90  apps/gaoxy_http/lib/gaoxy/http/options.ex
```

Status: DONE for narrow independent S4 specification and quality re-review;
both PASS, with first scoped green evidence accurately bounded above. Only
this review document was appended during re-review. Worker Task 5 rounds
remain 2 successful, behavioral repairs 0, Astra 0; S3/S4 fixture corrections
remain 0 and no worker production repair occurred. Parent repair 11 is recorded
separately. All reviewer commands finished; no commit/publication or user
decision is needed. Full current-source H2/RFC/M3 acceptance remains parent-owned.
