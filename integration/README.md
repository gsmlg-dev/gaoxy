# Acceptance boundaries

`core_consumer` is copied to a fresh temporary external project by
`scripts/external-consumer.sh`. It tests real TCP and UDP and rejects optional
HTTP/Plug/Phoenix/Bandit/QUIC dependencies and started applications. It uses the
root lock, not mutable checkout overrides.

`tls_peer.py` is an independent Python/OpenSSL TLS client called by the loopback
suite. Trust and hostname verification stay enabled; all credentials are
generated in ExUnit's temporary directory.

`scripts/release-smoke.py` tests a production release over TCP/TLS/UDP unicast.
It polls actual child-process/readiness state with a deadline, exchanges packets,
then sends SIGTERM and verifies that stream listeners are closed. This portable
smoke does **not** satisfy the required five-transport mixed release gate.

`network/fixture.py` provides isolated Linux ingress, membership, desired-state
restart and addressed egress, including interface/TTL/hop/loopback gates with
independent peers, explicit privilege opt-in and
cleanup on failure. See `network/README.md` for its precise scope. It hard-fails
missing prerequisites or zero executed gates. Local execution is unavailable
on macOS, and configured Linux CI is not executed evidence. The s93 execution
record separately proves real inet/socket combinations. `network/release_gate.py`
tests the full five-transport production release with two independent peers and
post-shutdown binding reuse. M1 keeps its full required acceptance matrix.
