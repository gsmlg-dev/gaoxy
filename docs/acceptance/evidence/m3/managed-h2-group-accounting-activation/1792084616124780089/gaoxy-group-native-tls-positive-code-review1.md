# Native TLS positive repair1 — independent code review

**DONE_REVIEW_NO_OPEN_SOURCE_FINDINGS.** Task `/root/browser_contract_spec/native-tls-positive-code-review1`; direct bounded read-only CODE review. The adapter readiness repair is justified at the production Conn construction boundary. Runtime acceptance remains pending.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; historical supplied baseline `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`. No Git run or whole-tree identity claim. Current Exchange before SHA256 is `513c300e4b3a161d54465696663eaa024acc7061c87aa43f961c42ea54de5652`. Patch SHA256 `24d256384037ab88a241e01bc13162f81cb8926874af20d36d81dab8b2d1e371` and both author report hashes match independently. Python stdlib exact-context/hunk-count reconstruction in memory produces declared after SHA256 `75b752c358d861be75446b99fef948f023082e6de177840bef35f99ce20776d0`. It adds only `Code.ensure_loaded!(Gaoxy.PlugAdapter)` and a blank line before Conn construction.

## Evidence and production boundary

The authenticated diagnostic receipt SHA256 `01fd918d56960b7d78d013f424796771d4ab97b15566acc157eac545f0cd874b` records actual **FAIL41 executed/2 failures/0 skipped/0 excluded**, exit2, joined/no timeout, stable190-input source. Its log SHA256 `61fda4c0f25e01f9fde0c6fd046a0fcc1163ccbd657251297bfc22a542cbc156` has two actual exception captures at140–146 and272–278: `RuntimeError`, `get_ssl_data not supported by Gaoxy.PlugAdapter`, and actual `:code.is_loaded(Gaoxy.PlugAdapter) == false`.

The diagnostic script SHA256 `a67cdc13b5c97532eb2b0e2d39389003c7e19067c7e064952a2ae851cc023d30` was read. It wraps only the original Plug metadata expression in memory, captures that real exception and loaded state, then reraises the original exception/stack. It neither preloads the adapter nor substitutes success. All original test assertions remain. The capture is explanatory FAIL evidence, not repaired acceptance.

`Exchange.plug_conn56–77` constructs a Conn carrying the Gaoxy.PlugAdapter atom. `Plug.Conn.Adapter.conn37–53` stores that atom without calling or loading it. `Plug.Conn.get_ssl_data662–668` first probes `function_exported?`; an unloaded module fails that optional-callback probe even though `Gaoxy.PlugAdapter67` implements it. Ordinary `Gaoxy.HTTP.PlugEndpoint.call27–30` constructs the Conn before user Plug execution, so SSL metadata can be the first real adapter operation in production. Loading the owned adapter in the shared constructor fixes both direct Exchange consumers and ordinary Plug endpoints. A fixture preload would leave that production path exposed.

The runtime load call introduces no interface, dependency or architecture change. An absent required owned adapter raises at construction; no fallback masks it. Only an explicit gaoxy_http Plug-Conn construction invokes the load, so core-only startup/isolation is untouched. This evidence identifies Gaoxy adapter readiness, not a proven Plug dependency defect.

## Preservation and limits

All9 author-listed source hashes match current reads. The unchanged formatted TLS test SHA256 `601d497749e5daee3c4dc43d6351ddcc70abe5bda17f888be49eee5cd2be4ea3` also matches the diagnostic manifest. No test, expected reason, assertion, timeout or fixture is changed. Native H1's direct Socket SSL path and secure/nonsecure behavior remain; H2's original caller-worker/id/token authority and authoritative deadline remain; H3/other transports retain their stored SSL path. TLS ownership, accountant and caps are unchanged.

Formatting, compilation, runtime/tests and browser checks were **NOT RUN**; zero new tests executed. Parent must adopt, format/strict compile and execute the original unchanged nativeTLS suite and prescribed affected compatibility/accounting gates. The observed diagnostic41/2 does not establish41/0 or whole-stage acceptance. Parent separately reports joined Session46/0 PASS; that receipt was not independently authenticated in this adapter review.

Reviewer adds0 Sol repair rounds; latest parent failedGREEN20/event22, Astra2/2 exhausted, no reset. No new design decision or permission is needed. An initial source search used an incorrect shorter PlugEndpoint path; it was corrected and the actual source read in full. All own commands finished. No repository, Git, build/runtime or process-control changes occurred; only this new review pair was written.
