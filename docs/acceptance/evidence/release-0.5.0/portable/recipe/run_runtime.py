"""Qualify exported package in one owned, fresh offline runtime container."""
import datetime
import json
from pathlib import Path
import re
import subprocess
import sys
import time

started = time.monotonic()
root = Path(sys.argv[1]).resolve()
name = sys.argv[2]
assert re.fullmatch(r"gaoxy-release-050-portable-[0-9a-f]{32}", name), name
deadline = min(float(sys.argv[3]), started + 300)
work_deadline = deadline - 30
evidence = root / "evidence" / "fresh-runtime"
evidence.mkdir(parents=True, exist_ok=True)
receipt = {"owned_name": name, "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
           "timeout_seconds": deadline - started, "cleanup_reserve_seconds": 30,
           "status": "FAIL", "commands": []}


def save():
    receipt["elapsed_seconds"] = time.monotonic() - started
    (evidence / "launch.json").write_text(json.dumps(receipt, indent=2) + "\n")


def docker(stage, arguments, cleanup=False, maximum=10, require_zero=True):
    limit = deadline if cleanup else work_deadline
    timeout = min(maximum, limit - time.monotonic())
    row = {"name": stage, "command": ["docker", *arguments], "timeout_seconds": timeout}
    receipt["commands"].append(row)
    save()
    tick = time.monotonic()
    try:
        assert timeout > 0, f"{stage}: absolute runtime budget exhausted"
        result = subprocess.run(row["command"], capture_output=True, text=True, timeout=timeout)
        row["exit_code"] = result.returncode
        (evidence / f"{stage}.log").write_text(result.stdout + result.stderr)
        if require_zero:
            result.check_returncode()
        return result
    except BaseException as error:
        row["error"] = repr(error)
        row["timed_out"] = isinstance(error, subprocess.TimeoutExpired)
        if isinstance(error, subprocess.TimeoutExpired):
            output = (error.stdout or b"") + (error.stderr or b"")
            (evidence / f"{stage}.log").write_bytes(output)
        raise
    finally:
        row["elapsed_seconds"] = time.monotonic() - tick
        save()


def inspect(stage, cleanup=False):
    data = json.loads(docker(stage, ["inspect", name], cleanup, maximum=3).stdout)[0]
    assert data["Name"] == "/" + name, data["Name"]
    (evidence / f"{stage}.json").write_text(json.dumps(data, indent=2) + "\n")
    return data


save()  # Persist ownership before image inspection or potentially partial create.
qualified = cleanup_complete = False


def container_absent(code, output):
    return code != 0 and re.search(
        r"(?:^|\n)(?i:(?:error(?: response from daemon)?:\s*)?no such (?:object|container):\s*)"
        + re.escape(name) + r"\s*$", output
    ) is not None


try:
    image = docker("image-inspect", ["image", "inspect", "gaoxy-release-050-portable-runtime:local", "--format", "{{.Id}}"]).stdout.strip()
    receipt["image_id"] = image
    command = ["create", "--name", name, "--network", "none", "--platform", "linux/amd64",
               "--mount", f"type=bind,source={root / 'artifacts'},target=/artifacts,readonly",
               "--mount", f"type=bind,source={evidence},target=/evidence", image]
    receipt["create_command"] = ["docker", *command]
    receipt["container_id"] = docker("container-create", command).stdout.strip()
    docker("container-start", ["start", name])
    live = inspect("container-inspect-live")
    assert live["State"]["Running"], live["State"]
    assert live["HostConfig"]["NetworkMode"] == "none", live["HostConfig"]["NetworkMode"]
    assert live["Image"] == image
    code = docker("container-wait", ["wait", name], maximum=300).stdout.strip()
    receipt["container_exit_code"] = int(code)
    assert receipt["container_exit_code"] == 0, receipt
    result = json.loads((evidence / "runtime-result.json").read_text())
    assert result["status"] == "PASS"
    qualified = True
except BaseException as error:
    receipt["error"] = repr(error)
finally:
    cleanup_errors = []
    try:
        before = inspect("container-inspect-before-cleanup", cleanup=True)
        if before["State"]["Running"]:
            qualified = False  # Forced cleanup can never turn a failed run into PASS.
            docker("container-stop", ["stop", "--time", "10", name], cleanup=True, maximum=12)
    except BaseException as error:
        cleanup_errors.append(repr(error))
    try:
        logs = docker("container-logs", ["logs", name], cleanup=True, maximum=3)
        (evidence / "container.log").write_text(logs.stdout + logs.stderr)
        print(logs.stdout + logs.stderr, end="")
    except BaseException as error:
        cleanup_errors.append(repr(error))
    try:
        final = inspect("container-inspect-final", cleanup=True)
        receipt["container_exit_code"] = final["State"]["ExitCode"]
        assert not final["State"]["Running"]
        assert not qualified or final["State"]["ExitCode"] == 0
        cleanup_complete = not cleanup_errors
    except BaseException as error:
        cleanup_errors.append(repr(error))
    finally:
        if cleanup_errors:
            receipt["cleanup_errors"] = cleanup_errors
        try:
            arguments = ["rm", name] if qualified and cleanup_complete else ["rm", "--force", name]
            removed = docker("container-remove", arguments, cleanup=True, maximum=3, require_zero=False)
            receipt["owned_container_removed"] = removed.returncode == 0
            absent = docker("container-absence", ["inspect", name], cleanup=True, maximum=3, require_zero=False)
            receipt["owned_container_absent"] = container_absent(absent.returncode, absent.stderr)
            if qualified and cleanup_complete and receipt["owned_container_removed"] and receipt["owned_container_absent"]:
                receipt["status"] = "PASS"
        except BaseException as error:
            receipt["removal_error"] = repr(error)
        receipt["completed_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        save()
sys.exit(0 if receipt["status"] == "PASS" else 1)
