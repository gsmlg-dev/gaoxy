# Independent Generation/config specification and quality review

Reviewer: H2 implementation worker (`/root/upstream_cleanup`), read-only review of root-owned code. Checkout: `22b76e8051ddaf09e36797cb781b9b119870a9d4` plus current task diff. No root-owned source edits or independent test execution. Reviewed Generation/Store, generation tests, RouteConfig/StaticEndpoint, route configuration tests, server manifest, approved design and Router integration.

Verdict: FINDINGS; targeted fixes and fresh regressions required.

## G1 — activation sends an unbounded candidate before rejecting it (high)

`Generation.activate/4` accepts any `%Router{}` and sends the complete candidate in `GenServer.call` before Store `compiled_bound/2`. A caller can construct a Router containing a multi-megabyte target/options value, suspend the Store, and observe that full candidate in its mailbox. Concurrent rejected activations can therefore create the same pre-admission mailbox growth that metadata-first preparation fixes. Obtain the immutable size limits and reject oversized/too-many-route candidates in the caller before sending activation payload; retain authoritative Store checks and CAS/deadline checks. Add a suspended-store mailbox regression with a large invalid candidate.

## G2 — invalid static response framing survives preparation and activation (medium)

RouteConfig.headers rejects CR/LF/NUL but permits transfer-encoding, duplicate or invalid content-length, and DEL/control values that HTTP1.Response rejects. StaticEndpoint.init only checks status/body/list types. A route containing `headers: [["transfer-encoding", "chunked"]]` is accepted by decode and preparation, then every request fails `:invalid_response_framing`. Similarly `[["content-length", "invalid"]]` survives preparation. Validate registered static response headers and framing before candidate activation, with deterministic rollback regressions. H2-only unsupported hop fields should not become an accepted static configuration either when the same registered endpoint is advertised protocol-neutral.

## Positive checks

- Metadata-only `:limits` / `{:begin_prepare, deadline}` cross to Store; only the single accepted worker receives routes.
- Single linked/monitored preparation retains capacity until worker DOWN; caller departure triggers kill and confirmed release.
- Prepared results are deadline-checked; queued activation checks deadline before CAS/mutation; reload carries one total deadline through snapshot/prepare/activate.
- Generation.call reserves snapshot bytes before snapshot handoff and retains route_bytes through Exchange accounting; old requests retain immutable routers.
- Current H1 live-listener regression verifies unchanged real port and simultaneous old/new route snapshots.
- File loading is bounded to maximum+1, registered target names create no atoms/modules, dependencies remain umbrella-scoped.

## Remaining acceptance

H2 reload and guardian integration checks belong to the H2 integration phase and have not run yet. Existing reported generation/config green is 15 tests/0 failures (parent evidence); this review does not replace fresh verification after findings are repaired.

## G1/G2 read-only follow-up after parent edits

G1 source fix resolves the original finding: activate obtains immutable limits and calls compiled_bound in the caller before sending candidate, with authoritative Store checks/CAS/deadline retained. Fresh regressions are pending parent execution.

G2 source fix now rejects hop fields, duplicate/invalid/mismatched content-length and controls, and adds rollback regressions. Two protocol compatibility refinements remain: `StaticEndpoint.valid_headers?` accepts leading/trailing OWS values such as `{"x", " value "}` that H2.Headers.validate rejects; it can therefore still activate an unusable H2 route. It also requires304 content-length to equal the unused response body length, rejecting valid representation metadata e.g304/bodyempty/content-length123 that the shared H1/H2 Response contract preserves. Align default common header bounds/OWS validation and retain valid304 metadata before final review PASS.
