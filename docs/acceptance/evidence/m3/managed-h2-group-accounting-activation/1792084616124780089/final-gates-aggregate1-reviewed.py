from pathlib import Path
import hashlib,json,re,time
R=Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E=R/'docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
cpath=E/'postactivation-full-review-candidate2.json'
c=json.loads(cpath.read_text());source=c['source_manifest']
adopt=json.loads((E/'full-review2-adoption1.json').read_text())
assert sha(cpath)=='2429bbdecb1bba716627af84f24c59209a10d953f985acace590736978e0fb7e'
assert len(source)==198
assert {p:sha(R/p) for p in source}==source
assert adopt['candidate_sha256']==sha(cpath)
for p,s in adopt['reports'].items():assert sha(E/p)==s
for k in ['collector','required_command_gates','browser_wrapper','counter_ledger']:
 item=c[k]; assert sha(E/item['path'])==item['sha256']
gates=(E/c['required_command_gates']['path']).read_text().splitlines()
assert len(gates)==25 and len(set(gates))==25
rows=[]
for gate in gates:
 paths=[p for p in E.glob(gate+'-*.json') if re.fullmatch(re.escape(gate)+r'-(\d+)\.json',p.name) and int(re.fullmatch(re.escape(gate)+r'-(\d+)\.json',p.name)[1])>=adopt['run_not_before_ns']]
 assert paths,('missing gate',gate)
 p=max(paths,key=lambda p:int(re.search(r'-(\d+)\.json$',p.name)[1]));d=json.loads(p.read_text())
 assert d['gate']==gate and d['actual_exit']==0 and not d['timed_out'] and d['process_joined'],(gate,'exit/join')
 assert d['source_stable'] and d['source_before']==source and d['source_after']==source,(gate,'source')
 assert d['collector_sha256']==c['collector']['sha256'] and not d['unexpected_warnings'],(gate,'collector/warnings')
 assert d['failures']==d['skips']==d['exclusions']==0 and d['zero_skip_exclusion_configuration'],(gate,'counts')
 assert gate in ['fresh-format','fresh-compile'] or d['tests_executed']>0,(gate,'nonzero')
 lp=R/d['log'];assert sha(lp)==d['log_sha256'] and lp.stat().st_size==d['log_bytes'],(gate,'log custody')
 rows.append({'gate':gate,'receipt':p.name,'receipt_sha256':sha(p),'log':d['log'],'log_sha256':d['log_sha256'],'tests_executed':d['tests_executed'],'failures':0,'skips':0,'exclusions':0,'actual_exit':0,'joined':True,'source_stable':True,'elapsed_ms':d['elapsed_ms']})
paths=[p for p in E.glob('browser-command2-*.json') if int(re.search(r'-(\d+)\.json$',p.name)[1])>=adopt['run_not_before_ns']]
assert paths,'missing browser'
p=max(paths,key=lambda p:int(re.search(r'-(\d+)\.json$',p.name)[1]));b=json.loads(p.read_text())
assert b['actual_exit']==0 and b['process_joined'] and not b['timed_out']
assert b['source_stable'] and b['source_before']==source and b['source_after']==source
assert b['collector_sha256']==c['browser_wrapper']['sha256'] and b['executed_completed_cases']==3 and b['suite_status']=='PASS'
assert sha(R/b['log'])==b['log_sha256'] and sha(R/b['qualification'])==b['qualification_sha256']
q=json.loads((R/b['qualification']).read_text());assert q['status']=='PASS' and q['executed']==3 and q['source_stable']
result={'kind':'FRESH_GROUP_ACCOUNTING_ACTIVATION_GATE_AGGREGATE','status':'PASS_COMMANDS_AND_CANONICAL_BROWSER','candidate':cpath.name,'candidate_sha256':sha(cpath),'source_manifest':source,'source_count':len(source),'reviews_adoption':'full-review2-adoption1.json','reviews_adoption_sha256':sha(E/'full-review2-adoption1.json'),'gates':rows,'gate_count':len(rows),'executed_test_invocations_including_repeated_fixtures':sum(r['tests_executed'] for r in rows),'browser':{'receipt':p.name,'receipt_sha256':sha(p),'qualification':b['qualification'],'qualification_sha256':b['qualification_sha256'],'executed_completed_cases':3,'actual_exit':0,'joined':True},'historical_cleanup':'UNCONFIRMED_WITH_RETAINED_FAILURE','counter_ledger':c['counter_ledger'],'astra':'2/2 exhausted unchanged','remaining':'documentation rebind and independent closure, index/commit byte custody and local commit'}
out=E/'fresh-final-gates-aggregate1.json'
with out.open('x') as f:f.write(json.dumps(result,indent=2)+'\n')
print(out,sha(out));print('commands',len(rows),'executed_test_invocations',result['executed_test_invocations_including_repeated_fixtures'],'browser_completed',3)
