"""Check executed portable qualification and prepare exact release notes."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

SOURCE = "32ec599790ccddb477345a765681f74852e5ffc0"
root = Path(sys.argv[1]).resolve()
portable = root / ".audit/release-0.2.0-portable"
artifacts = portable / "artifacts"
runtime = portable / "evidence/fresh-runtime"
output = root / ".audit/release-0.2.0-publication"
info = json.loads((artifacts / "build-info.json").read_text())
assert info["source_sha"] == SOURCE and info["version"] == "0.2.0"
assert info["compatibility_tests"] == 486 and info["compatibility_failures"] == 0
assert info["source_files_checked_unchanged"] == 2396
source = subprocess.check_output(["git", "archive", SOURCE], cwd=root, timeout=30)
assert hashlib.sha256(source).hexdigest() == info["source_archive_sha256"]
assert source == (portable / "context/source.tar").read_bytes()
checks = {check["name"]: check for check in info["checks"]}
expected_checks = {"toolchain", "hex", "rebar", "test-dependencies", "peer-venv", "peer-dependencies", "canonical-format", "strict-compile", "compatibility", "release", "core-smoke", "gateway-smoke", "package"}
assert checks.keys() == expected_checks and len(info["checks"]) == len(expected_checks)
for check in info["checks"]:
    assert check["exit_code"] == 0, check
    log = artifacts / "evidence" / (check["name"] + ".log")
    assert hashlib.sha256(log.read_bytes()).hexdigest() == check["log_sha256"], check["name"]
entries = [line.split("  ") for line in (artifacts / "SHA256SUMS").read_text().splitlines()]
assert len(entries) == 2 and {name for _, name in entries} == {"gaoxy-0.2.0-linux-x86_64.tar.gz", "build-info.json"}
for expected, name in entries:
    assert hashlib.sha256((artifacts / name).read_bytes()).hexdigest() == expected, name
archive_digest = hashlib.sha256((artifacts / "gaoxy-0.2.0-linux-x86_64.tar.gz").read_bytes()).hexdigest()
assert info["archive_sha256"] == archive_digest
result = json.loads((runtime / "runtime-result.json").read_text())
launch = json.loads((runtime / "launch.json").read_text())
stages = json.loads((portable / "evidence/runtime-qualification-stages.json").read_text())
assert result["status"] == launch["status"] == stages["status"] == "PASS"
assert result["source_sha"] == SOURCE and result["archive_sha256"] == archive_digest
assert result["core_transports"] == info["core_transports"] == 3
assert result["gateway_exchanges"] == info["gateway_exchanges"] == 2
assert result["missing_libraries"] == result["nix_elf_dependencies"] == 0
assert result["elf_objects_checked"] > 0
assert launch["container_exit_code"] == 0 and launch["owned_container_removed"]
for name in ["container-inspect-live.json", "container-inspect-final.json"]:
    inspection = json.loads((runtime / name).read_text())
    assert inspection["Id"] == launch["container_id"]
    assert inspection["Image"] == launch["image_id"]
    assert inspection["HostConfig"]["NetworkMode"] == "none"
    if name.endswith("final.json"):
        assert not inspection["State"]["Running"] and inspection["State"]["ExitCode"] == 0
assert all(check["exit_code"] == 0 for check in result["checks"])
notes = (root / "docs/releases/0.2.0.md").read_text()
notes += "\nPublished artifact: `gaoxy-0.2.0-linux-x86_64.tar.gz`, qualified on Debian bookworm / glibc Linux x86_64. Other operating systems, architectures and libc profiles are unqualified. Required runtime libraries: libssl3, libstdc++6, libncurses6, libtinfo6 and zlib1g.\n"
notes += f"\nSource: `{SOURCE}`. Builder: Elixir 1.18.5 / OTP 28.5.0.5, with pinned Debian and Rust images recorded in `build-info.json`. Archive SHA256: `{archive_digest}`. `SHA256SUMS` covers the archive and build metadata.\n"
notes += f"\nValidation: canonical format and strict compilation; 486 compatibility tests, zero failures; real TCP/TLS/UDP and native H1/H2 proxy traffic, finite shutdown and rebind. The exported archive passed the same runtime smoke in a fresh container with network disabled; {result['elf_objects_checked']} ELF objects had no missing or Nix store library dependencies. Independent specification, code and evidence review passed before publication.\n"
notes += "\nQualification used an isolated local build. The hosted workflow executed no steps and remains BLOCKED_ENV; hosted success is not claimed. Original failures and bounded recovery results are preserved in the release acceptance evidence. M4 HTTP/3 design and plan are prepared and independently reviewed; implementation and runtime acceptance are NOT RUN.\n"
(output / "release-notes.md").write_text(notes)
(output / "pre-publication.json").write_text(json.dumps({"status": "PASS", "source_sha": SOURCE, "archive_sha256": archive_digest, "compatibility_tests": 486, "runtime_image_id": launch["image_id"], "elf_objects_checked": result["elf_objects_checked"]}, indent=2) + "\n")
print((output / "pre-publication.json").read_text())
