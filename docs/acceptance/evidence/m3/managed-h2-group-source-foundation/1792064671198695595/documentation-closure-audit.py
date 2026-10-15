from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,subprocess
R=Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation');E=Path(Path('/tmp/gaoxy-h2-group-source-evidence-path.txt').read_text().strip());sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=R)
C=E/'documentation-closure-candidate1.json';M=json.loads(C.read_text());assert sha(C.read_bytes())=='f0535054f8d1f90fd1f162415af6cbf5312f643dcf030905383988ea831802a4'
assert git('rev-parse','HEAD').decode().strip()==M['feature_commit'];assert not git('diff','--cached','--name-only','-z')
assert all(sha((R/p).read_bytes())==h for p,h in M['source_hashes'].items());assert all(sha((R/p).read_bytes())==h for p,h in M['accepted_code_hashes'].items());assert all(sha((R/p).read_bytes())==v['sha256'] for p,v in M['evidence_files'].items())
reviews={}
for name in ['documentation-closure-spec1.json','documentation-closure-code1.json']:
 p=E/name;r=json.loads(p.read_text());assert r['verdict']=='PASS' and r['unresolved_findings']==[] and r['candidate_sha256']==sha(C.read_bytes());reviews[name]=sha(p.read_bytes())
raw_path=str((E/'raw-disk-index-byte-audit1.json').relative_to(R));raw=json.loads((R/raw_path).read_text())
for e in raw['entries']:
 data=git('cat-file','blob',M['feature_commit']+':'+e['path']);assert sha(data)==e['sha256'] and len(data)==e['bytes'];assert git('rev-parse',M['feature_commit']+':'+e['path']).decode().strip()==e['staged_oid']
assert git('cat-file','blob',M['feature_commit']+':'+raw_path)==(R/raw_path).read_bytes()
actual=set(git('diff-tree','--no-commit-id','--name-only','-r','-z',M['feature_commit']).decode().rstrip('\0').split('\0'));assert actual==set(e['path'] for e in raw['entries'])|{raw_path};assert len(actual)==64
record={'kind':'GROUP_SOURCE_DOCUMENTATION_CLOSURE_FRESH_AUDIT','recorded_at_utc':datetime.now(timezone.utc).isoformat(),'verdict':'PASS_DOCUMENTATION_ONLY','candidate_sha256':sha(C.read_bytes()),'reviews':reviews,'document_hashes':M['source_hashes'],'accepted_code_authority_dependency_hashes':M['accepted_code_hashes'],'immutable_evidence_count':len(M['evidence_files']),'feature_commit':M['feature_commit'],'feature_tree':M['feature_tree'],'actual_feature_paths_verified':64,'source_runtime_qualification':'Unchanged accepted source; no extra runtime command implied by docs','gate_evidence':'freshformat/forcedcompile/107tests0failures0skips0exclusions, complete SPEC2/CODE1','counters':'sourceRepairSol1/failedSPEC1/custody1/intendedRED1/unsuccessfulGREEN0; inherited unchanged Astra2/2 exhausted','live_group_accounting':'NOT_RUN ACCOUNTING_NOT_READY; no reserve','publication_deployment':'NOT_RUN','audit_script_sha256':sha(Path(__file__).read_bytes())}
out=E/'documentation-closure-complete-audit1.json';assert not out.exists();out.write_text(json.dumps(record,indent=2)+'\n')
untracked=git('ls-files','--others','--exclude-standard','-z','--',str(E.relative_to(R))).decode().rstrip('\0').split('\0');assert all(untracked)
paths=sorted(M['owned_document_paths']+untracked);assert len(paths)==len(set(paths));subprocess.check_call(['git','add','--',*paths],cwd=R)
assert set(git('diff','--cached','--name-only','-z').decode().rstrip('\0').split('\0'))==set(paths)
entries=[]
for p in paths:
 data=(R/p).read_bytes();oid=git('rev-parse',':'+p).decode().strip();assert git('cat-file','blob',oid)==data;entries.append({'path':p,'bytes':len(data),'sha256':sha(data),'staged_oid':oid})
audit=E/'documentation-closure-raw-byte-audit1.json';assert not audit.exists();audit.write_text(json.dumps({'kind':'GROUP_SOURCE_DOC_CLOSURE_DISK_INDEX_BYTES','verdict':'PASS','entries':entries,'files':len(entries),'bytes':sum(e['bytes'] for e in entries),'mismatches':0,'self_output':'Separately checked after staging','candidate_sha256':sha(C.read_bytes())},indent=2)+'\n');rel=str(audit.relative_to(R));subprocess.check_call(['git','add','--',rel],cwd=R);assert git('show',':'+rel)==audit.read_bytes()
subprocess.check_call(['git','diff','--cached','--check','--',*M['owned_document_paths']],cwd=R)
expected_tree=git('write-tree').decode().strip();subprocess.check_call(['git','commit','--quiet','-m','docs(proxy): close managed H2 group source acceptance'],cwd=R);head=git('rev-parse','HEAD').decode().strip();tree=git('rev-parse','HEAD^{tree}').decode().strip();assert tree==expected_tree;assert not git('diff','--cached','--name-only','-z')
for e in entries:assert git('rev-parse',head+':'+e['path']).decode().strip()==e['staged_oid']
assert git('cat-file','blob',head+':'+rel)==audit.read_bytes()
assert all(sha((R/p).read_bytes())==h for p,h in M['accepted_code_hashes'].items())
closure={'kind':'GROUP_SOURCE_ACTUAL_DOCUMENTATION_CLOSURE_COMMIT','recorded_at_utc':datetime.now(timezone.utc).isoformat(),'verdict':'PASS_LOCAL_SOURCE_PACKAGE_CLOSED','feature_commit':M['feature_commit'],'documentation_commit':head,'documentation_tree':tree,'candidate_sha256':sha(C.read_bytes()),'fresh_doc_audit_sha256':sha(out.read_bytes()),'raw_byte_audit_sha256':sha(audit.read_bytes()),'staged_files':len(entries)+1,'mismatches':0,'index_empty':True,'owned_package_closed':True,'next_stage_untracked':'preserved separately','push_release_deployment':'NOT_RUN','live_groups':'NOT_RUN ACCOUNTING_NOT_READY'}
Path('/tmp/gaoxy-h2-group-source-docclosure-commit.json').write_text(json.dumps(closure,indent=2)+'\n');print(json.dumps(closure,indent=2))
