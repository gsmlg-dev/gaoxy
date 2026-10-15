# Group browser failure diagnosis 1

Task: browser_contract_spec / bounded group browser diagnosis. DONE for read-only diagnosis; no acceptance or repair claim.

Repository/worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Historical run HEAD from qualification: `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`. No Git commands were run for this assignment. All repository changes/processes remain parent-owned.

Evidence root: `docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089`; case directory: `browser-three-cases1-1792095973474636383`.

## Actual outcome

`browser-command1-1792095973474636383.json` records exit1, joined process, no timeout, stable source, FAIL and zero completed cases. `qualification.json` records `executed:0`, `cases:[]` and failure at group_browser.py193 -> fixed_browser.mjs54, the unchanged strict positive `Page.navigate` no-error assertion.

The CDP Document response for `https://localhost:39307/probe` is **h2/503/Content-Length0**, not502. Request/loader `F14793D691199505E17E07FDD4278564` matches noncanceled `Network.loadingFailed net::ERR_HTTP_RESPONSE_CODE_FAILURE`, error frame and network Log error503. Chrome-generated error content is separate from the empty response. This positive navigation must continue to fail.

`host.log:3` records healthy group, zero active probes and16,478,862 full request reserve. `positive-peer.log:3-9` records one real TLS/h2 connection with SNI localhost and HEAD `/health`; no `/probe`, `/stream` or `/early` upstream request appears. EOF follows collection shutdown. `positive-browser.log:3` confirms Chrome exit0 without force but `passed:false`; browser process closure does not establish protocol acceptance.

## Source-derived cause and remaining attribution limit

There is a concrete **Gaoxy runtime accounting/native-constructor incompatibility**, strongly consistent with the observed local503 before upstream submission:

1. `apps/gaoxy_http/lib/gaoxy/http/connection.ex:19-23,31-39` stores the complete successful `ThousandIsland.Socket.connection_information/1` value as native context.ssl. `deps/thousand_island/lib/thousand_island/transports/ssl.ex:210` delegates this API to OTP `:ssl.connection_information/1`.
2. `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex:1031-1053` copies that native ssl value into Exchange.ssl.
3. `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:747-750` validates captured pins and the actual pump before starting Session. `ManagedH2GroupAccounting.pump?/1` at836-841 requires exchange?/1; exchange?/1 at875 requires tls_metadata?/1.
4. Accounting964-1027 traverses TLS metadata through `finite_native?/3`: depth<=6, binaries<=65,536 including backing checks, unsigned integers, lists<=min(nodes,64), tuples<=8, maps<=8 and a fixed atom vocabulary. Its atom list974-1012 includes protocol/session_id/cipher fields but **excludes `:session_data`**, `:undefined`, `:named_curve` and general SSL option keys. It is not an arbitrary native term validator.
5. The OTP SSL constructor in the exact historical BEAM distribution, `.../erlang-28.5.0.7/lib/erlang/lib/ssl-11.6.0.6/src/ssl_gen_statem.erl:1945-1951`, unconditionally includes `{session_data, term_to_binary(Session)}` and appends `ssl_options_list(Opts)`. `ssl.erl:2799-2802` drops only values equal to undefined, so the binary session_data remains. The full field therefore cannot satisfy this atom vocabulary. This suffices to establish the static constructor mismatch independently of optional curve fields.
6. Failed startup validation returns an error through start_prepared_session -> dispatch_request's generic failure at HTTP368-369, which sends503. No downstream trust failure, upstream peer content defect or expected negative navigation contract is required to explain it.

**Limit:** The failed run did not emit raw Exchange.ssl, individual validator results, G/T timelines or an immediate post-failure owner/admission snapshot. Thus the exact dynamically taken503 branch has not been directly captured; the incompatibility is proven by source construction, while attribution to this particular request remains source-derived until the parent captures that boundary. Do not call this a runtime-confirmed validator trace.

## Historical environment provenance

`host-loaded-before.json` binds pid1324176 (matching host.log:2), OTP28, Elixir1.18.5, ERTS16.4.0.6, and `beam_executable.path` `/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7/lib/erlang/erts-16.4.0.6/bin/beam.smp`, SHA256 `7d7cc767b20c28e26fe93a13d23d5daf688cbd83ed60523a5bdedd9cb6ee02e6`; mapped_files agrees. This is the **historical failed browser run**, not a claim about the parent's current environment. Parent reports its newer fresh commands use `/nix/store/5y0714j8czhkjbmjb6l6m46n5w5fyr6q-erlang-28.5.0.5`; its ssl_gen_statem constructor also includes session_data at1936. The receipt does not separately inventory the loaded OTP SSL module's code path/hash, so the installed distribution source is constructor evidence, not a new loaded-module attestation.

HTTP package cohort is0.21.10. Current accounting source SHA256 `933b07a056d3a80baa6ce9ff9df1c84d7b4fc24c49dde1770d16f8855a6ee92f` and native Connection source `d74a1ea9b35e996db51da5b698390afd3cdc5c47eb2c499d35c3af69de46d3f2` match this qualification's source_before entries.

## Narrow next step, owned by parent

Capture one actual native TLS group request at the existing pre-start pump boundary, recording only bounded named metadata/validator results and admission/owner state. Preserve the positive navigation assertion. Confirm the failure selector before changing production code.

Then repair the **named native TLS metadata constructor/accounting contract** narrowly: support the actual leased metadata representation or construct a documented closed metadata representation at its source, preserving public interface semantics and all byte/shape limits. Do not solve this by permitting arbitrary atoms/terms, dropping TLS validation, treating503 as positive, switching downstream to cleartext or deleting the field to make the test pass. The precise representation choice belongs to the parent; this diagnosis makes no architecture/API change.

Recommended minimal compatibility direction: preserve the full existing Exchange.ssl value and its Plug behavior (`Exchange.ssl_data/1:405-412`, `Gaoxy.PlugAdapter.get_ssl_data/1:69`), and reconcile the group validator with the already named `:native_tls_lease` projection at Accounting1043/1050-1051. The source constructor owns that leased metadata; it is not a generic caller-supplied scalar tree. Establish its actual provenance and retained ownership/budget before substituting the named projection for accounting. Retain the original value in the real Exchange; do not set it to nil, filter it away before measuring ownership, or expand `finite_native?` to arbitrary terms. OTP's public full metadata includes session_data plus supported user SSL options (`ssl_gen_statem.erl:2158-2182`), potentially callback functions and compound values, so adding one missing atom will not define the complete supported source contract. If choosing a smaller producer representation instead, preserve full Plug ssl_data via the native transport source and explicitly verify the old behavior; a silent public metadata reduction is not a minimal compatibility fix.

Required repair verification: deterministic regression using an actual native TLS/h2 group Exchange and the real OTP metadata constructor, scoped accounting negatives still rejecting malformed/oversized data, then the unchanged three isolated Chrome cases with exact peer requests, full16,478,862 reserves, G/T/Service joins and source identity. This assignment ran none of those checks.

## Classification and preservation

- No peer fixture or Chrome assertion defect is established by this evidence. Health HEAD succeeds; application request never reaches peer.
- A fixture observability gap exists: the Python collector's exception path kills actors without requesting a final host evidence snapshot, leaving exact local503 attribution unrecorded. Add bounded diagnostic capture; do not substitute it for passing acceptance.
- Browser suite remains FAIL/zero completed cases. `/stream`, `/early`, wrong-ca and wrong-name cases were NOT RUN in this invocation.
- Preserve historical negative TLS `UNCONFIRMED_WITH_RETAINED_FAILURE`; this positive failure supplies no replacement cleanup result.
- No new repair-and-validation rounds were performed. Parent cumulative Sol counters were not supplied for this new bounded diagnosis and are unchanged; Astra2/2 remains exhausted. No escalation requested.
- Commands were read-only source/evidence inspections plus creation of these two requested `/tmp` reports. All commands finished; no runtime/browser/build/tests/Git/process-control actions. No repository files changed.

Memory was consulted only for scoped evidence/excluded upstream proof preferences; no prior diagnosis conclusion was used.
