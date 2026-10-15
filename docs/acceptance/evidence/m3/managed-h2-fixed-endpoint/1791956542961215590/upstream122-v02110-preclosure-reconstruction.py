from pathlib import Path
import json,hashlib,re,difflib
R=Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation');E=R/'docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590'
m=json.loads((E/'upstream122-v02110-ready-candidate-manifest.json').read_text());out=Path('/tmp/gaoxy-v02110-preclosure-docs')
D=['docs/designs/m3-managed-h2-fixed-endpoint.md','docs/plans/m3-managed-h2-fixed-endpoint.md','docs/acceptance/m3-managed-h2-fixed-endpoint.md','implement-plan.md']
oldtable='''## Gate ledger

| Required gate | Required evidence | Current status |
| --- | --- | --- |
| Accepted pure preparation predecessor | Actual commit/source, complete reviews, fresh97/0+63/0 | PASS predecessor only |
| Fixed design/plan independent readiness | Three exact document hashes; complete interface/schema/ledger coverage | Original committed documents PASS; current compatibility amendments pending final review |
| Verified execution kickoff | Baseline/diff/untracked/source/lock/cohort; ownership/counters; all writers serialized | PASS recorded kickoff |
| Observed tests-first RED | Nonzero actual executed tests before production, preserved failures | PASS observed pure/owner/renderer and client/integration RED; failures retained |
| Pure envelope/client/reservation and owner tests | Exact/over/malformed/backing, protocol identity, complete slots | Pure/owner GREEN2 237/0; combined repair4 759/4, targeted107/2 and108/1 FAIL retained; repair7 Task7 PASS77/0; full53 GREEN1 PASS761/0; final fresh gate NOT RUN |
| Generation exclusion and renderer guards | Both Store paths; public renderer caps and actual Service reserve | Pure guard/full53 PASS; complete control/capacity/renderer combined repair12 PASS96/0; final fresh gate NOT RUN |
| Four independent fixed-proxy protocol cells | Native H1/H2 downstream, real TLS-H2/h2c upstream, exact byte/cleanup oracles | Matrix GREEN1 FAIL5, GREEN2 FAIL13, GREEN3 FAIL14, GREEN4 FAIL15; C2/R32 exact refusal PASS; native H1 short-read repair pending full135 |
| Deterministic backpressure/lifecycle | Full write->ACK and original completion release order; uncertainty retained | Task7 RED76/8, H2 network RED28/4, combined759/4, targeted107/2 and108/1 FAIL retained; repair7 Task7 PASS77/0 with source stable/zero skips; full53 GREEN1 PASS761/0; final fresh gate NOT RUN |
| Separate browser acceptance | Local native TLS/h2 browser navigation/stream/early/error and joins | Earlier five FAIL preserved; helper-join GREEN1 PASS3 with exact reserve/native identities/helpers0; negative cleanup remains unconfirmed |
| Existing public compatibility63 assertions | Fresh managed39/completion16/supplement8 with byte-preserved historical sources | Public GREEN1 PASS63, source stable/exit0; final fresh gate NOT RUN |
| Affected H1/H2/H3 and Generation/group compatibility | Intended full57 manifest including native H1 partial-upload and original-request-deadline seam suites; actual counts/exits/source stability | Historical full53 GREEN1 PASS761/0, source stable/exit0/zero skips; full57 final fresh gate NOT RUN |
| Complete independent SPEC then CODE | Full candidate/evidence, findings resolved and counters preserved | NOT RUN |
| Fresh post-review canonical gates | Format/strict compile/scoped tests/public/network/browser; source-stable | NOT RUN |
| Safe owned shutdown and local commit | Parent commands stopped, helpers joined, stage owned files, actual commit | NOT RUN |
'''
patch=[];proof=[]
for name in D:
 current=(R/name).read_text();first=current.split('\n',1)[0];s=first+'\n'+current.split('## Historical checkpoints before the final runtime gates\n',1)[1]
 if name=='docs/plans/m3-managed-h2-fixed-endpoint.md':
  for n in range(2,8):
   s,count=re.subn(rf'(## Task {n}:.*?)(?=\n## Task {n+1}:)',lambda x:x[0].replace('- [x]','- [ ]'),s,flags=re.S);assert count==1
  s=s.replace('- [x] Resolve actionable CODE findings;','- [ ] Resolve actionable CODE findings;',1)
  s=s.replace('- [x] Parent updates acceptance with actual predecessor/candidate source and','- [ ] Parent updates acceptance with actual predecessor/candidate source and',1)
 if name=='docs/acceptance/m3-managed-h2-fixed-endpoint.md':
  start=s.index('## Gate ledger');end=s.index('\nPASS requires',start);s=s[:start]+oldtable+s[end:]
  s=s.replace('The values below are runtime-qualified by complete independent SPEC/CODE and\nthe fresh full58/matrix/browser gates recorded in the current receipt audit.\nThe unit is bounded complete ETF payload, not heap/native/VM/OS/kernel/process\nmemory. Historical proposed worksheets remain historical evidence.','All values below remain **PROPOSED/UNACCEPTED** until executable enforcement,\nindependent review and fresh gates pass. Unit is bounded complete ETF payload,\nnot heap/native/VM/OS/kernel/process memory.')
  for text in ['Native Gaoxy H1 downstream, independent verified TLS/h2 peer','Native Gaoxy H1 downstream, independent prior-knowledge TCP/h2 peer','Native Gaoxy H2 downstream via independent h2 client, verified TLS/h2 peer','Native Gaoxy H2 downstream via independent h2 client, TCP/h2 peer']:
   s=s.replace('| '+text+' | PASS fresh matrix135 |','| '+text+' | NOT RUN |')
  s=s.replace('| PASS fresh3/3; prior failures and negative cleanup uncertainty retained |','| Positive case PASS; diagnostic1 FAIL0, diagnostic2/3 and negative-green1 FAIL1; full acceptance pending |')
  start=s.index('## Pure schema and request assertions');end=s.index('The document-preparation assignment',start)
  s=s[:start]+s[start:end].replace('- [x]','- [ ]')+s[end:]
  # The closure builder retained one additional blank separator after this block.
  s=s.replace('production acceptance remain separate and are not inferred.\n\n\nThe document-preparation assignment','production acceptance remain separate and are not inferred.\n\nThe document-preparation assignment',1)
 digest=hashlib.sha256(s.encode()).hexdigest();expected=m['source_files'][name]
 print(name,digest,'expected',expected,'MATCH',digest==expected)
 assert digest==expected,name
 p=out/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s)
 proof.append({'path':name,'sha256':digest,'matches_ready_manifest':True})
 patch+=list(difflib.unified_diff(s.splitlines(keepends=True),current.splitlines(keepends=True),fromfile='a/'+name,tofile='b/'+name))
(out/'verified-reconstruction.json').write_text(json.dumps({'kind':'BYTE_EXACT_PRE_DOC_RECONSTRUCTION','from_ready_manifest':str(E/'upstream122-v02110-ready-candidate-manifest.json'),'documents':proof,'method':'reverse_exact_closure_transforms_then_require_sha256_equality'},indent=2)+'\n')
(out/'closure-documents.patch').write_text(''.join(patch))
