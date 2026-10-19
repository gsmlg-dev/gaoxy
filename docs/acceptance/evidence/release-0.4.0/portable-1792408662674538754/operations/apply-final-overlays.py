"""Apply externally reviewed final overlays while preserving all historical bytes."""
import argparse
import hashlib
import json
from pathlib import Path


AUDIT = Path(__file__).resolve().parent
ROOT = AUDIT.parents[1]
INVENTORY = AUDIT / "closeout-overlay-inventory.json"
INVENTORY_SHA256 = "34379ee5ade6c5ba6d2f797c500d0184a169a04b7bfb0f1b91531729ac94ff53"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, detail):
    if not condition:
        raise ValueError(detail)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--replacements", required=True, type=Path,
                        help="External final JSON object: ten path-to-overlay strings.")
    parser.add_argument("--apply", action="store_true", required=True,
                        help="Explicitly write only the ten inventoried overlay spans.")
    args = parser.parse_args()
    inventory_bytes = INVENTORY.read_bytes()
    require(digest(inventory_bytes) == INVENTORY_SHA256, "Inventory identity changed")
    inventory = json.loads(inventory_bytes)
    replacement_bytes = args.replacements.read_bytes()
    replacements = json.loads(replacement_bytes)
    rows = inventory["files"]
    names = {row["path"] for row in rows}
    require(len(rows) == len(names) == 10, "Expected exactly ten inventoried files")
    require(isinstance(replacements, dict) and set(replacements) == names,
            "Replacement paths must exactly match the ten inventoried files")
    prepared = []
    for row in rows:
        path = ROOT / row["path"]
        require(not path.is_symlink() and path.is_file(), f"Not a regular file: {path}")
        original = path.read_bytes()
        start, end = row["overlay_start_byte"], row["overlay_end_byte_exclusive"]
        prefix, overlay, tail = original[:start], original[start:end], original[end:]
        for data, key in ((original, "file"), (prefix, "immutable_prefix"),
                          (overlay, "overlay"), (tail, "immutable_tail")):
            require(digest(data) == row[key + "_sha256"], f"Stale {key}: {path}")
        replacement = replacements[row["path"]]
        require(isinstance(replacement, str), f"Replacement is not text: {path}")
        require(replacement.startswith("## v0.4.0 release status — 2026-10-19\n\n")
                and replacement.endswith("\n\n"), f"Invalid overlay boundary: {path}")
        require(replacement.count("\n## ") == 0 and replacement.count("\n# ") == 0,
                f"Replacement includes another document heading: {path}")
        result = prefix + replacement.encode("utf-8") + tail
        prepared.append((row, path, original, result, prefix, tail))
    # Preflight the entire batch before writing any tracked file.
    for row, path, original, result, prefix, tail in prepared:
        require(path.read_bytes() == original, f"Source changed after preflight: {path}")
        path.write_bytes(result)
        copied = path.read_bytes()
        require(copied == result and copied[:len(prefix)] == prefix
                and copied[len(copied) - len(tail):] == tail,
                f"Write or preserved-history verification failed: {path}")
    print(json.dumps({
        "status": "PASS_OVERLAYS_APPLIED_HISTORY_PRESERVED",
        "replacements_sha256": digest(replacement_bytes),
        "files": [{"path": row["path"], "original_sha256": digest(original),
                   "final_sha256": digest(result),
                   "immutable_prefix_sha256": digest(prefix),
                   "immutable_tail_sha256": digest(tail)}
                  for row, _path, original, result, prefix, tail in prepared],
    }, indent=2))


if __name__ == "__main__":
    main()
