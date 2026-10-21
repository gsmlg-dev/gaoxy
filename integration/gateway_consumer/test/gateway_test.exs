defmodule GatewayConsumerTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Proxy.Gateway

  defmodule Endpoint do
    def init(body), do: {:ok, body}
    def call(exchange, body), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], body)
  end

  test "proxy-only consumer runs and reloads a managed gateway without Server or H3" do
    refute Code.ensure_loaded?(Gaoxy.Server.Application)
    refute Code.ensure_loaded?(Gaoxy.HTTP.HTTP3)
    origin = start_supervised!({Gaoxy.HTTP, id: :origin, endpoint: {Endpoint, "origin"}})
    {:ok, {_, port}} = Gaoxy.info(origin, :origin).local

    assert {:ok, target} =
             Gaoxy.Proxy.Gateway.Upstream.fixed(%{upstream: "http://127.0.0.1:#{port}"})

    gateway =
      start_supervised!(
        {Gateway,
         id: :consumer,
         listener_sets: [
           [
             id: "web",
             endpoint: {Gaoxy.HTTP.Router, [%{target: target}]},
             listeners: [http: [port: 0]]
           ]
         ]}
      )

    assert request(gateway) == "origin"

    assert {:ok, %{revision: 2}} =
             Gateway.reload_routes(gateway, "web", [%{target: {Endpoint, "new"}}],
               expected_revision: 1,
               timeout: 3000
             )

    assert request(gateway) == "new"
    assert :ok = Gateway.stop(gateway, 3000)
    refute Process.alive?(gateway)
  end

  defp request(gateway) do
    %{listeners: [%{local: {:ok, {ip, port}}}]} = Gateway.info(gateway)
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    :ok = :gen_tcp.send(socket, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    response = read(socket, "")
    :gen_tcp.close(socket)
    [_, body] = String.split(response, "\r\n\r\n", parts: 2)
    body
  end

  defp read(socket, bytes) do
    case :gen_tcp.recv(socket, 0, 2000) do
      {:ok, more} -> read(socket, bytes <> more)
      {:error, :closed} -> bytes
    end
  end
end
