import json,os,subprocess,time
from pathlib import Path
out=Path(__file__).resolve().parent
root=out.parents[1]
env={**os.environ,'PATH':str(root/'.audit/canonical-elixir/distribution/bin')+':'+os.environ['PATH'],'MIX_HOME':str(out/'mix-home'),'MIX_ARCHIVES':str(out/'mix-home/archives'),'OPENSSL_BIN':'/opt/homebrew/opt/openssl@3/bin/openssl','GAOXY_QUIC_PYTHON':str(root/'.audit/h2peer/bin/python'),'ELIXIR_ERL_OPTIONS':'+S 2:2','MIX_ENV':'test'}
checks=[('public-consumers',['python3','scripts/test-consumers.py','--published','--version','0.11.1'],root),('boundary-deps',['mix','deps.get'],out/'public-boundary'),('boundary-compile',['mix','compile','--warnings-as-errors'],out/'public-boundary'),('public-boundary',['python3',str(root/'scripts/check-tests.py'),'test/poll_boundary_network_test.exs','--seed','0','--max-cases','1'],out/'public-boundary')]
receipt=[]
for name,cmd,cwd in checks:
    start=time.time()
    with (out/(name+'.log')).open('w') as log:
        r=subprocess.run(cmd,cwd=cwd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=1800)
    row={'name':name,'command':cmd,'cwd':str(cwd),'exit':r.returncode,'seconds':round(time.time()-start,2)}
    receipt.append(row)
    (out/'public-checks.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(row),flush=True)
    print((out/(name+'.log')).read_text()[-1500:],flush=True)
    if r.returncode:raise SystemExit(r.returncode)
