# Independent E5 browser fixture source review

Task `native_worker_browser_source_review`: DONE (direct independent source-only assignment). Source verdict **FAIL**; runtime **NOT RUN**.

Repository: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Baseline from frozen identity: `codex/m3-h1-resource-foundation`, HEAD `58307a7084298db309a93697b9102b2cc4c87eda`. No Git commands were run.

## Finding BROWSER-SOURCE-1 (P2)

`native-worker-browser-runner1.py:46,64-73,103`: The raw peer calls a GET complete once `CRLFCRLF` arrives, without checking Content-Length or Transfer-Encoding or consuming a body. It emits the request barrier while `pending` may still contain request-body/partial next-request bytes. Normal stop can exit the outer loop and discard residual `pending`. That is weaker than Task5's explicit complete-request-only fixture policy. This is a concrete source assertion gap, not an observed runtime failure.

For this fixed bodyless HEAD/GET scenario, reject Transfer-Encoding, require Content-Length absent or zero, reject residual bytes at the request barrier, and require an empty partial buffer at normal stop. Preserve the complete-response-only idle-reset rule and the real sendall failure behavior. Parent accepted this finding and will derive runner2 after this frozen review.

## Other checks

The independent raw helper constructs real complete Exchange/default/MFA/Admission/control envelopes and uses ETF measurements plus the qualified future-reference bound, with no production WorkerAccounting sum for expected W. All 95 role names, ordering, dispatch classification and multiplicities match actual WorkerAccounting metadata. The already corrected Map.to_list struct traversal preserves __struct__. The source reproduces actual native dispatch operands and verifies independent N/W at the real captured worker.

At H2 capture, assertions identify exactly the connection, writer and worker leases and their real holders, the running Admission correlation, and public active=3/bytes=C+R+W+B. H1 checks its existing single lease. Original G7/T8 pins, owner-before-effect status, public owner replies, derived Session T8 source/acquirer ledger and actual Service-authenticated Gate cleanup attachment path are checked. The independent complete-GET response-release barrier keeps Session custody live for inspection.

Chrome source asserts actual response.protocol h2 plus TLS securityDetails, separate http/1.1 compatibility, exact URL/status/title/text/visible DOM and screenshot. Certificate generation is existing ephemeral TEST-only generation, with a leaf-SPKI-only exception. Normal actor joins, profile removal, process-group disappearance, Session/native lease cleanup and zero service/transport accounting are explicit. No additional actionable fixture source finding was found.

## Frozen verification and limits

Python AST parsing PASS; fixture/adoption/freeze hashes match supplied values at first and final read. All 239 frozen main-source manifest entries match current files. Exact hashes:

- `native-worker-browser-host1.exs`: `c6c80361783a6589195959d2f19c5dc1e11a9a370b234fac8fc0bdc381db441f`
- `native-worker-browser-runner1.py`: `bdc115c83a33baaf88d3ae8e9e5d8e6b1c55861b67d9fec91b4522a10bbd1440`
- `browser-adoption1.json`: `5129aa912db120c20fcd726c0adccaa104a44d15d7d1f2c94df4843b41a77826`
- `constructor-candidate-freeze1.json`: `1c3a31d4a882f13f66fe5c9efb04953a9bf15ba2b7b515ac73e0b02f40b4e1b9`

No runtime, browser, network, build, format, tests or Git commands ran. No Elixir parse or arithmetic execution was performed by this reviewer. Main constructor SPEC then CODE checkpoint and final full-stage review remain separate. Actual negotiated protocols, numeric capture results and normal exits remain NOT RUN.

Only the two assigned /tmp reports were written. Sol repair rounds added: 0; inherited group31/root36/Astra2/2 unchanged. No escalation or new product decision required. All reviewer commands completed; no runtime actors/suspensions owned.
