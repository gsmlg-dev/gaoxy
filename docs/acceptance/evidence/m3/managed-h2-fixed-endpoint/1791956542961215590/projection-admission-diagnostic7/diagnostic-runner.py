"""EXPERIMENT ONLY: Sol17 whole-buffer-floor plus exact adjacent projection, four R32 cells."""
from pathlib import Path
import ast
import hashlib
import inspect
import json
import sys
import time
import traceback

ROOT = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
sys.path.insert(0, str(ROOT / 'integration/http_fetch_contract'))
import managed_h2_fixed_qualification as q

E = ROOT / 'docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/projection-admission-diagnostic7'
E.mkdir(exist_ok=False)
previous_path = Path('/tmp/gaoxy-h2-fixed-async-admission-diagnostic.py')
previous_source = previous_path.read_text()
assert hashlib.sha256(previous_source.encode()).hexdigest() == '66f74e74e1c2a584f1cce8107e13243a4d3a18096915405355671b225ce97647'
previous = {}
for node in ast.parse(previous_source).body:
    if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
        if node.targets[0].id in ('HELPERS', 'SETUP'):
            previous[node.targets[0].id] = ast.literal_eval(node.value)
trace_helpers = previous['HELPERS'][previous['HELPERS'].index('  defp admission_trace(host, service, gate) do\n'):]
trace_setup = previous['SETUP'].split('          credits = :atomics.new', 1)[0]
trace_setup += '          diagnostic = fn control, event, _ ->' + previous['SETUP'].split('          diagnostic = fn control, event, _ ->', 1)[1]
canonical_host = q.HOST
canonical_cohort = inspect.getsource(q.concurrent_cohort)
assert hashlib.sha256(Path(q.__file__).read_bytes()).hexdigest() == 'ca7e48cecabfb332eee7a5769cb4b03d64cb1fc331d133316294d7528003eb16'

PROJECTION = r'''
  defp admission_projection(app_state) do
    leases = Map.new(app_state.leases, fn {ref, lease} ->
      {ref, {lease.pid, lease.bytes, lease.cleanup, lease.request_active}}
    end)
    cleanups = Map.new(app_state.cleanups, fn {token, cleanup} ->
      {token, {cleanup.lease, cleanup.bytes, cleanup.receipt}}
    end)
    {app_state.service, app_state.mode, app_state.bytes, leases, cleanups}
  end
'''
PROJECTED_DEBUG = r'''          admission_debug = fn trace, event, _ ->
            app_state = case event do
              {:out, _, _, app_state} -> app_state
              {:noreply, app_state} -> app_state
              _ -> nil
            end
            if not trace.failed and is_map(app_state) and
                 (trace.active or map_size(app_state.cleanups) > 0 or app_state.mode == :failed) do
              :atomics.add(credits, 2, 1)
              projection = admission_projection(app_state)
              if projection === trace.projection do
                :atomics.add(credits, 3, 1)
                trace
              else
                outstanding = :atomics.add_get(credits, 1, 1)
                if outstanding <= 1024 do
                  ordinal = trace.submitted + 1
                  send(admission_observer, {:admission_raw, gate, ordinal, app_state, outstanding})
                  %{trace | active: true, submitted: ordinal, projection: projection}
                else
                  :atomics.sub(credits, 1, 1)
                  send(admission_observer, {:admission_overflow, gate, outstanding, trace.submitted + 1})
                  %{trace | failed: true}
                end
              end
            else
              trace
            end
          end
          :ok = :sys.install(gate, {make_ref(), admission_debug,
            %{active: false, submitted: 0, failed: false, projection: nil}})
'''


def replace_once(source, old, new):
    assert source.count(old) == 1, ('injection anchor mismatch', old[:100])
    return source.replace(old, new, 1)


host_source = replace_once(canonical_host, '  def run(evidence) do\n',
                           PROJECTION + trace_helpers + '\n  def run(evidence) do\n')
host_source = replace_once(host_source, '          gate = :sys.get_state(service).gate\n',
                           '          gate = :sys.get_state(service).gate\n' + trace_setup)
host_source = replace_once(host_source, '          credits = :atomics.new(1, signed: true)',
                           '          credits = :atomics.new(3, signed: true)')
start = host_source.index('          admission_debug = fn trace, event, _ ->\n')
end_anchor = '          :ok = :sys.install(gate, {make_ref(), admission_debug, %{active: false, submitted: 0, failed: false}})\n'
end = host_source.index(end_anchor, start) + len(end_anchor)
host_source = host_source[:start] + PROJECTED_DEBUG + host_source[end:]
host_source = replace_once(host_source, '      outstanding: :atomics.get(state.credits, 1), high_water: state.high_water,\n',
                           '      outstanding: :atomics.get(state.credits, 1), high_water: state.high_water,\n'
                           '      raw_candidates: :atomics.get(state.credits, 2), adjacent_suppressed: :atomics.get(state.credits, 3),\n')
host_source = replace_once(host_source, '            admission_observer_failure: nil, admission_observer_join: nil}',
                           '            admission_observer_failure: nil, admission_observer_join: nil,\n'
                           '            diagnostic_tracer: tracer, diagnostic_tracer_ref: tracer_ref}')
host_source = replace_once(host_source, '          state = finish_admission(state, expires)\n          state = collect_originals(state)',
                           '          state = finish_admission(state, expires)\n'
                           '          trace_pid = state.diagnostic_tracer\n          trace_ref = state.diagnostic_tracer_ref\n'
                           '          receive do\n            {:DOWN, ^trace_ref, :process, ^trace_pid, reason} ->\n'
                           '              true = reason == :normal\n'
                           '              emit(%{event: "diagnostic_trace_joined", pid: inspect(trace_pid), reason: inspect(reason)})\n'
                           '          after max(0, expires - System.monotonic_time(:millisecond)) ->\n'
                           '            raise "diagnostic trace join deadline"\n          end\n'
                           '          1 = :erlang.trace_pattern({Gaoxy.Admission, :complete_cleanup, 2}, false, [:local])\n'
                           '          state = collect_originals(state)')

host_script = E / 'diagnostic-host.exs'
host_script.write_text(host_source)
(E / 'diagnostic-runner.py').write_text(Path(__file__).read_text())
cells = [(downstream, protocol) for downstream in ('h1', 'h2') for protocol in ('tls', 'h2c')]
proof = {
    'projection': 'service, mode, bytes; leases ref -> (pid, bytes, cleanup, request_active); cleanups token -> (lease, bytes, receipt)',
    'comparison': 'strict ===; only adjacent equal projections suppressed',
    'fixed_scope': 'One Gate PID per observer; gate snapshot identity is unchanged.',
    'equivalence': 'Equal raw references/scalars/maps imply identical inspected identities, sorted snapshot rows, row counts, byte sums and total-invariant outcome. Thus original serialized snapshot and digest are identical. An adjacent duplicate was already rejected by the unchanged observer seen-set.',
    'excluded': ['lease.monitor', 'lease.timer', 'lease.token', 'lease.deadline', 'lease.send', 'other fields not read by admission_snapshot'],
    'capture': 'Changed projection sends original complete app_state; original snapshot/hash/global dedup/distinct cap/invariants run unchanged in observer.',
    'cost': 'Projection/equality and BEAM send-copy scale with bounded lease/cleanup counts; no Gate inspect, sorting, hashing or serialization.',
}
inputs = {'kind': 'EXPERIMENT_ONLY_FOUR_CELL_ADJACENT_PROJECTION', 'cells': cells,
          'cohorts': 4, 'kind_each': 'r32', 'distinct_bound': 1024, 'outstanding_raw_bound': 1024,
          'canonical_collector_sha256': hashlib.sha256(Path(q.__file__).read_bytes()).hexdigest(),
          'canonical_concurrent_cohort_sha256': hashlib.sha256(canonical_cohort.encode()).hexdigest(),
          'canonical_host_sha256': hashlib.sha256(canonical_host.encode()).hexdigest(),
          'injected_host_sha256': hashlib.sha256(host_source.encode()).hexdigest(),
          'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'trace_support_source_sha256': hashlib.sha256(previous_source.encode()).hexdigest(),
          'production_admission_timeout_ms': 50, 'changed_repository_files': [], 'equivalence_proof': proof}
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
    for index, (downstream, protocol) in enumerate(cells):
        active_cohort = {'index': index, 'cell': downstream + '-to-' + protocol, 'status': 'RUNNING'}
        outcome = q.concurrent_cohort(E, active_cohort['cell'] + '-r32', protocol, downstream, host, actors, 'r32')
        outcomes.append(dict(active_cohort, status='PASS', outcome=outcome))
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
    observer_joins = [event['admission_observer'] for event in host.seen if event.get('event') == 'stopped'] if host else []
    trace_joins = [event for event in events if event['event'] == 'diagnostic_trace_joined']
    trace_setups = [event for event in events if event['event'] == 'diagnostic_trace_setup']
    trace_barriers = [event for event in events if event['event'] == 'diagnostic_trace_join_ready']
    source_stable = before == after and inspect.getsource(q.concurrent_cohort) == canonical_cohort
    acceptance = (failure is None and source_stable and len(outcomes) == 4 and len(observer_joins) == 4 and
                  all(row['reason'] == ':normal' and row['outstanding'] == 0 and row['failure'] is None and
                      row['high_water'] <= 1024 and row['distinct'] <= 1024 and
                      row['raw_candidates'] == row['received_raw'] + row['adjacent_suppressed']
                      for row in observer_joins) and len(trace_joins) == 4 and len(trace_setups) == 4 and
                  len(trace_barriers) == 4 and not pending and len(timings) == 4 * 32 and
                  all(row['terminal']['kind'] == ':return_from' and row['terminal'].get('value') == ':ok'
                      for row in timings))
    result = {'kind': 'EXPERIMENT_ONLY_NOT_PRODUCTION_OR_STAGE_ACCEPTANCE',
              'status': 'PASS_FOUR_CELLS' if acceptance else 'FAIL',
              'attempted': len(outcomes), 'passed': sum(row['status'] == 'PASS' for row in outcomes),
              'elapsed_ms': round((time.monotonic() - started_at) * 1000), 'failure': failure,
              'outcomes': outcomes, 'inputs': inputs, 'lifecycle_events': events, 'admission_timings': timings,
              'observer_joins': observer_joins, 'trace_joins': trace_joins, 'trace_setups': trace_setups,
              'trace_barriers': trace_barriers, 'unpaired_trace_calls': list(pending.values()),
              'source_stable': source_stable, 'source_before': before, 'source_after': after}
    (E / 'diagnostic.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: result[key] for key in ('kind', 'status', 'attempted', 'passed', 'elapsed_ms', 'failure', 'source_stable')}, indent=2))
sys.exit(0 if acceptance else 1)
