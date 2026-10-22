# Acceptance boundaries

`test_consumer`, `test_h3_consumer`, and `http_fetch_test_consumer` are copied to
fresh temporary projects by `python3 scripts/test-consumers.py`. Before
publication the script builds actual Hex tarballs, extracts their runtime files
and trust assets, and uses explicit fixture-only path mappings for the aligned
unreleased sibling packages. Other dependencies resolve from Hex. The base
consumer requires the shared `http_core`, QUIC and ExSSL dependencies and proves
the H3 server extension, HPAX, proxy and client packages are physically absent.
Manual mode starts no ExUnit runner, and the test-only dependency is absent from
a real production release. The explicit H3 consumer reuses the independent validating
aioquic peer. HTTPFetch uses its published public API in a separate project.

Future HTTPFetch migration candidates are ordinary request/response, upload,
redirect, finite SSE and H1 WebSocket scenarios that need expectation or teardown
verification. This delivery demonstrates adoption through the isolated consumer;
it does not migrate HTTPFetch's existing suites. Keep malformed-frame, exact-reset
and independent interoperability peers where their wire control is required.

After publication run `python3 scripts/test-consumers.py --published --version
VERSION`; this omits every local override and resolves fresh Hex-only consumers.
Set `GAOXY_QUIC_PYTHON` to a Python environment with the pinned dependencies in
`integration/http3/requirements.txt`. A missing peer prerequisite is a failed
gate, never an implicit skipped success.

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
