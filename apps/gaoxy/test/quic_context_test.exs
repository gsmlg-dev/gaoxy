defmodule Gaoxy.QUICContextTest do
  use ExUnit.Case, async: false
  alias Gaoxy.{Admission, QUICBridge}

  defmodule Handler do
    def init(connection, _, observer) do
      send(observer, {:quic_context, connection})
      {:ok, %{}}
    end

    def handle_event(_, state), do: {:ok, state}
  end

  defmodule ContextOwner do
    use Hell.Handler
    def validate_options(options), do: {:ok, options}

    def handle_connection(_, state) do
      send(state.spec.handler_options.owner, {:native_context, state})
      {:continue, state}
    end
  end

  test "callback death retains native byte ownership and connection quota until exact closed proof" do
    {:ok, runtime} =
      Gaoxy.start_link(
        services: [
          %{
            id: :native_fixture,
            transport: :tcp,
            handler_mode: :native,
            handler: ContextOwner,
            handler_options: %{owner: self()},
            limits: %{max_connections: 1, drain_timeout: 2_000}
          }
        ]
      )

    {:ok, {ip, port}} = Gaoxy.info(runtime, :native_fixture).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)

    on_exit(fn ->
      :gen_tcp.close(socket)
      if Process.alive?(runtime), do: Gaoxy.stop(runtime, 3_000)
    end)

    assert_receive {:native_context, context}, 1_000

    metadata = %{
      resources: %{
        queued_bytes: 10,
        ready_bytes: 20,
        receive_buffered_bytes: 30,
        io_queue_bytes: 40,
        operation_result_bytes: 50
      }
    }

    {:ok, proof} = Agent.start(fn -> {:ok, metadata} end)

    on_exit(fn ->
      if Process.alive?(proof) do
        Agent.update(proof, fn _ -> {:error, :closed} end)
        Process.sleep(10)
        Agent.stop(proof)
      end
    end)

    observer = self()
    context = %{context | spec: %{context.spec | handler: Handler, handler_options: observer}}

    callback =
      spawn(fn ->
        {:ok, state} = QUICBridge.init(:controlled_native_handle, metadata, context)
        send(observer, {:bridge_ready, self(), state})

        receive do
          :finish -> :ok
        end
      end)

    on_exit(fn -> if Process.alive?(callback), do: Process.exit(callback, :kill) end)
    assert_receive {:bridge_ready, ^callback, _}, 1_000
    assert %{active_connections: 1, active_requests: 0} = Gaoxy.resource_budget(runtime)
    # Only our guardian's public observation seam is controlled; no engine PID
    # or private QUIC state is extracted or suspended. On the old implementation
    # no guardian exists and the native charge disappears on callback DOWN.
    for {_, cleanup} <- :sys.get_state(context.service).cleanups do
      :sys.replace_state(cleanup.guardian, fn state ->
        Map.put(state, :probe, fn connection ->
          assert connection.handle == :controlled_native_handle
          result = Agent.get(proof, & &1)
          send(observer, {:native_probe, result})
          result
        end)
      end)
    end

    monitor = Process.monitor(callback)
    Process.exit(callback, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^callback, :killed}, 1_000
    eventually(fn -> Admission.status(context.gate).active == 0 end)
    budget = Gaoxy.resource_budget(runtime)
    assert budget.usage >= 150
    assert budget.active_connections == 1
    assert budget.active_requests == 0
    assert %{cleanup_pending: 1} = Admission.status(context.gate)

    assert {:error, :connection_limit} =
             Admission.acquire(context.gate, 0,
               kind: :connection,
               memberships: %{connection: make_ref()}
             )

    for unconfirmed <- [
          {:error, :timeout},
          {:error, {:closed, :timeout}},
          :ok,
          {:ok, %{resources: %{queued_bytes: 0}}},
          {:error, :unavailable}
        ] do
      Agent.update(proof, fn _ -> unconfirmed end)
      assert_receive {:native_probe, ^unconfirmed}, 1_000
      assert %{active_connections: 1, usage: retained} = Gaoxy.resource_budget(runtime)
      assert retained >= 150
      assert %{cleanup_pending: 1} = Admission.status(context.gate)
    end

    Agent.update(proof, fn _ -> {:error, :closed} end)

    eventually(fn ->
      budget = Gaoxy.resource_budget(runtime)
      budget.usage == 0 and budget.active_connections == 0 and budget.leases == 0
    end)

    assert %{cleanup_pending: 0} = Admission.status(context.gate)
    assert :sys.get_state(context.service).cleanup_failed == nil
  end

  defp eventually(fun, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(2_000)

    unless fun.() do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0
      Process.sleep(1)
      eventually(fun, deadline)
    end
  end

  test "QUIC callback receives runtime owners separately from telemetry identity" do
    {:ok, runtime} =
      Gaoxy.start_link(
        services: [
          %{
            id: :context_fixture,
            transport: :tcp,
            handler_mode: :native,
            handler: ContextOwner,
            handler_options: %{owner: self()}
          }
        ]
      )

    {:ok, {ip, port}} = Gaoxy.info(runtime, :context_fixture).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)
    assert_receive {:native_context, context}, 1_000
    context = %{context | spec: %{context.spec | handler: Handler, handler_options: self()}}

    on_exit(fn ->
      :gen_tcp.close(socket)
      if Process.alive?(runtime), do: Gaoxy.stop(runtime, 2_000)
    end)

    assert {:ok, state} =
             QUICBridge.init(
               :opaque_handle,
               %{
                 resources: %{
                   queued_bytes: 0,
                   ready_bytes: 0,
                   receive_buffered_bytes: 0,
                   io_queue_bytes: 0,
                   operation_result_bytes: 0
                 }
               },
               context
             )

    assert_receive {:quic_context, connection}
    assert Map.get(connection, :service) == context.service
    assert Map.get(connection, :instance) == context.instance
    assert connection.scope == context.scope
    assert state.connection == connection
    {guardian, token} = connection.native_cleanup
    :sys.replace_state(guardian, &Map.put(&1, :probe, fn _ -> {:error, :closed} end))
    send(guardian, {:gaoxy_native_closed, token})
    eventually(fn -> Admission.status(context.gate).cleanup_pending == 0 end)
  end

  @tag :tmp_dir
  test "raw QUIC pull credit leaves room for native results without changing administrator caps",
       %{
         tmp_dir: directory
       } do
    tls = certificates(directory)

    for {id, limits, window, capacity, cap} <- [
          {:explicit, %{max_active: 4, max_packet: 4096, max_bytes: 262_144}, 4096, 262_144,
           262_144},
          {:default, %{}, 16_384, 16_777_216, nil},
          {:small, %{max_bytes: 1024}, 1024, 1024, 1024}
        ] do
      {runtime, service, host} = quic_host(id, Handler, tls, limits)
      streams = host.quic_options[:streams]
      assert streams[:max_data] == window
      assert streams[:max_stream_data] == window
      assert streams[:max_buffer] == capacity
      assert streams[:max_ready_bytes] == capacity
      assert host.writer_max_bytes == capacity
      refute Keyword.has_key?(host.quic_options, :operation_limit)
      refute Keyword.has_key?(host.quic_options, :idle_timeout)
      assert service.spec.budget_policy.max_bytes == cap

      assert service.spec.budget_policy.provenance.max_bytes ==
               if(cap, do: :explicit, else: :omitted)

      assert :ok = Gaoxy.stop(runtime, 2_000)
    end
  end

  @tag :tmp_dir
  test "HTTP3 retains its independent native receive and idle profile", %{tmp_dir: directory} do
    tls = certificates(directory)

    for {id, limits, capacity, cap} <- [
          {:h3_explicit, %{max_bytes: 262_144}, 262_144, 262_144},
          {:h3_default, %{}, 16_777_216, nil}
        ] do
      {runtime, service, host} = quic_host(id, Gaoxy.HTTP.HTTP3.Connection, tls, limits)
      streams = host.quic_options[:streams]
      assert streams[:max_data] == capacity
      assert streams[:max_stream_data] == capacity
      assert streams[:max_buffer] == capacity
      assert streams[:max_ready_bytes] == capacity
      assert host.writer_max_bytes == capacity
      assert host.quic_options[:idle_timeout] == :infinity
      refute Keyword.has_key?(host.quic_options, :operation_limit)
      assert service.spec.budget_policy.max_bytes == cap
      assert :ok = Gaoxy.stop(runtime, 2_000)
    end
  end

  defp certificates(directory) do
    root = Path.expand("../../..", __DIR__)

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), directory])

    %{certfile: Path.join(directory, "cert.pem"), keyfile: Path.join(directory, "key.pem")}
  end

  defp quic_host(id, handler, tls, limits) do
    {:ok, runtime} =
      Gaoxy.start_link(
        services: [
          %{
            id: id,
            transport: :quic,
            handler: handler,
            tls: tls,
            quic: %{alpn: ["h3"]},
            limits: limits
          }
        ]
      )

    on_exit(fn -> if Process.alive?(runtime), do: Gaoxy.stop(runtime, 2_000) end)
    {:ok, service, _} = GenServer.call(runtime, {:lookup, id})
    state = :sys.get_state(service)
    {runtime, state, :sys.get_state(state.backend)}
  end

  test "QUIC keepalive rejects unbounded and duplicate operation options before backend access" do
    connection = %Gaoxy.QUIC.Connection{
      handle: :unused,
      gate: self(),
      lease: make_ref(),
      limits: %{callback_timeout: 50},
      scope: %{}
    }

    for options <- [
          [timeout: :infinity],
          [timeout: 0],
          [timeout: 51],
          [deadline: :infinity],
          [timeout: 1, timeout: 2],
          [unknown: true]
        ] do
      assert {:error, :invalid_operation_options} = Gaoxy.QUIC.ping(connection, options)
    end
  end
end
