"""Finalize checksums after clean artifact export, without modifying release bytes."""
import hashlib
import json
from pathlib import Path
import sys
import re
import tarfile

IDENTITY = json.loads(Path(__file__).with_name("source-identity.json").read_text())
directory = Path(sys.argv[1]).resolve()
info = json.loads((directory / "build-info.json").read_text())
assert info["source_sha"] == IDENTITY["source_sha"]
assert info["compatibility_tests"] > 0 and info["compatibility_failures"] == 0
assert all(check["exit_code"] == 0 for check in info["checks"])
assert info["source_archive_sha256"] == IDENTITY["source_archive_sha256"]
assert info["root_lock_sha256"] == IDENTITY["root_lock_sha256"]
assert info["h3_checks"] == 3
archive = directory / "gaoxy-0.3.0-linux-x86_64.tar.gz"
applications = {name: "0.3.0" for name in ("gaoxy", "gaoxy_http", "gaoxy_http3", "gaoxy_proxy", "gaoxy_server")}
with tarfile.open(archive) as package:
    inventory = package.getmembers()
    for name, version in applications.items():
        members = [m for m in inventory if m.name.endswith(f"/ebin/{name}.app")]
        assert len(members) == 1 and members[0].isfile(), (name, members)
        content = package.extractfile(members[0]).read().decode()
        assert re.search(r'\{vsn,\s*"' + re.escape(version) + r'"\}', content), (name, content)
    assert all(member.isfile() or member.isdir() for member in inventory), "invalid archive entry type"

assert info["applications"] == applications and info["archive_entries"] == len(inventory)
names = [archive.name, "build-info.json"]
digests = {name: hashlib.sha256((directory / name).read_bytes()).hexdigest() for name in names}
assert info["archive_sha256"] == digests[names[0]]
(directory / "SHA256SUMS").write_text("".join(f"{digests[name]}  {name}\n" for name in names))
print(json.dumps(digests, indent=2))
