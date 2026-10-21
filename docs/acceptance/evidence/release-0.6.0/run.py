#!/usr/bin/env python3
"""Record dependency-refresh commands without changing their exit status."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

directory = Path(__file__).resolve().parent
label, *command = sys.argv[1:]
assert re.fullmatch(r"[a-z0-9-]+", label) and command
started = time.monotonic()
record = {
    "command": command,
    "cwd": os.getcwd(),
    "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "environment": {key: os.environ.get(key) for key in
                    ("MIX_ENV", "MIX_DEPS_PATH", "MIX_BUILD_PATH",
                     "ELIXIR_ERL_OPTIONS", "GAOXY_QUIC_PYTHON", "PHOENIX_NATIVE_H3")},
}
snapshot = directory / "preflight-inputs.json"
record["preflight_inputs_sha256"] = hashlib.sha256(snapshot.read_bytes()).hexdigest()
with (directory / (label + ".log")).open("x") as log:
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, errors="replace")
    for line in process.stdout:
        log.write(line)
        log.flush()
        print(line, end="", flush=True)
    result = process.wait()
record.update(exit_code=result, elapsed_seconds=round(time.monotonic() - started, 3))
with (directory / (label + ".json")).open("x") as output:
    output.write(json.dumps(record, indent=2) + "\n")
print(f"RECORDED {label}: exit={result}", flush=True)
sys.exit(result)
