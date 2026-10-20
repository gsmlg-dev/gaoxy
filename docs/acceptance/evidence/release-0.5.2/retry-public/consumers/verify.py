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
ROOT = BASE.parents[2]
VERSION = "0.5.2"
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
           if not key.startswith("HEX_") and key not in {
               "MIX_DEPS_PATH", "MIX_BUILD_PATH", "MIX_LOCKFILE", "MIX_EXS", "MIX_PATH"}}
    env.update(HEX_HOME=str(run / "hex-home"), HEX_CACHE_HOME=str(run / "hex-cache"),
               XDG_CACHE_HOME=str(run / "cache"), MIX_ENV="test",
               MIX_DEPS_PATH=str(project / "deps"), MIX_BUILD_PATH=str(project / "_build"),
               ELIXIR_ERL_OPTIONS="+S 2:2", ERL_FLAGS="+S 2:2", HEX_HTTP_TIMEOUT="30")
    return env


def save(run, result):
    (run / "result.json").write_text(json.dumps(result, indent=2) + "\n")


def prepare():
    run = BASE / f"run-{time.time_ns()}"
    run.mkdir()
    result = {"status": "PREPARING", "version": VERSION, "run": str(run),
              "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "public_repository": "https://repo.hex.pm", "checks": [],
              "fixture_source_sha256": {}, "prepared_source_sha256": {}}
    core, http, phoenix = [run / name for name in ("core", "http", "phoenix")]
    for project in (core, http, phoenix):
        project.mkdir()

    def copy_tree(relative, destination):
        source = ROOT / relative
        shutil.copytree(source, destination)
        for path in source.rglob("*"):
            if path.is_file():
                result["fixture_source_sha256"][str(path.relative_to(ROOT))] = sha(path)
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
      {{:phoenix, "== 1.8.15"}},
      {{:phoenix_live_view, "~> 1.1"}},
      {{:phoenix_html, "~> 4.0"}},
      {{:phoenix_pubsub, "~> 2.1"}},
      {{:jason, "~> 1.4"}}
    ''', extra=', elixirc_paths: ["lib"], listeners: [Phoenix.CodeReloader]',
        application='[mod: {PhoenixNative.Application, []}, extra_applications: [:logger, :ssl]]'))
    # Preserve the accepted upstream lock cohort. Own packages and Git/path
    # entries are excluded; their first resolution will use public Hex.
    code = '''
locks = Enum.reduce(System.argv(), %{}, fn path, acc ->
  {lock, _} = Code.eval_file(path)
  Map.merge(acc, Map.filter(lock, fn {_app, value} ->
    elem(value, 0) == :hex and elem(value, 1) not in
      [:gaoxy, :gaoxy_http, :gaoxy_http3, :gaoxy_proxy, :gaoxy_websock_adapter]
  end),
    fn app, left, right ->
      if left != right, do: raise("inconsistent accepted lock entry #{app}")
      left
    end)
end)
IO.puts(inspect(locks, limit: :infinity, pretty: true, width: 98))
'''
    locks = [ROOT / "mix.lock", ROOT / "examples/phoenix_native/mix.lock"]
    command = ["elixir", "-e", code, *map(str, locks)]
    proc = subprocess.run(command, cwd=run, env=environment(run, run), text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
    (run / "prepare-lock.log").write_text(proc.stdout + proc.stderr)
    assert proc.returncode == 0, proc.stdout
    assert all(f':{name}, "{VERSION}"' not in proc.stdout for name in OWN)
    result["accepted_lock_sources"] = {str(path.relative_to(ROOT)): sha(path) for path in locks}
    (run / "accepted-upstream.lock").write_text(proc.stdout)
    result["accepted_upstream_lock_sha256"] = sha(run / "accepted-upstream.lock")
    for project in (core, http, phoenix):
        (project / "mix.lock").write_text(proc.stdout)
    for project in (core, http, phoenix):
        for path in project.rglob("*"):
            if path.is_file():
                result["prepared_source_sha256"][str(path.relative_to(run))] = sha(path)
    assert not any(path.name in {"deps", "_build"} for path in run.rglob("*"))
    result["status"] = "PREPARED"
    result["execution"] = "NOT RUN; awaiting confirmed public publication"
    save(run, result)
    print("PREPARED", run)


def execute(directory):
    run = Path(directory).resolve()
    assert run.parent == BASE, "execution must use a prepared run in this harness directory"
    result = json.loads((run / "result.json").read_text())
    assert result["status"] == "PREPARED", "prepare a fresh run instead of overwriting evidence"
    assert sha(run / "accepted-upstream.lock") == result["accepted_upstream_lock_sha256"]
    for relative, expected in result["prepared_source_sha256"].items():
        assert sha(run / relative) == expected, relative
    for relative, expected in result["fixture_source_sha256"].items():
        assert sha(ROOT / relative) == expected, relative

    def command(name, args, project=run, timeout=600):
        print("START", name, flush=True)
        started = datetime.datetime.now(datetime.timezone.utc).isoformat()
        proc = subprocess.run(args, cwd=project, env=environment(run, project), text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        path = run / (name + ".log")
        path.write_text(proc.stdout)
        result["checks"].append({"name": name, "command": args, "cwd": str(project),
                                 "started_utc": started, "exit": proc.returncode,
                                 "log": str(path), "log_sha256": sha(path)})
        save(run, result)
        print(proc.stdout, end="", flush=True)
        assert proc.returncode == 0, f"{name} failed: {proc.returncode}"
        return proc.stdout

    try:
        result["status"] = "RUNNING"
        result["execution_source_head"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        save(run, result)
        repositories = command("public-repository", ["mix", "hex.repo", "list"])
        assert "hexpm" in repositories and "https://repo.hex.pm" in repositories
        assert "127.0.0.1" not in repositories and "localhost" not in repositories
        for name, expected in (("core", 1), ("http", 2), ("phoenix", 4)):
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
Enum.each(deps, fn dep ->
  true = String.starts_with?(dep.opts[:dest], System.fetch_env!("MIX_DEPS_PATH") <> "/")
  {:hex, package, version, _, _, _, "hexpm", _} = lock[dep.app]
  if dep.app in [:gaoxy, :gaoxy_http, :gaoxy_http3, :gaoxy_proxy, :websock_adapter] do
    "0.5.2" = version
    true = package == if(dep.app == :websock_adapter, do: :gaoxy_websock_adapter, else: dep.app)
  else
    case accepted[dep.app] do
      nil ->
        true = {dep.app, version} in [{:hell, "0.1.2"}, {:abyss, "0.7.0"}]
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
            assert sha(ROOT / relative) == expected, relative
        for relative, expected in result["prepared_source_sha256"].items():
            if not relative.endswith("mix.lock"):
                assert sha(run / relative) == expected, relative
        assert sha(run / "accepted-upstream.lock") == result["accepted_upstream_lock_sha256"]
        result["status"] = "PASS"
        result["execution"] = "core1 / HTTP2 / Phoenix4 public Hex tests passed"
        save(run, result)
        print("PASS public Hex consumers", run, flush=True)
    except Exception as error:
        result["status"] = "FAIL"
        result["error"] = repr(error)
        save(run, result)
        raise


parser = argparse.ArgumentParser()
parser.add_argument("--execute", metavar="PREPARED_RUN", help="resolve and test only after confirmed publication")
arguments = parser.parse_args()
if arguments.execute:
    execute(arguments.execute)
else:
    prepare()
