#!/usr/bin/env python3
"""Task-local qualification runner; source hashes and raw command receipts."""
import argparse,datetime,hashlib,json,os,pathlib,re,signal,subprocess,time
ROOT=pathlib.Path('/home/gao/Workspace/gsmlg-opt/gaoxy')
ROOTS=["apps","vendor","scripts","integration",".github","examples","mix.exs","mix.lock"]
def fingerprint():
    paths=subprocess.check_output(["git","ls-files","--cached","--others","--exclude-standard","--",*ROOTS],cwd=ROOT,text=True).splitlines()
    return {f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in sorted(set(paths)) if (ROOT/f).is_file()}
p=argparse.ArgumentParser();p.add_argument("label");p.add_argument("--cwd",default=".");p.add_argument("--timeout",type=int,default=1200);p.add_argument("--env",action="append",default=[]);p.add_argument("command",nargs=argparse.REMAINDER);a=p.parse_args()
command=a.command
if command and command[0]=="--":command=command[1:]
if not command:p.error("missing command")
output=pathlib.Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.audit/adaptive-resource-budget/core/time-quota/extension24h-repair12');output.mkdir(parents=True,exist_ok=True)
env=dict(os.environ,MIX_ENV="test",ELIXIR_ERL_OPTIONS="+S 2:2",GAOXY_QUIC_PYTHON=str(ROOT/".audit/h2peer/bin/python"),GAOXY_H2_PYTHON=str(ROOT/".audit/h2peer/bin/python"),GAOXY_CONSUMER_DEPS=str(ROOT/"deps"))
for item in a.env:
    k,v=item.split("=",1);env[k]=v
before=fingerprint();source=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip();start=time.monotonic()
receipt=dict(label=a.label,command=command,cwd=str((ROOT/a.cwd).resolve()),source=source,started_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),environment={k:env[k] for k in ["MIX_ENV","ELIXIR_ERL_OPTIONS","GAOXY_QUIC_PYTHON","GAOXY_H2_PYTHON","GAOXY_CONSUMER_DEPS"]},source_hashes=before)
log=output/(a.label+".log")
with log.open("w") as stream:
    child=subprocess.Popen(command,cwd=ROOT/a.cwd,env=env,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
    try:code=child.wait(timeout=a.timeout)
    except subprocess.TimeoutExpired:
        os.killpg(child.pid,signal.SIGTERM)
        try:child.wait(timeout=5)
        except subprocess.TimeoutExpired:os.killpg(child.pid,signal.SIGKILL);child.wait(timeout=5)
        code=124
    except BaseException:
        if child.poll() is None:os.killpg(child.pid,signal.SIGTERM);child.wait(timeout=5)
        raise
text=log.read_text();after=fingerprint();changes=[f for f in sorted(set(before)|set(after)) if before.get(f)!=after.get(f)]
receipt.update(exit=code,elapsed_seconds=time.monotonic()-start,log=str(log.relative_to(ROOT)),log_sha256=hashlib.sha256(log.read_bytes()).hexdigest(),source_changes=changes,commands_terminal=True,evidence_lines=[line for line in text.splitlines() if re.search(r"(tests?, \d+ failures?|^REPAIR_PASS|^CONSUMER_PASS|PASS|^Ran \d+ tests?)",line)])
receipt["status"]="PASS" if code==0 and not changes else ("SOURCE_CHANGED" if code==0 else "FAIL")
(output/(a.label+".json")).write_text(json.dumps(receipt,indent=2)+"\n")
print(json.dumps({k:v for k,v in receipt.items() if k!="source_hashes"},indent=2),flush=True)
raise SystemExit(code if code else (3 if changes else 0))
