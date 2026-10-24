defmodule Gaoxy.HTTP.WebSocket.LifecycleConfigTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.{Lifecycle, HTTP.WebSocket}

  defmodule Handler do
    def init(state), do: {:ok, state}
    def handle_in(_, state), do: {:ok, state}
    def handle_info(_, state), do: {:ok, state}
  end

  test "omitted WebSocket policies impose no time, size, fragment or batch ceiling" do
    assert {:ok, %{response: {:websocket, Handler, nil, limits, []}}} = prepare([])

    for key <- [
          :timeout,
          :max_lifetime,
          :max_frame_size,
          :max_message_size,
          :max_fragments,
          :max_mailbox,
          :max_push_frames
        ] do
      assert limits[key] == :infinity
    end

    assert limits.callback_timeout == 5_000
    assert limits.close_timeout == 1_000
  end

  test "finite application policies remain deliberate and infinity is supported" do
    for key <- [
          :timeout,
          :max_lifetime,
          :max_frame_size,
          :max_message_size,
          :max_fragments,
          :max_mailbox,
          :max_push_frames
        ],
        value <- [17, :infinity] do
      assert {:ok, %{response: {:websocket, Handler, nil, limits, []}}} = prepare([{key, value}])
      assert limits[key] == value
    end

    for key <- [:callback_timeout, :close_timeout], value <- [0, -1, nil, :infinity] do
      assert {:error, :invalid_websocket_upgrade} = prepare([{key, value}])
    end
  end

  test "infinite lifetime has no arithmetic deadline and finite ordering is explicit" do
    assert Lifecycle.deadline(:infinity) == :infinity
    assert Lifecycle.remaining(:infinity) == :infinity
    assert Lifecycle.earlier(:infinity, 5) == 5
    assert Lifecycle.earlier(7, :infinity) == 7
    assert Lifecycle.earlier(:infinity, :infinity) == :infinity
    assert Lifecycle.earlier(7, 5) == 5
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

    WebSocket.prepare(%{request: request, response: nil}, {Handler, nil, options})
  end
end
