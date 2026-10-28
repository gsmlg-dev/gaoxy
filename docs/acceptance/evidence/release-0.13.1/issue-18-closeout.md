Released in [Gaoxy v0.13.1](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.13.1), source `84c7ff76461ada8aebaa34c567c61206bc963d83`.

The Plug adapter now removes connection-specific response headers and every field nominated by `Connection` before H2/H3 buffered, file, streaming and informational responses. HTTP/1 behavior, ordinary headers/payloads, raw header budgets and strict native framing/header validation remain effective.

Validation is complete:

- All five source workflows passed: 10 required jobs. [Guarded release 40728588011](https://github.com/gsmlg-dev/gaoxy/actions/runs/40728588011) repeated 583 ordinary cases, package staging/consumers, Phoenix clients/regressions and standalone smokes, then passed fresh public Hex consumers.
- A separate clean Hex-only 0.13.1 consumer strictly compiled and passed **15 tests, 0 failures/excluded/skipped**: 11 controlled adapter cases and 4 real H1/H2 cases, including MCP-shaped POST SSE and a synchronized GET notification stream with later data on the same stream. Its 72 packaged source files match the release commit; tag read-backs before and after agree.
- Independent read-back verified all **6 Hex packages**, **8 GitHub assets**, **7 payload checksums**, exact dependency pins and **136 packaged source files**, including equality with the successful Actions artifact.
- The downloaded standalone archive passed **13/13 checks** (core 3, gateway 7, H3 3), with clean exits, owned process cleanup and H3 endpoint reuse.

The [adapter tests](https://github.com/gsmlg-dev/gaoxy/blob/84c7ff76461ada8aebaa34c567c61206bc963d83/apps/gaoxy_http/test/plug_response_headers_test.exs) and [real transport regressions](https://github.com/gsmlg-dev/gaoxy/blob/84c7ff76461ada8aebaa34c567c61206bc963d83/apps/gaoxy_http/test/plug_response_headers_network_test.exs) preserve the legacy response header in the application fixture. Backplane can now qualify the published 0.13.1 packages using its own transport tests.
