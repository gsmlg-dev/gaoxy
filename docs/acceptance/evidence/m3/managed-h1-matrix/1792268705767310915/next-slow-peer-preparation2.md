# Task6 slow-peer preparation2 source recheck

**READY_SOURCE_RECHECK** — static preparation only. No implementation, adoption or runtime acceptance.

All25 explicitly named preparation1 source pins were checked against current actual files and candidate4:25/25 match candidate4;22 are unchanged from preparation1 and3 changed. A final second recheck found all25 stable. Candidate4 manifest SHA256: `05269802d86ec0f9742b5d2e725168fccdfbd6cdb98fa0d9f07e73aa3f745913`. Parent-verified entry remains `1426657e65d726629d618dcf03880df718375dd1`; no Git verification or next/postcommit HEAD claim is made.

Changed historical pins:

- `apps/gaoxy_proxy/test/support/managed_h1_matrix_fixture.exs`: `243cc3df9d8b20219e429cf8d23733685800aa23b5a35d2b113fcec5e5d84b66` → `94adbb8390513cdbc2a2a4e9d751b9db3a404ff82053ad104089782296aa628e` (29135 bytes).
- `integration/upstream_transport/run.py`: `f30ac0fda676f86cd81d52a878e2d21222884e757504f849d42aca05a852cac2` → `ca5ba4136a67eee50d25aeb5fee4cdaf8494e682989e778e91e059997feda7ca` (29504 bytes).
- `integration/upstream_transport/README.md`: `3f55f469d03a26435a634bf34df27d2b7aa4bad31fc946201779b02f3db5956a` → `96a9d02609ae3e847720b36093a2372f449badf46241c0f664e15db7801526c8` (3139 bytes).

The previous runner custody mismatch is resolved factually: current `run.py` is `ca5ba4136a67eee50d25aeb5fee4cdaf8494e682989e778e91e059997feda7ca`, matches candidate4 and was statically reread. This does not adopt the successor baseline or qualify execution.

No technical profile-plan correction is needed. The repaired H1 adapter is separate from the unchanged ManagedH2Client route used by the proposed h2c/TLS-H2 profile. The H1 matrix fixture now permits one native-H2 stream under64MiB, but the proposed three-stream profile already uses the unchanged F/G fixtures and their512MiB/1GiB service capacities. Do not transplant that single-stream matrix configuration. Runner cleanup/deadline changes and its synchronized README affect the preceding H1 matrix; the standalone slow-peer registry remains open.

The bounded handoff correction is to use these refreshed pins at actual successor adoption, replace stale custody/progress wording only from parent final evidence, and record/recheck the actual postcommit HEAD then. Current first2 PASS16/0 is parent-reported progress only; predecessor closure is not independently established here.

The existing four-case design, original deadlines, simultaneous hold/healthy-sibling oracles, capacities, finite queue observations and open H1/standalone/browser boundaries remain proposed and unchanged. No dismissed#97 equivalent is introduced. Task6/Task5/M3 remain OPEN.

Current25 pins:

| Named source | Bytes | Current SHA256 |
| --- | ---: | --- |
| `docs/plans/m3-upstream-transport.md` | 71602 | `7daf59850a33139e7b7fae21453a7b5e5b782debd3e6352abd5d8c616874c6fd` |
| `apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs` | 37573 | `2b53e3848a286147ff1b00ac10b5364238b070396d30cb729fcd12300f17dbc8` |
| `apps/gaoxy_proxy/test/managed_h2_fixed_write_lifecycle_test.exs` | 19430 | `d2887a75d72e33ea247bac51ad0466263c27024e0ddeaa30a701a4c4900ac7d4` |
| `apps/gaoxy_proxy/test/managed_h2_group_lifecycle_test.exs` | 15649 | `92ec2f5ecad11f03a7028d07e8f1191144f04384a211fa83076294cdd57bd21c` |
| `apps/gaoxy_proxy/test/managed_h2_group_endpoint_test.exs` | 25302 | `68ab3678fb6945d7a7cc18eb13b111572d8fb6356014d75a98c5731c79179ced` |
| `apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs` | 34161 | `318c839b3d6acfbcd515cd8b744e8f85c8660f97ee411322c4c53a3f820656bb` |
| `apps/gaoxy_proxy/test/support/managed_h1_matrix_fixture.exs` | 29135 | `94adbb8390513cdbc2a2a4e9d751b9db3a404ff82053ad104089782296aa628e` |
| `integration/upstream_transport/run.py` | 29504 | `ca5ba4136a67eee50d25aeb5fee4cdaf8494e682989e778e91e059997feda7ca` |
| `integration/upstream_transport/fixture.exs` | 1166 | `7f1ee353535d95b3c55830b216b6aff1089914fdf85810bdf41895f8174cacf0` |
| `integration/upstream_transport/README.md` | 3139 | `96a9d02609ae3e847720b36093a2372f449badf46241c0f664e15db7801526c8` |
| `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py` | 53205 | `d0444029bb6eae58699f83c07a60e7ee8aedc17fd55848666a4191fe3bda6083` |
| `apps/gaoxy_proxy/test/support/managed_h2_group_fixture.exs` | 14221 | `4d5f70dcee198409fb481947ddfb24e9d65dc65b3b41c0a58e8f6627778b1c53` |
| `apps/gaoxy_proxy/test/http_proxy_runtime_test.exs` | 20100 | `f9024c3d92edf7ee02dd71b1aa4f9430305c578e1d1c5772cc93e89398b3b32d` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex` | 54507 | `877bb6e4c891ee3f8c93a425a67b10f390137fcead2eeb52ccd9b78d9b2b1f51` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex` | 17995 | `e8c60d1d5a67f3b9737478149ac6e28b8e9ddf778289a2fac6035054379e7313` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex` | 68221 | `8a041a6bc217ef5ec626dc9e4efc2ec495db3a668912214420ad01bd4d449eac` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex` | 40925 | `dd04efd4b255f7b03a4f68d23ac6cabcca3b9be0fb1a9a431cd24df960b11c31` |
| `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex` | 44627 | `586db509de60712be04f5c7290adfbc6db31300a592344d54cf28e3872d24c52` |
| `apps/gaoxy_http/lib/gaoxy/http/http2/limits.ex` | 2241 | `f8d922deee2f7a45ecf3070498a3f82a50af47b5fbe0007545ab11bf3cf831ab` |
| `apps/gaoxy_http/lib/gaoxy/http/http2/writer.ex` | 2280 | `6af7f110ce8a39a834f40409b08f7626ca057230ee66cab0b65304584cec562a` |
| `apps/gaoxy_http/lib/gaoxy/http/connection.ex` | 11477 | `1b7e3caf6f99352f622f3243dbf3c1742a039182779af06c0ae5fe94eaa708a4` |
| `apps/gaoxy_http/lib/gaoxy/http/exchange.ex` | 14710 | `75b752c358d861be75446b99fef948f023082e6de177840bef35f99ce20776d0` |
| `apps/gaoxy_http/lib/gaoxy/http/http2/stream.ex` | 2344 | `2276f9bfb14053ff853a13b564397ba82e5ad685a1451619dde89e398980a581` |
| `apps/gaoxy_http/lib/gaoxy/http/options.ex` | 2528 | `3c1a68f1bf58d4f205958b82230e6d28665b719c7b64923593992decdcafdb90` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports/options.ex` | 2381 | `c3a7b5b56f7fc0f6bf843de2600920316bd525577f69cdd69214f80626dd9a5e` |

Extra adapter pin, outside the25 count: `apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex` = `b0fc774be009a2fea62ceee3a7fd7e8a35be7096ebaa249713678c9a1bdfe6c9`, matching candidate4.

Runtime/tests/Mix/browser/Git/format: **NOT RUN**. No historical runtime receipts audited, no repository edits, no architecture reinvestigation or delegation. Parent-reported Sol3/Astra2/2 exhausted preserved, repair deltas0. Only the two assigned `/tmp` reports written. One normal no-match adapter keyword search was followed by scoped relevant source reads; no protected/private access or other tooling incident. All commands finished; no background process started. Ownership returned to root.
