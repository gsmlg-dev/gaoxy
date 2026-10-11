# H2 functional supplement repair1 independent review

Verdicts: **PASS_STATIC_SPEC**, then **PASS_STATIC_CODE**. H2-IMPL-01 is resolved statically; no open findings. Runtime and failure-path regressions are **NOT RUN**.

Direct bounded review in `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch `codex/m3-gateway`, parent baseline `85c2284a035e0b4ecbf577279eee01142702b5a3`. Current canonical formatted Elixir source SHA256 `89cd7237a5864d86e9ffbd7f5f323a275ec9cad1d36cd4f03fc8881842cccbef`; peer `b1bcff8b19eba8c7bccb315ecd3ee66be860816128e76b2a15b5a36e0968f170` and approved plan `25fdfb876f7e83f65b97414816a6a82c258ec8f789f0d0eb7f4e07f627ad7270` are unchanged. Preserved original formatted source `83a947b179ce40e3f2b1e511fe3dd8f4995cd4fcff1743bb2b540d9141b43c62` and the original FAIL_SPEC/CODE reports remain intact. Parent formatter receipt records exit0 and only the permitted H2 path.

## Resolution of H2-IMPL-01

- **acquisition:** Original promise saved immediately at212 before completion extraction and all response assertions; exact original completion retained.
- **pre_response_failure:** Failure cancellation gates on acquired promise at503 rather than exposed stream. Manual abort_and_await uses original handle; follow abort uses exact owned controller and never unsupported completion.
- **response_ownership:** await_response422-445 registers a public response-stream monitor before outer status/version assertion. Unawaited saved promise can be awaited during cleanup; failed await is never retried.
- **stream_cleanup:** Any exposed stream acquires a reader when needed and drain_stream744 acknowledges chunk refs and retains exact monitorDOWN under originalC. Cleanup errors/forced joins remainFAIL; no private task/process discovery.
- **cleanup_terminal_proof:** Manual original terminal completion must beok or reportsBLOCKED_HANDOFF. Follow unresolved Promise with no exposed stream reportsBLOCKED_HANDOFF and requires dedicatedVM end; unsupported completion is never cleanup proof.
- **unchanged_contract:** Fixed8case list/options/control-reader parsing/exact-extra-message checks are byte-identical to preserved formatted original. Diff preserves main expected errors/RST1or8, reader ordering, originalD10/C15, request6/connect2, ready45 and peer controls3/events128/line4096. Peer/plan unchanged.
- **qualification_boundary:** Parent-owned600s collector and TLS95 identity wrapper remain separately required; no private runtime calls, native credit/refund/N8/fullM3/production claim added.

## Suggested focused parent verification

These are optional bounded negative injections, not changes or tests executed by this reviewer. Keep them in separately owned/frozen evidence, preserve the eight primary qualification cases, and retain primary FAIL plus actual child exit.

- **H2-NEG-ACQUIRED-BEFORE-AWAIT:** In a separate disposable negative qualification copy, inject a primary raise immediately after original Promise/completion capture, before first await. Exercise manual and follow in separate evidence runs; preserve the full primary registration/oracle source for qualification. Expected: Primary FAIL remains; failure_abort_and_await or failure_abort operation is recorded regardless of state.stream. OriginalC remains fixed; any late exposed stream is registered/drained/joined; peer/controller cleanup is recorded. No unsupported follow abort_and_await.
- **H2-NEG-FOLLOW-AWAIT-TIMEOUT:** In separately frozen negative evidence, withhold response headers long enough to make the first follow Promise.await hit its original2s cap; keep original request6s and outerD/C unchanged. Expected: promise_await is failed; public controller abort still executes; no second Promise.await occurs; result isBLOCKED_HANDOFF with dedicatedVM termination confirmed by parent collector. Retain actual child exit and partial evidence, never count this as an eight-casePASS.

## Evidence and limits

Static source diff review completed in SPEC-then-CODE order. Python AST parsing passed; all16 approved-plan frozen input hashes match. Fixed cases/options/control parser/extra terminal rejection blocks compare byte-identically with the preserved original. The primary scenario’s only response-path change uses an acquisition-recording helper; exact errors, resets, reader barriers and original deadlines are retained. Final report JSON and current input hashes were checked after writing.

Only these two new reports were written. No VM, Mix, test, peer, network, dependency or Git mutation ran; Elixir compilation was not run. All own commands finished synchronously and no background process exists. Counters received remain H2 Sol1/unsuccessful0/Astra0, H1 Sol3/unsuccessful2/Astra1, TLS Sol4/unsuccessful2/Astra2; this review adds zero repairs.

Parent still owns final-source-bound identity manifest, full loaded/native before/after verification and actual eight-case execution under its fixed600s collector. Follow lost-alias uncertainty correctly requires BLOCKED_HANDOFF and dedicatedVM termination rather than an ownership claim. Static PASS establishes no numerical/native frontier, sibling/proxy matrix, full M3 or production acceptance. No source/design decision remains unresolved.
