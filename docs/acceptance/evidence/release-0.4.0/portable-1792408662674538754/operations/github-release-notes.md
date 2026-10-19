Gaoxy v0.4.0 adds native server WebSocket over HTTP/2, explicit prior-knowledge
h2c and HTTP/3 through RFC 8441/9220 extended CONNECT.

- Embedded HTTP/Phoenix HTTPS defaults to H2-first negotiation with H1 fallback.
  Plain TCP defaults to H1; h2c is explicit. Extended CONNECT requires a separate
  listener opt-in, and Phoenix requires exact WebSocket paths.
- Embedded managed H1 connection reuse and managed H2/h2c fixed/group upstreams,
  probes, Generation ownership and resource accounting use public HTTPFetch
  0.21.10 APIs.
- Ordinary H2/H3 exchanges retain their native limits without WebSocket-only
  configuration, preserving strict managed-group accounting and avoiding an
  ordinary H2 group request incorrectly returning 503.

Standalone JSON defaults HTTP services to H1 and supports explicit H2/h2c and a
separate H3 HTTP service, with fixed H1/H3 origins. JSON does not activate
managed upstream handles/groups/probes or WebSocket endpoints. Packaged WebSocket
verification uses the public embedded API.

The Linux x86_64 Debian bookworm/glibc release was built from
`ebd2b12a997750109ffd3fc7db4f3eda223ab79b` with Elixir 1.18.5 and OTP 28.5.0.5.
Format checks and strict production compilation passed. Ordinary qualification
executed 200 tests with 0 failures and 90 deselections. Packaged H2/h2c/H3
WebSocket profiles each passed 15/15 in both the builder and a fresh container
with external networking disabled. Core TCP/TLS/UDP, gateway H1/H2 and H3 smoke
checks passed in both environments. All 21 ELF objects passed dependency checks;
normal exit, cleanup and port reuse passed.

M5 source acceptance also includes Phoenix Channels and LiveView mount, updates
and upload: H2/H3/H1 browser profiles each passed 12/12. Clients choose the actual
WebSocket transport. H3 browser evidence used controlled QUIC-first selection;
automatic H3 selection with TCP available remains unqualified. The multiplexed
browser profiles' rejected-Origin 403 used H1 TLS.

Outbound H2/H3 WebSocket proxying, compression, generic H2/H3 CONNECT,
WebTransport, DATAGRAM and the remaining recorded H3 limitations are outside
this release. Dedicated abnormal/disconnect, slow-peer, pressure and sustained
load qualification remains assigned to its specialist environment.

Assets: `gaoxy-0.4.0-linux-x86_64.tar.gz`, `build-info.json` and `SHA256SUMS`.
New hosted CI is NOT RUN; release pushes retain the ordinary-only scope with
skip markers. Historical BLOCKED_ENV jobs remain separate. Deployment,
production operation, Hex/OCI publication and release-artifact E2E activation
remain NOT RUN.

See [release acceptance](https://github.com/gsmlg-opt/gaoxy/blob/main/docs/acceptance/release-0.4.0.md)
and [M5 acceptance](https://github.com/gsmlg-opt/gaoxy/blob/main/docs/acceptance/m5-websocket-over-h2-h3.md)
for scope, source identities and retained evidence.
