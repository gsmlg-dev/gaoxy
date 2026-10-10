# Parent-owned repair checkpoints

Source: `22b76e8051ddaf09e36797cb781b9b119870a9d4` plus the M3 task diff in
`.trees/m3-gateway`, branch `codex/m3-gateway`. All commands use the pinned Nix
shell, `ERL_FLAGS="+S 2:2"`, `MIX_ENV=test`, `unbuffer mix`, warnings as errors
and `--max-cases 1`. Historical logs remain unchanged.

| Log | Command scope | Actual result |
| --- | --- | --- |
| h2/parent-repair-7-relay-f1.log | Format owned root files; strict umbrella compile; H2 network/integration, Forward, raw/TLS Relay | Compile PASS; HTTP 28/1, proxy 33/0; exit 2, seed 910150 |
| h2/parent-repair-7-green.log | H2 network/integration after fixing erroneous peer-RST echo expectation | 28/2, exit 2, seed 726383; both errors in already-resumed writer teardown |
| parent-udp3-h2-green.log | Format bridge/network/consumer files; strict compile; core datagram/config, H2 network/integration, UDP Relay | Compile PASS; core 7/0, HTTP 28/0, proxy 17/0; exit 0, seed 502446 |
| h2/independent-review-red.log | Independent H2 state/header/buffer/deadline review | 7/5, exit 2, seed 483847; five actionable production findings |
| h2/independent-review-round8.log | Eight independent review cases plus H2 network/integration after parent round 8 | 37/0, exit 0, seed 196890 |
| h2/generation-reload-initial.log | H2 response/proxy integration including 20 route activations with an old guardian | 10/0, exit 0, seed 32039 |
| standalone-initial-red.log | Standalone mixed HTTP/UDP configuration/start/reload | 4/3, exit 2, seed 715130; missing HTTP configuration branch |
| standalone-initial-green.log | First standalone implementation plus Generation compatibility | HTTP 12/0, server 13/2, exit 2, seed 497012; two fixture issues diagnosed below |
| external-core-consumer.log | Copied core in a clean external consumer, including forbidden HPAX dependency assertion | 1/0, exit 0, seed 898049 |

F1 permits mismatched absolute-form schemes only through an explicit optional
Endpoint callback. ForwardHTTP opts into `http`, preserving normal endpoint
listener-scheme validation. Verified TLS forwarding now returns the exact
upstream response through a TLS proxy listener.

H2 round 7 removes entirely unsent header blocks for reset streams. Once a block
is handed to its writer, remaining CONTINUATION frames reach END_HEADERS before
another frame. Each block independently signals a zero dynamic-table capacity
using public HPAX APIs, so deleting an unsent block cannot lose a resize update.
Tests require the live sibling's exact body, no canceled queued response, and
an intact fragmented block with no canceled DATA. Peer RST must not be echoed;
the first new fixture incorrectly required an echo and was corrected. Its
cleanup originally resumed an already-resumed live writer, also corrected;
runtime and on-wire assertions remain strict.

Relay R3 confirms both writer DOWN receipts before polling public raw-driver
send queues. Normal completion waits for both queues to empty; deadline expiry
keeps processing the same service drain budget and aborts uncertain output.
Tests require bounded 100 ms stop with withheld peer reads, and separately the
full exact admitted payload when reads resume before expiry. Proxy 33/0 covers
these repairs, Forward and raw/TLS Relay; expected rejection logs remain visible.

UDP round 2's startup helper was still linked on its normal exit, causing an
unexpected helper EXIT to reach the dispatcher. Parent round 3 unlinks that exact
owned helper in `after`, preserving its startup link while work is outstanding.
The existing network failures supply the red, and the 17-test UDP green includes
the independent Python rate/credit and delayed-drain/force-stop gates.

H2 round 8 rejects information responses after final commitment, distinguishes
initial END_STREAM from terminal input arriving before worker readiness, counts
generated status fields, validates frame-header ingress headroom before bind,
and retains the original stream deadline in every queued response-head fragment.
The large-frame contract now separately rejects incompatible configuration and
requires a legal 65535-byte frame with sufficient explicit ingress capacity to
preserve its exact live sibling response. The original failing log is retained.

The standalone first run completed its wire/reload assertions but its port-reuse
fixture omitted SO_REUSEADDR after a real accepted TCP connection entered
TIME_WAIT. The corrected fixture first requires connection refusal, then rebinds
with the same reuse policy as the original listener. The direct failed-supervisor
startup fixture also omitted OTP exit trapping; it now requires both the explicit
startup error and its linked shutdown message before checking rollback. These
are fixture corrections pending a fresh rerun, not an initial passing gate.

Cumulative counters: H2 Sol 8 production repair rounds, 1 unsuccessful production
round, Astra 0 (round 7's two fixture-only failed runs remain recorded above);
Relay Sol 3, unsuccessful 0, Astra 0; UDP Sol 3, unsuccessful 1, Astra 0.
Task 5 has its own counters. No counters are reset on ownership handoff.

Independent full H2, UDP re-review, standalone integration, upstream groups and
operational qualification remain outstanding. These checkpoints do not qualify
full M3, publication, hosted CI, deployment or production acceptance.

## Subsequent parent checkpoints through round 11

The earlier counters and pending statements describe their original checkpoints.
Current task-owned canonical formatting is repaired without semantic changes;
`canonical-round11-final.log` retains its failed format gate (exit1; later gates
NOT RUN). The successful follow-up is `canonical-round11-formatted.log`: strict
format/compile, core90/0+HTTP196/0+proxy152/0+server18/0, total456/0 seed216300,
corrected independentRFC40/0, clean externalcore1/0 seed387754, commandexit0.

- Standalone repair1 fixture2: generation/resource/loader21/0 and server18/0,
  seed459271 exit0. The erroneous mandatory failed-start EXIT receipt was removed;
  explicit error, absent runtime/registry, refusal and exact rebind remain. The
  independent standalone specification/quality reviews PASS. Old failed logs
  are retained rather than rewritten.
- Task5 expanded fixture1: HTTP21/0+proxy59/0 seed709212 exit0, strictcompilePASS.
  Two first expanded-test failures were peer/certificate fixtures and remain in
  the original HTTP21/0+proxy59/3 seed311044 exit2 log. Further activation is
  rejected while retired releases remain, and immutable handles must match the
  complete recorded capability. Worker counters remain2 successful rounds.
- Parent Generation publication repair1: deliberately red1/1 seed1281 exit2
  confirms synchronous old-pin releases delay a committed publication receipt.
  Reconciliation now releases one pin per dispatch after returning the receipt.
  Initial validation HTTP22/1+proxy20/1+server18/0 seed618354 exit2 exposed two old
  synchronous-metadata fixture assumptions. Existing finite polls now require
  the exact eventual pin0/retiring states; HTTP22/0+proxy20/0+server18/0
  seed806307 exit0 and narrow independent spec/quality PASS. Productionrepair1,
  fixturecontractupdate1; no weakened resource assertion.
- H2 round9: idle-stream zero WINDOW_UPDATE is connectionPROTOCOL_ERROR;
  malformed nonzero PRIORITY length is streamFRAME_SIZE_ERROR and preserves a
  live sibling. New reds execute1/1 seed33400 and1/1 seed979125, exit2. The raw
  independent idle-window red confirms actualRST1 rather than requiredGOAWAY1.
  Canonicalround9 strictcompilePASS+448/0 seed378921+correctedRFC40/0 exit0.
  The older39-case RFC green incorrectly expected PRIORITY GOAWAY; its report
  remains historical, with the corrected40-case expectation independently
  reviewed against RFC9113. Initial fixture cleanup_failed0 expectation was
  corrected to the public healthy nil/None value, retaining exactzero counts.
- H2 round10/S3: controlled late failed receipt from a real canceled starter
  changed another starter5→7, red1/1 seed90841 exit2. Worker/token/lease/current
  starting authentication now ignores the obsolete receipt. Strictcompile and
  stale/network/protocol28/0 seed718263 exit0, independent narrow spec/qualityPASS.
  Fixturecorrections0; controlled replay is not a natural-race timing claim.
- H2 round11/S4: seven independent capacity tests first execute7/6 expected
  failures seed325816 exit2. Cap controlrate4096/turn128, fix16KiB socket buffers,
  validate qualified H2 host profile before public-facade bind and at connection
  start, reserve4*carry+8*boundedTLSdelivery in addition to prior decode/16MiB
  state/65535connection allowances. Large bodycredit remains compatible. Initial
  scopedHTTP52/0+server18/0 seed655300 andRFC40/0 exit0 precede the final correction
  from advertised streamwindow to fixed65535connection allowance; formatted
  canonical above verifies the corrected source. Independent S4 spec/qualityPASS,
  fixturecorrections0. The codec fixture now supplies complete normalized limits.

Cumulative parent nativeH2Sol11, unsuccessfulproduction1, Astra0; RelaySol3,
unsuccessful0/Astra0; UDPSol3, unsuccessful1/Astra0; parentGenerationreleaseSol1,
unsuccessfulproduction0/Astra0. TDD/fixture/formatter failures do not reset these
counters or count as unsuccessful production repairs. Soak publicHTTPTask
capture was added after independent root review; original10s smoke stays
UNQUALIFIED. S5 member-timeout repair, finalbrowser/600s/finalwhole-review are
pending at this checkpoint; fullM3 remainsBLOCKED on HTTPFetch#66/#67.

## S5 bounded recovery routing

`groups/member-limits-handoff.md` freezes the three owned files after two
unsuccessful S5 Sol validations: compile exit1 (zero tests), then 26 tests/two
failures at seed107342/exit2. Corrected behavioral red is four/four at
seed862773/exit2; the earlier observer-profile fixture failure remains retained.
Cumulative Task5 Sol4, unsuccessful2, Astra0 at handoff. Root records
`astra_gate=SOL_REPEATED_FAILURE`, `mode=implementation`, authorized execution,
and at most two Astra recovery rounds; no counter resets.

Independent fixture adjudication requires exact empty bounded closure after
member absolute lifetime expiry, with peer EOF, unchanged healthy status and
zero public group/Service resources. Opening expiry still requires504 while
the total deadline permits it. A Content-Length5 origin response must preserve
fixed framing and exactbody, together with observed socket send_timeout80.
These corrections follow the existing absolute-deadline and framing contracts;
they do not grant extra time or remove cleanup, health or wire assertions.
The corrected final-source gate remains NOT RUN at this routing checkpoint.

## S5 and fresh canonical qualification

Astra recovery changed only the two erroneous wire fixture assertions and
formatter spacing. Owned production hashes match the Sol handoff.
`groups/member-limits-astra-recovery.md` preserves Astra round1 formatFAIL
(exit1, zero tests), round2 strictformat/compilePASS, scoped26/0 and fullproxy
156/0 seed107342 exits0. Cumulative Task5Sol4/unsuccessful2, Astra2 with one
conservatively counted failed format validation; no resets or third recovery.

Root final canonical session89625 exits0: strictformat/compilePASS, core90/0,
HTTP196/0, proxy156/0, server18/0, total460/0 seed49315. IndependentRFC40/0
exit0, every case exactzero reservations and finalRuntimeDOWN/rebind.
`canonical-s5-final.json` records the exact command, script body and actualexit;
before/after197source maps are identical. Independent bounded full specification
PASS follows that frozen identity; separate code-quality review now runs.
Phoenixfixture, fullbrowser/reverseexample and600s gates remain pending.

## Final independent local qualification

The previous paragraph is a historical S5 checkpoint. Separate bounded full
specification and quality reviews now PASS with S1–S5 resolved. Phoenix locked
resolution/strictcompile2/0 seed805388 exits0; only the missingHPAX1.1.0 lock
tuple changed. Initial browser import FAIL (greenlet/libstdc++ missing, zero
checks) remains in `browser-env-failed/`. Minimal Linux-only Nix LD_LIBRARY_PATH
compatibility repair1 passes the default-shell import probe and fullbrowser15/15
exit0, original13 checks retained, verifiedH2/Chromiumh2, LiveViewH1WebSocket,
exact source restoration. No runtime repair or weakened assertion was added.
Reverseexample6/6 actualsession71267 exits0.

Frozen600-second soak actualsession32874 exits0:600.0001466s offered,
602.8070603s load/drain;4064 offered=3872 exact completed+192 expected resets,
zero unexpectederrors,12052 slowcredits,299reloads. All600samples pass fixed
ceilings (RSSgrowth9940992B, processgrowth132, mailbox6, active34,
retained371570471B). Teardown7ms captures6082/6082DOWN and confirmszero
reservations/tasks/guardians, runtimeDOWN/refusal/rebind, exact descriptor
conservation and closedorigin. All199frozen/91soak hashes match; independent
soak specification then quality PASS. Soak tooling counter stays1 public-task
coverage improvement, zero unsuccessful repairs; no changes during this run.

The20-generation test and600-second soak use fixed proxy endpoints. Group
coverage is bounded concurrency/saturation, realHEADprobes and exactold/new
group peers acrossoneactivation; no group/probe soak is claimed.

Final live upstream state13:18:23Z: both#66/#67CLOSED, latestGitHub/Hex and
installed0.19.1 still precede their fixes. FullM3 remainsBLOCKED on a containing
release/update plus reusableH1/H2 cleanup/trailer/version-matrix qualification.
Local gates, reviews and commits do not authorize M4, push, publication,
deployment, productiondata, Vault, publicmanagement or release-artifactE2E.

## Local packaging checks

Six implementation/tool/CI commits through9eda1ca contain all199 source blobs
exactly matching the frozen candidate. First complete evidence staging exposes
full `git diff --cached --check` exit2:28 whitespace findings in seven raw logs,
only trailing whitespace/blankEOF from command output. The authored non-log
check exits0. Raw bytes and historical failure hashes are preserved; no source,
test assertion or raw evidence is rewritten to hide that result. Independent
delivery audit confirms this distinction and source coverage.
