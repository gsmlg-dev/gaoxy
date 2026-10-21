defmodule PhoenixNative.BodyTest do
  use ExUnit.Case, async: true

  test "the real Phoenix Endpoint parses JSON and forms above 16 KiB" do
    {:ok, {ip, port}} = PhoenixNative.Endpoint.server_info(:http)
    value = String.duplicate("p", 20_000)

    for {type, body} <- [
          {"application/json", Jason.encode!(%{"value" => value})},
          {"application/x-www-form-urlencoded", "value=" <> value}
        ] do
      {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 2_000)
      on_exit(fn -> :gen_tcp.close(socket) end)

      :ok =
        :gen_tcp.send(socket, [
          "POST /body HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n",
          "Content-Type: ",
          type,
          "\r\nContent-Length: ",
          Integer.to_string(byte_size(body)),
          "\r\n\r\n",
          body
        ])

      response = receive_all(socket, "")
      assert [head, ^value] = String.split(response, "\r\n\r\n", parts: 2)
      assert head =~ "HTTP/1.1 200"
    end
  end

  defp receive_all(socket, bytes) do
    case :gen_tcp.recv(socket, 0, 2_000) do
      {:ok, more} -> receive_all(socket, bytes <> more)
      {:error, :closed} -> bytes
      other -> flunk("Phoenix body response failed: #{inspect(other)}")
    end
  end
end
