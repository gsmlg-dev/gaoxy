defmodule Gaoxy.HTTP.NativeWebSocketProxyTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Exchange, WebSocket}
  alias Gaoxy.HTTP.WebSocket.Message

  defmodule Handler do
    def init(owner) do
      send(owner, {:ws_ready, self()})
      {:ok, owner}
    end

    def handle_in(_, owner), do: {:ok, owner}

    def handle_info({:push, messages, reference}, owner),
      do: {:gaoxy_push, messages, {owner, reference}, owner}

    def handle_info({:stop, detail}, owner), do: {:stop, :normal, detail, owner}

    def gaoxy_close(detail, owner) do
      send(owner, {:peer_close, detail, self()})

      receive do
        :allow_close -> {:ok, owner}
      end
    end

    def terminate(reason, owner), do: send(owner, {:terminated, reason})
  end

  defmodule Endpoint do
    @behaviour Gaoxy.HTTP.Endpoint
    def init(owner), do: {:ok, owner}

    def call(exchange, owner) do
      send(owner, {:metadata, exchange.service, exchange.instance})
      WebSocket.prepare(exchange, {Handler, owner, []})
    end
  end

  defmodule ControlledTransport do
    def send(owner, bytes) do
      Kernel.send(owner, {:write_started, self(), IO.iodata_to_binary(bytes)})

      receive do
        {:complete_write, result} -> result
      end
    end
  end

  test "optional callback observes empty peer close before native echo" do
    {socket, _server, owner} = connect()
    :ok = :gen_tcp.send(socket, masked_close(""))
    assert_receive {:peer_close, {nil, ""}, ^owner}
    assert {:error, :timeout} = :gen_tcp.recv(socket, 0, 5)
    send(owner, :allow_close)
    assert {:ok, <<0x88, 0>>} = :gen_tcp.recv(socket, 2, 1000)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
    assert_receive {:terminated, :remote}
  end

  test "optional callback preserves valid peer code and UTF-8 reason before echo" do
    {socket, _server, owner} = connect()
    payload = <<1001::16, "leaving"::binary>>
    :ok = :gen_tcp.send(socket, masked_close(payload))
    assert_receive {:peer_close, {1001, "leaving"}, ^owner}
    assert {:error, :timeout} = :gen_tcp.recv(socket, 0, 5)
    send(owner, :allow_close)
    assert {:ok, <<0x88, 9, ^payload::binary>>} = :gen_tcp.recv(socket, 11, 1000)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
    assert_receive {:terminated, :remote}
  end

  test "native exchange carries exact instance and service PIDs from context" do
    {_socket, server, _owner} = connect()
    assert_receive {:metadata, service, ^server}
    assert is_pid(service)
    assert Process.alive?(service)
  end

  test "empty local close output is a valid zero-length frame" do
    {socket, _server, owner} = connect()
    send(owner, {:stop, {nil, ""}})
    assert {:ok, <<0x88, 0>>} = :gen_tcp.recv(socket, 2, 1000)
    :ok = :gen_tcp.send(socket, masked_close(""))
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
    assert_receive {:terminated, :normal}
  end

  test "reserved close codes never reach the wire" do
    for code <- [1005, 1006, 1015] do
      {socket, _server, owner} = connect()
      send(owner, {:stop, {code, ""}})
      assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
    end
  end

  test "push acknowledges only after every frame write succeeds" do
    reference = make_ref()
    {worker, monitor} = writer(reference, [{:text, "one"}, {:binary, "two"}])
    assert_receive {:write_started, ^worker, <<0x81, 3, "one">>}
    refute_received {:gaoxy_websocket_written, ^reference, :ok}
    send(worker, {:complete_write, :ok})
    assert_receive {:write_started, ^worker, <<0x82, 3, "two">>}
    refute_received {:gaoxy_websocket_written, ^reference, :ok}
    send(worker, {:complete_write, :ok})
    assert_receive {:gaoxy_websocket_written, ^reference, :ok}
    assert_receive {:writer_result, ^worker, :continue}
    assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}
  end

  test "failed write never acknowledges success or sends later data frames" do
    reference = make_ref()
    {worker, monitor} = writer(reference, [{:text, "one"}, {:binary, "two"}])
    assert_receive {:write_started, ^worker, <<0x81, 3, "one">>}
    send(worker, {:complete_write, {:error, :closed}})
    assert_receive {:gaoxy_websocket_written, ^reference, {:error, :closed}}
    assert_receive {:write_started, ^worker, <<0x88, 2, 1011::16>>}
    send(worker, {:complete_write, {:error, :closed}})
    assert_receive {:writer_result, ^worker, :close}
    assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}
    refute_received {:gaoxy_websocket_written, ^reference, :ok}
    refute_received {:write_started, ^worker, <<0x82, _::binary>>}
  end

  defp writer(reference, messages) do
    owner = self()
    {:ok, spec} = Gaoxy.HTTP.service_spec(endpoint: {Endpoint, owner})

    {:ok, gate} =
      Gaoxy.Admission.start_link({spec.limits, %{instance: make_ref(), service: :test}})

    on_exit(fn -> if Process.alive?(gate), do: GenServer.stop(gate) end)

    {worker, monitor} =
      spawn_monitor(fn ->
        {:ok, lease} = Gaoxy.Admission.acquire(gate, 0)

        socket =
          struct!(Hell.Socket,
            socket: owner,
            transport_module: ControlledTransport,
            read_timeout: 1000,
            handshake_timeout: 1000,
            silent_terminate_on_error: false,
            span: Hell.Telemetry.start_span(:connection, %{}, %{handler: __MODULE__})
          )

        {:ok, limits} = websocket_limits(spec, owner)

        exchange = %Exchange{
          socket: socket,
          gate: gate,
          lease: lease,
          buffer: "",
          limits: Map.put(spec.handler_options.http_limits, :max_write_chunk, 1024)
        }

        ws = %WebSocket{
          exchange: exchange,
          handler: Handler,
          app_state: owner,
          limits: limits,
          deadline: Gaoxy.Lifecycle.deadline(5000),
          message: Message.new()
        }

        {action, _ws} = WebSocket.info({:push, messages, reference}, ws)
        send(owner, {:writer_result, self(), action})
      end)

    on_exit(fn -> if Process.alive?(worker), do: Process.exit(worker, :kill) end)
    {worker, monitor}
  end

  defp websocket_limits(spec, owner) do
    {:ok, request, ""} =
      Gaoxy.HTTP.HTTP1.Parser.parse_head(request(), spec.handler_options.http_limits)

    exchange = %Exchange{request: request}

    {:ok, %{response: {:websocket, _, _, limits, _}}} =
      WebSocket.prepare(exchange, {Handler, owner, []})

    {:ok, Map.put(limits, :max_state, spec.limits.max_state)}
  end

  defp connect do
    {:ok, server} = Gaoxy.HTTP.start_link(endpoint: {Endpoint, self()})
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    :ok = :gen_tcp.send(socket, request())
    assert head(socket, "") =~ "101 Switching Protocols"
    assert_receive {:ws_ready, owner}
    {socket, server, owner}
  end

  defp request,
    do:
      "GET /socket HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"

  defp head(socket, bytes) do
    if String.ends_with?(bytes, "\r\n\r\n") do
      bytes
    else
      {:ok, byte} = :gen_tcp.recv(socket, 1, 1000)
      head(socket, bytes <> byte)
    end
  end

  defp masked_close(payload), do: <<0x88, 1::1, byte_size(payload)::7, 0::32>> <> payload
end
