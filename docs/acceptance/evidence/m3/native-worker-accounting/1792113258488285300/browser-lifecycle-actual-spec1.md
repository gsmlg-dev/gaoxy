# Browser lifecycle actual SPEC1

FAIL — one actionable preservation finding. Independent CODE review should wait for the bounded repair and fresh actual-source SPEC.

Task `/root/native_worker_constructor_spec/browser_lifecycle_actual_spec1`; direct source-only assignment. Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; archived baseline `58307a7084298db309a93697b9102b2cc4c87eda` (no Git run). Actual host2 SHA256 `c56b0d98d655e2d146056174cc3c462e6146dc65acd6af3a27605357b8e3d910`; runner3 SHA256 `40321cba29a96ef4f670ef94912fc44d6d7c4869f472adcf529a3e8b2b426535`.

**SPEC1-F1, required:** host2:801-805 authorizes after checking only the connection alive/notjoined; writer :normal DOWN at975-977 is accepted without authorization. A real H2 writer can terminate after the request-clean baseline check, be recorded joined before authorization, and still qualify through `join_native(..., true)` while the connection is briefly alive. This violates the agreed requirement that the H2 writer remain alive until authorized browser closure.

Minimal correction: assert H2 writer `Process.alive?` and `not writer_joined` before authorization, and require `browser_close_authorized` on its exact normal-DOWN loop clause. Keep Session and H2 request-worker normal joins valid before authorization. Use new immutable host3/runner4; retain this failed review/source pair.

All other inspected conditions match the proposal: full exact custody payload plus explicit event discriminator; request-clean-before-authorization and acknowledgment-before-Chrome-exit; live/notjoined connection check; exact authorized connection monitor/PID/reason with H1 native versus separate H2 monitor; early/wrong connection reason failure; strict normal Session/H2 worker/writer reasons; dead/monitor assertions; zero Gate/resources/source identity; complete raw-peer framing/sends; actual CDP/DOM/TLS/accounting; normal Chrome/profile/actor cleanup with forced or nonzero cleanup still FAIL. Supplied diffs exactly match the complete old-to-new source differences, proving original peer/cleanup/accounting code is preserved outside the reviewed changes.

Verification: SHA256, full source/diff comparison, Python AST parse only. No runtime, Mix, browser, builds, tests, network or Git. No repository/evidence writes. Only assigned two `/tmp` reports written; all reviewer commands finished and no process started in background. BrowserGREEN1 remains FAIL (H2 executed1, H1 NOT RUN).

Counters unchanged: group36/root42/stage failedGREEN6/Astra2of2. This is a source-review finding, adds0 failedGREEN and0 reviewer repairs. No product decision/escalation. Fresh source-bound review is required after the minimal repair.
