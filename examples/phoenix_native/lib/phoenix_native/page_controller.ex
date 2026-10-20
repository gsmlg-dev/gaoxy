defmodule PhoenixNative.PageController do
  use Phoenix.Controller, formats: [:html]
  import Plug.Conn

  def index(conn, _params) do
    html(
      conn,
      "<h1 id=\"page\">Gaoxy Phoenix native</h1><a href=\"/live-counter\">Live counter</a><p><a href=\"/static/hello.txt\">Static file</a></p>"
    )
  end

  def events(conn, _params) do
    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> send_chunked(200)
    |> chunk("event: ready\ndata: native\n\n")
    |> case do
      {:ok, conn} -> conn
      {:error, reason} -> raise "SSE write failed: #{inspect(reason)}"
    end
  end

  def body(conn, %{"value" => value}), do: send_resp(conn, 200, value)
end
