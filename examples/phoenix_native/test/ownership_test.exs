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
end
