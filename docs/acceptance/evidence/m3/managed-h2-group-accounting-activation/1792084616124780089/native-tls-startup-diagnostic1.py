"""Diagnostic only: unchanged canonical browser with actual pump trace capture."""
from pathlib import Path
import hashlib
import json
import os
import signal
import subprocess
import sys
import time

R = Path(__file__).resolve().parents[6]
E = Path(__file__).resolve().parent
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

DIAGNOSTIC = r'''
defmodule GroupNativeTLSDiagnostic do
  alias Gaoxy.Proxy.ManagedH2GroupAccounting, as: A
  def install(directory) do
    tracer = spawn(fn -> loop(directory) end)
    {:module, A} = Code.ensure_loaded(A)
    :erlang.trace_pattern({A, :validate, 2}, [{[:pump, :"$1"], [], [{:return_trace}]}], [:local])
    :erlang.trace(:all, true, [:call, :set_on_spawn, {:tracer, tracer}])
    :erlang.trace(tracer, false, [:call])
    :ok
  end
  defp shape(v) when is_binary(v), do: %{type: "binary", bytes: byte_size(v), backing: :binary.referenced_byte_size(v)}
  defp shape(v) when is_list(v), do: %{type: "list", length: length(v)}
  defp shape(v) when is_map(v), do: %{type: "map", keys: Enum.map(Map.keys(v), &inspect/1)}
  defp shape(v) when is_tuple(v), do: %{type: "tuple", arity: tuple_size(v)}
  defp shape(v) when is_function(v), do: %{type: "function"}
  defp shape(v) when is_atom(v), do: %{type: "atom"}
  defp shape(v) when is_integer(v), do: %{type: "integer"}
  defp shape(_), do: %{type: "other"}
  defp owner(exchange) do
    case exchange.transport_state do
      {pid, id, _token} ->
        try do
          state = :sys.get_state(pid, 1_000)
          %{owner: inspect(pid), stream: id, same_ssl: state.ssl === exchange.ssl,
            same_gate: state.gate === exchange.gate, secure: state.secure}
        catch
          :exit, reason -> %{owner: inspect(pid), unavailable: inspect(reason, limit: 4)}
        end
      _ -> nil
    end
  end
  defp loop(directory) do
    receive do
      {:trace, pump, :call, {A, :validate, [:pump, source]}} ->
        original = A.validate(:pump, source)
        ssl_only = %{source | exchange: %{source.exchange | ssl: nil}}
        value = %{kind: "ACTUAL_NATIVE_TLS_PUMP_VALIDATION_DIAGNOSTIC", pump: inspect(pump),
          original_result: inspect(original), ssl_nil_only_result: inspect(A.validate(:pump, ssl_only)),
          metadata_count: length(source.exchange.ssl || []),
          metadata_shapes: Enum.map(source.exchange.ssl || [], fn {k,v} -> %{key: inspect(k), shape: shape(v)} end),
          actual_native_owner: owner(source.exchange),
          actual_vm: %{root: List.to_string(:code.root_dir()), erts: List.to_string(:erlang.system_info(:version)),
            otp: List.to_string(:erlang.system_info(:otp_release)), ssl: List.to_string(:code.which(:ssl))},
          limits_unchanged: true, acceptance: false}
        File.write!(Path.join(directory, "actual-pump-tls-validation.jsonl"), JSON.encode!(value) <> "\n", [:append])
        loop(directory)
      _ -> loop(directory)
    end
  end
end
'''

if "--inner" in sys.argv:
    sys.path.insert(0, str(R / "integration/http_fetch_contract"))
    import managed_h2_group_browser as browser
    browser.HOST = DIAGNOSTIC + browser.HOST.replace(
        "FixedManagedH2Host.run(evidence)",
        "GroupNativeTLSDiagnostic.install(evidence)\nFixedManagedH2Host.run(evidence)",
    )
    sys.argv.remove("--inner")
    browser.main()
    raise SystemExit(0)

sources = json.loads((E / "postactivation-full-review-candidate1.json").read_text())["source_manifest"]
extra = ["apps/gaoxy_http/lib/gaoxy/http/connection.ex", "apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex", "apps/gaoxy_http/lib/gaoxy/http/http2/transport.ex"]
snapshot = lambda: {p: sha(R / p) for p in dict.fromkeys([*sources, *extra])}
stamp = str(time.time_ns())
directory = E / ("native-tls-startup-diagnostic1-" + stamp)
log = E / (directory.name + ".log")
command = ["/tmp/gaoxy-m3-h2-soak-venv/bin/python", "-B", str(Path(__file__).resolve()), "--inner", "--evidence", str(directory)]
before = snapshot()
started = time.monotonic()
timed_out = False
with log.open("xb") as output:
    process = subprocess.Popen(command, cwd=R, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
    try:
        actual = process.wait(timeout=600)
    except subprocess.TimeoutExpired:
        timed_out = True
        os.killpg(process.pid, signal.SIGTERM)
        try:
            actual = process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            actual = process.wait(timeout=10)
after = snapshot()
capture = directory / "actual-pump-tls-validation.jsonl"
rows = [json.loads(line) for line in capture.read_text().splitlines()] if capture.is_file() else []
report = dict(kind="DIAGNOSTIC_COMMAND_NOT_ACCEPTANCE", command=command, actual_exit=actual,
              process_joined=process.poll() is not None, timed_out=timed_out,
              elapsed_ms=round((time.monotonic() - started) * 1000), source_before=before,
              source_after=after, source_stable=before == after, log=str(log.relative_to(R)),
              log_sha256=sha(log), capture=str(capture.relative_to(R)),
              capture_sha256=sha(capture) if capture.is_file() else None, captured=len(rows),
              collector_sha256=sha(Path(__file__)), acceptance=False, astra="2/2 exhausted unchanged")
with log.with_suffix(".json").open("x") as output:
    json.dump(report, output, indent=2)
    output.write("\n")
print(json.dumps({k:v for k,v in report.items() if k not in ("source_before", "source_after")}, indent=2))
print(json.dumps(rows, indent=2))
assert report["process_joined"] and report["source_stable"] and not timed_out
assert actual == 1 and rows
assert any(row["original_result"] == "{:error, :invalid_group_accounting}" and row["ssl_nil_only_result"] == ":ok" for row in rows)
