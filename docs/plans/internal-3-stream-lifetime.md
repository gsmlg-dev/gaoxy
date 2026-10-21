# Streaming response lifetime implementation plan

**Goal:** Resolve gsmlg-dev/gaoxy#3 and #7 through a supported opt-in without weakening
finite request, I/O, admission or shutdown protections.

**Architecture:** Reuse the request lease and HTTP stream owner. Transition to a
separate response deadline only at streaming-response start after body EOF.
**Tech stack:** Elixir 1.18, OTP 28, Plug/Phoenix, independent Python h2.

- [x] Add failing option, public Plug API and real H1 regressions in
  `apps/gaoxy_http/test/stream_lifetime_test.exs`; retain expected red output.
- [x] Normalize `stream_timeout` in HTTP Options, add the public helpers in
  `Gaoxy.HTTP`, and implement the lease transition in Admission and Exchange.
  Invoke it through protocol-neutral Response streaming start. Keep finite
  write timeouts when the response deadline is infinite.
- [x] Update H2 owner and transport for a stream-local lifetime transition and
  finite owner-operation waits. Add independent h2 tests for coexistence,
  reset/cancel, zero flow credit and resource reclamation.
- [x] Add a Phoenix fixture test and document direct Plug/Phoenix configuration,
  polling, cancellation, body-EOF requirements, admission and H3 boundaries.
- [x] Obtain independent specification/code review; repair actionable findings;
  rerun focused tests and ordinary compatibility on the integrated source.
- [ ] Commit the reviewed issue fix, then qualify and publish the coordinated
  next release through the existing release workflow, verifying public artifacts.

Commands: `mix test apps/gaoxy_http/test/stream_lifetime_test.exs`,
`mix test apps/gaoxy_http/test/stream_lifetime_h2_test.exs`, and, from
`examples/phoenix_native`, `mix test test/stream_lifetime_test.exs`.
All required cases must execute with zero failures/skips. Evidence belongs in
`.audit/internal-requests/3/` and the final release acceptance record.
