defmodule Gaoxy.HTTP.HTTP3.PlugTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.HTTP3.{Connection, Options}

  defmodule TestPlug do
    def init(observer), do: observer

    def call(conn, observer) do
      send(observer, {:endpoint_called, self(), conn})
      Plug.Conn.send_resp(conn, 200, "shared")
    end
  end

  test "an ordinary Plug creates a shared owner without dispatch before authenticated readiness" do
    {:ok, spec} =
      Options.normalize(
        plug: {TestPlug, self()},
        tls: %{certfile: "fixture.pem", keyfile: "fixture-key.pem"}
      )

    assert {:ok, state} =
             Connection.init(
               %{gate: self(), limits: spec.limits},
               %{alpn: "h3"},
               spec.handler_options
             )

    assert :ets.info(state.operations, :owner) == self()
    assert {:ok, ^state} = Connection.handle_event(:tick, state)
    refute_received {:endpoint_called, _, _}
    assert {:stop, :normal, closed} = Connection.handle_event({:closed, :test_close}, state)
    assert closed.streams == %{}
    assert :ets.info(state.operations) == :undefined
  end

  test "a failed supervised task start is scoped and releases its slot in an isolated real H3 runtime" do
    root = Path.expand("../../..", __DIR__)

    directory =
      Path.join(System.tmp_dir!(), "gaoxy-h3-start-#{System.unique_integer([:positive])}")

    File.mkdir!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    {_, 0} = System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), directory])
    script = Path.join(directory, "start_failure.exs")

    File.write!(script, ~S'''
    defmodule Gaoxy.HTTP3Fixture.Endpoint do
      def init(options), do: {:ok, options}
      def call(_, _), do: raise("minimal fixture dispatch must stay inside Connection")
    end
    defmodule StartFailurePlug do
      def init(observer), do: observer
      def call(conn, observer) do
        send(observer, :dispatched)
        Plug.Conn.send_resp(conn, 200, "ok")
      end
    end
    {:ok, _} = Application.ensure_all_started(:gaoxy_http3)
    :ok = Application.stop(:gaoxy_http)
    {:ok, tasks} = Task.Supervisor.start_link(name: Gaoxy.HTTP.Tasks, max_children: 1)
    {:ok, blocker} = Task.Supervisor.start_child(tasks, fn -> receive do :release -> :ok end end)
    directory = System.fetch_env!("GAOXY_HTTP3_START_CERTS")
    tls = %{certfile: Path.join(directory, "cert.pem"), keyfile: Path.join(directory, "key.pem")}
    {:ok, shared} = Gaoxy.HTTP.HTTP3.service_spec(id: :shared, plug: {StartFailurePlug, self()}, tls: tls)
    {:ok, sibling} = Gaoxy.HTTP.HTTP3.service_spec(id: :sibling, endpoint: {Gaoxy.HTTP3Fixture.Endpoint, %{profile: :minimal}}, tls: tls)
    {:ok, runtime} = Gaoxy.start_link(services: [shared, sibling])
    {:ok, {_, port}} = Gaoxy.info(runtime, :shared).local
    {:ok, {_, sibling_port}} = Gaoxy.info(runtime, :sibling).local
    python = System.get_env("GAOXY_QUIC_PYTHON") || Path.join(File.cwd!(), "integration/quic_consumer/.venv/bin/python")
    peer = ~S"""
    import asyncio,sys
    from types import SimpleNamespace
    sys.path.insert(0, 'integration/http3')
    from peer import opened
    args=SimpleNamespace(mode='startup',port=int(sys.argv[1]),sibling_port=int(sys.argv[2]),ca=sys.argv[3])
    async def run():
        async with opened(args) as client:
            sid=client.request(fin=sys.argv[4]!='blocked')
            if sys.argv[4]=='blocked':
                await client.until(lambda: sid in client.resets and sid in client.stops)
                assert client.resets[sid]==client.stops[sid]==0x107
                assert client.terminated is None
                await asyncio.wait_for(client.ping(),5)
            else:
                await client.response(sid)
            async with opened(args,port=args.sibling_port) as sibling:
                await sibling.response(sibling.request())
    asyncio.run(run())
    """
    try do
      {_, 0} = System.cmd(python, ["-c", peer, to_string(port), to_string(sibling_port), Path.join(directory, "ca.pem"), "blocked"], stderr_to_stdout: true)
      receive do :dispatched -> raise "endpoint dispatched despite failed start" after 0 -> :ok end
      :ok = Task.Supervisor.terminate_child(tasks, blocker)
      {_, 0} = System.cmd(python, ["-c", peer, to_string(port), to_string(sibling_port), Path.join(directory, "ca.pem"), "available"], stderr_to_stdout: true)
      receive do :dispatched -> :ok after 1_000 -> raise "recovered task admission did not dispatch" end
      deadline = Gaoxy.Lifecycle.deadline(2_000)
      wait = fn wait ->
        statuses = for id <- [:shared, :sibling], do: Gaoxy.status(runtime, id)
        if Enum.all?(statuses, &(&1.active == 0 and &1.retained_bytes == 0)) do
          :ok
        else
          if Gaoxy.Lifecycle.remaining(deadline) == 0, do: raise("termination_unconfirmed: #{inspect(statuses)}")
          receive do after 1 -> wait.(wait) end
        end
      end
      :ok = wait.(wait)
      IO.puts("FAILED_START_PASS")
    after
      Gaoxy.stop(runtime, 5_000)
      Supervisor.stop(tasks)
    end
    ''')

    paths = Enum.flat_map(:code.get_path(), fn path -> ["-pa", to_string(path)] end)

    {output, exit} =
      System.cmd("elixir", paths ++ [script],
        cd: root,
        stderr_to_stdout: true,
        env: [{"GAOXY_HTTP3_START_CERTS", directory}]
      )

    assert exit == 0, output
    assert output =~ "FAILED_START_PASS"
  end

  @tag :tmp_dir
  test "returned endpoint errors preserve completed responses and reset a committed prefix on real H3",
       %{
         tmp_dir: directory
       } do
    root = Path.expand("../../..", __DIR__)

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), directory],
               stderr_to_stdout: true
             )

    script = Path.join(directory, "returned_endpoint_errors.exs")

    File.write!(script, ~S'''
    defmodule ReturnedErrorEndpoint do
      alias Gaoxy.HTTP.{Exchange, Response}
      def init(options), do: {:ok, options}

      def call(exchange, _) do
        case exchange.request.path do
          "/returned-error" ->
            {:ok, committed} = Response.send_chunked(exchange, 200, [])
            {:ok, committed} = Response.chunk(committed, "progress-prefix")

            case Exchange.read_body(committed, 1, 5_000) do
              {status, "!", final} when status in [:ok, :more] ->
                IO.puts("ENDPOINT_ERROR_MARKER_CONSUMED")
                {:error, :intentional_endpoint_error, final}

              {:error, reason} ->
                {:error, reason, committed}
            end

          "/prehead-error" ->
            {:error, :intentional_endpoint_error, exchange}

          path when path in ["/completed-502", "/completed-504"] ->
            status = if path == "/completed-502", do: 502, else: 504
            {:ok, sent} = Response.send_resp(exchange, status, [], "completed-#{status}")
            {:error, :intentional_endpoint_error, sent}

          _ ->
            Response.send_resp(exchange, 200, [], "sibling")
        end
      end
    end

    {:ok, _} = Application.ensure_all_started(:gaoxy_http3)
    directory = System.fetch_env!("GAOXY_HTTP3_ENDPOINT_ERROR_CERTS")
    tls = %{certfile: Path.join(directory, "cert.pem"), keyfile: Path.join(directory, "key.pem")}
    {:ok, spec} = Gaoxy.HTTP.HTTP3.service_spec(id: :shared, endpoint: {ReturnedErrorEndpoint, []}, tls: tls, http_limits: %{request_timeout: 5_000})
    {:ok, runtime} = Gaoxy.start_link(services: [spec])
    {:ok, {_, port}} = Gaoxy.info(runtime, :shared).local
    python = System.get_env("GAOXY_QUIC_PYTHON") || Path.join(File.cwd!(), "integration/quic_consumer/.venv/bin/python")

    peer = ~S"""
    import asyncio,sys
    from types import SimpleNamespace
    sys.path.insert(0, 'integration/http3')
    from peer import opened
    args=SimpleNamespace(mode='endpoint-error',port=int(sys.argv[1]),ca=sys.argv[2])

    async def run():
        async with opened(args) as client:
            prehead=client.request(path=b'/prehead-error')
            await client.response(prehead,body=b'',status=b'500')
            await client.response(client.request(path=b'/sibling'),body=b'sibling')
            assert prehead not in client.resets
            print('PASS H3 pre-head returned error completes 500',flush=True)

            for status in (502,504):
                sid=client.request(path=f'/completed-{status}'.encode())
                await client.response(sid,body=f'completed-{status}'.encode(),status=str(status).encode())
                await client.response(client.request(path=b'/sibling'),body=b'sibling')
                assert sid not in client.resets
                print(f'PASS H3 completed {status} survives returned error',flush=True)

            sid=client.request(method=b'POST',path=b'/returned-error',fin=False)
            await client.until(lambda: sid in client.headers and client.data.get(sid,b'')==b'progress-prefix')
            assert client.headers[sid]==[[(b':status',b'200')]],client.headers[sid]
            assert sid not in client.ended and sid not in client.resets
            client.http.send_data(sid,b'!',end_stream=False)
            client.transmit()
            await client.until(lambda: sid in client.ended or (sid in client.resets and sid in client.stops))
            assert client.resets.get(sid)==client.stops.get(sid)==0x10C,(client.resets,client.stops)
            assert sid not in client.ended,'endpoint error emitted successful response FIN'
            assert client.data[sid]==b'progress-prefix',client.data[sid]
            assert client.headers[sid]==[[(b':status',b'200')]],client.headers[sid]
            await client.response(client.request(path=b'/sibling'),body=b'sibling')
            assert sid not in client.ended and client.terminated is None
            print('PASS H3 committed returned error resets 0x10C without FIN and sibling survives',flush=True)
    asyncio.run(run())
    """

    try do
      {output, exit} = System.cmd(python, ["-c", peer, to_string(port), Path.join(directory, "ca.pem")], stderr_to_stdout: true)
      if exit != 0, do: raise("independent endpoint-error peer failed: #{output}")
      IO.write(output)
      deadline = Gaoxy.Lifecycle.deadline(2_000)

      wait = fn wait ->
        status = Gaoxy.status(runtime, :shared)

        if status.active == 0 and status.retained_bytes == 0 do
          :ok
        else
          if Gaoxy.Lifecycle.remaining(deadline) == 0, do: raise("termination_unconfirmed: #{inspect(status)}")
          receive do after 1 -> wait.(wait) end
        end
      end

      :ok = wait.(wait)
      IO.puts("RETURNED_ENDPOINT_ERRORS_PASS")
    after
      :ok = Gaoxy.stop(runtime, 5_000)
    end
    ''')

    paths = Enum.flat_map(:code.get_path(), fn path -> ["-pa", to_string(path)] end)

    {output, exit} =
      System.cmd("elixir", paths ++ [script],
        cd: root,
        stderr_to_stdout: true,
        env: [{"GAOXY_HTTP3_ENDPOINT_ERROR_CERTS", directory}]
      )

    assert output =~ "ENDPOINT_ERROR_MARKER_CONSUMED", output
    assert exit == 0, output
    assert output =~ "PASS H3 pre-head returned error completes 500"
    assert output =~ "PASS H3 completed 502 survives returned error"
    assert output =~ "PASS H3 completed 504 survives returned error"

    assert output =~
             "PASS H3 committed returned error resets 0x10C without FIN and sibling survives"

    assert output =~ "RETURNED_ENDPOINT_ERRORS_PASS"
  end
end
