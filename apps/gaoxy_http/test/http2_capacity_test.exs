defmodule Gaoxy.HTTP2CapacityTest do
  alias HTTP.HTTP2.HPACK
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.{Exchange, Response}
  alias Gaoxy.HTTP.HTTP2.Frame
  @timeout 2_000
  @budget 268_435_456

  defmodule Endpoint do
    def init(owner), do: {:ok, owner}

    def call(exchange, owner) do
      send(owner, {:capacity_native, exchange.transport_state})

      case Exchange.read_body_step(exchange, 65_536, 500) do
        {result, bytes, next} when result in [:ok, :more] ->
          Response.send_resp(next, 200, [], bytes)

        {:error, reason, next} ->
          {:error, reason, next}
      end
    end
  end

  test "control rate above the qualified ceiling is rejected before binding" do
    assert_rejected_before_bind(%{control_rate: 4_097}, :invalid_http2_limits)
  end

  test "control turn above the qualified ceiling is rejected before binding" do
    assert_rejected_before_bind(%{control_turn: 129}, :invalid_http2_limits)
  end

  test "maximum qualified control limits preserve a real endpoint response" do
    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               options(h2_limits: %{control_rate: 4_096, control_turn: 128})
             )

    assert spec.handler_options.h2_limits.control_rate == 4_096
    assert spec.handler_options.h2_limits.control_turn == 128

    assert {%{status: "200", body: "hello"}, _native} =
             request(h2_limits: %{control_rate: 4_096, control_turn: 128})
  end

  test "a budget sufficient for default ingress rejects carry as large as the whole budget" do
    port = unused_port()
    assert {%{status: "200", body: "hello"}, _native} = request(port: port)
    assert_rebindable(port)

    # The carry alone equals the entire budget; decoding, writer and stream
    # obligations need additional room, independently of their exact formula.
    result = Gaoxy.HTTP.start_link(options(port: port, http_limits: %{max_buffer_bytes: @budget}))
    stop_unexpected_server(result)
    assert_rebindable(port)
    assert result == {:error, :http2_byte_budget}
  end

  test "large body credit preserves payload without enlarging native ingress buffers" do
    assert {%{status: "200", body: "hello"}, baseline} = request([])

    assert {%{status: "200", body: "hello"}, large} =
             request(http_limits: %{max_read_chunk: 65_536, max_buffer_bytes: 131_072})

    assert large == baseline
    assert large[:buffer] == 16_384
  end

  test "decode reservation grows before HPACK table insertion and retains its high water" do
    {server, socket} = live_connection()
    fields = request_fields() ++ [{"x-pad", String.duplicate("a", 3_000)}]

    {encoder, block} =
      HPACK.encode_headers(HPACK.new_encoder(), fields, indexing: :incremental, huffman: :never)

    block = IO.iodata_to_binary(block)
    send_head_and_body(socket, block)
    assert_receive {:capacity_native, {owner, 1, _}}, @timeout
    assert response(socket) == %{status: "200", body: "hello"}
    {_, state} = :sys.get_state(owner)
    reserve = Gaoxy.HTTP.HTTP2.Limits.decode_reservation(state.h2, byte_size(block))
    assert state.decode_reservation == reserve
    gate = :sys.get_state(state.gate)
    assert gate.leases[state.lease].bytes == state.reserves.connection + reserve

    # Reuse the inserted dynamic entry. A short indexed block must preserve
    # both the HPACK context and the connection's existing expansion charge.
    {_, indexed} = HPACK.encode_headers(encoder, fields, indexing: :incremental, huffman: :never)
    assert IO.iodata_length(indexed) < byte_size(block)
    send_head_and_body(socket, indexed, 3)
    assert_receive {:capacity_native, {^owner, 3, _}}, @timeout

    assert response(
             socket,
             %{status: nil, body: ""},
             HPACK.new_decoder(max_dynamic_size: 4_096),
             3
           ) ==
             %{status: "200", body: "hello"}

    {_, after_indexed} = :sys.get_state(owner)
    assert after_indexed.decode_reservation == reserve
    assert %{rejected: 0} = Gaoxy.status(server, :http)
  end

  test "unavailable expansion capacity rejects a block before HPACK decoding" do
    {_server, socket} = live_connection()

    {_, block} =
      HPACK.encode_headers(HPACK.new_encoder(), request_fields(),
        indexing: :never,
        huffman: :never
      )

    send_head_and_body(socket, block)
    assert_receive {:capacity_native, {owner, 1, _}}, @timeout
    assert response(socket) == %{status: "200", body: "hello"}
    {_, state} = :sys.get_state(owner)
    retained = Gaoxy.Admission.status(state.gate).retained_bytes
    parent = self()

    {filler, monitor} =
      spawn_monitor(fn ->
        {:ok, _lease} = Gaoxy.Admission.acquire(state.gate, @budget - retained - 1_024)
        send(parent, :capacity_filled)

        receive do
          :stop -> :ok
        end
      end)

    on_exit(fn -> send(filler, :stop) end)
    assert_receive :capacity_filled, @timeout

    # Index zero is malformed HPACK and would produce COMPRESSION_ERROR (9)
    # if reached. Resource rejection must happen first, before any expansion.
    :ok = :gen_tcp.send(socket, Frame.encode(1, 5, 3, :binary.copy(<<0x80>>, 4_096)))
    assert_goaway(socket, 11)
    send(filler, :stop)
    assert_receive {:DOWN, ^monitor, :process, ^filler, :normal}, @timeout
  end

  test "an unsupported native TCP backend is rejected by pure prebind validation" do
    with_env(:kernel, :inet_backend, :inet, fn ->
      assert {:ok, _} = Gaoxy.HTTP.service_spec(options())

      with_env(:kernel, :inet_backend, :socket, fn ->
        assert {:error, _reason} = Gaoxy.HTTP.service_spec(options())
      end)
    end)
  end

  test "OTP TLS delivery profiles must stay within the qualified finite range" do
    tls_options =
      options(transport: :tls, h2c: :disabled, tls: %{certfile: "cert.pem", keyfile: "key.pem"})

    with_env(:kernel, :inet_backend, :inet, fn ->
      for active <- [1, 100] do
        with_env(:ssl, :internal_active_n, active, fn ->
          assert {:ok, _} = Gaoxy.HTTP.service_spec(tls_options)
        end)
      end

      for active <- [101, 0, :infinity] do
        with_env(:ssl, :internal_active_n, active, fn ->
          assert {:error, _reason} = Gaoxy.HTTP.service_spec(tls_options)
        end)
      end
    end)
  end

  defp options(overrides \\ []) do
    Keyword.merge(
      [
        endpoint: {Endpoint, self()},
        protocols: [:http2],
        h2c: :prior_knowledge,
        limits: %{max_bytes: @budget, max_active: 128},
        http_limits: %{request_timeout: 5_000}
      ],
      overrides
    )
  end

  defp assert_rejected_before_bind(h2, reason) do
    port = unused_port()
    result = Gaoxy.HTTP.start_link(options(port: port, h2_limits: h2))
    stop_unexpected_server(result)
    assert_rebindable(port)
    assert result == {:error, reason}
  end

  defp stop_unexpected_server({:ok, server}), do: assert(:ok == Gaoxy.stop(server, @timeout))
  defp stop_unexpected_server(_), do: :ok

  defp unused_port do
    {:ok, socket} = :gen_tcp.listen(0, ip: {127, 0, 0, 1}, active: false)
    {:ok, {_, port}} = :inet.sockname(socket)
    :ok = :gen_tcp.close(socket)
    assert port > 0
    port
  end

  defp assert_rebindable(port) do
    assert {:ok, socket} =
             :gen_tcp.listen(port, ip: {127, 0, 0, 1}, active: false, reuseaddr: true)

    assert {:ok, {{127, 0, 0, 1}, ^port}} = :inet.sockname(socket)
    :ok = :gen_tcp.close(socket)
  end

  defp request(overrides) do
    {:ok, server} = Gaoxy.HTTP.start_link(options(overrides))
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @timeout) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    assert port > 0
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)

    try do
      fields = [
        {":method", "POST"},
        {":scheme", "http"},
        {":authority", "localhost"},
        {":path", "/echo"},
        {"content-length", "5"}
      ]

      {_, block} =
        HPACK.encode_headers(HPACK.new_encoder(), fields, indexing: :never, huffman: :never)

      :ok =
        :gen_tcp.send(socket, [
          "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n",
          Frame.encode(4, 0, 0, ""),
          Frame.encode(1, 4, 1, block),
          Frame.encode(0, 1, 1, "hello")
        ])

      assert_receive {:capacity_native, {owner, 1, _}}, @timeout
      {native_socket, _state} = :sys.get_state(owner, @timeout)
      {:ok, native} = Hell.Socket.getopts(native_socket, [:buffer, :recbuf])
      {response(socket), native}
    after
      :ok = :gen_tcp.close(socket)

      eventually(fn ->
        match?(%{active: 0, retained_bytes: 0, cleanup_pending: 0}, Gaoxy.status(server, :http))
      end)

      assert :ok = Gaoxy.stop(server, @timeout)
    end
  end

  defp live_connection do
    {:ok, server} = Gaoxy.HTTP.start_link(options())
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)

    on_exit(fn ->
      :gen_tcp.close(socket)
      if Process.alive?(server), do: Gaoxy.stop(server, @timeout)
    end)

    :ok =
      :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", Frame.encode(4, 0, 0, "")])

    {server, socket}
  end

  defp request_fields do
    [
      {":method", "POST"},
      {":scheme", "http"},
      {":authority", "localhost"},
      {":path", "/echo"},
      {"content-length", "5"}
    ]
  end

  defp send_head_and_body(socket, block, id \\ 1) do
    :ok = :gen_tcp.send(socket, [Frame.encode(1, 4, id, block), Frame.encode(0, 1, id, "hello")])
  end

  defp assert_goaway(socket, code) do
    assert {:ok, <<size::24, type, _flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, @timeout)
    bytes = if size == 0, do: "", else: elem(:gen_tcp.recv(socket, size, @timeout), 1)

    case {type, id} do
      {7, 0} -> assert <<_last::32, ^code::32>> = bytes
      {4, 0} -> assert_goaway(socket, code)
      _ -> flunk("unexpected H2 frame #{type} for stream #{id}: #{inspect(bytes)}")
    end
  end

  defp response(
         socket,
         result \\ %{status: nil, body: ""},
         decoder \\ HPACK.new_decoder(max_dynamic_size: 4_096),
         stream_id \\ 1
       ) do
    {:ok, <<size::24, type, flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, @timeout)
    bytes = if size == 0, do: "", else: elem(:gen_tcp.recv(socket, size, @timeout), 1)

    case {type, id} do
      {1, ^stream_id} ->
        assert Frame.flag?(flags, 4)
        {:ok, decoder, fields} = HPACK.decode(decoder, bytes)
        {":status", status} = List.keyfind(fields, ":status", 0)
        next = %{result | status: status}
        if Frame.flag?(flags, 1), do: next, else: response(socket, next, decoder, stream_id)

      {0, ^stream_id} ->
        next = %{result | body: result.body <> bytes}
        if Frame.flag?(flags, 1), do: next, else: response(socket, next, decoder, stream_id)

      {4, 0} ->
        unless Frame.flag?(flags, 1), do: :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
        response(socket, result, decoder, stream_id)

      _ ->
        flunk("unexpected H2 frame #{type} for stream #{id}: #{inspect(bytes)}")
    end
  end

  defp eventually(predicate, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(@timeout)

    unless predicate.() do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0

      receive do
      after
        1 -> eventually(predicate, deadline)
      end
    end
  end

  defp with_env(application, key, value, fun) do
    original = Application.fetch_env(application, key)
    Application.put_env(application, key, value)

    try do
      fun.()
    after
      case original do
        {:ok, value} -> Application.put_env(application, key, value)
        :error -> Application.delete_env(application, key)
      end
    end
  end
end
