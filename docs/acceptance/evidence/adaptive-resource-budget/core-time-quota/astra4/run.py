import datetime,hashlib,json,os,pathlib,re,subprocess,sys,time
ROOT=pathlib.Path(__file__).resolve().parents[4]
OUT=pathlib.Path(__file__).resolve().parent
label,*command=sys.argv[1:]
if command and command[0]=='--':command=command[1:]
log=OUT/(label+'.log');receipt=OUT/(label+'.json')
assert not log.exists() and not receipt.exists(),label
def fingerprint():
    paths=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','--','apps','vendor','scripts','integration','.github','examples','mix.exs','mix.lock'],cwd=ROOT,text=True).splitlines()
    return {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sorted(set(paths)) if (ROOT/p).is_file()}
env=dict(os.environ,MIX_ENV='test',ELIXIR_ERL_OPTIONS='+S 2:2',GAOXY_QUIC_PYTHON=str(ROOT/'.audit/h2peer/bin/python'),GAOXY_H2_PYTHON=str(ROOT/'.audit/h2peer/bin/python'))
before=fingerprint();start=time.monotonic();at=datetime.datetime.now(datetime.timezone.utc).isoformat()
with log.open('w') as f:
    result=subprocess.run(command,cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=900)
raw=log.read_text();after=fingerprint();counts=re.findall(r'(\d+) tests?, (\d+) failures?([^\n]*)',raw)
r=dict(task='ARB-CORE',label=label,command=command,started_at=at,exit=result.returncode,elapsed_seconds=time.monotonic()-start,source_hashes=before,source_changes=[p for p in sorted(set(before)|set(after)) if before.get(p)!=after.get(p)],log=str(log.relative_to(ROOT)),log_sha256=hashlib.sha256(log.read_bytes()).hexdigest(),tests=sum(int(n) for n,_,_ in counts),failures=sum(int(n) for _,n,_ in counts),excluded_or_skipped=any(re.search(r'[1-9]\d* (?:excluded|skipped)',suffix) for _,_,suffix in counts),commands_terminal=True)
receipt.write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps({k:v for k,v in r.items() if k!='source_hashes'},indent=2));sys.exit(result.returncode)
