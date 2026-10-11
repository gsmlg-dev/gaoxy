import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import tarfile

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
assert info["source_sha"] == "32ec599790ccddb477345a765681f74852e5ffc0"
archive = ARTIFACTS / "gaoxy-0.2.0-linux-x86_64.tar.gz"
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
entries = [line.split("  ") for line in (ARTIFACTS / "SHA256SUMS").read_text().splitlines()]
assert len(entries) == 2 and {name for _, name in entries} == {archive.name, "build-info.json"}
for expected, name in entries:
    assert hashlib.sha256((ARTIFACTS / name).read_bytes()).hexdigest() == expected, name
assert info["archive_sha256"] == digest
RELEASE.mkdir(parents=True)
with tarfile.open(archive) as package:
    package.extractall(RELEASE, filter="data")
assert platform.machine() == "x86_64", platform.machine()
assert (RELEASE / "releases/start_erl.data").read_text().split()[1] == "0.2.0"
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
run("packaged-core-smoke", ["python3", "scripts/release-smoke.py"])
run("packaged-gateway-smoke", ["/work/.audit/h2peer/bin/python", "scripts/gateway-release-smoke.py", "--release", str(RELEASE / "bin/gaoxy")])
result = {"status": "PASS", "source_sha": info["source_sha"], "archive_sha256": digest,
          "platform": "linux/amd64", "network": "none", "core_transports": 3, "gateway_exchanges": 2,
          "elf_objects_checked": len(elf_rows), "missing_libraries": 0, "nix_elf_dependencies": 0,
          "completed_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "checks": checks}
(EVIDENCE / "runtime-result.json").write_text(json.dumps(result, indent=2) + "\n")
print(f"PASS packaged fresh Debian bookworm runtime:core3; gateway2; ELF{len(elf_rows)}; no missing/nix libraries; networknone", flush=True)
