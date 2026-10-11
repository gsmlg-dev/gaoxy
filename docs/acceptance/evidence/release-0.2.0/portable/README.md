# Portable v0.2.0 qualification evidence

Source: `32ec599790ccddb477345a765681f74852e5ffc0`. The release archive and build
metadata are prepared for GitHub release assets. Their SHA256 values are
in `SHA256SUMS`; the archive itself is kept in the release assets rather than Git.

`manifest.json` records every imported file's stored and original SHA256 and byte
count. Files ending in `.log.gz`, `.erl.gz` or `.diff.gz` are lossless gzip copies. Historical
failures and pre-recovery recipe snapshots retain their original bytes.

The pinned recipe qualifies Debian bookworm/glibc Linux x86_64 with Elixir 1.18.5
and OTP 28.5.0.5. `build-info.json` records image pins, toolchain/package inventory,
the 2396 unchanged source files, all 13 build checks and compatibility totals.
Runtime libraries are libssl3, libstdc++6, libncurses6, libtinfo6 and zlib1g.
Other platform profiles and bit-reproducible output are unqualified.

The original OTP 28.5 profile failed two hostname-alert assertions while rejecting
both connections. `execution/tls-root-cause.json` and the official OTP snapshots
record the mapping change; the patched probe verifies the selected profile.
Two Sol repairs reached their actual outer deadlines and exited 124. Astra
recovery1 retained the same source, tests, commands and inner deadlines while
splitting prepare, compile and qualify into cacheable Docker layers.

Build receipts and logs are under `build/`. The builder executed 486 tests with
zero failures and the core3/gateway2 smoke checks. Fresh runtime receipts are in
`execution/fresh-runtime/`: launch and live/final Docker inspection identify the
actual image, container, `NetworkMode=none` and exit0. The runtime checksums the
exported assets, extracts the archive, checks every ELF object's dependencies,
and exercises TCP/TLS/UDP and native H1/H2 gateway traffic, shutdown and rebind.

To replay, copy `recipe/` into a new task-local `context/`, and generate
`context/source.tar` using `git archive` of the source above. Verify its SHA256
against `manifest.json` before building. Run the recorded builder command with
new output paths, then `finalize.py` and `qualify_runtime.py` from that recipe.
The recorded outer allowances are 1800 seconds for recovery build and 600 seconds
for runtime preparation plus execution. Individual checks retain their original
600/300/60-second deadlines. Preserve nonzero outcomes as failures.

Hosted execution, publication/download verification, independent review and M4
design review have separate receipts in the parent evidence directory. Production
deployment and the disabled release-artifact E2E workflow remain NOT RUN.

[Fresh GitHub download verification](../download-verification.json) confirms the
published archive, metadata and checksum file are byte-identical to the qualified
assets, with the remote tag and all five tagged versions checked separately.
