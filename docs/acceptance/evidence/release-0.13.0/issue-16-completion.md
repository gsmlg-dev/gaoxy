Released in [Gaoxy v0.13.0](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.13.0), publication source `bd325eb408d4566b807bcef9fdaf1a2b1ad83a2d`. All six coordinated Hex packages are public and independently verified.

Native WebSock H1/H2/H3 connections now have no implicit frame/message payload, fragment-count, callback-batch, inactivity or absolute-lifetime ceiling. Generic service byte/state budgets no longer impose the hidden 256 KiB message ceiling. Explicit application limits remain effective; reusable transport buffers, queues, flow control and separate finite operation deadlines remain bounded.

Phoenix applications need `websocket: [timeout: :infinity]` in their socket declarations for persistence. See the [published configuration guide](https://github.com/gsmlg-dev/gaoxy/blob/bd325eb408d4566b807bcef9fdaf1a2b1ad83a2d/docs/websocket-limits.md).

Verification:

- All five exact-source workflows passed, followed by [release run 40212587939](https://github.com/gsmlg-dev/gaoxy/actions/runs/40212587939): 568 ordinary cases, zero failures/excluded/skipped.
- Fresh public Hex-only native/Phoenix consumers passed 23 issue regressions: native default capacity 5, H2 persistence 4, TLS startup-close 1, Phoenix default capacity 1, configured limits 6 and compatibility 6. Published source matches the release commit; no source dependency overrides.
- Independent read-back verified six Hex packages, eight matching GitHub/Actions assets and seven payload checksums. Downloaded standalone passed 13/13 runtime checks, including H3 and cleanup/port reuse.
- Conforming independent Quinn/quic-go H3 peers preserve the original certificate, exact-data, FIN/EOF, deadline and cleanup assertions. Independent review has no remaining actionable findings.

The original aioquic, hosted consumer and local environment/parser failures remain recorded separately. This release adds no deployment or specialist pressure/soak acceptance.
