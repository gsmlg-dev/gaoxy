defmodule Gaoxy.HTTP.HTTP2StartupPeerCloseNetworkTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.Connection
  alias Gaoxy.HTTP.HTTP2.Frame
  @wait 3_000

  defmodule BarrierTransport do
    def secure?, do: true
    def negotiated_protocol({native, _}), do: :ssl.negotiated_protocol(native)
    def peername({native, _}), do: :ssl.peername(native)
    def sockname({native, _}), do: :ssl.sockname(native)
    def connection_information({native, _}), do: :ssl.connection_information(native)
    def peercert({native, _}), do: :ssl.peercert(native)
    def close({native, _}), do: :ssl.close(native)
    def getstat({native, _}), do: :ssl.getstat(native)

    def setopts({native, observer}, options) do
      send(observer, {:before_receive_options, self(), options})

      receive do
        :peer_closed -> :ok
      after
        3_000 -> raise "TLS startup peer-close barrier expired"
      end

      closed = :ssl.recv(native, 0, 3_000)
      result = :ssl.setopts(native, options)
      send(observer, {:receive_options_result, self(), closed, result})
      result
    end
  end

  defmodule StartupOwner do
    use GenServer

    def init(args), do: {:ok, args, {:continue, :accept}}

    def handle_continue(:accept, {listener, context, observer}) do
      {:ok, accepted} = :ssl.transport_accept(listener, 3_000)
      {:ok, native} = :ssl.handshake(accepted, 3_000)

      socket = %Hell.Socket{
        socket: {native, observer},
        transport_module: BarrierTransport,
        read_timeout: 3000,
        handshake_timeout: 3000,
        silent_terminate_on_error: false,
        span: Hell.Telemetry.start_span(:connection, %{}, %{handler: Connection})
      }

      Connection.handle_continue(:handle_connection, {socket, context})
    end

    def terminate(reason, {%Hell.Socket{} = socket, context}),
      do: Connection.terminate(reason, {socket, context})

    def terminate(_, _), do: :ok
  end

  defmodule HealthPlug do
    def init(options), do: options
    def call(conn, _), do: Plug.Conn.send_resp(conn, 200, "healthy")
  end

  @tag :tmp_dir
  test "TLS close after successful startup metadata ends normally and leaves healthy H2 service",
       %{
         tmp_dir: dir
       } do
    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    assert {_, 0} = System.cmd("bash", [script, dir], stderr_to_stdout: true)
    cert = Path.join(dir, "cert.pem")
    key = Path.join(dir, "key.pem")

    {:ok, spec} =
      Gaoxy.HTTP.service_spec(plug: {HealthPlug, []}, protocols: [:http2], h2c: :prior_knowledge)

    gate = start_supervised!({Admission, {spec.limits, %{instance: make_ref()}}})

    {:ok, listener} =
      :ssl.listen(0,
        mode: :binary,
        active: false,
        ip: {127, 0, 0, 1},
        certfile: String.to_charlist(cert),
        keyfile: String.to_charlist(key),
        alpn_preferred_protocols: ["h2"]
      )

    on_exit(fn -> :ssl.close(listener) end)
    {:ok, {ip, port}} = :ssl.sockname(listener)

    log =
      capture_log(fn ->
        {:ok, owner} =
          GenServer.start(StartupOwner, {listener, %{spec: spec, gate: gate}, self()})

        monitor = Process.monitor(owner)

        on_exit(fn ->
          if Process.alive?(owner), do: GenServer.stop(owner, :normal, @wait)
        end)

        client = connect(ip, port, dir)
        assert_receive {:before_receive_options, ^owner, [recbuf: 16_384, buffer: 16_384]}, @wait
        assert :ok = :ssl.close(client, @wait)
        send(owner, :peer_closed)

        assert_receive {:receive_options_result, ^owner, {:error, :closed}, {:error, _}}, @wait
        assert_receive {:DOWN, ^monitor, :process, ^owner, {:shutdown, :local_closed}}, @wait
        assert %{active: 0, retained_bytes: 0, cleanup_pending: 0} = Admission.status(gate)
      end)

    assert log == ""

    {:ok, server} =
      Gaoxy.HTTP.start_link(
        plug: {HealthPlug, []},
        port: 0,
        transport: :tls,
        tls: %{certfile: cert, keyfile: key}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @wait) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    client = connect(ip, port, dir)

    {_, block} =
      HTTP.HTTP2.HPACK.encode_headers(
        HTTP.HTTP2.HPACK.new_encoder(),
        [
          {":method", "GET"},
          {":scheme", "https"},
          {":authority", "localhost"},
          {":path", "/health"}
        ],
        indexing: :never,
        huffman: :never
      )

    assert :ok =
             :ssl.send(client, [
               "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n",
               Frame.encode(4, 0, 0, ""),
               Frame.encode(1, 5, 1, block)
             ])

    assert response(client, "") == "healthy"
    assert :ok = :ssl.close(client, @wait)
    await_empty(server, Lifecycle.deadline(@wait))
    assert :ok = Gaoxy.stop(server, @wait)
  end

  defp connect(ip, port, dir) do
    {:ok, client} =
      :ssl.connect(
        ip,
        port,
        [
          :binary,
          active: false,
          verify: :verify_peer,
          cacertfile: String.to_charlist(Path.join(dir, "ca.pem")),
          server_name_indication: ~c"localhost",
          alpn_advertised_protocols: ["h2"]
        ],
        @wait
      )

    on_exit(fn -> :ssl.close(client) end)
    assert {:ok, "h2"} = :ssl.negotiated_protocol(client)
    client
  end

  defp response(client, body) do
    assert {:ok, <<size::24, type, flags, _::1, id::31>>} = :ssl.recv(client, 9, @wait)
    payload = if size == 0, do: "", else: elem(:ssl.recv(client, size, @wait), 1)

    case {type, id} do
      {0, 1} ->
        body = body <> payload
        if Frame.flag?(flags, 1), do: body, else: response(client, body)

      {1, 1} ->
        {:ok, _, fields} =
          HTTP.HTTP2.HPACK.decode(HTTP.HTTP2.HPACK.new_decoder(max_dynamic_size: 4096), payload)

        assert {":status", "200"} in fields
        response(client, body)

      {4, 0} ->
        unless Frame.flag?(flags, 1), do: :ssl.send(client, Frame.encode(4, 1, 0, ""))
        response(client, body)

      {8, _} ->
        response(client, body)
    end
  end

  defp await_empty(server, deadline) do
    case Gaoxy.status(server, :http) do
      %{active: 0, retained_bytes: 0, cleanup_pending: 0} ->
        :ok

      _ ->
        assert Lifecycle.remaining(deadline) > 0, "H2 startup resources were not released"

        receive do
        after
          1 -> await_empty(server, deadline)
        end
    end
  end
end
