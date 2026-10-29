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

  defp declaration(extra \\ []) do
    Keyword.merge(
      [
        id: :budget,
        listener_sets: [
          [id: "web", endpoint: {Router, [%{target: {Endpoint, []}}]}, listeners: [http: []]]
        ]
      ],
      extra
    )
  end

  test "omitted Gateway policy normalizes once and survives reusable compilation" do
    assert {:ok, defaults} = Gaoxy.Config.validate([])
    assert {:ok, compiled} = Gateway.compile(declaration())
    assert compiled.resource_budget == defaults.resource_budget
    assert compiled.resource_budget.soft_limit == nil
    assert compiled.resource_budget.hard_limit == nil
    assert {:ok, ^compiled} = Gateway.compile(compiled)
  end

  test "Gateway ordered equal and adaptive threshold pairs use the shared normalizer" do
    for policy <- [
          %{soft_limit: 100, hard_limit: 200},
          %{soft_limit: 100, hard_limit: 100},
          %{soft_limit: nil, hard_limit: nil}
        ] do
      assert {:ok, expected} = Gaoxy.Config.validate(resource_budget: policy)
      assert {:ok, compiled} = Gateway.compile(declaration(resource_budget: policy))
      assert compiled.resource_budget == expected.resource_budget
      assert {:ok, ^compiled} = Gateway.compile(compiled)
    end
  end

  test "manual Gateway plans with the original fields retain adaptive policy" do
    assert {:ok, compiled} = Gateway.compile(declaration())

    manual = %Gateway.Plan{
      id: compiled.id,
      name: compiled.name,
      sets: compiled.sets,
      services: compiled.services,
      startup_timeout: compiled.startup_timeout
    }

    assert {:ok, ^compiled} = Gateway.compile(manual)
  end

  test "Gateway rejects malformed instance policies and contradictory provenance" do
    for policy <- [
          nil,
          %{},
          %{soft_limit: 1},
          %{hard_limit: 2},
          %{soft_limit: nil, hard_limit: 2},
          %{soft_limit: 1, hard_limit: nil},
          %{soft_limit: 3, hard_limit: 2},
          %{soft_limit: 0, hard_limit: 2},
          %{soft_limit: 1, hard_limit: 9_223_372_036_854_775_808},
          %{soft_limit: 1, hard_limit: 2, unknown: true},
          %{soft_limit: 1, hard_limit: 2, provenance: %{source: :adaptive}}
        ] do
      assert {:error, :invalid_resource_budget} =
               Gateway.compile(declaration(resource_budget: policy))
    end
  end

  test "embedded explicit ListenerSet instance policy is rejected even when equal to Gateway policy" do
    policy = %{soft_limit: 100, hard_limit: 200}
    [listener] = declaration()[:listener_sets]
    listener = Keyword.put(listener, :resource_budget, policy)
    assert {:ok, listener_plan} = Gaoxy.HTTP.ListenerSet.plan(listener)

    for input <- [listener, listener_plan], top <- [[], [resource_budget: policy]] do
      assert {:error, :listener_set_resource_budget_requires_gateway_policy} =
               Gateway.compile(declaration(Keyword.put(top, :listener_sets, [input])))
    end
  end

  test "embedded omitted and adaptive ListenerSets share the top-level Gateway policy" do
    [listener] = declaration()[:listener_sets]
    adaptive = %{soft_limit: nil, hard_limit: nil}

    assert {:ok, adaptive_plan} =
             Gaoxy.HTTP.ListenerSet.plan(Keyword.put(listener, :resource_budget, adaptive))

    policy = %{soft_limit: 100, hard_limit: 200}

    for input <- [listener, Keyword.put(listener, :resource_budget, adaptive), adaptive_plan] do
      assert {:ok, compiled} =
               Gateway.compile(declaration(listener_sets: [input], resource_budget: policy))

      assert compiled.resource_budget.soft_limit == 100
      assert compiled.resource_budget.hard_limit == 200
      assert hd(compiled.sets).listener.resource_budget.soft_limit == nil
      assert {:ok, ^compiled} = Gateway.compile(compiled)
    end
  end

  test "one pure runtime child receives Gateway policy and the complete planned services" do
    policy = %{soft_limit: 100, hard_limit: 200}
    assert {:ok, compiled} = Gateway.compile(declaration(resource_budget: policy))
    assert {:ok, planned} = Gateway.planned_services(compiled)

    context = %{
      plan: compiled,
      planned: planned,
      instance: :entry_runtime,
      owners: :entry_owners,
      host: []
    }

    assert {:ok, {_, children}} = Gaoxy.Proxy.Gateway.RuntimeSupervisor.init(context)
    core = Enum.filter(children, &match?(%{start: {Gaoxy, :start_link, [_]}}, &1))
    assert [%{start: {Gaoxy, :start_link, [options]}}] = core
    assert options[:resource_budget] == compiled.resource_budget
    assert options[:services] == planned
    assert options[:activation] == :deferred
  end

  test "Gateway instance policy preserves explicit service caps and distinct quotas" do
    limits = %{
      max_active: 128,
      max_bytes: 67_108_864,
      max_connections: 100,
      max_requests: 200,
      max_streams: 300
    }

    [listener] = declaration()[:listener_sets]
    listener = Keyword.put(listener, :listeners, http: [limits: limits])

    assert {:ok, compiled} =
             Gateway.compile(
               declaration(
                 listener_sets: [listener],
                 resource_budget: %{soft_limit: 100, hard_limit: 200}
               )
             )

    assert {:ok, [spec]} = Gateway.planned_services(compiled)
    assert Map.take(spec.budget_policy, Map.keys(limits)) == limits
    assert {:ok, recompiled} = Gateway.compile(compiled)
    assert {:ok, [^spec]} = Gateway.planned_services(recompiled)
  end
end
