# Gaoxy v0.5.1

**Hex publication: BLOCKED_ENV / unpublished.** GitHub Actions
[run 39377152673](https://github.com/gsmlg-opt/gaoxy/actions/runs/39377152673)
could not start because of an account billing restriction; zero steps executed.
This GitHub release contains five locally verified Hex source tarballs,
`SHA256SUMS` and `build-info.json`. No new standalone binary was built.

This release prepares Gaoxy for Hex distribution and Phoenix use. The packages
are `gaoxy`, `gaoxy_http`, `gaoxy_http3`, `gaoxy_proxy` and the patched
`gaoxy_websock_adapter` distribution (OTP application `websock_adapter`). All
five distribution versions follow the Gaoxy release version. The fork retains
upstream WebSockAdapter 0.6.0 source attribution and MIT licensing. Gaoxy's own
packages use the MIT license.

Phoenix dependencies after publication:

```elixir
{:gaoxy_http, "~> 0.5.1"},
{:websock_adapter, "~> 0.5.1", hex: :gaoxy_websock_adapter, override: true}
```

Configure the endpoint with `adapter: Gaoxy.PhoenixAdapter` and the existing
HTTP/HTTPS and explicit WebSocket-path settings. The override keeps Gaoxy's
WebSocket dispatch and native H2/H3 handshake validation when Phoenix requests
WebSockAdapter. Replacing it with the canonical package would lose those
changes. See [the HTTP guide](https://github.com/gsmlg-opt/gaoxy/blob/v0.5.1/docs/native-http.md).

The staging script generates standalone manifests without local Git/path or
umbrella dependency declarations, while preserving runtime source files.
Published core dependencies select byte-matched Hell 0.1.2 and Abyss 0.7.0.
The release workflow builds every Hex package before publication and requires
downloaded package bytes to match its preflight tarballs before pushing a tag.
That workflow did not execute for this release. Local signed-registry consumers
passed all seven existing core, HTTP and Phoenix tests; all seven packaging
regressions passed, including a real package-only publication dry run. Final
tarballs preserve the qualified runtime, manifests and dependency metadata;
four package READMEs changed after the consumer run. HexDocs generation is not
added. See [release acceptance](https://github.com/gsmlg-opt/gaoxy/blob/main/docs/acceptance/release-0.5.1.md)
for evidence and separate publication statuses.

There are no new protocol or runtime capabilities. Accepted embedded/standalone
activation differences and protocol limits remain unchanged. The existing
v0.5.0 Debian/bookworm standalone binary and qualification retain their source
identity. This source-package release makes no new standalone portability claim.
Specialist abnormal/disconnect, slow-peer, pressure, load and soak qualification,
deployment, production operations, Vault, public management and the disabled
release-artifact E2E remain outside this release.
