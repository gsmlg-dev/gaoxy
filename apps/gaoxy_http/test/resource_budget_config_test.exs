defmodule Gaoxy.HTTP.ResourceBudgetConfigTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.ListenerSet

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "budget")
  end

  test "H2 synthetic default remains numeric without becoming an explicit cap" do
    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               protocols: [:http2],
               h2c: :prior_knowledge
             )

    assert spec.limits.max_bytes == 268_435_456
    assert spec.budget_policy.max_bytes == nil
    assert spec.budget_policy.max_active == nil
    assert {:ok, ^spec} = Gaoxy.Config.service(spec)
  end

  test "an explicit H2 value equal to the historical default stays explicit" do
    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               protocols: [:http2],
               h2c: :prior_knowledge,
               limits: %{max_bytes: 268_435_456}
             )

    assert spec.budget_policy.max_bytes == 268_435_456
    assert {:ok, ^spec} = Gaoxy.Config.service(spec)
  end

  test "HTTP ListenerSet planned and prepared provider round trips preserve omission" do
    assert {:ok, plan} =
             ListenerSet.plan(id: :budget, endpoint: {Endpoint, []}, listeners: [http: []])

    assert {:ok, [planned]} = ListenerSet.planned_services(plan)
    assert {:ok, [prepared]} = ListenerSet.prepare(plan)
    assert planned.budget_policy == prepared.budget_policy
    assert planned.budget_policy.max_bytes == nil

    assert {:ok, [^prepared]} =
             apply(Gaoxy.Activation, :validate_services, [[prepared], [planned]])
  end
end
