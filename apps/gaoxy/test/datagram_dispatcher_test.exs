defmodule Gaoxy.DatagramDispatcherTest do
  use ExUnit.Case, async: true

  defmodule Dispatcher do
    def validate_options(%{owner: owner}) when is_pid(owner), do: {:ok, %{owner: owner}}
    def validate_options(_), do: {:error, :invalid_options}
    def validate_service(options, _spec), do: {:ok, options}

    def start_link(context, %{owner: owner}) do
      pid =
        spawn_link(fn ->
          receive do
            :stop -> :ok
          end
        end)

      send(owner, {:started, pid, context})
      {:ok, pid}
    end

    def offer(owner, packet) do
      send(owner, {:packet, packet})
      {:ok, owner}
    end

    def control(_, _, _), do: :ok
    def drain(_, _), do: :ok
  end

  defmodule BlockedDispatcher do
    defdelegate validate_options(options), to: Dispatcher
    defdelegate validate_service(options, spec), to: Dispatcher
    defdelegate offer(owner, packet), to: Dispatcher
    defdelegate control(owner, action, generation), to: Dispatcher
    defdelegate drain(owner, deadline), to: Dispatcher

    def start_link(_, %{owner: owner}) do
      send(owner, {:dispatcher_start_blocked, self()})

      receive do
        :never -> {:error, :fixture}
      end
    end
  end

  defp spec(extra \\ %{}) do
    Map.merge(
      %{
        id: "dispatcher",
        transport: :udp,
        handler_mode: :datagram_dispatcher,
        handler: Dispatcher,
        handler_options: %{owner: self()}
      },
      extra
    )
  end

  test "dispatcher validation is strict, opt in, unicast only, and idempotent" do
    assert {:ok, normalized} = Gaoxy.Config.service(spec())
    assert %{max_queue: 32, max_bytes: 262_144, handoff_timeout: 50} = normalized.dispatcher
    assert {:ok, ^normalized} = Gaoxy.Config.service(normalized)

    assert {:error, :dispatcher_requires_udp_unicast} =
             Gaoxy.Config.service(spec(%{transport: :tcp}))

    assert {:error, :dispatcher_requires_udp_unicast} =
             Gaoxy.Config.service(spec(%{mode: :multicast}))

    assert {:error, :invalid_dispatcher_options} =
             Gaoxy.Config.service(spec(%{dispatcher: %{max_queue: :infinity}}))

    assert {:error, {:unknown_options, [:module]}} =
             Gaoxy.Config.service(spec(%{dispatcher: %{module: Dispatcher}}))

    assert {:error, {:handler_options, :invalid_options}} =
             Gaoxy.Config.service(spec(%{handler_options: []}))

    assert {:error, :invalid_handler} = Gaoxy.Config.service(spec(%{handler: Gaoxy.Config}))
  end

  test "bridge preserves separate generations and bounded metadata without exporting socket" do
    assert {:ok, spec} = Gaoxy.Config.service(spec())
    service_generation = make_ref()
    writer_generation = make_ref()
    startup_token = make_ref()

    context = %{
      spec: spec,
      gate: self(),
      scope: %{generation: service_generation},
      service: self(),
      instance: self(),
      startup_token: startup_token
    }

    capability = %{generation: writer_generation}

    assert {:ok, state} =
             Gaoxy.DatagramDispatcherBridge.init(
               %{
                 generation: writer_generation,
                 local_info: {{127, 0, 0, 1}, 9000},
                 send: capability
               },
               gaoxy: context
             )

    assert_receive {:started, owner, merged}
    assert merged.generation == service_generation
    assert merged.writer_generation == writer_generation
    assert merged.send == capability
    refute Map.has_key?(merged, :socket)
    assert_receive {:gaoxy_dispatcher_ready, ^service_generation, ^startup_token, ^owner}

    datagram_context = %{
      state: state,
      generation: writer_generation,
      local: self(),
      send: capability,
      routes: %{},
      ancillary: [],
      local_info: {{127, 0, 0, 1}, 9000}
    }

    assert {:new, [{^service_generation, ^writer_generation, {127, 0, 0, 1}, 1234}], ^owner,
            ^state} =
             Gaoxy.DatagramDispatcherBridge.handle_datagram(
               {{127, 0, 0, 1}, 1234},
               "",
               123,
               datagram_context
             )

    Gaoxy.DatagramDispatcherBridge.terminate(:normal, state)
    send(owner, :stop)
  end

  test "blocked dispatcher initialization has a finite deadline and rolls back its bind" do
    {:ok, probe} = :gen_udp.open(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {ip, port}} = :inet.sockname(probe)
    :gen_udp.close(probe)
    started = Gaoxy.Lifecycle.now()
    owner = self()

    input =
      spec(%{handler: BlockedDispatcher, ip: ip, port: port, limits: %{callback_timeout: 50}})

    runner =
      spawn(fn ->
        send(owner, {:dispatcher_start_result, Gaoxy.start_link(services: [input])})
      end)

    assert_receive {:dispatcher_start_blocked, blocked}, 500

    on_exit(fn ->
      monitor = Process.monitor(runner)
      send(blocked, :never)

      receive do
        {:DOWN, ^monitor, :process, ^runner, _} -> :ok
      after
        1_000 -> Process.exit(runner, :kill)
      end
    end)

    assert_receive {:dispatcher_start_result, {:error, _}}, 800
    assert Gaoxy.Lifecycle.now() - started < 1_000
    assert {:ok, socket} = :gen_udp.open(port, [:binary, active: false, ip: ip])
    :gen_udp.close(socket)
  end
end
