import datetime
import json
from pathlib import Path
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

HERE = Path(__file__).resolve().parent
SOURCE = "aaa613985b08edd146f393ddd48f65fd6f3665b2"
RUNS = [39550306889, 39550306891, 39550306902]
OUT = HERE / "hosted-ci"
OUT.mkdir(exist_ok=True)

def read(run):
    result = subprocess.run(["gh", "api", f"repos/gsmlg-dev/gaoxy/actions/runs/{run}"],
                            capture_output=True, text=True, check=True, timeout=45)
    data = json.loads(result.stdout)
    assert data["head_sha"] == SOURCE and data["head_branch"] == "main" and data["event"] == "push"
    return data

previous = None
for attempt in range(80):
    with ThreadPoolExecutor(max_workers=3) as pool:
        rows = list(pool.map(read, RUNS))
    stamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
    snapshot = {"source": SOURCE, "captured_utc": stamp, "runs": rows}
    (OUT / f"snapshot-{attempt:03d}.json").write_text(json.dumps(snapshot, indent=2) + "\n")
    summary = [(r["id"], r["name"], r["status"], r["conclusion"]) for r in rows]
    if summary != previous:
        print(stamp, json.dumps(summary), flush=True)
        previous = summary
    if all(r["status"] == "completed" for r in rows):
        passed = all(r["conclusion"] == "success" for r in rows)
        snapshot["status"] = "PASS" if passed else "FAIL"
        for row in rows:
            result = subprocess.run(["gh", "api", f"repos/gsmlg-dev/gaoxy/actions/runs/{row['id']}/jobs?per_page=100"],
                                    capture_output=True, text=True, check=True, timeout=45)
            (OUT / f"jobs-{row['id']}.json").write_text(result.stdout)
        (OUT / "result.json").write_text(json.dumps(snapshot, indent=2) + "\n")
        print(snapshot["status"], "required CI", SOURCE, flush=True)
        sys.exit(0 if passed else 1)
    time.sleep(30)
raise SystemExit("CI observation timeout; no publication authorized by this watcher")
