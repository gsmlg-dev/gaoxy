#!/usr/bin/env python3
"""Run issue #16/#17 regressions after publication in fresh Hex-only consumers.

Invocation requires the frozen publication SHA and reviewed H2 execution count.
Only application fixtures, tests and protocol peers are copied from that SHA.
All Gaoxy library/runtime dependencies resolve from public Hex, without source
dependency injection, inherited lockfiles, build directories or dependency paths.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
VERSION = "0.13.0"
REPO = "gsmlg-dev/gaoxy"
NATIVE_TESTS = (
    ("native-default", "websocket_default_capacity_network_test.exs", 5),
    ("tls-startup-close", "http2_startup_peer_close_network_test.exs", 1),
)
PHOENIX_TESTS = (
    ("phoenix-default", "websocket_default_capacity_test.exs", 1),
    ("phoenix-configured", "websocket_configured_limits_test.exs", 6),
    ("phoenix-compatibility", "websocket_phoenix_compatibility_test.exs", 6),
)
PACKAGES = {
    "gaoxy": "apps/gaoxy",
    "gaoxy_http": "apps/gaoxy_http",
    "websock_adapter": "vendor/websock_adapter",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def save(path, value):
    temporary = path.with_suffix(".writing")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    temporary.replace(path)


def clean_environment():
    environment = dict(os.environ)
    for name in list(environment):
        if (name.startswith(("MIX_", "GAOXY_", "PHOENIX_NATIVE_"))
                or name in {"HEX_HOME", "HEX_OFFLINE", "HEX_MIRROR", "HEX_TRUSTED_MIRROR_URL",
                            "ERL_LIBS", "ERL_FLAGS", "ERL_AFLAGS", "ERL_ZFLAGS",
                            "ELIXIR_ERL_OPTIONS", "PYTHONPATH", "PYTHONHOME", "VIRTUAL_ENV"}):
            environment.pop(name)
    environment.update(MIX_ENV="test", ELIXIR_ERL_OPTIONS="+S 2:2",
                       PYTHONNOUSERSITE="1", PIP_DISABLE_PIP_VERSION_CHECK="1")
    return environment


class Audit:
    def __init__(self, sha, h2_count):
        self.folder = Path(tempfile.mkdtemp(prefix="public-regressions-", dir=HERE))
        self.workspace = self.folder / "workspace"
        self.workspace.mkdir()
        self.env = clean_environment()
        self.sha = sha
        self.receipt = {
            "status": "FAIL", "version": VERSION, "repo": REPO,
            "source_commit": sha, "started_at": now(), "workspace": str(self.workspace),
            "mode": "published-hex-only", "h2_expected_executions": h2_count,
            "commands": [], "copied_source_files": {}, "generated_manifests": {},
            "consumers": {}, "test_phases": {}, "processes_stopped": True,
        }
        self.checkpoint()

    def checkpoint(self):
        save(self.folder / "receipt.json", self.receipt)

    def command(self, phase, arguments, directory=None, timeout=600):
        directory = directory or ROOT
        logfile = self.folder / f"{len(self.receipt['commands']):02d}-{phase}.log"
        entry = {"phase": phase, "command": list(map(str, arguments)), "cwd": str(directory),
                 "timeout_seconds": timeout, "status": "RUNNING", "started_at": now(),
                 "log": str(logfile)}
        self.receipt["commands"].append(entry)
        self.receipt["processes_stopped"] = False
        self.checkpoint()
        started = time.monotonic()
        process = None
        try:
            with logfile.open("wb") as output:
                process = subprocess.Popen(arguments, cwd=directory, env=self.env,
                                           stdout=output, stderr=subprocess.STDOUT,
                                           start_new_session=True)
                entry["pid"] = entry["process_group"] = process.pid
                try:
                    entry["exit"] = process.wait(timeout=timeout)
                except subprocess.TimeoutExpired:
                    entry["timed_out"] = True
                    raise RuntimeError(f"phase {phase} exceeded {timeout}s")
            entry["status"] = "PASS" if entry["exit"] == 0 else "FAIL"
        except BaseException as error:
            entry["status"] = "FAIL"
            entry["error"] = f"{type(error).__name__}: {error}"
            raise
        finally:
            # Every command has its own process group. Stop only its descendants,
            # including protocol peers that might survive a failing ExUnit VM.
            if process is not None:
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                    entry["group_termination_sent"] = True
                except ProcessLookupError:
                    entry["group_termination_sent"] = False
                if process.poll() is None:
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait(timeout=5)
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                    entry["group_kill_sent"] = True
                except ProcessLookupError:
                    entry["group_kill_sent"] = False
                entry.setdefault("exit", process.returncode)
            entry.update(finished_at=now(), seconds=round(time.monotonic() - started, 3))
            if logfile.exists():
                entry["log_sha256"] = sha256(logfile.read_bytes())
            self.receipt["processes_stopped"] = True
            save(logfile.with_suffix(".json"), entry)
            self.checkpoint()
            print(f"{phase}: {entry['status']} exit={entry.get('exit')} log={logfile}", flush=True)
        require(entry["exit"] == 0, f"{phase} failed: {logfile}")
        return logfile.read_text(errors="replace")

    def git_bytes(self, relative):
        require(not Path(relative).is_absolute() and ".." not in Path(relative).parts,
                f"unsafe source path: {relative}")
        return subprocess.check_output(["git", "show", f"{self.sha}:{relative}"],
                                       cwd=ROOT, timeout=30)

    def copy(self, relative):
        data = self.git_bytes(relative)
        destination = self.workspace / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open("xb") as output:
            output.write(data)
        self.receipt["copied_source_files"][relative] = {"sha256": sha256(data), "bytes": len(data)}
        return destination

    def source_paths(self, prefix):
        output = subprocess.check_output(["git", "ls-tree", "-rz", "--name-only", self.sha,
                                          "--", prefix], cwd=ROOT, timeout=30)
        return [value.decode() for value in output.split(b"\0") if value]

    def tag_guard(self, phase):
        target = json.loads(self.command(phase, ["gh", "api",
                            f"repos/{REPO}/git/ref/tags/v{VERSION}"], timeout=60))["object"]
        for depth in range(5):
            if target["type"] == "commit":
                require(target["sha"] == self.sha,
                        f"remote release tag differs: {target['sha']} != {self.sha}")
                self.receipt[phase] = target["sha"]
                self.checkpoint()
                return
            require(target["type"] == "tag", f"unexpected release tag object: {target}")
            target = json.loads(self.command(f"{phase}-peel-{depth}", ["gh", "api",
                                f"repos/{REPO}/git/tags/{target['sha']}"], timeout=60))["object"]
        raise ValueError("release tag nesting exceeds five levels")

    def manifest(self, consumer, phoenix=False):
        consumer.mkdir(parents=True, exist_ok=True)
        dependencies = f'''      {{:gaoxy, "== {VERSION}", override: true}},
      {{:gaoxy_http, "== {VERSION}"}},
      {{:websock_adapter, "== {VERSION}", hex: :gaoxy_websock_adapter, override: true}}'''
        if phoenix:
            dependencies += ''',
      {:phoenix, "== 1.8.16"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:jason, "~> 1.4"}'''
        app = "phoenix_native" if phoenix else "public_native_consumer"
        application = ('[mod: {PhoenixNative.Application, []}, extra_applications: [:logger, :ssl]]'
                       if phoenix else '[extra_applications: [:logger, :ssl]]')
        manifest = f'''defmodule PublicReleaseConsumer.MixProject do
  use Mix.Project
  def project do
    [app: :{app}, version: "0.1.0", elixir: "~> 1.18",
     elixirc_paths: ["lib"], deps: [
{dependencies}
    ]]
  end
  def application, do: {application}
end
'''
        require(not re.search(r"\b(?:git|github|path|in_umbrella):", manifest),
                "generated consumer contains a source dependency")
        (consumer / "mix.exs").write_text(manifest)
        self.receipt["generated_manifests"][str(consumer.relative_to(self.workspace))] = {
            "sha256": sha256(manifest.encode()), "contents": manifest}
        self.checkpoint()

    def verify_dependencies(self, name, consumer):
        lock = (consumer / "mix.lock").read_bytes()
        text = lock.decode()
        require(b":git," not in lock and b":path," not in lock,
                f"{name} has source/path dependencies")
        for app, package in (("gaoxy", "gaoxy"), ("gaoxy_http", "gaoxy_http"),
                             ("websock_adapter", "gaoxy_websock_adapter")):
            require(re.search(r'"' + app + r'": \{:hex, :' + package + r', "'
                              + re.escape(VERSION) + r'"', text),
                    f"{name} does not resolve exact public {package} {VERSION}")
        for app, version in (("hell", "0.1.3"), ("abyss", "0.10.0")):
            require(re.search(r'"' + app + r'": \{:hex, :' + app + r', "'
                              + re.escape(version) + r'"', text),
                    f"{name} does not resolve expected public {app} {version}")
        source_hashes = {}
        for app, source in PACKAGES.items():
            paths = [path for path in self.source_paths(source + "/lib") if path.endswith(".ex")]
            expected = {path[len(source) + 1:] for path in paths}
            actual = {str(path.relative_to(consumer / "deps" / app))
                      for path in (consumer / "deps" / app / "lib").rglob("*.ex")}
            require(expected == actual, f"{name} public {app} source file set differs")
            for path in paths:
                relative = path[len(source) + 1:]
                public = consumer / "deps" / app / relative
                data = self.git_bytes(path)
                require(public.read_bytes() == data, f"public source mismatch: {name}/{app}/{relative}")
                source_hashes[f"{app}/{relative}"] = sha256(data)
        self.receipt["consumers"][name] = {
            "directory": str(consumer), "lock_sha256": sha256(lock),
            "hex_only": True, "exact_public_versions": VERSION,
            "public_source_sha256": source_hashes, "public_source_file_count": len(source_hashes)}
        self.checkpoint()

    def resolve(self, name, consumer):
        require(not (consumer / "mix.lock").exists() and not (consumer / "deps").exists()
                and not (consumer / "_build").exists(), f"{name} consumer is not fresh")
        self.command(f"{name}-resolve", ["mix", "deps.get"], consumer)
        self.verify_dependencies(name, consumer)
        self.command(f"{name}-compile", ["mix", "compile", "--warnings-as-errors"], consumer)
        self.command(f"{name}-dependencies", ["mix", "deps"], consumer)

    def test(self, phase, filename, count, consumer):
        entry = {"status": "RUNNING", "expected": count, "file": filename}
        self.receipt["test_phases"][phase] = entry
        self.checkpoint()
        try:
            output = self.command(phase, [sys.executable, str(self.workspace / "scripts/check-tests.py"),
                                  "test/" + filename, "--seed", "20261025", "--max-cases", "1"],
                                  consumer, timeout=600)
            matches = re.findall(r"(\d+) tests?, (\d+) failures?([^\n]*)", output)
            entry["observed_summaries"] = matches
            require(len(matches) == 1 and tuple(map(int, matches[0][:2])) == (count, 0),
                    f"{phase} must execute exactly {count} tests with zero failures: {matches}")
            require(not re.search(r"[1-9]\d* (?:excluded|skipped)", output),
                    f"{phase} excluded or skipped required tests")
            entry.update(status="PASS", executed=count, failures=0, excluded=0, skipped=0)
        except BaseException as error:
            entry.update(status="FAIL", error=f"{type(error).__name__}: {error}")
            raise
        finally:
            self.checkpoint()

    def run(self, h2_file, h2_count):
        self.command("source-identity", ["git", "rev-parse", self.sha + "^{commit}"])
        self.tag_guard("remote_tag_before")
        self.copy("scripts/check-tests.py")
        self.copy("scripts/generate-fixtures.sh")
        native = self.workspace / "apps/gaoxy_http"
        self.manifest(native)
        self.copy("apps/gaoxy_http/test/test_helper.exs")
        phases = (*NATIVE_TESTS, ("h2-persistence", h2_file, h2_count))
        for _, filename, _ in phases:
            self.copy("apps/gaoxy_http/test/" + filename)
        for relative in ("apps/gaoxy_http/test/support/websocket_persistent_h2_peer.py",
                         "apps/gaoxy_http/test/support/h2-requirements.txt"):
            self.copy(relative)
        # Preserve the peer path expected by the source test, within this fresh
        # workspace. This venv contains only independent Python protocol tools.
        venv = self.workspace / ".audit/h2peer"
        self.command("python-peer-venv", [sys.executable, "-m", "venv", str(venv)])
        self.command("python-peer-dependencies", [str(venv / "bin/python"), "-m", "pip", "install",
                     "--requirement", str(native / "test/support/h2-requirements.txt")], timeout=180)
        self.command("python-peer-versions", [str(venv / "bin/python"), "-m", "pip", "freeze"])
        self.resolve("native", native)
        for phase, filename, count in phases:
            self.test(phase, filename, count, native)

        phoenix = self.workspace / "examples/phoenix_native"
        self.manifest(phoenix, phoenix=True)
        for relative in self.source_paths("examples/phoenix_native/lib"):
            self.copy(relative)
        self.copy("examples/phoenix_native/config/config.exs")
        self.copy("examples/phoenix_native/test/test_helper.exs")
        for _, filename, _ in PHOENIX_TESTS:
            self.copy("examples/phoenix_native/test/" + filename)
        # Exact source bytes are retained, with no transport-budget or frame
        # overrides injected into the actual default LiveView test.
        default_test = self.git_bytes("examples/phoenix_native/test/websocket_default_capacity_test.exs")
        require(not re.search(rb"\b(?:max_frame_size|max_message_size|max_bytes|max_state):", default_test),
                "actual Phoenix default fixture contains a capacity override")
        self.resolve("phoenix", phoenix)
        for phase, filename, count in PHOENIX_TESTS:
            self.test(phase, filename, count, phoenix)
        self.tag_guard("remote_tag_after")
        self.receipt["executed"] = sum(item["executed"] for item in self.receipt["test_phases"].values())
        self.receipt["failures"] = self.receipt["excluded"] = self.receipt["skipped"] = 0
        self.receipt["status"] = "PASS"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sha", required=True, help="full frozen publication source commit")
    parser.add_argument("--h2-count", required=True, type=int, help="reviewed positive H2 network execution count")
    parser.add_argument("--h2-test", default="http2_websocket_network_test.exs")
    parser.add_argument("--run-published", action="store_true", help="explicitly run only after publication")
    args = parser.parse_args()
    require(re.fullmatch(r"[0-9a-f]{40}", args.sha), "--sha must be full lowercase commit SHA")
    require(args.h2_count > 0, "--h2-count must be positive")
    require(re.fullmatch(r"[a-z0-9_]+_test\.exs", args.h2_test), "--h2-test must be a test basename")
    require(args.run_published, "use --run-published only after publication is authorized and complete")
    audit = Audit(args.sha, args.h2_count)
    try:
        audit.run(args.h2_test, args.h2_count)
    except BaseException as error:
        audit.receipt["error"] = f"{type(error).__name__}: {error}"
    finally:
        audit.receipt["finished_at"] = now()
        audit.checkpoint()
        print(json.dumps({"status": audit.receipt["status"], "receipt": str(audit.folder / "receipt.json"),
                          "error": audit.receipt.get("error")}), flush=True)
    return 0 if audit.receipt["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
