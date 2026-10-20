# Standalone configuration parity

Scope: the review of main `c063607e` requests configuration access to existing
runtime features. No new protocol, public management endpoint, release or
specialist qualification is part of this change.

Keep version 1 JSON and strict string allowlists. Add `websocket` and inline
`upstream_group` route targets. Reverse proxies accept `http2`/`h2c` and
`managed: true` for reusable H1. Group members use managed H1/H2, with the
existing homogeneous-protocol and health policy. Inline definitions keep route
files independently reloadable without a second mutable configuration registry.
TCP/TLS and UDP relays use registered handlers with fixed numeric destinations;
UDP retains mandatory ingress/destination policies.

Decode and validate immutable upstream policies without processes. Declarative
upstream endpoint values are resolved before listener activation. A supervised
coordinator prepares existing transport and
group resources against the real Gaoxy instance. It holds preparation pins until
the generation store acquires baseline pins, then releases preparations. Reload
prepares a whole candidate, activates with the existing generation CAS, and
releases every preparation on success or failure. Owners are supervised alongside
the runtime and stop with it. Unconfirmed preparation releases retain their pins
and retry with a shared finite deadline; further activation is rejected until
reconciliation completes. Activation success identifies the installed generation,
without claiming deferred retirement has finished. On supervisor shutdown or
failed initialization the coordinator drains the instance while upstream owners
remain alive, using the original configured shutdown budget. Deferred listener
startup preserves that budget and ordinary compiled route matching.
Transport/group owners start lazily; the coordinator
also permits a static listener to adopt managed routes through reload. The runtime,
owner supervisor and coordinator restart together after an owner failure, because
prepared handles belong to the original instance. Literal origins infer a numeric
connection address; named origins require an explicit `connect_address`, keeping
the pinned dial address separate from the TLS identity.

Alternative: global named transport/group registries would require another
reload transaction and cross-file reference rules. Per-request resources would
lose reuse and health ownership. Inline immutable configuration fits the existing
generation model with the smallest configuration surface.

Ordinary acceptance covers strict decoding, real managed H1/H2 and group/probe
requests, stable-listener reload/rollback, shutdown, and fixed TCP/UDP relay
traffic. Existing H3 and generation compatibility tests remain scoped evidence.
