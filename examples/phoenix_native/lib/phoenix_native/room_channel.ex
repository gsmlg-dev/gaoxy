defmodule PhoenixNative.RoomChannel do
  use Phoenix.Channel

  def join("room:" <> _, _payload, socket), do: {:ok, socket}
  def handle_in("ping", payload, socket), do: {:reply, {:ok, payload}, socket}
end
