defmodule Gaoxy.HTTP.ResourceBudgetPhoenixTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.ListenerSet

  @coordinator __MODULE__.Coordinator
  @policy %{soft_limit: 16_777_216, hard_limit: 33_554_432}

  defmodule NativeEndpoint do
    def init(options), do: {:ok, options}

    def call(exchange, marker) do
      send(
        Process.whereis(Gaoxy.HTTP.ResourceBudgetPhoenixTest.Coordinator),
        {:budget_request, marker, self()}
      )

      receive do
        :budget_reply -> Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "shared-budget")
      after
        Gaoxy.Lifecycle.remaining(exchange.deadline) -> {:error, :timeout, exchange}
      end
    end
  end

  setup do
    Process.register(self(), @coordinator)
    :ok
  end

  test "independent ListenerSets retain separate instance policies and share VM accounting" do
    first_owner =
      start_supervised!(
        {ListenerSet,
         id: :first_budget,
         endpoint: {NativeEndpoint, :first},
         resource_budget: @policy,
         listeners: [http: []]}
      )

    second_owner =
      start_supervised!(
        {ListenerSet,
         id: :second_budget,
         endpoint: {NativeEndpoint, :second},
         resource_budget: @policy,
         listeners: [http: []]}
      )

    first = ListenerSet.info(first_owner)
    second = ListenerSet.info(second_owner)
    refute first.instance == second.instance

    a = connect(:gen_tcp, hd(first.listeners).local, [])
    b = connect(:gen_tcp, hd(second.listeners).local, [])
    exercise(first.instance, second.instance, {:gen_tcp, a}, {:gen_tcp, b})
  end

  defp connect(client, {:ok, {ip, port}}, options) do
    assert {:ok, socket} =
             apply(client, :connect, [ip, port, [:binary, active: false] ++ options, 2_000])

    on_exit(fn -> apply(client, :close, [socket]) end)
    socket
  end

  defp exercise(first, second, {a_client, a}, {b_client, b}) do
    wire = "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
    assert :ok = apply(a_client, :send, [a, wire])
    assert :ok = apply(b_client, :send, [b, wire])
    assert_receive {:budget_request, :first, a_worker}, 2_000
    assert_receive {:budget_request, :second, b_worker}, 2_000
    assert Process.alive?(a_worker)
    assert Process.alive?(b_worker)
    first_budget = Gaoxy.resource_budget(first)
    second_budget = Gaoxy.resource_budget(second)

    for budget <- [first_budget, second_budget] do
      assert budget.soft_limit == @policy.soft_limit
      assert budget.hard_limit == @policy.hard_limit
      assert budget.active_connections == 1
      assert budget.active_requests == 1
      assert budget.usage > 0
    end

    assert first_budget.vm.usage == second_budget.vm.usage
    assert first_budget.vm.usage >= first_budget.usage + second_budget.usage
    send(a_worker, :budget_reply)
    send(b_worker, :budget_reply)

    for {client, socket} <- [{a_client, a}, {b_client, b}] do
      response = receive_response(client, socket, Gaoxy.Lifecycle.deadline(2_000), "")
      assert response =~ "HTTP/1.1 200"
      assert response =~ "shared-budget"
    end

    for instance <- [first, second],
        do: await_idle(instance, Gaoxy.Lifecycle.deadline(2_000))
  end

  defp receive_response(client, socket, deadline, buffer) do
    remaining = Gaoxy.Lifecycle.remaining(deadline)
    assert remaining > 0, "response deadline expired"

    case apply(client, :recv, [socket, 0, remaining]) do
      {:ok, bytes} -> receive_response(client, socket, deadline, buffer <> bytes)
      {:error, :closed} -> buffer
      error -> flunk("response failed: #{inspect(error)}")
    end
  end

  defp await_idle(instance, deadline) do
    case Gaoxy.resource_budget(instance) do
      %{usage: 0, active_connections: 0, active_requests: 0} ->
        :ok

      status ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)
        Process.sleep(5)
        await_idle(instance, deadline)
    end
  end
end
