defmodule Gaoxy.ResourceBudget.SystemMemoryNativeTest do
  use ExUnit.Case, async: false
  alias Gaoxy.ResourceBudget.SystemMemory.Native

  test "physical system capacity is selected independently of free and available memory" do
    assert {:ok, 8_589_934_592} =
             Native.probe(
               fn ->
                 [system_total_memory: 8_589_934_592, total_memory: 4_294_967_296, free_memory: 1]
               end,
               100
             )
  end

  test "unavailable or ambiguous physical system capacity is rejected" do
    for data <- [
          [],
          [total_memory: 1024],
          [system_total_memory: 1],
          [system_total_memory: 9_223_372_036_854_775_808],
          [system_total_memory: 2048, system_total_memory: 4096]
        ] do
      assert {:error, :invalid_native_memory} = Native.probe(fn -> data end, 100)
    end
  end

  test "timeout confirms the probe worker died before returning" do
    parent = self()

    assert {:error, :timeout} =
             Native.probe(
               fn ->
                 Process.flag(:trap_exit, true)
                 send(parent, {:probe_worker, self()})

                 receive do
                   :release -> [system_total_memory: 2048]
                 end
               end,
               20
             )

    assert_receive {:probe_worker, worker}
    refute Process.alive?(worker)
    assert Process.info(self(), :messages) == {:messages, []}
  end

  test "successful probes finish their worker before returning" do
    parent = self()

    assert {:ok, 2048} =
             Native.probe(
               fn ->
                 send(parent, {:probe_worker, self()})
                 [system_total_memory: 2048]
               end,
               100
             )

    assert_receive {:probe_worker, worker}
    refute Process.alive?(worker)
    assert Process.info(self(), :messages) == {:messages, []}
  end

  test "raised native queries report failure without leaving a worker" do
    parent = self()

    assert {:error, :native_probe_failed} =
             Native.probe(
               fn ->
                 send(parent, {:probe_worker, self()})
                 raise "native query failed"
               end,
               100
             )

    assert_receive {:probe_worker, worker}
    refute Process.alive?(worker)
    assert Process.info(self(), :messages) == {:messages, []}
  end

  test "expired probe replies cannot accumulate or prevent the next successful probe" do
    for _ <- 1..5 do
      assert {:error, :timeout} =
               Native.probe(
                 fn ->
                   receive do
                     :release -> []
                   end
                 end,
                 1
               )

      assert {:ok, 4096} = Native.probe(fn -> [system_total_memory: 4096] end, 100)
    end

    assert Process.info(self(), :messages) == {:messages, []}
  end

  test "caller death terminates its query and cleanup owner even when the query traps exits" do
    parent = self()

    caller =
      spawn(fn ->
        Native.probe(
          fn ->
            Process.flag(:trap_exit, true)
            {:links, [owner]} = Process.info(self(), :links)
            send(parent, {:probe_owned, self(), owner})

            receive do
              :release -> [system_total_memory: 2048]
            end
          end,
          2_000
        )
      end)

    assert_receive {:probe_owned, query, owner}
    monitors = for pid <- [caller, query, owner], do: {pid, Process.monitor(pid)}
    Process.exit(caller, :kill)

    for {pid, monitor} <- monitors do
      assert_receive {:DOWN, ^monitor, :process, ^pid, _}, 1_000
      refute Process.alive?(pid)
    end

    assert Process.info(self(), :messages) == {:messages, []}
  end

  test "a killed native query reports failure without taking down its caller" do
    assert {:error, :native_probe_failed} =
             Native.probe(fn -> Process.exit(self(), :kill) end, 100)

    assert Process.info(self(), :messages) == {:messages, []}
  end

  test "the public OTP memory facility reuses its supervised helper across capacity probes" do
    owner = Process.whereis(:memsup)
    assert is_pid(owner)

    assert Enum.any?(Supervisor.which_children(:os_mon_sup), fn {_, pid, _, _} -> pid == owner end)

    assert {:ok, capacity} = Native.capacity(:darwin)
    assert capacity >= 2
    ports = memory_ports()
    assert ports != []

    assert {:ok, ^capacity} = Native.capacity(:windows)
    assert Process.whereis(:memsup) == owner
    assert memory_ports() == ports
  end

  defp memory_ports do
    :erlang.ports()
    |> Enum.filter(fn port ->
      case Port.info(port, :name) do
        {:name, name} ->
          basename = name |> to_string() |> String.trim("\"") |> Path.basename()
          basename in ["memsup", "win32sysinfo.exe"]

        nil ->
          false
      end
    end)
    |> Enum.sort()
  end
end
