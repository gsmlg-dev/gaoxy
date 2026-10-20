# Standalone configuration implementation plan

Goal: expose the reviewed existing proxy and relay capabilities through JSON.
Architecture: pure allowlisted decoding, followed by supervised instance-bound
preparation and generation activation. Tech stack: Elixir/OTP, Gaoxy generations,
existing UpstreamTransports/UpstreamGroups, native TCP/UDP peers.

- [x] Add `standalone_proxy_config_test.exs`; run it against the existing decoder
  and observe rejected WebSocket, H2 and group configurations.
- [x] Add a pure declarative upstream endpoint and extend RouteConfig; reuse
  existing policy, group and endpoint validators. Reject unknown keys, mixed
  protocols, invalid trust and unbounded limits.
- [x] Add supervised resource preparation for startup and reload. Prepare using
  the actual instance, acquire generation baseline before releasing preparation
  pins, and reconcile failed candidate releases. Preserve ordinary validation and
  configured shutdown budgets while deferring listener creation.
- [x] Register stream/UDP relay decoders and exercise real echo traffic with
  explicit UDP ingress/destination rules. Relay decoder ownership is delegated.
- [x] Exercise configured managed H1/H2, group health, stable-listener reload,
  invalid-candidate rollback and shutdown. Run scoped standalone compatibility.
- [x] Document runnable JSON examples and boundaries; independently review source
  and requirements; run fresh scoped checks; make local conventional commits.

Checks use `ELIXIR_ERL_OPTIONS='+S 2:2'`, the existing `unbuffer` executable and
the shared Mix lock. Ordinary baseline: config/route tests, 9/0, exit 0.
No pressure, slow-peer, soak, blocked-upload or release-artifact E2E execution.

Completed ordinary verification and independent review: see
[review acceptance](../acceptance/review-defaults-standalone.md).
