"""Bound runtime image preparation plus fresh packaged qualification to 600 seconds."""
import datetime
import json
from pathlib import Path
import subprocess
import sys
import time

root = Path(sys.argv[1]).resolve()
start = time.monotonic()
receipt = {"bound_seconds": 600, "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "stages": []}

def execute(name, command, log):
    stage_start = time.monotonic()
    remaining = 600 - (stage_start - start)
    assert remaining > 15, "fresh-runtime outer budget exhausted"
    with log.open("w") as output:
        result = subprocess.run(command, cwd=root, stdout=output, stderr=subprocess.STDOUT, timeout=remaining-10)
    receipt["stages"].append({"name": name, "command": command, "elapsed_seconds": time.monotonic()-stage_start, "exit_code": result.returncode})
    assert result.returncode == 0, (name, result.returncode)

try:
    execute("runtime-image", ["docker", "buildx", "build", "--platform", "linux/amd64", "--progress", "plain", "--target", "runtime", "--load", "-t", "gaoxy-release-020-portable-runtime:local", str(root / "context")], root / "evidence/docker-runtime-build.log")
    metadata = subprocess.check_output(["docker", "image", "inspect", "gaoxy-release-020-portable-runtime:local"], text=True)
    (root / "evidence/runtime-image-inspect.json").write_text(metadata)
    remaining = int(600 - (time.monotonic() - start) - 20)
    assert remaining > 0
    execute("fresh-runtime", [sys.executable, str(root / "context/run_runtime.py"), str(root), str(remaining)], root / "evidence/fresh-runtime-run.log")
    receipt["status"] = "PASS"
finally:
    receipt["elapsed_seconds"] = time.monotonic() - start
    receipt["completed_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    (root / "evidence/runtime-qualification-stages.json").write_text(json.dumps(receipt, indent=2) + "\n")
