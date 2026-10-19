defmodule Gaoxy.HTTP2CapacityTest do
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

      {block, _} = HPAX.encode(:never_store, fields, HPAX.new(4_096))

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

  defp response(socket, result \\ %{status: nil, body: ""}, decoder \\ HPAX.new(4_096)) do
    {:ok, <<size::24, type, flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, @timeout)
    bytes = if size == 0, do: "", else: elem(:gen_tcp.recv(socket, size, @timeout), 1)

    case {type, id} do
      {1, 1} ->
        assert Frame.flag?(flags, 4)
        {:ok, fields, decoder} = HPAX.decode(bytes, decoder)
        {":status", status} = List.keyfind(fields, ":status", 0)
        next = %{result | status: status}
        if Frame.flag?(flags, 1), do: next, else: response(socket, next, decoder)

      {0, 1} ->
        next = %{result | body: result.body <> bytes}
        if Frame.flag?(flags, 1), do: next, else: response(socket, next, decoder)

      {4, 0} ->
        unless Frame.flag?(flags, 1), do: :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
        response(socket, result, decoder)

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
