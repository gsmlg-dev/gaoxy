"""Archive bounded release receipts losslessly; assets/source archives stay external."""
import datetime
import gzip
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
AUDIT = Path(__file__).resolve().parent
RUN, PUBLICATION = [Path(value).resolve() for value in sys.argv[1:]]
DEST = ROOT / "docs/acceptance/evidence/release-0.5.0" / RUN.name
DEST.mkdir(exist_ok=False)
manifest = []


def archive(source, relative):
    data = source.read_bytes()
    assert not re.search(rb"(?m)^-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----\r?$", data), str(source)
    compress = len(data) > 65536
    encoded = gzip.compress(data, mtime=0) if compress else data
    target = DEST / (str(relative) + (".gz" if compress else ""))
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("xb") as output:
        output.write(encoded)
    assert (gzip.decompress(target.read_bytes()) if compress else target.read_bytes()) == data
    manifest.append({"original": str(source), "archived": str(target.relative_to(DEST)),
                     "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                     "stored_sha256": hashlib.sha256(encoded).hexdigest(), "round_trip": "PASS"})


for source_dir, label in ((RUN / "evidence", "host"), (RUN / "artifacts/evidence", "builder"),
                          (PUBLICATION, "publication")):
    for source in sorted(source_dir.rglob("*")):
        relative = source.relative_to(source_dir)
        if not source.is_file() or source.is_symlink():
            continue
        if label == "host" and relative.as_posix() == "source-archive.stdout":
            continue
        if label == "publication" and relative.parts[0] == "downloads":
            continue
        archive(source, Path(label) / relative)
for source in (RUN / "context/source-identity.json", RUN / "artifacts/build-info.json", RUN / "artifacts/SHA256SUMS"):
    archive(source, Path("metadata") / source.name)
for source in sorted(AUDIT.glob("*")):
    if source.is_file() and source.suffix in {".py", ".json", ".md"}:
        archive(source, Path("operations") / source.name)
(DEST / "manifest.json").write_text(json.dumps({"status": "PASS_LOSSLESS_ARCHIVE", "files": manifest,
    "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "omissions": "Large raw source archive is retained locally and bound by host Git/archive hashes; release assets remain on GitHub and in local qualified/download directories. No private keys are copied."}, indent=2) + "\n")
print(str(DEST))
print(f"PASS {len(manifest)} files archived with byte-for-byte round-trip verification")
