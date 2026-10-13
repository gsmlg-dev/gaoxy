# Gaoxy v0.3.0

v0.3.0 completes M4's qualified HTTP/3 subset: opt-in native H3 listeners,
shared HTTP endpoints and Plug APIs, and fixed verified HTTPS/H3 reverse origins.
The upstream adapter uses caller-owned public Session operations and a dedicated
endpoint per request, with bounded streaming, ordered duplicate trailers,
finite deadlines and confirmed local cleanup. Standalone version 1 JSON selects
H3 explicitly; route reload preserves in-flight generations and rejects invalid
replacements while keeping the listener.

Implementation acceptance includes 530 scoped tests with no failures,
Session 50 (17 network, 2 policy, 31 boundary doubles), native/Plug/browser
47/59/19, standalone 16, clean consumers 1/2/2 and two complete independently
reviewed upstream matrices of 66 network + 2 policy checks. Assertions and
historical failures remain recorded in the repository.

The downloadable artifact is qualified for Debian bookworm/glibc Linux x86_64:

- Builder from committed source: 757 tests, 0 failures,
  with nonzero execution in all five applications and zero skipped/excluded tests.
  Canonical formatting, all 83 changed Elixir paths and strict compilation pass.
- Fresh runtime with networking disabled: core TCP/TLS/UDP, native H1/H2 gateway and
  three H3 exchanges pass, including data/zero-data and duplicate trailers.
  All 21 packaged ELF objects have no missing libraries or Nix dependencies.
  Child exit 0, normal container removal and observed absence pass.
- All five packaged applications are version 0.3.0; safe inventory has 1420 entries.
  Archive and build-info checksums are listed in SHA256SUMS.

Source: `4931982cff7b07c8e9f42a5e4561d22854d418bd`. Artifact:
`gaoxy-0.3.0-linux-x86_64.tar.gz`.
SHA256: `257b91c9b97fa5c73b9718744249a3fc00511833aa81142e36924083a58cd902`.
The release also includes `build-info.json` and `SHA256SUMS`.

H1 remains the upstream default with dedicated per-request connections.
Upstream H1 pools and upstream H2 are not implemented. H3 origins require
explicit protocol and verified HTTPS/CA configuration; no automatic fallback,
pool or request replay is provided. Installed HTTP/QUIC cohort 0.21.4 uses public
8 KiB Session fragmentation under a 16 KiB application DATA ceiling. The qualified
UP2 tiny-window profile selects 1 ms host polling and retains its original 5 s
bound; default 10 ms burst throughput remains unqualified.

Dynamic QPACK, push, H3 WebSocket, extended CONNECT, WebTransport, DATAGRAM,
0-RTT/resumption, migration, mTLS, IPv6/wildcard QUIC and graceful H3 GOAWAY drain
remain unsupported. Other release platforms are unqualified.

Hosted CI is BLOCKED_ENV: three runs/ten jobs could not start due to the existing
account restriction and executed zero steps. This release uses the separately
qualified local build. Deployment and production acceptance were not executed;
Vault, operational certificates, public management and the disabled release-artifact
E2E workflow retain their restrictions.

[M4 acceptance](https://github.com/gsmlg-opt/gaoxy/blob/main/docs/acceptance/m4.md)
and [release acceptance](https://github.com/gsmlg-opt/gaoxy/blob/main/docs/acceptance/release-0.3.0.md)
record identities, verification, independent reviews and preserved failures.
The next prepared task is existing M3 Task 4 H1 resource foundation; its
implementation is NOT RUN.
