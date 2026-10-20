# Independent hosted compiler-baseline review

Task: review_compiler_ci / hosted baseline supplement. Direct read-only review. DONE: PASS for baseline evidence and provenance review; recorded product baseline remains FAIL as expected. No actionable source finding. Repository/worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/standalone-ci-followup`; current review HEAD `c965ee775d0678308d488077612a0bb6061fbe8b`, task baseline `581bea7d27b9d86c7dd0e63a1d49fcbca3adc3dd`. Concurrent uncommitted implementation is preserved.

## Exact hosted baseline

Metadata identifies run [39452105268](https://github.com/gsmlg-dev/gaoxy/actions/runs/39452105268), attempt2, failed job [118781656795](https://github.com/gsmlg-dev/gaoxy/actions/runs/39452105268/job/118781656795), `build (macos-15-intel, 1.20.1, 29.0.2)`. Job started2026-10-20T17:34:15Z and completed2026-10-20T17:41:36Z. Run conclusion is failure. The raw job log independently confirms the source and actual installed runtime:

- Published v0.5.3 source `62a325fe5153c2438b3ea717cd7fdf4d82d7b871`, rather than the current follow-up source. Log lines105-111 show fetch/rev-parse; lines254-255 show final checkout `git log -1 --format=%H`.
- macOS15.7.9, build24G830, macos-15 Intel runner (lines10-18).
- setup-beam requests Elixir1.20.1/OTP29.0.2 (lines258-259), installs OTP-29.0.2 for amd64/macOS15 (line271), and prints Erlang/OTP29 / ERTS17.0.2 and Elixir1.20.1 compiled with OTP29 (lines284-286).
- Locked dependency acquisition succeeds. The actual command `mix compile --warnings-as-errors` fails, exit1 (lines842-843), rather than being inferred from a unit-job result.

The raw log contains15 external-bitstring-size warnings in the repository-owned gaoxy_http application (lines737-840): Exchange.send_continue/2, decode_body/3, take_chunk/4; FramedResponse.take/3; HTTP1.Body.line/4; HTTP1.Parser.parse_head/2; HTTP2.Connection.parse/2, deliver/2 (two), schedule_data/1; HTTP2.Frame.decode/2; RendererBounds.frames/7; WebSocket.send_wire/2; WebSocket.Frame.decode/2 and unmask/2. They explicitly state that the size variable was defined outside the match and must use the pin operator. This freshly reproduces IssueB on the exact reported profile, including the new Continue implementation. It does not certify the repaired source, nor exhaust later warnings hidden because compilation stops at gaoxy_http.

## Separate dependency warning

Lines637-646 attribute `socket_resource/1` to the `http_core` compilation phase, path `lib/http/request_lifecycle.ex:200:8`, module `HTTP.RequestLifecycle`, matching `deps/http_core/lib/http/request_lifecycle.ex`. The package is locked at http_core0.21.10; both its Mix metadata and Hex metadata identify source `https://github.com/gsmlg-dev/http_fetch`. This warning is dependency-owned, not a Gaoxy callsite or one of the compiler repairs.

The log emits `Generated http_core app` immediately after this warning (line646), then compiles subsequent dependency and umbrella applications. The strict command reaches gaoxy_http nearly3.5minutes later and fails after its15 external-size warnings. Therefore the dependency warning is demonstrably nonfatal under the exact hosted baseline's unchanged root invocation. It is not evidence of a separate strict-compile blocker requiring a local workaround or dependency-stack upgrade. Inspected the local dependency's preceding connection_resources({:cancellable_ssl,...}) clause, which already dispatches that representation before the fallback invokes socket_resource; the reported branch is indeed unreachable on that path. No runtime dependency defect is established by this compiler warning.

This conclusion does not claim that final repaired-source macOS strict compilation has executed: that remains required separately. Dependency source, Mix lock, compiler flags, CI matrix and test/release workflows have no diff from baseline. No source modification, workaround, suppression, upstream dependency edit or issue mutation was performed by this read-only review.

## Final qualification/source prerequisite sanity check

Read `.audit/standalone-followup/qualify.py` and the unchanged release workflow. The local harness binds each phase to HEAD/version/lock hash; rejects tracked source changes before/after; writes new phase directories; records argv/cwd/exit/log hash; enforces finite command timeouts and fails nonzero exits. Its checks phase calls the full exact-count repair manifest, which currently preserves158 cases plus2 recovery cases. Standalone, optionalQUIC, public API consumers, browser, production build/packages and smoke phases are separate and retain their results. Exact macOS validation still comes from the hosted matrix, not this Linux harness.

Parent prerequisites remain: commit all task-owned new source/tests and the version before running final-source qualification; the harness's tracked-diff guard alone cannot prove absence of relevant untracked files. Recheck version/tag/package availability at publication time; the existing0.5.4 preflight is historical and does not reserve that version. The workflow requires a full expected_sha, validates the actual checkout and already-committed own-app versions, rejects an existing tag, runs all repair cases before publication and rechecks remote branch/source before irreversible upload. These checks were inspected, not executed by this reviewer.

No builds, tests, publication, or implementation writes were run. All reviewer commands completed; an rg command with no matches returned1 and was not a product/build failure. Only this new review artifact was created. Received repair counters remain B Sol2/Astra0; this review adds zero repair rounds. astra_gate: not applicable. No design decision needed. Remaining risk: final repaired-source hosted/profile and publication gates are not established by this failed baseline.

## Reviewed artifact SHA256

- `.audit/standalone-followup/compiler-baseline-hosted/run-attempt2-final.json`: `ad065e9463cb7d6cab250f658772aa08ba5027b294e134eb8a09379ecd17f488`
- `.audit/standalone-followup/compiler-baseline-hosted/macos-attempt2-final.log`: `7170df640dbd95854b0834c5d9a5d9d0b83cdc4ecc949e8d9af7804330e75512`
- `.audit/standalone-followup/qualify.py`: `7acd38c8bb7b1dc4f47f49ab2919f76db437d4619933fe6803d0b3f190c6a19c`
- `.github/workflows/release.yml`: `5944fbbe54dadb0bb21d18468ff9b6e454276d7841b8bc65bcd7094e77c7ab0b`
- `deps/http_core/lib/http/request_lifecycle.ex`: `0231b77a39529e54e1e4d25fa95981fec31dca8e2be566b2d513fb22a45a974c`
- `deps/http_core/hex_metadata.config`: `dbaa7836dc7ccbc50aab9dbb1723a893b1c8326d05091a21df5ebdc6650be2fc`
