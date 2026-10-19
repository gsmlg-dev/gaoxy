defmodule Gaoxy.PhoenixWebSocketTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Exchange, Request}

  defmodule Handler do
    def init(state), do: {:ok, state}
    def handle_in(_, state), do: {:ok, state}
    def handle_info(_, state), do: {:ok, state}
  end

  defmodule Endpoint do
    def init(options), do: options

    def call(conn, _) do
      {Gaoxy.PlugAdapter, exchange} = conn.adapter
      send(self(), {:endpoint_view, conn.method, exchange.request, exchange.transport_state})

      cond do
        Plug.Conn.get_req_header(conn, "origin") == ["https://blocked.test"] ->
          Plug.Conn.resp(conn, 403, "forbidden")

        conn.method == "GET" and exchange.request.body == :tunnel ->
          WebSockAdapter.upgrade(conn, Handler, nil, [])

        true ->
          Plug.Conn.resp(conn, 200, conn.method)
      end
    end
  end

  defp conn(version \\ :"HTTP/2", overrides \\ %{}) do
    request =
      struct(
        Request,
        Map.merge(
          %{
            method: "CONNECT",
            protocol: "websocket",
            version: version,
            scheme: :https,
            host: "example.test",
            port: 443,
            target: "/socket/websocket?vsn=2.0.0",
            target_form: :origin,
            path: "/socket/websocket",
            query_string: "vsn=2.0.0",
            body: :tunnel,
            headers: [{"sec-websocket-version", "13"}, {"origin", "https://example.test"}]
          },
          overrides
        )
      )

    state =
      if version == :"HTTP/3",
        do: {self(), make_ref(), :stream_key, make_ref()},
        else: {self(), 1, make_ref()}

    %Exchange{
      request: request,
      transport: Gaoxy.HTTP.HTTP2.Transport,
      transport_state: state,
      limits: %{extended_connect: true},
      peer: {{127, 0, 0, 1}, 12345},
      local: {{127, 0, 0, 1}, 443},
      secure: true
    }
    |> Exchange.plug_conn()
  end

  defp init(paths \\ ["/socket/websocket"]),
    do: apply(Gaoxy.PhoenixWebSocket, :init, [{Endpoint, paths}])

  defp call(conn, options), do: apply(Gaoxy.PhoenixWebSocket, :call, [conn, options])

  test "allowlisted native H2/H3 CONNECT presents GET and restores immutable wire metadata" do
    for version <- [:"HTTP/2", :"HTTP/3"] do
      conn = conn(version)
      {_, original} = conn.adapter
      result = call(conn, init())
      assert_receive {:endpoint_view, "GET", request, state}
      assert request == original.request
      assert state == original.transport_state
      assert result.method == "CONNECT"
      assert result.state == :upgraded

      assert {Gaoxy.PlugAdapter, %{request: ^request, response: {:websocket, Handler, nil, _, _}}} =
               result.adapter

      assert Plug.Conn.get_http_protocol(result) == version
    end
  end

  test "unlisted, disabled and invalid requests retain their actual method" do
    enabled = conn()
    {adapter, exchange} = enabled.adapter
    disabled = %{enabled | adapter: {adapter, %{exchange | limits: %{extended_connect: false}}}}

    for {input, options} <- [
          {enabled, init([])},
          {enabled, init(["/live/websocket"])},
          {disabled, init()},
          {conn(:"HTTP/2", %{protocol: "other"}), init()},
          {conn(:"HTTP/2", %{headers: [{"sec-websocket-version", "12"}]}), init()}
        ] do
      result = call(input, options)
      assert_receive {:endpoint_view, "CONNECT", _, _}
      assert result.method == "CONNECT"
      assert result.state == :set
    end
  end

  test "ordinary GET remains GET without becoming an extended upgrade" do
    result = call(conn(:"HTTP/2", %{method: "GET", protocol: nil, body: :none}), init())
    assert_receive {:endpoint_view, "GET", %{method: "GET", protocol: nil}, _}
    assert result.method == "GET"
    assert result.status == 200
    assert result.state == :set
  end

  test "application rejection preserves its status and restores CONNECT" do
    result =
      call(
        conn(:"HTTP/3", %{
          headers: [{"sec-websocket-version", "13"}, {"origin", "https://blocked.test"}]
        }),
        init()
      )

    assert_receive {:endpoint_view, "GET", %{method: "CONNECT"}, _}
    assert {result.status, result.resp_body, result.method} == {403, "forbidden", "CONNECT"}
    assert result.state == :set
  end

  test "WebSocket paths are exact and validated" do
    for invalid <- [
          nil,
          "bad",
          ["socket/websocket"],
          ["/socket/*"],
          ["/socket?x"],
          ["/socket#fragment"],
          ["/socket", "/socket"],
          [nil]
        ] do
      assert_raise ArgumentError, fn -> init(invalid) end
    end
  end

  test "Phoenix adapter installs the explicit wrapper and preserves managed startup" do
    assert [%{start: {Gaoxy, :start_link, [[name: _, services: [spec]]]}}] =
             Gaoxy.PhoenixAdapter.child_specs(Endpoint,
               http: [port: 0, extended_connect: true],
               websocket_paths: ["/socket/websocket"]
             )

    assert {Gaoxy.HTTP.PlugEndpoint,
            {Gaoxy.PhoenixWebSocket, {Endpoint, [], ["/socket/websocket"]}}} =
             spec.handler_options.endpoint

    assert spec.handler_options.extended_connect
  end
end
