defmodule PhoenixNative.Layouts do
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <title>Gaoxy Phoenix native fixture</title>
      </head>
      <body>
        {@inner_content}
        <script src="/vendor/phoenix/phoenix.min.js"></script>
        <script src="/vendor/live_view/phoenix_live_view.min.js"></script>
        <script src="/static/app.js"></script>
      </body>
    </html>
    """
  end
end
