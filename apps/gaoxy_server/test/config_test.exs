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

  test "omitted JSON instance policy preserves the original decoded option shape" do
    assert {:ok, [services: []]} = Gaoxy.Server.Config.decode(%{"version" => 1, "services" => []})
  end

  test "JSON explicit equal and adaptive policies normalize and reach the single core child" do
    for policy <- [
          %{"soft_limit" => 100, "hard_limit" => 200},
          %{"soft_limit" => 100, "hard_limit" => 100},
          %{"soft_limit" => nil, "hard_limit" => nil}
        ] do
      assert {:ok, options} =
               Gaoxy.Server.Config.decode(%{
                 "version" => 1,
                 "services" => [],
                 "resource_budget" => policy
               })

      assert {:ok, expected} =
               Gaoxy.Config.validate(
                 resource_budget: %{
                   soft_limit: policy["soft_limit"],
                   hard_limit: policy["hard_limit"]
                 }
               )

      assert options[:resource_budget] == expected.resource_budget
      assert {:ok, plan} = Gaoxy.Proxy.Gateway.compile(options)

      context = %{
        plan: plan,
        planned: [],
        instance: :json_entry_runtime,
        owners: :json_entry_owners,
        host: []
      }

      assert {:ok, {_, children}} = Gaoxy.Proxy.Gateway.RuntimeSupervisor.init(context)

      assert [%{start: {Gaoxy, :start_link, [core_options]}}] =
               Enum.filter(children, &match?(%{start: {Gaoxy, :start_link, [_]}}, &1))

      assert core_options[:resource_budget] == expected.resource_budget
    end
  end

  test "JSON rejects malformed instance policy values and threshold pairs" do
    for policy <- [
          %{},
          %{"soft_limit" => 1},
          %{"hard_limit" => 2},
          %{"soft_limit" => nil, "hard_limit" => 2},
          %{"soft_limit" => 1, "hard_limit" => nil},
          %{"soft_limit" => 3, "hard_limit" => 2},
          %{"soft_limit" => 0, "hard_limit" => 2},
          %{"soft_limit" => 1, "hard_limit" => 9_223_372_036_854_775_808},
          %{"soft_limit" => "1", "hard_limit" => 2}
        ] do
      assert {:error, :invalid_resource_budget} =
               Gaoxy.Server.Config.decode(%{
                 "version" => 1,
                 "services" => [],
                 "resource_budget" => policy
               })
    end

    for policy <- [nil, [], 1, "adaptive"] do
      assert {:error, :invalid_options} =
               Gaoxy.Server.Config.decode(%{
                 "version" => 1,
                 "services" => [],
                 "resource_budget" => policy
               })
    end
  end

  test "JSON exposes only the two public instance thresholds" do
    for key <- ["provenance", "server", "capacity_probe", "detection"] do
      policy = %{"soft_limit" => 1, "hard_limit" => 2, key => true}

      assert {:error, :unknown_configuration_keys} =
               Gaoxy.Server.Config.decode(%{
                 "version" => 1,
                 "services" => [],
                 "resource_budget" => policy
               })
    end
  end

  test "JSON preserves all three quotas and explicit legacy service caps" do
    limits = %{
      "max_connections" => 100,
      "max_requests" => 200,
      "max_streams" => 300,
      "max_active" => 128,
      "max_bytes" => 1_048_576
    }

    service = %{
      "id" => "quota",
      "handler" => "stream_echo",
      "transport" => "tcp",
      "limits" => limits
    }

    assert {:ok, [services: [spec]] = options} =
             Gaoxy.Server.Config.decode(%{"version" => 1, "services" => [service]})

    expected = %{
      max_connections: 100,
      max_requests: 200,
      max_streams: 300,
      max_active: 128,
      max_bytes: 1_048_576
    }

    assert spec.limits == expected
    assert {:ok, %{services: [normalized]}} = Gaoxy.Config.validate(options)
    assert Map.take(normalized.budget_policy, Map.keys(expected)) == expected
  end

  test "unknown JSON budget and quota names are rejected without creating atoms" do
    unknown = "arb_entry_unknown_#{System.unique_integer([:positive])}"
    assert_raise ArgumentError, fn -> String.to_existing_atom(unknown) end
    data = %{"version" => 1, "services" => []}

    assert {:error, :unknown_configuration_keys} =
             Gaoxy.Server.Config.decode(Map.put(data, "resource_budget", %{unknown => 1}))

    service = %{
      "id" => "unknown",
      "handler" => "stream_echo",
      "transport" => "tcp",
      "limits" => %{unknown => 1}
    }

    assert {:error, :unknown_configuration_keys} =
             Gaoxy.Server.Config.decode(%{data | "services" => [service]})

    assert_raise ArgumentError, fn -> String.to_existing_atom(unknown) end
  end

  @tag :tmp_dir
  test "loading JSON retains normalized instance policy and rejects invalid quotas", %{
    tmp_dir: dir
  } do
    path = Path.join(dir, "budget.json")
    limits = %{"max_connections" => 100, "max_requests" => 200, "max_streams" => 300}

    service = %{
      "id" => "quota",
      "handler" => "stream_echo",
      "transport" => "tcp",
      "limits" => limits
    }

    data = %{
      "version" => 1,
      "resource_budget" => %{"soft_limit" => 100, "hard_limit" => 200},
      "services" => [service]
    }

    File.write!(path, JSON.encode!(data))
    assert {:ok, options} = Gaoxy.Server.Config.load(path)

    assert options[:resource_budget] == %{
             soft_limit: 100,
             hard_limit: 200,
             provenance: %{source: :explicit}
           }

    assert {:ok, plan} = Gaoxy.Proxy.Gateway.compile(options)
    assert plan.resource_budget == options[:resource_budget]

    for key <- Map.keys(limits) do
      File.write!(path, JSON.encode!(put_in(data, ["services", Access.at(0), "limits", key], 0)))
      assert {:error, :invalid_limits} = Gaoxy.Server.Config.load(path)
    end
  end
end
