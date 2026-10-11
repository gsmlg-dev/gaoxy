Gaoxy v0.2.0 is the first gateway beta release. It adds opt-in native HTTP/2,
authenticated forward HTTP/H1 CONNECT, TCP/TLS relays, bounded UDP unicast
associations, immutable route generations, standalone HTTP configuration and
supervised dedicated-H1 upstream groups to the native H1/WebSocket/Plug runtime.

Standalone configuration is data only. Forward proxying requires explicit
authentication and destination rules; no public management endpoint is enabled.
HTTP Fetch and its coordinated transport packages are pinned to 0.21.3.

Upstream connections use dedicated HTTP/1.1 per request. Upstream pooling,
upstream HTTP/2 and native HTTP/3 are not implemented in this release. Native
H2 uses explicit TLS ALPN or prior-knowledge h2c; h2c upgrade, server push and
H2 CONNECT are unsupported. This beta is not full protocol-conformance,
security-audit or production-deployment qualification.

The release workflow checks canonical format/strict compilation and starts
the application for real TCP/TLS/UDP and native H1/H2 gateway smoke before
packaging. Current and historical acceptance is in `docs/acceptance/m3.md` and
`docs/acceptance/release-0.2.0.md`. Published platform/toolchain provenance is
recorded separately. Release artifact E2E remains disabled; deployment is separate.

Published artifact: `gaoxy-0.2.0-linux-x86_64.tar.gz`, qualified on Debian bookworm / glibc Linux x86_64. Other operating systems, architectures and libc profiles are unqualified. Required runtime libraries: libssl3, libstdc++6, libncurses6, libtinfo6 and zlib1g.

Source: `32ec599790ccddb477345a765681f74852e5ffc0`. Builder: Elixir 1.18.5 / OTP 28.5.0.5, with pinned Debian and Rust images recorded in `build-info.json`. Archive SHA256: `8e3eeb8c91f4a7cf9e5ccb2307f8623451e7872500a42a07cbc5c3d35b99aa16`. `SHA256SUMS` covers the archive and build metadata.

Validation: canonical format and strict compilation; 486 compatibility tests, zero failures; real TCP/TLS/UDP and native H1/H2 proxy traffic, finite shutdown and rebind. The exported archive passed the same runtime smoke in a fresh container with network disabled; 21 ELF objects had no missing or Nix store library dependencies. Independent specification, code and evidence review passed before publication.

Qualification used an isolated local build. The hosted workflow executed no steps and remains BLOCKED_ENV; hosted success is not claimed. Original failures and bounded recovery results are preserved in the release acceptance evidence. M4 HTTP/3 design and plan are prepared and independently reviewed; implementation and runtime acceptance are NOT RUN.
