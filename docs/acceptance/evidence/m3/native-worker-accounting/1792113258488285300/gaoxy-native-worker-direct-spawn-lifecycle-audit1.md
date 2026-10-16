# Native H2 direct-spawn lifecycle source audit 1

Status: DONE. Verdict: conditionally feasible with required custody design. This completes only the bounded source audit; it does not approve a spawn_monitor-only implementation or establish runtime acceptance.

Task: `checked_capture_full_code/native-worker-direct-spawn-lifecycle-audit1` (direct assignment).
Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`.
Branch: `codex/m3-h1-resource-foundation`; clean reviewed baseline `58307a7084298db309a93697b9102b2cc4c87eda`.

Only these two /tmp reports are audit-owned. No repository source, tests, design, accounting arithmetic, Git state or dependency was modified.

## Findings

### L1 — required_design_condition

spawn_monitor-only and bootstrap-only gate monitoring cannot terminate an endpoint-blocked child when Admission is killed. Use atomic linked+monitored gate-child creation or an equivalently evidenced fatal-custody mechanism. A later child-side link has a startup gap.

Source: `apps/gaoxy_http/lib/gaoxy/http/http2/stream.ex:14-62`; `apps/gaoxy/lib/gaoxy/admission.ex:419-424`.

### L2 — required_design_condition

Admission must trap child exits if linked to its children; isolate a worker crash, retain monitor-driven lease refund, and explicitly preserve non-child linked lifecycle policy. Actual OTP parent exits are intercepted before Admission.handle_info. Actual-parent normal exit now terminates when trapped; document and verify that behavior. scope.service_pid is not automatically OTP parent.

Source: `/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7/lib/erlang/lib/stdlib-7.3.0.3/src/gen_server.erl:2373-2386`; `apps/gaoxy/lib/gaoxy/admission.ex:47-61`; `apps/gaoxy/lib/gaoxy/admission.ex:380-424`; `apps/gaoxy/lib/gaoxy/service.ex:30-38`.

### L3 — required_design_condition

Track and charge every pending and active known PID before dispatch, preserve original deadline, and retain custody through DOWN. Original-owner link kills on abnormal exit; monitor/explicit gate owner cleanup is needed for normal exit and startup handoff races. Normal gate termination must kill pending children as well as leased active workers.

Source: `apps/gaoxy_http/lib/gaoxy/http/http2/stream.ex:6-12`; `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex:538-565`; `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex:1034-1080`; `apps/gaoxy/lib/gaoxy/admission.ex:290-298`; `apps/gaoxy/lib/gaoxy/admission.ex:367-424`.

### L4 — scope_boundary

Production Service gate-failure cleanup forces native backend/owner teardown, but does not establish isolated gate custody. Keep Lifecycle.resources ownership filtering intact. Current Task streams inherit global Task supervisor ancestry, so losing service ancestry is not established as a new regression; raw-child blanket inclusion would violate existing isolation tests.

Source: `apps/gaoxy/lib/gaoxy/service.ex:441-469`; `apps/gaoxy/lib/gaoxy/service.ex:662-678`; `apps/gaoxy/lib/gaoxy/lifecycle.ex:64-124`; `apps/gaoxy/test/lifecycle_ownership_test.exs:51-102`; `/nix/store/jc6g5l4a2qg89s3mng0p18r9dbijc28d-elixir-1.18.5/lib/elixir/lib/elixir/lib/dynamic_supervisor.ex:757-769`; `/nix/store/jc6g5l4a2qg89s3mng0p18r9dbijc28d-elixir-1.18.5/lib/elixir/lib/elixir/lib/task/supervised.ex:9-10,65-80`; `apps/gaoxy_http/lib/gaoxy/http/application.ex:5-6`.

### L5 — compatibility_boundary

Source search found no stream Task-supervisor membership, Task handle, or callers-metadata consumer in searched Gaoxy core/HTTP/proxy lib/test scope. Writer Task.Supervisor creation and explicit writer membership assertion remain required and unchanged. Keep H2 worker/token/lease identity checks, RST cancellation, DOWN handling, close callbacks, single-deadline drain and retained write/cleanup accounting.

Source: `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex:24-34,1034-1136,1179-1188,1231-1245,1280-1332,1362-1371`; `apps/gaoxy_http/lib/gaoxy/http/connection.ex:352-373`; `deps/thousand_island/lib/thousand_island/handler.ex:455-508`; `apps/gaoxy_http/test/http2_network_test.exs:361-371,843-853,1098-1111,1475-1484`.

## Interpretation of gate and owner shutdown

The present native stream links and monitors its native owner before acquiring its lease. Its monitor receive is only effective before endpoint invocation; an endpoint blocked inside module.call cannot process owner or gate DOWN messages. Abnormal owner exit propagates through the link; normal exit does not. Normal native owner close/error/shutdown/timeout callbacks explicitly kill known stream PIDs, and ThousandIsland generated terminate routes all initialized-socket termination cases through those callbacks. A hard-killed native owner skips terminate but kills an untrapped linked stream.

The production Service directly starts the gate linked to itself. Gate EXIT causes force/drain or Service termination and forced backend cleanup, so the production tree offers a second shutdown route. It is insufficient as the sole justification for a new generic gate-created child's lifecycle: isolated core gates can have no Service, and owner death can occur during child handoff before native state records its PID. Gate custody must cover pending as well as running children independently of the endpoint reaching a receive.

Atomic linked+monitored spawn lets hard gate death propagate as a fatal signal to an untrapped child even during endpoint execution. Enabling Admission trap_exit prevents child failure from cascading through the shared gate and siblings. OTP 28's installed gen_server decode_msg explicitly terminates on EXIT from its recorded parent before dispatching module handle_info, preserving parent/service abnormal shutdown. Actual parent normal exit also becomes a termination path under trapping and must be documented/verified. An arbitrary scope service_pid or arbitrary linked PID is not necessarily the actual OTP parent; do not silently swallow all newly trapped non-child exits. Existing normal terminate must explicitly kill every tracked child because a normal gate link signal alone does not terminate an untrapped child.

## Compatibility and required later verification

Keep writer creation under Gaoxy.HTTP.Tasks. The existing writer_for helper checks writer supervisor membership; source search found no equivalent downstream stream membership assertion, no Gaoxy $callers reads, and no Task handle operation on these stream PIDs. $ancestors is nevertheless operational for core ownership traversal. Current Task.Supervised source receives ancestry inside the global Task supervisor; these streams do not thereby inherit Service ancestry. Do not clone metadata speculatively or broaden raw traversal to compensate.

Implementation acceptance should deterministically cover: gate kill and normal stop during blocked endpoint; pending-child gate death; owner death before handoff and normal owner teardown; single worker crash preserving gate/sibling; cancellation/deadline cleanup retaining charge until DOWN; genuine OTP parent abnormal shutdown with trap_exit; unchanged writer supervision, H2 RST/GOAWAY and cleanup/write accounting. These are later implementation checks, not tests run by this audit.

## Evidence and limits

Source reads and scoped reference searches passed. Installed immutable OTP28 gen_server.erl parent EXIT source and Elixir1.18.5 Task.Supervised/DynamicSupervisor ancestry construction were read directly. Exact source hashes are recorded in the JSON companion. No project runtime, builds, tests, network requests or Git mutations were run. Thus runtime test count is zero by assignment, NOT RUN; there is no runtime PASS claim.

Initial status was clean. Final tracked diff remains empty. Concurrent untracked `docs/acceptance/evidence/m3/native-worker-accounting/` appeared while the parent/designer was working; it was not inspected or touched by this audit. All own commands completed; no command sessions remain.

Counters preserved: group Sol30 / root Sol35 / Astra2 of2; this audit adds0. No Astra escalation. Designer owns final custody contract; no user decision needed for this report.
