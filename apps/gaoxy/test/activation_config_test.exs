defmodule Gaoxy.ActivationConfigTest do
  use ExUnit.Case, async: true
  @moduletag :unit

  defmodule Echo do
    def init(_, _), do: {:ok, nil}
    def handle_data(bytes, state), do: {:send, bytes, state}
    def handle_datagram(packet, _), do: {:reply, packet.data}
  end

  defp spec(extra \\ %{}),
    do: Map.merge(%{id: "echo", transport: :tcp, handler: Echo}, extra)

  test "activation option is strict and immediate remains the default" do
    assert {:ok, %{activation: :immediate}} = Gaoxy.Config.validate(services: [spec()])

    assert {:ok, %{activation: :deferred}} =
             Gaoxy.Config.validate(services: [spec()], activation: :deferred)

    assert {:error, :invalid_activation} =
             Gaoxy.Config.validate(services: [spec()], activation: :paused)
  end
end
