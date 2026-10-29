defmodule Gaoxy.Proxy.ResourceBudgetConfigTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.Router
  alias Gaoxy.Proxy.Gateway

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "budget")
  end

  defp plan(limits) do
    Gateway.compile(
      id: :budget,
      listener_sets: [
        [
          id: "web",
          endpoint: {Router, [%{target: {Endpoint, []}}]},
          listeners: [http: [limits: limits]]
        ]
      ]
    )
  end

  test "Gateway synthetic 64 MiB remains an omitted aggregate cap through plan round trips" do
    assert {:ok, compiled} = plan(%{})
    assert {:ok, [spec]} = Gateway.planned_services(compiled)
    assert spec.limits.max_bytes == 67_108_864
    assert spec.budget_policy.max_bytes == nil
    assert {:ok, ^spec} = Gaoxy.Config.service(spec)
    assert {:ok, compiled_again} = Gateway.compile(compiled)
    assert {:ok, [^spec]} = Gateway.planned_services(compiled_again)
  end

  test "an explicit Gateway cap equal to its historical default remains explicit" do
    assert {:ok, compiled} = plan(%{max_bytes: 67_108_864})
    assert {:ok, [spec]} = Gateway.planned_services(compiled)
    assert spec.budget_policy.max_bytes == 67_108_864
    assert {:ok, ^spec} = Gaoxy.Config.service(spec)
  end
end
