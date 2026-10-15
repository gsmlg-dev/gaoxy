from pathlib import Path
import sys,subprocess,json,hashlib,time,signal,os
r=Path.cwd();e=Path(__file__).resolve().parent;gate=sys.argv[1];s=e/(gate+".exs");cmd=["nix","develop","--command","env","ERL_FLAGS=+S 2:2","MIX_ENV=test","unbuffer","mix","run","--no-start",str(s.relative_to(r))];entry=json.loads((e/"implementation-entry1.json").read_text());paths=entry["code_paths"];snap=lambda:{p:hashlib.sha256((r/p).read_bytes()).hexdigest() for p in paths};before=snap();script_hash=hashlib.sha256(s.read_bytes()).hexdigest();t=time.monotonic();log=e/(gate+".log");timeout=False
with log.open("xb") as out:
 p=subprocess.Popen(cmd,cwd=r,stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
 try:code=p.wait(timeout=600)
 except subprocess.TimeoutExpired:
  timeout=True;os.killpg(p.pid,signal.SIGKILL);code=p.wait(timeout=10)
after=snap();x={"kind":"AUXILIARY_METADATA_OR_DIAGNOSTIC_COMMAND","argv":cmd,"exit":code,"timed_out":timeout,"joined":p.poll() is not None,"elapsed_ms":round((time.monotonic()-t)*1000),"script_sha256":script_hash,"script_stable":script_hash==hashlib.sha256(s.read_bytes()).hexdigest(),"source_before":before,"source_after":after,"stable":before==after,"log_sha256":hashlib.sha256(log.read_bytes()).hexdigest(),"tests_executed":0};(e/(gate+".json")).write_text(json.dumps(x,indent=2)+"\n");print(json.dumps(x,indent=2));print(log.read_text()[-14000:]);raise SystemExit(code if before==after and x["script_stable"] else 1)
