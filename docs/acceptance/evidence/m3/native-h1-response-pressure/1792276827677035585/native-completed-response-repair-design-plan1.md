# Native completed fixed-length response repair design and implementation plan1

> For agentic workers: use subagent-driven-development; root retains all runtime/evidence/Git custody.

Goal: preserve an otherwise reusable H1 upstream when a native downstream closes after receiving every Content-Length byte, while still waiting for actual upstream terminal validation and cleanup.

Architecture: use the existing owned Exchange native response state. Once transport=nil and response={:fixed_stream,0}, passive downstream EOF cannot retract bytes already committed. Continue the ordinary bounded pump until the real Session end/error/current idle or total deadline. Only actual validated end dispatch calls Session.consumed. Framed H2/H3 fixed0 still owes END_STREAM and is excluded. Scope is only this native fixed-length completion window; incomplete fixed, chunked and bodyless states retain their existing paths in this initial repair. No new public API, process, retry or deadline.

Evidence: standalone-connection-matrix-diagnostic3-failure-observation1.json records actual9/8/1/7 and immediate EOF731us after final POST send. Own source supports the race; passive native-result diagnostic4 and deterministic old-source regression are still pending. No functional repair is permitted until the actual regression fails for the intended completed-fixed/closed reason. A failed setup/timeout/unjoined actor does not count as intended RED.

Alternatives considered: marking consumed on last chunk would skip genuine end/trailer/error validation and is rejected; adding a generic backend completeness callback would expand an API for one use and risks confusing H2/H3 fixed0 with terminal. Select a small native-only branch within current proxy progress.

Files: create apps/gaoxy_proxy/test/http_proxy_completed_response_test.exs from the reviewed standalone test draft; modify only apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex for the initial production repair. Existing passive fixture and pressure/runner work must be preserved. Canonical pressure design/plan/acceptance and two main plans receive final factual synchronization after actual gates.

- [ ] Complete candidate12 diagnostic sourceSPEC12 then CODE9, strict compile9/scoped format9. Run full existing standalone16 once with no selector as standalone-native-result-diagnostic4 under unchanged budgets; retain all counts/primary/cleanup results. It is observation, not a repair.
- [ ] Root installs the test-only draft after diagnostic4 exits; freeze test + prior unchanged source. Review deterministic regression specification and code before runtime. The test uses the actual fixture/socket/HTTP1.Response.chunk; suspend only the correlated owned Session, use same-sender opaque-state fence to retain <=1 actual end tuple, observe real socket EOF, return native Exchange and require positive native pump_wait before restoring genuine held end(s)/resuming. Exact body, normal public completion/Session joins, physical same-connection next request and clean zero accounting remain mandatory. Finite teardown always releases callback/resumes guardian before fixture stop.
- [ ] Root runs exactly that file under collector red; actual1 executed, failure must be immediate original error closed with fixed0 before terminal release. Audit real setup, source and cleanup separately. No production edit before intended failure is established.
- [ ] One writer then owns only proxy/http.ex. In progress/2, after the existing upload branches and before passive poll, insert:

```elixir
      state.exchange.transport == nil and state.exchange.response == {:fixed_stream, 0} ->
        pump(state, min(@poll_ms, remaining))
```

Preserve existing remaining/idle/total checks, ACK/end validation/accounting/error cleanup. Do not classify framed or pending native bodies as complete. No helper abstraction or Response backend change is needed: proxy already reads the public owned Exchange response state.

- [ ] Fresh independent repair sourceSPEC then CODE; root strict compile/scoped format, then exact regression GREEN1/0 with all expected normal joins and physical upstream reuse. Check old-source RED versus repaired GREEN use the same test bytes and unchanged assertions. If intended RED is not established, return to diagnosis rather than claim success.
- [ ] Root fresh native pressure4; separate existing five-file52 (pressure4+matrix16+wire12+TLS4+runtime16), seed166590/max-cases1; full standalone default16 with no selector; ordinary browser2rows/four actual root image opens. New regression1 is separately counted, never folded into planned52. Run additional scoped compatibility checks only when this own native change affects their contract or actual failures justify them. All existing assertions/deadlines remain.
- [ ] Independently review actual implementation/evidence SPEC then CODE, resolve findings, synchronize canonical3/two plans with exact current cohort and immutable failed history/counters, final fact/doc review, fresh affected verification, local conventional commit and postcommit custody including E12. No push/release/deployment. Only after actual slice closure advance prepared sole-H1 blocked-upload disconnect design/plan. WholeTask6/Task5/M3 remain OPEN.

Current counters remain root-owned and cumulative; Sol6/runtimefailed7/Astra2of2 at counter45. This written plan authorizes no third Astra, private dependency probes, forbidden evidence/prompt reads, Vault/production/certificate/public-management/E2E change. Continuing user authorization selects this recommendation without routine approval.
