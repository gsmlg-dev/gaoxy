# This isolated dependency test supplies the consumer's public adapter contract.
defmodule Gaoxy.PlugAdapter do
  def upgrade(:payload, :websocket, {handler, state, options}),
    do: {:ok, {:native, handler, state, options}}
end

defmodule WebSockAdapter.GaoxyDispatchTest do
  use ExUnit.Case, async: true

  test "dispatches the native Gaoxy adapter tuple" do
    conn = %Plug.Conn{adapter: {Gaoxy.PlugAdapter, :payload}}
    upgraded = WebSockAdapter.upgrade(conn, MyWebSock, :state, early_validate_upgrade: false)
    assert upgraded.state == :upgraded
    assert {Gaoxy.PlugAdapter, {:native, MyWebSock, :state, options}} = upgraded.adapter
    assert options[:max_frame_size] == 10_000_000
  end
end
