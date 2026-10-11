"""Import immutable portable receipts and lossless logs after qualification."""
import gzip
import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
portable = root / ".audit/release-0.2.0-portable"
target = root / "docs/acceptance/evidence/release-0.2.0/portable"
assert json.loads((portable / "evidence/fresh-runtime/runtime-result.json").read_text())["status"] == "PASS"
assert not target.exists(), "Do not overwrite an imported evidence snapshot"
files = {}

def copy(source, relative):
    data = source.read_bytes()
    zipped = source.suffix in {".log", ".erl", ".diff"}
    if zipped:
        relative = Path(str(relative) + ".gz")
        stored = gzip.compress(data, mtime=0)
        assert gzip.decompress(stored) == data
    else:
        stored = data
    destination = target / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(stored)
    files[str(relative)] = {"sha256": hashlib.sha256(stored).hexdigest(), "bytes": len(stored), "original_sha256": hashlib.sha256(data).hexdigest(), "original_bytes": len(data), "encoding": "lossless gzip" if zipped else "original bytes"}

for source in sorted((portable / "evidence").rglob("*")):
    if source.is_file():
        copy(source, Path("execution") / source.relative_to(portable / "evidence"))
for source in sorted((portable / "artifacts/evidence").rglob("*")):
    if source.is_file():
        copy(source, Path("build") / source.relative_to(portable / "artifacts/evidence"))
for source in sorted((portable / "context").iterdir()):
    if source.is_file() and source.name != "source.tar":
        copy(source, Path("recipe") / source.name)
for name in ["build-info.json", "SHA256SUMS"]:
    copy(portable / "artifacts" / name, Path(name))
for source in sorted(portable.iterdir()):
    if source.is_file() and source.suffix in {".md", ".json"}:
        copy(source, Path(source.name))
for source in sorted((portable / "runtime-attempt-astra1").rglob("*")):
    if source.is_file():
        copy(source, Path("snapshots/runtime-attempt-astra1") / source.relative_to(portable / "runtime-attempt-astra1"))
(target / "manifest.json").write_text(json.dumps({"source_sha": "32ec599790ccddb477345a765681f74852e5ffc0", "source_archive_sha256": hashlib.sha256((portable / "context/source.tar").read_bytes()).hexdigest(), "files": files}, indent=2) + "\n")
print(json.dumps({"files_imported": len(files), "stored_bytes": sum(row["bytes"] for row in files.values())}))
