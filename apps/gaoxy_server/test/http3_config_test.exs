defmodule Gaoxy.Server.HTTP3ConfigTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Server.{Config, StaticEndpoint}
  alias Gaoxy.HTTP.HTTP3.Connection

  test "explicit data-only H3 config fixes QUIC ALPN and keeps static routing" do
    assert {:ok, [services: [spec]]} = Config.decode(config())
    assert spec.handler == Connection
    assert spec.transport == :quic
    assert spec.quic == %{alpn: ["h3"]}
    assert spec.handler_options.endpoint |> elem(0) == Gaoxy.HTTP.Router
    assert {:ok, %{services: [%{handler: Connection}]}} = Gaoxy.Config.validate(services: [spec])
    refute Process.whereis(Gaoxy.Server.RouteStores)
    refute Process.whereis(Gaoxy.Server.Runtime)
  end

  test "H1 default remains available and H3 origin options remain rejected" do
    ordinary = config() |> put_service("handler", "http") |> put_service("transport", "tcp")

    ordinary =
      update_in(ordinary, ["services", Access.at(0)], &Map.drop(&1, ["protocols", "tls"]))

    assert {:ok, [services: [%{handler: Gaoxy.HTTP.Connection, handler_options: options}]]} =
             Config.decode(ordinary)

    assert options.protocols == [:http1]

    upstream = %{"type" => "reverse_proxy", "upstream" => "http://127.0.0.1:1234"}
    assert {:ok, _} = Config.decode(put_target(config(), upstream))

    assert {:error, _} =
             Config.decode(put_target(config(), Map.put(upstream, "upstream_protocol", "http3")))
  end

  for {name, value} <- [
        {"transport", "tcp"},
        {"transport", "tls"},
        {"transport", "udp"},
        {"protocols", ["http1"]},
        {"protocols", ["http2"]},
        {"protocols", ["http3", "http1"]},
        {"protocols", []},
        {"handler", "http"},
        {"ip", "0.0.0.0"},
        {"ip", "::1"},
        {"mode", "broadcast"},
        {"mode", "multicast"},
        {"handler_options", %{}},
        {"h2c", "disabled"},
        {"h2_limits", %{}},
        {"udp", %{}},
        {"quic", %{"alpn" => ["h3"]}},
        {"endpoint", "System.cmd"},
        {"plug", "System"},
        {"tls", %{"certfile" => "cert", "keyfile" => "key", "provider" => "ex_ssl"}},
        {"tls", %{"certfile" => "cert", "keyfile" => "key", "alpn" => ["h3"]}},
        {"tls", %{"certfile" => "cert"}},
        {"tls", %{}},
        {"h3_limits", %{"max_streams" => 9}},
        {"h3_limits", %{"dynamic_table_capacity" => 1}},
        {"h3_limits", %{"blocked_streams" => 1}},
        {"h3_limits", %{"arbitrary" => 1}},
        {"limits", %{"max_bytes" => 33_554_432, "max_state" => 1}}
      ] do
    test "H3 rejects #{name}=#{inspect(value)} before starting owners" do
      assert {:error, _} =
               Config.decode(put_service(config(), unquote(name), unquote(Macro.escape(value))))

      refute Process.whereis(Gaoxy.Server.RouteStores)
      refute Process.whereis(Gaoxy.Server.Runtime)
    end
  end

  test "H3 selection requires an explicit protocol list and both credentials" do
    for key <- ["protocols", "tls"] do
      assert {:error, _} =
               Config.decode(
                 update_in(config(), ["services", Access.at(0)], &Map.delete(&1, key))
               )
    end
  end

  test "binary configuration input cannot create handler, option or identity atoms" do
    value = "gaoxy_h3_untrusted_#{System.unique_integer([:positive])}"
    assert_raise ArgumentError, fn -> String.to_existing_atom(value) end
    assert {:error, _} = Config.decode(put_service(config(), "handler", value))
    assert {:error, _} = Config.decode(put_service(config(), value, true))
    assert {:ok, [services: [%{id: ^value}]]} = Config.decode(put_service(config(), "id", value))
    assert_raise ArgumentError, fn -> String.to_existing_atom(value) end
  end

  test "standalone H3 budget includes two snapshots for each of eight admitted streams" do
    # Default native connection 2_092_032, request 196_608, writer 16_384.
    # 2_092_032 + 8 * (196_608 + 2 * 1_048_576) + 16_384.
    required = 20_458_496
    assert {:ok, _} = Config.decode(put_service(config(), "limits", %{"max_bytes" => required}))

    assert {:error, :route_snapshot_byte_budget} =
             Config.decode(put_service(config(), "limits", %{"max_bytes" => required - 1}))
  end

  test "custom H3 stream and HTTP bounds retain the exact per-stream snapshot budget" do
    data =
      config()
      |> put_service("h3_limits", %{"max_streams" => 2})
      |> put_service("http_limits", %{
        "max_header_bytes" => 4096,
        "max_read_chunk" => 4096,
        "max_buffer_bytes" => 8192
      })

    # Connection 463_872, request 90_112, writer 16_384; two 2MiB snapshots.
    required = 4_854_784
    assert {:ok, _} = Config.decode(put_service(data, "limits", %{"max_bytes" => required}))

    assert {:error, :route_snapshot_byte_budget} =
             Config.decode(put_service(data, "limits", %{"max_bytes" => required - 1}))
  end

  test "H3 static count and UTF-8 byte boundaries include status and generated length" do
    options = %{status: 200, body: "h3", headers: [{"x", "é"}]}
    profile = %{protocols: [:http3], http_limits: %{max_headers: 3, max_header_bytes: 124}}
    assert :ok = StaticEndpoint.validate_limits(options, profile)

    assert {:error, :static_response_limit} =
             StaticEndpoint.validate_limits(
               options,
               put_in(profile, [:http_limits, :max_headers], 2)
             )

    assert {:error, :static_response_limit} =
             StaticEndpoint.validate_limits(
               options,
               put_in(profile, [:http_limits, :max_header_bytes], 123)
             )
  end

  test "initial H3 config rejects static count and byte overflow" do
    data = put_target(config(), %{"type" => "static", "body" => "h3", "headers" => [["x", "é"]]})

    assert {:ok, _} =
             Config.decode(
               put_service(data, "http_limits", %{"max_headers" => 3, "max_header_bytes" => 124})
             )

    assert {:error, :static_response_limit} =
             Config.decode(put_service(data, "http_limits", %{"max_headers" => 2}))

    assert {:error, :static_response_limit} =
             Config.decode(put_service(data, "http_limits", %{"max_header_bytes" => 123}))
  end

  defp put_service(data, key, value), do: put_in(data, ["services", Access.at(0), key], value)

  defp put_target(data, target),
    do:
      put_in(data, ["services", Access.at(0), "routes", "routes", Access.at(0), "target"], target)

  defp config do
    %{
      "version" => 1,
      "services" => [
        %{
          "id" => "h3",
          "handler" => "http3",
          "transport" => "quic",
          "protocols" => ["http3"],
          "ip" => "127.0.0.1",
          "port" => 0,
          "tls" => %{
            "certfile" => "/tmp/gaoxy-fixture/cert.pem",
            "keyfile" => "/tmp/gaoxy-fixture/key.pem"
          },
          "limits" => %{"max_bytes" => 33_554_432},
          "routes" => %{
            "version" => 1,
            "routes" => [%{"target" => %{"type" => "static", "body" => "h3"}}]
          }
        }
      ]
    }
  end
end
