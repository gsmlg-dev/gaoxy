# Independent specification and code review: B/C and integration gate

Task: review_compiler_ci. Assignment: direct independent review, read-only implementation scope. Verdict: PASS for specification/source review and code quality, no actionable findings. This is not final release qualification.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/standalone-ci-followup`.
Reviewed baseline: `581bea7d27b9d86c7dd0e63a1d49fcbca3adc3dd`.
Reviewed HEAD: `c965ee775d0678308d488077612a0bb6061fbe8b`, plus imported B changes and the one-line recovery manifest addition. The working tree contains other task-owned concurrent A changes; this review made no implementation edits. A lifecycle design/code/regression review is separately assigned.

## Specification review

B: PASS for implemented correction. All 20 B file SHA256 values match `.audit/standalone-followup/compiler-import.json`. The diff pins 24 application size references and six ordinary-test references. Each was inspected with its surrounding bindings: Exchange (3), FramedResponse (1), HTTP1 Body (1), HTTP1 Parser (1), HTTP2 Connection (4), HTTP2 Frame (1), RendererBounds (1), WebSocket (1), WebSocket Frame (2), HTTP3 Connection (3), HTTP3 Protocol (1), HTTP3SessionClient (1), ManagedH2Client (1), ManagedH2Envelope (1), ManagedH2Preparation (1), StreamRelay (1). Each size variable is bound before the match, including the function-argument `credit` and the `bytes` inside `byte_size(^bytes) - 1`. PlugBodyNetworkTest has one outer response-length binding; ProtocolTest has four comprehension split bindings and one preceding bytes binding. No earlier-in-the-same-pattern variable binding, literal size, assertion, or deadline is altered.

The seven subsequently exposed compiler-warning sites are in scope and preserve reachable behavior; detailed code review follows. No dependencies, supported matrix entries, or warnings policy change. Existing `mix compile --warnings-as-errors` remains in both strict CI profile jobs. The ordinary unit matrix remains established separately; successful unit results are not substituted for strict compilation.

C: PASS for implementation and retained local peer evidence. The only workflow difference adds `uv venv .venv --python 3.12` and `uv pip install --python .venv/bin/python -r ../http3/requirements.txt` before the unchanged consumer commands. From `integration/quic_consumer`, both the interpreter path and sibling requirements path resolve correctly. The new venv is outside the cached deps/build paths, and uv can provision the requested Python on a clean runner. The reused requirement pins aioquic==1.2.0. Consumer tests and peer.py are byte-identical to baseline; CA loading, hostname/ALPN rejection, existing assertions and finite deadlines remain intact.

Integration manifest: PASS. Static AST comparison confirms every baseline file/count remains present in its original suite. The only addition is `apps/gaoxy_server/test/standalone_recovery_test.exs` with two cases in protocol: unit 141, protocol 19, total 160 (previously 158). Existing per-file exact counts and no-failure/no-exclusion/no-skip checks are unchanged. Foundation integration and source-bound prepublication release already execute `python3 scripts/check-repairs.py all`, so both include the recovery regression. No specialist suite or new protocol feature is introduced. Actual final-source 160-case execution remains the parent's qualification gate.

## Code-quality review of the seven warning repairs

1. HTTP3.Connection.transition/3: all action/2 arms return {:ok,state}. Both enqueue/3 overflow and start_endpoint/3 register/start/bind failure branches convert failures into stream cancellation and {:ok,state}. A direct reduce and explicit {:ok,next} match preserve each action and work_deadline call. The separate stream/connection protocol error clauses remain.
2. HTTP3.Connection.settle_cancel/2: its only caller is cleanup_stream/2; the preceding operations:nil cleanup_stream clause already routes directly to cleanup_command/2. Removing the unreachable nil helper does not remove cancellation settlement from the operations-backed path.
3. ManagedH2Client.write_body/3: the locked http_fetch 0.21.10 implementation of public HTTP.Stream.chunk/3 returns only :ok or {:error,reason}; inspection of its receive/timeout arms confirms the spec. Existing normalization and rescue/catch remain. Even an unexpected future return still reaches the existing rescue through CaseClauseError.
4. ManagedH2Client.create_upload/1: public HTTP.Stream.start_link/1 returns {:ok,pid}, implemented through Task.start_link for these arguments. Explicit matching preserves unlink and the returned PID. Existing rescue/catch still map an unexpected result or exception to {:error,:unavailable}; none of the public dependency APIs changed.
5. HTTP.Session.activate_session/1: traced select/1, grouped selection, select_transport/2 and checkout_transport/4. Successful/await branches carry state, and every returned error is a three-tuple carrying state. The removed two-tuple error arm has no reachable producer.
6. HTTP.Session.group_open_reason/1: the earlier group_result clause handles {:error,:cleanup_unconfirmed} directly. The remaining callers pass the cleanup tuple or an error reason after that clause has excluded the bare atom. Tuple normalization and finite_reason remain.
7. ManagedH2GroupAccounting.scalar?/1: its two callers short-circuit with is_pid(value) and is_reference(value) before invoking it. The guarded implementation and external-size bound remain; the non-scalar fallback cannot be reached through these callers.

No requested API, resource-accounting, protocol, warning-suppression, or dependency workaround change was found in B/C.

## Evidence actually audited

Read the complete task attachment, AGENTS.md, current plan, prior repair acceptance, B notes/summary/final receipts, source diffs and dependency implementation. Recomputed SHA256 of all imported B files. Recomputed raw-log digests for all seven immutable final B checks in sibling `compiler-120/.audit/standalone-followup/compiler/final120-checks.json` and `attempt2-elixir118/verification.json`; all match. Receipts show strict `compile --force --warnings-as-errors` exits 0 on local Elixir1.18.5 and Elixir1.20.1, both OTP28.5.0.5; each unit gate executes 141 without failures/exclusions/skips; each focused set executes 172 without failures; canonical1.18 formatting exits0. The retained initial1.20 baseline log contains external-size warnings and strict compilation failure; retained intermediate type-warning logs identify the repaired sites.

C: recomputed four log hashes for clean baseline, venv creation, pinned dependency installation and peer-green receipts; all match. Baseline executes4/1 and fails at System.cmd :enoent before peer launch. Green executes4/0 and contains actual independent peer PASS outputs, including validating hostname localhost, wrong CA, wrong hostname and unsupported ALPN rejection, flow control/FIN, directional controls, isolation and rebind. These are inspected existing receipts, not reviewer reruns.

Fresh reviewer commands were read-only source/AST/hash/log audits and `git diff --check` (exit0). No shared Mix build, dependency mutation, network suite, commit or publication command was run. All reviewer commands have finished. Historical overwritten diagnostic logs are explicitly marked NOT_RETAINED_OVERWRITTEN; this review does not reconstruct them or claim they were retained.

## Remaining qualification limits

- Required exact macOS Elixir1.20.1/OTP29.0.2 strict compile and unit gate: NOT RUN on the final source at this review. The local1.20/OTP28 evidence is supplemental.
- Fresh final integrated/source-frozen compile, 160-case repair gate, relevant standalone regressions, optional-QUIC hosted job and publication qualification remain parent-owned pending work. This review authorizes no claim that those pending gates passed.
- Extra1.20 formatter difference is retained and reproduced on the unchanged baseline; canonical1.18 remains the supported formatting gate.
- No production, deployment or excluded specialist qualification is inferred.

Cumulative received Sol repair rounds: B2, Astra0; this independent review adds zero repair rounds and no code changes. astra_gate: not applicable. Decisions needed: none for the reviewed changes.

## Reviewed file SHA256 values

- `apps/gaoxy_http/lib/gaoxy/http/exchange.ex`: `908ee59eed020969a18e06a56f67af6f8f5aee35fa7ab00cbf1934183546eef4`
- `apps/gaoxy_http/lib/gaoxy/http/framed_response.ex`: `bf33f64c7576f53aa56a3a03149c71187ac6c0ea1271221d8fce56e1f5261eaa`
- `apps/gaoxy_http/lib/gaoxy/http/http1/body.ex`: `a44d9776dd4f729bde8550881d8e737d2d9239b6e33b61e84e942d2023f4d657`
- `apps/gaoxy_http/lib/gaoxy/http/http1/parser.ex`: `2aeefdd5f82f7ff0c88c9d5509be300035cf7e0bbfe77446e6b8ceb6d117deb0`
- `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex`: `e5e15473b9f6e190e6f6fa82994eb51b22af24eb831068ce03e81cf762086763`
- `apps/gaoxy_http/lib/gaoxy/http/http2/frame.ex`: `dbaef598b6cfccef096fde18c7d66e6cfc194d31168fafb99f60bda32f6510e0`
- `apps/gaoxy_http/lib/gaoxy/http/renderer_bounds.ex`: `e3d84096189129febeeed5f80ba945629db5583d2135524fe9cfedbe0f043d40`
- `apps/gaoxy_http/lib/gaoxy/http/websocket.ex`: `4f6b37dded8f2667e0d593a866ebb759fd2485de90bf0afbb987a32d9840a2cc`
- `apps/gaoxy_http/lib/gaoxy/http/websocket/frame.ex`: `020afea752845e6dcd05352dab36556cb60628f6a1df4730d19fafe1fbb1a599`
- `apps/gaoxy_http/test/plug_body_network_test.exs`: `27ba1f70cef7549a3b208e421c09cdada669accd5ad007cf4e50a28c8dd20625`
- `apps/gaoxy_http3/lib/gaoxy/http/http3/connection.ex`: `a90fdcbe4282159a37f302fd4d4af9790399411c87f405acbfa3c90bb69558d1`
- `apps/gaoxy_http3/lib/gaoxy/http/http3/protocol.ex`: `324e0c6b9f7a6a655860d170ae3bedd31a8563a27da5ebc9216b21c69ed93862`
- `apps/gaoxy_http3/test/protocol_test.exs`: `a8ec2caa9a3e809e9051e5f9e94d52374865e3487a06c9d53925632b864bb1e1`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex`: `0ddb0781079e5868ec98a5644e15d05bb2a25d83df254cafb956ef71c81f5998`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/http3_session_client.ex`: `592a6fde85d737d3f7c025a82d29e296bba3e53823a6af7c6eeae39b0982ccf1`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex`: `36c3719cec5dc968479fdf4622b0d14c2bc80f7c1ae70a39831864de25a0810c`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex`: `9e315cefb000202429e792a0371e3ea5566fc41330ce585b9ec7e79036b707d2`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_accounting.ex`: `e6247bee6290836f842a4db99ad41ea75d716758aa29c56877ef65e10d92938c`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_preparation.ex`: `64fb9a1e13c437bd6b38de34add283d6ddf72a583db2c4212b2de16615f0abe5`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/stream_relay.ex`: `d1b65b1bd10a209052137c10672657a4702150976cdc7f22b1b9be5a335aa2c2`
- `.github/workflows/portable.yml`: `9981cf0888ae3633fe5b40e99f05c32a8f99c2d97af847d6bd49380ba03b5fb2`
- `.github/workflows/ci.yml`: `177b657d5717150820ece2315a3ef97f1270dd5151ef340650662b2e57400f1f`
- `.github/workflows/release.yml`: `5944fbbe54dadb0bb21d18468ff9b6e454276d7841b8bc65bcd7094e77c7ab0b`
- `.github/workflows/test.yml`: `f5abf57d1c130447afe65359411d72a861a67f33c34c4a51e15c3f36a5c1abac`
- `scripts/check-repairs.py`: `072f3d24312c67fdbaeb8d16366312610af41e150ea429fd205be9890b5c55c9`
- `scripts/check-tests.py`: `03387fb8482972def834ceff0ef686fe5e5a4449dda02c20cb3317ebafd716a9`
- `integration/quic_consumer/test/quic_test.exs`: `9a9c7020981eae2cb85e117c4e02e963c4d6cc29e4a83cf74252627e1bf4b57c`
- `integration/quic_consumer/peer.py`: `b4f9bc012795f19251f8f1ab5dd247b7a2e9874976f66d8c9cd9ff233d168688`
- `integration/http3/requirements.txt`: `baa71ded2594f376d2ee2772a724b5b3d8be79e37a3b76392a94130e2069a3fb`
- `mix.lock`: `9f04f56f7b3389e217803614537133cda21a6bc176d2499fdcee6128292f0777`
- `apps/gaoxy_proxy/mix.exs`: `a4af3621ab2a9d4f16fa439dd78fffa6bfe42ce8bad378569609be12815729fa`
- `deps/http_fetch/lib/http/stream.ex`: `d67a6ba36851dc255376ba93131e84dd003c9da2497fc0bb6e7d6c721c4be77b`
