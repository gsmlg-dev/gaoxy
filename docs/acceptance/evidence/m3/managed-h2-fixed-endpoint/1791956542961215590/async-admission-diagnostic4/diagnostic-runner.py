"""EXPERIMENT ONLY: asynchronous own-Gaoxy Admission evidence observer."""
from pathlib import Path
import hashlib
import inspect
import json
import sys
import time
import traceback

ROOT = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
sys.path.insert(0, str(ROOT / 'integration/http_fetch_contract'))
import managed_h2_fixed_qualification as q

E = ROOT / 'docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/async-admission-diagnostic4'
E.mkdir(exist_ok=False)
canonical_host = q.HOST
canonical_cohort = inspect.getsource(q.concurrent_cohort)

HELPERS = r'''
  defp admission_observer(host, gate, credits) do
    host_ref = Process.monitor(host)
    gate_ref = Process.monitor(gate)
    send(host, {:admission_observer_ready, self()})
    admission_observer_loop(%{host: host, host_ref: host_ref, gate: gate,
      gate_ref: gate_ref, credits: credits, seen: MapSet.new(), count: 0,
      received: 0, high_water: 0, failure: nil})
  end
  defp observer_failure(state, reason) do
    if state.failure == nil do
      emit(%{event: "diagnostic_admission_observer_failure", observer: inspect(self()),
        gate: inspect(state.gate), reason: inspect(reason, limit: :infinity)})
      send(state.host, {:admission_observer_failure, self(), reason})
    end
    %{state | failure: state.failure || reason}
  end
  defp observer_summary(state) do
    %{observer: inspect(self()), gate: inspect(state.gate), received_raw: state.received,
      distinct: state.count, distinct_bound: 1024, outstanding_bound: 1024,
      outstanding: :atomics.get(state.credits, 1), high_water: state.high_water,
      failure: if(state.failure, do: inspect(state.failure, limit: :infinity), else: nil)}
  end
  defp admission_observer_loop(state) do
    receive do
      {:admission_raw, gate, ordinal, app_state, outstanding} when gate == state.gate ->
        state = %{state | high_water: max(state.high_water, outstanding)}
        state = try do
          true = ordinal == state.received + 1
          true = outstanding in 1..1024
          snapshot = admission_snapshot(app_state, gate)
          digest = :crypto.hash(:sha256, :erlang.term_to_binary(snapshot))
          if MapSet.member?(state.seen, digest) do
            state
          else
            true = state.count < 1024
            receipt = Map.put(snapshot, :sequence, state.count + 1)
            send(state.host, {:fixed_h2_admission_receipt, receipt})
            %{state | seen: MapSet.put(state.seen, digest), count: state.count + 1}
          end
        rescue
          exception -> observer_failure(state, {:snapshot_exception, exception, __STACKTRACE__})
        catch
          kind, reason -> observer_failure(state, {:snapshot_exception, kind, reason})
        end
        :atomics.sub(state.credits, 1, 1)
        admission_observer_loop(%{state | received: ordinal})
      {:admission_overflow, gate, outstanding, ordinal} when gate == state.gate ->
        state = observer_failure(state, {:collector_overflow, outstanding, ordinal})
        admission_observer_loop(state)
      {:admission_gate_fence, gate, marker} when gate == state.gate ->
        summary = observer_summary(state)
        emit(Map.put(summary, :event, "diagnostic_admission_observer_fence"))
        send(state.host, {:admission_observer_fence, self(), marker, summary})
        admission_observer_loop(state)
      {:DOWN, ref, :process, gate, reason} when ref == state.gate_ref and gate == state.gate ->
        state = if :atomics.get(state.credits, 1) == 0, do: state,
          else: observer_failure(state, :outstanding_raw_after_gate_down)
        summary = observer_summary(state) |> Map.put(:gate_reason, inspect(reason))
        emit(Map.put(summary, :event, "diagnostic_admission_observer_closed"))
        send(state.host, {:admission_observer_closed, self(), summary})
      {:DOWN, ref, :process, host, reason} when ref == state.host_ref and host == state.host ->
        emit(observer_summary(state) |> Map.put(:event, "diagnostic_admission_observer_host_down")
          |> Map.put(:host_reason, inspect(reason)))
    end
  end
  defp flush_admission(state, expires) do
    marker = make_ref()
    observer = state.admission_observer
    gate = state.gate
    try do
      :sys.replace_state(gate, fn exact_state ->
        send(observer, {:admission_gate_fence, self(), marker})
        exact_state
      end, max(0, expires - System.monotonic_time(:millisecond)))
      receive do
        {:admission_observer_fence, ^observer, ^marker, summary} ->
          state = collect_originals(state)
          true = summary.failure == nil and state.admission_observer_failure == nil
          true = length(state.admission_receipts) >= summary.distinct
          true = Enum.map(Enum.take(state.admission_receipts, summary.distinct), & &1.sequence) ==
            (if summary.distinct == 0, do: [], else: Enum.to_list(1..summary.distinct))
          true = Enum.map(state.admission_receipts, & &1.sequence) ==
            (if state.admission_receipts == [], do: [],
              else: Enum.to_list(1..length(state.admission_receipts)))
          state
        {:DOWN, ref, :process, ^observer, reason} when ref == state.admission_observer_ref ->
          state = collect_originals(state)
          emit(%{event: "diagnostic_admission_flush_failed", reason: inspect(reason),
            receipts: state.admission_receipts, failures: state.failures})
          raise "Admission observer ended before live fence"
      after max(0, expires - System.monotonic_time(:millisecond)) ->
        state = collect_originals(state)
        emit(%{event: "diagnostic_admission_flush_failed", reason: "fence_deadline",
          receipts: state.admission_receipts, failures: state.failures})
        raise "Admission observer fence deadline"
      end
    catch
      :exit, reason ->
        state = collect_originals(state)
        emit(%{event: "diagnostic_admission_flush_failed", reason: inspect(reason),
          receipts: state.admission_receipts, failures: state.failures})
        exit(reason)
    end
  end
  defp join_admission(state, expires) do
    observer = state.admission_observer
    summary = receive do
      {:admission_observer_closed, ^observer, summary} -> summary
    after max(0, expires - System.monotonic_time(:millisecond)) ->
      raise "Admission observer terminal fence deadline"
    end
    ref = state.admission_observer_ref
    reason = receive do
      {:DOWN, ^ref, :process, ^observer, reason} -> reason
    after max(0, expires - System.monotonic_time(:millisecond)) ->
      raise "Admission observer join deadline"
    end
    state = collect_originals(state)
    true = reason == :normal and summary.outstanding == 0 and summary.failure == nil
    true = state.admission_observer_failure == nil
    true = length(state.admission_receipts) == summary.distinct
    true = Enum.map(state.admission_receipts, & &1.sequence) ==
      (if summary.distinct == 0, do: [], else: Enum.to_list(1..summary.distinct))
    emit(summary |> Map.put(:event, "diagnostic_admission_observer_joined")
      |> Map.put(:reason, inspect(reason)))
    state
  end
  defp admission_trace(host, service, gate) do
    host_ref = Process.monitor(host)
    service_ref = Process.monitor(service)
    gate_ref = Process.monitor(gate)
    traced = :erlang.trace(service, true, [:call, :monotonic_timestamp])
    send(host, {:admission_trace_ready, self(), traced})
    admission_trace_loop(%{host: host, host_ref: host_ref, service: service,
      service_ref: service_ref, gate: gate, gate_ref: gate_ref,
      service_down: false, gate_down: false, barrier: nil, delivered: false})
  end
  defp admission_trace_loop(state) do
    if state.service_down and state.gate_down and state.delivered do
      emit(%{event: "diagnostic_trace_join_ready", service: inspect(state.service),
        gate: inspect(state.gate), barrier_delivered: true})
    else
      receive do
        {:trace_ts, pid, kind, mfa, value, timestamp} ->
          emit(%{event: "diagnostic_admission_trace", pid: inspect(pid), kind: inspect(kind),
            mfa: inspect(mfa, limit: :infinity), value: inspect(value, limit: :infinity),
            timestamp: timestamp, timestamp_unit: "nanosecond"})
          admission_trace_loop(state)
        {:trace_ts, pid, kind, mfa, timestamp} ->
          emit(%{event: "diagnostic_admission_trace", pid: inspect(pid), kind: inspect(kind),
            mfa: inspect(mfa, limit: :infinity), timestamp: timestamp,
            timestamp_unit: "nanosecond"})
          admission_trace_loop(state)
        {:DOWN, ref, :process, host, _} when ref == state.host_ref and host == state.host -> :ok
        {:DOWN, ref, :process, pid, reason} when ref in [state.service_ref, state.gate_ref] ->
          emit(%{event: "diagnostic_actor_down", pid: inspect(pid), reason: inspect(reason),
            service: inspect(state.service), gate: inspect(state.gate),
            monotonic_ms: System.monotonic_time(:millisecond)})
          state = if ref == state.service_ref do
            %{state | service_down: true, barrier: :erlang.trace_delivered(state.service)}
          else
            %{state | gate_down: true}
          end
          admission_trace_loop(state)
        {:trace_delivered, service, barrier} when service == state.service and barrier == state.barrier ->
          admission_trace_loop(%{state | delivered: true})
      end
    end
  end
'''

SETUP = r'''
          pattern_count = :erlang.trace_pattern({Gaoxy.Admission, :complete_cleanup, 2},
            [{:_, [], [{:exception_trace}]}], [:local])
          true = pattern_count == 1
          trace_host = self()
          {tracer, tracer_ref} = spawn_monitor(fn -> admission_trace(trace_host, service, gate) end)
          receive do
            {:admission_trace_ready, ^tracer, traced} ->
              true = traced == 1
              emit(%{event: "diagnostic_trace_setup", service: inspect(service),
                pattern_count: pattern_count, traced_processes: traced})
          after 1000 -> raise "diagnostic trace setup failed" end
          credits = :atomics.new(1, signed: true)
          {admission_observer, admission_observer_ref} = spawn_monitor(fn ->
            admission_observer(trace_host, gate, credits)
          end)
          receive do
            {:admission_observer_ready, ^admission_observer} -> :ok
          after 1000 -> raise "Admission observer setup failed" end
          diagnostic = fn control, event, _ ->
            app_state = case event do
              {:out, _, _, app_state} -> app_state
              {:noreply, app_state} -> app_state
              _ -> nil
            end
            if is_map(app_state) and (app_state.mode == :failed or app_state.cleanup_failed != nil or app_state.drain != nil) do
              emit(%{event: "diagnostic_service_transition", service: inspect(service),
                mode: inspect(app_state.mode), cleanup_failed: inspect(app_state.cleanup_failed),
                drain_outcome: inspect(if(app_state.drain, do: app_state.drain.outcome, else: nil)),
                pending: map_size(app_state.cleanups), input: inspect(event, limit: 4, printable_limit: 128),
                monotonic_ms: System.monotonic_time(:millisecond)})
            end
            case event do
              {:in, {:DOWN, _, :process, pid, reason}} ->
                emit(%{event: "diagnostic_service_down_input", service: inspect(service),
                  pid: inspect(pid), reason: inspect(reason, limit: 20, printable_limit: 128),
                  monotonic_ms: System.monotonic_time(:millisecond)})
              _ -> :ok
            end
            control
          end
          :ok = :sys.install(service, {make_ref(), diagnostic, nil})
'''

ASYNC_DEBUG = r'''          admission_debug = fn trace, event, _ ->
            app_state = case event do
              {:out, _, _, app_state} -> app_state
              {:noreply, app_state} -> app_state
              _ -> nil
            end
            if not trace.failed and is_map(app_state) and
                 (trace.active or map_size(app_state.cleanups) > 0 or app_state.mode == :failed) do
              outstanding = :atomics.add_get(credits, 1, 1)
              if outstanding <= 1024 do
                ordinal = trace.submitted + 1
                send(admission_observer, {:admission_raw, gate, ordinal, app_state, outstanding})
                %{trace | active: true, submitted: ordinal}
              else
                :atomics.sub(credits, 1, 1)
                send(admission_observer, {:admission_overflow, gate, outstanding, trace.submitted + 1})
                %{trace | failed: true}
              end
            else
              trace
            end
          end
          :ok = :sys.install(gate, {make_ref(), admission_debug,
            %{active: false, submitted: 0, failed: false}})
'''


def replace_once(source, old, new):
    assert source.count(old) == 1, ('injection anchor mismatch', old[:100])
    return source.replace(old, new, 1)


host_source = replace_once(canonical_host, '  def run(evidence) do\n', HELPERS + '\n  def run(evidence) do\n')
host_source = replace_once(host_source, '          gate = :sys.get_state(service).gate\n',
                          '          gate = :sys.get_state(service).gate\n' + SETUP)
start = host_source.index('          admission_debug = fn trace, event, _ ->\n')
end_anchor = '          :ok = :sys.install(gate, {make_ref(), admission_debug, %{active: false, seen: MapSet.new(), count: 0}})\n'
end = host_source.index(end_anchor, start) + len(end_anchor)
host_source = host_source[:start] + ASYNC_DEBUG + host_source[end:]
host_source = replace_once(host_source, '            gate_join: {gate, Process.monitor(gate)}, native_joins: %{}, admission_receipts: []}',
    '            gate_join: {gate, Process.monitor(gate)}, native_joins: %{}, admission_receipts: [],\n'
    '            admission_observer: admission_observer, admission_observer_ref: admission_observer_ref,\n'
    '            admission_observer_failure: nil, diagnostic_tracer: tracer, diagnostic_tracer_ref: tracer_ref}')
for operation in ('status', 'observe'):
    host_source = replace_once(host_source, '        "' + operation + '" ->\n          state = collect_originals(state)',
        '        "' + operation + '" ->\n          state = flush_admission(state, deadline())\n          state = collect_originals(state)')
host_source = replace_once(host_source, '        "clean" ->\n          wait_clean(state, deadline())\n          state = collect_originals(state)',
    '        "clean" ->\n          expires = deadline()\n          try do\n            wait_clean(state, expires)\n          rescue\n            error ->\n              late = collect_originals(state)\n              emit(%{event: "diagnostic_clean_failure_receipts", receipts: late.admission_receipts,\n'
    '                observer_failure: inspect(late.admission_observer_failure), failures: late.failures})\n'
    '              reraise error, __STACKTRACE__\n          end\n          state = flush_admission(state, expires)\n          state = collect_originals(state)')
host_source = replace_once(host_source, '        "request_clean" ->\n          {state, ledger} = wait_request_clean(state, deadline())',
    '        "request_clean" ->\n          expires = deadline()\n          {state, ledger} = wait_request_clean(state, expires)\n          state = flush_admission(state, expires)')
host_source = replace_once(host_source, '          gate_join = joined(gate, gate_ref)\n          state = collect_originals(state)',
    '          observer_expires = deadline()\n          gate_join = joined(gate, gate_ref)\n'
    '          state = join_admission(state, observer_expires)\n'
    '          trace_pid = state.diagnostic_tracer\n          trace_ref = state.diagnostic_tracer_ref\n'
    '          receive do\n            {:DOWN, ^trace_ref, :process, ^trace_pid, reason} ->\n'
    '              true = reason == :normal\n              emit(%{event: "diagnostic_trace_joined", pid: inspect(trace_pid), reason: inspect(reason)})\n'
    '          after max(0, observer_expires - System.monotonic_time(:millisecond)) ->\n'
    '            raise "diagnostic trace join deadline"\n          end\n'
    '          1 = :erlang.trace_pattern({Gaoxy.Admission, :complete_cleanup, 2}, false, [:local])\n'
    '          state = collect_originals(state)')
host_source = replace_once(host_source, '      {:fixed_h2_admission_receipt, receipt} ->\n',
    '      {:admission_observer_failure, observer, reason} when observer == state.admission_observer ->\n'
    '        collect_originals(%{state | admission_observer_failure: reason})\n'
    '      {:fixed_h2_admission_receipt, receipt} ->\n')
host_script = E / 'diagnostic-host.exs'
host_script.write_text(host_source)
(E / 'diagnostic-runner.py').write_text(Path(__file__).read_text())
inputs = {'kind': 'EXPERIMENT_ONLY_ASYNC_ADMISSION_OBSERVER', 'cohorts': 6,
          'protocols': ['tls', 'h2c'] * 3, 'downstream': 'h2', 'kind_each': 'r32',
          'distinct_bound': 1024, 'outstanding_raw_bound': 1024,
          'canonical_collector_sha256': hashlib.sha256(Path(q.__file__).read_bytes()).hexdigest(),
          'canonical_concurrent_cohort_sha256': hashlib.sha256(canonical_cohort.encode()).hexdigest(),
          'canonical_host_sha256': hashlib.sha256(canonical_host.encode()).hexdigest(),
          'injected_host_sha256': hashlib.sha256(host_source.encode()).hexdigest(),
          'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'production_admission_timeout_ms': 50, 'changed_repository_files': []}
(E / 'inputs.json').write_text(json.dumps(inputs, indent=2) + '\n')
before = q.inventory()
actors, outcomes = [], []
host, failure, active_cohort = None, None, None
started_at = time.monotonic()
try:
    host = q.Process(['nix', 'develop', '--command', 'env', 'ERL_FLAGS=+S 2:2',
                      'MIX_ENV=test', 'mix', 'run', str(host_script), str(E)],
                     E / 'host.log', 'FIXED_H2_HOST ')
    actors.append(host)
    host.event('ready', 90)
    for index in range(6):
        protocol = 'tls' if index % 2 == 0 else 'h2c'
        active_cohort = {'index': index, 'protocol': protocol, 'status': 'RUNNING'}
        outcome = q.concurrent_cohort(E, 'r32-' + str(index), protocol, 'h2', host, actors, 'r32')
        outcomes.append({'index': index, 'protocol': protocol, 'status': 'PASS', 'outcome': outcome})
        active_cohort = None
    host.send({'op': 'exit'})
    host.event('exited')
    host.join()
except Exception:
    failure = traceback.format_exc()
    if active_cohort is not None:
        outcomes.append(dict(active_cohort, status='FAIL', failure=failure))
finally:
    for actor in actors:
        actor.dispose()
    after = q.inventory()
    events = [event for event in host.seen if str(event.get('event', '')).startswith('diagnostic_')] if host else []
    timings, pending = [], {}
    for event in events:
        if event['event'] != 'diagnostic_admission_trace':
            continue
        pid, kind = event['pid'], event['kind']
        if kind == ':call':
            pending[pid] = event
        elif kind in (':return_from', ':exception_from') and pid in pending:
            call = pending.pop(pid)
            timings.append({'pid': pid, 'call': call, 'terminal': event,
                            'duration_ns': event['timestamp'] - call['timestamp'],
                            'duration_ms': (event['timestamp'] - call['timestamp']) / 1_000_000})
    source_stable = before == after and inspect.getsource(q.concurrent_cohort) == canonical_cohort
    observer_joins = [event for event in events if event['event'] == 'diagnostic_admission_observer_joined']
    trace_joins = [event for event in events if event['event'] == 'diagnostic_trace_joined']
    observer_failures = [event for event in events if event['event'] == 'diagnostic_admission_observer_failure']
    trace_setups = [event for event in events if event['event'] == 'diagnostic_trace_setup']
    trace_barriers = [event for event in events if event['event'] == 'diagnostic_trace_join_ready']
    acceptance = (failure is None and source_stable and len(outcomes) == 6 and
                  len(observer_joins) == 6 and len(trace_joins) == 6 and not observer_failures and
                  len(trace_setups) == 6 and len(trace_barriers) == 6 and not pending and
                  len(timings) == 6 * 32 and
                  all(row['terminal']['kind'] == ':return_from' and
                      row['terminal'].get('value') == ':ok' for row in timings))
    result = {'kind': 'EXPERIMENT_ONLY_NOT_PRODUCTION_OR_STAGE_ACCEPTANCE',
              'status': 'PASS_SIX_COHORTS' if acceptance else 'FAIL',
              'attempted': len(outcomes), 'passed': sum(row['status'] == 'PASS' for row in outcomes),
              'elapsed_ms': round((time.monotonic() - started_at) * 1000),
              'failure': failure, 'outcomes': outcomes, 'inputs': inputs,
              'lifecycle_events': events, 'admission_timings': timings,
              'observer_joins': observer_joins, 'trace_joins': trace_joins,
              'trace_setups': trace_setups, 'trace_barriers': trace_barriers,
              'observer_failures': observer_failures, 'unpaired_trace_calls': list(pending.values()),
              'source_stable': source_stable, 'source_before': before, 'source_after': after}
    (E / 'diagnostic.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: result[key] for key in ('kind', 'status', 'attempted', 'passed', 'elapsed_ms', 'failure', 'source_stable')}, indent=2))
sys.exit(0 if acceptance else 1)
