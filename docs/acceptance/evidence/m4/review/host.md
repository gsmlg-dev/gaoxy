# G0 author verification receipt

2026-10-12. Author/verifier: `m4_dependency_audit` (Sol). This receipt is a
self-verification record, not an independent code-review verdict. The separate
`host-independent.md` records the independent reviewer disposition.

Worktree `.trees/m4-http3`, branch `codex/m4-http3`, baseline
`78de9d0f3bba5a4662717359438eb3d0853a79b4`. Owned scope: consumer pins/lock,
QUIC test fixture and aioquic peer, HTTP3 peer pin/bootstrap README and host
evidence. No core/dependency edits, upstream issues, commits or publication.

Fresh verification **PASS**: `host/parent-review-fresh-command.json` records the
actual locked-Nix-shell command, exit 0, 41.85 seconds. It ran:

```sh
export MIX_ENV=test ERL_FLAGS='+S 2:2'
cd integration/quic_consumer
unbuffer mix format --check-formatted mix.exs test/quic_test.exs
unbuffer mix compile --warnings-as-errors
unbuffer mix test --warnings-as-errors
```

The fresh run executed **4 tests, 0 failures**, with **9 independent aioquic
peer cases**. Listener removal was 3 ms against its 2,000 ms deadline. Existing
source-bound evidence records uni/bidi directions, verified h3 ALPN, CA/name/
ALPN rejection, tiny-window blocked/admitted outcomes and eventual bytes,
FIN/reset/STOP, active sibling isolation, old Admission gate DOWN, same-port
rebind/new generation and post-restart exchange. Generic QUIC under ALPN h3
is not HTTP/3 protocol acceptance.

Immediately after the fresh run every `host/source.json` input SHA256 matched
the current file. Root lock remains unchanged; only two consumer lock entries
changed and both match root 0.21.3 tuples exactly. The original source receipt,
failures and final logs were preserved. `parent-review-fresh.log` records the
new execution; the new command receipt contains peer results and counts.

No unresolved G0 implementation findings remain from the author checks.
Disclosed inherited peer-close-phase errors remain in raw logs; the repaired
active incoming STOP race drops only the definitively canceled stream and
retains sibling assertions. No unknown-operation injection was executed and
no total native/VM memory claim is made. Required HTTP/3/browser/runtime gates
remain separate.

Cumulative G0 counters: **Sol repair rounds2 / unsuccessful1 / Astra0**. The
fresh repeat needed no edits and adds no repair round. All own consumer/peer
command sessions finished and the fresh process returned exit0.
