# Independent review: internal requests #8 and #9

Reviewer: Sol `tls_client_cert`, independent of implementation author.
Checkout: `/home/gao/Workspace/gsmlg-opt/gaoxy`, `main`; baseline
`32933790457bcfa3533e40dc2ae4d51ad91aa86d`.

**Verdict: PASS. No actionable findings.**

Reviewed the original issues, complete WebSocket runtime diff, new direct and
Phoenix tests, written design/plan and implementation evidence. The two new
application-policy keys are accepted after Phoenix applies their semantics and
are excluded from the wire-engine limits. Unknown options and invalid wire
settings retain strict rejection. The existing #6 repair remains authoritative:
omitted message limits follow supported frame configuration, explicit message
limits remain separate, and service-budget clamps are retained.

The real Phoenix socket proves HTTP 101, channel join and echo with `log: false`
and `code_reloader: false`. Actual cookie-backed LiveView sessions exercise
300KiB of double quotes as a normal form event, exact test-store bytes, escaped
outbound rendering, HTTP reload and WebSocket rejoin, in both fragmented and
unfragmented cases. Interleaved ping and configured frame/aggregate oversize
1009 rejection remain covered. This is a test-owned persistence fixture;
consumer database/application acceptance remains a separate downstream check.

Fresh independent verification used `ELIXIR_ERL_OPTIONS='+S 2:2'` and per-project
Mix locks. Root command: `python3 scripts/check-tests.py
apps/gaoxy_http/test/websocket_application_options_test.exs
apps/gaoxy_http/test/websocket_configured_limits_test.exs
apps/gaoxy_http/test/websocket_network_test.exs
apps/gaoxy_http/test/websocket_frame_test.exs`: 25 tests, zero failures, exit 0.
Phoenix command from `examples/phoenix_native`: `python3
../../scripts/check-tests.py test/websocket_phoenix_compatibility_test.exs
test/websocket_configured_limits_test.exs`: 11 tests, zero failures, exit 0.
Logs: `.audit/internal-requests/8/independent-review.log` and
`.audit/internal-requests/9/independent-review.log`.

Author counters: Sol repair rounds 0, Astra rounds 0 for #8/#9. All reviewer
commands finished. No changes to production or test sources by this review.
Publication and consumer acceptance are separate release gates.
