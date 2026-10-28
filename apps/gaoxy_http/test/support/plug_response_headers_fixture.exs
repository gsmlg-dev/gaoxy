defmodule Gaoxy.PlugResponseHeadersFixture do
  def init(options), do: options

  def call(conn, {owner, path}) do
    case {conn.method, conn.request_path} do
      {"POST", "/mcp"} ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        %{"jsonrpc" => "2.0", "id" => 1, "method" => "tools/call"} = JSON.decode!(body)

        conn = conn |> legacy_headers() |> Plug.Conn.put_resp_content_type("text/event-stream")
        conn = Plug.Conn.send_chunked(conn, 200)

        {:ok, conn} =
          Plug.Conn.chunk(conn, "event: message\ndata: {\"id\":1,\"result\":\"ok\"}\n\n")

        {:ok, conn} = Plug.Conn.chunk(conn, ": complete\n\n")
        conn

      {"GET", "/notifications"} ->
        conn =
          conn
          |> legacy_headers()
          |> Plug.Conn.put_resp_content_type("text/event-stream")
          |> Gaoxy.HTTP.put_stream_timeout(:infinity)
          |> Plug.Conn.send_chunked(200)

        {:ok, conn} = Plug.Conn.chunk(conn, "event: endpoint\ndata: /mcp\n\n")
        send(owner, {:notification_started, self()})

        receive do
          :send_notification ->
            {:ok, conn} =
              Plug.Conn.chunk(
                conn,
                "event: message\ndata: {\"method\":\"notifications/ready\"}\n\n"
              )

            conn
        after
          5_000 -> raise "peer never observed the first notification event"
        end

      {"GET", "/release"} ->
        send(owner, :notification_received)
        Plug.Conn.send_resp(conn, 200, "release-ok")

      {"GET", "/file"} ->
        conn |> legacy_headers() |> Plug.Conn.send_file(200, path, 2, 4)

      {"GET", "/inform"} ->
        conn =
          Plug.Conn.inform(conn, 103, [
            {"link", "</asset>; rel=preload"} | legacy_fields()
          ])

        conn |> legacy_headers() |> Plug.Conn.send_resp(200, "after-103")

      {"GET", "/buffered"} ->
        conn |> legacy_headers() |> Plug.Conn.send_resp(200, "buffered-ok")

      {"GET", "/ok"} ->
        Plug.Conn.send_resp(conn, 200, "followup-ok")
    end
  end

  defp legacy_headers(conn), do: %{conn | resp_headers: legacy_fields() ++ conn.resp_headers}

  defp legacy_fields do
    [
      {"connection", "keep-alive, X-One"},
      {"connection", "X-Two,\tX-Three"},
      {"keep-alive", "timeout=5"},
      {"proxy-connection", "keep-alive"},
      {"upgrade", "legacy"},
      {"te", "trailers"},
      {"x-one", "hop-one"},
      {"x-two", "hop-two"},
      {"x-three", "hop-three"},
      {"set-cookie", "a=1"},
      {"set-cookie", "b=2"},
      {"x-ordinary", "preserved"}
    ]
  end
end
