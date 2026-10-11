"""Finalize checksums after clean artifact export, without modifying release bytes."""
import hashlib
import json
from pathlib import Path
import sys

directory = Path(sys.argv[1]).resolve()
info = json.loads((directory / "build-info.json").read_text())
assert info["source_sha"] == "32ec599790ccddb477345a765681f74852e5ffc0"
assert info["compatibility_tests"] == 486 and info["compatibility_failures"] == 0
assert all(check["exit_code"] == 0 for check in info["checks"])
names = ["gaoxy-0.2.0-linux-x86_64.tar.gz", "build-info.json"]
digests = {name: hashlib.sha256((directory / name).read_bytes()).hexdigest() for name in names}
assert info["archive_sha256"] == digests[names[0]]
(directory / "SHA256SUMS").write_text("".join(f"{digests[name]}  {name}\n" for name in names))
print(json.dumps(digests, indent=2))
