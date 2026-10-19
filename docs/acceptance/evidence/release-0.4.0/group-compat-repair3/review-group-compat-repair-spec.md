# Ordinary Exchange compatibility repair SPEC — PASS, conditional

Reviewed updated release design/plan and exact ignored patch `86dffbfee45a7756541563016fe37349fbfe3e264e0e55263000e650d60113fb` against frozen source `9253b787b57b768682bb4d894f25ca82919c0a94`. In-memory hunk matching and all baseline/proposed hashes pass; no patch was applied.

The four-file proposal repairs ordinary H2/H3 Exchange construction for both listener opt-in values, preserves actual WebSocket metadata and connection settings, and leaves strict managed-group accounting/caps unchanged. One new H2 network test observes the actual endpoint limit map for false/true; one new H3 constructor test covers ordinary false/true and actual WebSocket metadata. Original tests/assertions and real WebSocket peers remain intact.

Application/execution remains conditional on the parent diagnostic reproducing4 executed/2 failures and H1 accepted versus H2 invalid-limit pump observations, followed by independent CODE review. Test-only RED must be executed and retained; preparation is not RED. No diagnostic outcome is claimed here.

Expected fresh ordinary counts are55 HTTP +83 H3 =138 M5, plus unchanged38 M3 unit +24 network =200 executed invocations, with90 network exclusions and no skips. Parent must synchronize only expected counts and bound scope/verifier hashes; selected files and existing selectors remain unchanged. Fresh ordinary portable/package/offline-runtime and actual artifact reviews remain required. Current metadata synchronization and runtime verification are pending.

No specialist abnormal/disconnect/pressure/soak scope is added. Only ignored review receipts written. No Git/build/test/runtime/browser/network commands. All reviewer commands finished. Reviewer repair0; completed release Sol2, proposed next repair3; inherited Astra2/2 unchanged.
