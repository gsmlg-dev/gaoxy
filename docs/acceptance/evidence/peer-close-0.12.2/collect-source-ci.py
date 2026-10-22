import concurrent.futures
import datetime
import gzip
import hashlib
import json
import pathlib
import re
import subprocess
import tarfile

SOURCE = "55ed97d2b05ba2a8dd7c911472833e71dd6b87f7"
RUNS = (39801796629, 39801796801, 39801796992, 39801796659, 39801797113)
OUT = pathlib.Path("/tmp/gaoxy-release-0.12.2/source-ci-55ed97d2")
OUT.mkdir(parents=True, exist_ok=True)


def collect(run_id):
    raw = subprocess.check_output(
        ["gh", "run", "view", str(run_id), "--repo", "gsmlg-dev/gaoxy",
         "--json", "databaseId,name,status,conclusion,headSha,event,url,jobs"],
        timeout=60,
    )
    run = json.loads(raw)
    assert run["headSha"] == SOURCE, run
    (OUT / f"{run_id}.json").write_bytes(raw)
    completed = run["status"] == "completed"
    path = OUT / f"{run_id}.log.gz"
    if completed and not path.exists():
        logs = subprocess.check_output(
            ["gh", "run", "view", str(run_id), "--repo", "gsmlg-dev/gaoxy", "--log"],
            timeout=120,
        )
        path.write_bytes(gzip.compress(logs, mtime=0))
    count_lines = []
    if path.exists():
        for line in gzip.decompress(path.read_bytes()).decode().splitlines():
            if re.search(r"(REPAIR_PASS \d+ executed|INVENTORY_PASS|CONSUMER_PASS|^.*PORTABLE_HTTP_PASS)", line):
                count_lines.append(line)
    return run, count_lines


with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
    results = list(executor.map(collect, RUNS))

passed = all(run["status"] == "completed" and run["conclusion"] == "success"
             for run, _ in results)
jobs = [{"run_id": run["databaseId"], "name": job["name"],
         "status": job["status"], "conclusion": job["conclusion"]}
        for run, _ in results for job in run["jobs"]]
if passed:
    assert sum(job["conclusion"] == "success" for job in jobs) == 10, jobs
    assert sum(job["conclusion"] == "skipped" for job in jobs) == 1, jobs
receipt = {
    "result": "PASS" if passed else (
        "FAIL" if any(run["status"] == "completed" and run["conclusion"] != "success"
                      for run, _ in results) else "PENDING"),
    "observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "source_commit": SOURCE,
    "runs": [{key: run[key] for key in
              ("databaseId", "name", "status", "conclusion", "headSha", "event", "url")}
             for run, _ in results],
    "jobs": jobs,
    "executed_successful_jobs": sum(job["conclusion"] == "success" for job in jobs),
    "separate_manual_skipped_jobs": sum(job["conclusion"] == "skipped" for job in jobs),
}
base = OUT.parent
(base / "source-ci-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
(base / "source-ci-counts.json").write_text(json.dumps(
    {str(run["databaseId"]): lines for run, lines in results}, indent=2) + "\n")
if passed:
    archive = base / "source-ci-raw.tar.gz"
    with archive.open("wb") as sink:
        with gzip.GzipFile(filename="", mode="wb", fileobj=sink, mtime=0) as compressed:
            with tarfile.open(mode="w", fileobj=compressed) as tar:
                for path in sorted(OUT.iterdir()):
                    info = tar.gettarinfo(str(path), arcname=f"source-ci/{path.name}")
                    info.uid = info.gid = 0
                    info.uname = info.gname = ""
                    info.mtime = 0
                    with path.open("rb") as stream:
                        tar.addfile(info, stream)
    print("archive_sha256", hashlib.sha256(archive.read_bytes()).hexdigest())
print(json.dumps(receipt, indent=2))
