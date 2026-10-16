from pathlib import Path
import hashlib,json,subprocess,sys
r=Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
e=r/'docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423'
collector=e/'command-collector2.py'
candidate=json.loads((e/'final-stage-candidate2.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert all(sha(r/n)==v for n,v in candidate['sources'].items())
assert all(sha(e/n)==v for n,v in candidate['evidence'].items())
base=['nix','develop','--command','env','ERL_FLAGS=+S 2:2','MIX_ENV=test','unbuffer']
common=['mix','test','--warnings-as-errors','--max-cases','1']
a=['apps/gaoxy_proxy/test/'+n+'.exs' for n in ['managed_h2_fixed_generation_test','managed_h2_generation_exclusion_test','managed_h2_fixed_endpoint_test','managed_h2_fixed_lifecycle_test','managed_h2_fixed_release_order_test']]
b=['apps/gaoxy_proxy/test/'+n+'.exs' for n in ['upstream_transport_h2_identity_test','upstream_transport_handoff_test','upstream_transport_generation_test','upstream_transport_generation_failure_test','managed_generation_checked_capture_test','managed_generation_accounting_test']]
c=['apps/gaoxy_http/test/'+n+'.exs' for n in ['generation_endpoint_validation_test','generation_resource_consistency_test','generation_resources_test','generation_checked_capture_test','generation_release_deadline_test','generation_test','http2_worker_startup_test','http2_stale_start_test']]
assert len(set(a+b+c))==len(a+b+c)==19
format_files=['apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex','apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs','apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs',str(e.relative_to(r)/'fixed-generation-browser-host2.exs'),str(e.relative_to(r)/'fixed-generation-browser-cohort1.exs')]
route=['env','GIT_CONFIG_COUNT=1','GIT_CONFIG_KEY_0=url.file:///tmp/gaoxy-consumer-local-git-diagnosis1-f2s_326d/locked-source.git.insteadOf','GIT_CONFIG_VALUE_0=https://github.com/mtrudel/thousand_island.git']
commands=[('final-format1','static',base+['mix','format','--check-formatted']+format_files,None),('final-compile1','static',base+['mix','compile','--force','--warnings-as-errors'],None),('final-syntax1','static',['python3','-B','/tmp/gaoxy-fixed-generation-final-syntax1.py'],None),('final-tests-a1','green',base+common+a,None),('final-tests-b1','green',base+common+b,None),('final-tests-c1','green',base+common+c,None),('final-core-consumer1','green',base+route+['bash','scripts/external-consumer.sh'],1),('final-http-consumer1','green',base+route+['bash','scripts/http-consumer.sh'],2)]
results=[]
for name,kind,command,expected in commands:
    print(json.dumps({'starting':name,'command':command}),flush=True)
    completed=subprocess.run(['python3','-B',str(collector),'--name',name,'--kind',kind,'--']+command,cwd=r)
    d=json.loads((e/(name+'.json')).read_text())
    results.append({'name':name,'receipt_sha256':sha(e/(name+'.json')),'log_sha256':d['log_sha256'],'tests':d['tests'],'failures':d['failures'],'verdict':d['verdict']})
    if completed.returncode!=0:raise SystemExit(completed.returncode)
    assert d['verdict']=='PASS' and d['actual_exit']==0 and d['process_joined'] and not d['forced'] and not d['process_group_remaining'] and not d['warnings'] and d['source_stable']
    assert d['failures']==d['skipped']==d['excluded']==0
    if kind=='green':assert d['tests']>0
    if expected is not None:assert d['tests']==expected
    assert all(candidate['sources'].get(n)==v for n,v in d['source_before'].items())
assert all(sha(r/n)==v for n,v in candidate['sources'].items())
assert all(sha(e/n)==v for n,v in candidate['evidence'].items())
v={'status':'PASS','candidate':'final-stage-candidate2.json','candidate_sha256':sha(e/'final-stage-candidate2.json'),'commands':results,'unique_test_files':a+b+c,'unique_file_count':19,'union_test_count':sum(x['tests'] for x in results if x['name'].startswith('final-tests-')),'consumers_separate_test_count':3,'browser':'PENDING separate fresh browser command and image review','immutable_candidate_matches_after':True}
with (e/'final-command-gates1.json').open('x') as f:json.dump(v,f,indent=2);f.write('\n')
print(json.dumps(v),flush=True)
