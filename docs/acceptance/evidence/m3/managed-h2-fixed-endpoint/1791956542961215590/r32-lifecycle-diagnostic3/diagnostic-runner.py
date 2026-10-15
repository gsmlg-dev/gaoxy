from pathlib import Path
import sys,json,time,traceback,hashlib
ROOT=Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
sys.path.insert(0,str(ROOT/'integration/http_fetch_contract'))
import managed_h2_fixed_qualification as q
E=ROOT/'docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/r32-lifecycle-diagnostic3'
E.mkdir(exist_ok=False)
needle='          gate = :sys.get_state(service).gate\n'
probe='''          :erlang.trace_pattern({Gaoxy.Admission, :complete_cleanup, 2},
            [{:_, [], [{:exception_trace}]}], [:local])
          starter = self()
          tracer = spawn(fn ->
            watched = Process.monitor(service)
            :erlang.trace(service, true, [:call, :monotonic_timestamp])
            send(starter, {:admission_trace_ready, self()})
            loop = fn recurse ->
              receive do
                {:trace_ts, pid, kind, mfa, value, timestamp} ->
                  emit(%{event: "diagnostic_admission_trace", pid: inspect(pid), kind: inspect(kind),
                    mfa: inspect(mfa), value: inspect(value, limit: 30, printable_limit: 256),
                    timestamp: timestamp})
                  recurse.(recurse)
                {:trace_ts, pid, kind, mfa, timestamp} ->
                  emit(%{event: "diagnostic_admission_trace", pid: inspect(pid), kind: inspect(kind),
                    mfa: inspect(mfa, limit: 30, printable_limit: 256), timestamp: timestamp})
                  recurse.(recurse)
                {:DOWN, ^watched, :process, ^service, _} -> :ok
              end
            end
            loop.(loop)
          end)
          receive do
            {:admission_trace_ready, ^tracer} -> :ok
          after 1000 -> raise "diagnostic trace setup failed" end
          spawn(fn ->
            monitored = for pid <- [service, gate], do: {pid, Process.monitor(pid)}
            for _ <- monitored do
              receive do
                {:DOWN, ref, :process, pid, reason} ->
                  true = {pid, ref} in monitored
                  emit(%{event: "diagnostic_actor_down", pid: inspect(pid), reason: inspect(reason),
                    service: inspect(service), gate: inspect(gate),
                    monotonic_ms: System.monotonic_time(:millisecond)})
              end
            end
          end)
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
assert q.HOST.count(needle)==1
hostscript=E/'diagnostic-host.exs';hostscript.write_text(q.HOST.replace(needle,needle+probe,1))
(E/'diagnostic-runner.py').write_text(Path(__file__).read_text())
before=q.inventory();actors=[];host=None;outcomes=[];failure=None;t=time.monotonic()
try:
 host=q.Process(['nix','develop','--command','env','ERL_FLAGS=+S 2:2','MIX_ENV=test','mix','run',str(hostscript),str(E)],E/'host.log','FIXED_H2_HOST ')
 actors.append(host);host.event('ready',90)
 for index in range(6):
  protocol='tls' if index%2==0 else 'h2c'
  outcome=q.concurrent_cohort(E,'r32-'+str(index),protocol,'h2',host,actors,'r32')
  outcomes.append(outcome)
 host.send({'op':'exit'});host.event('exited');host.join()
except Exception:failure=traceback.format_exc()
finally:
 for a in actors:a.dispose()
 after=q.inventory()
 result={'kind':'TARGETED_R32_LIFECYCLE_DIAGNOSTIC_NOT_STAGE_ACCEPTANCE','status':'FAIL' if failure else 'PASS_SIX_COHORTS','executed':len(outcomes),'elapsed_ms':round((time.monotonic()-t)*1000),'failure':failure,'outcomes':outcomes,'lifecycle_events':[e for e in host.seen if str(e.get('event','')).startswith('diagnostic_')] if host else [],'source_stable':before==after,'source_before':before,'source_after':after,'host_sha256':hashlib.sha256(hostscript.read_bytes()).hexdigest()}
 (E/'diagnostic.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({k:v for k,v in result.items() if k not in ['outcomes','source_before','source_after','lifecycle_events']},indent=2))
 print('LIFECYCLE_SUMMARY',json.dumps(result['lifecycle_events'][-6:],indent=2))
sys.exit(1 if failure else 0)
