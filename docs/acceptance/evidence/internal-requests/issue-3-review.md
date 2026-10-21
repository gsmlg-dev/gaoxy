# Independent review: internal request #3

Reviewer: `tls_client_cert` Sol worker, independent of the implementation author.
Baseline: `32933790457bcfa3533e40dc2ae4d51ad91aa86d`, working on `main`.
Reviewed the complete streaming-lifetime runtime diff, H1/H2/Phoenix tests,
HTTP/3 boundary, written design/plan and public guide, and Generation cleanup
compatibility including its nine deterministic regressions.

**Verdict: PASS. No actionable findings.**

The opt-in transition occurs only at streaming response start after body EOF.
Pre-response work, headers and uploads retain the finite request deadline;
ordinary responses retain their original lifetime. Infinite and finite stream
lifetimes preserve the same owner lease, active slot, byte accounting and drain
ownership. H1 physical writes and H2 owner/write waits remain finite. H2 lifetime
changes and cancellation affect the selected stream while preserving siblings.
HTTP/3 explicitly rejects the new lifetime policy rather than silently accepting
an unsupported capability.

Checked Generation completion releases request pins using a fresh finite
one-second allowance after a confirmed lifetime change. Exceptions and stale
returned Exchanges use a bounded owner-only lease query only after the original
cleanup allowance expires. Ordinary finite-request and acquisition cleanup keep
their original deadlines. Exception class, value and stack remain preserved.
The new tests prove pin release before request-owner exit, then lease reclamation.

Fresh independent checks used `ELIXIR_ERL_OPTIONS='+S 2:2'` and the shared Mix
locks. Root command: `mix test apps/gaoxy_http/test/stream_lifetime_test.exs
apps/gaoxy_http/test/stream_lifetime_h2_test.exs
apps/gaoxy_http/test/stream_lifetime_contract_test.exs
apps/gaoxy_http/test/stream_lifetime_generation_test.exs
apps/gaoxy_http3/test/stream_lifetime_boundary_test.exs
apps/gaoxy_http/test/generation_checked_capture_test.exs
apps/gaoxy_http/test/generation_release_deadline_test.exs`.
Result: HTTP 178 tests and HTTP/3 1 test, zero failures, exit 0.
Evidence: `.audit/internal-requests/3/independent-final-review.log`.
Phoenix command from `examples/phoenix_native`: `mix test
test/stream_lifetime_test.exs`; 2 tests, zero failures, exit 0.
Evidence: `.audit/internal-requests/3/independent-final-phoenix-review.log`.

Generation cleanup author counters: Sol repair rounds 0, Astra rounds 0.
Historical specialist pressure/soak/disconnect slices remain outside this review;
this verdict covers the ordinary issue-specific bounded tests. Publication and
consumer acceptance remain separate release gates. Both review commands finished.
