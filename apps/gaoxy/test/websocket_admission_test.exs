defmodule Gaoxy.WebSocketAdmissionTest do
  use ExUnit.Case, async: true
  alias Gaoxy.{Admission, Lifecycle}

  test "upgrade keeps arbitrary retained data outside explicit generic byte and state budgets" do
    gate = gate()
    lease = request(gate)
    assert :ok = Admission.upgrade(gate, lease, accounting(10, 1_000_000), :infinity)

    assert %{retained_bytes: 1_000_010, transport_bytes: 10, websocket_bytes: 1_000_000} =
             Admission.status(gate)

    assert :ok = Admission.update(gate, lease, 20)

    assert %{retained_bytes: 1_000_020, transport_bytes: 20, websocket_bytes: 1_000_000} =
             Admission.status(gate)

    assert {:error, :byte_limit} = Admission.update(gate, lease, 101)
    assert %{transport_bytes: 20, websocket_bytes: 1_000_000} = Admission.status(gate)
    assert :ok = Admission.adjust_bytes(gate, lease, -20)
    assert %{transport_bytes: 0, websocket_bytes: 1_000_000} = Admission.status(gate)
  end

  test "callback result invalidates execution timer before progressing sends and retains lifetime" do
    gate = gate()
    lease = request(gate)
    lifetime = Lifecycle.deadline(30_000)
    assert :ok = Admission.upgrade(gate, lease, accounting(10, 500), lifetime)

    assert :ok =
             Admission.begin_callback(gate, lease, accounting(10, 500), Lifecycle.deadline(1000))

    %{token: expired_token} = :sys.get_state(gate).leases[lease]
    assert :ok = Admission.end_websocket_callback(gate, lease, accounting(10, 2_000_000))
    assert %{timer: nil, token: nil, deadline: ^lifetime} = :sys.get_state(gate).leases[lease]
    send(gate, {:expired, lease, expired_token})
    assert {:ok, operation} = Admission.start_send(gate, lease, 30)
    assert :ok = Admission.finish_send(gate, lease, operation, :ok)
    assert %{active: 1, websocket_bytes: 2_000_000} = Admission.status(gate)
    assert Process.alive?(self())
  end

  test "invalid callback retention leaves the watchdog and prior retention intact" do
    gate = gate()
    lease = request(gate)
    assert :ok = Admission.upgrade(gate, lease, accounting(10, 1000), :infinity)

    assert :ok =
             Admission.begin_callback(
               gate,
               lease,
               accounting(10, 1000),
               Lifecycle.deadline(10_000)
             )

    %{token: token, timer: timer} = :sys.get_state(gate).leases[lease]

    assert {:error, :byte_limit} =
             Admission.end_websocket_callback(gate, lease, accounting(101, 2000))

    assert %{token: ^token, timer: ^timer, websocket_bytes: 1000} =
             :sys.get_state(gate).leases[lease]

    assert :ok = Admission.end_websocket_callback(gate, lease, accounting(10, 1000))
  end

  test "unauthorized and stale callback results cannot cancel or replace owned retention" do
    gate = gate()
    lease = request(gate)
    assert :ok = Admission.upgrade(gate, lease, accounting(10, 500), :infinity)
    task = Task.async(fn -> Admission.end_websocket_callback(gate, lease, accounting(0, 0)) end)
    assert {:error, :stale_generation} = Task.await(task)

    assert {:error, :stale_generation} =
             Admission.end_websocket_callback(gate, make_ref(), accounting(0, 0))

    assert %{transport_bytes: 10, websocket_bytes: 500} = Admission.status(gate)
  end

  test "repeated transport credit reuse preserves retention and owner death releases both once" do
    gate = gate()
    parent = self()

    owner =
      spawn(fn ->
        lease = request(gate)
        :ok = Admission.upgrade(gate, lease, accounting(10, 500_000), :infinity)

        for _ <- 1..10 do
          :ok = Admission.adjust_bytes(gate, lease, 90)
          :ok = Admission.adjust_bytes(gate, lease, -90)
        end

        send(parent, {:retained, self(), lease})

        receive do
          :finish -> :ok
        end
      end)

    assert_receive {:retained, ^owner, lease}, 1000

    assert %{transport_bytes: 10, websocket_bytes: 500_000, transport_high_water: 100} =
             Admission.status(gate)

    monitor = Process.monitor(owner)
    send(owner, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^owner, :normal}
    assert :ok = wait_removed(gate, lease, Lifecycle.deadline(1000))

    assert %{active: 0, transport_bytes: 0, websocket_bytes: 0, retained_bytes: 0} =
             Admission.status(gate)
  end

  test "ordinary leases retain their original scalar schema" do
    gate = gate()
    assert {:ok, lease} = Admission.acquire(gate, 10)
    ordinary = :sys.get_state(gate).leases[lease]

    assert Enum.sort(Map.keys(ordinary)) ==
             Enum.sort([
               :pid,
               :monitor,
               :bytes,
               :token,
               :timer,
               :send,
               :drain_notify,
               :request_active,
               :cleanup,
               :deadline
             ])

    assert :ok = Admission.update(gate, lease, 100)
    assert {:error, :byte_limit} = Admission.update(gate, lease, 101)
  end

  test "ordinary admission shares transport credits without inheriting websocket retention" do
    gate = gate()
    lease = request(gate)
    assert :ok = Admission.upgrade(gate, lease, accounting(10, 1_000_000), :infinity)
    assert {:ok, ordinary} = Admission.acquire(gate, 90)
    assert {:error, :byte_limit} = Admission.acquire(gate, 1)
    assert :ok = Admission.retain(gate, ordinary, 80)
    assert :ok = Admission.update(gate, lease, accounting(20, 2_000_000))
    assert %{transport_bytes: 100, websocket_bytes: 2_000_000} = Admission.status(gate)
  end

  test "only the request upgrade can introduce classified ownership" do
    gate = gate()
    lease = request(gate)
    assert {:error, :byte_limit} = Admission.update(gate, lease, accounting(0, 1000))

    assert {:error, :byte_limit} =
             Admission.begin_callback(gate, lease, accounting(0, 1000), Lifecycle.deadline(1000))

    assert {:error, :not_websocket} =
             Admission.end_websocket_callback(gate, lease, accounting(0, 1000))

    assert %{retained_bytes: 10, transport_bytes: 10, websocket_bytes: 0} = Admission.status(gate)
  end

  test "upgrade and callback retention preserve outstanding send ownership" do
    gate = gate()
    lease = request(gate)
    assert {:ok, operation} = Admission.start_send(gate, lease, 12)
    assert :ok = Admission.upgrade(gate, lease, accounting(10, 1000), :infinity)

    assert :ok =
             Admission.begin_callback(gate, lease, accounting(10, 1000), Lifecycle.deadline(1000))

    assert :ok = Admission.end_websocket_callback(gate, lease, accounting(10, 2000))
    assert :ok = Admission.finish_send(gate, lease, operation, :ok)
    assert {:error, :stale_operation} = Admission.finish_send(gate, lease, operation, :ok)
  end

  test "nonreturning websocket callback still expires and releases both categories" do
    gate = gate()
    parent = self()

    owner =
      spawn(fn ->
        lease = request(gate)
        :ok = Admission.upgrade(gate, lease, accounting(10, 1_000_000), :infinity)

        :ok =
          Admission.begin_callback(gate, lease, accounting(10, 1_000_000), Lifecycle.deadline(50))

        send(parent, {:callback, self(), lease})

        receive do
          :never -> :ok
        end
      end)

    monitor = Process.monitor(owner)
    assert_receive {:callback, ^owner, lease}, 1000
    assert_receive {:DOWN, ^monitor, :process, ^owner, :killed}, 1000
    assert :ok = wait_removed(gate, lease, Lifecycle.deadline(1000))

    assert %{active: 0, retained_bytes: 0, transport_bytes: 0, websocket_bytes: 0} =
             Admission.status(gate)
  end

  test "classified upgrade preserves drain eligibility and finite shutdown ownership" do
    gate = gate()
    lease = request(gate)
    assert :ok = Admission.upgrade(gate, lease, accounting(10, 1_000_000), :infinity)
    deadline = Lifecycle.deadline(1000)
    assert :ok = Admission.drain(gate, deadline)
    assert_receive {:gaoxy_drain, ^gate, ^lease, ^deadline}
    assert {:error, :draining} = Admission.acquire(gate, 0)
    assert :ok = Admission.update(gate, lease, accounting(0, 0))
    assert %{transport_bytes: 0, websocket_bytes: 0} = Admission.status(gate)
  end

  defp accounting(transport, retained),
    do: %{transport_bytes: transport, websocket_bytes: retained}

  defp request(gate) do
    {:ok, lease} = Admission.acquire(gate, 10, drain_notify: true)
    :ok = Admission.begin_request(gate, lease, 10, Lifecycle.deadline(10_000))
    lease
  end

  defp gate do
    limits = %{max_active: 4, max_bytes: 100, max_state: 1, callback_timeout: 5000}
    start_supervised!({Admission, {limits, %{service: "ws", generation: make_ref()}}})
  end

  defp wait_removed(gate, lease, deadline) do
    state = :sys.get_state(gate)

    cond do
      not Map.has_key?(state.leases, lease) -> :ok
      Lifecycle.remaining(deadline) == 0 -> flunk("owner lease was not released")
      true -> wait_removed(gate, lease, deadline)
    end
  end
end
