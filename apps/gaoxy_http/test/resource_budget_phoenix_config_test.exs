defmodule Gaoxy.HTTP.ResourceBudgetPhoenixConfigTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.ListenerSet

  defmodule Endpoint do
    def init(_), do: raise("pure planning must not initialize the endpoint")
    def call(_, _), do: raise("pure planning must not dispatch a request")
  end

  defp listeners do
    [
      http: [],
      https: [certfile: "cert.pem", keyfile: "key.pem"],
      http3: [ip: {127, 0, 0, 1}, port: 0, certfile: "cert.pem", keyfile: "key.pem"]
    ]
  end

  defp declaration(extra \\ []) do
    Keyword.merge([id: :budget, endpoint: {Endpoint, []}, listeners: listeners()], extra)
  end

  defp endpoint_plan(extra \\ []) do
    config =
      Keyword.merge([http: [], https: listeners()[:https], http3: listeners()[:http3]], extra)

    assert [%{start: {ListenerSet, :start_link, [options]}}] =
             Gaoxy.PhoenixAdapter.child_specs(Endpoint, config)

    options[:plan]
  end

  test "mixed listeners have one adaptive instance policy and stable reusable planning" do
    assert {:ok, defaults} = Gaoxy.Config.validate([])
    assert {:ok, plan} = ListenerSet.plan(declaration())
    assert plan.resource_budget == defaults.resource_budget
    assert plan.resource_budget.soft_limit == nil
    assert plan.resource_budget.hard_limit == nil
    assert Keyword.keys(plan.listeners) == [:http, :https, :http3]

    assert Enum.all?(plan.listeners, fn {_, options} ->
             not Keyword.has_key?(options, :resource_budget)
           end)

    assert {:ok, ^plan} = ListenerSet.plan(plan)
  end

  test "public Plan structs constructed with the original fields retain adaptive defaults" do
    input = %Gaoxy.HTTP.ListenerSet.Plan{
      id: :budget,
      target: {:endpoint, Endpoint, []},
      listeners: listeners(),
      service_ids: %{}
    }

    assert {:ok, expected} = ListenerSet.plan(declaration())
    assert {:ok, ^expected} = ListenerSet.plan(input)
  end

  test "explicit ordered or adaptive threshold pairs use the shared pure normalizer" do
    for policy <- [
          %{soft_limit: 100, hard_limit: 200},
          %{soft_limit: 100, hard_limit: 100},
          %{soft_limit: nil, hard_limit: nil}
        ] do
      assert {:ok, normalized} = Gaoxy.Config.validate(resource_budget: policy)
      assert {:ok, plan} = ListenerSet.plan(declaration(resource_budget: policy))
      assert plan.resource_budget == normalized.resource_budget
      assert {:ok, ^plan} = ListenerSet.plan(plan)
    end
  end

  test "invalid instance policies fail planning without endpoint preparation" do
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
          %{soft_limit: 1, hard_limit: 2, typo: true},
          %{soft_limit: 1, hard_limit: 2, provenance: %{source: :adaptive}}
        ] do
      assert {:error, :invalid_resource_budget} =
               ListenerSet.plan(declaration(resource_budget: policy))
    end
  end

  test "mixed planned services preserve omitted administrator caps in every protocol" do
    assert {:ok, plan} = ListenerSet.plan(declaration())
    assert {:ok, specs} = ListenerSet.planned_services(plan)
    assert Enum.map(specs, & &1.transport) == [:tcp, :tls, :quic]

    for spec <- specs do
      assert spec.budget_policy.max_active == nil
      assert spec.budget_policy.max_bytes == nil
      assert spec.budget_policy.max_connections == 16_384
      assert spec.budget_policy.max_requests == 65_536
      assert spec.budget_policy.max_streams == 65_536
      assert {:ok, ^spec} = Gaoxy.Config.service(spec)
    end
  end

  test "explicit per-listener legacy caps and quotas survive materialization and re-planning" do
    limits = %{
      max_active: 128,
      max_bytes: 536_870_912,
      max_connections: 100,
      max_requests: 200,
      max_streams: 300
    }

    listeners =
      Enum.map(listeners(), fn {role, options} ->
        {role, Keyword.put(options, :limits, limits)}
      end)

    assert {:ok, plan} = ListenerSet.plan(declaration(listeners: listeners))
    assert {:ok, specs} = ListenerSet.planned_services(plan)
    assert {:ok, repeated} = ListenerSet.plan(plan)
    assert {:ok, ^specs} = ListenerSet.planned_services(repeated)

    for spec <- specs do
      assert Map.take(spec.budget_policy, Map.keys(limits)) == limits
      assert {:ok, ^spec} = Gaoxy.Config.service(spec)
    end
  end

  test "Phoenix propagates one top-level policy to its single mixed ListenerSet child" do
    policy = %{soft_limit: 100, hard_limit: 200}
    plan = endpoint_plan(resource_budget: policy)
    assert {:ok, normalized} = Gaoxy.Config.validate(resource_budget: policy)
    assert plan.resource_budget == normalized.resource_budget
    assert Keyword.keys(plan.listeners) == [:http, :https, :http3]
    assert map_size(plan.service_ids) == 3
    assert {:ok, ^plan} = ListenerSet.plan(plan)
  end

  test "omitted Phoenix policy remains adaptive through mixed service materialization" do
    plan = endpoint_plan()
    assert plan.resource_budget.soft_limit == nil
    assert plan.resource_budget.hard_limit == nil
    assert {:ok, specs} = ListenerSet.planned_services(plan)
    assert length(specs) == 3
    assert Enum.all?(specs, &is_nil(&1.budget_policy.max_bytes))
    assert Enum.all?(specs, &is_nil(&1.budget_policy.max_active))
  end

  test "server false creates no duplicate listeners or policy owner" do
    assert [] =
             Gaoxy.PhoenixAdapter.child_specs(Endpoint,
               server: false,
               http: [port: 4000],
               https: true,
               http3: true,
               resource_budget: %{soft_limit: 2, hard_limit: 1}
             )
  end

  test "Phoenix rejects malformed top-level policies before creating its child" do
    for policy <- [nil, %{soft_limit: 100}, %{soft_limit: 200, hard_limit: 100}] do
      assert_raise ArgumentError, ~r/invalid_resource_budget/, fn ->
        endpoint_plan(resource_budget: policy)
      end
    end
  end

  test "instance policy is rejected inside a physical listener declaration" do
    policy = %{soft_limit: 100, hard_limit: 200}

    assert {:error, {:field, [:listeners, :http, :resource_budget], :unknown_option}} =
             ListenerSet.plan(declaration(listeners: [http: [resource_budget: policy]]))

    assert_raise ArgumentError, ~r/invalid http listener options/, fn ->
      Gaoxy.PhoenixAdapter.child_specs(Endpoint, http: [resource_budget: policy])
    end
  end
end
