#!/usr/bin/env python3
"""Compile an isolated candidate HTTP consumer, request /health once, then stop."""
import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def run(command, project, environment, output, timeout):
    output.write("COMMAND " + " ".join(command) + "\n")
    output.flush()
    child = subprocess.Popen(command, cwd=project, env=environment, stdout=output,
                             stderr=subprocess.STDOUT, start_new_session=True)
    try:
        if child.wait(timeout=timeout):
            raise RuntimeError(f"command failed: {command}, exit {child.returncode}")
    finally:
        if child.poll() is None:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait(timeout=5)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, default=ROOT / ".audit/portable-smoke")
    args = parser.parse_args()
    args.evidence.mkdir(parents=True, exist_ok=True)
    report = {"status": "FAIL", "mode": "candidate-source-boot",
              "platform": platform.platform(), "requests": 0,
              "source": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()}
    try:
        with tempfile.TemporaryDirectory(prefix="gaoxy-portable-") as directory:
            stage = Path(directory)
            for relative in ("apps/gaoxy", "apps/gaoxy_http", "vendor/websock_adapter",
                             "integration/portable_smoke"):
                shutil.copytree(ROOT / relative, stage / relative,
                                ignore=shutil.ignore_patterns("_build", "deps"))
            project = stage / "integration/portable_smoke"
            shutil.copyfile(ROOT / "mix.lock", project / "mix.lock")
            cached = os.environ.get("GAOXY_CONSUMER_DEPS")
            if cached:
                shutil.copytree(cached, project / "deps")
            environment = dict(os.environ, MIX_ENV="prod")
            # A consumer must build independently of the umbrella's build directory.
            environment.pop("MIX_BUILD_PATH", None)
            with (args.evidence / "consumer.log").open("w") as output:
                run(["mix", "deps.get", "--check-locked"], project, environment, output, 180)
                run(["mix", "compile", "--warnings-as-errors"], project, environment, output, 300)
                run(["mix", "run", "--no-compile", "smoke.exs"], project, environment, output, 30)
            assert "GAOXY_PORTABLE_PASS" in (args.evidence / "consumer.log").read_text()
            report.update(status="PASS", requests=1, stopped=True, exit=0)
    except BaseException as error:
        report["error"] = repr(error)
        raise
    finally:
        (args.evidence / "result.json").write_text(json.dumps(report, indent=2) + "\n")
    print("GAOXY_PORTABLE_PASS " + json.dumps(report))


if __name__ == "__main__":
    main()
