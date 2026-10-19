# Final closeout overlay draft — not applied

Draft scope: exactly the ten current overlays inventoried in `closeout-overlay-inventory.json` (SHA256 `34379ee5ade6c5ba6d2f797c500d0184a169a04b7bfb0f1b91531729ac94ff53`). All ten current full-file hashes were checked against that inventory and matched. Replace only each recorded byte span; preserve the README title and every immutable prefix/tail byte. Historical tails are not rewritten, including their older local-only wording, counts, FAIL/BLOCKED/NOT RUN outcomes and exhausted counters.

The frozen source identity below was read from `portable-1792408662674538754/context/source-identity.json`. Fresh build output is active and was not inspected for a final verdict. The cached 200/0/90 result was read from `group-compat-repair3/result/result.json` and its independent result-review receipt. It belongs to baseline `9253b787b57b768682bb4d894f25ca82919c0a94` plus the reviewed repair overlay, not a fresh execution of the later committed source. Expected test-only RED (2 executed/2 failures) is recorded separately from GREEN; prior failed release builds retain FAIL.

Every portable/publication pending statement must be replaced only from actual reviewed receipts. No asset, remote ref, runtime, hosted-CI or deployment result follows from source acceptance or cached tests. Parent owns final release acceptance, plan, notes and publication; this draft does not modify them. Deployment, production data/certificates, Vault, public management and disabled release-artifact E2E restrictions remain intact. No specialist scenarios are executed or added.

Each fenced block is the entire proposed replacement overlay, including its trailing blank line. To use the optional ignored helper, supply a separate final JSON object mapping exactly these ten repository-relative paths to the full replacement strings; review it before invoking `apply-final-overlays.py --replacements FILE --apply`. The helper is not executed during preparation.

## README.md

```markdown
## v0.4.0 release status — 2026-10-19

Accepted source includes embedded managed H1 reuse, managed H2/h2c fixed/group upstreams, probes and Generation/resource accounting, plus native downstream H2/h2c/H3 WebSocket and Phoenix integration. Embedded HTTPS prefers H2 with H1 negotiation/no-ALPN fallback; plain TCP defaults to H1, prior-knowledge h2c is explicit, and WebSocket requires listener `extended_connect` opt-in. Standalone JSON defaults HTTP services to H1, permits explicit H2/h2c and separate H3 HTTP services and fixed H1/H3 origins, and exposes no managed handles/groups/probes or WebSocket activation. Browser H3 evidence uses controlled QUIC-first selection; automatic H3 selection with TCP available remains unqualified.

Frozen source for fresh qualification: `ebd2b12a997750109ffd3fc7db4f3eda223ab79b`. Cached reviewed repair snapshot: **200 executed invocations / 0 failures / 90 excluded / 0 skipped** (M5 138, M3 unit 38, M3 network 24); counts overlap across commands and are not a unique-test total. Fresh source-bound portable builder, offline packaged runtime/ELF checks and packaged H2/h2c/H3 WebSocket profiles: **PENDING**. GitHub remote refs/release/assets and downloaded-byte verification: **PENDING**. Cached tests establish no hosted-CI result. See [release acceptance](docs/acceptance/release-0.4.0.md) for the separate gates and receipts.

Earlier snapshots below retain their capture-time scope and actual outcomes. Remaining exceptional/disconnect, slow-peer, pressure, sustained-load and combined qualification stays with the specialist test environment. Deployment and production acceptance remain outside this release.

```

## implement-plan.md

```markdown
## v0.4.0 release status — 2026-10-19

M3 and M5 source acceptance remains complete within implemented functionality and ordinary verification scope. The release tracks frozen source, cached repair evidence, fresh portable packaged bytes, offline runtime and publication/download verification separately. The existing milestone plans and historical results below retain their capture-time identities, counts and limits. Specialist qualification remains assigned to its dedicated environment.

Frozen source for fresh qualification: `ebd2b12a997750109ffd3fc7db4f3eda223ab79b`. Cached reviewed repair snapshot: **200 executed invocations / 0 failures / 90 excluded / 0 skipped** (M5 138, M3 unit 38, M3 network 24); counts overlap across commands and are not a unique-test total. Fresh source-bound portable builder, offline packaged runtime/ELF checks and packaged H2/h2c/H3 WebSocket profiles: **PENDING**. GitHub remote refs/release/assets and downloaded-byte verification: **PENDING**. Cached tests establish no hosted-CI result. See [release acceptance](docs/acceptance/release-0.4.0.md) for the separate gates and receipts.

Earlier snapshots below retain their capture-time scope and actual outcomes. Remaining exceptional/disconnect, slow-peer, pressure, sustained-load and combined qualification stays with the specialist test environment. Deployment and production acceptance remain outside this release.

```

## docs/capabilities.md

```markdown
## v0.4.0 release status — 2026-10-19

Accepted embedded capabilities include managed H1 reuse, managed H2/h2c fixed/group upstreams, probes and Generation/resource accounting, and native downstream H2/h2c/H3 WebSocket. Embedded HTTPS is H2-first with H1 negotiation/no-ALPN fallback; plain TCP defaults to H1, prior-knowledge h2c and listener `extended_connect` opt-in are explicit. Standalone JSON defaults HTTP services to H1, allows explicit H2/h2c and separate H3 HTTP services and fixed H1/H3 origins, but exposes no managed handles/groups/probes or WebSocket activation. Upstream H2/H3 WebSocket proxying remains outside M5. Browser H3 acceptance uses controlled QUIC-first selection; automatic selection with TCP available remains unqualified.

Frozen source for fresh qualification: `ebd2b12a997750109ffd3fc7db4f3eda223ab79b`. Cached reviewed repair snapshot: **200 executed invocations / 0 failures / 90 excluded / 0 skipped** (M5 138, M3 unit 38, M3 network 24); counts overlap across commands and are not a unique-test total. Fresh source-bound portable builder, offline packaged runtime/ELF checks and packaged H2/h2c/H3 WebSocket profiles: **PENDING**. GitHub remote refs/release/assets and downloaded-byte verification: **PENDING**. Cached tests establish no hosted-CI result. See [release acceptance](acceptance/release-0.4.0.md) for the separate gates and receipts.

Earlier snapshots below retain their capture-time scope and actual outcomes. Remaining exceptional/disconnect, slow-peer, pressure, sustained-load and combined qualification stays with the specialist test environment. Deployment and production acceptance remain outside this release.

```

## docs/implementation-status.md

```markdown
## v0.4.0 release status — 2026-10-19

M3/M5 implementation and ordinary source acceptance are complete. The reviewed repair restores the native numeric limit map for ordinary H2/H3 Exchanges while retaining existing WebSocket metadata only on actual WebSocket requests; strict managed-group accounting remains unchanged. Cached repair verification passed within its bounded snapshot. Fresh portable qualification and publication are separate gates tied to the frozen source and packaged bytes; earlier snapshots below retain their original status.

Frozen source for fresh qualification: `ebd2b12a997750109ffd3fc7db4f3eda223ab79b`. Cached reviewed repair snapshot: **200 executed invocations / 0 failures / 90 excluded / 0 skipped** (M5 138, M3 unit 38, M3 network 24); counts overlap across commands and are not a unique-test total. Fresh source-bound portable builder, offline packaged runtime/ELF checks and packaged H2/h2c/H3 WebSocket profiles: **PENDING**. GitHub remote refs/release/assets and downloaded-byte verification: **PENDING**. Cached tests establish no hosted-CI result. See [release acceptance](acceptance/release-0.4.0.md) for the separate gates and receipts.

Earlier snapshots below retain their capture-time scope and actual outcomes. Remaining exceptional/disconnect, slow-peer, pressure, sustained-load and combined qualification stays with the specialist test environment. Deployment and production acceptance remain outside this release.

```

## docs/native-http.md

```markdown
## v0.4.0 release status — 2026-10-19

Embedded HTTP/Phoenix HTTPS defaults to H2-first ALPN with H1 negotiation/no-ALPN fallback. Plain TCP defaults to H1; cleartext H2 requires explicit `protocols: [:http2], h2c: :prior_knowledge`, without HTTP/1 Upgrade or mixed detection. Native H2/H3 WebSocket requires listener `extended_connect` opt-in, plus exact `websocket_paths` for Phoenix. External Phoenix H3 uses a separate optional service with `server: false`. Standalone JSON defaults HTTP services to H1 and accepts explicit H2/h2c or a separate H3 HTTP service, but cannot activate WebSocket endpoints. Clients select the actual WebSocket transport; an H2 page alone does not establish H2 WebSocket negotiation.

Frozen source for fresh qualification: `ebd2b12a997750109ffd3fc7db4f3eda223ab79b`. Cached reviewed repair snapshot: **200 executed invocations / 0 failures / 90 excluded / 0 skipped** (M5 138, M3 unit 38, M3 network 24); counts overlap across commands and are not a unique-test total. Fresh source-bound portable builder, offline packaged runtime/ELF checks and packaged H2/h2c/H3 WebSocket profiles: **PENDING**. GitHub remote refs/release/assets and downloaded-byte verification: **PENDING**. Cached tests establish no hosted-CI result. See [release acceptance](acceptance/release-0.4.0.md) for the separate gates and receipts.

Earlier snapshots below retain their capture-time scope and actual outcomes. Remaining exceptional/disconnect, slow-peer, pressure, sustained-load and combined qualification stays with the specialist test environment. Deployment and production acceptance remain outside this release.

```

## docs/http3.md

```markdown
## v0.4.0 release status — 2026-10-19

Accepted source supports native H3 HTTP and RFC 9220 WebSocket through the optional embedded H3 service with explicit listener `extended_connect` opt-in. Standalone JSON can select an H3 HTTP service and fixed H3 origin, but cannot activate WebSocket endpoints or configure managed H1/H2 handles/groups/probes. External Phoenix H3 uses `server: false` and exact `websocket_paths`. Browser acceptance uses controlled QUIC-first selection; automatic H3 selection with TCP available remains unqualified. The recorded rejected-Origin 403 used H1 TLS and does not establish an H3-specific Origin-rejection result.

Frozen source for fresh qualification: `ebd2b12a997750109ffd3fc7db4f3eda223ab79b`. Cached reviewed repair snapshot: **200 executed invocations / 0 failures / 90 excluded / 0 skipped** (M5 138, M3 unit 38, M3 network 24); counts overlap across commands and are not a unique-test total. Fresh source-bound portable builder, offline packaged runtime/ELF checks and packaged H2/h2c/H3 WebSocket profiles: **PENDING**. GitHub remote refs/release/assets and downloaded-byte verification: **PENDING**. Cached tests establish no hosted-CI result. See [release acceptance](acceptance/release-0.4.0.md) for the separate gates and receipts.

Earlier snapshots below retain their capture-time scope and actual outcomes. Remaining exceptional/disconnect, slow-peer, pressure, sustained-load and combined qualification stays with the specialist test environment. Deployment and production acceptance remain outside this release.

```

## docs/http-proxy.md

```markdown
## v0.4.0 release status — 2026-10-19

Accepted embedded source implements managed H1 reuse, managed H2/h2c fixed/group upstreams, probes and Generation/resource ownership through public HTTPFetch 0.21.10 APIs. Managed H2/h2c requires explicit transport handles. Standalone JSON origins remain `http1` (default) or `http3`; JSON exposes no managed handles/groups/probes or WebSocket activation. JSON downstream HTTP services default to H1 and permit explicit H2/h2c or a separate H3 service. Native downstream WebSocket support does not add upstream H2/H3 WebSocket proxy transports.

Frozen source for fresh qualification: `ebd2b12a997750109ffd3fc7db4f3eda223ab79b`. Cached reviewed repair snapshot: **200 executed invocations / 0 failures / 90 excluded / 0 skipped** (M5 138, M3 unit 38, M3 network 24); counts overlap across commands and are not a unique-test total. Fresh source-bound portable builder, offline packaged runtime/ELF checks and packaged H2/h2c/H3 WebSocket profiles: **PENDING**. GitHub remote refs/release/assets and downloaded-byte verification: **PENDING**. Cached tests establish no hosted-CI result. See [release acceptance](acceptance/release-0.4.0.md) for the separate gates and receipts.

Earlier snapshots below retain their capture-time scope and actual outcomes. Remaining exceptional/disconnect, slow-peer, pressure, sustained-load and combined qualification stays with the specialist test environment. Deployment and production acceptance remain outside this release.

```

## docs/gateway.md

```markdown
## v0.4.0 release status — 2026-10-19

Accepted embedded gateway capabilities include managed H1 reuse, managed H2/h2c fixed/group upstreams, probes and bounded Generation/resource accounting. H2/h2c uses explicit managed handles. Standalone JSON supports fixed H1/H3 origins and HTTP services defaulting to H1 with explicit H2/h2c or separate H3 selection, without managed handles/groups/probes or WebSocket activation. Authentication, destination validation and connection-time policy requirements remain in force.

Frozen source for fresh qualification: `ebd2b12a997750109ffd3fc7db4f3eda223ab79b`. Cached reviewed repair snapshot: **200 executed invocations / 0 failures / 90 excluded / 0 skipped** (M5 138, M3 unit 38, M3 network 24); counts overlap across commands and are not a unique-test total. Fresh source-bound portable builder, offline packaged runtime/ELF checks and packaged H2/h2c/H3 WebSocket profiles: **PENDING**. GitHub remote refs/release/assets and downloaded-byte verification: **PENDING**. Cached tests establish no hosted-CI result. See [release acceptance](acceptance/release-0.4.0.md) for the separate gates and receipts.

Earlier snapshots below retain their capture-time scope and actual outcomes. Remaining exceptional/disconnect, slow-peer, pressure, sustained-load and combined qualification stays with the specialist test environment. Deployment and production acceptance remain outside this release.

```

## docs/acceptance/m3-completion.md

```markdown
## v0.4.0 release status — 2026-10-19

M3 remains accepted complete within implemented functionality and ordinary verification scope. Its original local-merge verification and historical implementation receipts below retain their own source identities and counts. The release repair preserves strict group-accounting limits and restores ordinary H2/H3 Exchange compatibility. Later release work does not certify absent capabilities or specialist qualification; fresh portable runtime and publication/download evidence remain separate gates.

Frozen source for fresh qualification: `ebd2b12a997750109ffd3fc7db4f3eda223ab79b`. Cached reviewed repair snapshot: **200 executed invocations / 0 failures / 90 excluded / 0 skipped** (M5 138, M3 unit 38, M3 network 24); counts overlap across commands and are not a unique-test total. Fresh source-bound portable builder, offline packaged runtime/ELF checks and packaged H2/h2c/H3 WebSocket profiles: **PENDING**. GitHub remote refs/release/assets and downloaded-byte verification: **PENDING**. Cached tests establish no hosted-CI result. See [release acceptance](release-0.4.0.md) for the separate gates and receipts.

Earlier snapshots below retain their capture-time scope and actual outcomes. Remaining exceptional/disconnect, slow-peer, pressure, sustained-load and combined qualification stays with the specialist test environment. Deployment and production acceptance remain outside this release.

```

## docs/acceptance/m5-websocket-over-h2-h3.md

```markdown
## v0.4.0 release status — 2026-10-19

M5 G0–G5 source acceptance remains complete within ordinary scope: native H2/h2c/H3 WebSocket, H2-first embedded HTTPS with H1 fallback and the recorded Phoenix profiles. Prior-knowledge h2c, listener `extended_connect` opt-in and exact Phoenix `websocket_paths` are explicit. Standalone JSON defaults HTTP services to H1, permits explicit H2/h2c and separate H3 HTTP services, and cannot activate WebSocket endpoints. Browser clients choose transport: H3 evidence is controlled QUIC-first; automatic H3 selection with TCP available remains unqualified. The rejected-Origin 403 used H1 TLS. Fresh packaged-byte qualification and publication are separate release gates.

Frozen source for fresh qualification: `ebd2b12a997750109ffd3fc7db4f3eda223ab79b`. Cached reviewed repair snapshot: **200 executed invocations / 0 failures / 90 excluded / 0 skipped** (M5 138, M3 unit 38, M3 network 24); counts overlap across commands and are not a unique-test total. Fresh source-bound portable builder, offline packaged runtime/ELF checks and packaged H2/h2c/H3 WebSocket profiles: **PENDING**. GitHub remote refs/release/assets and downloaded-byte verification: **PENDING**. Cached tests establish no hosted-CI result. See [release acceptance](release-0.4.0.md) for the separate gates and receipts.

Earlier snapshots below retain their capture-time scope and actual outcomes. Remaining exceptional/disconnect, slow-peer, pressure, sustained-load and combined qualification stays with the specialist test environment. Deployment and production acceptance remain outside this release.

```

