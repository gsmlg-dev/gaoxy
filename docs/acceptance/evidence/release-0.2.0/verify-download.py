"""Verify freshly downloaded v0.2.0 assets against the qualified artifacts."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tarfile

SOURCE = "32ec599790ccddb477345a765681f74852e5ffc0"
download, qualified, receipt = map(Path, sys.argv[1:])
names = {"gaoxy-0.2.0-linux-x86_64.tar.gz", "build-info.json", "SHA256SUMS"}
assert {path.name for path in download.iterdir()} == names
assert (download / "SHA256SUMS").read_bytes() == (qualified / "SHA256SUMS").read_bytes()
entries = [line.split("  ") for line in (download / "SHA256SUMS").read_text().splitlines()]
assert len(entries) == 2 and {name for _, name in entries} == names - {"SHA256SUMS"}
assets = {}
for name in sorted(names):
    digest = hashlib.sha256((download / name).read_bytes()).hexdigest()
    assert digest == hashlib.sha256((qualified / name).read_bytes()).hexdigest(), name
    assets[name] = {"sha256": digest, "bytes": (download / name).stat().st_size}
for expected, name in entries:
    assert assets[name]["sha256"] == expected, name
info = json.loads((download / "build-info.json").read_text())
assert info["version"] == "0.2.0" and info["source_sha"] == SOURCE
assert info["compatibility_tests"] == 486 and info["compatibility_failures"] == 0
assert info["checks"] and all(check["exit_code"] == 0 for check in info["checks"])
assert info["archive_sha256"] == assets["gaoxy-0.2.0-linux-x86_64.tar.gz"]["sha256"]
with tarfile.open(download / "gaoxy-0.2.0-linux-x86_64.tar.gz") as archive:
    members = archive.getmembers()
    inventory = {member.name.removeprefix("./") for member in members}
    assert "bin/gaoxy" in inventory
    for app in ["gaoxy", "gaoxy_http", "gaoxy_proxy", "gaoxy_server"]:
        assert f"lib/{app}-0.2.0/ebin/{app}.app" in inventory, app
    start = next(member for member in members if member.name.removeprefix("./") == "releases/start_erl.data")
    erts, version = archive.extractfile(start).read().decode().split()
    assert version == "0.2.0" and f"erts-{erts}/bin/beam.smp" in inventory

def command(args):
    result = subprocess.run(args, env=dict(os.environ, GODEBUG="http2client=0"),
                            capture_output=True, text=True, timeout=60)
    assert result.returncode == 0, (args, result.stdout, result.stderr)
    return result.stdout

remote_tag = command(["git", "ls-remote", "--tags", "origin", "v0.2.0", "v0.2.0^{}"])
assert f"{SOURCE}\trefs/tags/v0.2.0" in remote_tag.splitlines(), remote_tag
versions = {}
for path in ["mix.exs", "apps/gaoxy/mix.exs", "apps/gaoxy_http/mix.exs", "apps/gaoxy_proxy/mix.exs", "apps/gaoxy_server/mix.exs"]:
    selected = re.findall(r'\bversion:\s*"([^"]+)"', command(["git", "show", f"v0.2.0:{path}"]))
    assert selected == ["0.2.0"], (path, selected)
    versions[path] = selected[0]
release = json.loads(command(["gh", "release", "view", "v0.2.0", "--repo", "gsmlg-opt/gaoxy",
                              "--json", "tagName,url,assets,targetCommitish,isDraft,isPrerelease,publishedAt"]))
assert release["tagName"] == "v0.2.0" and not release["isDraft"]
assert {asset["name"] for asset in release["assets"]} == names
for asset in release["assets"]:
    assert asset["size"] == assets[asset["name"]]["bytes"], asset["name"]
result = {"status": "PASS", "verified_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
          "source_sha": SOURCE, "remote_tag": remote_tag.splitlines(), "tagged_versions": versions,
          "release": release, "downloaded_assets": assets, "archive_entries": len(members), "erts": erts,
          "qualification": "Debian bookworm/glibc Linux x86_64; local isolated build and offline runtime",
          "hosted_execution": "BLOCKED_ENV; no steps executed", "deployment": "NOT RUN",
          "release_artifact_e2e": "NOT RUN; disabled"}
receipt.write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
