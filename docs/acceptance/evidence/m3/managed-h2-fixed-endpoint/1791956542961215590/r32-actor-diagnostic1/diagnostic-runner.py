from pathlib import Path
import sys,json,time,traceback,hashlib
ROOT=Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
sys.path.insert(0,str(ROOT/'integration/http_fetch_contract'))
import managed_h2_fixed_qualification as q
E=ROOT/'docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/r32-actor-diagnostic1'
E.mkdir(exist_ok=False)
needle='          gate = :sys.get_state(service).gate\n'
probe='''          spawn(fn ->
            monitored = for pid <- [service, gate], do: {pid, Process.monitor(pid)}
            for _ <- monitored do
              receive do
                {:DOWN, ref, :process, pid, reason} ->
                  true = {pid, ref} in monitored
                  emit(%{event: "diagnostic_actor_down", pid: inspect(pid), reason: inspect(reason),
                    service: inspect(service), gate: inspect(gate),
                    kind: "EXTERNAL_MONITOR_DIAGNOSTIC_NOT_PRODUCT_ACCEPTANCE",
                    monotonic_ms: System.monotonic_time(:millisecond)})
              end
            end
          end)
'''
assert q.HOST.count(needle)==1
hostscript=E/'diagnostic-host.exs';hostscript.write_text(q.HOST.replace(needle,needle+probe,1))
(E/'diagnostic-runner.py').write_text(Path(__file__).read_text())
before=q.inventory();actors=[];host=None;outcome=None;failure=None;t=time.monotonic()
try:
 host=q.Process(['nix','develop','--command','env','ERL_FLAGS=+S 2:2','MIX_ENV=test','mix','run',str(hostscript),str(E)],E/'host.log','FIXED_H2_HOST ')
 actors.append(host);host.event('ready',90)
 outcome=q.concurrent_cohort(E,'h2-to-tls-r32','tls','h2',host,actors,'r32')
 host.send({'op':'exit'});host.event('exited');host.join()
except Exception:failure=traceback.format_exc()
finally:
 for a in actors:a.dispose()
 after=q.inventory()
 result={'kind':'TARGETED_R32_ACTOR_EXIT_DIAGNOSTIC_NOT_STAGE_ACCEPTANCE','status':'FAIL' if failure else 'PASS_ONE_COHORT','elapsed_ms':round((time.monotonic()-t)*1000),'failure':failure,'outcome':outcome,'actor_downs':[e for e in host.seen if e.get('event')=='diagnostic_actor_down'] if host else [],'source_stable':before==after,'source_before':before,'source_after':after,'host_sha256':hashlib.sha256(hostscript.read_bytes()).hexdigest()}
 (E/'diagnostic.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({k:v for k,v in result.items() if k not in ['outcome','source_before','source_after']},indent=2))
sys.exit(1 if failure else 0)
