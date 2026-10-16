# Checked browser proposal independent source review

Task: `checked_browser_source_review`. Assignment: direct, independent source-only Sol review. Verdict: **PASS (source review only)**. No actionable finding. Browser/runtime qualification remains **NOT RUN by this reviewer**.

Repository: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; observed baseline `e189894882bb6a530f2c38538be4efaf384be261`. Existing repository and untracked changes were root-owned and preserved. This reviewer writes only this report and its matching JSON. No application, runtime, build, formatter, test, browser, network actor, Git mutation, or dependency mutation was executed.

## Reviewed identity

| File | SHA256 |
| --- | --- |
| `/tmp/gaoxy-native-generation-checked-browser-host1.exs` | `a0f0931fa3bc05091d1df103b31726ed964bd1efd0ed897085f0b338c844762e` |
| `/tmp/gaoxy-native-generation-checked-browser-runner1.py` | `17749bc3d349ea843f86242b9c074973d5e5a82316990de91609fc98073c9eb2` |
| `/tmp/gaoxy-native-generation-checked-browser-notes1.md` | `766232aa93c9e1f2796b8a3d010ce91ffaaaf2816a0401e267ad7f9b95dee0db` |
| `/tmp/gaoxy-native-generation-checked-browser-notes1.json` | `ece0e3d6d6cf7288d4a98388ec349be3564896ec9c5192121dd67072371cfdfa` |

## Evidence and assessment

- The selected scope matches the canonical design's Required browser compatibility check and plan Task5/browser acceptance binding. It uses the existing opt-in native H1 Generation seam, a public G-H1/T route, one real Chrome document navigation, and an independent raw H1 peer. It neither activates upstream H2 nor substitutes for the existing downstream-H2 independent-peer gate.
- Host lines55-89 use actual current public preparation, Router, Generation, service, lifecycle and resource APIs. `UpstreamGroups.status/1` returns direct H1 group status; `T.status/1` returns `{:ok,status}`. The status fields used are correct. OTP28 `:sys.install/2` explicitly accepts the three-element debug-function specification used at lines74-82.
- Host lines101-107 independently calculate the fixed point using exact ETF integer widths. The default-M base is `6*1048576 + 4957373 = 11248829` at ordinary widths; coefficients3/5/4 match the separately derived native fixture expression. It does not obtain expected B from the production reservation function. Lines118-127 then compare that independent result with both captured `route_bytes` and the real compact reservation result and public owner-entry Admission observations.
- Original owner input comes from real Store-to-owner calls (lines74-82); complete public reply terms come from owner send tracing (lines83,128-139,179-182). Correlation receives the original owner, operation and complete original batch rather than projected receipt authority. Different-sender ordering is handled by selective original/receipt collection. The capture barrier prevents upstream forwarding until these checks and the actual Admission lease check pass.
- Runner lines25-89 implement a separate raw socket peer and assert the real HEAD health request and GET document. Embedded Node lines137-162 assert actual CDP document status/protocol, visible title/text/location, no page runtime exception/console event, and save a screenshot/events. Failure at any of these checks prevents a PASS qualification.
- Normal teardown verifies request pins/tokens/helpers settle before browser closure, then waits for zero native active/retained/cleanup state. Store, group, transport and instance shutdown are finite; input-helper and actor/reader/socket-worker joins are explicit. Browser.close is followed by a finite Chrome join. Forced actor/process-group cleanup makes qualification FAIL rather than being accepted as ordinary teardown. All subprocess sessions belong to the runner.
- Before/after relevant source/script inventories plus host-loaded source/BEAM identity checks bind successful evidence to local code. Evidence directory creation is exclusive. The runner's final PASS also requires stable source, normal zero process exits, no forced cleanup and joined readers/process groups.

Review verification consisted only of bounded file reads/searches, public-source comparison, OTP-source comparison, `git status --short`, `git rev-parse HEAD` and `sha256sum`. These commands completed. No task-owned live process remains. Syntax execution and runtime/browser success are deliberately not claimed; root must run the adopted exact candidate and inspect its qualification receipt.

Counters from the latest parent update are preserved: current-stage completed failedGREEN5 / aborted1 / production1 / postGREENfixture4 / preGREENfixture1; cumulative completed group failedGREEN29 / root failure events33; Astra2/2 exhausted. This source-only review adds zero implementation repair rounds, runtime failures or Astra rounds. No product decision or external permission is needed for this reviewed proposal.
