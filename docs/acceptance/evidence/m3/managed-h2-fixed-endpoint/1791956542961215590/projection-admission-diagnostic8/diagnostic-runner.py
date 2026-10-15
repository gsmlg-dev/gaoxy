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

E = ROOT / 'docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/projection-admission-diagnostic8'
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

CLEANUP_IDENTITY_SPEC = {'identity_domains': 'Admission cleanup refs are separate from upstream originals.token refs.', 'held_contract': 'Each cell has exactly32 live attached cleanup refs at its pre-refusal held barrier; each must have exactly one authenticated trace call/return pair.', 'all_trace_contract': 'Rebuild every raw call/terminal pair, validate Service/Gate identity, reject overlap/unmatched/duplicate calls, require :ok and 0..50ms; discard nothing.', 'partition_contract': 'Every observed cleanup ref equals one traced ref. Partition into held32 plus exactly one H1 refusal extra or zero H2 extras.', 'extra_contract': 'H1 extra has a new33rd native lease and cleanup in pending-to-after_refusal receipts, false-to-true receipt then cleanup removal, cleared lease, and eventual real lease removal; held32 remain identifiable and pending until response dispatch.', 'asynchrony': 'Final receipt capture may contain lease removal after the after_refusal prefix. No claim that lease removal precedes held completion is required.', 'refusal_proof': 'The unchanged sequential cohort creates only /refused between held and after_refusal barriers; response503, no additional upstream request/original, same held32 and C2/R32/P0 establish its provenance.', 'unchanged': 'Keep four cohort calls, original assertions, bodies,32/33capacity,1024caps,50ms timeout, deadlines, FIFO fences, source gates, joins,135matrix; diagnostic7 stays FAIL.'}

def authenticate_cleanup_identities(outcomes, events, timings, trace_setups, trace_barriers):
    """Authenticate the exact held128 plus separately identified refusal cleanup calls."""
    import re

    report = {"valid": False, "cells": [], "errors": [], "pairs": []}

    def require(condition, message):
        if not condition:
            raise ValueError(message)

    try:
        require(len(outcomes) == 4, "four cell outcomes required")
        expected_cells = ["h1-to-tls", "h1-to-h2c", "h2-to-tls", "h2-to-h2c"]
        require([row["cell"] for row in outcomes] == expected_cells, "cell identities/order changed")
        service_gates = {}
        for row in outcomes:
            require(row["status"] == "PASS" and row["outcome"]["status"] == "PASS", "cohort did not pass")
            pending = row["outcome"]["pending"]
            service, gate = pending["service_pid"], pending["gate_pid"]
            require(service not in service_gates and gate not in service_gates.values(), "reused Service/Gate identity")
            service_gates[service] = gate
        require(len(trace_setups) == 4 and {row["service"] for row in trace_setups} == set(service_gates), "trace setups do not cover exact Services")
        require(all(row["pattern_count"] == 1 and row["traced_processes"] == 1 for row in trace_setups), "trace setup incomplete")
        require(len(trace_barriers) == 4 and {(row["service"], row["gate"]) for row in trace_barriers} == set(service_gates.items()), "trace barriers identity mismatch")
        require(all(row["barrier_delivered"] for row in trace_barriers), "trace delivery barrier missing")

        pending_calls, rebuilt, seen = {}, [], set()
        call_re = re.compile(r"\{Gaoxy\.Admission, :complete_cleanup, \[(#PID<[0-9.]+>), (#Reference<[0-9.]+>)\]\}")
        for event in events:
            if event["event"] != "diagnostic_admission_trace":
                continue
            service = event["pid"]
            require(service in service_gates and event["timestamp_unit"] == "nanosecond", "unknown traced caller or clock")
            if event["kind"] == ":call":
                require(service not in pending_calls, "overlapping calls would overwrite a trace")
                match = call_re.fullmatch(event["mfa"])
                require(match is not None, "unexpected traced call MFA")
                gate, token = match.groups()
                require(gate == service_gates[service], "call Gate does not belong to traced Service")
                require((gate, token) not in seen, "duplicate cleanup call identity")
                seen.add((gate, token))
                pending_calls[service] = event
            else:
                require(event["kind"] == ":return_from" and event.get("value") == ":ok", "non-ok cleanup terminal")
                require(event["mfa"] == "{Gaoxy.Admission, :complete_cleanup, 2}" and service in pending_calls, "unpaired cleanup terminal")
                call = pending_calls.pop(service)
                duration = event["timestamp"] - call["timestamp"]
                require(0 <= duration <= 50_000_000, "cleanup call exceeded original50ms bound")
                rebuilt.append({"pid": service, "call": call, "terminal": event,
                                "duration_ns": duration, "duration_ms": duration / 1_000_000})
        require(not pending_calls, "unpaired cleanup calls remain")
        require(rebuilt == timings, "timing rows omit or change actual raw trace pairs")
        report["pairs"] = rebuilt

        all_held, all_observed = set(), set()
        for cell in outcomes:
            outcome = cell["outcome"]
            pending, after, stopped = outcome["pending"], outcome["after_refusal"], outcome["cleanup"]
            gate, service = pending["gate_pid"], pending["service_pid"]
            receipts = stopped["admission_receipts"]
            require(pending["admission_receipts"] == receipts[:len(pending["admission_receipts"])], "pending immutable prefix lost")
            require(after["admission_receipts"] == receipts[:len(after["admission_receipts"])], "after_refusal immutable prefix lost")
            require(0 < len(receipts) <= 1024 and [row["sequence"] for row in receipts] == list(range(1, len(receipts) + 1)), "snapshot cap/sequence changed")
            observed = {}
            for snapshot in receipts:
                require(snapshot["gate"] == gate and snapshot["service"] == service and snapshot["total_invariant"], "snapshot identity/invariant failure")
                require(snapshot["active"] == len(snapshot["leases"]) and snapshot["cleanup_pending"] == len(snapshot["cleanups"]), "snapshot count mismatch")
                require(snapshot["lease_bytes"] == sum(row["bytes"] for row in snapshot["leases"]) and snapshot["cleanup_bytes"] == sum(row["bytes"] for row in snapshot["cleanups"]), "snapshot byte sums changed")
                require(snapshot["retained_bytes"] == snapshot["lease_bytes"] + snapshot["cleanup_bytes"], "snapshot total changed")
                require(len({row["token"] for row in snapshot["cleanups"]}) == len(snapshot["cleanups"]), "duplicate cleanup rows")
                for cleanup in snapshot["cleanups"]:
                    identity = (cleanup["lease"], cleanup["bytes"])
                    require(cleanup["bytes"] == 9_444_956, "exact cleanup reservation changed")
                    require(observed.get(cleanup["token"], identity) == identity, "cleanup changed lease/reservation")
                    observed[cleanup["token"]] = identity
            for token in observed:
                started, received, removed = False, False, False
                for snapshot in receipts:
                    rows = [row for row in snapshot["cleanups"] if row["token"] == token]
                    if rows:
                        require(not removed, "cleanup identity reappeared after removal")
                        require(started or not rows[0]["receipt"], "cleanup first appeared with a fabricated receipt")
                        require(not received or rows[0]["receipt"], "cleanup receipt regressed")
                        started, received = True, received or rows[0]["receipt"]
                    elif started:
                        require(received, "cleanup removed without true receipt")
                        removed = True
                require(started and received and removed, "cleanup lacks full false/true/removal lifecycle")
            anchors = [row for row in pending["admission_receipts"] if row["cleanup_pending"] == 32]
            require(anchors, "authentic held32 snapshot missing")
            anchor = anchors[-1]
            held = {row["token"]: row for row in anchor["cleanups"]}
            require(len(held) == 32 and all(not row["receipt"] for row in held.values()), "held32 identities/receipts changed")
            require(all({row["token"] for row in snapshot["cleanups"]} == set(held) for snapshot in anchors), "held identity changed before refusal")
            held_rows = []
            for token, cleanup in held.items():
                leases = [row for row in anchor["leases"] if row["lease"] == cleanup["lease"] and row["cleanup"] == token and row["request_active"]]
                require(len(leases) == 1, "held cleanup lacks exact active lease/owner")
                held_rows.append({"token": token, "lease": cleanup["lease"], "owner": leases[0]["owner"], "bytes": cleanup["bytes"], "snapshot_sequence": anchor["sequence"]})
            require(len({row["lease"] for row in held_rows}) == 32 and len({row["owner"] for row in held_rows}) == 32, "held lease/owner identities reused")
            cell_pairs = [row for row in rebuilt if row["pid"] == service]
            paired = {call_re.fullmatch(row["call"]["mfa"])[2]: row for row in cell_pairs}
            require(set(paired) == set(observed), "observed cleanup refs and all trace calls are not an exact bijection")
            require(set(held) <= set(paired), "held cleanup completion missing")
            all_held.update((gate, token) for token in held)
            all_observed.update((gate, token) for token in observed)

            for phase in (pending, after):
                native, owner = phase["native_scope"], phase["owner"]
                require(native["active_requests"] == 32 and native["preparing_requests"] == 0 and native["pending"] == 0 and native["connections"] == 2, "held C2/R32/P0 changed")
                require(native["limits"]["max_requests"] == 32 and native["limits"]["max_connections"] == 2 and native["limits"]["max_pending"] == 0, "capacity limits changed")
                require(owner["request_tokens"] == 32 and owner["helpers"] == 0, "held owner32/helper ledger changed")
                require(len(phase["originals"]) == 32 and phase["originals"] == phase["original_repeat"] and all(row["result"] == "{:error, :cleanup_pending}" for row in phase["originals"]), "upstream originals32/pending identity changed")
            require(pending["originals"] == after["originals"], "refusal changed upstream original identity")
            require(len(outcome["requests"]) == 32 and {row["target"] for row in outcome["requests"]} == {"/hold/r32/" + str(i) for i in range(32)}, "refused request reached upstream or replayed")
            require(len(outcome["responses"]) == 33 and outcome["responses"][0]["status"] == 503 and outcome["responses"][0]["body_bytes"] == 0 and outcome["responses"][0]["socket_closed"], "actual33rd refusal missing")
            require(outcome["joined"]["requests"] == 32, "independent peer request cardinality changed")
            interval = receipts[len(pending["admission_receipts"]):len(after["admission_receipts"])]
            require(interval, "refusal interval not captured")
            for snapshot in interval:
                rows = {row["token"]: row for row in snapshot["cleanups"]}
                require(all(token in rows and rows[token] == held[token] for token in held), "held32 changed during refusal")
            extras = set(observed) - set(held)
            require(len(extras) == (1 if cell["cell"].startswith("h1-") else 0), "unexpected non-held cleanup identities")
            extra_rows = []
            for token in sorted(extras):
                lease, reserved = observed[token]
                require(lease not in {row["lease"] for row in anchor["leases"]}, "extra reused a held native lease")
                require(not any(row["token"] == token for snapshot in pending["admission_receipts"] for row in snapshot["cleanups"]), "extra predates refusal")
                new_leases = {row["lease"] for snapshot in interval for row in snapshot["leases"]} - {row["lease"] for row in anchor["leases"]}
                require(new_leases == {lease}, "refusal interval lacks a unique33rd lease")
                attached = [(snapshot, row) for snapshot in interval for row in snapshot["cleanups"] if row["token"] == token and not row["receipt"]]
                require(attached, "extra was never authentically attached without receipt")
                first, cleanup = attached[0]
                owners = [row for row in first["leases"] if row["lease"] == lease and row["cleanup"] == token and row["request_active"]]
                require(len(owners) == 1 and first["active"] == 33 and first["cleanup_pending"] == 33, "extra not on the33rd active native lease")
                received = [snapshot for snapshot in interval if snapshot["sequence"] > first["sequence"] and any(row["token"] == token and row["receipt"] for row in snapshot["cleanups"])]
                require(received, "extra receipt true not observed in refusal interval")
                cleared = [snapshot for snapshot in interval if snapshot["sequence"] > received[0]["sequence"] and all(row["token"] != token for row in snapshot["cleanups"]) and any(row["lease"] == lease and row["cleanup"] is None for row in snapshot["leases"])]
                require(cleared and cleared[0]["mode"] == ":ready", "normal extra cleanup removal/cleared lease not observed")
                removed = [snapshot for snapshot in receipts if snapshot["sequence"] > cleared[0]["sequence"] and all(row["lease"] != lease for row in snapshot["leases"])]
                require(removed, "extra native lease removal not observed")
                extra_rows.append({"token": token, "lease": lease, "owner": owners[0]["owner"], "bytes": reserved,
                                   "attached_sequence": first["sequence"], "receipt_sequence": received[0]["sequence"],
                                   "cleanup_removed_sequence": cleared[0]["sequence"], "lease_removed_sequence": removed[0]["sequence"],
                                   "timing": paired[token], "classification": "sole_refused_request_interval_cleanup"})
            require(len(outcome["clean"]["originals"]) == 32 and all(row["result"] == ":ok" for row in outcome["clean"]["originals"]), "held original completions not joined")
            require(outcome["clean"]["service"]["cleanup_pending"] == 0 and outcome["clean"]["service"]["retained_bytes"] == 0 and not stopped["service_failures"], "cleanup did not settle cleanly")
            report["cells"].append({"cell": cell["cell"], "gate": gate, "service": service, "held_snapshot_sequence": anchor["sequence"],
                                    "pending_prefix_length": len(pending["admission_receipts"]), "after_refusal_prefix_length": len(after["admission_receipts"]),
                                    "final_receipt_count": len(receipts), "held": held_rows, "extras": extra_rows,
                                    "all_call_count": len(cell_pairs), "max_duration_ms": max(row["duration_ms"] for row in cell_pairs)})
        require(len(all_held) == 128 and len(all_observed) == 130 and all_observed == seen, "exact held128/extra2/all130 partition failed")
        report.update(valid=True, held_count=len(all_held), extra_count=len(all_observed - all_held), all_call_count=len(rebuilt))
    except Exception as error:
        report["errors"].append(type(error).__name__ + ": " + str(error))
    return report


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
    cleanup_identity = authenticate_cleanup_identities(outcomes, events, timings, trace_setups, trace_barriers)
    acceptance = (failure is None and source_stable and len(outcomes) == 4 and len(observer_joins) == 4 and
                  all(row['reason'] == ':normal' and row['outstanding'] == 0 and row['failure'] is None and
                      row['high_water'] <= 1024 and row['distinct'] <= 1024 and
                      row['raw_candidates'] == row['received_raw'] + row['adjacent_suppressed']
                      for row in observer_joins) and len(trace_joins) == 4 and len(trace_setups) == 4 and
                  len(trace_barriers) == 4 and not pending and cleanup_identity["valid"] and
                  all(row['terminal']['kind'] == ':return_from' and row['terminal'].get('value') == ':ok'
                      for row in timings))
    result = {'kind': 'EXPERIMENT_ONLY_NOT_PRODUCTION_OR_STAGE_ACCEPTANCE',
              'status': 'PASS_FOUR_CELLS' if acceptance else 'FAIL',
              'attempted': len(outcomes), 'passed': sum(row['status'] == 'PASS' for row in outcomes),
              'elapsed_ms': round((time.monotonic() - started_at) * 1000), 'failure': failure,
              'outcomes': outcomes, 'inputs': inputs, 'lifecycle_events': events, 'admission_timings': timings,
              'observer_joins': observer_joins, 'trace_joins': trace_joins, 'trace_setups': trace_setups,
              'trace_barriers': trace_barriers, 'unpaired_trace_calls': list(pending.values()),
              'cleanup_identity': cleanup_identity, 'source_stable': source_stable, 'source_before': before, 'source_after': after}
    (E / 'diagnostic.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: result[key] for key in ('kind', 'status', 'attempted', 'passed', 'elapsed_ms', 'failure', 'source_stable')}, indent=2))
sys.exit(0 if acceptance else 1)
