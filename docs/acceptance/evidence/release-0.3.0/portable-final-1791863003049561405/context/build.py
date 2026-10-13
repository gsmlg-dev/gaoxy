import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile
import sys
import time

IDENTITY = json.loads(Path("/tools/source-identity.json").read_text())
SOURCE = IDENTITY["source_sha"]
assert re.fullmatch(r"[0-9a-f]{40}", SOURCE)
source_git = subprocess.run(["git", "get-tar-commit-id"], input=Path("/tools/source.tar").read_bytes(), capture_output=True, timeout=10)
assert source_git.returncode == 0 and source_git.stdout.decode().strip() == SOURCE, "source archive Git identity mismatch"
assert hashlib.sha256(Path("/tools/source.tar").read_bytes()).hexdigest() == IDENTITY["source_archive_sha256"]
assert hashlib.sha256(Path("/work/mix.lock").read_bytes()).hexdigest() == IDENTITY["root_lock_sha256"]
ROOT = Path("/work")
OUTPUT = Path("/output")
EVIDENCE = OUTPUT / "evidence"
EVIDENCE.mkdir(parents=True, exist_ok=True)
phase = sys.argv[1]
assert phase in {"prepare", "compile", "qualify"}, phase
receipt = EVIDENCE / "checks.json"
checks = json.loads(receipt.read_text()) if receipt.exists() else []


def run(name, command, env=None, timeout=600):
    environment = dict(os.environ, **(env or {}))
    tick = time.monotonic()
    print(f"START {name}: {command}", flush=True)
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    result = subprocess.run(command, cwd=ROOT, env=environment, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=timeout)
    print(result.stdout, end="", flush=True)
    path = EVIDENCE / f"{name}.log"
    path.write_text(result.stdout)
    checks.append({"name": name, "command": command, "environment": env or {},
                   "started_utc": started, "completed_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                   "elapsed_seconds": time.monotonic() - tick, "timeout_seconds": timeout,
                   "exit_code": result.returncode,
                   "log_sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    (EVIDENCE / "checks.json").write_text(json.dumps(checks, indent=2) + "\n")
    assert result.returncode == 0, f"{name}: exit {result.returncode}"
    return result.stdout


with tarfile.open("/tools/source.tar") as archive:
    original = {member.name: hashlib.sha256(archive.extractfile(member).read()).hexdigest()
                for member in archive.getmembers() if member.isfile()}

if phase == "prepare":
    versions = run("toolchain", ["bash", "-ec", "elixir --version; erl -noshell -eval 'io:format(\"OTP_RELEASE=~s OTP_VERSION=~s~n\", [erlang:system_info(otp_release), element(2, file:read_file(filename:join([code:root_dir(), \"releases\", erlang:system_info(otp_release), \"OTP_VERSION\"])))]), halt().'; rustc --version; cargo --version; python3 --version; openssl version; ldd --version; dpkg-query -W"])
    assert "Elixir 1.18.5" in versions
    assert "OTP_VERSION=28.5.0.5\n" in versions
    run("hex", ["mix", "local.hex", "--force"])
    run("rebar", ["mix", "local.rebar", "--force"])
    run("test-dependencies", ["mix", "deps.get", "--check-locked"], {"MIX_ENV": "test"})
    run("peer-venv", ["python3", "-m", "venv", "/work/.audit/h2peer"])
    run("peer-dependencies", ["/work/.audit/h2peer/bin/python", "-m", "pip", "install", "-r", "apps/gaoxy_http/test/support/h2-requirements.txt", "-r", "integration/http3/requirements.txt"])

elif phase == "compile":
    run("canonical-format", ["mix", "format", "--check-formatted"])
    changed_elixir = IDENTITY["changed_elixir_paths"]
    assert changed_elixir and len(set(changed_elixir)) == len(changed_elixir)
    assert all(name in original and name.endswith((".ex", ".exs")) for name in changed_elixir)
    run("changed-source-format", ["mix", "format", "--check-formatted", *changed_elixir])
    run("strict-compile", ["mix", "compile", "--warnings-as-errors"], {"MIX_ENV": "prod"})

else:
    versions = (EVIDENCE / "toolchain.log").read_text()
    tests = run("compatibility", ["python3", "scripts/check-tests.py", "--max-cases", "1",
                "apps/gaoxy/test", "apps/gaoxy_http/test", "apps/gaoxy_http3/test", "apps/gaoxy_proxy/test", "apps/gaoxy_server/test"],
                {"MIX_ENV": "test", "HTTP_FETCH_PEER_PYTHON": "/work/.audit/h2peer/bin/python", "GAOXY_QUIC_PYTHON": "/work/.audit/h2peer/bin/python", "PYTHONDONTWRITEBYTECODE": "1"}, timeout=300)
    counts = [(int(total), int(failed), suffix) for total, failed, suffix in
              re.findall(r"(\d+) tests?, (\d+) failures?([^\n]*)", tests)]
    application_names = {"gaoxy", "gaoxy_http", "gaoxy_http3", "gaoxy_proxy", "gaoxy_server"}
    app_counts = {}
    plain_tests = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", tests)
    for section in re.finditer(r"(?ms)^==> ([a-z0-9_]+)\n(.*?)(?=^==>|\Z)", plain_tests):
        name, output = section.groups()
        summaries = re.findall(r"(\d+) tests?, (\d+) failures?([^\n]*)", output)
        if name in application_names and summaries:
            assert name not in app_counts and len(summaries) == 1, (name, summaries)
            total, failed, suffix = summaries[0]
            skipped = sum(int(n) for n in re.findall(r"(\d+) (?:excluded|skipped)", suffix))
            app_counts[name] = {"tests": int(total), "failures": int(failed), "excluded_or_skipped": skipped}
    assert set(app_counts) == application_names, app_counts
    assert all(row["tests"] > 0 and row["failures"] == row["excluded_or_skipped"] == 0 for row in app_counts.values()), app_counts
    executed = sum(row["tests"] for row in app_counts.values())
    assert executed == sum(total for total, _, _ in counts), (app_counts, counts)
    assert all(failed == 0 and not re.search(r"[1-9]\d* (?:excluded|skipped)", suffix)
               for _, failed, suffix in counts), counts
    run("release", ["mix", "release", "gaoxy"], {"MIX_ENV": "prod"})
    run("core-smoke", ["python3", "scripts/release-smoke.py"], timeout=60)
    run("gateway-smoke", ["/work/.audit/h2peer/bin/python", "scripts/gateway-release-smoke.py"], timeout=60)
    run("h3-smoke", ["/work/.audit/h2peer/bin/python", "scripts/h3-release-smoke.py", "--evidence", str(EVIDENCE / "h3")], timeout=100)
    h3 = json.loads((EVIDENCE / "h3/result.json").read_text())
    assert h3["status"] == "PASS" and len(h3["checks"]) == 3 and h3["ports_rebound"]
    changed = [name for name, digest in original.items()
               if not (ROOT / name).is_file() or hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest]
    assert not changed, f"source changed during build: {changed}"
    archive = OUTPUT / "gaoxy-0.3.0-linux-x86_64.tar.gz"
    run("package", ["tar", "-C", "_build/prod/rel/gaoxy", "-czf", str(archive), "."])
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (OUTPUT / "SHA256SUMS").write_text(f"{digest}  {archive.name}\n")
    applications = {name: "0.3.0" for name in ("gaoxy", "gaoxy_http", "gaoxy_http3", "gaoxy_proxy", "gaoxy_server")}
    with tarfile.open(archive) as package:
        inventory = package.getmembers()
        for name, version in applications.items():
            members = [m for m in inventory if m.name.endswith(f"/ebin/{name}.app")]
            assert len(members) == 1 and members[0].isfile(), (name, members)
            content = package.extractfile(members[0]).read().decode()
            assert re.search(r'\{vsn,\s*"' + re.escape(version) + r'"\}', content), (name, content)
        assert all(member.isfile() or member.isdir() for member in inventory), "invalid archive entry type"
    info = {"version": "0.3.0", "source_sha": SOURCE,
            "source_archive_sha256": hashlib.sha256(Path("/tools/source.tar").read_bytes()).hexdigest(),
            "root_lock_sha256": IDENTITY["root_lock_sha256"],
            "source_files_checked_unchanged": len(original), "applications": applications, "archive_entries": len(inventory), "platform": "linux/amd64",
            "support": "Debian bookworm glibc x86_64; broader platforms unqualified",
            "builder": "hexpm/elixir@sha256:abbfaf9699b7a3650810c92268023806217486c26b4da3dc0492a778b22a09bb",
            "rust_image": "rust@sha256:0e2bcaef56d041a486784e54104a81aebe0da44bd03019bd70bc0401e42e4a97",
            "elixir_source_sha": "dfe6612e546cec6557900e67651f7d21805472ef",
            "runtime_base": "debian@sha256:a4672c0cb26fbdde88e38fa2dfb6c681942306680e41e4378b28770b6e79ee91",
            "toolchain_and_packages": versions, "compatibility_tests": executed, "compatibility_failures": 0, "compatibility_by_application": app_counts,
            "core_transports": 3, "gateway_exchanges": 2, "h3_checks": 3, "archive_sha256": digest,
            "built_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "checks": checks}
    (OUTPUT / "build-info.json").write_text(json.dumps(info, indent=2) + "\n")
    print(f"PASS clean portable build:{executed} tests/0 failures; core3; gateway2; SHA256={digest}", flush=True)
