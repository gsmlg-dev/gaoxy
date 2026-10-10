defmodule Gaoxy.HTTP.GenerationLoaderTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Generation, Router}

  test "trusted loader uses the one preparation worker and total deadline while snapshots remain responsive" do
    store = start_supervised!({Generation, []})
    assert {:ok, generation, router} = Generation.snapshot(store)
    parent = self()

    loader = fn ->
      send(parent, {:loading, self()})

      receive do
        :loaded -> {:ok, []}
      end
    end

    task = Task.async(fn -> Generation.prepare_with(store, loader, 100) end)
    assert_receive {:loading, worker}, 1_000
    refute worker == parent
    monitor = Process.monitor(worker)
    assert {:ok, ^generation, ^router} = Generation.snapshot(store)
    assert {:error, :preparation_busy} = Generation.prepare_with(store, fn -> {:ok, []} end, 100)
    assert {:error, :prepare_timeout} = Task.await(task, 1_000)
    assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, 1_000
    assert {:ok, %Router{routes: []}} = Generation.prepare_with(store, fn -> {:ok, []} end, 100)
  end

  test "caller death terminates its loader before the preparation slot is reusable" do
    store = start_supervised!({Generation, []})
    parent = self()

    caller =
      spawn(fn ->
        Generation.prepare_with(
          store,
          fn ->
            send(parent, {:loading, self()})

            receive do
              :loaded -> {:ok, []}
            end
          end,
          1_000
        )
      end)

    assert_receive {:loading, worker}, 1_000
    monitor = Process.monitor(worker)
    Process.exit(caller, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, 1_000
    assert {:ok, %Router{}} = available(store, Gaoxy.Lifecycle.deadline(1_000))
  end

  test "loader closures and loaded routes are bounded and malformed results do not alter the router" do
    store = start_supervised!({Generation, max_config_bytes: 1_024})
    assert {:ok, generation, router} = Generation.snapshot(store)
    captured = String.duplicate("x", 2_048)

    assert {:error, :configuration_too_large} =
             Generation.prepare_with(store, fn -> {:ok, [captured]} end, 100)

    assert {:error, :invalid_generation_loader} = Generation.prepare_with(store, :invalid, 100)

    assert {:error, :invalid_prepare_timeout} =
             Generation.prepare_with(store, fn -> {:ok, []} end, 0)

    assert {:error, :invalid_loader_result} =
             Generation.prepare_with(store, fn -> :malformed end, 100)

    assert {:error, :invalid_routes} =
             Generation.prepare_with(store, fn -> {:ok, :malformed} end, 100)

    assert {:error, :endpoint_preparation_failed} =
             Generation.prepare_with(store, fn -> raise "loader failure" end, 100)

    assert {:ok, ^generation, ^router} = Generation.snapshot(store)
  end

  defp available(store, deadline) do
    case Generation.prepare_with(store, fn -> {:ok, []} end, 100) do
      {:error, :preparation_busy} ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0

        receive do
        after
          1 -> available(store, deadline)
        end

      result ->
        result
    end
  end
end
