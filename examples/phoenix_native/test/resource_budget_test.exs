defmodule PhoenixNative.ResourceBudgetTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.HTTP2.Frame
  alias HTTP.HTTP2.HPACK

  @coordinator __MODULE__.Coordinator
  @policy %{soft_limit: 16_777_216, hard_limit: 33_554_432}
  @timeout 3_000

  defmodule HoldPlug do
    def init(marker), do: marker

    def call(conn, marker) do
      send(
        Process.whereis(PhoenixNative.ResourceBudgetTest.Coordinator),
        {:budget_request, marker, self()}
      )

      receive do
        :budget_reply -> Plug.Conn.send_resp(conn, 200, "shared-budget")
      after
        2_000 -> Plug.Conn.send_resp(conn, 504, "fixture-timeout")
      end
    end
  end

  defmodule FirstEndpoint do
    use Phoenix.Endpoint, otp_app: :phoenix_native
    plug(PhoenixNative.ResourceBudgetTest.HoldPlug, :first)
  end

  defmodule SecondEndpoint do
    use Phoenix.Endpoint, otp_app: :phoenix_native
    plug(PhoenixNative.ResourceBudgetTest.HoldPlug, :second)
  end

  defmodule H2HoldPlug do
    def init(options), do: options

    def call(conn, _) do
      send(
        Process.whereis(PhoenixNative.ResourceBudgetTest.Coordinator),
        {:phoenix_h2_request, conn.request_path, self()}
      )

      receive do
        :budget_reply -> Plug.Conn.send_resp(conn, 200, "phoenix:" <> conn.request_path)
      after
        3_000 -> Plug.Conn.send_resp(conn, 504, "fixture-timeout")
      end
    end
  end

  defmodule H2Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix_native
    plug(PhoenixNative.ResourceBudgetTest.H2HoldPlug)
  end

  defmodule MixedHoldPlug do
    def init(options), do: options

    def call(conn, _) do
      send(
        Process.whereis(PhoenixNative.ResourceBudgetTest.Coordinator),
        {:phoenix_mixed_request, conn.request_path, self()}
      )

      receive do
        :budget_reply -> Plug.Conn.send_resp(conn, 200, "mixed:" <> conn.request_path)
      after
        10_000 -> Plug.Conn.send_resp(conn, 504, "fixture-timeout")
      end
    end
  end

  defmodule MixedEndpoint do
    use Phoenix.Endpoint, otp_app: :phoenix_native
    plug(PhoenixNative.ResourceBudgetTest.MixedHoldPlug)
  end

  setup do
    Process.register(self(), @coordinator)
    :ok
  end

  @tag :tmp_dir
  test "two real Phoenix Endpoints each own mixed listeners in the shared VM pool", %{
    tmp_dir: dir
  } do
    root = Path.expand("../../..", __DIR__)

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), dir],
               stderr_to_stdout: true
             )

    for endpoint <- [FirstEndpoint, SecondEndpoint] do
      previous = Application.fetch_env(:phoenix_native, endpoint)

      on_exit(fn ->
        case previous do
          {:ok, config} -> Application.put_env(:phoenix_native, endpoint, config)
          :error -> Application.delete_env(:phoenix_native, endpoint)
        end
      end)

      Application.put_env(:phoenix_native, endpoint,
        adapter: Gaoxy.PhoenixAdapter,
        server: true,
        secret_key_base: String.duplicate("fixture-budget-secret-", 4),
        resource_budget: @policy,
        http: [ip: {127, 0, 0, 1}, port: 0],
        https: [
          ip: {127, 0, 0, 1},
          port: 0,
          protocols: [:http1],
          certfile: Path.join(dir, "cert.pem"),
          keyfile: Path.join(dir, "key.pem")
        ]
      )

      start_supervised!(endpoint)
    end

    first = Gaoxy.PhoenixAdapter.listeners(FirstEndpoint)
    second = Gaoxy.PhoenixAdapter.listeners(SecondEndpoint)
    assert Enum.map(first.listeners, & &1.role) == [:http, :https]
    assert Enum.map(second.listeners, & &1.role) == [:http, :https]
    refute first.instance == second.instance
    a = connect(:gen_tcp, Gaoxy.PhoenixAdapter.server_info(FirstEndpoint, :http), [])

    b =
      connect(:ssl, Gaoxy.PhoenixAdapter.server_info(SecondEndpoint, :https),
        verify: :verify_peer,
        cacertfile: String.to_charlist(Path.join(dir, "ca.pem")),
        server_name_indication: ~c"localhost",
        alpn_advertised_protocols: ["http/1.1"]
      )

    exercise(first.instance, second.instance, {:gen_tcp, a}, {:ssl, b})
  end

  @tag :tmp_dir
  test "adaptive Phoenix defaults serve overlapping streams on two independent TLS H2 connections",
       %{tmp_dir: dir} do
    root = Path.expand("../../..", __DIR__)

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), dir],
               stderr_to_stdout: true
             )

    previous = Application.fetch_env(:phoenix_native, H2Endpoint)

    on_exit(fn ->
      case previous do
        {:ok, config} -> Application.put_env(:phoenix_native, H2Endpoint, config)
        :error -> Application.delete_env(:phoenix_native, H2Endpoint)
      end
    end)

    # Omit resource_budget, limits, max_bytes, max_active and protocol overrides.
    Application.put_env(:phoenix_native, H2Endpoint,
      adapter: Gaoxy.PhoenixAdapter,
      server: true,
      secret_key_base: String.duplicate("fixture-h2-budget-secret-", 4),
      https: [
        ip: {127, 0, 0, 1},
        port: 0,
        certfile: Path.join(dir, "cert.pem"),
        keyfile: Path.join(dir, "key.pem")
      ]
    )

    start_supervised!(H2Endpoint)
    %{instance: instance, listeners: [listener]} = Gaoxy.PhoenixAdapter.listeners(H2Endpoint)
    assert listener.role == :https
    assert listener.protocols == [:http2, :http1]

    budget = Gaoxy.resource_budget(instance)
    assert %{soft_limit: nil, hard_limit: nil, provenance: %{source: :adaptive}} = budget.policy
    assert budget.capacity == budget.detection.capacity

    if budget.detection.fallback? do
      assert budget.capacity == nil
      assert budget.soft_limit == 268_435_456
    else
      assert is_integer(budget.capacity) and budget.capacity >= 2
      assert budget.soft_limit == div(budget.capacity, 2)
    end

    assert budget.hard_limit == 2 * budget.soft_limit
    assert budget.vm.soft_limit == budget.soft_limit
    assert budget.vm.hard_limit == budget.hard_limit

    first = h2_connect(dir)
    second = h2_connect(dir)
    refute first == second
    h2_request(first, 1, "/first")
    h2_request(first, 3, "/sibling")
    h2_request(second, 1, "/second")
    workers = for path <- ["/first", "/sibling", "/second"], do: h2_worker(path)
    assert MapSet.size(MapSet.new(workers)) == 3
    assert Enum.all?(workers, &Process.alive?/1)

    assert %{
             active_connections: 2,
             active_requests: 3,
             active_h2_streams: 3,
             active_h3_streams: 0
           } =
             budget = Gaoxy.resource_budget(instance)

    assert budget.usage > 0
    assert budget.vm.usage >= budget.usage
    Enum.each(workers, &send(&1, :budget_reply))
    first_decoder = h2_responses(first, %{1 => "phoenix:/first", 3 => "phoenix:/sibling"})
    second_decoder = h2_responses(second, %{1 => "phoenix:/second"})

    await_budget(instance, %{active_connections: 2, active_requests: 0, active_h2_streams: 0})

    h2_request(first, 5, "/first-again")
    h2_request(second, 3, "/second-again")
    again = for path <- ["/first-again", "/second-again"], do: h2_worker(path)
    assert Enum.all?(again, &Process.alive?/1)

    assert %{active_connections: 2, active_requests: 2, active_h2_streams: 2} =
             Gaoxy.resource_budget(instance)

    Enum.each(again, &send(&1, :budget_reply))
    h2_responses(first, %{5 => "phoenix:/first-again"}, first_decoder)
    h2_responses(second, %{3 => "phoenix:/second-again"}, second_decoder)
    assert %{rejected: 0} = Gaoxy.status(instance, listener.id)
    assert :ok = :ssl.close(first)
    assert :ok = :ssl.close(second)

    await_budget(instance, %{
      usage: 0,
      active_connections: 0,
      active_requests: 0,
      active_h2_streams: 0,
      active_h3_streams: 0,
      pending_processes: 0,
      leases: 0
    })

    assert %{active: 0, retained_bytes: 0, cleanup_pending: 0} =
             Gaoxy.status(instance, listener.id)
  end

  @tag :tmp_dir
  test "adaptive Phoenix HTTP H1, TLS H2 and QUIC H3 share one instance and VM budget",
       %{tmp_dir: dir} do
    root = Path.expand("../../..", __DIR__)
    assert Code.ensure_loaded?(Gaoxy.HTTP.HTTP3.ListenerProvider), "run with PHOENIX_NATIVE_H3=1"

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), dir],
               stderr_to_stdout: true
             )

    previous = Application.fetch_env(:phoenix_native, MixedEndpoint)

    on_exit(fn ->
      case previous do
        {:ok, config} -> Application.put_env(:phoenix_native, MixedEndpoint, config)
        :error -> Application.delete_env(:phoenix_native, MixedEndpoint)
      end
    end)

    secure = [
      ip: {127, 0, 0, 1},
      port: 0,
      certfile: Path.join(dir, "cert.pem"),
      keyfile: Path.join(dir, "key.pem")
    ]

    # Every listener uses adaptive defaults; no per-listener capacity overrides.
    Application.put_env(:phoenix_native, MixedEndpoint,
      adapter: Gaoxy.PhoenixAdapter,
      server: true,
      secret_key_base: String.duplicate("fixture-mixed-budget-secret-", 4),
      http: [ip: {127, 0, 0, 1}, port: 0],
      https: secure,
      http3: secure
    )

    start_supervised!(MixedEndpoint)

    assert %{phase: :ready, instance: instance, listeners: listeners} =
             Gaoxy.PhoenixAdapter.listeners(MixedEndpoint)

    assert Enum.map(listeners, & &1.role) == [:http, :https, :http3]
    assert Enum.map(listeners, & &1.transport) == [:tcp, :tls, :quic]
    assert MapSet.size(MapSet.new(listeners, & &1.id)) == 3

    ports =
      Map.new(listeners, fn listener ->
        assert %{local: {:ok, {{127, 0, 0, 1}, port}}} = Gaoxy.info(instance, listener.id)
        assert port > 0
        {listener.role, port}
      end)

    initial = Gaoxy.resource_budget(instance)
    assert %{soft_limit: nil, hard_limit: nil, provenance: %{source: :adaptive}} = initial.policy
    assert initial.usage == 0
    assert initial.capacity == initial.detection.capacity

    if initial.detection.fallback? do
      assert initial.capacity == nil
      assert initial.soft_limit == 268_435_456
    else
      assert is_integer(initial.capacity) and initial.capacity >= 2
      assert initial.soft_limit == div(initial.capacity, 2)
    end

    assert initial.hard_limit == 2 * initial.soft_limit
    assert initial.vm.soft_limit == initial.soft_limit
    assert initial.vm.hard_limit == initial.hard_limit

    diagnostics = attach_mixed_diagnostics(instance, listeners)

    try do
      python = System.get_env("GAOXY_QUIC_PYTHON") || Path.join(root, ".audit/h2peer/bin/python")

      peer =
        Port.open(
          {:spawn_executable, String.to_charlist(python)},
          [
            :binary,
            :exit_status,
            :stderr_to_stdout,
            args: [
              "-c",
              mixed_peer_script(),
              to_string(ports.http),
              to_string(ports.https),
              to_string(ports.http3),
              Path.join(dir, "ca.pem")
            ],
            cd: root
          ]
        )

      on_exit(fn -> if Port.info(peer), do: Port.close(peer) end)

      {workers, output} =
        Enum.map_reduce(["/http", "/https", "/http3"], "", fn path, output ->
          output = await_mixed_worker(peer, path, output, Gaoxy.Lifecycle.deadline(10_000))
          assert_receive {:phoenix_mixed_request, ^path, worker}, 10_000
          {worker, output}
        end)

      assert MapSet.size(MapSet.new(workers)) == 3
      assert Enum.all?(workers, &Process.alive?/1)

      assert %{
               active_connections: 3,
               active_requests: 3,
               active_h2_streams: 1,
               active_h3_streams: 1,
               pending_processes: 0
             } = live = Gaoxy.resource_budget(instance)

      assert live.usage > 0
      assert live.soft_limit == initial.soft_limit
      assert live.hard_limit == initial.hard_limit
      assert live.vm.soft_limit == initial.vm.soft_limit
      assert live.vm.hard_limit == initial.vm.hard_limit
      assert live.vm.usage == initial.vm.usage + live.usage
      assert live.vm.connections == initial.vm.connections + 3
      assert live.vm.requests == initial.vm.requests + 3
      assert live.vm.h2_streams == initial.vm.h2_streams + 1
      assert live.vm.h3_streams == initial.vm.h3_streams + 1

      Enum.each(workers, &send(&1, :budget_reply))

      output =
        await_mixed_marker(
          peer,
          "PHOENIX_MIXED_RESPONSES_PASS",
          output,
          Gaoxy.Lifecycle.deadline(10_000)
        )

      await_budget(instance, %{
        active_connections: 3,
        active_requests: 0,
        active_h2_streams: 0,
        active_h3_streams: 0,
        pending_processes: 0
      })

      for listener <- listeners do
        assert %{rejected: 0} = Gaoxy.status(instance, listener.id)
      end

      assert Port.command(peer, "close\n")
      output = await_mixed_exit(peer, output, Gaoxy.Lifecycle.deadline(10_000))
      assert output =~ "PHOENIX_MIXED_CONNECTIONS_CLOSED"

      await_budget(instance, %{
        usage: 0,
        active_connections: 0,
        active_requests: 0,
        active_h2_streams: 0,
        active_h3_streams: 0,
        pending_processes: 0,
        leases: 0
      })

      for listener <- listeners do
        assert %{
                 active: 0,
                 retained_bytes: 0,
                 cleanup_pending: 0,
                 cleanup_failed: nil,
                 rejected: 0
               } =
                 Gaoxy.status(instance, listener.id)
      end

      final = Gaoxy.resource_budget(instance)

      for key <- [
            :usage,
            :connections,
            :requests,
            :h2_streams,
            :h3_streams,
            :pending_processes,
            :leases
          ] do
        assert Map.fetch!(final.vm, key) == Map.fetch!(initial.vm, key)
      end

      IO.puts(output)
    catch
      kind, reason ->
        stacktrace = __STACKTRACE__
        mixed_failure_diagnostics(instance, listeners, ports, diagnostics.events)
        :erlang.raise(kind, reason, stacktrace)
    after
      :telemetry.detach(diagnostics.handler)
      :ets.delete(diagnostics.events)
    end
  end

  defp attach_mixed_diagnostics(instance, listeners) do
    scopes =
      MapSet.new(listeners, fn listener ->
        %{id: id, generation: generation} = Gaoxy.handle(instance, listener.id)
        {id, generation}
      end)

    events = :ets.new(:phoenix_mixed_diagnostics, [:set, :public])
    :ets.insert(events, {:count, 0})
    handler = make_ref()
    on_exit(fn -> :telemetry.detach(handler) end)

    assert :ok =
             :telemetry.attach_many(
               handler,
               [[:gaoxy, :admission_rejected], [:gaoxy, :http3, :queue]],
               &__MODULE__.record_mixed_event/4,
               {events, scopes}
             )

    %{handler: handler, events: events}
  end

  @doc false
  def record_mixed_event(event, measurements, metadata, {events, scopes}) do
    if MapSet.member?(scopes, {metadata[:service], metadata[:generation]}) do
      # Keep the first 64 scoped events and the total observed count.
      index = :ets.update_counter(events, :count, {2, 1})
      if index <= 64, do: :ets.insert(events, {index, {event, measurements, metadata}})
    end

    :ok
  rescue
    # The test owner may exit while a final telemetry callback is in flight.
    ArgumentError -> :ok
  end

  defp mixed_failure_diagnostics(instance, listeners, ports, events) do
    IO.inspect(
      %{
        listeners: listeners,
        ports: ports,
        telemetry: Enum.sort(:ets.tab2list(events)),
        public: mixed_public_observations(instance, listeners)
      },
      label: "PHOENIX_MIXED_FAILURE_DIAGNOSTICS",
      limit: :infinity,
      printable_limit: 8_192
    )
  catch
    kind, reason ->
      IO.puts("PHOENIX_MIXED_DIAGNOSTICS_UNAVAILABLE #{inspect({kind, reason})}")
  end

  defp mixed_public_observations(instance, listeners) do
    owner = self()

    reads =
      [{:resource_budget, fn -> Gaoxy.resource_budget(instance) end}] ++
        Enum.map(listeners, fn listener ->
          {{:status, listener.role}, fn -> Gaoxy.status(instance, listener.id) end}
        end)

    observers =
      Enum.map(reads, fn {key, read} ->
        token = make_ref()

        {pid, monitor} =
          spawn_monitor(fn ->
            result =
              try do
                read.()
              catch
                kind, reason -> {:unavailable, kind, reason}
              end

            send(owner, {token, result})
          end)

        {key, pid, monitor, token}
      end)

    # Failure-only diagnostics never reopen or extend a peer/worker deadline.
    deadline = Gaoxy.Lifecycle.deadline(200)

    values =
      Map.new(observers, fn {key, _, _, token} ->
        value =
          receive do
            {^token, result} -> result
          after
            Gaoxy.Lifecycle.remaining(deadline) -> {:unavailable, :observer_timeout}
          end

        {key, value}
      end)

    Enum.each(observers, fn {_, pid, _, _} -> Process.exit(pid, :kill) end)
    cleanup_deadline = Gaoxy.Lifecycle.deadline(50)

    cleanup =
      Map.new(observers, fn {key, pid, monitor, _} ->
        result =
          receive do
            {:DOWN, ^monitor, :process, ^pid, reason} -> {:terminal, reason}
          after
            Gaoxy.Lifecycle.remaining(cleanup_deadline) ->
              Process.demonitor(monitor, [:flush])
              {:unavailable, :observer_cleanup_unconfirmed}
          end

        {key, result}
      end)

    %{values: values, observer_cleanup: cleanup}
  end

  defp await_mixed_worker(peer, path, output, deadline) do
    assert Gaoxy.Lifecycle.remaining(deadline) > 0,
           "mixed worker #{path} deadline expired: #{output}"

    receive do
      {:phoenix_mixed_request, ^path, _} = request ->
        # Preserve the original assertion below; its message is already present.
        send(self(), request)
        output

      {^peer, {:data, bytes}} ->
        await_mixed_worker(peer, path, output <> bytes, deadline)

      {^peer, {:exit_status, code}} ->
        flunk("mixed peer exited #{code} before worker #{path}: #{output}")
    after
      Gaoxy.Lifecycle.remaining(deadline) ->
        flunk("mixed worker #{path} timeout: #{output}")
    end
  end

  defp mixed_peer_script do
    ~S'''
    import asyncio
    import json
    import ssl
    import sys
    from types import SimpleNamespace

    import h2.connection
    import h2.events

    sys.path.insert(0, 'integration/http3')
    from peer import opened
    import peer
    from aioquic.quic.events import ConnectionTerminated

    class DiagnosticPeer(peer.Peer):
        def quic_event_received(self, event):
            if isinstance(event, ConnectionTerminated):
                print('PHOENIX_MIXED_QUIC_CLOSED ' + json.dumps({
                    'error_code': event.error_code,
                    'frame_type': event.frame_type,
                    'reason_phrase': event.reason_phrase,
                }), flush=True)
            super().quic_event_received(event)

    # opened() keeps its exact configuration and selects this public-event override.
    peer.Peer = DiagnosticPeer

    async def h1_response(reader):
        head = await asyncio.wait_for(reader.readuntil(b'\r\n\r\n'), 5)
        lines = head.split(b'\r\n')
        assert lines[0] == b'HTTP/1.1 200 OK', head
        headers = [(name.lower(), value.strip()) for name, value in
                   (line.split(b':', 1) for line in lines[1:] if line)]
        lengths = [value for name, value in headers if name == b'content-length']
        assert lengths == [b'11'], headers
        assert (b'connection', b'close') not in headers, headers
        body = await asyncio.wait_for(reader.readexactly(11), 5)
        assert body == b'mixed:/http', body

    async def h2_response(reader, writer, connection):
        headers, body = [], b''
        while True:
            data = await asyncio.wait_for(reader.read(65536), 5)
            assert data, 'premature H2 close'
            ended = False
            for event in connection.receive_data(data):
                assert not isinstance(event, (h2.events.StreamReset, h2.events.ConnectionTerminated)), event
                if isinstance(event, h2.events.ResponseReceived):
                    assert event.stream_id == 1, event
                    headers = event.headers
                elif isinstance(event, h2.events.DataReceived):
                    assert event.stream_id == 1, event
                    body += event.data
                    connection.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
                elif isinstance(event, h2.events.StreamEnded):
                    assert event.stream_id == 1, event
                    ended = True
            writer.write(connection.data_to_send())
            await writer.drain()
            if ended:
                assert headers.count((b':status', b'200')) == 1, headers
                assert body == b'mixed:/https', body
                return

    async def run():
        http_port, tls_port, h3_port = map(int, sys.argv[1:4])
        ca = sys.argv[4]
        context = ssl.create_default_context(cafile=ca)
        context.set_alpn_protocols(['h2'])
        h1_reader, h1_writer = await asyncio.wait_for(
            asyncio.open_connection('127.0.0.1', http_port), 5)
        h2_reader, h2_writer = await asyncio.wait_for(
            asyncio.open_connection('127.0.0.1', tls_port, ssl=context, server_hostname='localhost'), 5)
        try:
            assert h2_writer.get_extra_info('ssl_object').selected_alpn_protocol() == 'h2'
            connection = h2.connection.H2Connection()
            connection.initiate_connection()
            h2_writer.write(connection.data_to_send())
            await h2_writer.drain()
            settings_received = False
            while not settings_received:
                data = await asyncio.wait_for(h2_reader.read(65536), 5)
                assert data, 'H2 closed before SETTINGS'
                for event in connection.receive_data(data):
                    assert not isinstance(event, h2.events.ConnectionTerminated), event
                    settings_received |= isinstance(event, h2.events.RemoteSettingsChanged)
                h2_writer.write(connection.data_to_send())
                await h2_writer.drain()

            args = SimpleNamespace(port=h3_port, ca=ca, mode='startup')
            print('PHOENIX_MIXED_H3_CONNECT', flush=True)
            async with opened(args) as client:
                print('PHOENIX_MIXED_H3_ALPN ' + str(client.negotiated), flush=True)
                await client.until(lambda: client.http.received_settings is not None)
                assert client.negotiated == 'h3'
                print('PHOENIX_MIXED_H3_SETTINGS ' + repr(client.http.received_settings), flush=True)
                h1_writer.write(b'GET /http HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive\r\n\r\n')
                await h1_writer.drain()
                connection.send_headers(1, [(b':method', b'GET'), (b':scheme', b'https'),
                                           (b':authority', b'localhost'), (b':path', b'/https')],
                                        end_stream=True)
                h2_writer.write(connection.data_to_send())
                await h2_writer.drain()
                stream = client.request(path=b'/http3')
                await asyncio.gather(h1_response(h1_reader),
                                     h2_response(h2_reader, h2_writer, connection),
                                     client.response(stream, b'mixed:/http3'))
                await asyncio.wait_for(client.ping(), 2)
                assert client.terminated is None, client.terminated
                print('PHOENIX_MIXED_RESPONSES_PASS', flush=True)
                command = await asyncio.to_thread(sys.stdin.readline)
                assert command == 'close\n', repr(command)
        finally:
            h1_writer.close()
            h2_writer.close()
            await asyncio.wait_for(asyncio.gather(h1_writer.wait_closed(), h2_writer.wait_closed()), 5)
        print('PHOENIX_MIXED_CONNECTIONS_CLOSED', flush=True)

    asyncio.run(asyncio.wait_for(run(), 30))
    '''
  end

  defp await_mixed_marker(peer, marker, output, deadline) do
    if String.contains?(output, marker) do
      output
    else
      receive do
        {^peer, {:data, bytes}} -> await_mixed_marker(peer, marker, output <> bytes, deadline)
        {^peer, {:exit_status, code}} -> flunk("mixed peer exited #{code}: #{output}")
      after
        Gaoxy.Lifecycle.remaining(deadline) -> flunk("mixed peer marker timeout: #{output}")
      end
    end
  end

  defp await_mixed_exit(peer, output, deadline) do
    receive do
      {^peer, {:data, bytes}} -> await_mixed_exit(peer, output <> bytes, deadline)
      {^peer, {:exit_status, 0}} -> output
      {^peer, {:exit_status, code}} -> flunk("mixed peer exited #{code}: #{output}")
    after
      Gaoxy.Lifecycle.remaining(deadline) -> flunk("mixed peer exit timeout: #{output}")
    end
  end

  defp h2_connect(dir) do
    socket =
      connect(:ssl, Gaoxy.PhoenixAdapter.server_info(H2Endpoint, :https),
        verify: :verify_peer,
        cacertfile: String.to_charlist(Path.join(dir, "ca.pem")),
        server_name_indication: ~c"localhost",
        alpn_advertised_protocols: ["h2", "http/1.1"]
      )

    assert {:ok, "h2"} = :ssl.negotiated_protocol(socket)

    assert :ok =
             :ssl.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", Frame.encode(4, 0, 0, "")])

    socket
  end

  defp h2_request(socket, id, path) do
    fields = [
      {":method", "GET"},
      {":scheme", "https"},
      {":authority", "localhost"},
      {":path", path}
    ]

    {_, block} =
      HPACK.encode_headers(HPACK.new_encoder(), fields, indexing: :never, huffman: :never)

    assert :ok = :ssl.send(socket, Frame.encode(1, 5, id, block))
  end

  defp h2_worker(path) do
    assert_receive {:phoenix_h2_request, ^path, worker}, @timeout
    worker
  end

  defp h2_responses(socket, expected, decoder \\ HPACK.new_decoder(max_dynamic_size: 4_096)) do
    responses = Map.new(expected, fn {id, _} -> {id, %{status: nil, body: ""}} end)
    h2_frames(socket, expected, responses, decoder, Gaoxy.Lifecycle.deadline(@timeout))
  end

  defp h2_frames(_, expected, _, decoder, _) when map_size(expected) == 0, do: decoder

  defp h2_frames(socket, expected, responses, decoder, deadline) do
    assert {:ok, <<size::24, type, flags, _::1, id::31>>} =
             :ssl.recv(socket, 9, remaining(deadline))

    bytes =
      if size == 0 do
        ""
      else
        assert {:ok, bytes} = :ssl.recv(socket, size, remaining(deadline))
        bytes
      end

    case {type, id} do
      {4, 0} ->
        unless Frame.flag?(flags, 1),
          do: assert(:ok = :ssl.send(socket, Frame.encode(4, 1, 0, "")))

        h2_frames(socket, expected, responses, decoder, deadline)

      {8, _} ->
        h2_frames(socket, expected, responses, decoder, deadline)

      {type, id} when type in [0, 1] and is_map_key(expected, id) ->
        {decoder, response} =
          if type == 1 do
            assert Frame.flag?(flags, 4)
            assert {:ok, next_decoder, fields} = HPACK.decode(decoder, bytes)
            assert {":status", "200"} = List.keyfind(fields, ":status", 0)
            {next_decoder, %{responses[id] | status: "200"}}
          else
            {decoder, %{responses[id] | body: responses[id].body <> bytes}}
          end

        if Frame.flag?(flags, 1) do
          assert response == %{status: "200", body: expected[id]}

          h2_frames(
            socket,
            Map.delete(expected, id),
            Map.delete(responses, id),
            decoder,
            deadline
          )
        else
          h2_frames(socket, expected, Map.put(responses, id, response), decoder, deadline)
        end

      _ ->
        flunk("unexpected H2 frame #{type} for stream #{id}: #{inspect(bytes)}")
    end
  end

  defp remaining(deadline) do
    milliseconds = Gaoxy.Lifecycle.remaining(deadline)
    assert milliseconds > 0, "H2 response deadline expired"
    milliseconds
  end

  defp await_budget(instance, expected, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(@timeout)
    budget = Gaoxy.resource_budget(instance)

    unless Map.take(budget, Map.keys(expected)) == expected do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(budget)

      receive do
      after
        1 -> await_budget(instance, expected, deadline)
      end
    end
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
