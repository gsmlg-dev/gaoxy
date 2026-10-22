defmodule Gaoxy.Server.ConfigTest do
  use ExUnit.Case, async: true
  @moduletag :unit

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

  test "standalone JSON mixed protocols use one native HTTP routing listener" do
    config = %{
      "version" => 1,
      "services" => [
        %{
          "id" => "mixed",
          "transport" => "tcp",
          "handler" => "http",
          "protocols" => ["http2", "http1"],
          "h2c" => "prior_knowledge",
          "routes" => %{
            "version" => 1,
            "routes" => [%{"target" => %{"type" => "static", "body" => "mixed"}}]
          }
        }
      ]
    }

    assert {:ok, [services: [spec]]} =
             config |> JSON.encode!() |> JSON.decode!() |> Gaoxy.Server.Config.decode()

    assert spec.transport == :tcp
    assert spec.handler == Gaoxy.HTTP.Connection
    assert {Gaoxy.HTTP.Router, _} = spec.handler_options.endpoint
    assert spec.handler_options.protocols == [:http2, :http1]
    assert spec.handler_options.h2c == :prior_knowledge

    assert {:error, :invalid_http_protocols} =
             config
             |> update_in(["services", Access.at(0)], &Map.delete(&1, "h2c"))
             |> Gaoxy.Server.Config.decode()

    assert {:error, :unsupported_value} =
             config
             |> put_in(["services", Access.at(0), "h2c"], "auto")
             |> Gaoxy.Server.Config.decode()
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
