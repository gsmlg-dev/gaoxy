"""Bind successful fresh builder/runtime evidence and exact release assets."""
import datetime
import hashlib
import json
from pathlib import Path

AUDIT = Path(__file__).resolve().parent
ROOT = AUDIT.parents[1]
RUN = Path(json.loads((AUDIT / "active-run.json").read_text())["run_directory"])
IDENTITY = json.loads((RUN / "context/source-identity.json").read_text())
SOURCE = IDENTITY["source_sha"]
ARTIFACTS = RUN / "artifacts"
NAMES = ["gaoxy-0.5.0-linux-x86_64.tar.gz", "build-info.json", "SHA256SUMS"]
HELL = {"application": "hell", "version": "0.1.2",
        "source_url": "https://github.com/gsmlg-dev/hell.git",
        "git_sha": "59eed42b019ca41413d1b8cd7a7dc3e344bb93ee",
        "root_lock_sha256": "9f04f56f7b3389e217803614537133cda21a6bc176d2499fdcee6128292f0777"}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


receipts = {}
for name in ("build", "finalize", "runtime"):
    path = RUN / f"evidence/host-{name}.json"
    row = json.loads(path.read_text())
    assert row["source_sha"] == SOURCE and row["status"] == "PASS" and row["exit_code"] == 0, row
    assert sha(RUN / f"evidence/host-{name}.log") == row["log_sha256"], name
    receipts[name] = {"receipt_sha256": sha(path), "log_sha256": row["log_sha256"]}
prepared = json.loads((RUN / "evidence/source-preparation.json").read_text())
assert prepared["source_sha"] == SOURCE and prepared["identity"] == IDENTITY
assert sha(RUN / "context/source.tar") == IDENTITY["source_archive_sha256"]
assert sha(ROOT / "mix.lock") == IDENTITY["root_lock_sha256"] == HELL["root_lock_sha256"]
for name, digest in prepared["recipe_sha256"].items():
    assert sha(RUN / "context" / name) == digest, name
    assert sha(ROOT / "docs/acceptance/evidence/release-0.5.0/portable/recipe" / name) == digest, name
info = json.loads((ARTIFACTS / "build-info.json").read_text())
for key in ("version", "source_sha", "source_archive_sha256", "root_lock_sha256"):
    assert info[key] == IDENTITY[key], key
assert info["hell_provenance"] == HELL
assert info["source_files_checked_unchanged"] == prepared["source_regular_files"] > 0
assert info["applications"] == {app: "0.5.0" for app in
                                ("gaoxy", "gaoxy_http", "gaoxy_http3", "gaoxy_proxy", "gaoxy_server")}
scope = json.loads((RUN / "context/ordinary-scope.json").read_text())
assert info["ordinary_scope_sha256"] == sha(RUN / "context/ordinary-scope.json")
assert info["ordinary_suites"] == [{"name": batch["name"], "command": batch["command"],
                                     "applications": batch["applications"], "status": "PASS"}
                                    for batch in scope["batches"]]
counts = {key: sum(row[key] for suite in info["ordinary_suites"]
                   for row in suite["applications"].values())
          for key in ("executed", "excluded", "failures", "skipped")}
assert counts == {"executed": 210, "excluded": 144, "failures": 0, "skipped": 0}, counts
assert info["compatibility_tests"] == 210 and info["compatibility_failures"] == 0
assert info["checks"] and all(row["exit_code"] == 0 for row in info["checks"])
assert len([row for row in info["checks"] if row["name"] == "packaged-hell-startup"]) == 1
runtime = json.loads((RUN / "evidence/fresh-runtime/runtime-result.json").read_text())
assert runtime["status"] == "PASS" and runtime["source_sha"] == SOURCE
assert runtime["archive_sha256"] == info["archive_sha256"]
assert runtime["hell_provenance"] == HELL
assert runtime["network"] == "none" and runtime["platform"] == "linux/amd64"
assert runtime["elf_objects_checked"] > 0
assert runtime["missing_libraries"] == runtime["nix_elf_dependencies"] == 0
assert len([row for row in runtime["checks"] if row["name"] == "packaged-hell-startup"]) == 1
assert all(row["exit_code"] == 0 for row in runtime["checks"])
for result in (info, runtime):
    assert (result["core_transports"], result["gateway_exchanges"], result["h3_checks"]) == (3, 2, 3)
    profiles = result["packaged_websocket_profiles"]
    assert [row["protocol"] for row in profiles] == ["h2", "h2c", "h3"]
    assert all(row["status"] == "PASS" and row["executed"] == 15 and row["failures"] == 0
               for row in profiles)
launch = json.loads((RUN / "evidence/fresh-runtime/launch.json").read_text())
stages = json.loads((RUN / "evidence/runtime-qualification-stages.json").read_text())
assert launch["status"] == stages["status"] == "PASS"
assert launch["owned_container_removed"] and launch["owned_container_absent"] and stages["owned_container_absent"]
assert launch["container_exit_code"] == 0
digests = {name: sha(ARTIFACTS / name) for name in NAMES}
assert digests[NAMES[0]] == info["archive_sha256"]
sums = (ARTIFACTS / "SHA256SUMS").read_text().splitlines()
assert len(sums) == 2
assert dict(line.split("  ")[::-1] for line in sums) == {name: digests[name] for name in NAMES[:2]}
receipt = {"status": "PASS", "source_sha": SOURCE, "identity": IDENTITY,
           "completed_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
           "artifact_sha256": digests, "ordinary_counts": counts,
           "hell_provenance": HELL, "source_regular_files": prepared["source_regular_files"],
           "archive_entries": info["archive_entries"], "elf_objects_checked": runtime["elf_objects_checked"],
           "builder_websocket_profiles": info["packaged_websocket_profiles"],
           "runtime_websocket_profiles": runtime["packaged_websocket_profiles"],
           "command_receipts": receipts,
           "runtime_qualification_sha256": sha(RUN / "evidence/runtime-qualification-stages.json"),
           "runtime_result_sha256": sha(RUN / "evidence/fresh-runtime/runtime-result.json"),
           "owned_container_absent": True}
path = RUN / "evidence/host-qualification.json"
assert not path.exists()
path.write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps(receipt, indent=2))
