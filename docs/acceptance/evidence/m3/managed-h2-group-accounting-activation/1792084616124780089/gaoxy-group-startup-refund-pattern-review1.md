# SPEC/compiler-expression review — exact startup refund pattern

**PASS_SOURCE; actual compile/test retry pending.** The correction preserves exact refund integer-5,963,776 while moving its negation into expression context and pinning the computed local in the trace pattern. No actionable findings.

Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; branch `codex/m3-h1-resource-foundation`; baseline `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`. Current target `apps/gaoxy_proxy/test/managed_h2_group_startup_reservation_test.exs` SHA256 `9c69acc3ca3aba29bb147973c46a421800297dbbac18361cc09a39231b5ba0bd`. Exact reverse reconstruction reproduces failed formatted source SHA256 `abf5884c91811392e3a398fe8dae8bbd85ef7232678af36f05ba9666b39c9b12`.

| Check | Result | Evidence |
|---|---|---|
| P01 | PASS_SOURCE | Current startup target SHA9c69acc… authenticated; reversing exactly local assignment and pinned-pattern replacement reproduces compile-failure source SHAabf5884…. |
| P02 | PASS_SOURCE | Preserved receipt/log SHA authenticated: actual exit1, process joined, sources stable, zero executed tests. Compiler exact cannot invoke remote function :erlang.-/1 inside a match is retained as FAIL, not zero-failure PASS. |
| P03 | PASS_SOURCE | Local refund = -@startup is evaluated in ordinary expression context before refund_call enumeration. Startup constant remains5963776; refund is exactly integer-5963776. |
| P04 | PASS_SOURCE | Pinned ^refund enforces exact original negative integer value. Pump, gate, lease, function/module/arity and original event tuple remain pinned/identical; no wildcard replacement or broadened result. |
| P05 | PASS_SOURCE | helper_return/refund_call nonnil checks and strict helper_return < refund_call ordering remain unchanged; all startup/attach/refund totals, exact-once adjustment traces, real request/original completion and denial assertions untouched. |
| P06 | PASS_SOURCE | Other -@startup uses are expression/guard contexts; correction narrowly moves this call out of match? pattern. Source syntax rationale addresses evidenced compile error; actual fresh compile/test retry remains required. |
| P07 | PASS_SOURCE | No production source change or API/dependency expansion. Earlier source-only syntax assessment missed this compiler restriction and is superseded by actual failure and this targeted review. |
| P08 | PASS_SOURCE | Reviewer ran only source/hash/diff/receipt reads; no runtime/build/formatter/Git/repository mutation. Parent counters failedGREEN18, ordered repair20 and Astra2/2 retained. |

Preserved failure receipt SHA256 `e534c76fa4b7c64b57e006047609998d9754dbf98e9d4477588feba89c6ec5e6`; actual log SHA256 `65b27e0f5afb93fd51c124b4d479f1e165368961258a1341fe3dedf9d43e2c29`. Actual exit1, zero tests executed. Prior source-only syntax confidence did not catch this restriction; it is not passing compilation evidence.

Reviewer repairs0; parent failedGREEN18/ordered repair20 and Astra2/2 exhausted, unchanged by review. All own commands finished, actors untouched, only assigned new /tmp reports written. Fresh retry and remaining stage gates remain parent-owned; no user decision needed.
