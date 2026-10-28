#!/usr/bin/env python3
"""Archive explicitly selected terminal evidence without replacing prior bytes."""
import gzip
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "docs/acceptance/evidence/release-0.13.1"
SHA = "84c7ff76461ada8aebaa34c567c61206bc963d83"
DEST.mkdir(parents=True, exist_ok=True)
manifest = DEST / "evidence-manifest.json"
previous = json.loads(manifest.read_text()) if manifest.exists() else {"source_commit": SHA, "copies": []}
if previous["source_commit"] != SHA:
    raise RuntimeError("publication source differs")
entries = {entry["path"]: entry for entry in previous["copies"]}


def archive(source, target):
    original = ROOT / source
    raw = original.read_bytes()
    compressed = original.suffix == ".log"
    data = gzip.compress(raw, mtime=0) if compressed else raw
    name = target + (".gz" if compressed else "")
    destination = DEST / name
    if destination.exists() and destination.read_bytes() != data:
        raise RuntimeError(f"refusing to replace archived evidence: {name}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    entries[name] = {"original": str(original.relative_to(ROOT)), "path": name,
                     "gzip": compressed, "original_bytes": len(raw),
                     "original_sha256": hashlib.sha256(raw).hexdigest(),
                     "archived_bytes": len(data), "archived_sha256": hashlib.sha256(data).hexdigest()}
    if compressed and gzip.decompress(destination.read_bytes()) != raw:
        raise RuntimeError(f"archive roundtrip differs: {name}")


for path in sorted((ROOT / ".audit/internal-18/worker").iterdir()):
    if path.suffix in {".json", ".log"}:
        archive(path, "issue-18/worker/" + path.name)
for name in ("review.json", "local-qualification-review.json", "frozen-integrated-files.json", "frozen-integrated-diff.patch"):
    archive(".audit/internal-18/" + name, "issue-18/" + name)
for name in ("discovery-mcp.json", "issue-before.json"):
    archive(".audit/internal-18/parent/" + name, "issue-18/" + name)
for path in sorted((ROOT / ".audit/release-0.13.1/local-qualification-dwo5hmgr").iterdir()):
    if path.suffix in {".json", ".log"}:
        archive(path, "local/" + path.name)
for name in ("environment.json", "source-bridge.json", "prepublication-hex-state.json", "public-issue-harness-controls.json"):
    archive(".audit/release-0.13.1/" + name, name)
for name in ("qualify-local.py", "public-issue-regressions.py", "archive-evidence.py"):
    archive(".audit/release-0.13.1/" + name, "helpers/" + name)
for name in ("verify-public-artifacts.py", "downloaded-runtime.py", "preparation.json", "runtime-preparation.json", "offline-controls.json"):
    archive(".audit/release-0.13.1/public-verification/" + name, "public-preparation/" + name)

extra = ROOT / ".audit/release-0.13.1/final-archive-spec.json"
if extra.exists():
    for source, target in json.loads(extra.read_text()):
        archive(source, target)

manifest.write_text(json.dumps({"source_commit": SHA, "copies": [entries[key] for key in sorted(entries)]}, indent=2) + "\n")
print(json.dumps({"status": "PASS", "manifest": str(manifest), "archived_files": len(entries)}))
