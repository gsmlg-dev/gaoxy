# M4 public Session fragment-size amendment

Bounded recovery candidate, 2026-10-13; `SOL_REPEATED_FAILURE`, implementation
mode, direct-chain Astra round 2. Parent explicitly authorized this configuration
amendment. Independent Sol specification/code review and runtime remain required.

## Decision and precedence

Use the supported `Session.new(max_frame: 8_192)` option for the selected public
Session client and its qualification harness. This supersedes only the
`max_frame: 16_384` choice in [the original Session design](m4-public-session-upstream.md).
The [consumer-affinity amendment](m4-public-session-consumer-affinity.md) and
original design otherwise remain unchanged and byte-for-byte preserved.

This setting controls encoded transport fragment size, not the application DATA
ceiling. `Session.send_data/5` still receives up to 16,384 application bytes;
the tiny-window case still sends 64 such chunks, verifies all 1,048,576 bytes
and their hash, and retains the peer's initial 16,384-byte stream window. No
application chunk is split or replayed by Gaoxy; Session owns wire fragmentation.

## Source and observed failure

Baseline: `codex/m4-http3`, HEAD `c574c784da5474117b7e911693fdc564d8565bf8`,
cohort 0.21.4, root lock SHA256
`aa9220766e1699f5cfa9d8513df95910a613cf2cbba37e8ce977267e3b68d9ab`.
[Astra1's actual run](../acceptance/evidence/m4/upstream-contract/run-1791831993043786216/result.json)
failed after 31 double and six network rows. Request HEADERS consumed some stream
credit; the first 16,384-byte encoded send could not fit the remaining window.
822 resumptions remained blocked, the peer received no DATA, and the original
deadline expired. The final missing guardian RPC response does not establish
confirmed cleanup for that request; preserve that absence.

Installed `Session.new/1` accepts `max_frame` from 1 through 16,384 (lines 49–67).
`data_steps/chunks` splits complete public DATA-frame bytes using that size
(618–626), preserving one original application operation and terminal FIN.
QUIC admits each fragment atomically against current credit; it receives new
MAX_STREAM_DATA independently of application polling. aioquic doubles its receive
window after more than half the current limit arrives. With this fixture's small
HEADERS already received, an 8,192-byte prefix fits the remaining initial credit
and crosses that growth threshold. Later fragments can resume within the same
original deadline. This is a supported configuration route to the prescribed
gate, not a confirmed missing required SDK capability.

`max_frame` also caps each transport read (Session line 462). Reads become at
most 8,192 bytes; `max_read_batches: 1`, paused refs, ACK ordering and existing
queue/event/deadline limits stay unchanged. Response parsing limits do not derive
from `max_frame` (request decoder construction at 537–543). More bounded reads
and sends may cost time; the original finite runtime gate must still pass.

Alternatives: retaining 16,384 fragments reproduces the fixture stall; increasing
the peer window or reducing the 1 MiB requirement would change acceptance and is
rejected. Selecting the supported 8,192 setting retains the original product
requirements. Arbitrary-peer residual-window guarantees are not added here.

The diagnosis-only `session-astra2-upstream-diagnosis-1791832393639.json` remains
immutable historical reasoning. Its upstream-blocker conclusion is superseded
by this supported route; its observed default-configuration failure remains true.
The default-configuration interoperability issue is tracked as severity `needed`
in [http_fetch#105](https://github.com/gsmlg-dev/http_fetch/issues/105). The 8 KiB
public setting is an explicitly marked temporary workaround; its runtime is
still unqualified. A newly demonstrated required API gap still follows normal
dependency routing; no private state or dependency patch is permitted.

## Invariants and acceptance

Preserve the stable caller/guardian architecture, public endpoint adoption/stop,
all-task DOWN evidence, cleanup uncertainty, no unknown-admission replay, exact
DATA/trailer/FIN bytes, 16 KiB application limits, original absolute deadlines,
all 50 row names/classifications and every original peer assertion. No queue,
reservation, TLS, policy, dependency or production activation change is selected.

Add deterministic public-codec/Transport subcases to the existing
`blocked_suspend_poll_resume` row: a 16 KiB DATA body encodes to 16,389 bytes,
sent as 8,192 + 8,192 + 5. Assert exact concatenation and FIN only on the last
fragment. When the second fragment is definitely blocked, resume it without
resending the accepted prefix; when admission is unknown, reconcile it without
replaying that fragment. Retain the prior paused-control cases.

Follow [the task delta](../plans/m4-session-frame-fragmentation.md). Static
preparation does not pass UP0 or confirm the previous request's cleanup.
