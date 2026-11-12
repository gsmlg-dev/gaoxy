defmodule Gaoxy.HTTP1UnregisteredStatusNetworkTest do
  use ExUnit.Case, async: true

  defmodule Endpoint do
    def init(options), do: {:ok, options}

    def call(exchange, _) do
      "/" <> code = exchange.request.path
      Gaoxy.HTTP.Response.send_resp(exchange, String.to_integer(code), [], "body")
    end
  end

  for {status, line} <- [
        {599, "HTTP/1.1 599 \r\n"},
        {499, "HTTP/1.1 499 \r\n"},
        {404, "HTTP/1.1 404 Not Found\r\n"}
      ] do
    @status status
    @line line
    test "HTTP/1.1 relays status #{status} as sent by the endpoint" do
      assert {:ok, spec} = Gaoxy.HTTP.service_spec(endpoint: {Endpoint, nil})
      assert {:ok, runtime} = Gaoxy.start_link(services: [spec])
      on_exit(fn -> if Process.alive?(runtime), do: Gaoxy.stop(runtime, 1_000) end)
      assert {:ok, {ip, port}} = Gaoxy.info(runtime, :http).local

      assert {:ok, socket} =
               :gen_tcp.connect(ip, port, [:binary, active: false, packet: :line], 2_000)

      on_exit(fn -> :gen_tcp.close(socket) end)

      request = "GET /#{@status} HTTP/1.1\r\nhost: localhost\r\nconnection: close\r\n\r\n"
      assert :ok = :gen_tcp.send(socket, request)
      assert {:ok, @line} = :gen_tcp.recv(socket, 0, 2_000)
    end
  end
end
