# v0.4.0 ordinary portable release qualification

Date: 2026-10-19. The user explicitly authorizes commit, main integration, push
and the next GitHub release. The selected version is 0.4.0, following published
v0.3.0. Deployment and production operations remain outside this release.

The candidate combines accepted M3 managed H1/H2 upstream resources and M5 native
WebSocket over H2/h2c/H3. Preserve the implementation acceptances, their historical
failures and the specialist-test handoff. The JSON standalone schema retains its
actual boundary: it does not activate managed upstream handles/groups/probes or
WebSocket endpoints. Embedded HTTPS prefers H2; JSON's explicit H1 default and
explicit prior-knowledge h2c remain distinct.

Reuse the reviewed v0.3.0 portable recipe in a new v0.4.0 directory, keeping the
old files unchanged. Retain its pinned Debian/glibc x86_64 toolchain, staged
build, committed-source archive/hash checks, safe package extraction, five
application-version checks, checksums, ELF linkage inspection and finite owned
container cleanup. Record actual versions and counts, rather than reusing old
binary or test receipts.

Replace the old whole-directory test execution with the exact 17-file M5
ordinary scope and accepted M3 ordinary merge selectors (38 pure/configuration
and 24 positive network cases). Record selected and excluded counts separately;
require nonzero executed cases and zero failures for every command. Existing
assertions remain intact. Abnormal/disconnect, slow-peer, pressure and sustained
load scenarios remain in their dedicated environment.

Keep the old H2/H3 smoke peer environment and the separately pinned M5 peer
environment separate. The packaged WebSocket runner uses public release
`bin/gaoxy eval` to start the existing embedded fixture with packaged application
beams. It retains all 15 independent-peer cases, normal Close, resource release
and runtime DOWN assertions for H2, h2c and H3. It uses no Mix or Phoenix fixture
beams. Builder and fresh offline runtime both execute these profiles alongside
the existing core TCP/TLS/UDP, H1/H2 gateway and three H3 smoke exchanges.

The runtime runs with network mode none and readonly artifact input; real
loopback sockets remain available. Retain the 600-second parent / 300-second
child bounds and cleanup reserves. Forced cleanup remains FAIL. Independently
review the recipe before execution and actual artifact/runtime/notes afterward.

Do not dispatch the automatic release publisher or enable E2E. Push-triggered
CI currently includes the excluded broad suites and 600-second soak; release
and final documentation commits use GitHub's `[skip ci]` marker. Record new
hosted verification as NOT RUN, separately from historical BLOCKED_ENV jobs.
All ordinary release gates execute locally; no account/settings changes follow.

Publish an annotated immutable-by-convention v0.4.0 tag and exactly the release
archive, build-info.json and SHA256SUMS after review. Verify remote source/tag,
fresh-download all assets and compare their bytes/hashes to qualified originals.
The documentation closeout may follow the frozen artifact source as a separate
commit. Inherited repair counters remain unchanged; Astra recovery stays 2/2.
