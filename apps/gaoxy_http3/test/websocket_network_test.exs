defmodule Gaoxy.HTTP.HTTP3.WebSocketNetworkTest do
  use ExUnit.Case, async: true

  defmodule Echo do
    def init(owner) do
      send(owner, {:websocket_initialized, self()})
      send(self(), :push)
      {:ok, owner}
    end

    def handle_in({bytes, opcode: opcode}, owner), do: {:push, {opcode, bytes}, owner}
    def handle_info(:push, owner), do: {:push, {:text, "push"}, owner}
    def handle_info(_, owner), do: {:ok, owner}
    def terminate(reason, owner), do: send(owner, {:websocket_terminated, self(), reason})
  end

  defmodule Endpoint do
    def init(owner), do: {:ok, owner}

    def call(%{request: %{path: "/ws"}} = exchange, owner) do
      send(owner, {:websocket_dispatched, self(), exchange.request})
      Gaoxy.PlugAdapter.upgrade(exchange, :websocket, {Echo, owner, [max_lifetime: 10_000]})
    end

    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "ok")
  end

  defmodule PersistentEndpoint do
    def init(owner), do: {:ok, owner}

    def call(%{request: %{path: "/ws"}} = exchange, owner),
      do: Gaoxy.PlugAdapter.upgrade(exchange, :websocket, {Echo, owner, []})

    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "ok")
  end

  @tag :tmp_dir
  test "persistent H3 websocket outlives peer idle and repeatedly reuses small receive windows",
       %{tmp_dir: directory} do
    root = Path.expand("../../..", __DIR__)

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), directory],
               stderr_to_stdout: true
             )

    {:ok, server} =
      Gaoxy.HTTP.HTTP3.start_link(
        endpoint: {PersistentEndpoint, self()},
        extended_connect: true,
        limits: %{idle_timeout: 200},
        tls: %{
          certfile: Path.join(directory, "cert.pem"),
          keyfile: Path.join(directory, "key.pem")
        }
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {_, port}} = Gaoxy.info(server, :http3).local
    python = System.get_env("GAOXY_QUIC_PYTHON") || Path.join(root, ".audit/h2peer/bin/python")

    peer = ~S'''
    import asyncio, sys
    sys.path.insert(0, 'integration/http3')
    from peer import Peer
    from aioquic.asyncio import connect
    from aioquic.quic.configuration import QuicConfiguration
    from aioquic.quic.events import ConnectionTerminated
    from aioquic.quic.logger import QuicLogger
    class DiagnosticPeer(Peer):
        def quic_event_received(self,event):
            if isinstance(event,ConnectionTerminated):
                print("PEER_CLOSED",event,flush=True)
            super().quic_event_received(event)
    def masked(opcode,payload):
        key=b'\x01\x02\x03\x04'
        n=len(payload)
        size=(bytes([0x80|n]) if n<126 else
              b'\xfe'+n.to_bytes(2,'big') if n<=65535 else b'\xff'+n.to_bytes(8,'big'))
        return bytes([0x80|opcode])+size+key+bytes(b^key[i%4] for i,b in enumerate(payload))
    transfers=[]
    for size in [5*1024*1024,300*1024,300*1024]:
        payload=b'a'*size
        transfers.append((b'\x82\x7f'+size.to_bytes(8,'big')+payload,masked(2,payload)))
    async def run():
        config=QuicConfiguration(is_client=True,alpn_protocols=['h3'],max_data=65536,
                                 max_stream_data=16384,idle_timeout=0.3)
        config.quic_logger=QuicLogger()
        config.server_name='localhost'
        config.load_verify_locations(sys.argv[2])
        async with connect('127.0.0.1',int(sys.argv[1]),configuration=config,
                           create_protocol=DiagnosticPeer) as client:
            await client.until(lambda: client.http.received_settings is not None)
            remote=[event['data'] for trace in config.quic_logger.to_dict()['traces']
                    for event in trace['events'] if event['name']=='transport:parameters_set'
                    and event['data'].get('owner')=='remote']
            assert remote and remote[0].get('max_idle_timeout')==0, remote
            sid=client.request(b'CONNECT',b'/ws',[(b':protocol',b'websocket'),
                               (b'sec-websocket-version',b'13')],fin=False)
            await client.until(lambda: client.data.get(sid,b'')==b'\x81\x04push')
            client.data[sid]=b''
            await asyncio.sleep(0.9)
            assert client.terminated is None, client.terminated
            await asyncio.wait_for(client.ping(),2)
            for expected,wire in transfers:
                client.http.send_data(sid,wire,end_stream=False)
                client.transmit()
                try:
                    async with asyncio.timeout(30):
                        while len(client.data.get(sid,b''))<len(expected):
                            assert client.terminated is None, client.terminated
                            client.changed.clear()
                            await client.changed.wait()
                except TimeoutError:
                    packets=[event for trace in config.quic_logger.to_dict()['traces']
                             for event in trace['events'] if event['name']=='transport:packet_sent']
                    streams=[frame for event in packets for frame in event['data'].get('frames',[])
                             if frame.get('frame_type')=='stream' and frame.get('stream_id')==sid]
                    print('TRANSFER_PROGRESS',len(client.data.get(sid,b'')),len(expected),
                          max([frame.get('offset',0)+frame.get('length',0) for frame in streams] or [0]),flush=True)
                    raise
                assert client.data[sid]==expected, (len(client.data[sid]),len(expected))
                print('H3_TRANSFER_PASS bytes='+str(len(expected)-10),flush=True)
                client.data[sid]=b''
            client.http.send_data(sid,masked(9,b'alive'),end_stream=False)
            client.transmit()
            await client.until(lambda: client.data.get(sid,b'')==b'\x8a\x05alive')
            client.data[sid]=b''
            await client.response(client.request())
            client.http.send_data(sid,masked(8,b'\x03\xe8'),end_stream=False)
            client.transmit()
            await client.until(lambda: sid in client.ended)
            assert client.data[sid]==b'\x88\x02\x03\xe8'
            client.http.send_data(sid,b'',end_stream=True)
            client.transmit()
            await client.response(client.request())
            assert not client.resets and not client.stops, (client.resets,client.stops)
        print('H3_IDLE_PARAMS remote_ms=0 peer_ms=300 quiet_ms=900 connection_window=65536 stream_window=16384')
        print('H3_WEBSOCKET_PERSISTENT_PASS')
    asyncio.run(run())
    '''

    {output, exit} =
      System.cmd(python, ["-c", peer, to_string(port), Path.join(directory, "ca.pem")],
        cd: root,
        stderr_to_stdout: true
      )

    assert exit == 0, output
    assert output =~ "H3_WEBSOCKET_PERSISTENT_PASS"
    IO.puts(output)
    assert_receive {:websocket_initialized, worker}, 1000
    assert_receive {:websocket_terminated, ^worker, :remote}, 1000
    assert :ok = Gaoxy.stop(server)
  end

  @tag :tmp_dir
  test "ordinary H3 tunnels push, echo and Close with HTTP siblings on the same verified connection",
       %{tmp_dir: directory} do
    root = Path.expand("../../..", __DIR__)

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), directory],
               stderr_to_stdout: true
             )

    {:ok, server} =
      Gaoxy.HTTP.HTTP3.start_link(
        endpoint: {Endpoint, self()},
        extended_connect: true,
        tls: %{
          certfile: Path.join(directory, "cert.pem"),
          keyfile: Path.join(directory, "key.pem")
        },
        http_limits: %{max_body_bytes: 2}
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
    def masked(opcode,payload):
        key=b'\x01\x02\x03\x04'
        return bytes([0x80|opcode,0x80|len(payload)])+key+bytes(b^key[i%4] for i,b in enumerate(payload))
    async def run():
        async with opened(args) as client:
            await client.until(lambda: client.http.received_settings is not None)
            assert client.http.received_settings.get(8)==1, client.http.received_settings
            streams=[]
            for _ in range(2):
                sid=client.request(b'CONNECT',b'/ws',[(b':protocol',b'websocket'),(b'sec-websocket-version',b'13')],fin=False)
                streams.append(sid)
                await client.until(lambda: sid in client.headers or sid in client.resets)
                assert client.headers[sid][0].count((b':status',b'200'))==1, client.headers
                assert not {b'connection',b'upgrade',b'content-length',b'transfer-encoding',b'sec-websocket-accept'}.intersection(dict(client.headers[sid][0]))
                assert sid not in client.ended
                await client.until(lambda: client.data.get(sid,b'')==b'\x81\x04push')
                client.http.send_data(sid,masked(1,b'hello'),end_stream=False)
                client.transmit()
                await client.until(lambda: client.data.get(sid,b'')==b'\x81\x04push\x81\x05hello')
            await client.response(client.request())
            for sid in streams:
                client.http.send_data(sid,masked(8,b'\x03\xe8'),end_stream=False)
                client.transmit()
                await client.until(lambda: sid in client.ended or sid in client.resets)
                assert client.data[sid].endswith(b'\x88\x02\x03\xe8')
                client.http.send_data(sid,b'',end_stream=True)
                client.transmit()
            await client.response(client.request())
            assert not client.resets and not client.stops, (client.resets,client.stops)
            await asyncio.wait_for(client.ping(),5)
        print('H3_WEBSOCKET_NORMAL_PASS')
    asyncio.run(run())
    '''

    {output, exit} =
      System.cmd(python, ["-c", peer, to_string(port), Path.join(directory, "ca.pem")],
        cd: root,
        stderr_to_stdout: true
      )

    assert exit == 0, output
    assert output =~ "H3_WEBSOCKET_NORMAL_PASS"

    for _ <- 1..2 do
      assert_receive {:websocket_dispatched, worker,
                      %{method: "CONNECT", protocol: "websocket", body: :tunnel}},
                     1000

      assert_receive {:websocket_initialized, ^worker}
      assert_receive {:websocket_terminated, ^worker, :remote}, 1000
    end

    refute_receive {:websocket_terminated, _, _}, 10
    assert :ok = Gaoxy.stop(server)
  end
end
