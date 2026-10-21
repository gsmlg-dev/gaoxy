# Gaoxy 0.6.0 release acceptance

Date: 2026-10-21, Asia/Shanghai. The user authorizes the next minor release,
including push and publication. Preparation is directly on `main`, from
`ec1fead80884804de9ab662e311ebb9c1cfdaf60`.

Status: **PREPARING — not yet published**. The
[release plan](../plans/release-0.6.0.md) defines the source and verification
boundary. Local command receipts, source hashes, builds and reviews are stored
under `.audit/release-0.6.0/20261021T052454Z-ec1fead8/`.

The release includes the already qualified HTTP/TLS/QUIC `0.21.14` cohort and
Phoenix `1.8.16` / LiveView `1.2.13` example. Version preparation updates six
own manifests and current installation guides; dependency locks and runtime
implementation remain unchanged. Hex `abyss == 0.9.0` and Hell `0.1.2` are
retained. The five distributions are `gaoxy_websock_adapter`, `gaoxy`,
`gaoxy_http`, `gaoxy_http3` and `gaoxy_proxy`; `gaoxy_server` ships inside the
standalone application.

Local preflight, independent review, exact-source hosted gates, publication,
download verification and clean public-Hex consumers are pending. Their actual
results will be recorded separately. Specialist qualification, deployment,
production operations and disabled release-artifact E2E are **NOT RUN**.
