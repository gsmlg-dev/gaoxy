# P4 TCP/TLS StreamRelay evidence

Source baseline: `22b76e8051ddaf09e36797cb781b9b119870a9d4`, branch
`codex/m3-gateway`, worktree `.trees/m3-gateway`, plus task-owned relay files.
The shared parent owns HTTP/H2, policy, generation and core compatibility edits.
No dependency patches or publication are part of this relay slice.

## Contract

The native ThousandIsland owner remains in synchronous passive duplex transfer.
It owns both receive directions; two independently admitted temporary writers
each permit one outstanding authenticated piece of at most16KiB. The owner
alternates empty-side reads with at most5ms polling, retains bounded carry, and
services writer replies, DOWN, drain and shutdown on each turn. Receive backend
qualification is OTP inet; an explicitly selected socket backend is rejected.
The passive raw-buffer qualification is recorded in `raw-buffer-probe.exs/.log`.

Raw owner reservation is `4*65536 + 4*chunk + 4096`; TLS modes instead use four
conservative1656837byte delivery windows (see `ssl-receive-audit.md`), plus each
writer's `2*chunk + 1024`, acquired before reads/payload handoff. Defaults are connect5s,
write5s, idle30s, lifetime300s. All are finite and positive. Drain uses the same
absolute service budget with up to25ms reserved for writer/socket/receipt cleanup.
Uncertain writes are never replayed. Both writers are killed before their DOWN
confirmations share one absolute cleanup deadline, capped at25ms and never
extending the caller/service deadline. Unconfirmed termination is an error.
Independent writers use send_timeout_close:false; the receive owner closes hard
failures with zero TCP linger or bounded public TLS close to avoid poisoning an
in-flight passive receive and OTP's180s queued-output close wait.

Raw TCP and opaque passthrough preserve TCP FIN independently in each direction.
TLS termination and verified upstream TLS explicitly stop both directions on
EOF with telemetry reason `:tls_directional_shutdown_not_supported`; TLS
directional half-close is UNSUPPORTED, not claimed as TCP-equivalent. Upstream
TLS uses the numeric dial candidate, explicit hostname/SNI, CA verification,
HTTPS hostname matcher and TLS1.2/1.3. There is no sniffing, PROXY protocol, MITM,
or operational certificate generation.

The supported CONNECT seam accepts an already dialled upstream and the current
admitted owner/absolute deadline. It adds relay windows to the existing lease,
forwards bounded initial bytes once, then uses the same pump. H1 authority,
authentication, policy, dial-before200 and parser integration remain parent-owned.

## Runs recorded so far

| Evidence | Executed result |
| --- | --- |
| raw-red.log | 5 expected missing-module failures (TDD red), exit2 |
| raw-initial.log | 5 tests,0failures, exit0; force-stop barrier later strengthened |
| raw-tls-initial.log | 9 tests,2failures, exit2: drain receipt and empty ALPN option |
| repair-1.log | 9 tests,0failures, exit0, seed992899 |
| core-compatibility.log | 13 scoped core native/stream/TLS tests,0failures, exit0 |
| seam-red.log | 18 tests,3 expected missing-facade failures, exit2 |
| seam-green.log | 18 tests,0failures, exit0, seed914509 |
| final-green.log | 20 tests,0failures, exit0, seed284390 |
| backpressure-green.log | 21 tests,1 real stalled-close failure, exit2, seed848408 |
| review-red.log | 23 tests,3 failures, exit2; TLS reserve deficit, host-test fixture-tag error, stuck upstream passive recv |
| repair-2.log | 23 tests,0failures plus scoped format/strict compile, exit0, seed976830 |
| normal-close-red.log | one executed normal EOF cleanup regression fails at100ms service stop with deadline_exceeded/cleanup_pending;15 excluded, exit2, seed250425 |
| ../h2/parent-repair-7-relay-f1.log | proxy33 tests,0failures, seed910150; real drain and normal byte-preservation regressions included; concurrent HTTP28/1 unrelated H2 fixture failure excludes whole-run PASS |
| ssl-buffer-probe.log | OTP public SSL3MiB eachdirection, source/hash qualification, exit0 |
| normal-close-probe.log | Genuine half-closed peer:999424bytes accepted,12160driverbytes pending; normal close waits>200ms, releases on readcredit with all bytes preserved, exit0 |

Relay worker Sol repair count:2 attempted,0 unsuccessful; Astra0. Core empty-ALPN
fix belongs to parent. Fresh green covers raw FIN, buffered facade, original
deadline/additive lease, idle/lifetime, real and barrier-controlled stalled writes,
confirmed writer failure/drain cleanup, pre-handoff admission rejection, all TLS
modes with independent Python peers, TLS burst/reservation and SSL host checks.
Expected bad-certificate/CA and deliberate admission rejection callbacks log
terminal errors; their tests require rejection and zero forwarded payload.

R3 is RESOLVED by parent output-drain pump and scoped proxy33/0 evidence above.
The original successful both-EOF completion could call normal OTP TCP close
with accepted output still queued, which can wait180s rather than keep pumping
the original deadline/drain messages. `normal-close-probe.exs/.log` confirms the
public primitive and preserves the full payload after releasing peer readcredit.
Parent completed the bounded final queue-drain fix and real relay regression;
successful normal completion must preserve payload, while deadline expiry may
abort uncertain output. Parent source now implements that sequence and fresh
evidence are reviewed. This is a worker-local two-round ownership handoff, not
an Astra gate (both rounds succeeded), external blocker or product decision.

## Commands

From `apps/gaoxy_proxy`:

```sh
nix develop --command bash -c "export ERL_FLAGS='+S 2:2'; export MIX_ENV=test; unbuffer mix test test/stream_relay_test.exs test/stream_relay_tls_test.exs"
```

Core compatibility, from `apps/gaoxy`:

```sh
nix develop --command bash -c "export ERL_FLAGS='+S 2:2'; export MIX_ENV=test; unbuffer mix test test/native_stream_test.exs test/stream_isolation_test.exs test/tls_test.exs"
```

Local focused evidence does not qualify hosted CI, released artifacts, deployment,
or production acceptance. No umbrella-wide test claim is made.
