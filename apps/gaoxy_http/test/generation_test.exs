defmodule Gaoxy.HTTP.GenerationTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Generation, PlugEndpoint, Router}

  defmodule Target do
    def init({:wait, owner}) do
      send(owner, {:preparing, self()})

      receive do
        :prepare -> {:ok, :prepared}
      end
    end

    def init(:invalid), do: {:error, :invalid_target}
    def init(:inflate), do: {:ok, String.duplicate("x", 2048)}
    def init(value), do: {:ok, value}
    def call(exchange, _), do: {:ok, exchange}
  end

  defmodule Page do
    def init(options), do: options

    def call(conn, %{label: label, owner: owner}) do
      if conn.request_path == "/hold" do
        token = make_ref()
        send(owner, {:selected, self(), token, label})

        receive do
          {:release, ^token} -> :ok
        after
          2_000 -> raise "request release deadline"
        end
      end

      Plug.Conn.send_resp(conn, 200, label)
    end
  end

  test "activation compares generations and preparation failure preserves the current snapshot" do
    store = start_supervised!({Generation, routes: routes(:old)})
    assert {:ok, original, old_router} = Generation.snapshot(store)
    assert {:ok, prepared} = Generation.prepare(store, routes(:new))
    assert {:ok, next} = Generation.activate(store, original, prepared)
    refute next == original
    assert {:error, :stale_generation} = Generation.activate(store, original, old_router)
    assert {:error, :invalid_target} = Generation.prepare(store, routes(:invalid))
    assert {:ok, ^next, ^prepared} = Generation.snapshot(store)
  end

  test "route and compiled byte bounds reject before activation" do
    store = start_supervised!({Generation, routes: routes(:old), max_routes: 1})
    assert {:ok, original, router} = Generation.snapshot(store)

    assert {:error, :route_limit} =
             Generation.prepare(store, routes(:one) ++ routes(:two))

    assert {:error, :configuration_too_large} =
             Generation.prepare(store, routes(String.duplicate("x", 1_048_577)))

    assert {:ok, ^original, ^router} = Generation.snapshot(store)

    small =
      start_supervised!({Generation, routes: routes(:old), max_config_bytes: 1024}, id: :small)

    assert {:error, :configuration_too_large} = Generation.prepare(small, routes(:inflate))
  end

  test "one bounded preparation runs outside the store and competing preparation is rejected" do
    store = start_supervised!({Generation, routes: routes(:old)})
    assert {:ok, original, router} = Generation.snapshot(store)
    owner = self()
    task = Task.async(fn -> Generation.prepare(store, routes({:wait, owner})) end)
    assert_receive {:preparing, preparing}, 1_000
    assert {:ok, ^original, ^router} = Generation.snapshot(store)
    assert {:error, :preparation_busy} = Generation.prepare(store, routes(:other))
    send(preparing, :prepare)
    assert {:ok, %Router{}} = Task.await(task, 1_000)
    assert {:ok, ^original, ^router} = Generation.snapshot(store)
  end

  test "expired preparation is terminated and a later preparation can proceed" do
    store = start_supervised!({Generation, routes: routes(:old)})
    assert {:ok, original, router} = Generation.snapshot(store)
    owner = self()
    task = Task.async(fn -> Generation.prepare(store, routes({:wait, owner}), 100) end)
    assert_receive {:preparing, preparing}, 1_000
    monitor = Process.monitor(preparing)
    assert {:error, :prepare_timeout} = Task.await(task, 1_000)
    assert_receive {:DOWN, ^monitor, :process, ^preparing, :killed}, 1_000
    assert {:ok, ^original, ^router} = Generation.snapshot(store)
    assert {:ok, %Router{}} = Generation.prepare(store, routes(:new))
  end

  test "stopping the store terminates its blocked preparation" do
    store = start_supervised!({Generation, routes: routes(:old)})
    owner = self()
    task = Task.async(fn -> Generation.prepare(store, routes({:wait, owner})) end)
    assert_receive {:preparing, preparing}, 1_000
    monitor = Process.monitor(preparing)
    GenServer.stop(store)
    assert {:error, :generation_unavailable} = Task.await(task, 1_000)
    assert_receive {:DOWN, ^monitor, :process, ^preparing, :killed}, 1_000
  end

  test "reload keeps one total deadline when the generation owner is unavailable" do
    store = start_supervised!({Generation, routes: routes(:old)})
    assert {:ok, original, router} = Generation.snapshot(store)
    :ok = :sys.suspend(store)
    task = Task.async(fn -> Generation.reload(store, routes(:new), 20) end)
    result = Task.yield(task, 200)
    :ok = :sys.resume(store)
    assert {:ok, {:error, :generation_unavailable}} = result
    assert {:ok, ^original, ^router} = Generation.snapshot(store)
  end

  test "an activation queued beyond its deadline cannot mutate the live snapshot" do
    store = start_supervised!({Generation, routes: routes(:old)})
    assert {:ok, original, router} = Generation.snapshot(store)
    assert {:ok, prepared} = Generation.prepare(store, routes(:new))
    assert function_exported?(Generation, :activate, 4)
    :ok = :sys.suspend(store)

    task = Task.async(fn -> apply(Generation, :activate, [store, original, prepared, 20]) end)
    result = Task.yield(task, 200)
    :ok = :sys.resume(store)
    assert {:ok, {:error, :generation_unavailable}} = result
    assert {:ok, ^original, ^router} = Generation.snapshot(store)
  end

  test "invalid public options and timeouts fail without starting an owner" do
    for options <- [nil, %{}, [:invalid], [routes: [], routes: []], [unknown: true]] do
      assert {:error, :invalid_generation_options} = Generation.start_link(options)
    end

    assert {:error, :invalid_generation_limits} = Generation.start_link(max_routes: 0)
    assert {:error, :invalid_prepare_timeout} = Generation.prepare(self(), [], 0)
    assert {:error, :invalid_reload_timeout} = Generation.reload(self(), [], 0)
  end

  test "configuration payload is admitted before it crosses to a preparation worker" do
    store = start_supervised!({Generation, routes: routes(:old)})
    :ok = :sys.suspend(store)
    task = Task.async(fn -> Generation.prepare(store, routes(String.duplicate("x", 500_000))) end)
    messages = pending_calls(store, Gaoxy.Lifecycle.deadline(1_000))
    :ok = :sys.resume(store)
    assert {:ok, %Router{}} = Task.await(task, 1_000)
    assert messages != []
    sizes = Enum.map(messages, &:erlang.external_size/1)
    assert Enum.all?(sizes, &(&1 < 1024))
  end

  test "a departing caller terminates its preparation before capacity is reused" do
    store = start_supervised!({Generation, routes: routes(:old)})
    owner = self()
    caller = spawn(fn -> Generation.prepare(store, routes({:wait, owner})) end)
    assert_receive {:preparing, preparing}, 1_000
    monitor = Process.monitor(preparing)
    Process.exit(caller, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^preparing, :killed}, 1_000
    assert {:ok, %Router{}} = available_prepare(store, Gaoxy.Lifecycle.deadline(1_000))
  end

  test "oversized activation is rejected before its payload crosses to the owner" do
    store = start_supervised!({Generation, routes: routes(:old)})
    assert {:ok, original, router} = Generation.snapshot(store)

    candidate = %{
      router
      | generation: make_ref(),
        routes: routes(String.duplicate("x", 2_000_000))
    }

    :ok = :sys.suspend(store)
    task = Task.async(fn -> Generation.activate(store, original, candidate) end)
    messages = pending_calls(store, Gaoxy.Lifecycle.deadline(1_000))
    :ok = :sys.resume(store)
    assert {:error, :configuration_too_large} = Task.await(task, 1_000)
    assert messages != []
    sizes = Enum.map(messages, &:erlang.external_size/1)
    assert Enum.all?(sizes, &(&1 < 1024))
    assert {:ok, ^original, ^router} = Generation.snapshot(store)
  end

  test "a live listener keeps its port while old and new requests retain different snapshots" do
    initial = page("old")
    store = start_supervised!({Generation, routes: initial})
    assert {:ok, original, _} = Generation.snapshot(store)

    {:ok, server} =
      Gaoxy.HTTP.start_link(endpoint: {Generation, store}, limits: %{max_bytes: 8_388_608})

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    before = Gaoxy.info(server, :http)
    {:ok, {ip, port}} = before.local
    {:ok, first} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)
    on_exit(fn -> :gen_tcp.close(first) end)

    :ok =
      :gen_tcp.send(first, "GET /hold HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")

    assert_receive {:selected, request_owner, token, "old"}, 1_000

    assert {:ok, prepared} = Generation.prepare(store, page("new"))
    assert {:ok, _} = Generation.activate(store, original, prepared)
    assert Gaoxy.info(server, :http).local == before.local
    {:ok, second} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)
    on_exit(fn -> :gen_tcp.close(second) end)
    :ok = :gen_tcp.send(second, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    assert receive_all(second) =~ "\r\n\r\nnew"
    send(request_owner, {:release, token})
    assert receive_all(first) =~ "\r\n\r\nold"
  end

  defp routes(options), do: [%{target: {Target, options}}]

  defp page(label),
    do: [%{target: {PlugEndpoint, {Page, %{label: label, owner: self()}}}}]

  defp receive_all(socket, acc \\ "") do
    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, bytes} -> receive_all(socket, acc <> bytes)
      {:error, :closed} -> acc
    end
  end

  defp pending_calls(store, deadline) do
    {:messages, messages} = Process.info(store, :messages)

    if messages != [] or Gaoxy.Lifecycle.remaining(deadline) == 0 do
      messages
    else
      receive do
      after
        1 -> pending_calls(store, deadline)
      end
    end
  end

  defp available_prepare(store, deadline) do
    case Generation.prepare(store, routes(:new)) do
      {:error, :preparation_busy} = result ->
        if Gaoxy.Lifecycle.remaining(deadline) > 0 do
          receive do
          after
            1 -> available_prepare(store, deadline)
          end
        else
          result
        end

      result ->
        result
    end
  end
end
