#!/usr/bin/env python3
"""Parent-owned, additive public HTTP 0.21.10 qualification; no activation claim."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time
import traceback

ROOT = Path(__file__).resolve().parents[2]
DESIGN = "docs/designs/m3-managed-h2-preparation.md"
DESIGN_SHA = "1b4e9e24a75aa44529074fba4fa2f3f3e29c4c9f97e5870d5ca309f40ecd1865"
PACKAGES = ("http_core", "http_runtime", "http_fetch", "http_web_socket",
            "ex_ssl", "elixir_quic", "elixir_quic_http3")
HISTORICAL = {
    "integration/http_fetch_contract/h2_0214_qualification.py":
        "2dc5357e927abd2f60dfd5b3526968a478e9fca88dd4af60d7ccfa13e479eb86",
    "integration/http_fetch_contract/h2_0214_functional_supplement.exs":
        "06073b85be1dcc13995c793e27ee4ec9b8736cf4de996543618ecf98562d6f5e",
    "integration/http_fetch_contract/h2_functional_supplement.exs":
        "89cd7237a5864d86e9ffbd7f5f323a275ec9cad1d36cd4f03fc8881842cccbef",
    "integration/http_fetch_contract/h2_functional_supplement_peer.py":
        "b1bcff8b19eba8c7bccb315ecd3ee66be860816128e76b2a15b5a36e0968f170",
    "integration/http_fetch_contract/managed_transport_probe.exs":
        "0e266d6c278682e23d2611d053c8d155bb19d4354c6a5dfa2f411dc177c49520",
    "integration/http_fetch_contract/pooled_completion_probe.exs":
        "f681723ff58754cb6169d0b42fb681a8439eeaa6c7ec7e94c752894405ce1e30",
    "integration/http_fetch_contract/upstream_peer.py":
        "f2e40b0e72362f06b4c933b14f45d49e768b2133bee4281c4241bbd122d9b95f",
    "integration/http_fetch_contract/managed_peer.py":
        "319e9c9f2832ddf2ab9cc84aedd519bfe33f36e2152d24bb47bf5fcde8169d79",
    "docs/plans/m3-h2-0.21.3-functional-supplement.md":
        "25fdfb876f7e83f65b97414816a6a82c258ec8f789f0d0eb7f4e07f627ad7270",
}
CASES = ["TLS98_LATE", "TLS98_EARLY", "TLS100_ABORT", "TLS100_DEADLINE",
         "H2C98_LATE", "H2C98_EARLY", "H2C100_ABORT", "H2C100_DEADLINE"]
GATES = [
    ("managed39", "integration/http_fetch_contract/managed_transport_probe.exs", 39),
    ("completion16", "integration/http_fetch_contract/pooled_completion_probe.exs", 16),
    ("supplement8", "integration/http_fetch_contract/h2_02110_functional_supplement.exs", 8),
]

# This wrapper runs in each actual probe VM, never in a substitute identity VM.
WRAPPER = r'''
defmodule HTTPFetch02110Identity do
  @packages ~w(http_core http_runtime http_fetch http_web_socket ex_ssl elixir_quic elixir_quic_http3)a
  def digest(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
  def file(path), do: %{path: path, sha256: digest(File.read!(path))}
  def capture do
    applications = Enum.map(@packages, fn app ->
      loaded = Application.load(app)
      true = loaded in [:ok, {:error, {:already_loaded, app}}]
      "0.21.10" = version = to_string(Application.spec(app, :vsn))
      app_path = :code.where_is_file(~c"#{app}.app") |> to_string()
      modules = Enum.map(Application.spec(app, :modules), fn module ->
        Code.ensure_loaded!(module)
        {^module, bytes, path} = :code.get_object_code(module)
        path = to_string(path)
        ^bytes = File.read!(path)
        {:ok, {^module, md5}} = :beam_lib.md5(bytes)
        ^md5 = module.module_info(:md5)
        compile_source = module.module_info(:compile) |> Keyword.fetch!(:source) |> to_string()
        [_prefix, relative] = String.split(compile_source, "/deps/#{app}/")
        source = Path.expand(Path.join("deps/#{app}", relative))
        true = String.starts_with?(source, Path.expand("deps/#{app}") <> "/")
        source_hash = digest(File.read!(source))
        compile_source_hash =
          if File.regular?(compile_source), do: digest(File.read!(compile_source)), else: nil
        true = is_nil(compile_source_hash) or compile_source_hash == source_hash
        %{module: to_string(module), beam_path: path, beam_sha256: digest(bytes),
          loaded_code_md5: Base.encode16(md5, case: :lower),
          disk_code_md5: Base.encode16(md5, case: :lower),
          source: source, source_sha256: source_hash,
          compile_source: compile_source, compile_source_sha256: compile_source_hash}
      end)
      true = modules != []
      %{application: to_string(app), version: version, app: file(app_path), modules: modules}
    end)
    mapped = File.read!("/proc/self/maps") |> String.split("\n", trim: true)
    paths = Enum.flat_map(mapped, fn line ->
      case String.split(line, ~r/\s+/, parts: 6) do
        [_, _, _, _, _, "/" <> _ = path] ->
          if String.ends_with?(path, " (deleted)") do
            true = String.starts_with?(path, "/memfd:vmem")
            []
          else
            [path]
          end
        _ -> []
      end
    end) |> Enum.uniq() |> Enum.sort()
    files = Enum.map(paths, &file/1)
    true = Enum.any?(paths, &String.ends_with?(&1, "/crypto.so"))
    true = Enum.any?(paths, &String.contains?(&1, "/libcrypto.so"))
    %{applications: applications, mapped_files: files,
      beam_executable: file(File.read_link!("/proc/self/exe")),
      pid: System.pid(), elixir: System.version(), otp: System.otp_release(),
      erts: to_string(:erlang.system_info(:version)), architecture: to_string(:erlang.system_info(:system_architecture)),
      native_claim: "Actual loaded file identity; excludes mutable JIT/anonymous memory; no memory certification"}
  end
  def record(path), do: File.write!(path, JSON.encode!(capture()) <> "\n")
end
[before_path, after_path, runner | args] = System.argv()
System.argv(args)
for app <- [:http_core, :http_runtime, :http_fetch] do
  {:ok, _} = Application.ensure_all_started(app)
end
HTTPFetch02110Identity.record(before_path)
result = try do
  Code.require_file(runner)
  %{status: "OK"}
rescue
  error -> %{status: "FAIL", failure: Exception.format(:error, error, __STACKTRACE__)}
catch
  kind, reason -> %{status: "FAIL", failure: Exception.format(kind, reason, __STACKTRACE__)}
end
post = try do
  HTTPFetch02110Identity.record(after_path)
  %{status: "OK"}
rescue
  error -> %{status: "FAIL", failure: Exception.format(:error, error, __STACKTRACE__)}
catch
  kind, reason -> %{status: "FAIL", failure: Exception.format(kind, reason, __STACKTRACE__)}
end
IO.puts("H202110_WRAPPER " <> JSON.encode!(%{primary: result, post_identity: post}))
if result.status != "OK" or post.status != "OK", do: System.halt(1)
'''

PEER_IDENTITY = r'''
import hashlib, importlib.metadata, json, shutil, ssl, subprocess, sys
from pathlib import Path
import h2.config, h2.connection, h2.events, hpack, hyperframe
executable = Path(sys.executable).resolve()
openssl = Path(shutil.which("openssl")).resolve()
print(json.dumps({"python": str(executable), "python_sha256": hashlib.sha256(executable.read_bytes()).hexdigest(),
 "python_version": sys.version, "packages": {p: importlib.metadata.version(p) for p in ("h2", "hpack", "hyperframe")},
 "package_sources": {p: {"path": m.__file__, "sha256": hashlib.sha256(Path(m.__file__).read_bytes()).hexdigest()}
                     for p, m in (("h2", h2), ("hpack", hpack), ("hyperframe", hyperframe))},
 "python_openssl": ssl.OPENSSL_VERSION, "openssl": str(openssl),
 "openssl_sha256": hashlib.sha256(openssl.read_bytes()).hexdigest(),
 "openssl_version": subprocess.run([str(openssl), "version", "-a"], check=True, capture_output=True, text=True, timeout=10).stdout}))
'''


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1048576), b""):
            digest.update(block)
    return digest.hexdigest()


def write(path, value):
    with Path(path).open("x") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def inventory():
    paths = {ROOT / p for p in HISTORICAL}
    paths.update(ROOT / p for p in (DESIGN, "mix.lock", "mix.exs", "flake.nix", "flake.lock",
                                  "integration/h2_gateway/requirements.txt"))
    paths.update(Path(__file__).parent / p for p in ("h2_02110_qualification.py", "h2_02110_functional_supplement.exs"))
    for package in PACKAGES:
        paths.update(p for p in (ROOT / "deps" / package).rglob("*") if p.is_file())
        build = ROOT / "_build/test/lib" / package
        for directory in (build / "ebin", build / "priv"):
            if directory.exists():
                paths.update(p for p in directory.rglob("*") if p.is_file())
    paths.update(ROOT.glob("apps/*/lib/**/*.ex"))
    paths.update(ROOT.glob("apps/*/mix.exs"))
    paths.update(ROOT.glob("config/*.exs"))
    return {str(p.relative_to(ROOT)): {"sha256": sha(p), "bytes": p.stat().st_size}
            for p in sorted(paths)}


def snapshot(directory, state):
    directory.mkdir()
    for name in state:
        # Build identities have hashes; source snapshots retain reviewable inputs.
        if name.startswith("_build/"):
            continue
        target = directory / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, target)
        require(sha(target) == state[name]["sha256"], "source changed during snapshot: " + name)


def group_members(group):
    members = []
    for path in Path("/proc").glob("[0-9]*/stat"):
        try:
            stat = path.read_text().rsplit(")", 1)[1].split()
            # state, ppid, pgrp, session; zombies have already stopped execution.
            if int(stat[2]) == group and stat[0] != "Z":
                members.append(int(path.parent.name))
        except (FileNotFoundError, ProcessLookupError):
            continue
    return sorted(members)


def run(command, directory, name, environment, timeout):
    receipt = {"command": command, "cwd": str(ROOT), "status": "NOT RUN", "timeout_seconds": timeout,
               "environment": {key: environment.get(key) for key in
                               ("ERL_FLAGS", "MIX_ENV", "HTTP_FETCH_PEER_PYTHON", "HTTP_FETCH_PROBE_LIBRARY", "IN_NIX_SHELL")}}
    log_path = directory / (name + ".log")
    process = None
    started = time.monotonic()
    try:
        with log_path.open("xb") as log:
            process = subprocess.Popen(command, cwd=ROOT, env=environment, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            receipt["process_group"] = process.pid
            try:
                receipt["exit"] = process.wait(timeout=timeout)
                receipt["timed_out"] = False
            except subprocess.TimeoutExpired:
                receipt["timed_out"] = True
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=5)
                receipt["exit"] = process.returncode
            remaining = group_members(process.pid)
            receipt["remaining_before_cleanup"] = remaining
            if remaining:
                os.killpg(process.pid, signal.SIGKILL)
                deadline = time.monotonic() + 5
                while group_members(process.pid) and time.monotonic() < deadline:
                    time.sleep(0.05)
            receipt["remaining_after_cleanup"] = group_members(process.pid)
            receipt["group_shutdown_confirmed"] = not receipt["remaining_after_cleanup"]
            receipt["status"] = ("PASS_COMMAND" if receipt["exit"] == 0 and not receipt["timed_out"] and not remaining
                                 else "FAIL") if receipt["group_shutdown_confirmed"] else "BLOCKED_HANDOFF"
    except OSError as error:
        receipt.update(status="BLOCKED_ENV", failure=str(error))
    finally:
        receipt["elapsed_seconds"] = time.monotonic() - started
        if log_path.exists():
            receipt.update(log=log_path.name, log_sha256=sha(log_path), log_bytes=log_path.stat().st_size)
        write(directory / (name + "-command.json"), receipt)
    return receipt


def records(log, tag):
    return [json.loads(line.split(tag + " ", 1)[1]) for line in log.splitlines() if line.startswith(tag + " ")]


def identity_check(before, after):
    require(before["pid"] == after["pid"], "identity came from different VMs")
    require(before["applications"] == after["applications"], "loaded cohort changed")
    require({row["application"] for row in before["applications"]} == set(PACKAGES), "partial cohort")
    for identity in (before, after):
        for app in identity["applications"]:
            require(app["version"] == "0.21.10" and app["modules"], "unqualified package")
            require(sha(app["app"]["path"]) == app["app"]["sha256"], "application identity changed")
            for row in app["modules"]:
                require(row["loaded_code_md5"] == row["disk_code_md5"], "loaded BEAM mismatch")
                require(sha(row["beam_path"]) == row["beam_sha256"], "BEAM changed")
                require(sha(row["source"]) == row["source_sha256"], "loaded source changed")
                if row["compile_source_sha256"] is not None:
                    require(sha(row["compile_source"]) == row["compile_source_sha256"] == row["source_sha256"],
                            "original compile source changed or differs from current source")
        for row in identity["mapped_files"] + [identity["beam_executable"]]:
            require(sha(row["path"]) == row["sha256"], "native file changed")
    original = {(row["path"], row["sha256"]) for row in before["mapped_files"]}
    final = {(row["path"], row["sha256"]) for row in after["mapped_files"]}
    require(original <= final, "loaded native identity lost or changed")


def evaluate(name, expected, log, directory, peer_identity):
    wrappers = records(log, "H202110_WRAPPER")
    require(wrappers == [{"primary": {"status": "OK"}, "post_identity": {"status": "OK"}}], "wrapper failed or incomplete")
    before = json.loads((directory / (name + "-loaded-before.json")).read_text())
    after = json.loads((directory / (name + "-loaded-after.json")).read_text())
    identity_check(before, after)
    if name != "supplement8":
        marker = "MANAGED_CASE:" if name == "managed39" else "PUBLIC_CASE:"
        chunks = log.split(marker)[1:]
        names = [re.search(r'case:\s*"([^"\n]+)"', chunk).group(1) for chunk in chunks]
        require(len(names) == len(set(names)) == expected, "zero, partial or duplicate cases")
        require(all(re.search(r"result:\s*:pass\b", chunk) for chunk in chunks), "nonpassing case")
        final = "MANAGED_PROBE_PASS profile=full cases=39;" if name == "managed39" else "PUBLIC_PROBE_PASS cases=16;"
        require(log.count(final) == 1, "missing full-run terminal")
        require(not re.search(r"result:\s*:skip(?:ped)?\b", log), "skipped case")
        cleanup = "MANAGED_CLEANUP:" if name == "managed39" else "PUBLIC_PEER_STOPPED:"
        require(log.count(cleanup) > 0, "missing public cleanup evidence")
        return {"status": "PASS", "executed": expected, "failed": 0, "skipped": 0,
                "cases": names, "cleanup_records": log.count(cleanup), "loaded_identity_stable": True}
    summaries = records(log, "H2_FUNCTIONAL_SUMMARY")
    require(len(summaries) == 1, "missing supplement summary")
    summary = summaries[0]
    cases = records(log, "H2_FUNCTIONAL_CASE")
    require([case["case"] for case in cases] == summary["cases"] == CASES, "partial supplement")
    require(summary["status"] == "PASS" and summary["executed"] == summary["peer_shutdowns"] == 8,
            "supplement failed or unjoined peer")
    require(summary["tls"] == summary["h2c"] == 4 and summary["skipped"] == summary["failed"] == summary["exit"] == 0,
            "invalid supplement counts")
    require(summary["source_stable"] and summary["source_before"] == summary["source_after"], "supplement source drift")
    require(summary["python_stable"] and summary["python_identity"] == {
        key: peer_identity[key] for key in ("python", "python_sha256", "python_version", "packages", "python_openssl")},
        "peer identity mismatch")
    artifacts = directory / "supplement-cases"
    require(json.loads((artifacts / "results.json").read_text()) == summary, "summary artifact mismatch")
    for case in cases:
        require(json.loads((artifacts / (case["case"] + ".json")).read_text()) == case, "case artifact mismatch")
        require(case["status"] == "PASS" and not case["cleanup_errors"] and not case["forced_cleanup"], "case cleanup failed")
        require(case["peer_shutdown"] and case["peer_exit"] == 0 and case["peer_port_down"] == ":normal", "peer not joined")
        require(case["promise_acquired"] and case["promise_await"] == "resolved", "original promise not resolved")
        require(case["cleanup_deadline_ms"] - case["oracle_deadline_ms"] == 5000, "fixture deadline changed")
        events = case["events"]
        require(len(events) <= 128 and len(case["controls"]) <= 3, "peer budget exceeded")
        require(not any(event["event"] == "failure" for event in events), "peer failure")
        for event_name in ("accept", "request", "reset", "closed", "stopped"):
            require(sum(event["event"] == event_name for event in events) == 1, "missing/duplicate " + event_name)
        stopped = next(event for event in events if event["event"] == "stopped")
        closed = next(event for event in events if event["event"] == "closed")
        require(stopped["live_threads"] == 0 and stopped["accepts"] == stopped["requests"] == stopped["resets"] == 1
                and not stopped["failed"] and closed["owned_shutdown"], "owned physical close/join failed")
        operations = {row["operation"]: row for row in case["operations"]}
        parser = "98_" in case["case"]
        reason = ":invalid_headers_transition" if parser else (":aborted" if "ABORT" in case["case"] else ":request_timeout")
        require(operations["exact_terminal_error"]["result"] == reason, "terminal reason changed")
        require(operations["exactly_one_terminal_error_and_normal_stream_down"]["result"] == ":ok", "stream terminal failed")
        if parser:
            require(operations["original_completion_after_reader"]["result"] == operations["original_completion_repeated"]["result"] == ":ok",
                    "original completion failed")
            key = "original_completion_before_reader" if "LATE" in case["case"] else "reader_attached_and_sentinel_acked"
            require(operations[key]["result"] == ("{:error, :cleanup_pending}" if "LATE" in case["case"] else ":ok"), "reader barrier changed")
        else:
            require(operations["unsupported_completion"]["result"] == "{:error, {:unsupported_completion, :redirect}}", "unsupported completion changed")
        if case["protocol"] == "tls":
            tls = [event for event in events if event["event"] == "tls"]
            require(len(tls) == 1 and tls[0]["alpn"] == "h2" and "verify_peer" in case["options"], "TLS fallback/unverified peer")
            require(not Path(case["ready"]["ca"]).parent.exists(), "TLS fixture cleanup failed")
    return {"status": "PASS", "executed": 8, "tls": 4, "h2c": 4, "failed": 0, "skipped": 0,
            "cases": CASES, "peer_shutdowns": 8, "loaded_identity_stable": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", required=True, type=Path)
    args = parser.parse_args()
    directory = args.evidence.resolve()
    directory.parent.mkdir(parents=True, exist_ok=True)
    directory.mkdir()  # Refuse stale evidence rather than overwriting a prior run.
    environment = os.environ.copy()
    environment.pop("HTTP_FETCH_PROBE_LIBRARY", None)
    peer_python = environment.get("HTTP_FETCH_PEER_PYTHON", "/tmp/gaoxy-m3-h2-soak-venv/bin/python")
    environment["HTTP_FETCH_PEER_PYTHON"] = peer_python
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    before = None
    results = {name: {"status": "NOT RUN", "executed": 0} for name, _, _ in GATES}
    summary = {"status": "FAIL", "qualification": "Public functional behavior only; no H2 activation or complete M3 acceptance",
               "argv": sys.argv, "cwd": str(ROOT), "commands": [], "gates": results}
    try:
        require(Path.cwd().resolve() == ROOT, "BLOCKED_ENV: invoke from repository root")
        require(environment.get("ERL_FLAGS") == "+S 2:2" and environment.get("MIX_ENV") == "test", "BLOCKED_ENV: noncanonical runtime flags")
        tools = {name: shutil.which(name) for name in ("unbuffer", "mix", "erl", "openssl", "git")}
        require(all(tools.values()), "BLOCKED_ENV: required tools unavailable")
        require(all(str(Path(tools[name]).resolve()).startswith("/nix/store/") for name in ("unbuffer", "mix", "erl", "openssl")),
                "BLOCKED_ENV: tools are outside canonical Nix environment")
        summary["tools"] = {name: {"path": str(Path(path).resolve()), "sha256": sha(path)} for name, path in tools.items()}
        before = inventory()
        write(directory / "source-before.json", before)
        snapshot(directory / "source-snapshots-before", before)
        require(before[DESIGN]["sha256"] == DESIGN_SHA, "immutable design changed")
        require(before["mix.lock"]["sha256"] == "c93b608b77c457e4324430544c1acc2b384ee21e1a2b8ab528bad248ac666cb6", "cohort lock changed")
        require(all(before[path]["sha256"] == expected for path, expected in HISTORICAL.items()), "historical input changed")
        source = run([tools["git"], "rev-parse", "HEAD"], directory, "git-head", environment, 10)
        summary["commands"].append(source)
        require(source["status"] == "PASS_COMMAND", "source identity command failed")
        summary["head"] = (directory / "git-head.log").read_text().strip()
        source = run([tools["git"], "status", "--porcelain=v1", "--untracked-files=all"], directory, "git-status", environment, 10)
        summary["commands"].append(source)
        require(source["status"] == "PASS_COMMAND", "source inventory command failed")
        peer = run([peer_python, "-B", "-c", PEER_IDENTITY], directory, "peer-environment", environment, 30)
        summary["commands"].append(peer)
        require(peer["status"] == "PASS_COMMAND", "BLOCKED_ENV: peer Python/h2/OpenSSL qualification failed")
        peer_identity = json.loads((directory / "peer-environment.log").read_text())
        require(peer_identity["packages"] == {"h2": "4.3.0", "hpack": "4.1.0", "hyperframe": "6.1.0"}, "BLOCKED_ENV: unpinned peer packages")
        write(directory / "peer-identity.json", peer_identity)
        summary["peer_identity"] = peer_identity
        for name, runner, expected in GATES:
            command = [tools["unbuffer"], tools["mix"], "run", "--no-compile", "--no-deps-check", "--no-start", "-e", WRAPPER, "--",
                       str(directory / (name + "-loaded-before.json")), str(directory / (name + "-loaded-after.json")), runner]
            if name == "supplement8":
                command.extend(["--evidence", str(directory / "supplement-cases")])
            receipt = run(command, directory, name, environment, 600)
            summary["commands"].append(receipt)
            log = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", (directory / (name + ".log")).read_text(errors="replace"))
            marker = "H2_FUNCTIONAL_CASE " if name == "supplement8" else ("MANAGED_CASE:" if name == "managed39" else "PUBLIC_CASE:")
            results[name] = {"status": receipt["status"], "executed": log.count(marker), "expected": expected, "actual_exit": receipt.get("exit")}
            require(receipt["status"] == "PASS_COMMAND", name + " command did not pass")
            try:
                evaluated = evaluate(name, expected, log, directory, peer_identity)
                require(inventory() == before, "frozen source/build changed during " + name)
                results[name] = evaluated
            except Exception as error:
                results[name].update(status="FAIL", failure=str(error))
                raise
        require(sha(peer_identity["python"]) == peer_identity["python_sha256"] and sha(peer_identity["openssl"]) == peer_identity["openssl_sha256"], "peer tools changed")
        summary["status"] = "PASS"
    except Exception as error:
        summary["failure"] = str(error)
        summary["traceback"] = traceback.format_exc()
        if any(row.get("status") == "BLOCKED_HANDOFF" for row in summary["commands"]):
            summary["status"] = "BLOCKED_HANDOFF"
        elif "BLOCKED_ENV" in str(error):
            summary["status"] = "BLOCKED_ENV"
    finally:
        try:
            after = inventory()
            write(directory / "source-after.json", after)
            summary["source_stable"] = before is not None and before == after
            if before is not None:
                snapshot(directory / "source-snapshots-after", after)
            if not summary["source_stable"] and summary["status"] == "PASS":
                summary.update(status="FAIL", failure="source/build drift")
        except Exception:
            summary.update(status="FAIL", source_stable=False, source_after_failure=traceback.format_exc())
        summary["gates"] = results
        summary["executed"] = sum(row["executed"] for row in results.values())
        summary["expected"] = 63
        summary["exit"] = 0 if summary["status"] == "PASS" else 1
        summary["artifacts"] = [{"path": str(path.relative_to(directory)), "sha256": sha(path), "bytes": path.stat().st_size}
                                for path in sorted(directory.rglob("*")) if path.is_file()]
        write(directory / "qualification.json", summary)
        print("H202110_QUALIFICATION " + json.dumps({key: summary[key] for key in ("status", "executed", "expected", "exit")}))
    return summary["exit"]


if __name__ == "__main__":
    sys.exit(main())
