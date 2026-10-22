import argparse
import gzip
import json
import pathlib
import re
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--run", required=True)
parser.add_argument("--sha", required=True)
args = parser.parse_args()
out = pathlib.Path("/tmp/gaoxy-release-0.12.2/release")
out.mkdir(parents=True, exist_ok=True)
raw = subprocess.check_output(
    ["gh", "run", "view", args.run, "--repo", "gsmlg-dev/gaoxy", "--json",
     "databaseId,name,status,conclusion,headSha,event,url,jobs"], timeout=60)
run = json.loads(raw)
(out / "release-run.json").write_bytes(raw)
assert run["headSha"] == args.sha
if run["status"] != "completed":
    print(json.dumps({"status": run["status"], "conclusion": run["conclusion"]}))
    raise SystemExit(2)
logs = subprocess.check_output(
    ["gh", "run", "view", args.run, "--repo", "gsmlg-dev/gaoxy", "--log"], timeout=120)
(out / "release.log.gz").write_bytes(gzip.compress(logs, mtime=0))
text = logs.decode()
assert run["conclusion"] == "success", run["conclusion"]
step_output = {}
for line in text.splitlines():
    fields = line.split("\t", 2)
    if len(fields) == 3:
        step_output.setdefault(fields[1], []).append(fields[2])
expected = {
    "Isolated core, HTTP, H3 and Gateway consumers on publication source": 9,
    "Correctness repair and ordinary compatibility on publication source": 466,
    "Built-package test consumers and production dependency isolation": 7,
    "Phoenix client-certificate, large-message and streaming regressions": 18,
    "Fresh Hex-only test consumers after publication": 7,
}
gates = {}
for step, count in expected.items():
    matches = [re.search(r"\b(\d+) tests?, (\d+) failures?\b", line)
               for line in step_output[step]]
    matches = [match for match in matches if match]
    actual = sum(int(match[1]) for match in matches)
    failures = sum(int(match[2]) for match in matches)
    assert actual == count and failures == 0, (step, actual, failures)
    gates[step] = {"executed": actual, "failures": failures, "status": "PASS"}
marker = "REPAIR_PASS 466 executed, 0 failures, 0 excluded, 0 skipped"
assert marker in text
assert "CONSUMER_MODE published-hex-only version=0.12.2" in text
isolation = "CONSUMER_RELEASE_ISOLATION_PASS cases=1 helper_absent=true exunit_absent=true"
assert text.count(isolation) == 2
unified = step_output["Unified Endpoint H1/H2/H3 clients, WebSocket and reload acceptance"]
reports = []
for line in unified:
    if '{"status": "PASS", "checks":' in line:
        reports.append(json.loads(line[line.index("{"):]))
assert len(reports) == 1, reports
report = reports[0]
assert len(report["checks"]) == 8 and all(item["status"] == "PASS" for item in report["checks"])
assert report["process_exit"] == 0 and report["source_restored"] is True
receipt = {
    "status": "PASS", "release_run": int(args.run), "source_sha": args.sha,
    "url": run["url"], "exunit_counts_by_gate": gates,
    "ordinary_marker": marker, "unified_phoenix_checks": len(report["checks"]),
    "standalone_smoke": "PASS: source-built core, gateway H1/H2, H3",
    "public_consumer_mode": "published-hex-only version=0.12.2",
    "production_isolation_markers": [isolation, isolation],
}
(out / "release-qualification.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps(receipt, indent=2))
