#!/usr/bin/env python3
"""Verify isolated consumers of built package tarballs or published Hex packages."""
import argparse
import io
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile


ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "integration/http3"))
from quinn_peer import prepare as prepare_h3_peer

FIXTURES = {
    "base": "test_consumer",
    "h3": "test_h3_consumer",
    "http_fetch": "http_fetch_test_consumer",
}
PACKAGES = ["gaoxy_websock_adapter", "gaoxy", "gaoxy_http", "gaoxy_http3", "gaoxy_proxy", "gaoxy_test"]


def execute(command, directory, env, expected=None):
    print("CONSUMER_COMMAND", directory.name, " ".join(map(str, command)), flush=True)
    result = subprocess.run(command, cwd=directory, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
    print(result.stdout, end="", flush=True)
    if result.returncode:
        raise RuntimeError(f"consumer command failed: exit {result.returncode}")
    if expected and expected not in result.stdout:
        raise RuntimeError(f"missing required consumer evidence: {expected}")
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kind", choices=[*FIXTURES, "all"], default="all")
    parser.add_argument("--published", action="store_true")
    parser.add_argument("--version")
    args = parser.parse_args()
    source_version = re.search(r'version: "([^\"]+)"', (ROOT / "mix.exs").read_text()).group(1)
    version = args.version
    if version is None:
        if args.published:
            parser.error("--published requires --version")
        version = source_version
    if not args.published and version != source_version:
        parser.error(f"local package version must match source: {version} != {source_version}")
    selected = list(FIXTURES) if args.kind == "all" else [args.kind]
    env = {**os.environ, "MIX_ENV": "test", "GAOXY_TEST_VERSION": version}
    env.setdefault("ELIXIR_ERL_OPTIONS", "+S 2:2")
    env.pop("GAOXY_TEST_PACKAGES", None)
    env.setdefault("GAOXY_QUIC_PYTHON", str(ROOT / ".audit/h2peer/bin/python"))
    print("CONSUMER_SOURCE", subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(), flush=True)
    print("CONSUMER_MODE", "published-hex-only" if args.published else "built-tarballs-local-siblings",
          "version=" + version, flush=True)

    with tempfile.TemporaryDirectory(prefix="gaoxy-test-consumers-") as temporary:
        workspace = Path(temporary)
        if "h3" in selected:
            binary, _ = prepare_h3_peer(workspace / "h3-peer")
            env["GAOXY_H3_CONSUMER_PEER"] = str(binary)
        if not args.published:
            staged, unpacked = workspace / "staged", workspace / "packages"
            execute(["elixir", str(ROOT / "scripts/stage-hex-packages.exs"), str(ROOT), str(staged)],
                    ROOT, env)
            unpacked.mkdir()
            for package in PACKAGES:
                archive = workspace / f"{package}-{version}.tar"
                execute(["mix", "hex.build", "--output", str(archive)], staged / package, env)
                target = unpacked / package
                target.mkdir()
                with tarfile.open(archive) as outer:
                    payload = outer.extractfile("contents.tar.gz").read()
                with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as contents:
                    contents.extractall(target, filter="data")
            env["GAOXY_TEST_PACKAGES"] = str(unpacked)

        for kind in selected:
            fixture = FIXTURES[kind]
            target = workspace / fixture
            shutil.copytree(ROOT / "integration" / fixture, target,
                            ignore=shutil.ignore_patterns("deps", "_build", "mix.lock"))
            if kind == "h3":
                shutil.copyfile(ROOT / "integration/h3_consumer/peer.py", target / "peer.py")
            execute(["mix", "deps.get"], target, env)
            execute(["mix", "compile", "--warnings-as-errors"], target, env)
            output = execute([sys.executable, str(ROOT / "scripts/check-tests.py"),
                              "test/consumer_test.exs", "--seed", "0"], target, env)
            if re.search(r"[1-9]\d* (?:excluded|skipped)", output):
                raise RuntimeError("required consumer cases excluded or skipped")
            if kind == "base":
                execute(["mix", "run", "manual.exs"], target, env,
                        "GAOXY_TEST_MANUAL_PASS cases=1 exunit_started=false")
                production_env = {**env, "MIX_ENV": "prod"}
                execute(["mix", "deps.get"], target, production_env)
                execute(["mix", "run", "production.exs"], target, production_env,
                        "GAOXY_TEST_PRODUCTION_PASS cases=1 helper_absent=true exunit_absent=true")
                execute(["mix", "release", "--overwrite"], target, production_env)
                release = target / "_build/prod/rel/gaoxy_test_consumer"
                for forbidden in ["gaoxy_test", "gaoxy_http", "gaoxy_http3", "ex_unit"]:
                    if list((release / "lib").glob(forbidden + "-[0-9]*")):
                        raise RuntimeError(f"test dependency leaked into production release: {forbidden}")
                print("CONSUMER_RELEASE_ISOLATION_PASS cases=1 helper_absent=true exunit_absent=true", flush=True)
            print("CONSUMER_PASS", kind, flush=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        sys.exit(f"CONSUMER_FAIL: {error}")
