defmodule Gaoxy.HTTP2DiagnosticsTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.HTTP2.Frame
  alias HTTP.HTTP2.HPACK

  @wait 3_000
  @event [:gaoxy, :http, :failure]

  defmodule FailurePlug do
    import Plug.Conn
    def init(observer), do: observer

    def call(conn, observer) do
      case conn.request_path do
        "/before" ->
          raise "secret exception before response"

        "/after" ->
          conn = send_chunked(conn, 201)
          {:ok, _conn} = chunk(conn, "partial")
          raise "secret exception after response"

        "/throw" ->
          throw({:secret, "credential"})

        "/body" ->
          send(observer, {:h2_body_entered, self()})

          receive do
            :never -> conn
          end

        "/timeout" ->
          send(observer, {:h2_timeout_entered, self()})

          receive do
            :never -> conn
          end

        _ ->
          send_resp(conn, 200, "ok")
      end
    end
  end

  defmodule Endpoint do
    def init(observer), do: {:ok, observer}
    def call(%{request: %{path: "/unset"}} = exchange, _observer), do: {:ok, exchange}

    def call(exchange, observer),
      do: Gaoxy.HTTP.PlugEndpoint.call(exchange, {FailurePlug, observer})
  end

  setup do
    handler = make_ref()
    :ok = :telemetry.attach(handler, @event, &__MODULE__.capture/4, self())
    on_exit(fn -> :telemetry.detach(handler) end)
    :ok
  end

  def capture(event, measurements, metadata, observer),
    do: send(observer, {event, measurements, metadata})

  test "invalid HTTP/2 headers emit one bounded stream-local rejection" do
    socket = connect()
    send_headers(socket, 1, "/secret?token=credential", [{"connection", "keep-alive"}])
    assert_reset(socket, 1)
    metadata = failure(1, :headers, :malformed_request, nil, false)
    assert is_reference(metadata.request_id)
    assert_safe(metadata)
    assert_healthy(socket, 3)
    refute_receive {@event, _, _}, 0
  end

  test "Plug exception before commitment reports the actual 500 and preserves other streams" do
    socket = connect()
    send_headers(socket, 1, "/before")
    assert_response(socket, 1, 500)
    metadata = failure(1, :endpoint, :plug_exception, 500, true)
    assert_safe(metadata)
    assert_healthy(socket, 3)
    refute_receive {@event, _, _}, 0
  end

  test "Plug exception after commitment reports the sent 201 exactly once" do
    socket = connect()
    send_headers(socket, 1, "/after")
    assert_reset(socket, 1)
    metadata = failure(1, :endpoint, :plug_exception, 201, true)
    assert_safe(metadata)
    assert_healthy(socket, 3)
    refute_receive {@event, _, _}, 0
  end

  test "escaped endpoint throw is classified without the thrown value" do
    socket = connect()
    send_headers(socket, 1, "/throw")
    assert_response(socket, 1, 500)
    metadata = failure(1, :endpoint, :endpoint_throw, 500, true)
    assert_safe(metadata)
    assert_healthy(socket, 3)
    refute_receive {@event, _, _}, 0
  end

  test "expired request emits a stream-local timeout without claiming a response" do
    socket = connect(%{request_timeout: 100})
    send_headers(socket, 1, "/timeout")
    assert_receive {:h2_timeout_entered, worker}, @wait
    monitor = Process.monitor(worker)
    assert_reset(socket, 1)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, @wait
    metadata = failure(1, :request, :request_timeout, nil, false)
    assert_safe(metadata)
    assert_healthy(socket, 3)
    refute_receive {@event, _, _}, 0
  end

  test "incomplete header block reports its stream before existing protocol GOAWAY" do
    socket = connect(%{}, %{frame_timeout: 100})
    assert {4, 0, 0, _} = frame(socket)
    :ok = :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
    assert {4, 1, 0, ""} = frame(socket)
    :ok = :gen_tcp.send(socket, Frame.encode(1, 1, 1, ""))
    assert {7, _, 0, _} = frame(socket)
    metadata = failure(1, :headers, :header_timeout, nil, false)
    assert_safe(metadata)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @wait)
    refute_receive {@event, _, _}, 0
  end

  test "successful endpoint result with no response reports the 500 fallback" do
    socket = connect()
    send_headers(socket, 1, "/unset")
    assert_response(socket, 1, 500)
    assert_safe(failure(1, :endpoint, :response_not_sent, 500, true))
    assert_healthy(socket, 3)
    refute_receive {@event, _, _}, 0
  end

  test "DATA exceeding the body limit reports a stream-local rejection" do
    socket = connect(%{max_body_bytes: 3})
    send_headers(socket, 1, "/body", [], false)
    assert_receive {:h2_body_entered, _}, @wait
    :ok = :gen_tcp.send(socket, Frame.encode(0, 1, 1, "four"))
    assert_reset(socket, 1)
    assert_safe(failure(1, :request, :body_limit, nil, false))
    assert_healthy(socket, 3)
    refute_receive {@event, _, _}, 0
  end

  test "DATA disagreeing with content length reports a stream-local rejection" do
    socket = connect()
    send_headers(socket, 1, "/body", [{"content-length", "1"}], false)
    assert_receive {:h2_body_entered, _}, @wait
    :ok = :gen_tcp.send(socket, Frame.encode(0, 1, 1, "two"))
    assert_reset(socket, 1)
    assert_safe(failure(1, :request, :malformed_body, nil, false))
    assert_healthy(socket, 3)
    refute_receive {@event, _, _}, 0
  end

  defp connect(http_limits \\ %{}, h2_limits \\ %{}) do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint: {Endpoint, self()},
        protocols: [:http2],
        h2c: :prior_knowledge,
        limits: %{max_bytes: 536_870_912, max_active: 128},
        http_limits: Map.merge(%{request_timeout: 5_000}, http_limits),
        h2_limits: h2_limits
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @wait) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @wait)
    on_exit(fn -> :gen_tcp.close(socket) end)
    :ok = :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", Frame.encode(4, 0, 0, "")])
    socket
  end

  defp send_headers(socket, id, path, extra \\ [], ended \\ true) do
    fields =
      [
        {":method", "GET"},
        {":scheme", "http"},
        {":authority", "localhost"},
        {":path", path}
      ] ++ extra

    {_, block} =
      HPACK.encode_headers(HPACK.new_encoder(), fields, indexing: :never, huffman: :never)

    :ok = :gen_tcp.send(socket, Frame.encode(1, if(ended, do: 5, else: 4), id, block))
  end

  defp assert_healthy(socket, id) do
    send_headers(socket, id, "/ok")
    assert_response(socket, id, 200)
  end

  defp failure(id, stage, reason, status, committed) do
    assert_receive {@event, %{count: 1, duration: duration}, metadata}, @wait
    assert duration >= 0

    assert %{
             protocol: :http2,
             stream_id: ^id,
             stage: ^stage,
             reason: ^reason,
             status: ^status,
             response_committed: ^committed
           } = metadata

    metadata
  end

  defp assert_safe(metadata) do
    assert Enum.sort(Map.keys(metadata)) ==
             Enum.sort([
               :protocol,
               :stream_id,
               :stage,
               :reason,
               :status,
               :response_committed,
               :request_id
             ])

    refute inspect(metadata) =~ "secret"
    refute inspect(metadata) =~ "credential"
  end

  defp assert_response(socket, id, status, seen \\ nil) do
    case frame(socket) do
      {1, flags, ^id, bytes} ->
        {:ok, _, fields} = HPACK.decode(HPACK.new_decoder(), bytes)
        assert {":status", Integer.to_string(status)} in fields
        if Frame.flag?(flags, 1), do: :ok, else: assert_response(socket, id, status, status)

      {0, flags, ^id, _} ->
        assert seen == status
        if Frame.flag?(flags, 1), do: :ok, else: assert_response(socket, id, status, seen)

      {4, flags, 0, _} ->
        unless Frame.flag?(flags, 1), do: :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
        assert_response(socket, id, status, seen)

      other ->
        flunk("unexpected frame #{inspect(other)}")
    end
  end

  defp assert_reset(socket, id) do
    case frame(socket) do
      {3, _, ^id, _} ->
        :ok

      {4, flags, 0, _} ->
        unless Frame.flag?(flags, 1), do: :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
        assert_reset(socket, id)

      {type, _, ^id, _} when type in [0, 1] ->
        assert_reset(socket, id)

      other ->
        flunk("unexpected frame #{inspect(other)}")
    end
  end

  defp frame(socket) do
    {:ok, <<size::24, type, flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, @wait)
    bytes = if size == 0, do: "", else: elem(:gen_tcp.recv(socket, size, @wait), 1)
    {type, flags, id, bytes}
  end
end
