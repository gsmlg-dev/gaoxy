# Issue B compiler follow-up evidence

Baseline: 581bea7d27b9d86c7dd0e63a1d49fcbca3adc3dd, codex/compiler-120.
Local profiles: Elixir 1.18.5 and downloaded Elixir 1.20.1 (OTP 28 build), both on OTP 28.5.0.5. Exact macOS Elixir 1.20.1 / OTP 29.0.2 is a parent-hosted gate, not established by local results.

Root cause: Elixir 1.20 warns when a bitstring match's size reads a previously bound variable without ^. Pin 24 application references and six references in two ordinary test files. Every changed variable is external to its match; literal sizes and other pattern bindings remain unchanged. Test, dependency, CI matrix, and warnings-as-errors contracts are preserved.

After those pins, strict compilation revealed seven previously hidden unreachable warning sites. Minimal repairs:

- HTTP3.Connection.transition/3 (baseline line358): every action/2 arm, including start_endpoint/enqueue failure handling, returns {:ok,state}; reduce directly with an explicit {:ok,next} match and retain stream/connection protocol failure clauses.
- HTTP3.Connection.settle_cancel/2 (baseline861): sole cleanup_stream/2 caller already dispatches operations:nil to cleanup_command/2; remove unreachable nil helper clause and retain that bypass.
- ManagedH2Client.write_body/3 (baseline148): HTTP.Stream.chunk/3 returns :ok or {:error,reason}; remove unreachable catch-all, preserving normalized errors and rescue/catch.
- ManagedH2Client.create_upload/1 (baseline236): HTTP.Stream.start_link/1 returns {:ok,pid}; replace single reachable case with a match, preserving unlink, rescue and catch behavior.
- HTTP.Session.activate_session/1 (baseline421): select/1 paths return {:ok,state,config}, {:await,state}, or {:error,reason,state}; remove impossible two-element error arm.
- HTTP.Session.group_open_reason/1 (baseline693): group_result/4 handles atom :cleanup_unconfirmed before invoking helper; remove unreachable helper atom arm, preserve tuple normalization.
- ManagedH2GroupAccounting.scalar?/1 (baseline398): both callers short-circuit is_pid/is_reference before calling; remove unreachable non-scalar fallback, keep the PID/reference guard and ETF limit.

Initial local strict baseline fails15 external-size warnings in gaoxy_http. Initial pin implementation exposes the two HTTP3 warnings; repair1 fixes those and exposes the five proxy warnings; repair2 fixes those and passes strict compilation. Cumulative Sol repair rounds:2. Astra rounds:0. Initial implementation is not a repair. No assertions, APIs, dependency stack, or compile settings changed.

Validation: strict --force --warnings-as-errors; exact141-case scripts/check-repairs.py unit; expanded172-case existing ordinary WebSocket frame/H3 parser/H3 connection/managed H2 client/accounting/session/Plug body network focused set. These focused cases do not run the excluded specialist suites. See final120-checks.json and attempt2-elixir118/verification.json for exact commands, source/file hashes, exits and logs.

The noncanonical extra1.20 formatter check fails unchanged HTTP2 connection line309 indentation; extracting the original baseline file reproduces the identical difference (attempt2-elixir120/baseline-120-format.json). CI's canonical formatter remains1.18. No formatting churn is applied.

The first focused run fails at H2 Python peer setup (:enoent), before peer exchange; focused118-missing-peer.log retains it. Provisioning the existing h2-requirements.txt under owned .audit/h2peer resolves setup. Historical earlier1.18 logs overwritten by the initial driver are explicitly marked NOT_RETAINED_OVERWRITTEN in historical-log-preservation.json; retained renamed1.20 failure logs have matching digests. Current final checks use immutable attempt directories. Archived evidence and unselected specialist/probe source files are untouched.
