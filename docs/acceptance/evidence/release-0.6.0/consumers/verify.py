#!/usr/bin/env python3
"""Prepare disposable consumers; execute public Hex checks only when requested."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time


BASE = Path(__file__).resolve().parent
ROOT = Path("/home/gao/Workspace/gsmlg-opt/gaoxy")
VERSION = "0.6.0"
OWN = {"gaoxy", "gaoxy_http", "gaoxy_http3", "gaoxy_proxy", "gaoxy_websock_adapter"}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def manifest(module, app, deps, extra="", application="[extra_applications: [:logger]]"):
    return f'''defmodule {module}.MixProject do
  use Mix.Project
  def project, do: [app: :{app}, version: "0.1.0", elixir: "~> 1.18", deps: [{deps}]{extra}]
  def application, do: {application}
end
'''


def environment(run, project):
    # Keep installed Mix/Hex/Rebar tools, without inherited repository, mirror,
    # authentication, dependency, build, or cache configuration.
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(("HEX_", "PHOENIX_NATIVE_", "GAOXY_")) and key not in {
               "MIX_DEPS_PATH", "MIX_BUILD_PATH", "MIX_LOCKFILE", "MIX_EXS", "MIX_PATH"}}
    env.update(HEX_HOME=str(run / "hex-home"), HEX_CACHE_HOME=str(run / "hex-cache"),
               XDG_CACHE_HOME=str(run / "cache"), MIX_ENV="test",
               MIX_DEPS_PATH=str(project / "deps"), MIX_BUILD_PATH=str(project / "_build"),
               ELIXIR_ERL_OPTIONS="+S 2:2", ERL_FLAGS="+S 2:2", HEX_HTTP_TIMEOUT="30")
    return env


def save(run, result):
    (run / "result.json").write_text(json.dumps(result, indent=2) + "\n")


def prepare(snapshot, inputs):
    snapshot = Path(snapshot).resolve()
    inputs = Path(inputs).resolve()
    binding = json.loads(inputs.read_text())
    assert Path(binding["source_root"]).resolve() == snapshot
    assert all(sha(snapshot / path) == digest for path, digest in binding["source_files"].items())
    run = BASE / f"run-{time.time_ns()}"
    run.mkdir()
    result = {"status": "PREPARING", "version": VERSION, "run": str(run),
              "snapshot": str(snapshot), "snapshot_base": binding["base"],
              "candidate_inputs": str(inputs), "candidate_inputs_sha256": sha(inputs),
              "tool_sha256": sha(Path(__file__)),
              "public_repository": "https://repo.hex.pm", "checks": [],
              "fixture_source_sha256": {}, "prepared_source_sha256": {}}
    core, http, phoenix = [run / name for name in ("core", "http", "phoenix")]
    for project in (core, http, phoenix):
        project.mkdir()

    def copy_tree(relative, destination):
        source = snapshot / relative
        shutil.copytree(source, destination)
        for path in source.rglob("*"):
            if path.is_file():
                result["fixture_source_sha256"][str(path.relative_to(snapshot))] = sha(path)
                assert path.read_bytes() == (destination / path.relative_to(source)).read_bytes()

    copy_tree("integration/core_consumer/test", core / "test")
    copy_tree("integration/http_consumer/test", http / "test")
    for folder in ("lib", "config", "test"):
        copy_tree("examples/phoenix_native/" + folder, phoenix / folder)
    (core / "mix.exs").write_text(manifest("CoreConsumer", "core_consumer", f'{{:gaoxy, "== {VERSION}"}}'))
    (http / "mix.exs").write_text(manifest("HTTPConsumer", "http_consumer", f'{{:gaoxy_http, "== {VERSION}"}}'))
    (phoenix / "mix.exs").write_text(manifest("PhoenixNative", "phoenix_native", f'''
      {{:gaoxy_http, "== {VERSION}"}},
      {{:websock_adapter, "== {VERSION}", hex: :gaoxy_websock_adapter, override: true}},
      {{:phoenix, "== 1.8.16"}},
      {{:phoenix_live_view, "~> 1.1"}},
      {{:phoenix_html, "~> 4.0"}},
      {{:phoenix_pubsub, "~> 2.1"}},
      {{:jason, "~> 1.4"}}
    ''', extra=', elixirc_paths: ["lib"], listeners: [Phoenix.CodeReloader]',
        application='[mod: {PhoenixNative.Application, []}, extra_applications: [:logger, :ssl]]'))
    # Preserve the accepted upstream lock cohort. Own packages and Git/path
    # entries are excluded; their first resolution will use public Hex.
    # Both accepted lockfiles use one complete entry per line. Preserve the
    # exact upstream entries; reject an unfamiliar format or conflicting cohort.
    locks = [snapshot / "mix.lock", snapshot / "examples/phoenix_native/mix.lock"]
    entries = {}
    for path in locks:
        lines = path.read_text().splitlines()
        assert lines[0] == "%{" and lines[-1] == "}"
        for line in lines[1:-1]:
            match = re.fullmatch(r'  "([^"\n]+)": (.+),', line)
            assert match, (path, line)
            app, value = match.groups()
            if not value.startswith("{:hex,"):
                continue
            package = re.match(r"\{:hex, :([a-z0-9_]+),", value).group(1)
            if package in OWN:
                continue
            assert app not in entries or entries[app] == value, ("inconsistent accepted lock entry", app)
            entries[app] = value
    lock_text = "%{\n" + "".join(f'  "{app}": {value},\n' for app, value in sorted(entries.items())) + "}\n"
    result["accepted_lock_sources"] = {str(path.relative_to(snapshot)): sha(path) for path in locks}
    (run / "accepted-upstream.lock").write_text(lock_text)
    result["accepted_upstream_lock_sha256"] = sha(run / "accepted-upstream.lock")
    for project in (core, http, phoenix):
        (project / "mix.lock").write_text(lock_text)
    for project in (core, http, phoenix):
        for path in project.rglob("*"):
            if path.is_file():
                result["prepared_source_sha256"][str(path.relative_to(run))] = sha(path)
    assert not any(path.name in {"deps", "_build"} for path in run.rglob("*"))
    counts = {name: sum(len(re.findall(r"^\s*test \"", p.read_text(), re.M))
                        for p in (run / name / "test").glob("*_test.exs"))
              for name in ("core", "http", "phoenix")}
    assert counts == {"core": 1, "http": 3, "phoenix": 5}, counts
    result["expected_test_counts"] = counts
    result["status"] = "PREPARED"
    result["execution"] = "NOT RUN; awaiting confirmed public publication"
    save(run, result)
    print("PREPARED", run)


def execute(directory, source, release_run, publication):
    run = Path(directory).resolve()
    assert run.parent == BASE, "execution must use a prepared run in this harness directory"
    result = json.loads((run / "result.json").read_text())
    assert result["status"] == "PREPARED", "prepare a fresh run instead of overwriting evidence"
    assert re.fullmatch(r"[0-9a-f]{40}", source)
    publication = Path(publication).resolve()
    published = json.loads(publication.read_text())
    assert published["status"] == "PASS" and published["version"] == VERSION
    assert published["source"] == source and published["run_id"] == release_run
    snapshot = Path(result["snapshot"])
    assert sha(Path(result["candidate_inputs"])) == result["candidate_inputs_sha256"]
    assert sha(Path(__file__)) == result["tool_sha256"], "harness changed after preparation"
    result.update(source=source, run_id=release_run, publication_receipt=str(publication),
                  publication_receipt_sha256=sha(publication))
    assert sha(run / "accepted-upstream.lock") == result["accepted_upstream_lock_sha256"]
    for relative, expected in result["prepared_source_sha256"].items():
        assert sha(run / relative) == expected, relative
    for relative, expected in result["fixture_source_sha256"].items():
        assert sha(snapshot / relative) == expected, relative

    def command(name, args, project=run, timeout=600):
        if args[0] == "mix":
            args = ["/nix/store/hypwn40g5g43jvfgx8hha9b130v8vigy-expect-5.45.4/bin/unbuffer", *args]
        print("START", name, flush=True)
        started = datetime.datetime.now(datetime.timezone.utc).isoformat()
        env = environment(run, project)
        try:
            proc = subprocess.run(args, cwd=project, env=env,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
            stdout, stderr, exit_code = proc.stdout, proc.stderr, proc.returncode
        except subprocess.TimeoutExpired as error:
            stdout, stderr, exit_code = error.stdout or b"", error.stderr or b"", "TIMEOUT"
        path = run / (name + ".stdout")
        error_path = run / (name + ".stderr")
        path.write_bytes(stdout)
        error_path.write_bytes(stderr)
        result["checks"].append({"name": name, "command": args, "cwd": str(project),
                                 "started_utc": started, "exit": exit_code,
                                 "environment": {key: env.get(key) for key in ("MIX_ENV", "MIX_DEPS_PATH", "MIX_BUILD_PATH", "HEX_HOME", "HEX_CACHE_HOME", "XDG_CACHE_HOME", "ELIXIR_ERL_OPTIONS", "ERL_FLAGS")},
                                 "stdout": str(path), "stdout_sha256": sha(path),
                                 "stderr": str(error_path), "stderr_sha256": sha(error_path)})
        save(run, result)
        print(stdout.decode(errors="replace"), end="", flush=True)
        print(stderr.decode(errors="replace"), end="", flush=True)
        assert exit_code == 0, f"{name} failed: {exit_code}"
        return stdout.decode()

    try:
        result["status"] = "RUNNING"
        # Bind every original fixture/lock to the supplied actual commit without
        # consulting live working files. Capture real hashes BEFORE any resolution/test.
        inputs = {**result["fixture_source_sha256"], **result["accepted_lock_sources"]}
        result["pretest_source_sha256"] = {relative: sha(snapshot / relative) for relative in inputs}
        result["pretest_prepared_sha256"] = {relative: sha(run / relative) for relative in result["prepared_source_sha256"]}
        commit_files = {}
        for index, (relative, digest) in enumerate(sorted(inputs.items())):
            data = command(f"source-{index}", ["git", "-C", str(ROOT), "show", f"{source}:{relative}"], timeout=30)
            actual = hashlib.sha256(data.encode()).hexdigest()
            assert actual == digest == result["pretest_source_sha256"][relative], relative
            commit_files[relative] = actual
        result["committed_fixture_and_lock_sha256"] = commit_files
        save(run, result)
        result["runtime_versions"] = command("runtime-versions", ["elixir", "--version"])
        repositories = command("public-repository", ["mix", "hex.repo", "list"])
        assert "hexpm" in repositories and "https://repo.hex.pm" in repositories
        assert "127.0.0.1" not in repositories and "localhost" not in repositories
        for name, expected in (("core", 1), ("http", 3), ("phoenix", 5)):
            project = run / name
            command(name + "-deps", ["mix", "deps.get"], project)
            command(name + "-trim-lock", ["mix", "deps.unlock", "--unused"], project)
            assert ":git" not in (project / "mix.lock").read_text()
            command(name + "-compile", ["mix", "compile", "--warnings-as-errors"], project)
            assertion = '''
deps = Mix.Dep.load_and_cache()
lock = Mix.Dep.Lock.read()
{accepted, _} = Code.eval_file("../accepted-upstream.lock")
true = Enum.all?(deps, &(&1.scm == Hex.SCM))
true = Enum.all?(deps, &(&1.app not in [:abyss_raw, :rustler]))
Enum.each(deps, fn dep ->
  true = String.starts_with?(dep.opts[:dest], System.fetch_env!("MIX_DEPS_PATH") <> "/")
  {:hex, package, version, _, _, _, "hexpm", _} = lock[dep.app]
  if dep.app in [:gaoxy, :gaoxy_http, :gaoxy_http3, :gaoxy_proxy, :websock_adapter] do
    "0.6.0" = version
    true = package == if(dep.app == :websock_adapter, do: :gaoxy_websock_adapter, else: dep.app)
  else
    case accepted[dep.app] do
      nil ->
        true = {dep.app, version} in [{:hell, "0.1.2"}, {:abyss, "0.9.0"}]
      previous ->
        true = lock[dep.app] == previous
    end
  end
  IO.puts("PUBLIC_HEX_DEP #{dep.app} #{package} #{version}")
end)
Code.ensure_loaded!(Gaoxy)
true = String.starts_with?(to_string(:code.which(Gaoxy)), System.fetch_env!("MIX_BUILD_PATH") <> "/")
'''
            command(name + "-resolved", ["mix", "run", "--no-start", "--no-compile", "-e", assertion], project)
            output = command(name + "-tests", ["mix", "test", "--warnings-as-errors", "--seed", "0", "--max-cases", "1"], project)
            summary = re.findall(r"(\d+) tests?, (\d+) failures?([^\n]*)", output)
            assert len(summary) == 1 and tuple(map(int, summary[0][:2])) == (expected, 0), summary
            assert "excluded" not in summary[0][2] and "skipped" not in summary[0][2], summary
            result.setdefault("consumers", {})[name] = {"executed": expected, "failures": 0,
                                                       "lock_sha256": sha(project / "mix.lock")}
        for relative, expected in result["fixture_source_sha256"].items():
            assert sha(snapshot / relative) == expected, relative
        for relative, expected in result["prepared_source_sha256"].items():
            if not relative.endswith("mix.lock"):
                assert sha(run / relative) == expected, relative
        assert sha(run / "accepted-upstream.lock") == result["accepted_upstream_lock_sha256"]
        result["status"] = "PASS"
        result["execution"] = "core=1 / HTTP=3 / Phoenix=5 public Hex tests passed"
        save(run, result)
        print("PASS public Hex consumers", run, flush=True)
    except Exception as error:
        result["status"] = "FAIL"
        result["error"] = repr(error)
        save(run, result)
        raise
    finally:
        result["final_source_sha256"] = {relative: sha(snapshot / relative)
                                          for relative in {**result["fixture_source_sha256"], **result["accepted_lock_sources"]}}
        result["final_prepared_sha256"] = {relative: sha(run / relative) for relative in result["prepared_source_sha256"]}
        result["evidence_files_sha256"] = {str(path.relative_to(run)): sha(path)
                                           for path in sorted(run.iterdir()) if path.is_file() and path.name != "result.json"}
        result["finished_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        save(run, result)


parser = argparse.ArgumentParser(description=__doc__)
mode = parser.add_mutually_exclusive_group(required=True)
mode.add_argument("--prepare", action="store_true", help="Copy fixtures/merge accepted lock entries only; no commands or network")
mode.add_argument("--execute", metavar="PREPARED_RUN", help="Resolve and test only after confirmed publication")
parser.add_argument("--snapshot", type=Path, help="Clean parent-owned candidate source for preparation")
parser.add_argument("--candidate-inputs", type=Path, help="Parent candidate snapshot hash receipt for preparation")
parser.add_argument("--source", help="Full actual published commit SHA for execution")
parser.add_argument("--run", type=int, help="Actual successful release workflow run for execution")
parser.add_argument("--publication", type=Path, help="PASS publication verifier receipt for execution")
arguments = parser.parse_args()
if arguments.execute:
    if not (arguments.source and arguments.run and arguments.publication):
        parser.error("execution requires --source, --run and --publication")
    execute(arguments.execute, arguments.source, arguments.run, arguments.publication)
else:
    if not (arguments.snapshot and arguments.candidate_inputs):
        parser.error("preparation requires --snapshot and --candidate-inputs")
    prepare(arguments.snapshot, arguments.candidate_inputs)
