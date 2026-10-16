# Frozen diagnostic5 actual-source SPEC1

**DONE — PASS for the planned NONACCEPTED diagnostic, source only.** No runtime GREEN, browser qualification or full-stage acceptance is claimed. No actionable blocking finding remains on this tuple.

## F1 resolved without weaker terminal checks

`native-worker-browser-frontdoor2.py:61–93` processes selected socket reads/writes/EOF before interpreting control. EOF while unauthorized still raises and terminates nonzero. Lines104–108 create only a pending authorization; lines121–130 commit authorization only with the same live pair, no EOF, empty queues and a fresh zero-time read-select reporting neither selected socket readable. Readable input defers authorization and is serviced next iteration while still unauthorized. Duplicate authorization or stop while pending fails. This resolves the frozen diagnostic4 control-first EOF race.

The new comment correctly describes an **observed quiet I/O boundary**; a local poll cannot establish unknowable remote physical FIN timing. Previous diagnostic4 FAIL remains immutable and is not retroactively relabeled.

## Preserved profile and native contract

The first accepted socket remains irreversibly selected with exactly one bounded loopback backend connection attempt. Extras close without backend creation. Raw ordered bytes use bounded65536-byte direction queues/backpressure and16384 reads; partial sends update accurate counts/hashes. Positive traffic, equal per-direction receive/send lengths and SHA256s, genuine EOF both ways, empty queues and postdrain write-half-closes are mandatory before connection complete. Stop can return0 only after completed pair closure; inherited actor exit/logreader/group joins and forced-cleanup FAIL rules remain. Absolute90s and backend5s bounds are unchanged.

Host4 is byte-for-byte unchanged from the prior reviewed tuple. Runner5 differs from runner4 only by the helper filename. Existing global exact3 and byte assertions, postrequest original C/R exact2 and bytes, G7/T8/Session custody, worker/Session normal joins, zero cleanup/accounting, actor terminal reasons, strict full upstream response/framing, native TLS/ALPN, actual Chrome CDP h2/visible page/screenshot, and sequential H1 compatibility all remain. Host requestclean and same captured live/unjoined C/R authorization precede relay ack, which precedes Browser.close. Relay complete/normal join precede host stop.

Source inventory includes the new helper. Metadata still explicitly identifies `NONACCEPTED_BROWSER_DIAGNOSTIC` / `single-selected-raw-tcp-connection`; production APIs, dependencies, accounting limits and calculators are unchanged. Native Gaoxy remains TLS/HTTP endpoint; direct Chrome-to-listener TCP or broad multi-connection behavior is not claimed. Prior writer-beforeauth cause remains **UNKNOWN**.

## Exact reviewed tuple

- `native-worker-browser-diagnostic-host4.exs`: `1c2b98b459c3d15d3fad7d5c20d73e7a5b7629c1a507da0ead62e8c929d15113`
- `native-worker-browser-diagnostic-runner5.py`: `35e7e0fc6d7c5e34b107257a19d1d9a89488884776a1d1908e24a82daf92d502`
- `native-worker-browser-frontdoor2.py`: `dd53b803832545b1b68897141da8c7fd2e4a09c78a534ff16d6421cd844f43cc`

Repository: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Evidence root: `docs/acceptance/evidence/m3/native-worker-accounting/1792113258488285300`. Frozen hashes were verified before and after review. Read-only full helper and scoped diffs completed; no runtime/browser/network/Mix/Git command or actor launch. Parent's AST parse PASS is not independently rerun or promoted to runtime evidence. No raw trace/archive or full sys-state replies were read. Only these two assigned `/tmp` reports were created.

Historical runner entry_counters text remains original lineage metadata; actual parent counters stay group37/root47/stage7/Astra2of2. This review adds zero failedGREEN and zero Sol repairs. All own commands finished. Full stage remains OPEN pending actual evidence and required reviews/gates.
