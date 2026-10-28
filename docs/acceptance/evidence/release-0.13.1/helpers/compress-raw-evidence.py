#!/usr/bin/env python3
"""Preserve raw evidence bytes while removing their whitespace from Git diffs."""
import gzip
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIT = ROOT / ".audit/release-0.13.1"
DEST = ROOT / "docs/acceptance/evidence/release-0.13.1"
path = DEST / "evidence-manifest.json"
manifest = json.loads(path.read_text())
before = hashlib.sha256(path.read_bytes()).hexdigest()
entries = {entry["path"]: entry for entry in manifest["copies"]}
changes = []
for name in ("issue-18/frozen-integrated-diff.patch", "source-ci.json",
             "source-ci-details.json", "final-github-mcp-issue-audit.json"):
    entry = dict(entries.pop(name))
    original = (ROOT / entry["original"]).read_bytes()
    old = DEST / name
    if old.read_bytes() != original or hashlib.sha256(original).hexdigest() != entry["original_sha256"]:
        raise RuntimeError(f"raw evidence changed: {name}")
    compressed = gzip.compress(original, mtime=0)
    target = name + ".gz"
    (DEST / target).write_bytes(compressed)
    if gzip.decompress((DEST / target).read_bytes()) != original:
        raise RuntimeError(f"gzip roundtrip differs: {name}")
    entry.update(path=target, gzip=True, archived_bytes=len(compressed),
                 archived_sha256=hashlib.sha256(compressed).hexdigest())
    entries[target] = entry
    old.unlink()
    changes.append({"from": name, "to": target, "decoded_sha256": entry["original_sha256"]})

receipt = {"status": "COMPRESSED; full Git whitespace verification follows",
           "source_commit": manifest["source_commit"], "previous_manifest_sha256": before,
           "reason": "Preserve the reviewed raw patch and JSON bytes including their original whitespace",
           "changes": changes, "product_or_test_changes": False}
(AUDIT / "raw-evidence-compression.json").write_text(json.dumps(receipt, indent=2) + "\n")
for name, target in (("compress-raw-evidence.py", "helpers/compress-raw-evidence.py"),
                     ("raw-evidence-compression.json", "raw-evidence-compression.json"),
                     ("archive-whitespace-initial.log", "archive-whitespace-initial.log.gz"),
                     ("archive-whitespace-initial.json", "archive-whitespace-initial.json")):
    original = (AUDIT / name).read_bytes()
    compressed = name.endswith(".log")
    data = gzip.compress(original, mtime=0) if compressed else original
    (DEST / target).write_bytes(data)
    entries[target] = {"original": str((AUDIT / name).relative_to(ROOT)), "path": target,
                       "gzip": compressed, "original_bytes": len(original),
                       "original_sha256": hashlib.sha256(original).hexdigest(),
                       "archived_bytes": len(data), "archived_sha256": hashlib.sha256(data).hexdigest()}
manifest["copies"] = [entries[key] for key in sorted(entries)]
path.write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps({"compressed_raw_files": len(changes), "archived_copies": len(entries), "decoded_bytes_unchanged": True}))
