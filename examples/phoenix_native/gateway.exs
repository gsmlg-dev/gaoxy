endpoint = PhoenixNative.Endpoint
config = Application.fetch_env!(:phoenix_native, endpoint)
Application.put_env(:phoenix_native, endpoint, Keyword.put(config, :server, false))
{:ok, _apps} = Application.ensure_all_started(:phoenix_native)

{:ok, instance} =
  Gaoxy.HTTP.start_link(
    id: :gateway,
    plug: {endpoint, []},
    port: String.to_integer(System.get_env("PHOENIX_NATIVE_PORT", "0"))
  )

IO.inspect(Gaoxy.info(instance, :gateway).local, label: "GATEWAY_BOUND")
Process.sleep(:infinity)
