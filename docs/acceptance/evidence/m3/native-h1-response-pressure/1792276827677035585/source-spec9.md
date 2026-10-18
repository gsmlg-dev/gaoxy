NATIVE H1 PRESSURE SOURCE SPEC9 — DONE (review verdict FAIL)

Direct independent read-only review of candidate9, worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Baseline HEAD from candidate `fb7d0fda2b7c16c42c65579736dc1f643e17d812`; no Git run.

Two actionable findings:

1. P2 `apps/gaoxy_proxy/test/upstream_transport_native_h1_pressure_test.exs:476`: `events/0` checks overflow before the concurrent committed-row snapshot but not after it. A callback can set sticky129 during that snapshot, and the reader returns an already-overflowed partial history. diagnosis5.json:37 expressly requires both checks. Final completeness prevents an overall success receipt; it does not replace per-reader enforcement. Bind rows, recheck count<=128, then return them; keep progress free of reservation/row equality.
2. P2 `apps/gaoxy_proxy/test/upstream_transport_native_h1_pressure_test.exs:114`: unconditional ETS deletion also runs after failed cleanup. `failure_cleanup/1` can return fixture errors (1715-1716) or incomplete forced joins (1662-1668); detach does not join in-flight callbacks. diagnosis5.json:39 requires established emitter quiescence before explicit destruction. Delete only with that proof; otherwise preserve failure/cleanup and let controller exit reclaim the table. Normal success joins/detach/final-completeness ordering passes.

All 404 source,11 document,12 dependency and252 E13 evidence pins match. Candidate8 delta is exactly two source changes, no additions/removals;11 docs/12 deps unchanged;219 evidence entries retained unchanged plus33 additions. Exact reverse application of both author diffs to preformat9 snapshots restores candidate8 hashes. Format9 adds only inspected whitespace/wrapping. Four rows unchanged.

Controller-owned public synchronous ETS, same scope/event/time/bytes/operation/outcome, atomic saturation129, retained slots1..128, no new process/per-event packet, committed-row progress and exact final count/rows/prefix/control pass. All original mailbox64/event128/body262145/prefix262144/EOF/O+B1..16384/2→1→0/deadline/resource/normal-cleanup assertions remain. Fixture additions are failure-only and max16 safe summaries plus total/truncated; same RuntimeError/5000ms/error prefix/success path. No added raw bodies, headers or targets. Matrix cause UNKNOWN; historical fresh3 FAIL52/3 retained, fresh2 PASS52/0 is scoped evidence and no fix proof.

Candidate9 SHA256 `b3f9ffb32f272b973c3c4aa299ea089a18e542412cd7cb1d3be3631774b93f8e`. Pressure test SHA256 `f10077760305acf52bbe3a6f5b532783ae7be5097f71f6c7740d1352a7299948`; fixture SHA256 `fe6dc7ca61e98e42e0c734053e4232cd3a20b4b5b88f74d3494729ca7a155f79`.

Read-only source/evidence/hash/text checks completed;0 tests executed. Runtime/compiler/formatter/AST/browser/Git NOT RUN by assignment. Counter33 cumulative Sol5/runtimefailed5/Astra2of2 retained;0 repair/runtime increment. Later root counter34 notice retained. Four new tooling incidents: three excessive/truncated read-only outputs and one guessed absent source path rg exit2; all disclosed in JSON for root accounting. No repository writes, forbidden evidence access or private dependency process inspection.

Only these two /tmp reports written; fresh full-map sealing hash checks pass. All synchronous reviewer commands finished; no background commands. Reports immutable at DONE; custody returned to root. No user decision needed. Root owns the targeted repairs and fresh prescribed gates.
