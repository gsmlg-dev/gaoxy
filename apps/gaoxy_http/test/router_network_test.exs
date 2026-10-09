defmodule Gaoxy.HTTP.RouterNetworkTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{PlugEndpoint, Router}

  defmodule Echo do
    def init(name), do: name

    def call(conn, name),
      do:
        Plug.Conn.send_resp(
          conn,
          200,
          "#{name}|#{conn.host}|#{conn.method}|#{conn.request_path}|#{conn.query_string}"
        )
  end

  test "wire routes use declared precedence and raw target, ignoring forwarded authority" do
    routes = [
      %{
        host: "example.test",
        methods: ["GET"],
        path: {:prefix, "/api"},
        target: {PlugEndpoint, {Echo, "api"}}
      },
      %{path: "/a%2Fb", target: {PlugEndpoint, {Echo, "escaped"}}},
      %{target: {PlugEndpoint, {Echo, "fallback"}}}
    ]

    {:ok, server} = Gaoxy.HTTP.start_link(endpoint: {Router, routes})
    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :gen_tcp.send(socket, [
      "GET /api/item?q=%2F HTTP/1.1\r\nHost: EXAMPLE.test\r\n\r\n",
      "GET /apiary HTTP/1.1\r\nHost: example.test\r\n\r\n",
      "GET /api HTTP/1.1\r\nHost: other.test\r\nX-Forwarded-Host: example.test\r\n\r\n",
      "GET /a%2Fb HTTP/1.1\r\nHost: example.test\r\nConnection: close\r\n\r\n"
    ])

    response = all(socket)
    assert response =~ "api|example.test|GET|/api/item|q=%2F"
    assert response =~ "fallback|example.test|GET|/apiary|"
    assert response =~ "fallback|other.test|GET|/api|"
    assert response =~ "escaped|example.test|GET|/a%2Fb|"
  end

  defp all(socket, acc \\ "") do
    case :gen_tcp.recv(socket, 0, 1000) do
      {:ok, data} -> all(socket, acc <> data)
      {:error, :closed} -> acc
    end
  end
end
