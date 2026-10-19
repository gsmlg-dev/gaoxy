import hashlib, json, os, re, subprocess, sys, time
from datetime import datetime, timezone
from pathlib import Path
label, *command = sys.argv[1:]
root = Path.cwd()
evidence = root / ".audit/hell-migration"
log = evidence / (label + ".log")
record = {"label":label,"cwd":str(root),"command":command,"source_sha":subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip(),"lock_sha256":hashlib.sha256((root/"mix.lock").read_bytes()).hexdigest(),"diff_sha256":hashlib.sha256(subprocess.check_output(["git","diff","--binary"])).hexdigest(),"started_utc":datetime.now(timezone.utc).isoformat(),"environment":{"ERL_FLAGS":os.environ.get("ERL_FLAGS"),"MIX_ENV":os.environ.get("MIX_ENV"),"GAOXY_QUIC_PYTHON":os.environ.get("GAOXY_QUIC_PYTHON")}}
started=time.monotonic()
with log.open("w") as stream:
    try:
        completed=subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT,text=True,timeout=900)
        record["exit"]=completed.returncode
    except subprocess.TimeoutExpired:
        record["exit"]=124
output=log.read_text(errors="replace")
record.update({"completed_utc":datetime.now(timezone.utc).isoformat(),"elapsed_seconds":time.monotonic()-started,"output_sha256":hashlib.sha256(log.read_bytes()).hexdigest(),"test_summaries":re.findall(r"(?:\d+ doctest, )?\d+ tests?, \d+ failures?[^\n]*",output),"status":"PASS" if record["exit"]==0 else "FAIL"})
(evidence/(label+".json")).write_text(json.dumps(record,indent=2)+"\n")
print(json.dumps(record,indent=2))
if record["exit"]:
    print(output[-14000:])
sys.exit(record["exit"])
