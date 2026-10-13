# M4 UP2 retained DATA delivery implementation plan

Root owns the adapter/test changes and all serialized Mix/live commands.
Independent Sol owns unique SPEC/CODE/evidence review receipts. Writers are not
alone; preserve others' edits and freeze apps/integration/scripts during runtime.

Goal: remove avoidable downstream roundtrips for small DATA events already held
in the bounded public Session queue, within the existing16KiB delivery ceiling.
See [design](../designs/m4-up2-retained-data-delivery.md).

- [ ] Independent SPEC review of actual repair10 FAIL, bounded traversal,
  byte accounting, immediate partial delivery and unchanged acceptance oracles.
- [ ] Add deterministic tests to
  apps/gaoxy_proxy/test/http3_session_client_test.exs. Record genuine assertion
  RED with unchanged production source. TDD RED adds no failed live execution.
- [ ] Minimal apps/gaoxy_proxy/lib/gaoxy/proxy/http3_session_client.ex change:
  consume only consecutive already retained DATA up to16KiB, retain exact tail,
  subtract delivered bytes, preserve one ACK and all terminal/control fences.
- [ ] Focused GREEN, exact format/strict compile and all affected scoped tests;
  immutable counts/exits/source hashes. Independent CODE/prelive clearance.
- [ ] Entire matrix with GAOXY_UP2_REPAIR=11 GAOXY_UP2_FAILED=19 under canonical
  Nix test environment. Require66 network+2 policy checks, original5s, exact
  1MiB/hash/FIN and all cleanup/sibling/error oracles. Preserve any actual FAIL
  and update counters. After PASS, independent actual-evidence review and fresh
  full68 repeat precede prescribed final M4 verification/review and publication.

No third Astra round, counter reset, weakened assertion or publication on an
incomplete gate. Current cumulative UP2 counters19 live/7 production/3 harness.
