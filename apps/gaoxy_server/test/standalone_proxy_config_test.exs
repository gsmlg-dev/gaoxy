defmodule Gaoxy.Server.StandaloneProxyConfigTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Server.{Config, RouteConfig}

  test "WebSocket routes expose the existing finite proxy options" do
    assert {:ok, [%{target: {Gaoxy.Proxy.WebSocket, config}}]} =
             RouteConfig.decode(
               routes(%{
                 "type" => "websocket",
                 "upstream" => "ws://localhost:9000",
                 "max_message_bytes" => 1024,
                 "opening_timeout" => 500
               })
             )

    assert config.limits.max_message_bytes == 1024
    assert config.limits.opening_timeout == 500
  end

  test "managed H1 and h2c routes validate without starting owners" do
    for {protocol, upstream} <- [
          {"http1", "http://127.0.0.1:9000"},
          {"h2c", "http://127.0.0.1:9001"}
        ] do
      target = %{
        "type" => "reverse_proxy",
        "upstream" => upstream,
        "upstream_protocol" => protocol,
        "managed" => true
      }

      assert {:ok, options} = Config.decode(service(target))

      assert {:ok, %{services: [%{handler: Gaoxy.HTTP.Connection}]}} =
               Gaoxy.Config.validate(options)
    end

    refute Process.whereis(Gaoxy.Server.UpstreamOwners)
  end

  test "inline homogeneous groups expose health policy and member capacities" do
    target = group()

    assert {:ok, [%{target: {Gaoxy.Server.UpstreamEndpoint, _}}]} =
             RouteConfig.decode(routes(target))

    assert {:ok, _} = Config.decode(service(target))
  end

  test "new targets reject unknown keys and invalid policies" do
    for target <- [
          %{"type" => "websocket", "upstream" => "ws://localhost", "module" => "System"},
          %{
            "type" => "reverse_proxy",
            "upstream" => "https://localhost",
            "upstream_protocol" => "http2"
          },
          %{
            "type" => "reverse_proxy",
            "upstream" => "http://localhost",
            "upstream_protocol" => "h2c",
            "managed" => false
          },
          %{"type" => "reverse_proxy", "upstream" => "http://localhost", "managed" => "yes"},
          put_in(group(), ["health", "timeout"], 0),
          put_in(group(), ["members", Access.at(1), "id"], "one"),
          put_in(group(), ["members", Access.at(1), "upstream_protocol"], "http1"),
          Map.put(group(), "eval", "code")
        ] do
      assert {:error, _} = RouteConfig.decode(routes(target))
    end
  end

  defp group do
    %{
      "type" => "upstream_group",
      "id" => "api",
      "max_inflight" => 8,
      "health" => %{"path" => "/health", "interval" => 1000, "timeout" => 500},
      "members" => [
        %{
          "id" => "one",
          "upstream" => "http://127.0.0.1:9001",
          "upstream_protocol" => "h2c",
          "max_inflight" => 4
        },
        %{
          "id" => "two",
          "upstream" => "http://127.0.0.1:9002",
          "upstream_protocol" => "h2c",
          "max_inflight" => 4
        }
      ]
    }
  end

  defp routes(target), do: %{"version" => 1, "routes" => [%{"target" => target}]}

  defp service(target),
    do: %{
      "version" => 1,
      "services" => [
        %{
          "id" => "web",
          "transport" => "tcp",
          "handler" => "http",
          "routes" => routes(target),
          "limits" => %{"max_bytes" => 67_108_864}
        }
      ]
    }
end
