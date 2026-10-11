import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile

SOURCE = "32ec599790ccddb477345a765681f74852e5ffc0"
ROOT = Path("/work")
OUTPUT = Path("/output")
EVIDENCE = OUTPUT / "evidence"
EVIDENCE.mkdir(parents=True)
checks = []


def run(name, command, env=None, timeout=600):
    environment = dict(os.environ, **(env or {}))
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    result = subprocess.run(command, cwd=ROOT, env=environment, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=timeout)
    print(result.stdout, end="", flush=True)
    path = EVIDENCE / f"{name}.log"
    path.write_text(result.stdout)
    checks.append({"name": name, "command": command, "environment": env or {},
                   "started_utc": started, "exit_code": result.returncode,
                   "log_sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    (EVIDENCE / "checks.json").write_text(json.dumps(checks, indent=2) + "\n")
    assert result.returncode == 0, f"{name}: exit {result.returncode}"
    return result.stdout


with tarfile.open("/tools/source.tar") as archive:
    original = {member.name: hashlib.sha256(archive.extractfile(member).read()).hexdigest()
                for member in archive.getmembers() if member.isfile()}

versions = run("toolchain", ["bash", "-ec", "elixir --version; erl -noshell -eval 'io:format(\"OTP_RELEASE=~s OTP_VERSION=~s~n\", [erlang:system_info(otp_release), element(2, file:read_file(filename:join([code:root_dir(), \"releases\", erlang:system_info(otp_release), \"OTP_VERSION\"])))]), halt().'; rustc --version; cargo --version; python3 --version; openssl version; ldd --version; dpkg-query -W"])
assert "Elixir 1.18.5" in versions
assert "OTP_VERSION=28.5.0.5\n" in versions
run("hex", ["mix", "local.hex", "--force"])
run("rebar", ["mix", "local.rebar", "--force"])
run("test-dependencies", ["mix", "deps.get", "--check-locked"], {"MIX_ENV": "test"})
run("peer-venv", ["python3", "-m", "venv", "/work/.audit/h2peer"])
run("peer-dependencies", ["/work/.audit/h2peer/bin/python", "-m", "pip", "install", "-r", "apps/gaoxy_http/test/support/h2-requirements.txt"])
run("canonical-format", ["mix", "format", "--check-formatted"])
run("strict-compile", ["mix", "compile", "--warnings-as-errors"], {"MIX_ENV": "prod"})
tests = run("compatibility", ["python3", "scripts/check-tests.py", "--max-cases", "1",
            "apps/gaoxy/test", "apps/gaoxy_http/test", "apps/gaoxy_proxy/test", "apps/gaoxy_server/test"],
            {"MIX_ENV": "test", "HTTP_FETCH_PEER_PYTHON": "/work/.audit/h2peer/bin/python", "PYTHONDONTWRITEBYTECODE": "1"}, timeout=300)
counts = [(int(total), int(failed), suffix) for total, failed, suffix in
          re.findall(r"(\d+) tests?, (\d+) failures?([^\n]*)", tests)]
assert sum(total for total, _, _ in counts) == 486, counts
assert all(failed == 0 and not re.search(r"[1-9]\d* (?:excluded|skipped)", suffix)
           for _, failed, suffix in counts), counts
run("release", ["mix", "release", "gaoxy"], {"MIX_ENV": "prod"})
run("core-smoke", ["python3", "scripts/release-smoke.py"], timeout=60)
run("gateway-smoke", ["/work/.audit/h2peer/bin/python", "scripts/gateway-release-smoke.py"], timeout=60)
changed = [name for name, digest in original.items()
           if not (ROOT / name).is_file() or hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest]
assert not changed, f"source changed during build: {changed}"
archive = OUTPUT / "gaoxy-0.2.0-linux-x86_64.tar.gz"
run("package", ["tar", "-C", "_build/prod/rel/gaoxy", "-czf", str(archive), "."])
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(OUTPUT / "SHA256SUMS").write_text(f"{digest}  {archive.name}\n")
info = {"version": "0.2.0", "source_sha": SOURCE,
        "source_archive_sha256": hashlib.sha256(Path("/tools/source.tar").read_bytes()).hexdigest(),
        "source_files_checked_unchanged": len(original), "platform": "linux/amd64",
        "support": "Debian bookworm glibc x86_64; broader platforms unqualified",
        "builder": "hexpm/elixir@sha256:abbfaf9699b7a3650810c92268023806217486c26b4da3dc0492a778b22a09bb",
        "rust_image": "rust@sha256:0e2bcaef56d041a486784e54104a81aebe0da44bd03019bd70bc0401e42e4a97",
        "elixir_source_sha": "dfe6612e546cec6557900e67651f7d21805472ef",
        "runtime_base": "debian@sha256:a4672c0cb26fbdde88e38fa2dfb6c681942306680e41e4378b28770b6e79ee91",
        "toolchain_and_packages": versions, "compatibility_tests": 486, "compatibility_failures": 0,
        "core_transports": 3, "gateway_exchanges": 2, "archive_sha256": digest,
        "built_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "checks": checks}
(OUTPUT / "build-info.json").write_text(json.dumps(info, indent=2) + "\n")
print(f"PASS clean portable build:486 tests/0 failures; core3; gateway2; SHA256={digest}", flush=True)
