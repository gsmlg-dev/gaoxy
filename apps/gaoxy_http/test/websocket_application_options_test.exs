defmodule Gaoxy.HTTP.WebSocket.ApplicationOptionsTest do
  use ExUnit.Case, async: true

  defmodule Handler do
    def init(state), do: {:ok, state}
    def handle_in(_, state), do: {:ok, state}
    def handle_info(_, state), do: {:ok, state}
  end

  test "Phoenix log and code reloader policies do not become wire engine limits" do
    for options <- [[log: false], [code_reloader: false], [log: :debug, code_reloader: true]] do
      assert {:ok, %{response: {:websocket, Handler, nil, limits, []}}} = prepare(options)
      refute Map.has_key?(limits, :log)
      refute Map.has_key?(limits, :code_reloader)
      assert limits.max_frame_size == 262_144
    end
  end

  test "application policies retain strict validation of wire settings" do
    for options <- [
          [max_frame_size: 0],
          [compress: true],
          [validate_utf8: false],
          [unknown: true]
        ] do
      assert {:error, :invalid_websocket_upgrade} =
               prepare([log: false, code_reloader: false] ++ options)
    end
  end

  defp prepare(options) do
    request = %{
      method: "GET",
      version: :"HTTP/1.1",
      body: :none,
      headers: [
        {"upgrade", "websocket"},
        {"connection", "Upgrade"},
        {"sec-websocket-version", "13"},
        {"sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ=="}
      ]
    }

    Gaoxy.HTTP.WebSocket.prepare(%{request: request, response: nil}, {Handler, nil, options})
  end
end
