defmodule Gaoxy.HTTP.HTTP3.OperationsTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.HTTP3.Operations
  alias Gaoxy.Lifecycle

  defp op(name, args), do: apply(Operations, name, args)

  defp worker do
    parent = self()
    pid = spawn(fn -> worker_loop(parent) end)
    on_exit(fn -> if Process.alive?(pid), do: Process.exit(pid, :kill) end)
    pid
  end

  defp worker_loop(parent) do
    receive do
      {:invoke, name, args} ->
        send(parent, {:result, self(), op(name, args)})
        worker_loop(parent)

      message ->
        send(parent, {:observed, self(), message})
        worker_loop(parent)
    end
  end

  defp invoke(pid, name, args) do
    send(pid, {:invoke, name, args})
    assert_receive {:result, ^pid, result}
    result
  end

  defp slot(limits \\ nil, key \\ make_ref()) do
    table = op(:new, [])
    token = make_ref()
    deadline = Lifecycle.deadline(1_000)
    pid = worker()
    lease = make_ref()

    arguments =
      if limits, do: [table, key, token, deadline, limits], else: [table, key, token, deadline]

    :ok = op(:register, arguments)
    :ok = op(:bind, [table, key, token, pid])
    :ok = invoke(pid, :ready, [table, key, token, lease])
    :ok = op(:activate, [table, key, token, pid])
    {table, key, token, pid, deadline}
  end

  defp websocket_slot(lifetime \\ nil) do
    assert Code.ensure_loaded?(Operations) and function_exported?(Operations, :upgrade, 5),
           "missing owner-validated H3 websocket lifetime transition"

    {table, key, token, pid, original} = slot()
    lifetime = lifetime || Lifecycle.deadline(10_000)
    operation = {:websocket_open, [], lifetime}
    assert {:ok, ref} = invoke(pid, :submit, [table, key, token, {operation, original}])
    assert {:ok, ^pid, ^ref, ^operation, ^original} = op(:claim, [table, key, token])
    {table, key, token, pid, original, lifetime, ref}
  end

  test "infinite websocket ownership retains finite operations and reusable receive credits" do
    {table, key, token, pid, original, :infinity, ref} = websocket_slot(:infinity)
    assert :ok = op(:upgrade, [table, key, token, ref, :infinity])
    assert :ok = op(:reply, [table, key, token, ref, :ok])
    assert :ok = invoke(pid, :ack, [table, key, token, ref])
    assert {:ok, %{deadline: :infinity, websocket: :open}} = op(:status, [table, key, token])

    assert {:error, :timeout} =
             invoke(pid, :submit, [
               table,
               key,
               token,
               {{:data, "unbounded operation", false}, :infinity}
             ])

    for _ <- 1..3 do
      demand = make_ref()
      assert :ok = invoke(pid, :demand, [table, key, token, 4, demand])
      assert :ok = op(:deliver, [table, key, token, demand, "data", false])
      assert_receive {:observed, ^pid, {:gaoxy_websocket_data, ^token, ^demand, "data", false}}
      assert :ok = invoke(pid, :demand, [table, key, token, 0, demand])

      deadline = original + 1_000
      operation = {:data, "progress", false}
      assert {:ok, write} = invoke(pid, :submit, [table, key, token, {operation, deadline}])
      assert {:ok, ^pid, ^write, ^operation, ^deadline} = op(:claim, [table, key, token])
      assert :ok = op(:reply, [table, key, token, write, :ok])
      assert :ok = invoke(pid, :ack, [table, key, token, write])
    end
  end

  test "only the owner adopts the requested lifetime once while the opening operation stays finite" do
    {table, key, token, pid, original, lifetime, ref} = websocket_slot()
    assert {:error, :closed} = invoke(pid, :upgrade, [table, key, token, ref, lifetime])
    assert :ok = op(:upgrade, [table, key, token, ref, lifetime])
    assert {:error, :closed} = op(:upgrade, [table, key, token, ref, lifetime])

    assert {:ok,
            %{
              deadline: ^lifetime,
              websocket: :opening,
              status: {:claimed, ^ref, {:websocket_open, [], ^lifetime}, ^original}
            }} =
             op(:status, [table, key, token])

    assert :ok = op(:reply, [table, key, token, ref, :ok])
    assert :ok = invoke(pid, :ack, [table, key, token, ref])

    assert {:ok, %{deadline: ^lifetime, websocket: :open, status: :idle}} =
             op(:status, [table, key, token])

    # An operation beyond the original request boundary now uses the adopted lifetime.
    assert {:ok, _} =
             invoke(pid, :submit, [table, key, token, {{:data, "push", false}, lifetime}])
  end

  test "one separate demand permits application output and requires fresh delivery acknowledgments" do
    {table, key, token, pid, _, lifetime, opening} = websocket_slot()
    assert :ok = op(:upgrade, [table, key, token, opening, lifetime])
    assert :ok = op(:reply, [table, key, token, opening, :ok])
    assert :ok = invoke(pid, :ack, [table, key, token, opening])
    ref = make_ref()
    assert :ok = invoke(pid, :demand, [table, key, token, 32, ref])
    assert {:error, :pending_read} = invoke(pid, :demand, [table, key, token, 32, make_ref()])

    assert {:ok, output} =
             invoke(pid, :submit, [table, key, token, {{:data, "idle push", false}, lifetime}])

    assert {:ok, ^pid, ^output, _, ^lifetime} = op(:claim, [table, key, token])
    assert :ok = op(:reply, [table, key, token, output, :ok])
    assert :ok = invoke(pid, :ack, [table, key, token, output])
    assert :ok = op(:deliver, [table, key, token, ref, "hello", false])
    assert_receive {:observed, ^pid, {:gaoxy_websocket_data, ^token, ^ref, "hello", false}}
    assert {:ok, %{demand: {:delivered, ^ref, 5}}} = op(:status, [table, key, token])
    assert {:error, :stale_demand} = invoke(pid, :demand, [table, key, token, 0, make_ref()])
    assert {:error, :stale_demand} = invoke(pid, :demand, [table, key, token, 32, ref])
    next = make_ref()
    assert :ok = invoke(pid, :demand, [table, key, token, 32, next])
    assert {:error, :closed} = op(:deliver, [table, key, token, ref, "stale", false])
    assert :ok = op(:deliver, [table, key, token, next, "", true])
    assert :ok = invoke(pid, :demand, [table, key, token, 0, next])
    assert {:error, :stale_demand} = invoke(pid, :demand, [table, key, token, 0, next])
    assert {:ok, %{status: :idle, demand: nil}} = op(:status, [table, key, token])
    assert :ok = invoke(pid, :close_demand, [table, key, token])
    assert {:ok, %{websocket: :closing}} = op(:status, [table, key, token])
  end

  test "opaque map and QUIC stream keys preserve exactly one claim and reply" do
    for key <- [
          %{opaque: make_ref()},
          %Gaoxy.QUIC.Stream{handle: make_ref(), connection: %{opaque: make_ref()}}
        ] do
      {table, ^key, token, pid, deadline} = slot(nil, key)
      operation = {:data, "wire", true}
      assert {:ok, ref} = invoke(pid, :submit, [table, key, token, {operation, deadline}])
      assert {:ok, ^pid, ^ref, ^operation, ^deadline} = op(:claim, [table, key, token])
      assert :idle = op(:claim, [table, key, token])
      assert :ok = op(:reply, [table, key, token, ref, :ok])
      assert :ok = invoke(pid, :ack, [table, key, token, ref])
      assert :ok = op(:remove, [table, key, token])
      assert {:error, :closed} = op(:status, [table, key, token])
    end
  end

  test "metadata operations honor the owner-registered configured limits" do
    limits = %{
      max_headers: 120,
      max_header_bytes: 40_000,
      max_trailers: 40,
      max_trailer_bytes: 10_000
    }

    {table, key, token, pid, deadline} = slot(limits)
    heads = for index <- 1..120, do: {"x-#{index}", "field"}
    trailers = for index <- 1..40, do: {"x-#{index}", "field"}

    for operation <- [{:head, 200, heads, false}, {:trailers, trailers}] do
      assert {:ok, ref} = invoke(pid, :submit, [table, key, token, {operation, deadline}])
      assert {:ok, ^pid, ^ref, ^operation, ^deadline} = op(:claim, [table, key, token])
      assert :ok = op(:reply, [table, key, token, ref, :ok])
      assert :ok = invoke(pid, :ack, [table, key, token, ref])
    end

    assert {:error, :operation_limit} =
             invoke(pid, :submit, [
               table,
               key,
               token,
               {{:head, 200, [{"x-more", "field"} | heads], false}, deadline}
             ])

    assert {:error, :operation_limit} =
             invoke(pid, :submit, [
               table,
               key,
               token,
               {{:trailers, [{"x-more", "field"} | trailers]}, deadline}
             ])
  end

  test "returned PID binding precedes readiness and dispatch" do
    table = op(:new, [])
    key = make_ref()
    token = make_ref()
    deadline = Lifecycle.deadline(1_000)
    pid = worker()
    other = worker()
    lease = make_ref()
    assert :ok = op(:register, [table, key, token, deadline])
    assert {:error, :closed} = invoke(pid, :ready, [table, key, token, lease])
    assert :ok = op(:bind, [table, key, token, pid])
    assert {:error, :closed} = invoke(other, :ready, [table, key, token, lease])
    assert :ok = invoke(pid, :ready, [table, key, token, lease])
    assert {:error, :closed} = op(:activate, [table, key, token, other])
    assert :ok = op(:activate, [table, key, token, pid])

    assert {:ok, %{worker: ^pid, lease: ^lease, deadline: ^deadline, status: :idle}} =
             op(:status, [table, key, token])
  end

  test "one operation is claimed once and acknowledged before reuse" do
    {table, key, token, pid, deadline} = slot()
    operation = {:data, "piece", false}
    assert {:ok, ref} = invoke(pid, :submit, [table, key, token, {operation, deadline}])
    assert {:error, :busy} = invoke(pid, :submit, [table, key, token, {operation, deadline}])
    assert {:ok, ^pid, ^ref, ^operation, ^deadline} = op(:claim, [table, key, token])
    assert :idle = op(:claim, [table, key, token])
    assert :ok = op(:reply, [table, key, token, ref, :ok])
    assert_receive {:observed, ^pid, {:http3_operation, ^token, ^ref, :ok}}
    assert {:error, :closed} = op(:reply, [table, key, token, ref, :ok])
    assert {:error, :busy} = invoke(pid, :submit, [table, key, token, {operation, deadline}])
    assert :ok = invoke(pid, :ack, [table, key, token, ref])
    assert {:ok, next} = invoke(pid, :submit, [table, key, token, {operation, deadline}])
    refute next == ref
  end

  test "stale tokens and other workers cannot submit or clear a slot" do
    {table, key, token, pid, deadline} = slot()
    other = worker()
    stale = make_ref()
    operation = {{:data, "piece", false}, deadline}
    assert {:error, :closed} = invoke(other, :submit, [table, key, token, operation])
    assert {:error, :closed} = invoke(pid, :submit, [table, key, stale, operation])
    assert {:error, :closed} = op(:remove, [table, key, stale])
    assert {:ok, %{status: :idle}} = op(:status, [table, key, token])
  end

  test "oversized operations never enter the bounded slot" do
    {table, key, token, pid, deadline} = slot()

    for operation <- [
          {:data, :binary.copy("x", 16_385), false},
          {:head, 200, [{"x-large", :binary.copy("x", 32_769)}], false},
          {:trailers, [{"x-large", :binary.copy("x", 8_193)}]},
          {:read, 16_385, {:until, deadline}},
          {:poll, {:until, deadline + 1}}
        ] do
      assert {:error, :operation_limit} =
               invoke(pid, :submit, [table, key, token, {operation, deadline}])

      assert {:ok, %{status: :idle}} = op(:status, [table, key, token])
    end
  end

  test "caller timeout before claim fences later output" do
    {table, key, token, pid, deadline} = slot()
    operation = {:data, "once", true}
    assert {:ok, ref} = invoke(pid, :submit, [table, key, token, {operation, deadline}])
    assert :ok = invoke(pid, :timeout, [table, key, token, ref])
    assert :idle = op(:claim, [table, key, token])
    assert {:error, :closed} = invoke(pid, :submit, [table, key, token, {operation, deadline}])
    assert {:error, :closed} = op(:reply, [table, key, token, ref, :ok])
    refute_receive {:observed, ^pid, {:http3_operation, ^token, ^ref, :ok}}
  end

  test "caller timeout after claim preserves tombstone and blocks late reply" do
    {table, key, token, pid, deadline} = slot()
    operation = {:data, "once", true}
    assert {:ok, ref} = invoke(pid, :submit, [table, key, token, {operation, deadline}])
    assert {:ok, ^pid, ^ref, ^operation, ^deadline} = op(:claim, [table, key, token])
    assert :ok = invoke(pid, :timeout, [table, key, token, ref])
    assert {:ok, %{status: {:cancelled, ^ref, :timeout}}} = op(:status, [table, key, token])
    assert {:error, :closed} = op(:reply, [table, key, token, ref, :ok])
    assert {:error, :closed} = invoke(pid, :ack, [table, key, token, ref])
  end

  test "owner-confirmed pending reads permit later reads and output" do
    {table, key, token, pid, deadline} = slot()

    for operation <- [
          {:read, 10, {:until, deadline}},
          {:read, 10, {:until, deadline}},
          {:data, "later", true}
        ] do
      assert {:ok, ref} = invoke(pid, :submit, [table, key, token, {operation, deadline}])
      assert {:ok, ^pid, ^ref, ^operation, ^deadline} = op(:claim, [table, key, token])
      result = if elem(operation, 0) == :read, do: :pending, else: :ok
      assert :ok = op(:reply, [table, key, token, ref, result])
      assert_receive {:observed, ^pid, {:http3_operation, ^token, ^ref, ^result}}
      assert :ok = invoke(pid, :ack, [table, key, token, ref])
    end
  end

  test "finite read expiry permits owner-confirmed pending within the original request" do
    {table, key, token, pid, deadline} = slot()
    operation = {:read, 10, {:until, Lifecycle.now() - 1}}
    assert {:ok, ref} = invoke(pid, :submit, [table, key, token, {operation, deadline}])
    assert {:ok, ^pid, ^ref, ^operation, ^deadline} = op(:claim, [table, key, token])
    assert :ok = op(:reply, [table, key, token, ref, :pending])
    assert_receive {:observed, ^pid, {:http3_operation, ^token, ^ref, :pending}}
    assert :ok = invoke(pid, :ack, [table, key, token, ref])
    assert {:ok, %{status: :idle, deadline: ^deadline}} = op(:status, [table, key, token])
  end

  test "caller expiry also fences a completed but unacknowledged reply" do
    {table, key, token, pid, deadline} = slot()
    operation = {:data, "retained", false}
    assert {:ok, ref} = invoke(pid, :submit, [table, key, token, {operation, deadline}])
    assert {:ok, ^pid, ^ref, ^operation, ^deadline} = op(:claim, [table, key, token])
    assert :ok = op(:reply, [table, key, token, ref, :ok])
    assert :ok = invoke(pid, :timeout, [table, key, token, ref])
    assert {:ok, %{status: {:cancelled, ^ref, :timeout}}} = op(:status, [table, key, token])
    assert {:error, :closed} = invoke(pid, :ack, [table, key, token, ref])

    assert {:error, :closed} =
             invoke(pid, :submit, [table, key, token, {{:data, "late", true}, deadline}])
  end

  test "a late owner reply cannot complete an expired reference" do
    {table, key, token, pid, _} = slot()
    deadline = Lifecycle.deadline(40)
    operation = {:data, "once", true}
    assert {:ok, ref} = invoke(pid, :submit, [table, key, token, {operation, deadline}])
    assert {:ok, ^pid, ^ref, ^operation, ^deadline} = op(:claim, [table, key, token])

    receive do
    after
      Lifecycle.remaining(deadline) + 1 -> :ok
    end

    assert {:error, :timeout} = op(:reply, [table, key, token, ref, :ok])
    assert {:ok, %{status: {:cancelled, ^ref, :timeout}}} = op(:status, [table, key, token])
    refute_received {:observed, ^pid, {:http3_operation, ^token, ^ref, :ok}}
  end

  test "a caller paused past confirmation expiry cannot acknowledge into idle" do
    {table, key, token, pid, _} = slot()
    deadline = Lifecycle.deadline(40)
    operation = {:data, "once", true}
    assert {:ok, ref} = invoke(pid, :submit, [table, key, token, {operation, deadline}])
    assert {:ok, ^pid, ^ref, ^operation, ^deadline} = op(:claim, [table, key, token])
    assert :ok = op(:reply, [table, key, token, ref, :ok])
    assert_receive {:observed, ^pid, {:http3_operation, ^token, ^ref, :ok}}

    receive do
    after
      Lifecycle.remaining(deadline) + 1 -> :ok
    end

    assert {:error, :timeout} = invoke(pid, :ack, [table, key, token, ref])
    assert {:ok, %{status: {:cancelled, ^ref, :timeout}}} = op(:status, [table, key, token])
    assert {:error, :closed} = invoke(pid, :ack, [table, key, token, ref])
  end

  test "only eight owner-registered slots survive and failed-start rows are removable" do
    table = op(:new, [])
    token = make_ref()
    deadline = Lifecycle.deadline(1_000)
    keys = for _ <- 1..8, do: make_ref()
    for key <- keys, do: assert(:ok = op(:register, [table, key, token, deadline]))
    assert {:error, :slot_limit} = op(:register, [table, make_ref(), token, deadline])
    [key | _] = keys
    assert :ok = op(:remove, [table, key, token])
    assert {:error, :closed} = op(:status, [table, key, token])
    assert :ok = op(:register, [table, make_ref(), token, deadline])
    assert :ets.info(table, :size) == 8
  end

  test "expired deadlines and deleted tables cannot publish operations" do
    {table, key, token, pid, deadline} = slot()

    assert {:error, :timeout} =
             invoke(pid, :submit, [
               table,
               key,
               token,
               {{:data, "late", true}, Lifecycle.now() - 1}
             ])

    assert :ets.delete(table)

    assert {:error, :closed} =
             invoke(pid, :submit, [table, key, token, {{:data, "late", true}, deadline}])
  end
end
