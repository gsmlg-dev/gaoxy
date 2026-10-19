# Proposed v0.4.0 closeout overlays

These are draft replacements for exactly the ten recorded overlays. No publication claim is made: every `PENDING_*` value must be replaced only from actual, independently reviewed receipts. If a gate has not passed, retain its actual FAIL/BLOCKED/NOT RUN/PENDING status. Counts are executed invocations per command, not aggregate unique-test claims.

Apply only the recorded byte span in `closeout-overlay-inventory.json`; preserve the immutable prefix and tail and recheck their hashes. README retains its existing `# Gaoxy` title. Source acceptance, builder verification, fresh offline runtime, hosted CI, publication and deployment remain separate. Do not infer any hosted-CI result from local portable verification.

The repeated status sentence is intentionally explicit while receipts are pending; the parent can replace it with concise verified results and the exact acceptance link. Historical tails stay unchanged. Specialist abnormal/disconnect/slow-peer/pressure/sustained-load and combined qualification remains excluded; no deployment, production data/certificates, Vault, public-management or disabled release-artifact E2E action is added. H2 page negotiation never guarantees H2 WebSockets.

## README.md

```markdown
## v0.4.0 release status — 2026-10-19

Accepted source includes embedded managed H1 reuse and H2/h2c fixed/group upstreams, probes and Generation/resource accounting, plus native H2/h2c/H3 WebSocket and Phoenix integration. Embedded HTTPS prefers H2 with H1 fallback; prior-knowledge h2c is explicit and WebSocket support requires independent opt-in. Standalone JSON retains explicit H1 HTTP service selection and fixed H1/H3 origins, without managed resource configuration or WebSocket activation. Browser transport selection remains client-controlled; H3 browser evidence uses controlled QUIC-first selection.

Frozen release source: `PENDING_RELEASE_SOURCE_SHA`. Portable builder: `PENDING_BUILD_EXECUTED_INVOCATIONS` executed invocations / `PENDING_BUILD_FAILURES` failures; fresh offline packaged runtime: `PENDING_RUNTIME_VERDICT`; packaged H2/h2c/H3 WebSocket profile counts: `PENDING_PACKAGED_WS_COUNTS`. GitHub release, remote refs and downloaded-byte verification: `PENDING_PUBLICATION_AND_DOWNLOAD_VERDICT`. See [release acceptance](docs/acceptance/release-0.4.0.md) for exact source, commands and limits.

Earlier snapshots below retain their capture-time scope. Specialist abnormal/disconnect/slow-peer/pressure/sustained-load and combined qualification remains excluded; deployment and production acceptance are outside this release.

```

## implement-plan.md

```markdown
## v0.4.0 release status — 2026-10-19

M3 and M5 source acceptance is complete within ordinary verification scope. Release work binds the frozen source, fresh portable builder/runtime qualification and GitHub publication/download verification to separate receipts. Source completion does not establish portable or publication completion. The source behaviors and browser-selection limits recorded below remain authoritative; specialist validation stays with its dedicated environment.

Frozen release source: `PENDING_RELEASE_SOURCE_SHA`. Portable builder: `PENDING_BUILD_EXECUTED_INVOCATIONS` executed invocations / `PENDING_BUILD_FAILURES` failures; fresh offline packaged runtime: `PENDING_RUNTIME_VERDICT`; packaged H2/h2c/H3 WebSocket profile counts: `PENDING_PACKAGED_WS_COUNTS`. GitHub release, remote refs and downloaded-byte verification: `PENDING_PUBLICATION_AND_DOWNLOAD_VERDICT`. See [release acceptance](docs/acceptance/release-0.4.0.md) for exact source, commands and limits.

Earlier snapshots below retain their capture-time scope. Specialist abnormal/disconnect/slow-peer/pressure/sustained-load and combined qualification remains excluded; deployment and production acceptance are outside this release.

```

## docs/capabilities.md

```markdown
## v0.4.0 release status — 2026-10-19

Accepted source supports embedded managed H1 reuse, managed H2/h2c fixed/group upstreams and native downstream H2/h2c/H3 WebSocket. Embedded HTTPS prefers H2 with H1 fallback; prior-knowledge h2c and listener WebSocket opt-in remain explicit. Standalone JSON supports explicit H1 HTTP services and fixed H1/H3 origins, without managed resource handles/groups/probes or WebSocket activation. H3 browser acceptance is controlled QUIC-first; automatic H3 selection while TCP is available remains unqualified. Upstream WebSocket proxying over H2/H3 remains outside M5.

Frozen release source: `PENDING_RELEASE_SOURCE_SHA`. Portable builder: `PENDING_BUILD_EXECUTED_INVOCATIONS` executed invocations / `PENDING_BUILD_FAILURES` failures; fresh offline packaged runtime: `PENDING_RUNTIME_VERDICT`; packaged H2/h2c/H3 WebSocket profile counts: `PENDING_PACKAGED_WS_COUNTS`. GitHub release, remote refs and downloaded-byte verification: `PENDING_PUBLICATION_AND_DOWNLOAD_VERDICT`. See [release acceptance](acceptance/release-0.4.0.md) for exact source, commands and limits.

Earlier snapshots below retain their capture-time scope. Specialist abnormal/disconnect/slow-peer/pressure/sustained-load and combined qualification remains excluded; deployment and production acceptance are outside this release.

```

## docs/implementation-status.md

```markdown
## v0.4.0 release status — 2026-10-19

M3/M5 source implementation and ordinary acceptance are complete. Portable qualification and publication are separate gates bound to the frozen release source and the exact packaged bytes. The earlier source-only, local-only and capability snapshots below retain their capture-time status; this release overlay records later results only after the corresponding receipts are verified.

Frozen release source: `PENDING_RELEASE_SOURCE_SHA`. Portable builder: `PENDING_BUILD_EXECUTED_INVOCATIONS` executed invocations / `PENDING_BUILD_FAILURES` failures; fresh offline packaged runtime: `PENDING_RUNTIME_VERDICT`; packaged H2/h2c/H3 WebSocket profile counts: `PENDING_PACKAGED_WS_COUNTS`. GitHub release, remote refs and downloaded-byte verification: `PENDING_PUBLICATION_AND_DOWNLOAD_VERDICT`. See [release acceptance](acceptance/release-0.4.0.md) for exact source, commands and limits.

Earlier snapshots below retain their capture-time scope. Specialist abnormal/disconnect/slow-peer/pressure/sustained-load and combined qualification remains excluded; deployment and production acceptance are outside this release.

```

## docs/native-http.md

```markdown
## v0.4.0 release status — 2026-10-19

Embedded HTTP/Phoenix HTTPS prefers H2 with H1 negotiation/no-ALPN fallback. Plain TCP stays H1 unless prior-knowledge h2c is selected explicitly; no Upgrade or mixed detection is implied. Native H2/H3 WebSocket requires listener extended_connect opt-in, and Phoenix requires exact websocket_paths. External Phoenix H3 uses a separate optional service with server: false. Standalone JSON retains explicit H1 HTTP selection and cannot activate WebSocket endpoints. Clients select actual WebSocket transport; H3 browser evidence is controlled QUIC-first.

Frozen release source: `PENDING_RELEASE_SOURCE_SHA`. Portable builder: `PENDING_BUILD_EXECUTED_INVOCATIONS` executed invocations / `PENDING_BUILD_FAILURES` failures; fresh offline packaged runtime: `PENDING_RUNTIME_VERDICT`; packaged H2/h2c/H3 WebSocket profile counts: `PENDING_PACKAGED_WS_COUNTS`. GitHub release, remote refs and downloaded-byte verification: `PENDING_PUBLICATION_AND_DOWNLOAD_VERDICT`. See [release acceptance](acceptance/release-0.4.0.md) for exact source, commands and limits.

Earlier snapshots below retain their capture-time scope. Specialist abnormal/disconnect/slow-peer/pressure/sustained-load and combined qualification remains excluded; deployment and production acceptance are outside this release.

```

## docs/http3.md

```markdown
## v0.4.0 release status — 2026-10-19

Accepted source supports native H3 HTTP and RFC 9220 WebSocket through an explicit embedded listener opt-in. Standalone JSON can select H3 HTTP services and fixed H3 origins, but cannot activate WebSocket endpoints or managed H1/H2 resources. Phoenix H3 uses an external optional service with server: false and exact websocket_paths. Browser acceptance uses controlled QUIC-first selection; automatic H3 selection with TCP available is unqualified, and the recorded rejected-Origin 403 used H1 TLS. No H3-specific Origin-rejection result is inferred.

Frozen release source: `PENDING_RELEASE_SOURCE_SHA`. Portable builder: `PENDING_BUILD_EXECUTED_INVOCATIONS` executed invocations / `PENDING_BUILD_FAILURES` failures; fresh offline packaged runtime: `PENDING_RUNTIME_VERDICT`; packaged H2/h2c/H3 WebSocket profile counts: `PENDING_PACKAGED_WS_COUNTS`. GitHub release, remote refs and downloaded-byte verification: `PENDING_PUBLICATION_AND_DOWNLOAD_VERDICT`. See [release acceptance](acceptance/release-0.4.0.md) for exact source, commands and limits.

Earlier snapshots below retain their capture-time scope. Specialist abnormal/disconnect/slow-peer/pressure/sustained-load and combined qualification remains excluded; deployment and production acceptance are outside this release.

```

## docs/http-proxy.md

```markdown
## v0.4.0 release status — 2026-10-19

Accepted embedded source implements managed H1 reuse and managed H2/h2c fixed/group upstreams, probes and Generation/resource ownership through public HTTPFetch 0.21.10 APIs. H2/h2c uses explicitly supplied managed transport handles. Standalone JSON origins remain http1/default or http3; JSON exposes no managed handles/groups/probes or WebSocket activation. Native downstream H2/H3 WebSocket support does not add upstream H2/H3 WebSocket proxy transports.

Frozen release source: `PENDING_RELEASE_SOURCE_SHA`. Portable builder: `PENDING_BUILD_EXECUTED_INVOCATIONS` executed invocations / `PENDING_BUILD_FAILURES` failures; fresh offline packaged runtime: `PENDING_RUNTIME_VERDICT`; packaged H2/h2c/H3 WebSocket profile counts: `PENDING_PACKAGED_WS_COUNTS`. GitHub release, remote refs and downloaded-byte verification: `PENDING_PUBLICATION_AND_DOWNLOAD_VERDICT`. See [release acceptance](acceptance/release-0.4.0.md) for exact source, commands and limits.

Earlier snapshots below retain their capture-time scope. Specialist abnormal/disconnect/slow-peer/pressure/sustained-load and combined qualification remains excluded; deployment and production acceptance are outside this release.

```

## docs/gateway.md

```markdown
## v0.4.0 release status — 2026-10-19

Accepted embedded gateway source includes managed H1 reuse, managed H2/h2c fixed/group upstreams, probes and bounded Generation/resource accounting. H2/h2c uses explicit managed handles. Standalone JSON supports explicit H1 HTTP service selection and fixed H1/H3 origins, without managed handles/groups/probes or WebSocket endpoints. Existing authenticated forwarding, destination validation and connection-time policy boundaries remain in force.

Frozen release source: `PENDING_RELEASE_SOURCE_SHA`. Portable builder: `PENDING_BUILD_EXECUTED_INVOCATIONS` executed invocations / `PENDING_BUILD_FAILURES` failures; fresh offline packaged runtime: `PENDING_RUNTIME_VERDICT`; packaged H2/h2c/H3 WebSocket profile counts: `PENDING_PACKAGED_WS_COUNTS`. GitHub release, remote refs and downloaded-byte verification: `PENDING_PUBLICATION_AND_DOWNLOAD_VERDICT`. See [release acceptance](acceptance/release-0.4.0.md) for exact source, commands and limits.

Earlier snapshots below retain their capture-time scope. Specialist abnormal/disconnect/slow-peer/pressure/sustained-load and combined qualification remains excluded; deployment and production acceptance are outside this release.

```

## docs/acceptance/m3-completion.md

```markdown
## v0.4.0 release status — 2026-10-19

M3 remains accepted complete within implemented functionality and ordinary verification scope; its local merge and source-bound ordinary evidence below retain their exact identities and counts. Later release authorization does not extend that acceptance to absent capabilities or specialist qualification. Fresh portable tests/runtime and publication/download results are separate, source-bound release gates.

Frozen release source: `PENDING_RELEASE_SOURCE_SHA`. Portable builder: `PENDING_BUILD_EXECUTED_INVOCATIONS` executed invocations / `PENDING_BUILD_FAILURES` failures; fresh offline packaged runtime: `PENDING_RUNTIME_VERDICT`; packaged H2/h2c/H3 WebSocket profile counts: `PENDING_PACKAGED_WS_COUNTS`. GitHub release, remote refs and downloaded-byte verification: `PENDING_PUBLICATION_AND_DOWNLOAD_VERDICT`. See [release acceptance](release-0.4.0.md) for exact source, commands and limits.

Earlier snapshots below retain their capture-time scope. Specialist abnormal/disconnect/slow-peer/pressure/sustained-load and combined qualification remains excluded; deployment and production acceptance are outside this release.

```

## docs/acceptance/m5-websocket-over-h2-h3.md

```markdown
## v0.4.0 release status — 2026-10-19

M5 G0–G5 source acceptance remains complete within ordinary scope: native H2/h2c/H3 WebSocket, H2-first embedded HTTPS with H1 fallback and the recorded Phoenix profiles. Prior-knowledge h2c and listener extended_connect opt-in are explicit; standalone JSON cannot activate WebSocket endpoints. Browser clients choose transport: H3 evidence is controlled QUIC-first, automatic selection with TCP available is unqualified, and the rejected-Origin 403 used H1 TLS. Fresh packaged-byte qualification and publication are separate release gates.

Frozen release source: `PENDING_RELEASE_SOURCE_SHA`. Portable builder: `PENDING_BUILD_EXECUTED_INVOCATIONS` executed invocations / `PENDING_BUILD_FAILURES` failures; fresh offline packaged runtime: `PENDING_RUNTIME_VERDICT`; packaged H2/h2c/H3 WebSocket profile counts: `PENDING_PACKAGED_WS_COUNTS`. GitHub release, remote refs and downloaded-byte verification: `PENDING_PUBLICATION_AND_DOWNLOAD_VERDICT`. See [release acceptance](release-0.4.0.md) for exact source, commands and limits.

Earlier snapshots below retain their capture-time scope. Specialist abnormal/disconnect/slow-peer/pressure/sustained-load and combined qualification remains excluded; deployment and production acceptance are outside this release.

```

