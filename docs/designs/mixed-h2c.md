# HTTP/1.1 and prior-knowledge H2 on one TCP listener

## Scope and source

Implement the connection-selection contract in `prompt.md`, starting from
`ec1fead8` (the reviewed 0.5.5 baseline plus the existing dependency refresh).
The user authorizes implementation, ordinary verification, independent review,
commit, push and release. Preserve accepted M3/M5 scope and historical evidence;
specialist exceptional/pressure/soak qualification, Upgrade, HTTP/3 and upstream
negotiation remain outside this change.

## Public contract

`transport: :tcp, protocols: [:http2, :http1], h2c: :prior_knowledge` enables
mixed mode. Standalone accepts the same values as JSON strings. Embedded,
standalone and Phoenix configuration all reach `Gaoxy.HTTP.Connection`.
Defaults, protocol ordering, unknown-value rejection, H2 host/budget checks and
invalid transport/h2c combinations remain intact. There is no `:auto` option.

## Architecture and alternatives

Use a small pure incremental classifier and a mixed-only detecting phase in
the native handler. This preserves active-once events and existing ownership.
A separate socket-reading process would complicate handoff and admission;
blocking receives would bypass Hell's lifecycle. Neither is needed.

Compare against all 24 bytes of the H2 preface. Empty input and an incomplete
matching prefix remain undecided; the first mismatch chooses H1; a complete
match chooses H2. Carry at most 23 copied bytes, without retaining a larger
backing binary. On selection, replay carry followed by the complete incoming
delivery exactly once, including preface, headers, bodies and pipelined bytes.
Check the selected engine's ingress limit before concatenation. Selection is
permanent, including when parsing later fails.

Detection acquires one owner lease with drain notifications. Retained prefix
bytes are charged. Initializers reuse that lease; H2 grows its owner reservation
before allocating decoder/writer state, retaining its separate writer lease and
stream accounting. Keep runtime host/budget checks. Failure returns a safe
uninitialized context, never partial H2 state. The existing owner-exit cleanup
reclaims the lease. Drain closes undecided connections immediately, and request
admission remains an explicit selected-engine check.

## Deadlines and lifecycle

Before input, preserve the existing finite idle timeout. Record first input
using monotonic milliseconds. Detection's fixed deadline is first input plus
the minimum header, request and H2 frame timeout. More prefix bytes do not renew
it. H1's first header/request deadlines use that first-input timestamp; later
keep-alive requests keep existing semantics. H2's startup timer gets only the
remaining first-input allowance and still completes on acknowledgment of server
SETTINGS. Its separate partial-frame timer remains unchanged.

Handle detector timeout tokens before H2 delegation. Cancel timers on selection
and lifecycle completion; stale queued messages are ignored after selection.
Existing engine cleanup handles selected connections, while detecting
close/error/timeout/shutdown requires no H2 resources.

## Verification and release

Focused deterministic tests cover configuration entry points; all classifier
splits and bounded carry; live H1 and independent Python H2 clients on the same
port; exact H1 body/pipeline and H2 preface/SETTINGS/HEADERS handoff; fixed
deadlines; stale timers; lease identity/reservations; drain, close and failed
initialization. Run affected ordinary H1/H2/TLS/body/keep-alive/WebSocket/stream
regressions and existing CI/release gates without specialist qualification.

Independent specification review precedes final code-quality review. Record
source, commands, nonzero counts and explicit outcomes. Select the next unused
coordinated version from current policy/tags; use the established portable
standalone artifact process, then verify remote commit/tag/assets separately
from deployment, which is not authorized.
