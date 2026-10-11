# ADR007: M3 gateway beta release and M4 preparation

Date: 2026-10-11. Status: ACCEPTED by the user's reviewed scope decision.

## Decision

The user reviewed `gsmlg-dev/http_fetch#97`, judged its requested control proof
excessive, and instructed Gaoxy not to pursue or re-raise it. Exclude this
requirement from acceptance, release and M4 progression. Do not recreate it
through equivalent proof/accounting gates. Preserve historical request text,
assertions, failures, immutable snapshots and repair counters. This decision
does not establish a missing numerical proof.

Publish v0.2.0 as the verified gateway beta subset: native HTTP/1.1 and opt-in
HTTP/2, Plug/Phoenix and WebSocket integration, reverse proxy, authenticated
forward HTTP/H1 CONNECT, TCP/TLS relays, bounded UDP unicast associations,
immutable route generations, standalone data configuration and supervised
dedicated-H1 upstream groups. Keep existing transport foundation capabilities.

Production `HTTPFetchClient` selects `http_version: :http1` and
`http1_reuse: false`. Upstream pools and upstream H2 are not implemented and are
outside this release. Dependency managed probes and preparation/lease fixtures
do not imply an enabled production adapter. HTTP/3 remains M4. The roadmap
remains the product direction; this release does not claim all original M3
features are complete.

## Verification and publication

The seven-package HTTP cohort is 0.21.3. Independent review,
compatibility486/0, managed39/39, H1 baseline20/0, B21, supplemental TLS5/5 and
public H2 supplement8/8 retain their exact receipts. Earlier browser15/15,
selected RFC40/40, reverse example6/6 and the real 600-second fixed-H1 soak retain
their historical source/dependency identities.

Perform fresh canonical format/strict compilation, relevant nonempty
compatibility tests and current standalone artifact smoke: readiness, actual
core/native H1/H2 gateway traffic, finite exit and endpoint cleanup. Add smoke
before workflow packaging/publication. Record the artifact platform/toolchain,
archive hashes, tag/source/assets and actual workflow result in a separate
release receipt. Local Nix smoke does not establish generic Linux portability.

The user authorizes main integration, push, tag and GitHub standalone release.
Deployment, production data, operational certificates, public management,
Vault freezes and disabled release-artifact E2E remain restricted. Local fixture
credentials and independent implementation tests remain authorized.

## M4 handoff

Prepare the [M4 design](../designs/m4-http3.md) and
[implementation plan](../plans/m4-http3.md) from installed public QUIC/H3 APIs.
Independent architecture review and scoped implementation gates follow
continuing authorization. M4 runtime acceptance remains NOT RUN until its own
tests execute. No transport recovery counter resets under this decision.
