from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,subprocess
R=Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation');E=Path(Path('/tmp/gaoxy-h2-group-source-evidence-path.txt').read_text().strip());sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=R)
A=json.loads((E/'postreview-complete-audit1.json').read_text());assert A['verdict']=='PASS_PURE_SOURCE_GATES_ONLY'
M=json.loads((E/'implementation-candidate2.json').read_text());assert all(sha((R/p).read_bytes())==h for p,h in M['source_hashes'].items())
assert git('rev-parse','HEAD').decode().strip()=='192745a4104b65d84c8de05d0fefff19b4de90fc'
assert not git('diff','--cached','--name-only','-z')
paths=sorted(M['owned_paths']+[str(p.relative_to(R)) for p in E.rglob('*') if p.is_file()])
assert len(paths)==len(set(paths));subprocess.check_call(['git','add','--',*paths],cwd=R)
assert set(git('diff','--cached','--name-only','-z').decode().rstrip('\0').split('\0'))==set(paths)
entries=[]
for p in paths:
 data=(R/p).read_bytes();oid=git('rev-parse',':'+p).decode().strip();assert git('cat-file','blob',oid)==data,p
 entries.append({'path':p,'sha256':sha(data),'bytes':len(data),'staged_oid':oid})
record={'kind':'GROUP_SOURCE_EXACT_RAW_DISK_INDEX_BYTE_AUDIT','recorded_at_utc':datetime.now(timezone.utc).isoformat(),'verdict':'PASS','candidate_sha256':sha((E/'implementation-candidate2.json').read_bytes()),'postreview_audit_sha256':sha((E/'postreview-complete-audit1.json').read_bytes()),'files':len(entries),'total_bytes':sum(e['bytes'] for e in entries),'mismatches':0,'entries':entries,'audit_output':'Excluded from its own inventory; separately staged/blob-byte checked before commit','git_settings':'Unchanged; evidence directory-local * -text preserves exact bytes','next_stage_evidence':'Preserved unstaged, outside this package'}
out=E/'raw-disk-index-byte-audit1.json';assert not out.exists();out.write_text(json.dumps(record,indent=2)+'\n');rel=str(out.relative_to(R));subprocess.check_call(['git','add','--',rel],cwd=R);oid=git('rev-parse',':'+rel).decode().strip();assert git('cat-file','blob',oid)==out.read_bytes()
expected=set(paths+[rel]);assert set(git('diff','--cached','--name-only','-z').decode().rstrip('\0').split('\0'))==expected
subprocess.check_call(['git','diff','--cached','--check','--',*M['owned_paths']],cwd=R)
staged_tree=git('write-tree').decode().strip();subprocess.check_call(['git','commit','--quiet','-m','feat(proxy): prepare bounded managed H2 group sources'],cwd=R)
head=git('rev-parse','HEAD').decode().strip();tree=git('rev-parse','HEAD^{tree}').decode().strip();assert tree==staged_tree
assert not git('diff','--cached','--name-only','-z')
for e in entries:assert git('rev-parse',head+':'+e['path']).decode().strip()==e['staged_oid']
assert git('cat-file','blob',head+':'+rel)==out.read_bytes()
closure={'kind':'GROUP_SOURCE_ACTUAL_LOCAL_COMMIT_CLOSURE','recorded_at_utc':datetime.now(timezone.utc).isoformat(),'verdict':'PASS_LOCALLY_COMMITTED_PURE_SOURCE_ONLY','commit':head,'tree':tree,'parent':'192745a4104b65d84c8de05d0fefff19b4de90fc','candidate_sha256':sha((E/'implementation-candidate2.json').read_bytes()),'accepted_source_hashes':M['source_hashes'],'postreview_audit_sha256':sha((E/'postreview-complete-audit1.json').read_bytes()),'raw_index_audit_sha256':sha(out.read_bytes()),'audited_files':len(entries),'audited_bytes':record['total_bytes'],'audit_file_separately_byte_verified':True,'committed_paths':len(expected),'index_empty':True,'owned_sources_unchanged':True,'next_stage_evidence':'Preserved unstaged','push_release_deployment':'NOT_RUN','group_activation_accounting':'NOT_RUN ACCOUNTING_NOT_READY','source_repair_sol':1,'failed_spec':1,'astra':'2/2 exhausted'}
closed=E/'local-commit-closure1.json';assert not closed.exists();closed.write_text(json.dumps(closure,indent=2)+'\n');print('commit',head,'tree',tree,'files',len(expected));print('closure',sha(closed.read_bytes()))
