defmodule Gaoxy.HTTP.HTTP3UpgradeTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Exchange, Request}

  test "H3 refuses WebSocket upgrade before interpreting H1 handshake arguments" do
    exchange = %Exchange{request: %Request{version: :"HTTP/3"}}

    assert {:error, :not_supported} =
             Gaoxy.PlugAdapter.upgrade(exchange, :websocket, :invalid_h1_arguments)
  end

  test "existing H1 validation and H2 upgrade refusal keep their contracts" do
    h1 = %Exchange{request: %Request{version: :"HTTP/1.1"}}
    h2 = %Exchange{request: %Request{version: :"HTTP/2"}}

    assert_raise ArgumentError, ~r/invalid WebSocket upgrade/, fn ->
      Gaoxy.PlugAdapter.upgrade(h1, :websocket, :invalid_h1_arguments)
    end

    assert {:error, :not_supported} =
             Gaoxy.PlugAdapter.upgrade(h2, :websocket, :invalid_h1_arguments)
  end
end
