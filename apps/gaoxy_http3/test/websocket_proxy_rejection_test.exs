defmodule Gaoxy.HTTP.HTTP3.WebSocketProxyRejectionTest do
  use ExUnit.Case, async: false

  defmodule Local do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "local")
  end

  @tag :tmp_dir
  test "H3 rejects ordinary HTTP and unsupported WebSocket CONNECT before opening upstream",
       %{tmp_dir: directory} do
    root = Path.expand("../../..", __DIR__)

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), directory],
               stderr_to_stdout: true
             )

    {:ok, upstream} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_tcp.close(upstream) end)
    {:ok, {_, upstream_port}} = :inet.sockname(upstream)

    {:ok, server} =
      Gaoxy.HTTP.HTTP3.start_link(
        extended_connect: true,
        tls: %{
          certfile: Path.join(directory, "cert.pem"),
          keyfile: Path.join(directory, "key.pem")
        },
        endpoint:
          {Gaoxy.HTTP.Router,
           [
             %{
               path: "/ws",
               target: {Gaoxy.Proxy.WebSocket, %{upstream: "ws://127.0.0.1:#{upstream_port}"}}
             },
             %{path: "/local", target: {Local, []}}
           ]}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {_, port}} = Gaoxy.info(server, :http3).local
    python = System.get_env("GAOXY_QUIC_PYTHON") || Path.join(root, ".audit/m5/venv/bin/python")

    peer = ~S'''
    import asyncio, sys
    from types import SimpleNamespace
    sys.path.insert(0, 'integration/http3')
    from peer import opened
    args=SimpleNamespace(mode='startup',port=int(sys.argv[1]),ca=sys.argv[2])
    async def run():
        async with opened(args) as client:
            await client.until(lambda: client.http.received_settings is not None)
            assert client.http.received_settings.get(8)==1
            requests=[
                (b'GET',b'/ws',[],b'400',b''),
                (b'CONNECT',b'/ws',[(b':protocol',b'websocket'),(b'sec-websocket-version',b'13')],b'400',b''),
                (b'GET',b'/local',[],b'200',b'local'),
            ]
            for method,path,extra,status,body in requests:
                sid=client.request(method,path,extra)
                await client.response(sid,body,status)
                assert not {b'connection',b'upgrade'}.intersection(dict(client.headers[sid][0]))
            assert not client.resets and not client.stops, (client.resets,client.stops)
            await asyncio.wait_for(client.ping(),5)
        print('H3_WEBSOCKET_PROXY_REJECTION_PASS')
    asyncio.run(run())
    '''

    {output, exit} =
      System.cmd(python, ["-c", peer, to_string(port), Path.join(directory, "ca.pem")],
        cd: root,
        stderr_to_stdout: true
      )

    assert exit == 0, output
    assert output =~ "H3_WEBSOCKET_PROXY_REJECTION_PASS"
    assert DynamicSupervisor.which_children(Gaoxy.Proxy.SessionSupervisor) == []
    assert {:error, :timeout} = :gen_tcp.accept(upstream, 0)
    assert :ok = Gaoxy.stop(server)
  end
end
