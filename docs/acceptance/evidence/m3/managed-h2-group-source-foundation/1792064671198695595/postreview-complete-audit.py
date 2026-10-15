from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,re,subprocess
R=Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E=Path(Path('/tmp/gaoxy-h2-group-source-evidence-path.txt').read_text().strip())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
C=E/'implementation-candidate2.json'; candidate=json.loads(C.read_text())
assert sha(C)=='081310a76ca7c98709237957f933bb2978d1fc644c8ee1a9b9170bde5f2a7bdf'
assert all(sha(R/p)==h for p,h in candidate['source_hashes'].items())
assert all(sha(R/p)==v['sha256'] and (R/p).stat().st_size==v['bytes'] for p,v in candidate['evidence_files'].items())
invocation=json.loads((E/'postreview-invocation1.json').read_text())
assert invocation['source_hashes']==candidate['source_hashes']
reviews={}
for name in ['implementation-spec2.json','implementation-code1.json']:
 p=E/name; report=json.loads(p.read_text())
 assert report['verdict']=='PASS' and report['unresolved_findings']==[],name
 assert report['candidate_sha256']==sha(C),name
 assert invocation['review_hashes'][name]==sha(p),name
 reviews[name]=sha(p)
results={}
for gate,command in [('fresh-format','format'),('fresh-compile','compile'),('fresh-tests','complete_tests')]:
 paths=list(E.glob(gate+'-*.json'));assert len(paths)==1,(gate,paths)
 p=paths[0];record=json.loads(p.read_text());log=R/record['log']
 assert record['argv']==candidate['commands'][command]
 assert record['actual_exit']==0 and record['timed_out'] is False and record['process_joined'] is True
 assert record['source_stable'] is True and record['source_before']==record['source_after']
 assert all(h==candidate['source_hashes'][path] for path,h in record['source_before'].items())
 assert record['log_sha256']==sha(log) and record['log_bytes']==log.stat().st_size
 assert record['collector_sha256']==sha(E/'command-runner.py')
 assert record['skips']==0 and record['exclusions']==0 and record['failures']==0
 assert record['recorded_at_utc']>invocation['recorded_at_utc']
 if gate=='fresh-tests':
  assert record['tests_executed']==107 and record['counts']==[{'tests':107,'failures':0,'skipped':0,'excluded':0,'executed':107}]
  clean=re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]','',log.read_text())
  assert re.findall(r'(\d+) tests?, (\d+) failures?',clean)==[('107','0')]
 results[gate]={'receipt':str(p.relative_to(R)),'receipt_sha256':sha(p),'log_sha256':sha(log),'log_bytes':log.stat().st_size,'actual_exit':record['actual_exit'],'tests_executed':record['tests_executed'],'failures':record['failures'],'skips':record['skips'],'exclusions':record['exclusions'],'source_stable':True,'process_joined':True}
assert sha(R/'codex-prompt.md')=='87112f8eb621966e0062c8611054bda49af0508693c46fa621de87a2b774038c'
assert sha(Path('/home/gao/Workspace/gsmlg-opt/gaoxy/gaoxy-m1.1-fix-prompt.md'))=='7982874aacafe8bc4f4814740f25d1bd1e5bb35cbdc3938338ab132f2cdf9f1f'
record={'audit_script_sha256':sha(Path(__file__)),'kind':'GROUP_SOURCE_FOUNDATION_COMPLETE_POSTREVIEW_AUDIT','recorded_at_utc':datetime.now(timezone.utc).isoformat(),'verdict':'PASS_PURE_SOURCE_GATES_ONLY','head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),'candidate_sha256':sha(C),'review_hashes':reviews,'source_hashes':candidate['source_hashes'],'immutable_evidence_count':len(candidate['evidence_files']),'immutable_evidence_unchanged':True,'fresh_gates':results,'total_test_count':107,'failures':0,'skips':0,'exclusions':0,'source_foundation_counters':{'implementation':1,'repair_sol':1,'failed_spec':1,'unsuccessful_green':0,'custody_harness_failure':1,'intended_red':1,'astra':'2/2 exhausted'},'inherited_counters':'unchanged; candidate + predecessor ledgers retain all histories','local_commit':'NOT_YET_CREATED','runtime_scope':'pure source only; no live groups/probes enabled','group_accounting':'ACCOUNTING_NOT_READY, reserves PROPOSED_UNPROVED','predecessor_negative_tls_cleanup':'UNCONFIRMED_WITH_RETAINED_FAILURE','publication_deployment_production':'NOT_RUN','preserved_prompts':True}
out=E/'postreview-complete-audit1.json';assert not out.exists();out.write_text(json.dumps(record,indent=2)+'\n');print(out.name,sha(out));print('PASS: frozen33 sources,43 evidence entries; SPEC2+CODE1; fresh format/compile/107 tests,0 failures/skips/exclusions')
