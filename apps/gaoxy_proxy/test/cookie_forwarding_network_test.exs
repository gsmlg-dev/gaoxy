defmodule Gaoxy.Proxy.CookieForwardingNetworkTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Proxy.UpstreamTransports

  for mode <- [:dedicated, :managed] do
    @tag :loopback
    test "H2 downstream serializes one ordered Cookie on the #{mode} H1 upstream" do
      {listener, origin} = origin()
      {instance, options, baseline} = upstream(listener, unquote(mode))

      {:ok, spec} =
        Gaoxy.HTTP.service_spec(
          id: :http,
          protocols: [:http2],
          h2c: :prior_knowledge,
          endpoint: {Gaoxy.Proxy.HTTP, options},
          limits: %{max_bytes: 536_870_912}
        )

      assert {:ok, _} = Gaoxy.add(instance, spec)
      {:ok, {_, port}} = Gaoxy.info(instance, :http).local
      root = Path.expand("../../..", __DIR__)
      python = Path.join(root, ".audit/h2peer/bin/python")

      peer = ~S'''
      import socket, sys
      from h2.connection import H2Connection
      from h2.config import H2Configuration
      from h2.events import ResponseReceived, DataReceived, StreamEnded, StreamReset, ConnectionTerminated
      conn=H2Connection(config=H2Configuration(client_side=True,normalize_outbound_headers=False))
      conn.initiate_connection()
      with socket.create_connection(('127.0.0.1',int(sys.argv[1])),timeout=5) as sock:
          fields=[(':method','GET'),(':scheme','http'),(':authority','localhost'),(':path','/cookies'),
                  ('cookie','a=1'),('x-trace','first'),('cookie','b=2; c=3'),('x-trace','second'),('cookie','d=4')]
          conn.send_headers(1,fields,end_stream=True)
          sock.sendall(conn.data_to_send())
          status=None
          body=b''
          done=False
          while not done:
              data=sock.recv(65536)
              assert data, 'connection ended before response'
              for event in conn.receive_data(data):
                  assert not isinstance(event,(StreamReset,ConnectionTerminated)),event
                  if isinstance(event,ResponseReceived): status=dict(event.headers)[b':status']
                  if isinstance(event,DataReceived): body+=event.data
                  if isinstance(event,StreamEnded): done=True
              pending=conn.data_to_send()
              if pending: sock.sendall(pending)
          assert (status,body)==(b'200',b'ok'),(status,body)
      print('H2_COOKIE_WIRE_PASS')
      '''

      {output, status} = System.cmd(python, ["-c", peer, to_string(port)], stderr_to_stdout: true)
      assert status == 0, output
      assert output =~ "H2_COOKIE_WIRE_PASS"
      assert_cookie_wire(Task.await(origin, 5_000))
      if baseline, do: assert(:ok = Resources.release(baseline))
      assert :ok = Gaoxy.stop(instance, 5_000)
    end
  end

  @tag :loopback
  @tag :tmp_dir
  test "H3 downstream serializes one ordered Cookie on the dedicated H1 upstream", %{
    tmp_dir: directory
  } do
    root = Path.expand("../../..", __DIR__)

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), directory],
               stderr_to_stdout: true
             )

    {listener, origin} = origin()
    {instance, options, nil} = upstream(listener, :dedicated)

    {:ok, spec} =
      Gaoxy.HTTP.HTTP3.service_spec(
        id: :http3,
        endpoint: {Gaoxy.Proxy.HTTP, options},
        tls: %{
          certfile: Path.join(directory, "cert.pem"),
          keyfile: Path.join(directory, "key.pem")
        },
        limits: %{max_bytes: 536_870_912}
      )

    assert {:ok, _} = Gaoxy.add(instance, spec)
    {:ok, {_, port}} = Gaoxy.info(instance, :http3).local
    python = System.get_env("GAOXY_QUIC_PYTHON") || Path.join(root, ".audit/h2peer/bin/python")

    peer = ~S'''
    import asyncio, sys
    from types import SimpleNamespace
    sys.path.insert(0,'integration/http3')
    from peer import opened
    args=SimpleNamespace(mode='startup',port=int(sys.argv[1]),ca=sys.argv[2])
    async def run():
        async with opened(args) as client:
            sid=client.request(path=b'/cookies',extra=[(b'cookie',b'a=1'),(b'x-trace',b'first'),
                (b'cookie',b'b=2; c=3'),(b'x-trace',b'second'),(b'cookie',b'd=4')])
            await client.response(sid,b'ok')
        print('H3_COOKIE_WIRE_PASS')
    asyncio.run(run())
    '''

    {output, status} =
      System.cmd(python, ["-c", peer, to_string(port), Path.join(directory, "ca.pem")],
        cd: root,
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert output =~ "H3_COOKIE_WIRE_PASS"
    assert_cookie_wire(Task.await(origin, 5_000))
    assert :ok = Gaoxy.stop(instance, 5_000)
  end

  defp origin do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_tcp.close(listener) end)

    task =
      Task.async(fn ->
        {:ok, socket} = :gen_tcp.accept(listener, 5_000)
        wire = read_head(socket, "")

        :ok =
          :gen_tcp.send(
            socket,
            "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"
          )

        :gen_tcp.close(socket)
        wire
      end)

    {listener, task}
  end

  defp upstream(listener, mode) do
    {:ok, {_, port}} = :inet.sockname(listener)
    url = "http://127.0.0.1:#{port}"
    {:ok, instance} = Gaoxy.start_link()
    on_exit(fn -> if Process.alive?(instance), do: Gaoxy.stop(instance, 5_000) end)

    if mode == :managed do
      {:ok, owner} =
        UpstreamTransports.start_link(
          instance: instance,
          limits: %{
            max_resources: 1,
            max_pins: 32,
            max_request_tokens: 32,
            max_owned_payload_bytes: 4_194_304
          }
        )

      deadline = Gaoxy.Lifecycle.deadline(5_000)

      {:ok, handle, preparation} =
        UpstreamTransports.prepare(
          owner,
          %{origin: url, connect_address: {127, 0, 0, 1}, trust: nil},
          self(),
          deadline
        )

      {:ok, baseline} = Resources.pin_many([handle], self(), :baseline, deadline)
      :ok = Resources.release(preparation)
      {instance, %{upstream: url, transport: handle}, baseline}
    else
      {instance, %{upstream: url}, nil}
    end
  end

  defp read_head(socket, bytes) do
    if String.contains?(bytes, "\r\n\r\n") do
      bytes
    else
      assert {:ok, next} = :gen_tcp.recv(socket, 0, 5_000)
      read_head(socket, bytes <> next)
    end
  end

  defp assert_cookie_wire(wire) do
    [head, _body] = String.split(wire, "\r\n\r\n", parts: 2)
    [request | fields] = String.split(head, "\r\n", trim: true)
    assert request == "GET /cookies HTTP/1.1"

    fields =
      Enum.map(fields, fn field ->
        [name, value] = String.split(field, ":", parts: 2)
        {String.downcase(name), String.trim_leading(value)}
      end)

    assert [{"cookie", "a=1; b=2; c=3; d=4"}] = Enum.filter(fields, &match?({"cookie", _}, &1))

    assert [{"x-trace", "first"}, {"x-trace", "second"}] =
             Enum.filter(fields, &match?({"x-trace", _}, &1))
  end
end
