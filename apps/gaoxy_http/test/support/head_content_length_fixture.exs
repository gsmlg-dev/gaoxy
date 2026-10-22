defmodule Gaoxy.HeadContentLengthFixture do
  def init(options), do: options

  def call(conn, _) do
    {status, length, body} =
      case conn.request_path do
        "/declared" -> {200, "12345", ""}
        "/declared-body" -> {200, "12345", "body"}
        "/inferred" -> {200, nil, "body"}
        "/empty" -> {200, nil, ""}
        "/zero" -> {200, "0", ""}
        "/204" -> {204, "12345", "body"}
        "/205" -> {205, "12345", "body"}
        "/304" -> {304, "12345", "body"}
      end

    conn = if length, do: Plug.Conn.put_resp_header(conn, "content-length", length), else: conn
    Plug.Conn.send_resp(conn, status, body)
  end
end
