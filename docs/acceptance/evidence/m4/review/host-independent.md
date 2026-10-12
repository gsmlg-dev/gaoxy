# Independent M4 G0 and design review

Reviewer: `/root/m4_spec_review`, independent from the host/fixture author.
Review completed 2026-10-12 on `codex/m4-http3`, worktree `.trees/m4-http3`,
starting baseline `78de9d0f3bba5a4662717359438eb3d0853a79b4`.
This receipt records the previously completed review; the host author owns fresh
verification and must not describe that rerun as independent review.

## Specification compliance: PASS

Reviewed the selected public Gaoxy/Abyss API path and source-bound host evidence:
`host/source.json`, `source.diff`, `final-commands.json`, `final-format.log`,
`final-compile.log`, `final-tests.log`, `summary.json` and preserved red/repair
logs. Final recorded consumer gate executed **4 tests, 0 failures** and **9 real
independent aioquic peer cases**. CA/hostname/ALPN verification, fragmented uni
and bidi traffic, FIN, directional RESET/STOP, definitely blocked admission and
eventual received bytes, sibling isolation, live listener removal, Admission gate
DOWN and same-port/new-generation rebind all have matching assertions and logs.
The consumer cohort matches root 0.21.3; Abyss is pinned to
`9b710e6480900e16e304f40e63623aff8c922e19`; root lock is unchanged.

Generic QUIC bytes negotiated with ALPN `h3` do not prove HTTP/3-frame acceptance.
A controlled unknown-operation probe remains **NOT RUN**, no uncertain receipts
were observed, and no blind retry was introduced. Peer-close phase error logs
are preserved and disclosed, without weakening active-traffic assertions.
Application retained-byte observations do not claim total VM/native memory.
Local cleanup does not claim graceful HTTP/3 GOAWAY drain.
No unresolved specification findings remain for G0.

## Code quality: PASS

The host fixture waits for authenticated readiness, retains opaque capabilities,
derives numeric IDs from public read items, keeps reset/STOP directional, and
handles the evidenced definitive `:stopped` race per stream. No private engine
API, patched dependency, listener capability leak or new process outside the
qualified host path was introduced. Task-scoped source changes, explicit finite
bounds, pinned peer environment and preserved failed attempts are reviewable.
No unresolved code-quality findings remain for G0.

Cumulative G0 counters: Sol repair rounds **2**, unsuccessful **1**, Astra **0**.
All reviewer commands finished; no build/peer process is owned by this reviewer.

## Previously completed design and implementation-plan review

**Specification PASS; code/design quality PASS.** Parent incorporated all
reported findings before Task2: explicit unsupported H3 WebSocket upgrade,
QPACK compression versus message/resource error classification, aggregate
DATA/content-length verification, capability/document synchronization, reserved
unidirectional parser bytes, and required later upstream-H3 matrix plus
standalone H3 slices. G0-G3 cannot substitute for full M4 acceptance. The
optional `gaoxy_http3` package and G0/Task1 starting boundary were accepted.
This receipt does not claim Task2, shared Plug, browser, remaining upstream
matrix, standalone, hosted CI, publication or deployment completion.

## Reviewed inputs

All recorded input hashes below matched the current checkout when this receipt
was written; the original reviewed evidence is in `host/source.json`.

- `integration/quic_consumer/mix.exs`: `256e9b39568a253446290ee73c16564b674b1d3786f21b03ffe2578b72d5b262`
- `integration/quic_consumer/mix.lock`: `300576700534c047c4f5cfc2e3621eeea27f45900c4097a93e3cb452a75ce916`
- `integration/quic_consumer/test/quic_test.exs`: `9a9c7020981eae2cb85e117c4e02e963c4d6cc29e4a83cf74252627e1bf4b57c`
- `integration/quic_consumer/peer.py`: `b4f9bc012795f19251f8f1ab5dd247b7a2e9874976f66d8c9cd9ff233d168688`
- `integration/http3/requirements.txt`: `baa71ded2594f376d2ee2772a724b5b3d8be79e37a3b76392a94130e2069a3fb`
- `integration/http3/README.md`: `1a01018133305bb6eeb9c4d95e7d16f61380e7f006ab811a0c8eaa5dd2a3f5f1`
- `mix.lock`: `16542ddd554f9b78139ddf456288450a12da5781cf3900576edd7e83f159dc25`
- `flake.lock`: `ab9cba40e49dca0023bfd18bff4df80e5470abb70ee2acd64f8419ffb8a19459`
- `apps/gaoxy/lib/gaoxy/quic.ex`: `138f847c993bcbd7ae54127cd0f22614f726e78d3eccc8bc76e3d624b3031b98`
- `apps/gaoxy/lib/gaoxy/quic_bridge.ex`: `249d39e3956212eb49c0692c19c46f401e9d29e846af0fd8f1e409d993cc6a32`
- `apps/gaoxy/lib/gaoxy/service.ex`: `c0fa0549815500dad5f50779b05777880b008276540bae58d47a4cccd061037b`
- `apps/gaoxy/lib/gaoxy/config.ex`: `43609c0e7ea8150161f315b242e0d5c38d92baba4cb9f11700605195dbdcf241`
- `integration/quic_consumer/deps/elixir_quic/lib/quic.ex`: `7791050053a16acdb9c8329a9a23034335d423c574adbc77d6215b8231d5500d`
- `integration/quic_consumer/deps/elixir_quic/lib/quic/connection.ex`: `cee54dac44b538d50f546dc91c28a6d46a7e713f100f591a44309ac55b3ad806`
- `integration/quic_consumer/deps/elixir_quic/lib/quic/streams.ex`: `2ddf17fe7372796f21b65c2e4fd54e5d36f28071ee59d615c11e43029c163145`
- `integration/quic_consumer/deps/ex_ssl/lib/ssl/quic.ex`: `d8575ea864739830c9b52185ad09aa3af03cf8a61d8164ebce5473b4cbdfddf3`
- `integration/quic_consumer/deps/abyss/lib/abyss/quic.ex`: `440cb155d37d6f374cee704b8cc5c35a09dbb0759366116c8220d4cde3f3c9e2`
- `integration/quic_consumer/deps/abyss/lib/abyss/quic/service.ex`: `ecd853982f39301c88fd174d81978deeca28c21e6800797647fbd30b268d8b42`
