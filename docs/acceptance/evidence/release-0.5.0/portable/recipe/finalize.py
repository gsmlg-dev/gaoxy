"""Finalize checksums after clean artifact export, without modifying release bytes."""
import hashlib
import json
from pathlib import Path
import sys
import re
import tarfile

IDENTITY = json.loads(Path(__file__).with_name("source-identity.json").read_text())
assert IDENTITY["version"] == "0.5.0"
directory = Path(sys.argv[1]).resolve()
info = json.loads((directory / "build-info.json").read_text())
assert info["source_sha"] == IDENTITY["source_sha"]
assert info["compatibility_tests"] > 0 and info["compatibility_failures"] == 0
assert all(check["exit_code"] == 0 for check in info["checks"])
assert info["source_archive_sha256"] == IDENTITY["source_archive_sha256"]
assert info["root_lock_sha256"] == IDENTITY["root_lock_sha256"]
HELL = {"application": "hell", "version": "0.1.2",
        "source_url": "https://github.com/gsmlg-dev/hell.git",
        "git_sha": "59eed42b019ca41413d1b8cd7a7dc3e344bb93ee",
        "root_lock_sha256": "9f04f56f7b3389e217803614537133cda21a6bc176d2499fdcee6128292f0777"}
assert info["hell_provenance"] == HELL
assert IDENTITY["root_lock_sha256"] == HELL["root_lock_sha256"]
source_archive = Path(__file__).with_name("source.tar")
assert hashlib.sha256(source_archive.read_bytes()).hexdigest() == IDENTITY["source_archive_sha256"]
with tarfile.open(source_archive) as source:
    lock_bytes = source.extractfile("mix.lock").read()
assert hashlib.sha256(lock_bytes).hexdigest() == HELL["root_lock_sha256"]
lock = lock_bytes.decode()
hell_lock = re.search(r'^\s*"hell": \{:git, "([^"]+)", "([0-9a-f]{40})", \[ref: "([0-9a-f]{40})"\]\},?$', lock, re.MULTILINE)
assert hell_lock and hell_lock.groups() == (HELL["source_url"], HELL["git_sha"], HELL["git_sha"])
assert not re.search(r'^\s*"thousand_island":', lock, re.MULTILINE)
assert len([check for check in info["checks"] if check["name"] == "packaged-hell-startup"]) == 1
assert info["h3_checks"] == 3
scope_bytes = Path(__file__).with_name("ordinary-scope.json").read_bytes()
scope = json.loads(scope_bytes)
assert scope["version"] == info["version"] == IDENTITY["version"]
assert info["ordinary_scope_sha256"] == hashlib.sha256(scope_bytes).hexdigest()
assert len(info["ordinary_suites"]) == len(scope["batches"])
for actual, expected in zip(info["ordinary_suites"], scope["batches"]):
    assert actual == {"name": expected["name"], "command": expected["command"],
                      "applications": expected["applications"], "status": "PASS"}, actual
assert info["compatibility_tests"] == sum(row["executed"] for suite in info["ordinary_suites"]
                                         for row in suite["applications"].values())
assert [row["protocol"] for row in info["packaged_websocket_profiles"]] == ["h2", "h2c", "h3"]
for row in info["packaged_websocket_profiles"]:
    assert row["status"] == "PASS" and row["executed"] == 15 and row["failures"] == 0, row
    report = directory / row["report"]
    assert report.resolve().is_relative_to(directory), str(report)
    assert hashlib.sha256(report.read_bytes()).hexdigest() == row["report_sha256"], row
archive = directory / "gaoxy-0.5.0-linux-x86_64.tar.gz"
applications = {name: "0.5.0" for name in ("gaoxy", "gaoxy_http", "gaoxy_http3", "gaoxy_proxy", "gaoxy_server")}
with tarfile.open(archive) as package:
    inventory = package.getmembers()
    for name, version in applications.items():
        members = [m for m in inventory if m.name.endswith(f"/ebin/{name}.app")]
        assert len(members) == 1 and members[0].isfile(), (name, members)
        content = package.extractfile(members[0]).read().decode()
        assert re.search(r'\{vsn,\s*"' + re.escape(version) + r'"\}', content), (name, content)
    hell_members = [m for m in inventory if m.name.endswith("/ebin/hell.app")]
    assert len(hell_members) == 1 and hell_members[0].isfile(), hell_members
    hell_content = package.extractfile(hell_members[0]).read().decode()
    assert re.search(r'\{vsn,\s*"0\.1\.2"\}', hell_content), hell_content
    assert not any(m.name.endswith("/ebin/thousand_island.app") for m in inventory)
    gaoxy_member = next(m for m in inventory if m.name.endswith("/ebin/gaoxy.app"))
    gaoxy_content = package.extractfile(gaoxy_member).read().decode()
    dependencies = re.search(r'\{applications,\s*\[([^\]]*)\]\}', gaoxy_content)
    assert dependencies, gaoxy_content
    dependency_names = re.findall(r'[a-z][a-z0-9_]*', dependencies[1])
    assert "hell" in dependency_names and "thousand_island" not in dependency_names, dependency_names
    assert all(member.isfile() or member.isdir() for member in inventory), "invalid archive entry type"

assert info["applications"] == applications and info["archive_entries"] == len(inventory)
names = [archive.name, "build-info.json"]
digests = {name: hashlib.sha256((directory / name).read_bytes()).hexdigest() for name in names}
assert info["archive_sha256"] == digests[names[0]]
(directory / "SHA256SUMS").write_text("".join(f"{digests[name]}  {name}\n" for name in names))
print(json.dumps(digests, indent=2))
