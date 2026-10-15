ExUnit.start(autorun: false, seed: 33015, max_cases: 1)
source = File.read!("apps/gaoxy_proxy/test/managed_h2_group_accounting_test.exs")
original = """
  defp accepted(selector, original, role, cap \\\\ nil) do
    assert {:ok, result} = call(:project, [selector, original])
"""
replacement = """
  defp accepted(selector, original, role, cap \\\\ nil) do
    stats =
      case {selector, original} do
        {{:control, family}, {:gaoxy_proxy_http, pid, {:transport_handoff, ref, transport, identity, deadline}}}
        when family in [:handoff_request, :identity] ->
          # Compute only scalars before any trace, send, inspect or serialization
          # can share the original appendable binary with another process.
          {family, byte_size(identity.origin), :binary.referenced_byte_size(identity.origin),
           :erlang.external_size(pid), :erlang.external_size(ref),
           :erlang.external_size(identity.instance), deadline,
           map_size(identity), map_size(transport)}
        _ -> nil
      end
    answer = call(:project, [selector, original])
    if stats != nil, do: IO.inspect({stats, elem(answer, 0)}, label: "unshared_origin_before_actual_project")
    assert {:ok, result} = answer
"""
if not String.contains?(source, original), do: raise("diagnostic source seam drift")
source = source |> String.replace("defmodule Gaoxy.Proxy.ManagedH2GroupAccountingTest do", "defmodule Gaoxy.Proxy.ManagedH2GroupAccountingDiagnostic5Test do") |> String.replace(original, replacement)
Code.compile_string(source, "identity-diagnostic5-generated-test.exs")
result = ExUnit.run()
IO.inspect(result, label: "diagnostic5_actual_ExUnit_result")
System.halt(if result.failures == 0, do: 0, else: 2)
