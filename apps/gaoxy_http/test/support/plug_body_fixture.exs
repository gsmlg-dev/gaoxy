defmodule Gaoxy.PlugBodyFixture do
  def init(options), do: options

  def call(conn, _) do
    if conn.request_path == "/status" do
      Plug.Conn.send_resp(conn, 200, "ready")
    else
      options =
        Plug.Parsers.init(
          parsers: [:json, :urlencoded],
          json_decoder: JSON,
          length: if(conn.request_path == "/parser-limit", do: 16_384, else: 100_000)
        )

      conn = Plug.Parsers.call(conn, options)
      Plug.Conn.send_resp(conn, 200, to_string(byte_size(conn.body_params["value"])))
    end
  end
end
