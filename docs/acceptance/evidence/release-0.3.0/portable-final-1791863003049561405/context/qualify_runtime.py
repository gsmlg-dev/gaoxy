"""Bound runtime image preparation, qualification and owned cleanup to 600 seconds."""
import datetime
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
import uuid

root = Path(sys.argv[1]).resolve()
start = time.monotonic()
deadline = start + 600
work_deadline = deadline - 40
name = "gaoxy-release-030-portable-" + uuid.uuid4().hex
evidence = root / "evidence"
evidence.mkdir(parents=True, exist_ok=True)
receipt = {"bound_seconds": 600, "cleanup_reserve_seconds": 40, "owned_name": name,
           "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
           "status": "FAIL", "stages": []}


def save():
    receipt["elapsed_seconds"] = time.monotonic() - start
    (evidence / "runtime-qualification-stages.json").write_text(json.dumps(receipt, indent=2) + "\n")


def execute(stage, command, log, cleanup=False, maximum=600, require_zero=True):
    timeout = min(maximum, (deadline if cleanup else work_deadline) - time.monotonic())
    row = {"name": stage, "command": command, "timeout_seconds": timeout - 2,
           "reap_reserve_seconds": 2}
    receipt["stages"].append(row)
    save()
    tick = time.monotonic()
    process = None
    try:
        assert timeout > 2, f"{stage}: absolute qualification budget exhausted"
        with log.open("w") as output:
            process = subprocess.Popen(command, cwd=root, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
            process.wait(timeout=timeout - 2)
        row["exit_code"] = process.returncode
        if require_zero:
            assert process.returncode == 0, (stage, process.returncode)
        return process.returncode
    except BaseException as error:
        row["error"] = repr(error)
        row["timed_out"] = isinstance(error, subprocess.TimeoutExpired)
        if process is not None and process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=2)
            row["exit_code"] = process.returncode
        raise
    finally:
        row["elapsed_seconds"] = time.monotonic() - tick
        save()


save()  # Parent ownership survives a child timeout or partial container creation.
child_attempted = False


def container_absent(code, output):
    return code != 0 and re.search(
        r"(?:^|\n)(?i:(?:error(?: response from daemon)?:\s*)?no such (?:object|container):\s*)"
        + re.escape(name) + r"\s*$", output
    ) is not None


try:
    execute("runtime-image", ["docker", "buildx", "build", "--platform", "linux/amd64", "--progress", "plain", "--target", "runtime", "--load", "-t", "gaoxy-release-030-portable-runtime:local", str(root / "context")], evidence / "docker-runtime-build.log")
    execute("runtime-image-inspect", ["docker", "image", "inspect", "gaoxy-release-030-portable-runtime:local"], evidence / "runtime-image-inspect.json", maximum=10)
    child_deadline = min(work_deadline - 2, time.monotonic() + 300)
    assert child_deadline - time.monotonic() > 30, "fresh-runtime cleanup reserve unavailable"
    child_attempted = True
    execute("fresh-runtime", [sys.executable, str(root / "context/run_runtime.py"), str(root), name, str(child_deadline)], evidence / "fresh-runtime-run.log", maximum=child_deadline - time.monotonic() + 2)
    launch = json.loads((evidence / "fresh-runtime/launch.json").read_text())
    assert launch["owned_name"] == name and launch["status"] == "PASS"
    assert launch["owned_container_removed"] and launch["owned_container_absent"]
    code = execute("owned-container-absence", ["docker", "inspect", name], evidence / "owned-container-absence.log", maximum=5, require_zero=False)
    output = (evidence / "owned-container-absence.log").read_text()
    assert container_absent(code, output), output
    receipt["owned_container_absent"] = True
    receipt["status"] = "PASS"
except BaseException as error:
    receipt["error"] = repr(error)
finally:
    if child_attempted and receipt["status"] != "PASS":
        # Each diagnostic is independent so a stalled inspect cannot prevent removal.
        for stage, arguments in [("fallback-inspect-before-cleanup", ["inspect", name]),
                                 ("fallback-logs", ["logs", name]),
                                 ("fallback-inspect-final", ["inspect", name])]:
            try:
                execute(stage, ["docker", *arguments], evidence / f"{stage}.log", cleanup=True, maximum=5, require_zero=False)
            except BaseException as error:
                receipt[stage + "_error"] = repr(error)
        try:
            code = execute("fallback-remove", ["docker", "rm", "--force", name], evidence / "fallback-remove.log", cleanup=True, maximum=10, require_zero=False)
            receipt["fallback_remove_exit_code"] = code
            code = execute("fallback-absence", ["docker", "inspect", name], evidence / "fallback-absence.log", cleanup=True, maximum=5, require_zero=False)
            output = (evidence / "fallback-absence.log").read_text()
            receipt["owned_container_absent"] = container_absent(code, output)
        except BaseException as error:
            receipt["fallback_cleanup_error"] = repr(error)
    receipt["completed_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save()
sys.exit(0 if receipt["status"] == "PASS" else 1)
