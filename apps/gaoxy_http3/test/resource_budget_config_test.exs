defmodule Gaoxy.HTTP.HTTP3.ResourceBudgetConfigTest do
  use ExUnit.Case, async: true
  @moduletag :unit

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "budget")
  end

  defp options(extra \\ []),
    do: [endpoint: {Endpoint, []}, tls: %{certfile: "cert", keyfile: "key"}] ++ extra

  test "H3 synthetic default and legacy 64 retain omitted policy through core normalization" do
    assert {:ok, spec} = Gaoxy.HTTP.HTTP3.service_spec(options())
    assert spec.limits.max_bytes == 16_777_216
    assert spec.limits.max_active == 64
    assert spec.budget_policy.max_bytes == nil
    assert spec.budget_policy.max_active == nil
    assert {:ok, ^spec} = Gaoxy.Config.service(spec)
  end

  test "explicit H3 values equal to its historical defaults remain administrator caps" do
    assert {:ok, spec} =
             Gaoxy.HTTP.HTTP3.service_spec(
               options(limits: %{max_bytes: 16_777_216, max_active: 64})
             )

    assert spec.budget_policy.max_bytes == 16_777_216
    assert spec.budget_policy.max_active == 64
    assert {:ok, ^spec} = Gaoxy.Config.service(spec)
  end

  test "H3 accepts a synthetic Gateway transport profile without an aggregate cap" do
    assert {:ok, spec} =
             Gaoxy.HTTP.HTTP3.service_spec(options(limits: %{protocol_max_bytes: 67_108_864}))

    assert spec.limits.max_bytes == 67_108_864
    assert spec.budget_policy.max_bytes == nil
    assert {:ok, ^spec} = Gaoxy.Config.service(spec)
  end
end
