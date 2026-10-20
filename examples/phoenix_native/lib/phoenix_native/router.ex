defmodule PhoenixNative.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {PhoenixNative.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  scope "/", PhoenixNative do
    pipe_through(:browser)

    get("/", PageController, :index)
    live("/live-counter", CounterLive)
  end

  scope "/", PhoenixNative do
    get("/events", PageController, :events)
    post("/body", PageController, :body)
  end
end
