# Independent UDP association specification and quality review

Reviewer `/root/upstream_cleanup`, direct read-only assignment from `/root`.
Worktree `.trees/m3-gateway`, branch `codex/m3-gateway`, baseline
`22b76e8051ddaf09e36797cb781b9b119870a9d4` plus shared current task changes.
Scope: approved `docs/designs/m3-udp-associations.md`; core dispatcher behaviour,
bridge, Config/Service adapter; UDPRelay facade, Options, Controller, Association;
scoped tests and acceptance evidence. Reviewer authored none of these sources.
No UDP production or test source changed by this reviewer. Shared Service ALPN
repair belongs to parent and is not a UDP finding.

Verdict: PASS for the scoped UDP association slice after U1-U4 repairs and
fresh parent verification. Review performed specification-first, then ownership,
accounting and failure paths. This does not qualify full M3 or deployment.

## Actionable findings

### U1 (resolved): absolute expiry absent at permit submission

Controller reserve stores `timer`, but neither an absolute permit expiration
nor the caller handoff deadline. Submit checks token, producer, key, byte count
and lifecycle mode only. A payload request queued before an expiry timer can be
processed after the permit lifetime when the controller resumes, and still be
accepted. A canceled/timed-out GenServer call does not retract its message.
The required contract says expired permits are dropped. Require an absolute
expiration/deadline check in the owner, plus a suspended-controller test with
the payload preceding the timer in its mailbox and both executing after expiry.
Timer cleanup remains necessary but cannot establish timeliness alone.

### U2 (resolved): advertised handoff timeout exceeds actual hard cap

Core Config accepts `dispatcher.handoff_timeout` through 1000 ms. UDPRelay.offer
creates a 50 ms absolute deadline before its immutable control lookup, then
clips the configured timeout to that original deadline. Values above 50 ms are
accepted but can never take effect. Carry the immutable configured budget to
the trusted caller before starting the one total deadline, or narrow the
advertised supported configuration explicitly. Keep all lookup/reserve/submit
waits inside the same absolute budget, including delayed owner processing.

### U3 (resolved): known local directed broadcast guard missing

Approved design requires rejecting known local directed-broadcast upstream
destinations. Options.unicast? rejects IPv4 addresses whose last octet is 255,
but examines no known local interface broadcast/netmask. A /25 broadcast ending
in 127 (or a /23 broadcast at another boundary) can therefore pass an explicit
narrow reserved opt-in. Conversely, a usable unicast ending in 255 is rejected
without relation to a local interface. Root must choose the bounded local
interface snapshot boundary while retaining pure configuration validation;
there is no need for privileged network mutation or an upstream workaround.
Require deterministic pure coverage for non-/24 directed broadcast and retain
actual-host prebind validation evidence.

### U4 (resolved): unknown output loses host reservation before host teardown

Controller.fail sends Service a failure message and immediately stops. Its
Admission lease is released on DOWN even while the independent Abyss writer
can retain an already submitted unknown datagram. Service receives the failure
later and then forces host teardown. This violates the required lifetime of the
fixed shared-writer infrastructure reservation. Keep the failed controller and
reservation until bounded Service teardown; reject new work and settle/stop
workers without refunding uncertain host capacity. Test at a barrier after the
failure notification and before host force that the reservation remains held,
then confirm worker/controller/host DOWN and full restoration after teardown.
The retained failed state must also refuse a later drain call: current drain
handling accepts any mode with `drain: nil` and could overwrite `:failed`.
The UDP worker independently identified this same source issue.

## Confirmed contracts and quality paths

- Explicit unicast dispatcher opt-in preserves the legacy per-packet handler.
  Core validates callbacks/configuration before binding and remains independent
  of proxy/HTTP packages. Bridge retains separate service and writer generations
  and opaque capability; startup handshake matches generation and unique token.
- Caller performs a metadata-only policy/context lookup and reservation before
  sending payload. Controller checks producer, policy, generations, association
  and queue limits before adding bytes to its own lease. One-use permits and
  ordered cancellation avoid duplicate refunds. Controller tracks starting and
  closing workers, queues one admitted packet per worker, and refunds only on
  acknowledgment or matching worker DOWN.
- Each temporary worker acquires a lease, owns a connected numeric upstream UDP
  socket, and receives with one active credit. Empty datagrams retain their wire
  shape while charging one byte/item. Source, size, earned ratio credits and
  per-association egress limits precede public capability submission. One
  outstanding receipt prevents arbitrary writer/worker mailbox growth.
- Public `Abyss.Dispatcher.send/4` and `Writer.await/4` classify admitted versus
  completed versus unknown outcomes. Await uses finite polling under the same
  submission deadline; unknown outputs are never retried. Shared-writer reserve
  arithmetic includes queued/in-flight copy allowance, subject to U4 lifetime.
- Idle/lifetime messages carry generation/token state. Pause preserves listener
  binding; service drain seals unused permits and flushes admitted queues before
  ordered worker sealing and response grace. Normal controller drain retains its
  fixed reservation until host stop. Service explicitly includes the controller
  root in resource census and force teardown, even after dispatcher death.

## Repair re-review and evidence

Live source/test re-review confirms:

- U1: reserve retains `expires_at = min(handoff deadline, reservation timeout)`;
  submit checks the absolute remaining budget before mutation. The suspended
  controller regression queues payload before timer delivery and proves the
  expired permit is still rejected/refunded.
- U2: the bridge carries immutable configured handoff timeout; offer starts one
  deadline before metadata lookup and requires the control snapshot to match.
  A 200 ms budget succeeds across an 80 ms delayed lookup without a 50 ms cap.
- U3: pure directed-broadcast arithmetic uses known IPv4 address/netmask vectors.
  Runtime preflight obtains a bounded public interface snapshot before binding.
  Tests cover /30 and /25 broadcasts, usable .255 unicast, and actual loopback
  directed-broadcast rejection ahead of a deliberately occupied listener.
- U4: failure seals work and retains the controller/fixed infrastructure lease
  until Service teardown. Failed drain/resume are refused. The public blocked
  writer regression checks retained bytes and writer liveness before explicit
  coordinator force, then confirms controller/worker death. Independent Python
  delayed-response/rate tests and real listener force/sibling isolation pass.

`parent-udp3-h2-green.log` records core 7, HTTP 28 and UDP proxy 17 tests, all
zero failures, seed 502446. The parent reported strict compile and command exit 0;
this reviewer read the actual counts/log and current source/tests. The earlier
`udp-repair2-green.log` is a failed intermediate run (UDP 17 tests/8 failures)
caused by the bridge startup helper retaining its link to Abyss. Parent removed
that completed helper link before the passing run; the failure remains preserved.
`udp-repair2-compile.log` is a passing compile checkpoint, not the later runtime
acceptance. Reviewer ran no Mix commands and edited no UDP production/test source.
UDP worker cumulative repair rounds remain parent-managed; no reviewer production
repair was performed. Hosted CI, publication, deployment and production
qualification are separate and unexecuted by this review.
