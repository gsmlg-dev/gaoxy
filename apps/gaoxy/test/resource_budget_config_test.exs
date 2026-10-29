defmodule Gaoxy.ResourceBudgetConfigTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.Config

  defmodule Echo do
    def init(_, _), do: {:ok, nil}
    def handle_data(bytes, state), do: {:send, bytes, state}
  end

  defp spec(extra \\ %{}),
    do: Map.merge(%{id: "budget", transport: :tcp, handler: Echo}, extra)

  test "omitted legacy caps retain finite protocol numbers and adaptive policy" do
    assert {:ok, service} = Config.service(spec())
    assert service.limits.max_bytes == 1_048_576
    assert service.limits.max_active == 64
    assert service.budget_policy.max_bytes == nil
    assert service.budget_policy.max_active == nil
    assert service.budget_policy.max_connections == 16_384
    assert service.budget_policy.max_requests == 65_536
    assert service.budget_policy.max_streams == 65_536
  end

  test "explicit historical default numbers remain undoubled administrator caps" do
    assert {:ok, service} =
             Config.service(spec(%{limits: %{max_bytes: 1_048_576, max_active: 64}}))

    assert service.budget_policy.max_bytes == 1_048_576
    assert service.budget_policy.max_active == 64
    assert service.budget_policy.provenance.max_bytes == :explicit
    assert service.budget_policy.provenance.max_active == :explicit
  end

  test "normalized specs and complete plans preserve omission across repeated validation" do
    assert {:ok, service} = Config.service(spec())
    assert {:ok, ^service} = Config.service(service)
    assert {:ok, %{services: [^service]}} = Config.validate(services: [service])
    assert {:ok, ^service} = Config.service(service)
  end

  test "editing a normalized numeric limit becomes an explicit policy" do
    assert {:ok, original} = Config.service(spec())
    changed = put_in(original.limits.max_bytes, 500_000)
    assert {:ok, normalized} = Config.service(changed)
    assert normalized.budget_policy.max_bytes == 500_000
    assert normalized.budget_policy.max_active == nil
    assert {:ok, ^normalized} = Config.service(normalized)
  end

  test "malformed or contradictory normalized policy provenance is rejected" do
    assert {:ok, original} = Config.service(spec(%{limits: %{max_bytes: 1_048_576}}))

    assert {:error, :invalid_budget_policy} =
             Config.service(put_in(original.budget_policy.max_bytes, nil))

    assert {:error, :invalid_budget_policy} =
             Config.service(%{original | budget_policy: %{max_bytes: nil}})

    assert {:error, :invalid_budget_policy} = Config.service(%{original | budget_policy: nil})

    assert {:error, :invalid_budget_policy} =
             Config.service(put_in(original.budget_policy.provenance.max_bytes, :unknown))
  end

  test "independent quotas are positive finite values and retain their explicit values" do
    limits = %{max_connections: 100, max_requests: 200, max_streams: 300}
    assert {:ok, service} = Config.service(spec(%{limits: limits}))
    assert Map.take(service.budget_policy, Map.keys(limits)) == limits

    for key <- Map.keys(limits), value <- [nil, 0, -1, :infinity, 9_223_372_036_854_775_808] do
      assert {:error, _} = Config.service(spec(%{limits: %{key => value}}))
    end
  end

  test "a finite protocol profile does not become an aggregate administrator cap" do
    assert {:ok, service} = Config.service(spec(%{limits: %{protocol_max_bytes: 67_108_864}}))
    assert service.limits.max_bytes == 67_108_864
    assert service.limits.protocol_max_bytes == 67_108_864
    assert service.budget_policy.max_bytes == nil
    assert {:ok, ^service} = Config.service(service)

    for value <- [0, nil, :infinity, 9_223_372_036_854_775_808] do
      assert {:error, _} = Config.service(spec(%{limits: %{protocol_max_bytes: value}}))
    end
  end

  test "an explicit byte cap preserves its old numeric transport semantics" do
    for cap <- [2_097_152, 134_217_728] do
      assert {:ok, service} =
               Config.service(spec(%{limits: %{protocol_max_bytes: 67_108_864, max_bytes: cap}}))

      assert service.limits.max_bytes == cap
      assert service.budget_policy.max_bytes == cap
      assert {:ok, ^service} = Config.service(service)
    end
  end

  test "instance budgets default to adaptive and accept an explicit adaptive pair" do
    assert {:ok, %{resource_budget: %{soft_limit: nil, hard_limit: nil}}} = Config.validate([])

    assert {:ok, %{resource_budget: %{soft_limit: nil, hard_limit: nil}}} =
             Config.validate(resource_budget: %{soft_limit: nil, hard_limit: nil})
  end

  test "explicit instance thresholds are ordered undoubled and normalize idempotently" do
    assert {:ok, plan} = Config.validate(resource_budget: %{soft_limit: 100, hard_limit: 150})
    assert plan.resource_budget.soft_limit == 100
    assert plan.resource_budget.hard_limit == 150

    assert {:ok, %{resource_budget: budget}} =
             Config.validate(resource_budget: plan.resource_budget)

    assert budget == plan.resource_budget
  end

  test "partial malformed and unbounded instance policies fail validation" do
    for budget <- [
          nil,
          %{soft_limit: 100},
          %{hard_limit: 200},
          %{soft_limit: nil},
          %{soft_limit: 200, hard_limit: 100},
          %{soft_limit: 0, hard_limit: 100},
          %{soft_limit: 100, hard_limit: :infinity},
          %{soft_limit: 100, hard_limit: 9_223_372_036_854_775_808},
          %{soft_limit: 100, hard_limit: 200, typo: 1}
        ] do
      assert {:error, _} = Config.validate(resource_budget: budget)
    end
  end

  test "connection capacity honors connection quota and explicit legacy lease cap" do
    assert {:ok, adaptive} = Config.service(spec())
    assert apply(Config, :connection_capacity, [adaptive]) == 16_384

    assert {:ok, explicit} =
             Config.service(spec(%{limits: %{max_active: 32, max_connections: 100}}))

    assert apply(Config, :connection_capacity, [explicit]) == 32
  end

  test "acceptor safety intersects connection capacity and preserves the finite 64 cap" do
    assert {:ok, _} =
             Config.service(
               spec(%{limits: %{max_connections: 2}, hell_options: [num_acceptors: 2]})
             )

    for extra <- [
          %{limits: %{max_connections: 2}, hell_options: [num_acceptors: 3]},
          %{limits: %{max_active: 1}, hell_options: [num_acceptors: 2]},
          %{hell_options: [num_acceptors: 65]}
        ] do
      assert {:error, {:invalid_backend_option, :hell_options, :num_acceptors}} =
               Config.service(spec(extra))
    end
  end

  test "lease safety is finite and independent of administrator and connection limits" do
    assert apply(Config, :lease_safety_limit, []) == 262_144
  end
end
