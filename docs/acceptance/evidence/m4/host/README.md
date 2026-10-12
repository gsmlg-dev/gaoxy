# M4 G0 public-host requalification

2026-10-12, baseline `78de9d0f3bba5a4662717359438eb3d0853a79b4`, branch
`codex/m4-http3`, worktree `.trees/m4-http3`.

Implementation checks **PASS**; independent parent review is **PENDING**.
This is generic QUIC host qualification with verified `h3` ALPN, not HTTP/3
wire-protocol acceptance. H3 protocol, shared Plug, browser, upstream matrix,
hosted CI, publication and deployment gates are **NOT RUN** here.

`source.json` records final source hashes, task diff digest and the complete
workspace dirty-diff digest at its snapshot. `source.diff` preserves the tracked
task diff; new requirements and usage documentation are separately hashed. The
root lock remains byte-identical to HEAD. Only consumer `elixir_quic` and `ex_ssl`
lock entries changed, and both match root 0.21.3 tuples exactly. The public Abyss
host is `9b710e6480900e16e304f40e63623aff8c922e19`. No dependencies were patched.

`environment.log` records locked Elixir 1.18.5 / OTP 28, ERTS 16.4.0.6, OpenSSL
3.6.5, Rust 1.95.0, and the isolated Python 3.12.13 peer environment with
`aioquic==1.2.0` and all resolved package versions. Fixture keys stay in the
ignored test temporary directory; no keys are included in evidence.

Consumer lock regeneration used `unbuffer mix deps.update elixir_quic ex_ssl`
inside the locked Nix shell with `MIX_ENV=test` and `ERL_FLAGS='+S 2:2'`.
`initial-commands.json` and `final-commands.json` preserve actual fetch, compile,
format and test commands/exits. Final format and compilation passed; final tests
executed **4 tests, 0 failures**, plus **9 independently asserted peer cases**.
The final runner rejects a zero executed-test count. See `summary.json` for
individual peer results and `final-tests.log` for raw observations.

The peer independently checked 344,064 fragmented echo bytes before and after
restart, both uni directions and bidi FIN, a blocked 4,096-byte write followed
by bounded 1,024-byte output progress under a 2,048-byte stream receive window,
connection isolation, both directions of reset/STOP, and surviving request
traffic after peer cancellation. Wrong CA, hostname and ALPN were rejected.
Public reads returned IDs 0, 1 and 2; handles were kept opaque. Callbacks wait for
readiness before pulling bytes, and the host retains its configured 5,000 ms
callback watchdog. The final observed application retained high-water mark was
8,938 bytes under the 262,144-byte service ceiling; this is not total VM/native
memory accounting.

The listener was removed after its application read a readiness token on an
established connection. Removal returned in **2 ms** within the **2,000 ms**
deadline, the old Admission gate was observed DOWN, an already established
sibling listener exchanged 77,824 bytes, and the original port rebound with a
new generation and completed another full exchange. This proves bounded local
cleanup, not graceful network-protocol drain.

Write admission/status and independent received bytes remain separate
assertions. No controlled unknown-operation injection was run; observed writes
were admitted or definitively blocked. The fixture does not replay unknown
operations. Exact VM/native accounting or additional receipt requirements were
not introduced.

Preserved failure history:

- `red.log`: intended uni-tracking regression failed, 1 executed / 1 failure.
- `stop-red.log` and `stop-red-exact.log`: intended incoming STOP fixture
  regressions failed; the latter checks exact sibling-only state and empty
  pending output, 1 executed / 1 failure.
- `initial.log`: 3 tests / 1 failure from the fixture expecting `:ok` instead of
  the supported `{:ok, handle}` result of `Gaoxy.add/2`; live pre-restart wire
  cases passed. Repair 1 corrected that contract.
- `repair1.log`: 4 tests / 1 failure. Peer STOP changed the engine between polling
  events and the next write. The resulting `{:error, :stopped}` caused the old
  fixture to close the connection, preventing sibling completion.
- Repair 2 drops output only for that canceled stream on definitive `:stopped`,
  while keeping peer-code and sibling-byte assertions. `repair2.log` passed
  4 tests / 0 failures; the subsequent fresh final run also passed.

Cumulative task counters: **Sol repair rounds 2, unsuccessful rounds 1;
Astra recovery rounds 0**. Existing stage counters are not reset.

Raw logs retain the old fixture's peer-close-phase errors: public read returns
`:invalid_operation` outside the established phase, and writes can return
`:not_established` after peer close. Those messages follow intentional peer
closures; independently checked active traffic and sibling receipts passed.
The active peer STOP race is handled narrowly; other write failures and unknown
receipts still fail visibly. No assertion was weakened or skipped.

All own command sessions finished; no peer/build process remains owned by this
worker. No commits or publication were performed.
