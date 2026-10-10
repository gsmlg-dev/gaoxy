defmodule GaoxyReverseProxyExample.Local do
  import Plug.Conn

  def init(options), do: options
  def call(conn, _options), do: send_resp(conn, 200, "served locally\n")
end

upstream = System.get_env("GAOXY_UPSTREAM", "http://127.0.0.1:4001")
port = System.get_env("GAOXY_PORT", "4000") |> String.to_integer()

{:ok, gateway} =
  Gaoxy.HTTP.start_link(
    ip: {127, 0, 0, 1},
    port: port,
    endpoint:
      {Gaoxy.HTTP.Router,
       [
         %{
           path: "/local",
           target: {Gaoxy.HTTP.PlugEndpoint, {GaoxyReverseProxyExample.Local, []}}
         },
         %{path: :any, target: {Gaoxy.Proxy.HTTP, %{upstream: upstream}}}
       ]},
    limits: %{max_bytes: 134_217_728}
  )

{:ok, {address, port}} = Gaoxy.info(gateway, :http).local

IO.puts(
  "GAOXY_PROXY_READY " <>
    JSON.encode!(%{address: to_string(:inet.ntoa(address)), port: port, upstream: upstream})
)

IO.puts("Enter stop to drain the gateway and exit.")

Stream.repeatedly(fn -> IO.gets("") end)
|> Enum.reduce_while(:ok, fn
  :eof, _ -> {:halt, :ok}
  {:error, reason}, _ -> {:halt, {:error, reason}}
  line, _ -> if String.trim(line) == "stop", do: {:halt, :ok}, else: {:cont, :ok}
end)

:ok = Gaoxy.stop(gateway, 5_000)
