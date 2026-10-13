**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m3-h1-resource-foundation`

**Severity:** nice-to-have for optional explicitly negotiated managed-H1 ALPN. This is not a Gaoxy foundation/stage/release blocker.

**Package provenance:** `http_runtime` and `http_fetch` 0.21.4 package `mix.exs` source URLs identify `https://github.com/gsmlg-dev/http_fetch`. Gaoxy locks the coordinated HTTP/QUIC/TLS cohort at 0.21.4. Qualification uses Elixir 1.18.5, OTP 28 / ERTS 16.4.0.6 and OpenSSL 3.6.5 on Linux. Public facade SHA256: `2f89d9535c116dfc129f7e64c36d54256271a24405d1f860d58911e2bc397e5a`.

## Scope correction after independent review — 2026-10-13

The initial blocker classification was incorrect. Gaoxy's already established TLS qualification plan explicitly requires managed H1 to send no ALPN and the peer-selected value to be Python `None` / JSON `null`. Its fixed compact SSL grammar also has no ALPN option. The new consumer harness mistakenly expected negotiated `http/1.1`, and an attempted unsupported policy addition followed that harness assumption. Independent review traced the original contract and caught this scope expansion.

Gaoxy is restoring the supported original policy and correcting the exact peer assertion to **only null**, while preserving all H1 framing/bytes/reuse/no-replay, CA/hostname/SNI and cleanup assertions. Historical 8/4, 8/5 and subsequent 8/4 failure evidence is preserved; no old run is relabelled PASS. This optional feature may remain useful for a future explicitly negotiated profile, but this issue does not block the existing product scope. No dependency workaround is being introduced.

## Optional feature and observed behavior

An optional explicitly negotiated H1 HTTPS profile could advertise `http/1.1` while retaining explicit CA DER, peer/hostname verification, SNI, numeric dial address and H1/C2/R32/P0. The current established Gaoxy profile requires no advertisement. A scope without explicit ALPN connects successfully but the real peer observes selected ALPN `null`. Adding the fixed OTP setting `alpn_advertised_protocols: ["http/1.1"]` is rejected by the public `HTTP.ManagedTransport.open/1` API as `{:error, :invalid_transport_scope_tls_policy}`.

The public facade says `ssl` freezes supported OTP TLS settings but does not enumerate the supported keys or promise arbitrary OTP parity. This requests a bounded feature and its public contract, rather than claiming an existing explicit ALPN guarantee is broken. HTTP/1 without ALPN may be legal generally; this request concerns optional future support, not the current Gaoxy acceptance requirement.

## Minimal public reproduction — executed

Start `:http_fetch` and obtain a DER CA certificate from a disposable localhost fixture (Gaoxy's `scripts/generate-fixtures.sh`). No listener, Fetch request, opaque-field inspection or private process access is needed:

```elixir
{:ok, _} = Application.ensure_all_started(:http_fetch)
ssl = [
  verify: :verify_peer,
  depth: 4,
  versions: [:"tlsv1.3", :"tlsv1.2"],
  cacerts: [ca_der],
  server_name_indication: ~c"localhost"
]
opts = [
  origin: "https://localhost:443",
  connect_address: {127, 0, 0, 1},
  http_version: :http1,
  tls_backend: :ssl,
  http2_profile: :native_v1,
  max_requests: 32,
  max_connections: 2,
  max_pending: 0,
  idle_timeout: 30_000
]
{:ok, scope} = HTTP.ManagedTransport.open(opts ++ [ssl: ssl])
{:ok, receipt} = HTTP.ManagedTransport.retire(scope, mode: :abort)
:ok = HTTP.ManagedTransport.await_retired(receipt, 5_000)
HTTP.ManagedTransport.open(opts ++ [
  ssl: ssl ++ [alpn_advertised_protocols: ["http/1.1"]]
])
# => {:error, :invalid_transport_scope_tls_policy}
```

Diagnostic executed both rows, exit 0; baseline public retirement confirmed and temporary certificates removed. Consumer evidence: `integration/http_fetch_contract/h1_resource_foundation_alpn_probe.exs`, receipt `docs/acceptance/evidence/m3/h1-resource-foundation/1791870010586271722/profile-step7-public-alpn-diagnostic-1791889481798207527.json`, log SHA256 `55d7d5b5f0eb2eba07d535b8c821382c688b5676c9846a3b0caf46cda355b858`.

The initial full consumer profile executed 8/4 (four TCP pass, four TLS fail exact ALPN); the explicit ALPN repair executed 8/5 (all TLS reject open, plus one separately diagnosed TCP helper-finish harness race). Those failure receipts remain preserved. No full foundation acceptance is claimed. Latest v0.21.5 release notes describe the residual-credit H3 fix; this reproduction is for the installed 0.21.4 cohort.

## Expected bounded behavior

Expose a supported immutable H1 TLS ALPN contract, accepting the fixed single binary protocol `http/1.1` or applying it through the public H1 protocol selection. Freeze/bound its representation, preserve exact origin/SNI/trust/socket policy and reject conflicting protocol overrides. Document the supported SSL/ALPN options. Add real verified-TLS managed H1 coverage proving peer selection `http/1.1`, sequential reuse, original request completion and public retirement without replay, then publish containing coordinated packages.

This is an ordinary wire/policy feature request. It does not request native-memory certification, deferred-resource numerical bounds or replacement proof for the dismissed #97.
