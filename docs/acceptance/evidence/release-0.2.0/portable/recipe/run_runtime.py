"""Qualify exported package in one owned, fresh offline runtime container."""
import datetime
import json
from pathlib import Path
import subprocess
import sys
import time
import uuid

started = time.monotonic()
root = Path(sys.argv[1]).resolve()
wait_bound = min(300, int(sys.argv[2])) if len(sys.argv) > 2 else 300
evidence = root / "evidence" / "fresh-runtime"
evidence.mkdir(parents=True, exist_ok=True)
image = subprocess.check_output(["docker", "image", "inspect", "gaoxy-release-020-portable-runtime:local", "--format", "{{.Id}}"], text=True).strip()
name = "gaoxy-release-020-portable-" + uuid.uuid4().hex[:12]
command = ["docker", "create", "--name", name, "--network", "none", "--platform", "linux/amd64", "--mount", f"type=bind,source={root / 'artifacts'},target=/artifacts,readonly", "--mount", f"type=bind,source={evidence},target=/evidence", image]
receipt = {"image_id": image, "create_command": command, "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "timeout_seconds": wait_bound, "status": "RUNNING"}
(evidence / "launch.json").write_text(json.dumps(receipt, indent=2) + "\n")
container = subprocess.check_output(command, text=True).strip()
receipt["container_id"] = container
try:
    subprocess.run(["docker", "start", container], check=True)
    live = json.loads(subprocess.check_output(["docker", "inspect", container], text=True))[0]
    (evidence / "container-inspect-live.json").write_text(json.dumps(live, indent=2) + "\n")
    assert live["State"]["Running"], live["State"]
    assert live["HostConfig"]["NetworkMode"] == "none", live["HostConfig"]["NetworkMode"]
    assert live["Image"] == image
    code = subprocess.check_output(["docker", "wait", container], text=True, timeout=wait_bound).strip()
    receipt["container_exit_code"] = int(code)
    logs = subprocess.check_output(["docker", "logs", container], stderr=subprocess.STDOUT, text=True)
    (evidence / "container.log").write_text(logs)
    print(logs, end="")
    final = json.loads(subprocess.check_output(["docker", "inspect", container], text=True))[0]
    (evidence / "container-inspect-final.json").write_text(json.dumps(final, indent=2) + "\n")
    assert not final["State"]["Running"]
    assert receipt["container_exit_code"] == 0, receipt
    result = json.loads((evidence / "runtime-result.json").read_text())
    assert result["status"] == "PASS"
    receipt["status"] = "PASS"
finally:
    qualification_passed = receipt["status"] == "PASS"
    receipt["status"] = "FAIL"
    cleanup_evidence_complete = False
    # Capture evidence even when startup already failed before the live assertion.
    # Stop only this owned container, then retain logs/final state before removal.
    try:
        before = json.loads(subprocess.check_output(["docker", "inspect", container], text=True))[0]
        (evidence / "container-inspect-before-cleanup.json").write_text(json.dumps(before, indent=2) + "\n")
        if before["State"]["Running"]:
            subprocess.run(["docker", "stop", "--time", "10", container], check=True)
        captured = subprocess.run(["docker", "logs", container], stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, text=True)
        (evidence / "container.log").write_text(captured.stdout)
        receipt["log_capture_exit_code"] = captured.returncode
        captured.check_returncode()
        final = json.loads(subprocess.check_output(["docker", "inspect", container], text=True))[0]
        (evidence / "container-inspect-final.json").write_text(json.dumps(final, indent=2) + "\n")
        receipt["container_exit_code"] = final["State"]["ExitCode"]
        assert not final["State"]["Running"]
        cleanup_evidence_complete = True
    finally:
        removed = subprocess.run(["docker", "rm", container], capture_output=True, text=True)
        receipt["owned_container_removed"] = removed.returncode == 0
        receipt["completed_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        receipt["elapsed_seconds"] = time.monotonic() - started
        if qualification_passed and cleanup_evidence_complete and removed.returncode == 0:
            receipt["status"] = "PASS"
        (evidence / "launch.json").write_text(json.dumps(receipt, indent=2) + "\n")
        removed.check_returncode()
