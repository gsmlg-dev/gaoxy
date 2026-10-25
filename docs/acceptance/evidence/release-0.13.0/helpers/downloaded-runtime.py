import hashlib,importlib.metadata,json,os,signal,subprocess,sys,tarfile,time
from pathlib import Path
ROOT=Path.cwd();E=Path(__file__).resolve().parent;SHA='bd325eb408d4566b807bcef9fdaf1a2b1ad83a2d'
def digest(data):return hashlib.sha256(data).hexdigest()
invocation=json.loads((E/'artifact-invocation-keyword.json').read_text())
assert invocation['exit']==0 and invocation['verifier']['status']=='PASS',invocation
artifact_receipt=Path(invocation['verifier']['receipt']);verified=json.loads(artifact_receipt.read_text());assets=artifact_receipt.parent
assert verified['status']=='PASS' and verified['source_commit']==SHA and verified['remote_tag_sha']==SHA
assert len(verified['packages'])==6 and len(verified['assets'])==8 and verified['sha256sums_entries']==7
archive=assets/'gaoxy-0.13.0-linux-x86_64.tar.gz'
assert digest(archive.read_bytes())==verified['assets'][archive.name]['sha256']
runtime=E/'downloaded-runtime';assert not runtime.exists();runtime.mkdir()
with tarfile.open(archive,'r:gz') as package:
 members=package.getmembers();assert len(members)<100000 and sum(m.size for m in members)<1024*1024*1024
 package.extractall(runtime,filter='data')
release=runtime/'bin/gaoxy';assert release.is_file() and os.access(release,os.X_OK)
host_source=ROOT/'.audit/release-0.9.0-public-runtime/receipt.json';host=json.loads(host_source.read_text())
assert host['status']=='PASS'
env=dict(os.environ);env.update(host['environment']);env.update(ELIXIR_ERL_OPTIONS='+S 4:4',SSL_CERT_FILE='/etc/ssl/certs/ca-certificates.crt',PYTHONDONTWRITEBYTECODE='1')
script_names=['scripts/release-smoke.py','scripts/gateway-release-smoke.py','scripts/h3-release-smoke.py','scripts/generate-fixtures.sh','apps/gaoxy_http/test/support/mixed_http_peer.py','integration/http3/quinn_peer.py','integration/http3/release_peer/Cargo.toml','integration/http3/release_peer/Cargo.lock','integration/http3/release_peer/src/main.rs','integration/http3/upstream/origin.py','integration/http3/upstream/run.py']
scripts={}
for name in script_names:
 data=(ROOT/name).read_bytes();committed=subprocess.check_output(['git','show',f'{SHA}:{name}'],cwd=ROOT,timeout=30);assert data==committed,name;scripts[name]=digest(data)
receipt={'status':'FAIL','source_commit':SHA,'version':'0.13.0','artifact_receipt':str(artifact_receipt),'archive_sha256':digest(archive.read_bytes()),'runtime':str(runtime),'release':str(release),'safe_extraction_filter':'data','archive_members':len(members),'host_environment_source':str(host_source),'host_environment_scope':'process-local Nix host compatibility; downloaded Ubuntu runtime qualification only','environment':{k:env[k] for k in ['LD_LIBRARY_PATH','NIX_LD_LIBRARY_PATH','ERL_FLAGS','ELIXIR_ERL_OPTIONS','SSL_CERT_FILE']},'script_hashes':scripts,'runner_sha256':digest(Path(__file__).read_bytes()),'python':sys.version,'python_dependencies':{n:importlib.metadata.version(n) for n in ['aioquic','h2','hpack','hyperframe']},'checks':[],'processes_stopped':True}
def save():(E/'runtime-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
core='import importlib.util,sys;from pathlib import Path;s=importlib.util.spec_from_file_location("release_smoke","scripts/release-smoke.py");m=importlib.util.module_from_spec(s);s.loader.exec_module(m);m.release=Path(sys.argv[1]);m.main()'
commands=[('core',[sys.executable,'-B','-c',core,str(release)],3,150),('gateway',[sys.executable,'-B','scripts/gateway-release-smoke.py','--release',str(release)],7,150),('h3',[sys.executable,'-B','scripts/h3-release-smoke.py','--release',str(release),'--evidence',str(E/'downloaded-h3')],3,750)]
save()
try:
 for name,command,count,timeout in commands:
  entry={'name':name,'command':command,'expected_checks':count,'status':'RUNNING','timeout_seconds':timeout,'log':str(E/(name+'.log'))};receipt['checks'].append(entry);receipt['processes_stopped']=False;save();started=time.monotonic()
  with (E/(name+'.log')).open('w') as log:
   process=subprocess.Popen(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True);entry['pid']=entry['process_group']=process.pid
   try:entry['exit']=process.wait(timeout=timeout)
   except BaseException:
    os.killpg(process.pid,signal.SIGTERM)
    try:process.wait(timeout=5)
    except subprocess.TimeoutExpired:os.killpg(process.pid,signal.SIGKILL);process.wait(timeout=5)
    entry['exit']=process.returncode;raise
  entry['seconds']=round(time.monotonic()-started,2)
  try:os.killpg(process.pid,0)
  except ProcessLookupError:entry['process_group_gone']=True
  else:
   os.killpg(process.pid,signal.SIGTERM);entry['process_group_gone']=False
  receipt['processes_stopped']=entry['process_group_gone'];save()
  assert entry['exit']==0 and entry['process_group_gone'],entry
  output=(E/(name+'.log')).read_text()
  if name=='core':assert 'PASS portable release TCP/TLS/UDP' in output and '; 3 transports' in output
  elif name=='gateway':assert 'PASS standalone gateway release readiness' in output and '; 7 exchanges' in output
  else:
   detail=json.loads((E/'downloaded-h3/result.json').read_text());assert detail['status']=='PASS' and len(detail['checks'])==3 and all(x['status']=='PASS' for x in detail['checks'])
   assert all(code==0 for code in detail['child_exits'].values()),detail['child_exits'];entry['h3_child_exits']=detail['child_exits'];entry['ports_rebound']=True
  entry.update(status='PASS',verified_checks=count,log_sha256=digest((E/(name+'.log')).read_bytes()));save();print(json.dumps(entry),flush=True)
 receipt.update(status='PASS',verified_checks=sum(c['verified_checks'] for c in receipt['checks']))
except BaseException as error:
 receipt['error']=f'{type(error).__name__}: {error}';raise
finally:save()
print(json.dumps({'status':receipt['status'],'checks':receipt.get('verified_checks'),'receipt':str(E/'runtime-receipt.json')}),flush=True)
