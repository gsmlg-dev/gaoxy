from pathlib import Path
import hashlib,json,os,signal,subprocess,time
R=Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E=R/'docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089'
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
source=json.loads((E/'postactivation-full-review-candidate5.json').read_text())['source_manifest']
snapshot=lambda:{p:h(R/p) if (R/p).is_file() else None for p in source}
stamp=str(time.time_ns());directory=E/('browser-three-cases5-'+stamp)
command=['/tmp/gaoxy-m3-h2-soak-venv/bin/python','-B','integration/http_fetch_contract/managed_h2_group_browser.py','--evidence',str(directory)]
before=snapshot();started=time.monotonic();timed_out=False;log=E/('browser-command5-'+stamp+'.log')
with log.open('xb') as output:
 p=subprocess.Popen(command,cwd=R,stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
 try:actual=p.wait(timeout=600)
 except subprocess.TimeoutExpired:
  timed_out=True;os.killpg(p.pid,signal.SIGTERM)
  try:actual=p.wait(timeout=10)
  except subprocess.TimeoutExpired:
   os.killpg(p.pid,signal.SIGKILL);actual=p.wait(timeout=10)
after=snapshot();qpath=directory/'qualification.json';q=json.loads(qpath.read_text()) if qpath.is_file() else None
report={'kind':'ACTUAL_THREE_CASE_BROWSER_COMMAND','command':command,'pid':p.pid,'actual_exit':actual,'process_joined':p.poll() is not None,'timed_out':timed_out,'elapsed_ms':round((time.monotonic()-started)*1000),'source_before':before,'source_after':after,'source_stable':before==after,'log':str(log.relative_to(R)),'log_sha256':h(log),'qualification':str(qpath.relative_to(R)),'qualification_sha256':h(qpath) if q else None,'suite_status':q.get('status') if q else 'NO_REPORT','executed_completed_cases':q.get('executed',0) if q else 0,'collector_sha256':h(Path(__file__)),'astra':'2/2 exhausted unchanged'}
receipt=log.with_suffix('.json');receipt.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['source_before','source_after']},indent=2));print('receipt_sha256',h(receipt));print(log.read_text(errors='replace')[-6000:] if actual else '')
assert not timed_out and report['process_joined'] and report['source_stable']
if actual:raise SystemExit(actual)
assert q is not None and q['status']=='PASS' and q['executed']==3 and q['source_stable']
