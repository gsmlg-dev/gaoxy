Gaoxy v0.5.0 replaces Thousand Island with [Hell](https://github.com/gsmlg-dev/hell) 0.1.2 for TCP/OTP TLS. Gaoxy now uses the public `Hell` namespace and `:hell` OTP application. The dependency is pinned to `59eed42b019ca41413d1b8cd7a7dc3e344bb93ee`; the old Thousand Island application is absent from the package. Accepted protocol and Phoenix functionality and the HTTP/QUIC dependency cohort are unchanged.

Retained functionality includes native H1/H2/h2c/H3 HTTP, downstream RFC 8441/9220 WebSocket and Phoenix integration, embedded managed H1 reuse and managed H2/h2c fixed/group upstreams, probes and Generation/resource accounting. Embedded HTTPS prefers H2 with H1 fallback; plain TCP defaults to H1, h2c is explicit, and extended CONNECT requires listener opt-in and exact Phoenix WebSocket paths.

Standalone JSON defaults HTTP services to H1 and supports explicit H2/h2c and a separate H3 HTTP service, with fixed H1/H3 origins. JSON does not activate managed upstream handles/groups/probes or WebSocket endpoints. Packaged WebSocket verification uses the public embedded API.

The Linux amd64 (x86_64) Debian bookworm/glibc archive was built from `b0e1531b9d2ac682e4af19d4616ad4461e3ca6f2` with Elixir 1.18.5 and OTP 28.5.0.5 / ERTS 16.4.0.5. Fresh ordinary qualification passed:

- Formatting and strict production compilation.
- **210 test executions, 0 failures, 144 excluded, 0 skipped**, counted across the recorded invocations.
- Packaged H2/h2c/H3 WebSocket profiles **15/15 each**, in both the builder and a fresh runtime with external networking disabled.
- Core TCP/TLS/UDP, gateway H1/H2 and three H3 smoke checks in both environments.
- Public packaged-release Hell startup/version and dependency checks in both environments.
- Custody of **22,125 unchanged source files**, safe inventory of **1,439 archive entries**, checksums, and **21 ELF objects / 0 missing libraries / 0 Nix dependencies**. The offline runtime exited normally and its owned container was removed and observed absent.

Assets: `gaoxy-0.5.0-linux-x86_64.tar.gz`, `build-info.json` and `SHA256SUMS`. Archive SHA256: `3e750adae17bb8ecf8ecb3da3889bc743a43006432179a23c33bf76190a7d128`. Other operating systems, architectures and libc variants remain unqualified for this archive.

Clients choose the actual WebSocket transport. Retained browser H3 evidence uses controlled QUIC-first selection; automatic H3 selection with TCP available remains unqualified. The recorded rejected-Origin 403 used H1 TLS. Historical browser results retain their original source identities; this release's fresh peer checks do not constitute a new browser run.

Outbound H2/H3 WebSocket proxying, compression, generic H2/H3 CONNECT, WebTransport, DATAGRAM and existing H3 limitations remain outside this release. Specialist abnormal/disconnect, slow-peer, pressure, load and soak qualification remains assigned to its dedicated environment, with historical results and assertions preserved.

New hosted CI is **NOT RUN**; release commits retain `[skip ci]`. Release-artifact E2E remains disabled. Deployment, production operation, Hex/OCI publication, production data/certificates, Vault and public management changes remain outside this release.
