defmodule Gaoxy.E2E.Echo do
  def init(state), do: {:ok, state}
  def handle_in({bytes, opcode: opcode}, state), do: {:push, {opcode, bytes}, state}
  def handle_info(_, state), do: {:ok, state}
end

defmodule Gaoxy.E2E.Plug do
  import Plug.Conn
  def init(options), do: options

  def call(conn, _) do
    conn = put_resp_header(conn, "x-e2e", "gaoxy")

    case conn.request_path do
      "/health" ->
        send_resp(conn, 200, "ok")

      "/upload" ->
        {body, conn} = read_all(conn, [])
        send_resp(conn, 200, body)

      "/stream" ->
        conn = send_chunked(conn, 200)
        {:ok, conn} = chunk(conn, "first\n")
        {:ok, conn} = chunk(conn, "second\n")
        conn

      "/websocket" ->
        WebSockAdapter.upgrade(conn, Gaoxy.E2E.Echo, [], timeout: 5_000)
    end
  end

  defp read_all(conn, parts) do
    case read_body(conn, read_timeout: 3_000) do
      {:more, bytes, conn} -> read_all(conn, [bytes | parts])
      {:ok, bytes, conn} -> {IO.iodata_to_binary(Enum.reverse([bytes | parts])), conn}
    end
  end
end

for app <- [:gaoxy_http, :gaoxy_http3] do
  {:ok, _} = Application.ensure_all_started(app)
end

version = to_string(Application.spec(:gaoxy, :vsn))
true = version == System.fetch_env!("GAOXY_E2E_VERSION")
directory = System.fetch_env!("GAOXY_E2E_CERTS")
tls = %{certfile: Path.join(directory, "cert.pem"), keyfile: Path.join(directory, "key.pem")}

services =
  for {id, module, extra} <- [
        {:h1, Gaoxy.HTTP, []},
        {:https, Gaoxy.HTTP, [transport: :tls, tls: tls]},
        {:h3, Gaoxy.HTTP.HTTP3, [tls: tls]}
      ] do
    {:ok, runtime} =
      module.start_link(
        [id: id, ip: {127, 0, 0, 1}, port: 0, plug: {Gaoxy.E2E.Plug, []}] ++ extra
      )

    {id, runtime}
  end

try do
  ports =
    Map.new(services, fn {id, runtime} ->
      {:ok, {{127, 0, 0, 1}, port}} = Gaoxy.info(runtime, id).local
      {id, port}
    end)

  File.write!(
    System.fetch_env!("GAOXY_E2E_READY"),
    JSON.encode!(%{version: version, ports: ports})
  )

  deadline = System.monotonic_time(:millisecond) + 120_000

  Stream.repeatedly(fn ->
    true = System.monotonic_time(:millisecond) < deadline
    Process.sleep(20)
    File.exists?(System.fetch_env!("GAOXY_E2E_STOP"))
  end)
  |> Enum.find(& &1)
after
  for {_, runtime} <- Enum.reverse(services) do
    :ok = Gaoxy.stop(runtime, 3_000)
    false = Process.alive?(runtime)
  end
end

IO.puts("GAOXY_E2E_STOPPED")
