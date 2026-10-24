# This isolated dependency test supplies the consumer's public adapter contract.
defmodule Gaoxy.PlugAdapter do
  def upgrade(:payload, :websocket, {handler, state, options}),
    do: {:ok, {:native, handler, state, options}}

  def upgrade(%{request: _} = payload, :websocket, {handler, state, options}),
    do: {:ok, {:native, payload, handler, state, options}}

  def get_http_protocol(%{request: %{version: version}}), do: version
end

defmodule WebSockAdapter.GaoxyDispatchTest do
  use ExUnit.Case, async: true

  test "dispatches the native Gaoxy adapter tuple" do
    conn = %Plug.Conn{adapter: {Gaoxy.PlugAdapter, :payload}}
    upgraded = WebSockAdapter.upgrade(conn, MyWebSock, :state, early_validate_upgrade: false)
    assert upgraded.state == :upgraded
    assert {Gaoxy.PlugAdapter, {:native, MyWebSock, :state, options}} = upgraded.adapter
    refute Keyword.has_key?(options, :max_frame_size)
  end

  test "Gaoxy preserves explicitly selected frame and inactivity policies" do
    conn = %Plug.Conn{adapter: {Gaoxy.PlugAdapter, :payload}}

    upgraded =
      WebSockAdapter.upgrade(conn, MyWebSock, :state,
        max_frame_size: 10_000_000,
        timeout: 60_000,
        early_validate_upgrade: false
      )

    assert {Gaoxy.PlugAdapter, {:native, MyWebSock, :state, options}} = upgraded.adapter
    assert options[:max_frame_size] == 10_000_000
    assert options[:timeout] == 60_000
  end

  test "other adapters retain their default and explicitly selected frame ceiling" do
    for options <- [[], [max_frame_size: 1234]] do
      ref = make_ref()
      conn = %Plug.Conn{adapter: {Plug.Adapters.Test.Conn, %{owner: self(), ref: ref}}}

      upgraded =
        WebSockAdapter.upgrade(
          conn,
          MyWebSock,
          :state,
          Keyword.put(options, :early_validate_upgrade, false)
        )

      assert upgraded.state == :upgraded
      assert_receive {^ref, :upgrade, {:websocket, {MyWebSock, :state, passed}}}
      assert passed[:max_frame_size] == Keyword.get(options, :max_frame_size, 10_000_000)
    end
  end

  test "Gaoxy H2 and H3 use immutable CONNECT metadata while Phoenix sees GET" do
    for version <- [:"HTTP/2", :"HTTP/3"] do
      request = %{
        method: "CONNECT",
        protocol: "websocket",
        version: version,
        headers: [{"sec-websocket-version", "13"}]
      }

      conn = %Plug.Conn{
        method: "GET",
        req_headers: request.headers,
        adapter: {Gaoxy.PlugAdapter, %{request: request}}
      }

      result = WebSockAdapter.upgrade(conn, MyWebSock, :state, [])
      assert result.state == :upgraded

      assert {Gaoxy.PlugAdapter, {:native, %{request: ^request}, MyWebSock, :state, _}} =
               result.adapter
    end
  end

  test "apparent GET cannot replace missing or invalid native extended metadata" do
    for request <- [
          %{
            method: "GET",
            protocol: "websocket",
            version: :"HTTP/2",
            headers: [{"sec-websocket-version", "13"}]
          },
          %{
            method: "CONNECT",
            protocol: "other",
            version: :"HTTP/3",
            headers: [{"sec-websocket-version", "13"}]
          },
          %{
            method: "CONNECT",
            protocol: "websocket",
            version: :"HTTP/3",
            headers: [{"sec-websocket-version", "12"}]
          }
        ] do
      conn = %Plug.Conn{
        method: "GET",
        req_headers: [{"sec-websocket-version", "13"}],
        adapter: {Gaoxy.PlugAdapter, %{request: request}}
      }

      assert_raise WebSockAdapter.UpgradeError, fn ->
        WebSockAdapter.upgrade(conn, MyWebSock, :state, [])
      end
    end
  end
end
