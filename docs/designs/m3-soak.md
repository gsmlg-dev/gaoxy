# M3 loopback HTTP/2 sustained-load fixture

This is local interoperability and retained-resource evidence. It binds and
connects only `127.0.0.1`; it does not publish, deploy or contact external targets.
Production runtime ownership remains with root and the Groups worker. The
independent client uses Python `h2`/`hpack` and an independent stdlib HTTP/1
origin. RFC malformed-frame qualification remains a separate root-owned gate.

## Profile and bounds fixed before execution

- One h2c prior-knowledge connection, batches of 32 concurrently opened streams.
- Alternate local streaming upload echo and a fixed reverse proxy to an ephemeral
  loopback HTTP/1 origin. Proxy connections use the existing non-reuse policy.
- Each offered POST body is 131072 exact patterned bytes. Every completed
  response must return status 200 and the exact payload.
- Request lifetime 30000 ms; writes 5000 ms; service active limit 128 and retained
  capacity 536870912 bytes; HTTP/2 concurrent streams 32.
- Pace socket reads and withhold selected response WINDOW_UPDATE credits for
  200 ms. Reset periodic streams only after response DATA progress and completion
  of the request upload. Every expected reset is recorded separately.
- Replace complete route generations periodically through the public Generation
  API while retaining the same listener and client socket.
- Default offered-load interval at least 600 seconds. A shorter explicit smoke
  run is useful tooling validation and is labelled UNQUALIFIED.
- RSS must remain at or below startup RSS plus 512 MiB; BEAM total process count
  must remain at or below startup count plus 512. Sampled owned endpoint workers,
  connection owners, admission gates, public HTTP Task.Supervisor children and
  proxy guardians must have mailboxes at
  most 2048 messages. Admission active must remain at most 128 and retained bytes
  at most 536870912 in every sample. These are fixed acceptance ceilings, not
  claims about peak unsampled resource use.
- Zero unexpected stream errors, response mismatches, sample-bound violations
  or origin payload failures. Both route types must complete, slow-credit and
  actual-progress-reset paths must execute, and at least two reloads must succeed.

## Ownership and teardown

The Elixir script reports endpoint workers and their native H2 transport owners.
Public DynamicSupervisor child enumeration captures proxy guardians; public
Task.Supervisor enumeration also captures native H2 writers and stream tasks. Sampling
uses public `Gaoxy.status`, `Process.info` and system process counts. The fixture
tracks captured live processes with monitors and drains DOWN messages; it never
reads or modifies private protocol state. Python also records gateway Linux
`/proc/<pid>/status` RSS and socket descriptors for the launched process only.

After closing the client socket, a single 15-second budget covers zero admission
and cleanup reservations, `Gaoxy.stop`, runtime DOWN, every captured live owned
process DOWN, empty proxy guardian children, Generation-store shutdown, empty
HTTP Task.Supervisor children,
connection refusal and exact listener-port rebind with `reuseaddr: true`.
Bounded status polling and monitors provide the proof; elapsed sleeps do not.
The Python origin separately shuts down its owned server and closes its socket.

## Implementation and verification plan

1. Add a minimal Elixir echo/proxy/Generation script and JSON control protocol;
   expose bounded sample/reload/stop commands without production-file edits.
2. Add Python upload/response multiplexing, flow-credit pacing, progress-based
   resets and exact response checks; pin dependencies in the fixture directory.
3. Validate syntax and a short scoped smoke under a root-coordinated Mix window.
   Keep smoke UNQUALIFIED and retain actual command, source hashes and exit.
4. Freeze the candidate identity and run the default 600-second interval after
   required runtime repairs and independent review. Record UTC start/end, actual
   interval, environment/version/source identities, offered/completed/reset/error
   counts, throughput, p50/p95/p99 completion latency, all samples and teardown.

The artifact cannot establish TLS/browser, malformed-wire, upstream pool, public
deployment or overall M3 acceptance. Those gates retain their own evidence.

## Initial tooling smoke — UNQUALIFIED

Executed after root granted an exclusive Mix/source freeze, in this worktree:

```sh
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; set -euo pipefail; unbuffer mix format integration/h2_gateway/fixture.exs; unbuffer mix compile --warnings-as-errors; /tmp/gaoxy-m3-h2-soak-venv/bin/python integration/h2_gateway/run.py --duration 10 --smoke --evidence docs/acceptance/evidence/m3/h2-soak-smoke-initial'
```

Actual shell exit **0**, formatting and strict compilation pass. Evidence:
`docs/acceptance/evidence/m3/h2-soak-smoke-initial/result.json` and `gateway.log`.
The JSON records every source SHA256, UTC timestamps and environment: Linux
6.18.33 x86_64/glibc 2.42, Elixir 1.18.5/OTP 28, Python 3.13.15,
h2 4.3.0/hpack 4.1.0/hyperframe 6.1.0.

Actual offered interval **10.0085 s**, load plus drain **14.4598 s**;
**96 offered / 92 completed** (46 local, 46 proxy), **4 expected resets / 0
unexpected errors**, **4 reloads**, observed local response epochs **0/2/4**.
P50/P95/P99 completion latencies: **2.663/4.643/4.828 s**.

Fifteen samples stay within all preselected ceilings: maximum RSS growth
**8650752 bytes**, process-count growth **132**, sampled mailbox **2**, active
admission **34**, retained admission **358053631 bytes**. Samples are scoped
evidence rather than an assertion about unsampled peaks.

Teardown: **10 ms**, runtime DOWN, **145 captured / 145 DOWN**, zero admission
active/bytes/cleanup reservations, zero guardian children, connection refusal,
same-port SO_REUSEADDR rebind, gateway descriptor set equal to the baseline minus
the recorded owned listener inode, origin client/listener sockets closed, gateway
exit **0**. No weakened assertion or tooling repair was needed; cumulative
Task7 Sol repair rounds **0**. The compile/source window was released to root.

This validates the original tooling only. Root's subsequent independent review
added public HTTP task capture and an exact empty-task teardown assertion, so
the original smoke does not qualify that final tooling identity. **Full
600-second execution at that historical checkpoint: NOT RUN**, pending member-limit repair and the final
candidate freeze. No ten-minute, whole-M3 or production acceptance follows from
this historical smoke.

## Final frozen 600-second qualification — PASS

After S5 repair, separate full specification/quality review, final canonical460/0
and selectedRFC40/40, root froze199 source files in `candidate-frozen.json`.
The original profile and acceptance ceilings above stayed unchanged. Public
HTTP task capture and empty-task teardown are included in this final tooling.

Root session32874, actual exit0:

```sh
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; set -euo pipefail; /tmp/gaoxy-m3-h2-soak-venv/bin/python integration/h2_gateway/run.py --duration 600 --evidence docs/acceptance/evidence/m3/h2-soak-final'
```

Actual UTC interval2026-10-10T13:07:02.561587Z–13:17:07.425705Z;
offered600.0001466s and load-plus-drain602.8070603s. **4064 offered,
3872 completed** (1959 local/1913 fixed proxy), **192 expected progress resets,
zero unexpected errors**,12052 slow-credit events,299 successful reloads.
Completion throughput6.4233/s; p50/p95/p99 latency2.5798/4.6054/4.8549s.

All600 samples pass the fixed bounds: maxRSSgrowth9940992bytes,
processgrowth132, mailbox6, active34, retained/high-water371570471bytes.
The single15s teardown takes7ms, confirms6082 captured/6082DOWN,
zero admission/cleanup reservations, guardians and publicHTTPtasks,
runtimeDOWN/refusal/rebind, exact descriptor conservation and closed origin
clients/listener. Gatewayexit0; no new tooling/runtime repair.

`h2-soak-final/result.json` and `gateway.log` retain all samples, hashes,
environment, counts and teardown. All199 frozen and91 soak-source hashes
remain exact. Independent specification then quality soak review recomputes
the raw evidence and passes in `final-spec-review.md`.

This is local echo/fixed dedicated-H1 proxy qualification. It does not qualify
upstream groups/live probes under sustained load, upstream reusableH1/H2,
TLS/browser, fullRFC conformance, unsampled memory peaks or production use.
FullM3 remainsBLOCKED on a containing HTTPFetch release/update and subsequent
qualification of closed#66/#67 fixes; the original10s smoke remainsUNQUALIFIED.
