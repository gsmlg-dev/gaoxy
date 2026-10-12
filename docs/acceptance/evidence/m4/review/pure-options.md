# Independent pure protocol and options review

2026-10-12. Reviewer: `m4_dependency_audit` (Sol), independent of the Options and
Protocol/Headers writers. Assignment: read-only specification and code review.
Worktree `.trees/m4-http3`, branch `codex/m4-http3`, baseline
`78de9d0f3bba5a4662717359438eb3d0853a79b4`.

Verdict: **PASS for the reviewed pure/options implementation scope**. No unresolved
actionable findings in that scope. This is not G1 live HTTP/3, Plug, browser,
upstream-H3, standalone, publication, or production acceptance.

Reviewed package dependency boundaries and public-codec use; strict options,
initialization ordering and aggregate reservations; incremental framing and
bounded extension discard; stream/connection error scope; SETTINGS and push-ID
rules; QPACK static/literal/Huffman behavior and instructions; request/trailer
validation; continuing authorization and preserved product restrictions.

Findings resolved by the owners and re-reviewed:

1. Invalid byte budgets initialized the endpoint before rejection. Options now
   validate normalized limits and aggregate reservations before initialization;
   valid endpoint initialization still occurs once. Uni parser carry reservations
   are explicit and the default `max_state` is 3 MiB.
2. Legal zero-capacity QPACK Stream Cancellation closed the connection.
   RFC9204 section 2.2.2 permits a zero-capacity decoder to send cancellations
   (it MAY omit them). The decoder parser now incrementally accepts/ignores
   prefix-six cancellations with IDs below 2^62; invalid acknowledgments,
   increments, overflow and out-of-range IDs retain error 0x202.
3. CONNECT rejected a matching ordinary Host. Matching Host now parses for
   the explicit 501 policy; disagreement and duplicate Host remain 0x10e.
4. Valid Content-Length above the configured body ceiling was classified as a
   malformed message. It now receives resource error 0x107; malformed syntax
   retains 0x10e and actual DATA length checks retain their assertions.

Evidence inspected: `options/repair3.log` executes **8 tests, 0 failures**;
`pure-protocol/repair-2-green.log` executes **52 tests, 0 failures**. Their
verification commands are the scoped `scripts/check-tests.py` wrapper, inside
`nix develop` with `MIX_ENV=test`, `ERL_FLAGS='+S 2:2'`. Parent owns the final
fresh combined gate and format/compile receipt; this review does not replace it.

The reviewer independently executed current source using:

```sh
elixir -pa '_build/test/lib/*/ebin' \
  -r apps/gaoxy_http3/lib/gaoxy/http/http3/headers.ex \
  -r apps/gaoxy_http3/lib/gaoxy/http/http3/protocol.ex -e '<pure assertions>'
```

Before repair, `new -> open(:decoder,:uni) -> feed(<<3,0x40>>)` returned
`{:error,:connection,0x202,:unexpected_decoder_instruction,...}`; matching
CONNECT Host and valid over-limit Content-Length both returned stream 0x10e.
After repair the same current-source probes accepted cancellation with empty
carry, accepted CONNECT Host, and returned stream 0x107 `:body_limit`. Command
exit 0; in-memory module-redefinition warnings are expected, no BEAM writes.
Public RFC9114/RFC9204 text was read from rfc-editor.org, not inferred from a
library implementation. All reviewer command sessions have finished.

Integration risk carried to G1: `feed/3` deliberately stops at its finite work
quantum and can retain complete input. The connection owner must drain credited
empty-input continuations before delivering FIN; otherwise `fin/2` can report
false truncation. Body parsing must still respect application credit.

Reviewer cumulative G0 author counters remain Sol2 / unsuccessful1 / Astra0;
this read-only review has no repair rounds and does not reset owner counters.

## Current reviewed source receipt

| File | SHA256 |
| --- | --- |
| `AGENTS.md` | `343b7a27706f0547a1d42ea49628938017d21170d04cc4fe84cd9b76d5d99969` |
| `apps/gaoxy_http3/lib/gaoxy/http/http3/headers.ex` | `87fedd6a097542d810cc6c49fb6b9dc0a7aac47d6fc7522333212936ceeaa84d` |
| `apps/gaoxy_http3/lib/gaoxy/http/http3/options.ex` | `8c9d17c955373b16e12011fa2762e5fb7c1edc76ba564111e4ae625b0b826e0d` |
| `apps/gaoxy_http3/lib/gaoxy/http/http3/protocol.ex` | `0e7c588075ebccb16e6d3d6dde32c0ad2cb8a65dc04a4010e6d0fbdffcb9194f` |
| `apps/gaoxy_http3/mix.exs` | `5391c790c0720e678f1a0ea99f4462df9069e89fb5536b97f03a317d5a86bc86` |
| `apps/gaoxy_http3/test/headers_test.exs` | `e1198a89ef77d482e6535857757e5f7b0447c462fdd850e8d3e22e02b66e0676` |
| `apps/gaoxy_http3/test/options_test.exs` | `1dcf1942c3fe5f94e1bcd923ab131841d63f573ff97db3a3837932693061186c` |
| `apps/gaoxy_http3/test/protocol_test.exs` | `c36144672061ad67b3891917b0985012948a1ad9e3758bc220a94c9e640031ab` |
| `apps/gaoxy_http3/test/qpack_test.exs` | `95f8b04c5b46e0501bd1fbea3ae2e4653c8813935d46138afe4dc19846951d77` |
| `docs/designs/m4-http3.md` | `281f2eabeca29d7928e7c1afb61bf369d1aa3ae8bca070e7923f175d14bae876` |
| `docs/plans/m4-http3.md` | `0313ec847c1de403ecfd956fe6d16558acb75c0cbe39a8c622de9f7f2135d0d0` |
| `implement-plan.md` | `83e491bd4dbf60d8c220346e5a6e41e5481c5683294ac362ef3f34c0dd150b9d` |
