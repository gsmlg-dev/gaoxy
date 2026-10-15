defmodule Gaoxy.Proxy.ManagedH2GenerationExclusionTest do
  use ExUnit.Case, async: true

  alias Gaoxy.HTTP.{Generation, Router}
  alias Gaoxy.Proxy.HTTP, as: ProxyHTTP
  alias Gaoxy.Proxy.UpstreamTransports

  test "static fixed H2 routes compile but both Store paths reject without contacting an owner" do
    store = start_supervised!({Generation, routes: h1_routes()})
    assert {:ok, current, original} = Generation.snapshot(store)

    for protocol <- [:http2, :h2c] do
      options = h2_options(protocol)
      assert {:ok, config} = ProxyHTTP.init(options)
      assert config.upstream_protocol == protocol
      assert config.client == Gaoxy.Proxy.ManagedH2Client

      assert {:error, :unsupported_generation_endpoint} =
               apply(ProxyHTTP, :generation_validate, [config])

      routes = [%{target: {ProxyHTTP, options}}]
      assert {:ok, compiled} = Router.compile(routes)
      assert {:error, :unsupported_generation_endpoint} = Generation.prepare(store, routes)

      assert {:error, :unsupported_generation_endpoint} =
               Generation.activate(store, current, compiled)

      assert {:ok, ^current, ^original} = Generation.snapshot(store)
      refute_receive {:"$gen_call", _, _}, 0
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

      assert {:error, :unsupported_generation_endpoint} =
               Generation.activate(store, current, forged)

      assert {:error, :unsupported_generation_endpoint} =
               GenServer.call(
                 store,
                 {:activate, current, forged, Gaoxy.Lifecycle.deadline(1000)},
                 2000
               )

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
