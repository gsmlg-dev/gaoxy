defmodule Gaoxy.SendOutcomeTest do
  use ExUnit.Case, async: true
  @moduletag :loopback
  @output_size 16 * 1_048_576

  defmodule Output do
    @behaviour Gaoxy.StreamHandler
    def init(_, options), do: {:ok, options}

    def handle_data(_, %{owner: owner, output: output} = state) do
      send(owner, {:sending_worker, self()})
      {:send, :ets.lookup_element(output, :bytes, 2), state}
    end
  end

  defmodule Echo do
    @behaviour Gaoxy.StreamHandler
    def init(_, options), do: {:ok, options}
    def handle_data(bytes, state), do: {:send, bytes, state}
  end

  defp fixture do
    # Fixture generation can exceed the 500ms callback budget before any send.
    # Prepare bytes outside that budget; retain only a table reference as state.
    output = :ets.new(__MODULE__, [:set, :protected])
    :ets.insert(output, {:bytes, :binary.copy("x", @output_size)})

    runtime =
      start_supervised!(
        {Gaoxy,
         services: [
           %{
             id: "blocked",
             transport: :tcp,
             handler: Output,
             handler_options: %{owner: self(), output: output},
             limits: %{
               max_active: 1,
               max_output: @output_size,
               max_bytes: @output_size + 65_536,
               callback_timeout: 500
             }
           },
           %{id: "live", transport: :tcp, handler: Echo}
         ]}
      )

    %{generation: generation, local: {:ok, {ip, port}}} = Gaoxy.info(runtime, "blocked")
    reference = make_ref()
    owner = self()

    :ok =
      :telemetry.attach_many(
        reference,
        [[:gaoxy, :send_started], [:gaoxy, :send]],
        fn event, measurements, metadata, _ ->
          if metadata.generation == generation,
            do: send(owner, {reference, event, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(reference) end)
    on_exit(fn -> if Process.alive?(runtime), do: Gaoxy.stop(runtime, 0) end)
    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false, recbuf: 1_024])
    on_exit(fn -> :gen_tcp.close(client) end)
    :ok = :gen_tcp.send(client, "begin")
    assert_receive {:sending_worker, worker}, 2_000
    {runtime, client, worker, reference}
  end

  test "blocked real TCP output has a referenced uncertain outcome without retransmission" do
    {runtime, client, worker, reference} = fixture()
    monitor = Process.monitor(worker)

    # The inet driver can accept the first output into its local queue. Fill it
    # through a completed operation before asserting a subsequent blocked send.
    assert_receive {^reference, [:gaoxy, :send_started], %{bytes: @output_size},
                    %{operation: first}},
                   2_000

    assert_receive {^reference, [:gaoxy, :send], %{bytes: @output_size},
                    %{operation: ^first, outcome: :ok}},
                   2_000

    :ok = :gen_tcp.send(client, "again")
    assert_receive {:sending_worker, ^worker}, 2_000

    assert_receive {^reference, [:gaoxy, :send_started], %{bytes: @output_size},
                    %{operation: operation}},
                   2_000

    assert is_reference(operation)
    assert_blocked_with_live_sibling(runtime, worker)

    assert_receive {^reference, [:gaoxy, :send], %{bytes: @output_size},
                    %{operation: ^operation, outcome: {:unknown, _reason}}},
                   2_000

    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 2_000
    # Previously accepted bytes still reach the peer after a later send times
    # out. This does not identify how many bytes of the uncertain operation
    # arrived, and the runtime must not claim that it was definitely unsent.
    assert {:ok, "x"} = :gen_tcp.recv(client, 1, 2_000)
    eventually(fn -> Gaoxy.status(runtime, "blocked").active == 0 end)
    assert %{retained_bytes: 0, retained_high_water: retained} = Gaoxy.status(runtime, "blocked")
    assert retained <= @output_size + 65_536
    refute_receive {^reference, [:gaoxy, :send_started], _, _}, 100
    refute_receive {^reference, [:gaoxy, :send], _, _}, 100
  end

  test "forced drain preserves the pending operation reference and emits one unknown outcome" do
    {runtime, client, worker, reference} = fixture()
    monitor = Process.monitor(worker)
    assert_receive {^reference, [:gaoxy, :send_started], _, %{operation: first}}, 2_000
    assert_receive {^reference, [:gaoxy, :send], _, %{operation: ^first, outcome: :ok}}, 2_000
    :ok = :gen_tcp.send(client, "again")
    assert_receive {:sending_worker, ^worker}, 2_000
    assert_receive {^reference, [:gaoxy, :send_started], _, %{operation: operation}}, 2_000
    assert_blocked_with_live_sibling(runtime, worker)
    started = System.monotonic_time(:millisecond)
    assert {:error, {:deadline_exceeded, :cleanup_pending}} = Gaoxy.remove(runtime, "blocked", 10)
    assert System.monotonic_time(:millisecond) - started < 500

    assert_receive {^reference, [:gaoxy, :send], %{bytes: @output_size},
                    %{operation: ^operation, outcome: {:unknown, _}}},
                   2_000

    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 2_000
    eventually(fn -> Gaoxy.info(runtime, "blocked") == {:error, :not_running} end)
    refute_receive {^reference, [:gaoxy, :send], _, _}, 100
  end

  defp assert_blocked_with_live_sibling(runtime, worker) do
    # Observe the actual inet send wait, beyond the pre-submission telemetry event.
    eventually(fn ->
      Process.info(worker, :current_function) == {:current_function, {:prim_inet, :send, 4}}
    end)

    %{local: {:ok, {ip, port}}} = Gaoxy.info(runtime, "live")
    {:ok, sibling} = :gen_tcp.connect(ip, port, [:binary, active: false])
    on_exit(fn -> :gen_tcp.close(sibling) end)
    :ok = :gen_tcp.send(sibling, "still-running")
    assert {:ok, "still-running"} = :gen_tcp.recv(sibling, 0, 2_000)
    assert Process.alive?(worker)
    :gen_tcp.close(sibling)
  end

  defp eventually(predicate, deadline \\ nil) do
    deadline = deadline || System.monotonic_time(:millisecond) + 2_000

    if predicate.() do
      :ok
    else
      assert System.monotonic_time(:millisecond) < deadline

      receive do
      after
        5 -> eventually(predicate, deadline)
      end
    end
  end
end
