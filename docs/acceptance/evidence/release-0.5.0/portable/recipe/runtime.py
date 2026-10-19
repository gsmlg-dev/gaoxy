import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import tarfile

IDENTITY = json.loads(Path("/tools/source-identity.json").read_text())
assert IDENTITY["version"] == "0.5.0"
ARTIFACTS = Path("/artifacts")
EVIDENCE = Path("/evidence")
RELEASE = Path("/work/_build/prod/rel/gaoxy")
checks = []


def run(name, command, timeout=60, require_zero=True):
    result = subprocess.run(command, cwd="/work", stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=timeout)
    (EVIDENCE / f"{name}.log").write_text(result.stdout)
    print(result.stdout, end="", flush=True)
    checks.append({"name": name, "command": command, "exit_code": result.returncode})
    (EVIDENCE / "runtime-checks.json").write_text(json.dumps(checks, indent=2) + "\n")
    if require_zero:
        assert result.returncode == 0, f"{name}: exit{result.returncode}"
    return result


info = json.loads((ARTIFACTS / "build-info.json").read_text())
assert info["source_sha"] == IDENTITY["source_sha"]
assert info["source_archive_sha256"] == IDENTITY["source_archive_sha256"]
assert info["root_lock_sha256"] == IDENTITY["root_lock_sha256"]
HELL = {"application": "hell", "version": "0.1.2",
        "source_url": "https://github.com/gsmlg-dev/hell.git",
        "git_sha": "59eed42b019ca41413d1b8cd7a7dc3e344bb93ee",
        "root_lock_sha256": "9f04f56f7b3389e217803614537133cda21a6bc176d2499fdcee6128292f0777"}
assert info["hell_provenance"] == HELL
assert IDENTITY["root_lock_sha256"] == HELL["root_lock_sha256"]
assert len([check for check in info["checks"] if check["name"] == "packaged-hell-startup" and check["exit_code"] == 0]) == 1
assert info["compatibility_tests"] > 0 and info["compatibility_failures"] == 0
scope_bytes = Path("/tools/ordinary-scope.json").read_bytes()
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
archive = ARTIFACTS / "gaoxy-0.5.0-linux-x86_64.tar.gz"
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
entries = [line.split("  ") for line in (ARTIFACTS / "SHA256SUMS").read_text().splitlines()]
assert len(entries) == 2 and {name for _, name in entries} == {archive.name, "build-info.json"}
for expected, name in entries:
    assert hashlib.sha256((ARTIFACTS / name).read_bytes()).hexdigest() == expected, name
assert info["archive_sha256"] == digest
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
RELEASE.mkdir(parents=True)
with tarfile.open(archive) as package:
    # Debian bookworm Python 3.11.2 predates the extraction-filter API.
    # This release contains only regular files/directories: validate the entire
    # inventory before extraction and reject links, devices and escaping paths.
    members = package.getmembers()
    for member in members:
        assert member.isfile() or member.isdir(), member.name
        assert not Path(member.name).is_absolute(), member.name
        assert (RELEASE / member.name).resolve().is_relative_to(RELEASE.resolve()), member.name
        member.uid = member.gid = 0
        member.uname = member.gname = ""
        member.mode &= 0o755
    package.extractall(RELEASE, members=members)
assert platform.machine() == "x86_64", platform.machine()
assert (RELEASE / "releases/start_erl.data").read_text().split()[1] == "0.5.0"
elf_rows = []
for path in sorted(RELEASE.rglob("*")):
    if not path.is_file():
        continue
    with path.open("rb") as file:
        if file.read(4) != b"\x7fELF":
            continue
    dynamic = subprocess.run(["readelf", "-l", "-d", str(path)], capture_output=True, text=True, timeout=10)
    assert dynamic.returncode == 0, (str(path), dynamic.stderr)
    assert "/nix/store" not in dynamic.stdout + dynamic.stderr, str(path)
    linked = subprocess.run(["ldd", str(path)], capture_output=True, text=True, timeout=10)
    output = linked.stdout + linked.stderr
    assert "not found" not in output and "/nix/store" not in output, (str(path), output)
    assert linked.returncode == 0 or "not a dynamic executable" in output or "statically linked" in output, (str(path), output)
    elf_rows.append({"path": str(path.relative_to(RELEASE)), "readelf": dynamic.stdout, "ldd": output})
assert elf_rows, "zero ELF objects inspected"
(EVIDENCE / "elf-dependencies.json").write_text(json.dumps(elf_rows, indent=2) + "\n")
run("runtime-system", ["bash", "-ec", "cat /etc/os-release; uname -m; ldd --version; python3 --version; openssl version; dpkg-query -W"])
run("packaged-hell-startup", [str(RELEASE / "bin/gaoxy"), "eval", '''
{:ok, _} = Application.ensure_all_started(:gaoxy)
true = Enum.any?(Application.started_applications(), fn {app, _, version} ->
  app == :hell and to_string(version) == "0.1.2"
end)
true = :hell in Application.spec(:gaoxy, :applications)
false = :thousand_island in Application.spec(:gaoxy, :applications)
nil = Application.spec(:thousand_island)
:non_existing = :code.where_is_file(~c"thousand_island.app")
IO.puts("PASS packaged Hell 0.1.2 startup; Thousand Island absent")
'''])
run("packaged-core-smoke", ["python3", "scripts/release-smoke.py"])
run("packaged-gateway-smoke", ["/work/.audit/h2peer/bin/python", "scripts/gateway-release-smoke.py", "--release", str(RELEASE / "bin/gaoxy")])
run("packaged-h3-smoke", ["/work/.audit/h2peer/bin/python", "scripts/h3-release-smoke.py", "--release", str(RELEASE / "bin/gaoxy"), "--evidence", str(EVIDENCE / "h3")], timeout=100)
h3 = json.loads((EVIDENCE / "h3/result.json").read_text())
assert h3["status"] == "PASS" and len(h3["checks"]) == 3 and h3["ports_rebound"]
websocket_profiles = []
for protocol in ("h2", "h2c", "h3"):
    evidence = EVIDENCE / f"websocket-{protocol}"
    run(f"packaged-websocket-{protocol}", ["/work/.audit/m5peer/bin/python", "integration/websocket_multiplexed/run.py",
        "--protocol", protocol, "--release", str(RELEASE / "bin/gaoxy"),
        "--source-identity", "/tools/source-identity.json", "--evidence", str(evidence)], timeout=100)
    reports = list(evidence.glob("run-*/report.json"))
    assert len(reports) == 1, reports
    report = json.loads(reports[0].read_text())
    assert report["status"] == "PASS" and report["exit"] == 0 and report["executed"] == 15 and not report["not_run"], report
    assert report["protocol"] == protocol and report["source"]["identity"] == IDENTITY, report
    websocket_profiles.append({"protocol": protocol, "executed": report["executed"], "failures": 0,
                               "status": report["status"], "report": str(reports[0].relative_to(EVIDENCE)),
                               "report_sha256": hashlib.sha256(reports[0].read_bytes()).hexdigest()})
result = {"status": "PASS", "source_sha": info["source_sha"], "archive_sha256": digest,
          "hell_provenance": HELL,
          "platform": "linux/amd64", "network": "none", "core_transports": 3, "gateway_exchanges": 2, "h3_checks": 3,
          "elf_objects_checked": len(elf_rows), "missing_libraries": 0, "nix_elf_dependencies": 0,
          "packaged_websocket_profiles": websocket_profiles,
          "completed_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "checks": checks}
(EVIDENCE / "runtime-result.json").write_text(json.dumps(result, indent=2) + "\n")
print(f"PASS packaged fresh Debian bookworm runtime:core3; gateway2; H3checks3; ELF{len(elf_rows)}; no missing/nix libraries; networknone", flush=True)
