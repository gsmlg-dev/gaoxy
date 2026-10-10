defmodule Gaoxy.HTTP2ProtocolTest do
  use ExUnit.Case, async: true
  alias __MODULE__.Endpoint

  test "frame length is rejected from the advertised header before buffering its payload" do
    header = <<16_385::24, 0, 0, 0::1, 1::31>>
    assert {:error, :frame_size_error} = apply(Gaoxy.HTTP.HTTP2.Frame, :decode, [header, 16_384])
    assert :more = apply(Gaoxy.HTTP.HTTP2.Frame, :decode, [<<0::24, 4>>, 16_384])

    assert {:ok, %{type: 4, flags: 0, id: 0, payload: ""}, "tail"} =
             apply(Gaoxy.HTTP.HTTP2.Frame, :decode, [<<0::24, 4, 0, 0::32, "tail">>, 16_384])
  end

  test "settings validate wire values and retain negative stream-window deltas" do
    defaults = apply(Gaoxy.HTTP.HTTP2.Settings, :defaults, [])

    assert {:ok, %{initial_window: 0}, -65_535} =
             apply(Gaoxy.HTTP.HTTP2.Settings, :apply, [defaults, <<4::16, 0::32>>])

    assert {:error, :flow_control_error} =
             apply(Gaoxy.HTTP.HTTP2.Settings, :apply, [defaults, <<4::16, 2_147_483_648::32>>])

    assert {:error, :protocol_error} =
             apply(Gaoxy.HTTP.HTTP2.Settings, :apply, [defaults, <<2::16, 2::32>>])

    assert {:error, :frame_size_error} =
             apply(Gaoxy.HTTP.HTTP2.Settings, :apply, [defaults, <<1, 2>>])
  end

  test "header mapping rejects pseudoheader ambiguity and retains escaped targets" do
    {:ok, spec} = Gaoxy.HTTP.service_spec(endpoint: {Endpoint, []})
    limits = spec.handler_options.http_limits

    fields = [
      {":method", "POST"},
      {":scheme", "http"},
      {":authority", "example.test"},
      {":path", "/a%2Fb?x=%2F"},
      {"content-length", "3"},
      {"x-value", "a"},
      {"x-value", "b"}
    ]

    assert {:ok,
            %{
              version: :"HTTP/2",
              path: "/a%2Fb",
              query_string: "x=%2F",
              body: {:length, 3},
              headers: [{"content-length", "3"}, {"x-value", "a"}, {"x-value", "b"}]
            }} =
             apply(Gaoxy.HTTP.HTTP2.Headers, :request, [fields, false, limits])

    for invalid <- [
          [{"x", "a"} | fields],
          fields ++ [{":method", "GET"}],
          fields ++ [{"connection", "close"}],
          fields ++ [{"host", "other.test"}],
          fields ++ [{"X-UPPER", "x"}]
        ] do
      assert {:error, :protocol_error, _} =
               apply(Gaoxy.HTTP.HTTP2.Headers, :request, [invalid, false, limits])
    end
  end

  test "an independent peer's default SETTINGS ignore unsupported extension identifiers" do
    defaults = Gaoxy.HTTP.HTTP2.Settings.defaults()

    payload =
      <<1::16, 4096::32, 2::16, 1::32, 4::16, 65535::32, 5::16, 16384::32, 8::16, 0::32, 3::16,
        100::32, 6::16, 65536::32>>

    assert {:ok, %{max_header_list: 65536}, 0} =
             Gaoxy.HTTP.HTTP2.Settings.apply(defaults, payload)

    assert {:ok, ^defaults, 0} =
             Gaoxy.HTTP.HTTP2.Settings.apply(defaults, <<8::16, 1::32, 65535::16, 42::32>>)
  end

  test "codec reservation includes worst-case expansion before dispatch capacity" do
    {:ok, spec} = Gaoxy.HTTP.service_spec(endpoint: {Endpoint, []})
    {:ok, h2} = apply(Gaoxy.HTTP.HTTP2.Limits, :normalize, [%{}])

    reservations =
      apply(Gaoxy.HTTP.HTTP2.Limits, :reservation, [spec.handler_options.http_limits, h2])

    assert reservations.decode >= 2 * 16_384 * 4_098 + 512 * 16_384 + 2 * 4_096
    assert reservations.connection >= reservations.decode + 16_777_216
    assert reservations.stream > 0
    assert reservations.writer > 0
  end

  test "invalid TLS protocol options return an error before ALPN mapping" do
    for protocols <- [[:unknown], :http2, nil, ["h2"], [:http1, :http2]] do
      assert {:error, :invalid_http_protocols} =
               Gaoxy.HTTP.service_spec(
                 endpoint: {Endpoint, []},
                 transport: :tls,
                 protocols: protocols
               )
    end
  end

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: {:ok, exchange}
  end
end
