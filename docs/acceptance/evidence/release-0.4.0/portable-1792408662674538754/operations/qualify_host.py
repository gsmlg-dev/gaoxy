"""Qualify only the frozen committed v0.4.0 source; never publish from here."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tarfile
import time

ROOT = Path(__file__).resolve().parents[2]
RUN = Path(__file__).resolve().parent / f"portable-{time.time_ns()}"
CONTEXT = RUN / "context"
ARTIFACTS = RUN / "artifacts"
EVIDENCE = RUN / "evidence"
for path in (CONTEXT, ARTIFACTS, EVIDENCE):
    path.mkdir(parents=True, exist_ok=False)
RECEIPT = EVIDENCE / "host-qualification.json"
receipt = {"status": "FAIL", "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
           "cwd": str(ROOT), "run_directory": str(RUN), "commands": []}


def save():
    RECEIPT.write_text(json.dumps(receipt, indent=2) + "\n")


def command(name, args, timeout=60, binary=False):
    row = {"name": name, "command": args, "timeout_seconds": timeout,
           "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    receipt["commands"].append(row)
    save()
    result = subprocess.run(args, cwd=ROOT, capture_output=True, timeout=timeout)
    row["exit_code"] = result.returncode
    row["stdout_sha256"] = hashlib.sha256(result.stdout).hexdigest()
    row["stderr_sha256"] = hashlib.sha256(result.stderr).hexdigest()
    (EVIDENCE / f"{name}.stdout").write_bytes(result.stdout)
    (EVIDENCE / f"{name}.stderr").write_bytes(result.stderr)
    save()
    result.check_returncode()
    return result.stdout if binary else result.stdout.decode().strip()


def execute(name, args, timeout):
    row = {"name": name, "command": args, "timeout_seconds": timeout,
           "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    receipt["commands"].append(row)
    save()
    process = None
    tick = time.monotonic()
    try:
        with (EVIDENCE / f"{name}.log").open("wb") as output:
            process = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            process.wait(timeout=timeout)
        row["exit_code"] = process.returncode
        assert process.returncode == 0, (name, process.returncode)
    except BaseException as error:
        row["error"] = repr(error)
        if process is not None and process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=10)
            row["exit_code"] = process.returncode
        raise
    finally:
        row["elapsed_seconds"] = time.monotonic() - tick
        row["completed_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        row["log_sha256"] = hashlib.sha256((EVIDENCE / f"{name}.log").read_bytes()).hexdigest()
        save()


print(str(RUN), flush=True)
try:
    assert command("clean-source", ["git", "status", "--porcelain"]) == ""
    source = command("source-sha", ["git", "rev-parse", "HEAD"])
    receipt["source_sha"] = source
    archive_bytes = command("source-archive", ["git", "archive", "--format=tar", source], 180, True)
    (CONTEXT / "source.tar").write_bytes(archive_bytes)
    paths = command("changed-elixir", ["git", "diff", "--name-only", "--diff-filter=ACMR",
                    "v0.3.0", source, "--", "*.ex", "*.exs"]).splitlines()
    tracked = dict(line.split("\t", 1)[::-1] for line in command(
        "git-tree", ["git", "ls-tree", "-r", source]).splitlines())
    with tarfile.open(CONTEXT / "source.tar") as archive:
        original = {m.name: archive.extractfile(m).read() for m in archive.getmembers() if m.isfile()}
    assert set(original) == {name for name, metadata in tracked.items() if metadata.startswith("100")}
    for name, data in original.items():
        object_id = hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest()
        assert object_id == tracked[name].split()[-1], name
    assert all(path in original for path in paths) and paths
    lock_sha = hashlib.sha256(original["mix.lock"]).hexdigest()
    assert lock_sha == "c93b608b77c457e4324430544c1acc2b384ee21e1a2b8ab528bad248ac666cb6"
    identity = {"version": "0.4.0", "source_sha": source,
                "source_archive_sha256": hashlib.sha256(archive_bytes).hexdigest(),
                "root_lock_sha256": lock_sha, "changed_elixir_paths": paths}
    (CONTEXT / "source-identity.json").write_text(json.dumps(identity, indent=2) + "\n")
    recipe_prefix = "docs/acceptance/evidence/release-0.4.0/portable/recipe/"
    recipes = {name.removeprefix(recipe_prefix): data for name, data in original.items()
               if name.startswith(recipe_prefix)}
    assert len(recipes) == 8 and all("/" not in name for name in recipes)
    for name, data in recipes.items():
        (CONTEXT / name).write_bytes(data)
    receipt["identity"] = identity
    receipt["archive_regular_files_verified_against_git_blobs"] = len(original)
    receipt["recipe_sha256"] = {name: hashlib.sha256(data).hexdigest() for name, data in recipes.items()}
    save()
    execute("docker-portable-build", ["docker", "buildx", "build", "--platform", "linux/amd64",
            "--progress", "plain", "--target", "artifact", "--output", f"type=local,dest={ARTIFACTS}",
            str(CONTEXT)], 3600)
    execute("finalize", [sys.executable, str(CONTEXT / "finalize.py"), str(ARTIFACTS)], 120)
    execute("runtime-qualification", [sys.executable, str(CONTEXT / "qualify_runtime.py"), str(RUN)], 620)
    assert command("frozen-source-final", ["git", "rev-parse", "HEAD"]) == source
    assert command("clean-source-final", ["git", "status", "--porcelain"]) == ""
    info = json.loads((ARTIFACTS / "build-info.json").read_text())
    runtime = json.loads((EVIDENCE / "fresh-runtime/runtime-result.json").read_text())
    stages = json.loads((EVIDENCE / "runtime-qualification-stages.json").read_text())
    assert info["source_sha"] == runtime["source_sha"] == source
    assert runtime["status"] == stages["status"] == "PASS"
    receipt["artifact_sha256"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                  for p in sorted(ARTIFACTS.iterdir()) if p.is_file()}
    assert set(receipt["artifact_sha256"]) == {"gaoxy-0.4.0-linux-x86_64.tar.gz", "build-info.json", "SHA256SUMS"}
    receipt["status"] = "PASS"
except BaseException as error:
    receipt["error"] = repr(error)
    raise
finally:
    receipt["completed_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save()
print("PASS frozen source portable builder and offline runtime", flush=True)
