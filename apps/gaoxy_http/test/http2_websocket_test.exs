defmodule Gaoxy.HTTP.HTTP2WebSocketTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.HTTP2.{Headers, Settings}

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(exchange, _options), do: {:ok, exchange}
  end

  defp fields do
    [
      {":method", "CONNECT"},
      {":protocol", "websocket"},
      {":scheme", "http"},
      {":authority", "example.test"},
      {":path", "/socket?topic=test"},
      {"sec-websocket-version", "13"},
      {"origin", "https://example.test"}
    ]
  end

  defp limits do
    {:ok, spec} = Gaoxy.HTTP.service_spec(endpoint: {Endpoint, []})
    spec.handler_options.http_limits
  end

  test "enabled extended CONNECT retains wire metadata and marks tunnel bytes" do
    assert {:ok, request} = apply(Headers, :request, [fields(), false, limits(), true])
    assert request.method == "CONNECT"
    assert request.protocol == "websocket"
    assert request.version == :"HTTP/2"
    assert request.body == :tunnel
    assert request.target == "/socket?topic=test"
    assert request.path == "/socket"
    assert request.query_string == "topic=test"
    assert request.scheme == :http
    assert {"origin", "https://example.test"} in request.headers
  end

  test "disabled listeners and non-CONNECT pseudoheader use remain rejected" do
    assert {:error, :protocol_error, _} = Headers.request(fields(), false, limits())
    invalid = List.keyreplace(fields(), ":method", 0, {":method", "GET"})

    assert {:error, :protocol_error, _} =
             apply(Headers, :request, [invalid, false, limits(), true])
  end

  test "extended CONNECT validates target and rejects HTTP body framing" do
    for invalid <- [
          fields() ++ [{":protocol", "websocket"}],
          fields() ++ [{"content-length", "0"}],
          List.keydelete(fields(), ":path", 0),
          List.keyreplace(fields(), ":scheme", 0, {":scheme", "https"})
        ] do
      assert {:error, :protocol_error, _} =
               apply(Headers, :request, [invalid, false, limits(), true])
    end
  end

  test "other well-formed extended protocols stay identifiable for a 501 response" do
    other = List.keyreplace(fields(), ":protocol", 0, {":protocol", "example"})

    assert {:ok, %{protocol: "example", method: "CONNECT", body: :tunnel}} =
             apply(Headers, :request, [other, false, limits(), true])
  end

  test "setting eight validates values and retains enablement" do
    defaults = Settings.defaults()

    assert {:ok, %{enable_connect_protocol: 1} = enabled, 0} =
             Settings.apply(defaults, <<8::16, 1::32>>)

    assert {:error, :protocol_error} = Settings.apply(defaults, <<8::16, 2::32>>)
    assert {:error, :protocol_error} = Settings.apply(enabled, <<8::16, 0::32>>)
  end

  test "extended CONNECT is a strict boolean listener option with disabled default" do
    assert {:ok, spec} = Gaoxy.HTTP.service_spec(endpoint: {Endpoint, []})
    assert Map.get(spec.handler_options, :extended_connect) == false

    assert {:ok, enabled} =
             Gaoxy.HTTP.service_spec(endpoint: {Endpoint, []}, extended_connect: true)

    assert enabled.handler_options.extended_connect

    assert {:error, _} =
             Gaoxy.HTTP.service_spec(endpoint: {Endpoint, []}, extended_connect: :yes)
  end
end
