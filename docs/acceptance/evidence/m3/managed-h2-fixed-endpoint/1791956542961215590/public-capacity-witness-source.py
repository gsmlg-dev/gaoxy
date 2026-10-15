import argparse,hashlib,json,pathlib,subprocess,sys,time,traceback
ROOT=pathlib.Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
sys.path.insert(0,str(ROOT/'integration/http_fetch_contract'))
from managed_h2_fixed_qualification import Process,PYTHON,PEER,PACKAGES,inventory,require
from h2_0214_qualification import WRAPPER,identity_check
HOST=WRAPPER.split('[before_path, after_path, runner | args]')[0]+r'''
defmodule PublicCapacityWitness do
 def emit(value), do: IO.puts("CAPACITY_WITNESS " <> JSON.encode!(value))
 def run do
  [dir] = System.argv()
  HTTPFetch0214Identity.record(Path.join(dir,"loaded-before.json"))
  emit(%{event: "ready", elixir: System.version(), otp: System.otp_release()})
  Enum.reduce(IO.stream(:stdio,:line), %{scope: nil, promises: %{}}, fn line,state ->
   cmd = JSON.decode!(line)
   case cmd["op"] do
    "open" ->
     nil = state.scope
     origin = "http://localhost:#{cmd["port"]}"
     {:ok,scope} = HTTP.ManagedTransport.open(origin: origin, connect_address: {127,0,0,1},
       http_version: :h2c, tls_backend: :ssl, http2_profile: :native_v1,
       max_requests: 32, max_connections: 2, max_pending: 0, idle_timeout: 5000)
     emit(%{event: "opened"})
     Map.merge(state,%{scope: scope,origin: origin})
    "fetch" ->
     p=HTTP.fetch(state.origin<>cmd["target"],transport_scope: state.scope,
       redirect: :manual, decode_body: false, stream_response: true,
       timeout: 10000, connect_timeout: 5000)
     original=HTTP.Promise.completion(p)
     true=match?(%HTTP.RequestCompletion{},original)
     emit(%{event: "fetch_started",id: cmd["id"], original_completion_bound: true})
     %{state|promises: Map.put(state.promises,cmd["id"],{p,original})}
    "snapshot" ->
     {:ok,s}=HTTP.ManagedTransport.snapshot(state.scope,1000)
     emit(%{event: "snapshot",active_requests: s.active_requests, preparing_requests: s.preparing_requests,
       connections: s.connections, pending: s.pending,limits: s.limits})
     state
    "await" ->
     {p,original}=Map.fetch!(state.promises,cmd["id"])
     result=HTTP.Promise.await(p,5000)
     true=HTTP.Promise.completion(p) === original
     detail=case result do
       {:error,{:transport_scope_capacity,:connections}} ->
        %{raw_result: inspect(result),exact_capacity_connections: true}
       %HTTP.Response{status: 200}=response ->
        ""=body=HTTP.Response.read_all(response)
        %{status: response.status,body_bytes: byte_size(body),http_version: inspect(response.http_version)}
     end
     :ok=HTTP.RequestCompletion.await(original,5000)
     :ok=HTTP.RequestCompletion.await(original,0)
     emit(Map.merge(detail,%{event: "result", id: cmd["id"],original_completion_unchanged: true,cleanup: ":ok", repeated_cleanup: ":ok"}))
     state
    "retire" ->
     {:ok,receipt}=HTTP.ManagedTransport.retire(state.scope,mode: :graceful)
     :ok=HTTP.ManagedTransport.await_retired(receipt,5000)
     :ok=HTTP.ManagedTransport.await_retired(receipt,0)
     emit(%{event: "retired",result: ":ok",repeated: ":ok"})
     state
    "exit" ->
     HTTPFetch0214Identity.record(Path.join(dir,"loaded-after.json"))
     emit(%{event: "exited"})
     state
   end
  end)
 end
end
PublicCapacityWitness.run()
'''
p=argparse.ArgumentParser();p.add_argument('--evidence',type=pathlib.Path,required=True);a=p.parse_args()
d=a.evidence.resolve();d.mkdir(parents=True,exist_ok=False)
source_before=inventory();start=time.monotonic();actors=[];rows=[];passed=False;failure=None;command=None
(d/'public-capacity-host.exs').write_text(HOST)
try:
 peer=Process([str(PYTHON),str(PEER),'--protocol','h2c','--manual','--max-streams','1'],d/'peer.log');actors.append(peer)
 ready=peer.event('ready');require(ready['identity']['packages']==PACKAGES,'peer identity mismatch')
 command=['nix','develop','--command','env','ERL_FLAGS=+S 2:2','MIX_ENV=test','mix','run','--no-compile',str(d/'public-capacity-host.exs'),str(d)]
 host=Process(command,d/'host.log','CAPACITY_WITNESS ');actors.append(host);host.event('ready',90)
 host.send(dict(op='open',port=ready['port']));host.event('opened')
 requests=[]
 for i in range(2):
  target='/hold/'+str(i);host.send(dict(op='fetch',id=str(i),target=target));rows.append(host.event('fetch_started'))
  req=peer.event('request',predicate=lambda event,t=target:event['target']==t);requests.append(req)
  peer.event('settings_ack',predicate=lambda event,c=req['connection']:event['connection']==c and event['max_streams']==1)
 require(len({r['connection'] for r in requests})==2,'held C2 identity mismatch')
 host.send(dict(op='snapshot'));s=host.event('snapshot');rows.append(s)
 require(s['connections']==2 and s['active_requests']==2 and s['preparing_requests']==0 and s['pending']==0,'public C2 ledger mismatch')
 host.send(dict(op='fetch',id='refused',target='/refused'));rows.append(host.event('fetch_started'))
 host.send(dict(op='await',id='refused'));r=host.event('result');rows.append(r)
 require(r['raw_result']=='{:error, {:transport_scope_capacity, :connections}}' and r['exact_capacity_connections'],'raw capacity result mismatch')
 for i,req in enumerate(requests):
  peer.send(dict(op='respond',connection=req['connection'],stream=req['stream'],status=200,fields=[['content-length','0']],body64='',ended=True));peer.event('command',predicate=lambda event,stream=req['stream']:event.get('stream')==stream and event.get('op')=='respond')
  host.send(dict(op='await',id=str(i)));rows.append(host.event('result'))
 host.send(dict(op='snapshot'));s=host.event('snapshot');rows.append(s);require(s['active_requests']==0 and s['preparing_requests']==0 and s['pending']==0,'public requests not joined')
 require(not any(e.get('event')=='request' and e['target']=='/refused' for e in peer.seen),'refused request reached peer')
 host.send(dict(op='retire'));rows.append(host.event('retired'))
 for c in (1,2):rows.append(peer.event(('eof','connection_reset'),predicate=lambda event,c=c:event['connection']==c))
 peer.send(dict(op='stop'));joined=peer.event('joined');rows.append(joined)
 require(joined==dict(event='joined',accepts=2,requests=2,forced=0,live=0,failed=False),'peer join/no replay mismatch');peer.join()
 host.send(dict(op='exit'));host.event('exited');host.process.stdin.close();host.join()
 identity_check(json.loads((d/'loaded-before.json').read_text()),json.loads((d/'loaded-after.json').read_text()))
 require(source_before==inventory(),'source changed during witness');passed=True
except Exception:failure=traceback.format_exc()
finally:
 for actor in actors:actor.dispose()
 after=inventory()
 receipt=dict(kind='PUBLIC_C2_RAW_PROMISE_CAPACITY_WITNESS',status='PASS' if passed else 'FAIL',command=command,
  executed=1 if passed else 0,elapsed_ms=round((time.monotonic()-start)*1000),events=rows,failure=failure,
  source_before=source_before,source_after=after,source_stable=source_before==after,
  script_sha256=hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),host_sha256=hashlib.sha256(HOST.encode()).hexdigest(),
  assertions_unchanged=True,private_dependency_probe=False,exclusions=[],skips=[])
 (d/'qualification.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print(json.dumps({k:v for k,v in receipt.items() if k not in ['source_before','source_after','events']},indent=2))
sys.exit(0 if passed else 1)
