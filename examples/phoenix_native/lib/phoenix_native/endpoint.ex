defmodule PhoenixNative.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoenix_native

  @session_options [store: :cookie, key: "_phoenix_native", signing_salt: "nativefixture"]

  socket("/socket", PhoenixNative.UserSocket,
    websocket: [timeout: :infinity],
    longpoll: false
  )

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [timeout: :infinity, connect_info: [session: @session_options]],
    longpoll: false
  )

  plug(Plug.Static,
    at: "/static",
    from: :phoenix_native,
    gzip: false
  )

  plug(Plug.Static,
    at: "/vendor/phoenix",
    from: {:phoenix, "priv/static"},
    only: ~w(phoenix.min.js)
  )

  plug(Plug.Static,
    at: "/vendor/live_view",
    from: {:phoenix_live_view, "priv/static"},
    only: ~w(phoenix_live_view.min.js)
  )

  if code_reloading? do
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(PhoenixNative.Router)
end
