defmodule PortableSmoke.Endpoint do
  def init(options), do: {:ok, options}

  def call(%{request: %{method: "GET", path: "/health"}} = exchange, _),
    do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "ok")
end

{:ok, runtime} =
  Gaoxy.HTTP.start_link(
    id: :portable,
    ip: {127, 0, 0, 1},
    port: 0,
    endpoint: {PortableSmoke.Endpoint, []}
  )

monitor = Process.monitor(runtime)

try do
  {:ok, {{127, 0, 0, 1}, port}} = Gaoxy.info(runtime, :portable).local
  url = ~c"http://127.0.0.1:#{port}/health"

  {:ok, {{_, 200, _}, _, "ok"}} =
    :httpc.request(:get, {url, []}, [timeout: 2_000, connect_timeout: 1_000],
      body_format: :binary
    )
after
  :ok = Gaoxy.stop(runtime, 3_000)

  receive do
    {:DOWN, ^monitor, :process, ^runtime, :normal} -> :ok
  after
    3_000 -> raise "portable runtime stop deadline"
  end
end

IO.puts("GAOXY_PORTABLE_PASS")
