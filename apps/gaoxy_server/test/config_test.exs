defmodule Gaoxy.Server.ConfigTest do
  use ExUnit.Case, async: true

  test "configuration is data-only and handler resolution is allowlisted" do
    assert {:ok, options} =
             Gaoxy.Server.Config.decode(%{
               "version" => 1,
               "services" => [
                 %{"id" => "echo", "transport" => "udp", "handler" => "datagram_echo"}
               ]
             })

    assert {:ok, %{services: [%{handler: Gaoxy.Server.DatagramEcho}]}} =
             Gaoxy.Config.validate(options)

    assert {:error, :unsupported_value} =
             Gaoxy.Server.Config.decode(%{
               "version" => 1,
               "services" => [
                 %{"id" => "bad", "transport" => "tcp", "handler" => "System.cmd"}
               ]
             })

    assert {:error, :unknown_configuration_keys} =
             Gaoxy.Server.Config.decode(%{"version" => 1, "services" => [], "eval" => "code"})

    assert {:error, :invalid_configuration_version_or_shape} =
             Gaoxy.Server.Config.decode(%{"version" => 2, "services" => []})
  end
end
