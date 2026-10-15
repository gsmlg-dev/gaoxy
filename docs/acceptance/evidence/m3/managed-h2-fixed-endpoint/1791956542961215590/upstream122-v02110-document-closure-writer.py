import hashlib,json,re
from pathlib import Path
R=Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E=R/'docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590'
D=['docs/designs/m3-managed-h2-fixed-endpoint.md','docs/plans/m3-managed-h2-fixed-endpoint.md','docs/acceptance/m3-managed-h2-fixed-endpoint.md','implement-plan.md']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
mp=E/'upstream122-v02110-ready-candidate-manifest.json';m=json.loads(mp.read_text())
ap=E/'upstream122-v02110-postreview-complete-evidence-audit.json';a=json.loads(ap.read_text())
assert a['status']=='PASS_ALL_REQUIRED_GATES_PENDING_DOC_CLOSURE_AND_COMMIT'
assert a['candidate_manifest_sha256']==sha(mp)
for name,value in (m['source_files']|m['authorities']).items():assert sha(R/name)==value,name
for name in D:
 p=R/name;s=p.read_text();first,rest=s.split('\n',1)
 ep='docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/' if name=='implement-plan.md' else '../acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/' if name.startswith(('docs/designs/','docs/plans/')) else 'evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/'
 current=f'''\n\n## Current checkpoint — 2026-10-15\n\nAll six fresh post-review runtime gates PASS for the managed H2 fixed-endpoint\ncandidate at baseline `{m['head']}`. Complete independent\n[SPEC]({ep}upstream122-v02110-ready-spec.json) then\n[CODE]({ep}upstream122-v02110-ready-code.json) passed with zero findings.\nCandidate manifest SHA256 is `{sha(mp)}`.\n\nFresh format43 and forced strict compile passed; complete full58 executed\n**853 tests /0 failures /0 skips /0 exclusions**, exit0. Additive HTTP0.21.10\npublic qualification passed **63/63**, the four-cell real-peer matrix passed\n**135/135** unique required cases, and isolated browser acceptance passed\n**3/3**. All source identities remained stable. The\n[complete receipt audit]({ep}{ap.name}) verifies logs/artifacts, actual\nloaded source/BEAM identities, original public completions and peer/browser\nprocess joins. HTTP0.21.10 resolves upstream122; every original assertion and\nall historical failure evidence remain preserved.\n\nNegative wrong-CA/name browser cleanup remains\n`UNCONFIRMED_WITH_RETAINED_FAILURE`; passing negative cases do not establish\nsuccessful original cleanup. Historical EOF and connection-reset outcomes\nremain distinct. FixedSol19, collectorSol17, fixtureSol20 RED1/GREEN1,\nnew-cohort full58failed2 and all earlier counters persist; Astra recovery2/2\nremains exhausted.\n\nRuntime verification is complete. Final documentation-only independent review\nand the authorized local conventional commit remain pending. Managed H2\ngroups/probes is the next bounded slice after this closure; its design draft\ndoes not activate it. Generation, standalone/load, hosted CI, publication,\ndeployment and production acceptance retain their separate gates.\n\n## Historical checkpoints before the final runtime gates\n'''
 s=first+current+rest
 if name=='docs/plans/m3-managed-h2-fixed-endpoint.md':
  for n in range(2,9):
   pattern=rf'(## Task {n}:.*?)(?=\n## Task {n+1}:)'
   s,count=re.subn(pattern,lambda x:x[0].replace('- [ ]','- [x]'),s,flags=re.S);assert count==1,n
  old='- [ ] Parent updates acceptance with actual predecessor/candidate source and'
  assert old in s;s=s.replace(old,'- [x] Parent updates acceptance with actual predecessor/candidate source and',1)
 if name=='docs/acceptance/m3-managed-h2-fixed-endpoint.md':
  start=s.index('## Gate ledger');end=s.index('\nPASS requires',start)
  rows=[
   ('Accepted pure preparation predecessor','Actual commit/source, complete reviews, fresh97/0+63/0','PASS predecessor only'),
   ('Fixed design/plan independent readiness','Exact source, complete interface/schema/ledger coverage','PASS complete SPEC/CODE; final evidence-only document delta pending review'),
   ('Verified execution kickoff','Baseline/diff/untracked/source/lock/cohort; serialized ownership/counters','PASS recorded kickoff'),
   ('Observed tests-first RED','Nonzero executed RED before repairs, preserved failures','PASS preserved pure/owner/client/integration/renderer/native/fixture RED receipts'),
   ('Pure envelope/client/reservation and owner tests','Complete malformed/backing, identity, closed slots','PASS fresh full58 853/0; historical failures retained'),
   ('Generation exclusion and renderer guards','Both Store paths; public renderer caps/Service reserve','PASS fresh full58 853/0'),
   ('Four independent fixed-proxy protocol cells','Native H1/H2 downstream × verified TLS-H2/h2c independent upstream','PASS fresh135/135 unique required identities; no omissions/skips/exclusions'),
   ('Deterministic backpressure/lifecycle','Write→ACK, original completion/release order, bounded controls','PASS fresh full58 and matrix135; actual unconfirmed cleanup retained'),
   ('Separate browser acceptance','Native TLS/h2 navigation/stream/early/error plus joins','PASS fresh3/3; negative cleanup UNCONFIRMED_WITH_RETAINED_FAILURE'),
   ('Existing public compatibility63 assertions','Managed39/completion16/supplement8, historical source pins','PASS fresh63/63 at HTTP0.21.10; original assertions preserved'),
   ('Affected H1/H2/H3 and Generation/group compatibility','All58 canonical paths, exact nonzero counts/exits/source identities','PASS fresh853/0, exit0, source stable, zero skips/exclusions'),
   ('Complete independent SPEC then CODE','Full frozen52+5 candidate; resolved findings/cumulative counters','PASS ready-spec then ready-code, zero findings'),
   ('Fresh post-review canonical gates','Format43/forced strict compile/full58/public63/matrix135/browser3','PASS all six; complete evidence audit verifies artifacts and joins'),
   ('Final documentation-only review','Runtime unchanged; actual current ledger/checklist/evidence bindings','NOT RUN'),
   ('Safe owned shutdown and local commit','Commands/actors joined; preserved user inventory; exact local commit','Runtime joins PASS; final inventory/local commit NOT RUN')]
  table='## Gate ledger\n\n| Required gate | Required evidence | Current status |\n| --- | --- | --- |\n'+'\n'.join('| '+' | '.join(row)+' |' for row in rows)+'\n'
  s=s[:start]+table+s[end:]
  s=s.replace('All values below remain **PROPOSED/UNACCEPTED** until executable enforcement,\nindependent review and fresh gates pass. Unit is bounded complete ETF payload,\nnot heap/native/VM/OS/kernel/process memory.','The values below are runtime-qualified by complete independent SPEC/CODE and\nthe fresh full58/matrix/browser gates recorded in the current receipt audit.\nThe unit is bounded complete ETF payload, not heap/native/VM/OS/kernel/process\nmemory. Historical proposed worksheets remain historical evidence.')
  for text in ['Native Gaoxy H1 downstream, independent verified TLS/h2 peer','Native Gaoxy H1 downstream, independent prior-knowledge TCP/h2 peer','Native Gaoxy H2 downstream via independent h2 client, verified TLS/h2 peer','Native Gaoxy H2 downstream via independent h2 client, TCP/h2 peer']:
   s=s.replace('| '+text+' | NOT RUN |','| '+text+' | PASS fresh matrix135 |')
  s=s.replace('| Positive case PASS; diagnostic1 FAIL0, diagnostic2/3 and negative-green1 FAIL1; full acceptance pending |','| PASS fresh3/3; prior failures and negative cleanup uncertainty retained |')
  start=s.index('## Pure schema and request assertions');end=s.index('## Closure evidence',start)
  s=s[:start]+s[start:end].replace('- [ ]','- [x]')+s[end:]
  start=s.index('## Closure evidence');end=s.index('The document-preparation assignment',start)
  block=s[start:end];lines=block.splitlines();n=0
  for i,line in enumerate(lines):
   if line.startswith('- [ ]'):
    n+=1
    if n<=3:lines[i]=line.replace('- [ ]','- [x]',1)
  assert n==5,n;s=s[:start]+'\n'.join(lines)+'\n\n'+s[end:]
 p.write_text(s)
new={name:sha(R/name) for name in m['source_files']};changes={name:{'before':m['source_files'][name],'after':new[name]} for name in D}
assert {name for name in new if new[name]!=m['source_files'][name]}==set(D)
for name,value in m['authorities'].items():assert sha(R/name)==value,name
out={'kind':'FIXED_H2_FINAL_DOCUMENTATION_REVIEW_CANDIDATE','status':'FROZEN_FOR_DOCUMENT_SPEC_THEN_CODE','baseline':m['head'],'runtime_candidate':{'path':str(mp.relative_to(R)),'sha256':sha(mp)},'runtime_audit':{'path':str(ap.relative_to(R)),'sha256':sha(ap)},'document_changes':changes,'source_files':new,'authorities':m['authorities'],'runtime_source_unchanged':True,'format_paths':m['format_paths'],'scoped_paths':m['scoped_paths'],'current_runtime_gates':'PASS_ALL_SIX','local_commit':'NOT_RUN','successor_activation':'NOT_RUN'}
p=E/'upstream122-v02110-closure-candidate-manifest.json';assert not p.exists();p.write_text(json.dumps(out,indent=2)+'\n');print('CLOSURE_CANDIDATE',sha(p));print(json.dumps(changes,indent=2))
