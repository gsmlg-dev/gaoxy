#!/usr/bin/env python3
"""Archive selected immutable release receipts without changing their contents."""
import gzip
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
AUDIT = ROOT / ".audit/release-0.13.0"
OUT = ROOT / "docs/acceptance/evidence/release-0.13.0"
PUBLIC = AUDIT / "public-runtime-verification-o_yath33"
REGRESSIONS = AUDIT / "public-regressions-rbuk_a7g"
SHA = "bd325eb408d4566b807bcef9fdaf1a2b1ad83a2d"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_json(path):
    return json.loads(path.read_text())


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


assert subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() == SHA
assert not subprocess.check_output(["git", "diff", "HEAD", "--", "apps", "vendor"], cwd=ROOT)
OUT.mkdir(exist_ok=False)
manifest = []


def archive(source, name, compress=False):
    data = source.read_bytes()
    target = OUT / name
    assert not target.exists(), target
    target.parent.mkdir(parents=True, exist_ok=True)
    archived = gzip.compress(data, mtime=0) if compress else data
    target.write_bytes(archived)
    manifest.append({"path": name, "original": str(source.relative_to(ROOT)),
                     "original_bytes": len(data), "original_sha256": digest(data),
                     "archived_bytes": len(archived), "archived_sha256": digest(archived),
                     "gzip": compress})


for source, name in [
    (AUDIT / "source-ci-bd325eb4.json", "source-ci.json"),
    (AUDIT / "source-ci-details-bd325eb4.json", "source-ci-details.json"),
    (AUDIT / "release-dispatch.json", "release-dispatch.json"),
    (AUDIT / "release-run.json", "release-run.json"),
    (AUDIT / "release-final.log.gz", "release.log.gz"),
    (AUDIT / "final-gates.json", "local-gates.json"),
    (AUDIT / "final-peer-replacement-gates.json", "local-peer-gates.json"),
    (AUDIT / "ci-consumer-final-gates.json", "local-consumer-gates.json"),
    (AUDIT / "ci-source-h3-consumer-green.json", "source-h3-consumer.json"),
    (AUDIT / "optional-quic-lock/summary.json", "optional-quic-lock.json"),
    (PUBLIC / "summary.json", "public-verification-summary.json"),
    (PUBLIC / "runtime-receipt.json", "downloaded-runtime-receipt.json"),
    (PUBLIC / "public-artifacts-sff7ug_t/receipt.json", "public-artifacts-receipt.json"),
    (PUBLIC / "public-artifacts-sff7ug_t/github-release.json", "github-release.json"),
    (PUBLIC / "host-https-trust.json", "host-https-trust.json"),
    (PUBLIC / "parser-controls.json", "parser-controls.json"),
    (PUBLIC / "parser-repair.patch", "parser-repair.patch"),
    (PUBLIC / "independent-review.json", "independent-public-review.json"),
    (REGRESSIONS / "receipt.json", "public-issue-regressions.json"),
    (AUDIT / "public-issue-validation-environment.json", "public-issue-environment.json"),
    (AUDIT / "public-artifacts-vwr9489l/receipt.json", "historical/artifacts-ca-failure.json"),
    (AUDIT / "public-artifacts-pnhqzbua/receipt.json", "historical/artifacts-parser-failure.json"),
    (AUDIT / "public-regressions-l7r3oa39/receipt.json", "historical/public-regression-ca-failure.json"),
    (AUDIT / "post-review-gates.json", "historical/aioquic-post-review-gates.json"),
    (AUDIT / "post-review-unified/report.json", "historical/aioquic-post-review-report.json"),
    (AUDIT / "diagnosis-h3-reproduction/result.json", "historical/aioquic-reproduction.json"),
    (AUDIT / "diagnosis-h3-summary.md", "historical/aioquic-diagnosis.md"),
    (AUDIT / "ci-e7d294d0-consumer-red.json", "historical/first-consumer-failure.json"),
    (AUDIT / "source-ci-e7d294d0.json", "historical/first-source-ci.json"),
]:
    archive(source, name)

for original, name in [
    (AUDIT / "verify-public-artifacts.py", "helpers/verify-public-artifacts.py"),
    (PUBLIC / "verify-public-artifacts-keyword.py", "helpers/verify-public-artifacts-keyword.py"),
    (PUBLIC / "parser-control-runner.py", "helpers/parser-control-runner.py"),
    (PUBLIC / "downloaded-runtime.py", "helpers/downloaded-runtime.py"),
    (AUDIT / "public-issue-regressions.py", "helpers/public-issue-regressions.py"),
]:
    archive(original, name)

for name in ["core", "gateway", "h3"]:
    archive(PUBLIC / f"{name}.log", f"runtime/{name}.log.gz", compress=True)
for name in ["unit", "component", "protocol", "inventory", "dependencies"]:
    archive(AUDIT / f"final-{name}.log", f"local/{name}.log.gz", compress=True)
for path in sorted(REGRESSIONS.glob("*.log")):
    archive(path, f"public-issues/{path.name}.gz", compress=True)
for path in sorted((PUBLIC / "public-artifacts-sff7ug_t").glob("hex-*.json")):
    archive(path, path.name)
for source, name in [
    (AUDIT / "ci-e7d294d0-package-failed.log", "historical/first-package-failure.log.gz"),
    (AUDIT / "diagnosis-h3-reproduction.log", "historical/aioquic-reproduction.log.gz"),
    (AUDIT / "public-regressions-l7r3oa39/03-python-peer-dependencies.log", "historical/public-regression-ca-failure.log.gz"),
    (PUBLIC / "artifact-verifier.log", "historical/artifact-verifier-ca-failure.log.gz"),
    (PUBLIC / "artifact-verifier-system-ca.log", "historical/artifact-verifier-parser-failure.log.gz"),
    (PUBLIC / "artifact-verifier-keyword.log", "artifact-verifier.log.gz"),
]:
    archive(source, name, compress=True)

for consumer, directory in [("native", REGRESSIONS / "workspace/apps/gaoxy_http"),
                            ("phoenix", REGRESSIONS / "workspace/examples/phoenix_native")]:
    for name in ["mix.exs", "mix.lock"]:
        archive(directory / name, f"public-issues/{consumer}-{name}")

tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
selected = [p for p in tracked if p.startswith(("apps/", "vendor/")) and p.endswith((".ex", ".exs"))]
canonical = read_json(AUDIT / "qualification-source-files.json")
final = read_json(AUDIT / "final-publication-source.json")
fingerprints = {p: digest((ROOT / p).read_bytes()) for p in selected}
assert all(canonical.get(p) == final["files"].get(p) == h for p, h in fingerprints.items())
write_json(OUT / "source-bridge.json", {
    "status": "PASS", "source_commit": SHA, "tracked_elixir_files": len(selected),
    "tracked_product_and_test_files_match_canonical_and_prepublication_receipts": True,
    "canonical_receipt_sha256": digest((AUDIT / "qualification-source-files.json").read_bytes()),
    "prepublication_receipt_sha256": digest((AUDIT / "final-publication-source.json").read_bytes()),
    "fingerprints": fingerprints,
    "prepublication_review": final["independent_review"],
    "later_client_and_lock_changes": "Requalified by all exact-source hosted workflows and release run.",
})

log = gzip.decompress((AUDIT / "release-final.log.gz").read_bytes()).decode()
assert "REPAIR_PASS 568 executed, 0 failures, 0 excluded, 0 skipped" in log
steps = {}
for step in ["Isolated core, HTTP, H3 and Gateway consumers on publication source",
             "Built-package test consumers and production dependency isolation",
             "Phoenix client-certificate, large-message and streaming regressions",
             "Fresh Hex-only test consumers after publication"]:
    rows = [line for line in log.splitlines() if f"\t{step}\t" in line]
    counts = [(int(a), int(b)) for a, b in re.findall(r"\b(\d+) tests?, (\d+) failures\b", "\n".join(rows))]
    assert counts and all(b == 0 for _, b in counts), (step, counts)
    steps[step] = {"executed": sum(a for a, _ in counts), "failures": 0, "summaries": counts}
ci = read_json(AUDIT / "source-ci-details-bd325eb4.json")
jobs = [j for run in ci for j in run["jobs"]]
assert sum(j["conclusion"] == "success" for j in jobs) == 10
assert sum(j["conclusion"] == "skipped" for j in jobs) == 1
write_json(OUT / "qualification-counts.json", {
    "status": "PASS", "source_commit": SHA, "source_workflows": 5,
    "source_successful_jobs": 10, "separately_gated_released_server_jobs_skipped": 1,
    "canonical": {"unit": 254, "component": 181, "protocol": 133, "executed": 568,
                  "failures": 0, "excluded": 0, "skipped": 0},
    "release_log_raw_sha256": digest(log.encode()), "release_test_steps": steps,
    "public_issue_tests": read_json(REGRESSIONS / "receipt.json")["executed"],
    "downloaded_runtime_checks": read_json(PUBLIC / "runtime-receipt.json")["verified_checks"],
})
archive(Path(__file__).resolve(), "helpers/collect-final-evidence.py")
write_json(OUT / "evidence-manifest.json", {"source_commit": SHA, "copies": manifest})
print(json.dumps({"status": "PASS", "archived_files": len(manifest), "elixir_source_files": len(selected),
                  "output": str(OUT), "bytes": sum(p.stat().st_size for p in OUT.rglob("*") if p.is_file())}))
