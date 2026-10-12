defmodule Gaoxy.HTTP.HTTP3.OptionsTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.HTTP3.Options

  defmodule Endpoint do
    def init(observer) do
      send(observer, :initialized)
      {:ok, observer}
    end

    def call(exchange, _), do: {:ok, exchange}
  end

  defp options do
    [endpoint: {Endpoint, self()}, tls: %{certfile: "fixture.pem", keyfile: "fixture-key.pem"}]
  end

  test "H3 explicitly opts into QUIC and initializes its endpoint once" do
    assert {:ok, service} = Options.normalize(options())
    assert %{transport: :quic, quic: %{alpn: ["h3"]}, handler_options: handler} = service
    assert %{endpoint: {Endpoint, observer}, initialized: true} = handler
    assert observer == self()
    assert_receive :initialized
    refute_receive :initialized
    assert handler.h3_limits.dynamic_table_capacity == 0
    assert handler.h3_limits.blocked_streams == 0
    assert service.limits.max_state >= Options.reservation(handler).connection
  end

  test "rejects absent credentials, unsupported bindings and ALPN before activation" do
    assert {:error, :missing_credentials} = Options.normalize(Keyword.delete(options(), :tls))

    assert {:error, :missing_credentials} =
             Options.normalize(Keyword.put(options(), :tls, %{certfile: "", keyfile: "key"}))

    assert {:error, :wildcard_bind_unsupported} =
             Options.normalize(Keyword.put(options(), :ip, {0, 0, 0, 0}))

    assert {:error, {:unsupported_capability, :quic_ipv6}} =
             Options.normalize(Keyword.put(options(), :ip, {0, 0, 0, 0, 0, 0, 0, 1}))

    assert {:error, :unsupported_http3_alpn} =
             Options.normalize(Keyword.put(options(), :quic, %{alpn: ["h2"]}))

    refute_received :initialized
  end

  test "rejects unknown, duplicate and mixed protocol options" do
    assert {:error, :invalid_http3_options} = Options.normalize(options() ++ [port: 0, port: 1])
    assert {:error, :invalid_http3_options} = Options.normalize(options() ++ [unknown: true])

    assert {:error, :invalid_http3_options} =
             Options.normalize(options() ++ [protocols: [:http3, :http2]])

    assert {:error, :invalid_http3_options} = Options.normalize(%{})
    refute_received :initialized
  end

  test "rejects invalid identity and TLS options" do
    for entry <- [id: nil, port: 65_536, ip: {256, 0, 0, 1}, transport: :tcp] do
      assert {:error, _} = Options.normalize(Keyword.merge(options(), [entry]))
    end

    assert {:error, :invalid_http3_tls} =
             Options.normalize(
               Keyword.put(options(), :tls, %{certfile: "c", keyfile: "k", alpn: ["h3"]})
             )

    refute_received :initialized
  end

  test "requires exactly one endpoint or Plug tuple" do
    assert {:error, :invalid_endpoint} = Options.normalize(Keyword.delete(options(), :endpoint))

    assert {:error, :invalid_endpoint} =
             Options.normalize(options() ++ [plug: {Endpoint, []}])
  end

  test "zero-capacity QPACK and finite stream/output limits are enforced" do
    for input <- [
          %{dynamic_table_capacity: 1},
          %{blocked_streams: 1},
          %{max_streams: 0},
          %{max_pending_output: 65_537},
          %{max_header_block: 32_769},
          %{control_turn: 0},
          %{unknown: 1}
        ] do
      assert {:error, :invalid_http3_limits} =
               Options.normalize(Keyword.put(options(), :h3_limits, input))
    end

    refute_received :initialized
  end

  test "aggregate connection/request reservations are validated" do
    for limits <- [
          %{max_state: 65_536},
          %{max_bytes: 1_048_576},
          %{max_active: 8},
          %{max_packet: 1_024},
          %{max_output: 1_024}
        ] do
      assert {:error, :http3_byte_budget} =
               Options.normalize(Keyword.put(options(), :limits, limits))

      refute_received :initialized
    end

    assert {:error, :invalid_http_limit} =
             Options.normalize(Keyword.put(options(), :http_limits, %{max_read_chunk: 65_537}))

    assert {:error, :unknown_http_limit} =
             Options.normalize(Keyword.put(options(), :http_limits, %{unknown: 1}))
  end

  test "the connection reservation includes independent unidirectional parser carry" do
    assert {:ok, service} = Options.normalize(options())
    handler = service.handler_options
    reserve = Options.reservation(handler)

    assert reserve.unidirectional >=
             3 * handler.http_limits.max_buffer_bytes + 5 * handler.h3_limits.max_header_block

    assert service.limits.max_state >= reserve.connection

    assert {:error, :http3_byte_budget} =
             Options.normalize(Keyword.put(options(), :limits, %{max_state: 2_080_768}))
  end
end
