endpoint = PhoenixNative.Endpoint
config = Application.fetch_env!(:phoenix_native, endpoint)
Application.put_env(:phoenix_native, endpoint, Keyword.put(config, :server, false))
false = Phoenix.Endpoint.server?(:phoenix_native, endpoint)
{:ok, _apps} = Application.ensure_all_started(:phoenix_native)

defmodule PhoenixNative.H3BrowserPlug do
  @behaviour Plug

  def init(observer) do
    {:ok, {module, initialized}} =
      Gaoxy.HTTP.PlugEndpoint.init(
        {Gaoxy.PhoenixWebSocket,
         {PhoenixNative.Endpoint, ["/socket/websocket", "/live/websocket"]}}
      )

    {observer, module, initialized}
  end

  def call(conn, {observer, module, options}) do
    conn = module.call(conn, options)

    send(observer, {
      :h3_browser_request,
      %{
        path: conn.request_path,
        marker: Plug.Conn.get_req_header(conn, "x-gaoxy-m4-browser"),
        protocol: to_string(Plug.Conn.get_http_protocol(conn)),
        status: conn.status
      }
    })

    conn
  end
end

directory = System.fetch_env!("GAOXY_HTTP3_CERT_DIR")

{:ok, spec} =
  Gaoxy.HTTP.HTTP3.service_spec(
    id: :phoenix_h3,
    ip: {127, 0, 0, 1},
    port: 0,
    plug: {PhoenixNative.H3BrowserPlug, self()},
    extended_connect: true,
    tls: %{
      certfile: Path.join(directory, "cert.pem"),
      keyfile: Path.join(directory, "key.pem")
    },
    http_limits: %{request_timeout: 10_000, write_timeout: 5_000}
  )

{:ok, runtime} = Gaoxy.start_link(services: [spec])
{:ok, {_, port}} = Gaoxy.info(runtime, :phoenix_h3).local

defmodule PhoenixNative.H3Gateway do
  def emit(prefix, data), do: IO.puts(prefix <> " " <> JSON.encode!(data))

  def collect(requests) do
    receive do
      {:h3_browser_request, request} -> collect([request | requests])
    after
      0 -> Enum.reverse(requests)
    end
  end

  def run(runtime, port, requests \\ []) do
    case IO.gets("") do
      :eof ->
        stop(runtime, port)

      line ->
        requests = collect(Enum.reverse(requests))

        case JSON.decode!(line) do
          %{"command" => "sample"} ->
            emit("GAOXY_HTTP3_BROWSER_CONTROL", %{
              event: "sample",
              requests: requests,
              admission:
                Map.take(Gaoxy.status(runtime, :phoenix_h3), [
                  :active,
                  :retained_bytes,
                  :cleanup_pending,
                  :cleanup_failed,
                  :queued_items,
                  :queued_bytes
                ])
            })

            run(runtime, port, requests)

          %{"command" => "stop"} ->
            stop(runtime, port)
        end
    end
  end

  defp stop(runtime, port) do
    monitor = Process.monitor(runtime)
    started = Gaoxy.Lifecycle.now()
    :ok = Gaoxy.stop(runtime, 5_000)

    receive do
      {:DOWN, ^monitor, :process, ^runtime, _} -> :ok
    after
      1_000 -> raise "browser runtime termination unconfirmed"
    end

    {:ok, socket} = :gen_udp.open(port, [:binary, ip: {127, 0, 0, 1}])
    :ok = :gen_udp.close(socket)
    :ok = Application.stop(:phoenix_native)

    emit("GAOXY_HTTP3_BROWSER_CONTROL", %{
      event: "stopped",
      runtime_down: true,
      port_rebound: true,
      elapsed_ms: Gaoxy.Lifecycle.now() - started
    })
  end
end

PhoenixNative.H3Gateway.emit("GAOXY_HTTP3_BROWSER_READY", %{
  event: "ready",
  port: port,
  server_disabled: true,
  elixir: System.version(),
  otp: System.otp_release(),
  erts: to_string(:erlang.system_info(:version))
})

PhoenixNative.H3Gateway.run(runtime, port)
