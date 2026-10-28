# Issue 18: Plug response headers on multiplexed HTTP

The user requests all eligible internal-request repairs directly on `main` and
the next release. Initial main/origin main are
`9f272f9284e1526838d518b294e08f62511191c6`, with a clean worktree and stable
0.13.0 already published. GitHub MCP and paginated REST discovery identify only
[#18](https://github.com/gsmlg-dev/gaoxy/issues/18), without an unable-to-resolve
label or an existing open `fix/issue-18` PR. The direct-main instruction takes
precedence over the skill's worktree/PR defaults.

## Design

The Plug adapter currently forwards application response headers unchanged.
The strict shared H2/H3 response encoder rejects connection-specific fields,
causing middleware's `Connection: keep-alive` to turn otherwise valid SSE into
HTTP 500. Normalize these fields at the Plug compatibility boundary, before
calling native response operations. Keep native response validation strict.

For H2/H3, discard connection-specific response fields and every field nominated
by any `Connection` header, using case-insensitive names/tokens. Preserve ordinary
header order and duplicates, application payloads and native framing checks.
Apply the same policy to buffered, file, chunked and informational responses.
HTTP/1 behavior, request headers and WebSocket handshake handling stay unchanged.
A private pure function in the existing adapter is sufficient; no process,
dependency patch or protocol-policy change is needed.

## Execution and acceptance

1. Add public-adapter regressions before production changes and retain an actual
   failing execution. Cover every response operation, repeated connection-token
   fields, ordinary duplicate headers, H1 behavior, H3 shared-adapter parity and
   strict native/invalid/framing controls.
2. Add bounded real H1/H2 regressions for MCP-shaped POST SSE and a held GET
   notification stream with later data on the same stream, normal completion,
   cleanup and healthy follow-up. Use independent protocol clients and finite
   synchronization. Classify new app test files in the canonical manifest;
   pure/controlled cases and protocol cases retain their proper workflow owners.
3. Make the smallest adapter repair, obtain independent specification/code
   review, resolve findings and rerun relevant verification. Require positive
   exact counts, canonical ordinary suites, format/strict compilation, inventory
   and package staging/consumer checks. Preserve original failures separately.
4. Release patch version **0.13.1** with synchronized own manifests and current
   installation examples. Preserve dependency pins and vendor provenance.
   Commit/push main, verify all exact-source hosted workflows, then dispatch
   guarded `release.yml` with the full expected source SHA.
5. Independently verify the immutable tag, stable release, eight assets/seven
   payload checksums, six public Hex packages and package source/dependency
   identity. Run the issue regression against a fresh Hex-only consumer and
   downloaded standalone smokes; then evidence-comment, label and close #18.
   Recheck both GitHub MCP and paginated REST discovery and record final delivery.

Root owns versions, docs, release orchestration and Git. The implementation
worker owns adapter/tests/inventory and serial shared builds. Audit-only public
verification preparation is independent and must not run competing builds.
All writers preserve each other's edits; no branches or worktrees are created.

Historical specialist abnormal/disconnect, slow-peer, pressure and sustained-load
evidence retains its disposition. This release does not include deployment,
production data/certificates, Vault, public-management changes, browser gates or
the separately gated released-server E2E suite.

Execution completed in [v0.13.1](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.13.1),
publication source `84c7ff76461ada8aebaa34c567c61206bc963d83`. Ordinary 583,
public issue 15 and downloaded-runtime 13 checks pass, with independent review
and issue #18 closeout complete. Both final discovery methods return zero open
internal requests; see the [final acceptance](../acceptance/release-0.13.1.md).
