# Native H1 pressure contract author1

DONE for direct bounded source repair2. Only `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/apps/gaoxy_proxy/test/upstream_transport_native_h1_pressure_test.exs` changed: +59/-12 lines.

Before SHA256: `33365a6758fa560045fe92294e666178ba3be9602435c54a7469b8b57a275dcd`.
After SHA256: `8c30bc398c5ffd875235f3dce4f9e4a13ca576cfc578b14cfe4e21d8371883e4`.
Reviewed DESIGN SPEC4 SHA/verdict match the supplied PASS.

The test now freezes actual positive framed O+B (B1..16384), requires that exact pair in all four pressure snapshots and started/post-read-success telemetry, and excludes O from the completed head operations. The new pre-prefix barrier requires nonempty unique head IDs, exact started/:ok same-byte matching, summed started bytes equal actual consumed head_bytes<=8192, and the exact slow owner/lease send=nil via existing finite monitored system(). Receipt adds B and hashed head provenance. No packet-count/size discriminator, payload-only assumption or new direct process observation is introduced.

Static baseline/hash, unchanged prefix/helper blocks, single-case count and obsolete strict-size checks passed. All original body/hash/buffers/deadlines/accounting bounds/EOF/joins and failure diagnostics remain; production/dependency/fixture/docs/evidence untouched. Formatter/compiler/tests/runtime/browser/Git and fresh SPEC/CODE NOT RUN. No runtime pass claimed.

One tooling incident: canonical keyword read projection output truncated (2612 original tokens against1900 budget); reported to parent, no command failure. Counter16 remains authoritative: current Sol source repairround2; actualfails2/sourcefailedSPEC1/designfailedSPEC2; Astra2/2 exhausted; no reset and0 runtime runs. All synchronous commands finished; no runtime processes started. Custody returned to root; source immutable after DONE.
