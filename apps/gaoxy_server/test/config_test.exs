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

  test "H2 routes retain the maximum decode and two-snapshot byte budget" do
    config = %{
      "version" => 1,
      "services" => [
        %{
          "id" => "h2",
          "transport" => "tcp",
          "handler" => "http",
          "protocols" => ["http2"],
          "h2c" => "prior_knowledge",
          "limits" => %{"max_bytes" => 268_435_456},
          "routes" => %{
            "version" => 1,
            "routes" => [
              %{"target" => %{"type" => "static", "body" => "ok"}}
            ]
          }
        }
      ]
    }

    assert {:ok, [services: [spec]]} = Gaoxy.Server.Config.decode(config)

    reserves =
      Gaoxy.HTTP.HTTP2.Limits.reservation(
        spec.handler_options.http_limits,
        spec.handler_options.h2_limits
      )

    required =
      reserves.connection + reserves.decode + reserves.stream + reserves.writer + 2 * 1_048_576

    put_budget = fn bytes ->
      put_in(config, ["services", Access.at(0), "limits", "max_bytes"], bytes)
    end

    assert {:error, :route_snapshot_byte_budget} =
             Gaoxy.Server.Config.decode(put_budget.(required - 1))

    assert {:ok, _} = Gaoxy.Server.Config.decode(put_budget.(required))
  end
end
