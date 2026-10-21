defmodule PhoenixNative.OwnershipTest do
  use ExUnit.Case

  test "an Endpoint-owned listener rejects a second gateway listener" do
    assert PhoenixNative.Endpoint.config(:server) == true

    assert {:error, :duplicate_endpoint_listener} =
             Gaoxy.HTTP.PlugEndpoint.init({PhoenixNative.Endpoint, []})

    assert {:error, _reason} =
             Gaoxy.HTTP.start_link(plug: {PhoenixNative.Endpoint, []})
  end

  test "global Phoenix serve_endpoints also rejects a duplicate gateway" do
    endpoint_config = Application.fetch_env!(:phoenix_native, PhoenixNative.Endpoint)
    global = Application.get_env(:phoenix, :serve_endpoints)

    on_exit(fn ->
      Application.put_env(:phoenix_native, PhoenixNative.Endpoint, endpoint_config)

      if global == nil,
        do: Application.delete_env(:phoenix, :serve_endpoints),
        else: Application.put_env(:phoenix, :serve_endpoints, global)
    end)

    Application.put_env(
      :phoenix_native,
      PhoenixNative.Endpoint,
      Keyword.delete(endpoint_config, :server)
    )

    Application.put_env(:phoenix, :serve_endpoints, true)

    assert {:error, :duplicate_endpoint_listener} =
             Gaoxy.HTTP.PlugEndpoint.init({PhoenixNative.Endpoint, []})
  end

  test "WebSocket and code-reload wrappers preserve real Endpoint listener ownership" do
    endpoint = PhoenixNative.Endpoint
    config = Application.fetch_env!(:phoenix_native, endpoint)
    paths = ["/socket/websocket", "/live/websocket"]
    on_exit(fn -> Application.put_env(:phoenix_native, endpoint, config) end)

    for target <- [endpoint, {Phoenix.Endpoint.SyncCodeReloadPlug, {endpoint, []}}] do
      Application.put_env(:phoenix_native, endpoint, Keyword.put(config, :server, true))

      assert {:error, :duplicate_endpoint_listener} =
               Gaoxy.HTTP.PlugEndpoint.init({Gaoxy.PhoenixWebSocket, {target, paths}})

      assert {:ok, {Gaoxy.PhoenixWebSocket, _}} =
               Gaoxy.HTTP.PlugEndpoint.init(
                 {Gaoxy.PhoenixWebSocket, {target, paths}, :endpoint_managed}
               )

      Application.put_env(:phoenix_native, endpoint, Keyword.put(config, :server, false))

      assert {:ok, {Gaoxy.PhoenixWebSocket, _}} =
               Gaoxy.HTTP.PlugEndpoint.init({Gaoxy.PhoenixWebSocket, {target, paths}})
    end
  end

  test "managed WebSocket startup retains Phoenix's real code-reload composition" do
    endpoint = PhoenixNative.Endpoint
    paths = ["/socket/websocket", "/live/websocket"]

    assert [%{start: {Gaoxy.HTTP.ListenerSet, :start_link, [options]}}] =
             Gaoxy.PhoenixAdapter.child_specs(endpoint,
               server: true,
               code_reloader: true,
               websocket_paths: paths,
               http: [port: 0]
             )

    assert {:endpoint, Gaoxy.HTTP.PlugEndpoint,
            {Gaoxy.PhoenixWebSocket,
             {{Phoenix.Endpoint.SyncCodeReloadPlug, {^endpoint, []}}, ^paths},
             :endpoint_managed}} =
             options[:plan].target
  end
end
