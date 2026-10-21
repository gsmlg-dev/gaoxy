defmodule PhoenixNative.UserSocket do
  use Phoenix.Socket

  channel("room:*", PhoenixNative.RoomChannel)

  def connect(_params, socket, _connect_info), do: {:ok, socket}
  def id(_socket), do: nil
end
