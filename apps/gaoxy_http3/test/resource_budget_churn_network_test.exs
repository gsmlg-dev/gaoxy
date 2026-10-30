defmodule Gaoxy.HTTP.HTTP3.ResourceBudgetChurnNetworkTest do
  use ExUnit.Case, async: false
  @moduletag :protocol
  @timeout 5_000

  defmodule Endpoint do
    def init(observer), do: {:ok, observer}

    def call(exchange, observer) do
      send(observer, {:churn_request, self(), exchange.request.path})

      receive do
        :respond -> Gaoxy.HTTP.Response.send_resp(exchange, 200, [], exchange.request.path)
      after
        Gaoxy.Lifecycle.remaining(exchange.deadline) -> {:error, :timeout, exchange}
      end
    end
  end

  @tag :tmp_dir
  test "H1 readmits three fresh connections on the same listener after confirmed cleanup",
       context do
    churn(:http1, context.tmp_dir)
  end

  @tag :tmp_dir
  test "H2 readmits three fresh connections on the same listener after confirmed cleanup",
       context do
    churn(:http2, context.tmp_dir)
  end

  @tag :tmp_dir
  test "H3 readmits three fresh connections on the same listener after confirmed cleanup",
       context do
    churn(:http3, context.tmp_dir)
  end

  defp churn(protocol, directory) do
    root = Path.expand("../../..", __DIR__)
    spec = spec(protocol, directory, root)
    assert {:ok, server} = Gaoxy.start_link(services: [spec])
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @timeout) end)

    assert %{generation: generation, local: {:ok, {_, port} = local}, mode: :ready} =
             Gaoxy.info(server, spec.id)

    # Keep the venv entrypoint path: resolving its symlink loses site-packages.
    python = System.get_env("GAOXY_QUIC_PYTHON") || Path.join(root, ".audit/h2peer/bin/python")
    await_idle(server, spec.id, Gaoxy.Lifecycle.deadline(@timeout))

    Enum.reduce(1..3, [], fn round, workers ->
      path = "/churn/#{round}"

      # A new executable and a new client connection are created for every round.
      peer =
        Port.open(
          {:spawn_executable, String.to_charlist(python)},
          [
            :binary,
            :exit_status,
            :stderr_to_stdout,
            args: [
              "-c",
              peer_script(),
              Atom.to_string(protocol),
              to_string(port),
              path,
              Path.join(directory, "ca.pem")
            ],
            cd: root
          ]
        )

      on_exit(fn -> if Port.info(peer), do: Port.close(peer) end)
      assert_receive {:churn_request, worker, ^path}, @timeout
      assert Process.alive?(worker)
      refute worker in workers
      assert_live(server, protocol)
      send(worker, :respond)
      output = await_marker(peer, "CHURN_RESPONSE_PASS", "", Gaoxy.Lifecycle.deadline(@timeout))
      await_completed(server, protocol, Gaoxy.Lifecycle.deadline(@timeout))
      assert Port.command(peer, "close\n")
      output = await_exit(peer, output, Gaoxy.Lifecycle.deadline(10_000))
      assert output =~ "CHURN_CONNECTION_CLOSED"

      # No next connect until the same instance reports actual zero ownership.
      await_idle(server, spec.id, Gaoxy.Lifecycle.deadline(@timeout))

      assert %{generation: ^generation, local: {:ok, ^local}, mode: :ready} =
               Gaoxy.info(server, spec.id)

      [worker | workers]
    end)

    assert :ok = Gaoxy.stop(server, @timeout)
  end

  defp spec(:http3, directory, root) do
    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), directory],
               stderr_to_stdout: true
             )

    assert {:ok, spec} =
             Gaoxy.HTTP.HTTP3.service_spec(
               endpoint: {Endpoint, self()},
               limits: %{max_connections: 1},
               http_limits: %{request_timeout: @timeout},
               tls: %{
                 certfile: Path.join(directory, "cert.pem"),
                 keyfile: Path.join(directory, "key.pem")
               }
             )

    spec
  end

  defp spec(protocol, _directory, _root) do
    options = [
      endpoint: {Endpoint, self()},
      protocols: [protocol],
      limits: %{max_connections: 1},
      http_limits: %{request_timeout: @timeout}
    ]

    options =
      if protocol == :http2, do: Keyword.put(options, :h2c, :prior_knowledge), else: options

    assert {:ok, spec} = Gaoxy.HTTP.service_spec(options)
    spec
  end

  defp assert_live(server, protocol) do
    assert %{active_connections: 1, active_requests: 1, usage: bytes} =
             budget = Gaoxy.resource_budget(server)

    assert is_integer(bytes) and bytes > 0
    assert budget.active_h2_streams == if(protocol == :http2, do: 1, else: 0)
    assert budget.active_h3_streams == if(protocol == :http3, do: 1, else: 0)
  end

  defp await_completed(server, protocol, deadline) do
    case Gaoxy.resource_budget(server) do
      %{
        active_connections: 1,
        active_requests: 0,
        active_h2_streams: 0,
        active_h3_streams: 0,
        usage: bytes
      }
      when is_integer(bytes) and bytes >= 0 and (protocol == :http1 or bytes > 0) ->
        # H1 keeps its connection quota but an empty idle buffer owns zero bytes.
        :ok

      snapshot ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect({protocol, snapshot})

        receive do
        after
          5 -> await_completed(server, protocol, deadline)
        end
    end
  end

  defp await_idle(server, service, deadline) do
    case {Gaoxy.resource_budget(server), Gaoxy.status(server, service)} do
      {%{
         usage: 0,
         active_connections: 0,
         active_requests: 0,
         active_h2_streams: 0,
         active_h3_streams: 0,
         leases: 0,
         pending_processes: 0
       },
       %{active: 0, retained_bytes: 0, cleanup_pending: 0, cleanup_failed: nil, state: :ready}} ->
        :ok

      snapshot ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(snapshot)

        receive do
        after
          5 -> await_idle(server, service, deadline)
        end
    end
  end

  defp await_marker(peer, marker, output, deadline) do
    if String.contains?(output, marker) do
      output
    else
      receive do
        {^peer, {:data, bytes}} -> await_marker(peer, marker, output <> bytes, deadline)
        {^peer, {:exit_status, code}} -> flunk("churn peer exited #{code}: #{output}")
      after
        Gaoxy.Lifecycle.remaining(deadline) -> flunk("churn peer marker timeout: #{output}")
      end
    end
  end

  defp await_exit(peer, output, deadline) do
    receive do
      {^peer, {:data, bytes}} -> await_exit(peer, output <> bytes, deadline)
      {^peer, {:exit_status, 0}} -> output
      {^peer, {:exit_status, code}} -> flunk("churn peer exited #{code}: #{output}")
    after
      Gaoxy.Lifecycle.remaining(deadline) -> flunk("churn peer exit timeout: #{output}")
    end
  end

  defp peer_script do
    ~S'''
    import asyncio, sys
    from types import SimpleNamespace

    async def close_command():
        command = await asyncio.wait_for(asyncio.to_thread(sys.stdin.readline), 10)
        assert command == 'close\n', repr(command)

    async def h1_response(reader, body):
        head = await asyncio.wait_for(reader.readuntil(b'\r\n\r\n'), 5)
        lines = head.split(b'\r\n')
        assert lines[0] == b'HTTP/1.1 200 OK', head
        headers = [(name.lower(), value.strip()) for name, value in
                   (line.split(b':', 1) for line in lines[1:] if line)]
        assert [value for name, value in headers if name == b'content-length'] == [str(len(body)).encode()], headers
        assert (b'connection', b'close') not in headers, headers
        assert await asyncio.wait_for(reader.readexactly(len(body)), 5) == body

    async def h2_response(reader, writer, connection, body):
        import h2.events
        headers, received = [], b''
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
                    received += event.data
                    connection.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
                elif isinstance(event, h2.events.StreamEnded):
                    assert event.stream_id == 1, event
                    ended = True
            writer.write(connection.data_to_send())
            await writer.drain()
            if ended:
                assert headers.count((b':status', b'200')) == 1, headers
                assert received == body, received
                return

    async def run():
        protocol, port, path, ca = sys.argv[1:5]
        body = path.encode()
        if protocol == 'http3':
            sys.path.insert(0, 'integration/http3')
            from peer import opened
            args = SimpleNamespace(port=int(port), ca=ca, mode='startup')
            async with opened(args) as client:
                await client.until(lambda: client.http.received_settings is not None)
                await client.response(client.request(path=body), body=body)
                await asyncio.wait_for(client.ping(), 2)
                assert client.terminated is None, client.terminated
                print('CHURN_RESPONSE_PASS', flush=True)
                await close_command()
        else:
            reader, writer = await asyncio.wait_for(asyncio.open_connection('127.0.0.1', int(port)), 5)
            try:
                if protocol == 'http1':
                    writer.write(b'GET ' + body + b' HTTP/1.1\r\nHost: localhost\r\n\r\n')
                    await writer.drain()
                    await h1_response(reader, body)
                else:
                    assert protocol == 'http2', protocol
                    import h2.connection
                    import h2.events
                    connection = h2.connection.H2Connection()
                    connection.initiate_connection()
                    writer.write(connection.data_to_send())
                    await writer.drain()
                    settings_received = False
                    while not settings_received:
                        data = await asyncio.wait_for(reader.read(65536), 5)
                        assert data, 'H2 closed before SETTINGS'
                        for event in connection.receive_data(data):
                            assert not isinstance(event, h2.events.ConnectionTerminated), event
                            settings_received |= isinstance(event, h2.events.RemoteSettingsChanged)
                        writer.write(connection.data_to_send())
                        await writer.drain()
                    connection.send_headers(1, [(b':method', b'GET'), (b':scheme', b'http'),
                                               (b':authority', b'localhost'), (b':path', body)], end_stream=True)
                    writer.write(connection.data_to_send())
                    await writer.drain()
                    await h2_response(reader, writer, connection, body)
                print('CHURN_RESPONSE_PASS', flush=True)
                await close_command()
            finally:
                writer.close()
                await asyncio.wait_for(writer.wait_closed(), 5)
        print('CHURN_CONNECTION_CLOSED', flush=True)

    asyncio.run(asyncio.wait_for(run(), 30))
    '''
  end
end
