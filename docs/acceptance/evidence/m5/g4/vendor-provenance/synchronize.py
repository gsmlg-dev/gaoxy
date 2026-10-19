from pathlib import Path
import datetime, hashlib, json, subprocess, tempfile
root=Path.cwd(); vendor=root/'vendor/websock_adapter'; evidence=root/'.audit/m5/vendor-provenance'
manifest=json.loads((vendor/'SOURCE.json').read_text())
files=[name for name in manifest['sha256'] if name!='gaoxy.patch']; original_files=[name for name in files if name!='test/gaoxy_dispatch_test.exs']
head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
base=subprocess.check_output(['git','rev-parse','4c6f089'],text=True).strip()
sha=lambda data:hashlib.sha256(data).hexdigest()
current={name:(vendor/name).read_bytes() for name in files}
upstream={name:subprocess.check_output(['git','show',f'{base}:vendor/websock_adapter/{name}']) for name in original_files}
dispatch=b'  defp tuple_for(Gaoxy.PlugAdapter, websock, state, opts), do: {websock, state, opts}\n'
assert upstream['lib/websock_adapter.ex'].count(dispatch)==1
upstream['lib/websock_adapter.ex']=upstream['lib/websock_adapter.ex'].replace(dispatch,b'')
assert sha(upstream['lib/websock_adapter/upgrade_validation.ex'])==manifest.get('upstream_sha256',manifest['sha256'])['lib/websock_adapter/upgrade_validation.ex']
commands=[]
def git(where,*args):
 result=subprocess.run(['git',*args],cwd=where,capture_output=True,check=True)
 commands.append({'cwd':str(where.relative_to(root)), 'command':['git',*args],'exit':result.returncode,'stdout':result.stdout.decode(),'stderr':result.stderr.decode()})
 return result.stdout
workspace=Path(tempfile.mkdtemp(prefix='canonical-',dir=evidence))
for name,data in upstream.items():
 path=workspace/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
git(workspace,'init','--quiet');git(workspace,'add','.')
for name,data in current.items():
 path=workspace/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
git(workspace,'add','--intent-to-add','test/gaoxy_dispatch_test.exs')
patch=git(workspace,'-c','core.quotePath=false','diff','--binary','--full-index','--no-ext-diff','--no-renames','--src-prefix=a/','--dst-prefix=b/')
assert patch.count(b'diff --git ')==3,patch
(vendor/'gaoxy.patch').write_bytes(patch)
check=Path(tempfile.mkdtemp(prefix='apply-',dir=evidence))
for name,data in upstream.items():
 path=check/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
git(check,'init','--quiet')
git(check,'apply','--check',str(vendor/'gaoxy.patch'))
git(check,'apply',str(vendor/'gaoxy.patch'))
for name,data in current.items():
 assert (check/name).read_bytes()==data,name
 assert (vendor/name).read_bytes()==data,('source changed during ownership',name)
manifest['fork_commit_role']='Historical dispatch-only fork; the current downstream snapshot also includes M5 immutable-metadata early validation.'
manifest['patch']={'file':'gaoxy.patch','base_commit':manifest['upstream_commit'],'format':'Canonical git diff --binary --full-index from upstream; not a commit mail patch.','files':['lib/websock_adapter.ex','lib/websock_adapter/upgrade_validation.ex','test/gaoxy_dispatch_test.exs']}
manifest['sha256']={name:sha(data) for name,data in current.items()}
manifest['sha256']['gaoxy.patch']=sha(patch)
manifest['upstream_sha256']={name:sha(data) for name,data in upstream.items()}
(vendor/'SOURCE.json').write_text(json.dumps(manifest,indent=2)+'\n')
receipt={'task':'M5 G4 vendor provenance synchronization','status':'PASS','timestamp_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'worktree':str(root),'head':head,'upstream_commit':manifest['upstream_commit'],'historical_dispatch_fork_commit':manifest['fork_commit'],'offline_reconstruction':{'repository_baseline':base,'method':'Read vendor files from repository baseline; remove the single Gaoxy dispatch clause from websock_adapter.ex; omit the downstream regression test. upgrade_validation.ex is unchanged upstream at that baseline.','upstream_sha256':manifest['upstream_sha256']},'commands':commands,'applied_files_sha256':{name:sha((check/name).read_bytes()) for name in files},'patch_sha256':sha(patch),'checks':{'git_apply_check':'PASS','git_apply':'PASS','all_snapshot_files_match':'PASS','runtime_test_files_unchanged_during_task':'PASS'},'runtime_tests':'NOT RUN; parent owns build/runtime verification','sol_repair_rounds':1,'astra_recovery_rounds_received':2,'shutdown':'All owned commands completed; no build or runtime processes started'}
(evidence/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'status':'PASS','verified_files':len(files),'patch_sha256':sha(patch),'evidence':str(evidence)}))
