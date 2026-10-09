defmodule Gaoxy.HTTP.WebSocket.HandshakeTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Request, WebSocket.Handshake}

  defp request do
    %Request{
      method: "GET",
      version: :"HTTP/1.1",
      body: :none,
      headers: [
        {"host", "example.test"},
        {"connection", "keep-alive, Upgrade"},
        {"upgrade", "websocket"},
        {"sec-websocket-version", "13"},
        {"sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ=="}
      ]
    }
  end

  test "RFC 6455 handshake accepts tokens and keeps application response headers" do
    req = %{request() | headers: request().headers ++ [{"sec-websocket-protocol", "chat, other"}]}

    assert {:ok, headers} =
             Handshake.headers(req, [{"sec-websocket-protocol", "chat"}, {"set-cookie", "a=b"}])

    assert {"sec-websocket-accept", "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="} in headers
    assert {"upgrade", "websocket"} in headers
    assert {"connection", "Upgrade"} in headers
    assert {"set-cookie", "a=b"} in headers
    refute Enum.any?(headers, fn {key, _} -> key == "sec-websocket-extensions" end)
  end

  test "rejects invalid method, version, key, duplicate singleton and request body" do
    req = request()

    for invalid <- [
          %{req | method: "POST"},
          %{req | version: :"HTTP/1.0"},
          %{req | body: {:length, 1}},
          %{
            req
            | headers:
                List.keyreplace(
                  req.headers,
                  "sec-websocket-key",
                  0,
                  {"sec-websocket-key", "aA=="}
                )
          },
          %{req | headers: [{"sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ=="} | req.headers]},
          %{req | headers: List.keydelete(req.headers, "upgrade", 0)}
        ] do
      assert {:error, :invalid_websocket_handshake} = Handshake.headers(invalid, [])
    end
  end

  test "accepts websocket among multiple offered Upgrade protocols" do
    req = request()

    req = %{
      req
      | headers: List.keyreplace(req.headers, "upgrade", 0, {"upgrade", "h2c, websocket"})
    }

    assert {:ok, _} = Handshake.headers(req, [])
  end

  test "rejects unsolicited subprotocol, extensions, framing or response injection" do
    for headers <- [
          [{"sec-websocket-protocol", "unknown"}],
          [{"sec-websocket-extensions", "permessage-deflate"}],
          [{"content-length", "12"}],
          [{"x-header", "bad\r\nvalue"}]
        ] do
      assert {:error, :invalid_websocket_response} = Handshake.headers(request(), headers)
    end
  end
end
