defmodule Gaoxy.UnifiedPhoenixFixture do
  def emit(value), do: IO.puts("GAOXY_UNIFIED_PHOENIX " <> JSON.encode!(value))

  defmodule Observer do
    def init({module, options}), do: {module, module.init(options)}

    def call(conn, {module, options}) do
      returned = module.call(conn, options)

      if conn.request_path in ["/socket/websocket", "/live/websocket"] do
        {Gaoxy.PlugAdapter, exchange} = conn.adapter

        Gaoxy.UnifiedPhoenixFixture.emit(%{
          event: "websocket",
          path: conn.request_path,
          marker: conn.query_string,
          version: to_string(exchange.request.version),
          protocol: exchange.request.protocol,
          state: to_string(returned.state)
        })
      end

      returned
    end
  end

  defmodule Adapter do
    def child_specs(endpoint, config) do
      Gaoxy.PhoenixAdapter.child_specs(endpoint, config)
      |> Enum.map(fn %{start: {Gaoxy.HTTP.ListenerSet, :start_link, [options]}} = child ->
        plan = options[:plan]
        {:endpoint, Gaoxy.HTTP.PlugEndpoint, {module, raw, :endpoint_managed}} = plan.target

        target =
          {:endpoint, Gaoxy.HTTP.PlugEndpoint,
           {Gaoxy.UnifiedPhoenixFixture.Observer, {module, raw}, :endpoint_managed}}

        %{
          child
          | start:
              {Gaoxy.HTTP.ListenerSet, :start_link,
               [Keyword.put(options, :plan, %{plan | target: target})]}
        }
      end)
    end

    defdelegate server_info(endpoint, scheme), to: Gaoxy.PhoenixAdapter
  end

  def run do
    endpoint = PhoenixNative.Endpoint
    config = Application.fetch_env!(:phoenix_native, endpoint)
    Application.put_env(:phoenix_native, endpoint, Keyword.put(config, :adapter, Adapter))
    {:ok, _} = Application.ensure_all_started(:phoenix_native)
    %{phase: :ready, listeners: listeners} = Gaoxy.PhoenixAdapter.listeners(endpoint)

    ports = Map.new(listeners, fn %{role: role, local: {:ok, {_, port}}} -> {role, port} end)

    emit(%{
      event: "ready",
      ports: ports,
      endpoint_server: endpoint.config(:server),
      code_reloader: endpoint.config(:code_reloader)
    })

    "stop\n" = IO.gets("")
    :ok = Application.stop(:phoenix_native)
    emit(%{event: "stopped"})
  end
end

Gaoxy.UnifiedPhoenixFixture.run()
