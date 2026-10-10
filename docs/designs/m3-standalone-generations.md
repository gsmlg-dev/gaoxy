# M3 standalone route generations

The standalone application must start the same native HTTP runtime as embedded
consumers. Version 1 JSON adds the allowlisted `http` handler with an inline
`routes` object in the existing RouteConfig format. `protocols` and `h2c` use
fixed string enumerations; transport, address, TLS and finite service limits
remain explicit. No input resolves arbitrary modules or creates atoms.

Configuration loading is bounded to 1 MiB before JSON decoding. HTTP route
compilation and HTTP service validation remain pure and happen before any bind.
A caller must supply enough retained-byte capacity for generation snapshots;
H2 additionally retains its separately qualified conservative codec reservation.
Core defaults remain unchanged.

The application supervisor starts a private Registry, a named Generation store
per HTTP service from its already compiled Router, and then the ordinary Gaoxy
runtime. It uses `rest_for_one` so a configuration-owner crash restarts dependent
listeners. The runtime stops before the stores during normal supervisor shutdown.
Configuration generation names use binary service IDs through Registry.

`Gaoxy.Server.reload_routes(service_id, path, timeout)` is a local Elixir API.
It loads a complete bounded route candidate and performs the existing Generation
prepare/CAS activation within one deadline. The live listener and admitted
request snapshot survive route changes. Invalid files leave the current route
table unchanged. This API does not change listener/address/TLS settings and
does not create an HTTP management endpoint.

The startup configuration currently resolves the existing `static` and fixed
`reverse_proxy` route targets. Upstream group resources are prepared explicitly
by the supervising configuration owner before accepting their endpoint handles;
their separate lifecycle integration belongs to Task 5.

Execution steps and evidence:

1. Add a real mixed HTTP/UDP startup, exact-response route reload and rollback
   regression; confirm the missing allowlisted HTTP handler/startup API is red.
2. Add the pure HTTP configuration branch and bounded file loading, then the
   supervising startup and local route reload API. Generation's compiled-router
   and OTP name seams are implemented with Task 5, without recompiling targets.
3. Run scoped standalone/config/generation tests and verify finite shutdown and
   listener-port reuse. Require independent specification and code review.
4. Qualify H2 old/new streams and proxy guardians across repeated route changes,
   plus the required consumer/browser/soak gates before overall M3 acceptance.

No release, deployment, public management endpoint or production-data mutation
is authorized here. Startup and route reload acceptance are local evidence.
