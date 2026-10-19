"""Archive completed ordinary repair evidence; run only after the builder stops."""
import argparse
import datetime
import gzip
import hashlib
import json
from pathlib import Path
import re


AUDIT = Path(__file__).resolve().parent
ROOT = AUDIT.parents[1]
RUN = AUDIT / "group-compat-repair3"
DEST = ROOT / "docs/acceptance/evidence/release-0.4.0/group-compat-repair3"
PRIVATE_KEY = re.compile(rb"(?m)^-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----\r?$")
EXTRAS = [
    "review-group-compat-repair-spec.json",
    "review-group-compat-repair-spec.md",
    "review-group-compat-repair-code.json",
    "review-group-compat-repair-code.md",
    "review-group-compat-repair-result.json",
    "review-group-compat-repair-result.md",
    "group-diagnostic3/repair3.patch",
    "repair3-proposal.md",
    "group-compat-confirmed-diagnosis.json",
    "archive-repair3.py",
]


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def read_stable(source):
    if source.is_symlink() or not source.is_file():
        raise ValueError(f"Expected regular source file: {source}")
    before = source.stat()
    data = source.read_bytes()
    after = source.stat()
    stable_fields = ("st_dev", "st_ino", "st_mode", "st_size", "st_mtime_ns", "st_ctime_ns")
    if any(getattr(before, name) != getattr(after, name) for name in stable_fields) or len(data) != after.st_size:
        raise ValueError(f"Source changed while reading: {source}")
    if PRIVATE_KEY.search(data):
        raise ValueError(f"Private-key header in source: {source}")
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-finished", action="store_true", required=True,
                        help="Confirm the builder and all evidence writers have stopped.")
    parser.parse_args()
    if RUN.is_symlink() or not RUN.is_dir():
        raise ValueError(f"Expected regular repair directory: {RUN}")
    entries = sorted(RUN.rglob("*"))
    if any(path.is_symlink() for path in entries):
        raise ValueError("Repair directory contains a symlink")
    sources = [path for path in entries if path.is_file()]
    sources.extend(AUDIT / name for name in EXTRAS)
    # Preflight all files and name collisions before creating the exclusive target.
    originals = {}
    targets = set()
    for source in sources:
        data = read_stable(source)
        relative = source.relative_to(AUDIT).as_posix()
        compress = len(data) > 65536 and source.suffix in {".log", ".stdout", ".stderr"}
        stored = relative + (".gz" if compress else "")
        if stored in targets or stored == "manifest.json":
            raise ValueError(f"Archive path collision: {stored}")
        targets.add(stored)
        originals[source] = (data, relative, stored, compress)
    results = [path for path in sources if path.is_relative_to(RUN) and path.name == "result.json"]
    if len(results) != 1:
        raise ValueError("Completed repair result.json is required before archiving")
    result = json.loads(originals[results[0]][0])
    if result.get("status") not in {"PASS", "FAIL"} or not result.get("completed_utc"):
        raise ValueError("Repair result must have a final PASS/FAIL status and completion timestamp")
    DEST.mkdir(exist_ok=False)
    manifest = []
    for source, (data, relative, stored, compress) in originals.items():
        encoded = gzip.compress(data, mtime=0) if compress else data
        target = DEST / stored
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as output:
            output.write(encoded)
        copied = target.read_bytes()
        if copied != encoded or (gzip.decompress(copied) if compress else copied) != data:
            raise ValueError(f"Round-trip mismatch: {relative}")
        manifest.append({
            "original": relative, "archived": stored,
            "bytes": len(data), "sha256": sha256(data),
            "compression": "gzip" if compress else "none",
            "stored_bytes": len(copied), "stored_sha256": sha256(copied),
            "round_trip": "PASS",
        })
    for source, (data, *_rest) in originals.items():
        if read_stable(source) != data:
            raise ValueError(f"Source changed during archival: {source}")
    if sorted(RUN.rglob("*")) != entries:
        raise ValueError("Repair directory inventory changed during archival")
    report = {
        "status": "PASS_LOSSLESS_ARCHIVE",
        "kind": "ORDINARY_REPAIR_EVIDENCE_NOT_RELEASE_ACCEPTANCE",
        "historical_product_failure_status": "FAIL; preserved without reclassification",
        "repair_result_status": result["status"],
        "source_root": ".audit/release-0.4.0",
        "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "omissions": [], "files": manifest,
    }
    with (DEST / "manifest.json").open("x") as output:
        output.write(json.dumps(report, indent=2) + "\n")
    print(f"PASS {len(manifest)} files archived losslessly to {DEST}")


if __name__ == "__main__":
    main()
