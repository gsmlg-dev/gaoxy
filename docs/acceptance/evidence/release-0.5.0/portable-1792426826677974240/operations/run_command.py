"""Run one bounded release command and preserve its actual output and exit."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

AUDIT = Path(__file__).resolve().parent
ROOT = AUDIT.parents[1]
RUN = Path(json.loads((AUDIT / "active-run.json").read_text())["run_directory"])
label, seconds, *command = sys.argv[1:]
assert label.replace("-", "").isalnum() and command
timeout = int(seconds)
assert 1 <= timeout <= 1800
evidence = RUN / "evidence"
receipt_path = evidence / f"host-{label}.json"
log = evidence / f"host-{label}.log"
assert not receipt_path.exists() and not log.exists()
started = time.monotonic()
receipt = {"status": "FAIL", "command": command, "cwd": str(ROOT),
           "timeout_seconds": timeout, "source_sha": json.loads((RUN / "context/source-identity.json").read_text())["source_sha"],
           "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat()}
receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
process = None
try:
    with log.open("w") as output:
        process = subprocess.Popen(command, cwd=ROOT, stdout=output,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            receipt["timed_out"] = True
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=5)
    receipt["exit_code"] = process.returncode
    assert process.returncode == 0, (label, process.returncode)
    receipt["status"] = "PASS"
except BaseException as error:
    receipt["error"] = repr(error)
finally:
    receipt["elapsed_seconds"] = time.monotonic() - started
    receipt["completed_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    receipt["log_sha256"] = hashlib.sha256(log.read_bytes()).hexdigest()
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
    print(log.read_text()[-16000:], end="")
    print(json.dumps(receipt, indent=2))
sys.exit(0 if receipt["status"] == "PASS" else 1)
