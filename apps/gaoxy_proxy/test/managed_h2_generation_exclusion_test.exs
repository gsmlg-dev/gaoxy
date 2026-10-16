defmodule Gaoxy.Proxy.ManagedH2GenerationExclusionTest do
  use ExUnit.Case, async: true

  alias Gaoxy.HTTP.{Generation, Router}
  alias Gaoxy.Proxy.HTTP, as: ProxyHTTP
  alias Gaoxy.Proxy.UpstreamTransports

  test "canonical H2 shapes pass pure validation while malformed configs remain excluded" do
    store = start_supervised!({Generation, routes: h1_routes()})
    assert {:ok, current, original} = Generation.snapshot(store)

    for protocol <- [:http2, :h2c] do
      options = h2_options(protocol)
      assert {:ok, config} = ProxyHTTP.init(options)
      assert config.upstream_protocol == protocol
      assert config.client == Gaoxy.Proxy.ManagedH2Client
      # These are shape-only handles. Genuine baseline activation and listener
      # acceptance use real prepared transports in fixed_generation_test.
      assert :ok = ProxyHTTP.generation_validate(config)
      routes = [%{target: {ProxyHTTP, options}}]
      assert {:ok, compiled} = Router.compile(routes)
      assert {:ok, prepared} = Generation.prepare(store, routes)
      assert prepared.resources == compiled.resources

      for invalid <- invalid_h2_configs(config) do
        assert {:error, :unsupported_generation_endpoint} =
                 ProxyHTTP.generation_validate(invalid)

        forged = %{
          original
          | generation: make_ref(),
            routes: [%{host: :any, methods: :any, path: :any, target: {ProxyHTTP, invalid}}],
            resources: []
        }

        assert {:error, :unsupported_generation_endpoint} =
                 Generation.activate(store, current, forged)

        assert {:error, :unsupported_generation_endpoint} =
                 GenServer.call(
                   store,
                   {:activate, current, forged, Gaoxy.Lifecycle.deadline(1000)},
                   2000
                 )

        assert {:error, :unsupported_generation_endpoint} = Generation.start_link(router: forged)
        assert {:ok, ^current, ^original} = Generation.snapshot(store)
        refute_receive {:"$gen_call", _, _}, 0
      end
    end
  end

  test "forged prepared H2 routers cannot bypass the public or direct Store activation gate" do
    store = start_supervised!({Generation, routes: h1_routes()})
    assert {:ok, current, original} = Generation.snapshot(store)

    for protocol <- [:http2, :h2c] do
      assert {:ok, config} = ProxyHTTP.init(h2_options(protocol))

      forged = %{
        original
        | generation: make_ref(),
          routes: [%{host: :any, methods: :any, path: :any, target: {ProxyHTTP, config}}],
          resources: []
      }

      assert {:error, :invalid_endpoint_resources} =
               Generation.activate(store, current, forged)

      assert {:error, :invalid_endpoint_resources} =
               GenServer.call(
                 store,
                 {:activate, current, forged, Gaoxy.Lifecycle.deadline(1000)},
                 2000
               )

      assert {:error, :invalid_endpoint_resources} = Generation.start_link(router: forged)

      assert {:ok, ^current, ^original} = Generation.snapshot(store)
      refute_receive {:"$gen_call", _, _}, 0
    end
  end

  test "H1 preparation activation and initial routes retain their accepted Generation behavior" do
    assert {:ok, config} = ProxyHTTP.init(%{upstream: "http://example.test"})
    assert :ok = apply(ProxyHTTP, :generation_validate, [config])
    store = start_supervised!({Generation, routes: h1_routes()})
    assert {:ok, current, _} = Generation.snapshot(store)
    assert {:ok, prepared} = Generation.prepare(store, h1_routes())
    assert {:ok, next} = Generation.activate(store, current, prepared)
    assert next == prepared.generation
  end

  defp invalid_h2_configs(config) do
    backing = String.duplicate("x", 70_000)
    host = binary_part(backing, 0, 100)

    [
      %{config | transport: nil},
      %{config | transport: Map.put(config.transport, :extra, true)},
      %{config | transport: %{config.transport | owner_epoch: nil}},
      %{config | client: Gaoxy.Proxy.HTTPFetchClient},
      %{
        config
        | uri: %{config.uri | scheme: if(config.uri.scheme == "http", do: "https", else: "http")}
      },
      %{config | uri: %{config.uri | path: "/unprepared"}},
      %{config | uri: %{config.uri | query: "unprepared"}},
      %{config | uri: %{config.uri | userinfo: "credentials"}},
      %{config | uri: %{config.uri | host: host, authority: host}},
      %{config | uri: %{config.uri | authority: String.duplicate("x", 65_537)}},
      %{config | limits: %{config.limits | max_chunk_bytes: 65_537}},
      %{config | limits: %{config.limits | opening_timeout: 0}},
      %{config | limits: Map.put(config.limits, :extra, 1)},
      %{config | cacertfile: "/unprepared"},
      %{config | connect_address: {127, 0, 0, 1}},
      Map.put(config, :extra, true)
    ]
  end

  defp h1_routes, do: [%{target: {ProxyHTTP, %{upstream: "http://example.test"}}}]

  defp h2_options(protocol) do
    %{
      upstream: if(protocol == :http2, do: "https://example.test", else: "http://example.test"),
      upstream_protocol: protocol,
      transport: %{
        provider: UpstreamTransports,
        owner: self(),
        owner_epoch: make_ref(),
        resource: make_ref()
      }
    }
  end
end
