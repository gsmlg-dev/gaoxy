from pathlib import Path
import hashlib,json,collections,os,re
r=Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
e=r/'docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
c=json.loads((e/'browser-diagnostic4-candidate2.json').read_text())
assert all(sha(r/n)==v for n,v in c['sources'].items())
assert all(sha(e/n)==v for n,v in c['evidence'].items())
g=json.loads((e/'final-command-gates1.json').read_text());assert g['status']=='PASS'
for item in g['commands']:
 p=e/(item['name']+'.json');assert sha(p)==item['receipt_sha256'];d=json.loads(p.read_text())
 assert sha(e/d['log'])==d['log_sha256']==item['log_sha256']
 assert d['verdict']=='PASS' and d['actual_exit']==0 and d['source_stable'] and not d['warnings'] and d['process_joined'] and not d['forced'] and not d['process_group_remaining']
 assert d['failures']==d['skipped']==d['excluded']==0
 assert all(c['sources'].get(n)==v for n,v in d['source_before'].items())
 plain=re.sub(r'\x1b\[[0-9;]*[A-Za-z]','',(e/d['log']).read_text(errors='replace'))
 totals=re.findall(r'(\d+) tests?, (\d+) failures?',plain)
 assert sum(int(n) for n,_ in totals)==d['reported_tests']
 assert sum(int(n) for _,n in totals)==0
 assert not re.search(r'[1-9]\d* (?:skipped|excluded)',plain)
assert len(set(g['unique_test_files']))==g['unique_file_count']==19
for name in ['final-format2','final-syntax2']:
 d=json.loads((e/(name+'.json')).read_text())
 assert d['verdict']=='PASS' and d['actual_exit']==0 and d['source_stable'] and not d['warnings']
 assert d['process_joined'] and not d['forced'] and not d['process_group_remaining']
 assert sha(e/d['log'])==d['log_sha256']
 assert all(c['sources'].get(n)==v for n,v in d['source_before'].items())

bp=e/'browser-command-diagnostic4.json';b=json.loads(bp.read_text());assert b['status']=='PASS' and b['actual_exit_code']==0 and b['joined'] and b['owned_group_gone'] and b['source_stable'] and not b['timed_out'] and b['wait_error'] is None
assert b['source_before']==b['source_after'] and all(sha(r/n)==v for n,v in b['source_after'].items())
assert not b['descendant_cleanup']['forced'] and not b['descendant_cleanup']['remaining']
assert sha(Path(b['log']))==b['log_sha256'];qp=Path(b['qualification']);assert sha(qp)==b['qualification_sha256'];q=json.loads(qp.read_text())
assert q['status']=='PASS' and q['executed']==4 and q['source_stable'] and not q['adopted_remaining']
assert q['source_before']==q['source_after'] and all(sha(Path(n))==v for n,v in q['source_after'].items())
assert {(x['mode'],x['upstream_protocol']) for x in q['cases']}=={('h2','h2c'),('h2','http2'),('h1','h2c'),('h1','http2')}
assert all(x['status']=='PASS' for x in q['cases'])
assert len(q['joins'])==16 and all(x['exit']==0 and not x['forced'] and x['reader_joined'] and x['owned_group_gone'] for x in q['joins'])
assert all(sha(qp.parent/n)==v for n,v in q['artifact_sha256'].items())
loaded={}
for case in q['cases']:
 folder=qp.parent/case['case']
 before=json.loads((folder/'host-loaded-before.json').read_text());after=json.loads((folder/'host-loaded-after.json').read_text());assert before==after
 for row in before:
  assert sha(Path(row['source']))==row['source_sha256']
  if row.get('beam_sha256') is not None:assert sha(Path(row['beam']))==row['beam_sha256']
 loaded[case['case']]=len(before)
raw_custody={}
for case in q['cases']:
 custody=json.loads((qp.parent/case['case']/'diagnostic-raw-custody.json').read_text())
 assert custody['status']=='REMOVED_AFTER_ACTOR_GROUP_JOINS' and custody['actor_groups_joined']
 assert custody['raw_removed'] and not custody['directory_exists'] and not Path(custody['directory']).exists()
 raw_custody[case['case']]=sha(qp.parent/case['case']/'diagnostic-raw-custody.json')
images=json.loads((e/'browser-diagnostic4-image-review1.json').read_text());assert images['status']=='PASS' and len(images['images'])==8
assert all(sha(e/x['path'])==x['sha256'] for x in images['images'])
assert {(x['row'],x['navigation']) for x in images['images']}=={(case['case'],nav) for case in q['cases'] for nav in ['old','new']}
for source,expected in [(r/'codex-prompt.md','87112f8eb621966e0062c8611054bda49af0508693c46fa621de87a2b774038c'),(r.parents[1]/'gaoxy-m1.1-fix-prompt.md','7982874aacafe8bc4f4814740f25d1bd1e5bb35cbdc3938338ab132f2cdf9f1f')]:assert sha(source)==expected
out={'status':'PASS','candidate':'browser-diagnostic4-candidate2.json','candidate_sha256':sha(e/'browser-diagnostic4-candidate2.json'),'source_entries_unchanged':len(c['sources']),'frozen_evidence_entries_unchanged':len(c['evidence']),'command_gates_sha256':sha(e/'final-command-gates1.json'),'scoped_unique_files':19,'scoped_tests':g['union_test_count'],'failures':0,'skips':0,'exclusions':0,'warnings':0,'consumers':{'core':1,'http':2},'browser_rows':4,'viewed_images':8,'browser_receipt_sha256':sha(bp),'browser_qualification_sha256':sha(qp),'image_review_sha256':sha(e/'browser-diagnostic4-image-review1.json'),'owned_actors':16,'adopted_waits':len(q['adopted_joins']),'adopted_exit_counts':dict(collections.Counter(str(x['exit']) for x in q['adopted_joins'])),'loaded_entries_by_row':loaded,'counters':c['counters'],'commit_and_final_document_review':'PENDING'}
out.update(scope='Actual scoped implementation/diagnostic gate evidence; final documents/Git custody and local commit pending',
           historical_browser_failure={'receipt':'browser-command-final2.json','sha256':sha(e/'browser-command-final2.json'),'status':'FAIL preserved','initiating_cause':'UNKNOWN; did not reproduce; no production repair claimed'},
           netlog_completeness='All projected final NetLogs explicitly read_complete=false; finite prefix only, no absent-event inference',
           raw_custody=raw_custody,
           post_diagnostic_static={'final-format2':sha(e/'final-format2.json'),'final-syntax2':sha(e/'final-syntax2.json')},
           full_stage_review_checkpoint_sha256=sha(e/'final-stage-review-checkpoint1.json'),
           diagnostic_review_checkpoint_sha256=sha(e/'browser-diagnostic4-review-checkpoint1.json'))
with (e/'final-gates1.json').open('x') as f:json.dump(out,f,indent=2);f.write('\n')
print(json.dumps(out,indent=2))
