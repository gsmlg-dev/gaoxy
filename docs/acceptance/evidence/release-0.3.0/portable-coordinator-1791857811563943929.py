import datetime,hashlib,json,os,pathlib,signal,subprocess,sys,time
ROOT=pathlib.Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m4-http3')
BASELINE='78de9d0f3bba5a4662717359438eb3d0853a79b4'
POINTER=pathlib.Path('/tmp/gaoxy-030-portable-directory')
def digest(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for block in iter(lambda:f.read(1048576),b''):h.update(block)
 return h.hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def check_identity(base):
 d=json.loads((base/'context/source-identity.json').read_text()); assert git('rev-parse','HEAD').decode().strip()==d['source_sha']; assert digest(base/'context/source.tar')==d['source_archive_sha256'];assert hashlib.sha256(git('show',d['source_sha']+':mix.lock')).hexdigest()==d['root_lock_sha256'];return d
mode=sys.argv[1]
if mode=='prepare':
 base=ROOT/'.audit'/('release-030-'+str(time.time_ns()));context=base/'context';context.mkdir(parents=True);(base/'evidence').mkdir();(base/'artifacts').mkdir()
 source=git('rev-parse','HEAD').decode().strip();assert not git('diff','--name-only','HEAD').strip(),'tracked changes present at archive capture'
 subprocess.run(['git','archive','--format=tar','--output',str(context/'source.tar'),source],cwd=ROOT,check=True,timeout=120)
 recipe='docs/acceptance/evidence/release-0.3.0/portable/recipe/'
 for name in ('Dockerfile','build.py','finalize.py','qualify_runtime.py','run_runtime.py','runtime.py','hostname-probe.exs'):(context/name).write_bytes(git('show',source+':'+recipe+name))
 paths=git('diff','--diff-filter=ACMRT','--name-only','-z',BASELINE,source).decode().split('\0');paths=sorted(p for p in paths if p.endswith(('.ex','.exs')));assert paths
 identity={'version':'0.3.0','source_sha':source,'baseline_sha':BASELINE,'source_archive_sha256':digest(context/'source.tar'),'root_lock_sha256':hashlib.sha256(git('show',source+':mix.lock')).hexdigest(),'changed_elixir_paths':paths}
 (context/'source-identity.json').write_text(json.dumps(identity,indent=2)+'\n');POINTER.write_text(str(base));print(json.dumps({'base':str(base),'identity':identity}),flush=True)
 sys.exit(0)
base=pathlib.Path(POINTER.read_text());identity=check_identity(base)
if mode=='build':
 cmd=['docker','buildx','build','--platform','linux/amd64','--progress','plain','--target','artifact','--output','type=local,dest='+str(base/'artifacts'),str(base/'context')];bound=1790
elif mode=='finalize':cmd=[sys.executable,str(base/'context/finalize.py'),str(base/'artifacts')];bound=30
elif mode=='runtime':cmd=[sys.executable,str(base/'context/qualify_runtime.py'),str(base)];bound=620
else:raise ValueError(mode)
receipt={'kind':'EXACT_COMMIT_PORTABLE_QUALIFICATION','mode':mode,'status':'FAIL','command':cmd,'source_identity':identity,'timeout_seconds':bound,'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
log=base/'evidence'/(mode+'.log');path=base/'evidence'/(mode+'.json');started=time.monotonic();process=None
try:
 with log.open('w') as out:
  process=subprocess.Popen(cmd,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
  process.wait(timeout=bound-10)
 receipt['actual_exit']=process.returncode;assert process.returncode==0,(mode,process.returncode)
 assert check_identity(base)==identity
 receipt['status']='PASS'
except BaseException as e:
 receipt['error']=repr(e)
 if process is not None and process.poll() is None:
  os.killpg(process.pid,signal.SIGKILL);process.wait(timeout=5);receipt['actual_exit']=process.returncode
finally:
 receipt['elapsed_seconds']=time.monotonic()-started;receipt['log_sha256']=digest(log);receipt['completed_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();path.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps({'status':receipt['status'],'receipt':str(path),'log':str(log)}),flush=True)
sys.exit(0 if receipt['status']=='PASS' else 1)
