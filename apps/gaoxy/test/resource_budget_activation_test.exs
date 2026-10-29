defmodule Gaoxy.ResourceBudgetActivationTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.{Activation, Config}

  defmodule Echo do
    def init(_, _), do: {:ok, nil}
    def handle_data(bytes, state), do: {:send, bytes, state}
  end

  defp service(limits \\ %{}) do
    {:ok, spec} = Config.service(%{id: "budget", transport: :tcp, handler: Echo, limits: limits})
    spec
  end

  defp compare(actual, planned),
    do: apply(Activation, :validate_services, [[actual], [planned]])

  test "repeated adaptive normalized services preserve deferred ceilings" do
    planned = service()
    assert {:ok, [^planned]} = compare(planned, planned)
  end

  test "adaptive legacy policy may narrow to explicit transport and aggregate lease caps" do
    assert {:ok, [_]} = compare(service(%{max_bytes: 500_000, max_active: 32}), service())
  end

  test "an explicit legacy cap cannot be omitted during deferred activation" do
    assert {:error, {:planned_service_ceiling, "budget"}} =
             compare(service(), service(%{max_bytes: 1_048_576, max_active: 64}))
  end

  test "explicit limits and independent quotas may decrease but never increase" do
    planned = service(%{max_bytes: 1000, max_connections: 10})
    assert {:ok, [_]} = compare(service(%{max_bytes: 900, max_connections: 9}), planned)

    assert {:error, {:planned_service_ceiling, "budget"}} =
             compare(service(%{max_bytes: 1001, max_connections: 9}), planned)

    assert {:error, {:planned_service_ceiling, "budget"}} =
             compare(service(%{max_bytes: 900, max_connections: 11}), planned)
  end

  test "a malformed policy cannot exploit generic term ordering in deferred validation" do
    planned = service()
    invalid = Map.put(planned, :budget_policy, %{max_bytes: nil})
    assert {:error, :invalid_budget_policy} = compare(invalid, planned)
  end
end
