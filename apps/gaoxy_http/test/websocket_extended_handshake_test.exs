defmodule Gaoxy.HTTP.WebSocket.ExtendedHandshakeTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Exchange, Request, WebSocket}
  alias Gaoxy.HTTP.WebSocket.ExtendedHandshake

  def read_body_step(_, _, _), do: flunk("tunnel bytes reached the ordinary body transport")

  defmodule Handler do
    def init(state), do: {:ok, state}
    def handle_in(_, state), do: {:ok, state}
    def handle_info(_, state), do: {:ok, state}
  end

  defp request(version \\ :"HTTP/2") do
    %Request{
      method: "CONNECT",
      version: version,
      scheme: :https,
      host: "example.test",
      port: 443,
      target: "/socket?vsn=2.0.0",
      target_form: :origin,
      path: "/socket",
      query_string: "vsn=2.0.0",
      body: :tunnel,
      headers: [{"sec-websocket-version", "13"}, {"sec-websocket-protocol", "chat, other"}]
    }
    |> Map.put(:protocol, "websocket")
  end

  defp headers(request, fields) do
    assert Code.ensure_loaded?(ExtendedHandshake), "missing extended CONNECT handshake"
    apply(ExtendedHandshake, :headers, [request, fields])
  end

  test "request metadata has an optional protocol and preserves CONNECT" do
    assert Map.get(%Request{}, :protocol, :missing) == nil
    assert %{method: "CONNECT", protocol: "websocket", body: :tunnel} = request()
  end

  test "H2 and H3 extended handshakes preserve legal fields without H1 headers" do
    fields = [{"sec-websocket-protocol", "chat"}, {"set-cookie", "session=yes"}]

    for version <- [:"HTTP/2", :"HTTP/3"] do
      assert {:ok, ^fields} = headers(request(version), fields)
      assert {:ok, []} = headers(request(version), [])
    end
  end

  test "requires validated CONNECT tunnel metadata, authority, path, scheme and version 13" do
    req = request()

    for invalid <- [
          %{req | method: "GET"},
          %{req | protocol: "other"},
          %{req | protocol: nil},
          %{req | version: :"HTTP/1.1"},
          %{req | body: :none},
          %{req | scheme: nil},
          %{req | host: ""},
          %{req | port: 0},
          %{req | target_form: :authority},
          %{req | path: ""},
          %{req | target: "*"},
          %{req | headers: []},
          %{req | headers: [{"sec-websocket-version", "12"}]},
          %{req | headers: [{"sec-websocket-version", "13"} | req.headers]},
          %{
            req
            | headers: [{"sec-websocket-version", "13"}, {"sec-websocket-protocol", "bad token"}]
          }
        ] do
      assert {:error, :invalid_websocket_handshake} = headers(invalid, [])
    end
  end

  test "rejects H1, framing, extension, injected and unsolicited response fields" do
    for fields <- [
          [{"connection", "Upgrade"}],
          [{"upgrade", "websocket"}],
          [{"sec-websocket-accept", "ignored"}],
          [{"content-length", "0"}],
          [{"transfer-encoding", "chunked"}],
          [{"keep-alive", "timeout=1"}],
          [{"sec-websocket-extensions", "permessage-deflate"}],
          [{"sec-websocket-protocol", "unknown"}],
          [{"sec-websocket-protocol", "chat"}, {"sec-websocket-protocol", "other"}],
          [{"sec-websocket-protocol", "chat, other"}],
          [{"X-Test", "value"}],
          [{"x-test", "bad\r\nvalue"}],
          [{":status", "200"}]
        ] do
      assert {:error, :invalid_websocket_response} = headers(request(), fields)
    end
  end

  test "shared preparation accepts extended metadata without rewriting the wire method" do
    req = request()
    exchange = %Exchange{request: req}
    assert {:ok, prepared} = WebSocket.prepare(exchange, {Handler, :state, []})
    assert prepared.request == req
    assert {:websocket, Handler, :state, %{max_lifetime: 86_400_000}, []} = prepared.response

    assert {:error, :invalid_websocket_upgrade} =
             WebSocket.prepare(exchange, {Handler, :state, compress: true})
  end

  test "generic body readers reject tunnel bytes before invoking the transport" do
    exchange = %Exchange{request: request(), transport: __MODULE__, body: :tunnel}
    assert {:error, :unsupported_tunnel_body} = Exchange.read_body(exchange, 16, 100)

    assert {:error, :unsupported_tunnel_body, ^exchange} =
             Exchange.read_body_step(exchange, 16, 0)
  end
end
