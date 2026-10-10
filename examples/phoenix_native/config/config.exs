import Config

https =
  case System.get_env("PHOENIX_NATIVE_HTTPS_PORT") do
    nil ->
      nil

    port ->
      [
        ip: {127, 0, 0, 1},
        port: String.to_integer(port),
        certfile: System.fetch_env!("PHOENIX_NATIVE_CERTFILE"),
        keyfile: System.fetch_env!("PHOENIX_NATIVE_KEYFILE")
      ]
  end

config :phoenix_native, PhoenixNative.Endpoint,
  adapter: Gaoxy.PhoenixAdapter,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PHOENIX_NATIVE_PORT", "0"))],
  https: https,
  server: true,
  code_reloader: System.get_env("PHOENIX_NATIVE_RELOAD") == "1",
  check_origin: :conn,
  secret_key_base: String.duplicate("a", 64),
  pubsub_server: PhoenixNative.PubSub,
  live_view: [signing_salt: "nativefixture"]

config :phoenix, :json_library, Jason
