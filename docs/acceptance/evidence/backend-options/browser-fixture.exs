defmodule BackendOptionsBrowserEndpoint do
  def init(options), do: options

  def call(conn, _) do
    conn
    |> Plug.Conn.put_resp_content_type("text/html")
    |> Plug.Conn.send_resp(
      200,
      "<title>Gaoxy backend options</title><h1>Gaoxy backend options</h1><p>Phoenix adapter listener with two acceptors.</p>"
    )
  end
end

[child] =
  Gaoxy.PhoenixAdapter.child_specs(BackendOptionsBrowserEndpoint,
    http: [
      port: 0,
      limits: %{max_active: 8},
      hell_options: [num_acceptors: 2, transport_options: [backlog: 32, keepalive: true]]
    ]
  )

{module, function, arguments} = child.start
{:ok, owner} = apply(module, function, arguments)

%{instance: instance, listeners: [%{local: {:ok, {_, port}}}]} =
  Gaoxy.PhoenixAdapter.listeners(BackendOptionsBrowserEndpoint)

IO.puts("BROWSER_READY http://127.0.0.1:#{port}")
deadline = System.monotonic_time(:millisecond) + 60_000

Stream.repeatedly(fn -> Process.sleep(100) end)
|> Enum.reduce_while(nil, fn _, _ ->
  if File.exists?("/tmp/gaoxy-backend-options-browser.stop") or
       System.monotonic_time(:millisecond) > deadline, do: {:halt, nil}, else: {:cont, nil}
end)

monitor = Process.monitor(instance)
:ok = GenServer.stop(owner, :normal, 3_000)

receive do
  {:DOWN, ^monitor, :process, ^instance, :normal} -> IO.puts("BROWSER_CLEANUP_PASS")
after
  1_000 -> raise "browser fixture failed cleanup"
end

{:ok, socket} = :gen_tcp.listen(port, ip: {127, 0, 0, 1}, active: false, reuseaddr: true)
:ok = :gen_tcp.close(socket)
IO.puts("BROWSER_REBIND_PASS")
