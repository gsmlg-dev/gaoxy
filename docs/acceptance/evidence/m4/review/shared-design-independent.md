# Independent shared HTTP/3 design and plan review

Reviewer `/root/m4_spec_review`, independent of parent document author,
2026-10-12. Worktree `.trees/m4-http3`, branch `codex/m4-http3`, reviewed HEAD
`2b4a5e58bf3044baf289c266b96ee9a979f61309`, original baseline `78de9d0`.
The reviewed documents are uncommitted additions at that HEAD.

## Specification compliance: PASS

Reviewed `docs/designs/m4-shared-http.md` and
`docs/plans/m4-shared-http.md` against the main M4 design and Task 3/G2 plan,
plus the existing Exchange, H2 response, Transport and Admission contracts.
The supplement preserves the existing endpoint/Plug API, sole callback-owner
QUIC I/O, bounded ingress/output, original request deadline and Admission
ownership. H3 upgrades remain refused; CONNECT remains 501 for this slice.
The required independent peer, H1/H2 compatibility and busy-Plug cleanup
checks remain explicit. G2 is not presented as full M4 acceptance.

Three actionable design findings were corrected before this receipt:

- Register-before-task startup binds exactly the PID returned by the supervised
  start through an owner-only operation. The worker immediately monitors the
  owner and waits on a token-bound start barrier. Admission acquisition and
  `begin_request/4` with the original D precede readiness and dispatch. Failed
  start removes the row; no worker is linked to its callback owner.
- One absolute operation deadline D_op is retained through submission, claim,
  caller wait, blocked output and uncertain-reference resolution. It is bounded
  by original D and the configured operation wait; ticks cannot renew it.
  Zero-wait probes cannot leave destructive work executing after return.
- Owner-confirmed no-progress read/poll results complete as `:pending` and
  permit acknowledged reuse. Caller expiry or uncertain destructive outcomes
  retain terminal tombstones. Claimed-read expiry races retain consumed bytes
  in bounded ingress before replying, or terminate visibly on a lost reply
  claim. Repeated pending/read/output and expiry-race regressions are required.

The busy-Plug regression retains the explicit dispatched barrier, unreleased
Plug token, owner-only kill and live Admission. By original D plus 1,000 ms it
must observe worker DOWN, deleted ETS, released lease/bytes and monitored
resource pins, while another connection and listener complete requests.
Missing confirmation remains `termination_unconfirmed`.

No unresolved specification findings remain for the reviewed supplement.

## Implementation design and plan quality: PASS

Extracting the existing H2 response rules into a shared FramedResponse module
with explicit H2/H3 delegating wrappers avoids duplicating streaming, file,
bodyless and content-length behavior. Dispatch through the existing
`exchange.transport.operation/2` seam introduces no QUIC dependency in shared
HTTP code. H1 retains its separate wire backend.

One owner-created ETS row per admitted request and one occupied operation slot
per row provide an explicit finite rendezvous without extra runtime processes,
timers or callback-owner GenServer calls. Identity, token/reference CAS,
acknowledgement, retained unknown references and terminal timeout states are
specified together with meaningful races and cleanup observations. File
ownership and serialized Mix/live source leases are explicit. Nonzero red/green
evidence, independent specification/code review and fresh verification precede
local commits. No new dependency, publication or deployment is introduced.
No unresolved implementation-design or plan-quality findings remain.

## Reviewed source hashes and limits

- `docs/designs/m4-shared-http.md`:
  `4c8ed707bc7120d734a7e844c26e4f5e59263891a8b0f64f757348a5e5a3fb93`
- `docs/plans/m4-shared-http.md`:
  `0bf67f3fe8e59580956bddcd02c9817bb13b7da2dfc4b85f5831b69e9361770a`

This is design/plan review only. Runtime implementation, tests and live G2
acceptance are NOT RUN by this review; parent owns their gates and commits.
Reviewer read/hash commands finished; no Mix, live process or runtime source
mutation was performed during the parent's G1 lease.
