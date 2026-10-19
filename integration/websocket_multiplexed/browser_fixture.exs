defmodule Gaoxy.M5BrowserFixture.Receipt do
  def emit(value), do: IO.puts("GAOXY_M5_BROWSER " <> JSON.encode!(value))

  def wire(conn) do
    {Gaoxy.PlugAdapter, exchange} = conn.adapter
    request = exchange.request

    {connection, stream} =
      case exchange.transport_state do
        {owner, _table, key, _token} -> {inspect(owner), key.handle.id}
        {owner, id, _token} -> {inspect(owner), id}
        nil -> {inspect(self()), "http1-websocket"}
      end

    %{
      marker: URI.decode_query(request.query_string || "")["m5_ws"],
      path: request.path,
      origin: Plug.Conn.get_req_header(conn, "origin"),
      query: request.query_string,
      method: request.method,
      version: to_string(request.version),
      protocol: request.protocol,
      stream: stream,
      connection: connection
    }
  end
end

defmodule Gaoxy.M5BrowserFixture.Observer do
  @behaviour Plug
  alias Gaoxy.M5BrowserFixture.Receipt

  # External H3 initialization explicitly runs the native duplicate-listener
  # guard before this prepared state is wrapped. Managed TLS state is likewise
  # already initialized by the real Phoenix adapter.
  def init({:initialized, module, options}), do: {module, options}

  def call(conn, {module, options}) do
    websocket = conn.request_path in ["/socket/websocket", "/live/websocket"]
    wire = Receipt.wire(conn)

    try do
      returned = module.call(conn, options)

      if websocket do
        Receipt.emit(
          Map.merge(wire, %{
            event:
              if(returned.state == :upgraded, do: "websocket-upgrade", else: "websocket-refusal"),
            status: returned.status,
            state: to_string(returned.state),
            returned_method: returned.method
          })
        )
      end

      returned
    rescue
      error ->
        if websocket,
          do:
            Receipt.emit(
              Map.merge(wire, %{event: "websocket-error", error: Exception.message(error)})
            )

        reraise error, __STACKTRACE__
    end
  end
end

defmodule Gaoxy.M5BrowserFixture.Adapter do
  alias Gaoxy.M5BrowserFixture.Observer

  def child_specs(endpoint, config) do
    Gaoxy.PhoenixAdapter.child_specs(endpoint, config)
    |> Enum.map(fn %{start: {Gaoxy, :start_link, [options]}} = child ->
      services =
        Enum.map(options[:services], fn service ->
          {Gaoxy.HTTP.PlugEndpoint, {module, initialized}} = service.handler_options.endpoint
          endpoint = {Gaoxy.HTTP.PlugEndpoint, {Observer, {module, initialized}}}
          %{service | handler_options: %{service.handler_options | endpoint: endpoint}}
        end)

      send(Application.fetch_env!(:phoenix_native, :m5_browser_observer), {
        :m5_managed_runtime,
        options[:name],
        Enum.map(services, & &1.id)
      })

      %{child | start: {Gaoxy, :start_link, [Keyword.put(options, :services, services)]}}
    end)
  end

  defdelegate server_info(endpoint, scheme), to: Gaoxy.PhoenixAdapter
end

defmodule Gaoxy.M5BrowserFixture do
  alias Gaoxy.M5BrowserFixture.{Adapter, Observer, Receipt}
  @paths ["/socket/websocket", "/live/websocket"]

  def run do
    endpoint = PhoenixNative.Endpoint
    protocol = System.fetch_env!("GAOXY_M5_BROWSER_PROTOCOL")
    certificate = System.fetch_env!("GAOXY_M5_CERT")
    key = System.fetch_env!("GAOXY_M5_KEY")
    Application.put_env(:phoenix_native, :m5_browser_observer, self())
    config = Application.fetch_env!(:phoenix_native, endpoint)

    https = [
      ip: {127, 0, 0, 1},
      port: 0,
      certfile: certificate,
      keyfile: key,
      extended_connect: protocol == "h2"
    ]

    https = if protocol == "http1", do: Keyword.put(https, :protocols, [:http1]), else: https

    # The opaque-Origin policy case uses its own browser connection partition.
    # Reserve capacity for both ordinary H2 connections in this test fixture.
    https =
      if protocol == "h2",
        do: Keyword.put(https, :limits, %{max_bytes: 536_870_912}),
        else: https

    config =
      Keyword.merge(config,
        adapter: Adapter,
        http: false,
        https: if(protocol == "h3", do: false, else: https),
        server: protocol != "h3",
        code_reloader: false,
        websocket_paths: @paths
      )

    Application.put_env(:phoenix_native, endpoint, config)
    {:ok, _apps} = Application.ensure_all_started(:phoenix_native)

    {runtime, ids, port, fallback} =
      if protocol == "h3" do
        false = Phoenix.Endpoint.server?(:phoenix_native, endpoint)

        {:ok, {module, initialized}} =
          Gaoxy.HTTP.PlugEndpoint.init({Gaoxy.PhoenixWebSocket, {endpoint, @paths}})

        {:ok, runtime} =
          Gaoxy.HTTP.HTTP3.start_link(
            id: :m5_phoenix_h3,
            ip: {127, 0, 0, 1},
            port: 0,
            plug: {Observer, {:initialized, module, initialized}},
            extended_connect: true,
            tls: %{certfile: certificate, keyfile: key}
          )

        {:ok, {_, port}} = Gaoxy.info(runtime, :m5_phoenix_h3).local

        # Prepare the opaque-Origin policy check's TCP fallback. The browser
        # enables it only after proving both successful WebSockets use H3.
        {:ok, fallback} =
          Gaoxy.HTTP.service_spec(
            id: :m5_phoenix_h3_fallback,
            ip: {127, 0, 0, 1},
            port: port,
            transport: :tls,
            protocols: [:http1],
            plug: {Observer, {:initialized, module, initialized}},
            tls: %{certfile: certificate, keyfile: key}
          )

        {runtime, [:m5_phoenix_h3], port, fallback}
      else
        {name, ids} =
          receive do
            {:m5_managed_runtime, name, ids} -> {name, ids}
          after
            3_000 -> raise "M5 managed Phoenix runtime identity deadline"
          end

        runtime = Process.whereis(name)
        true = is_pid(runtime)
        {:ok, {_, port}} = endpoint.server_info(:https)
        {runtime, ids, port, nil}
      end

    Receipt.emit(%{
      event: "ready",
      protocol: protocol,
      port: port,
      endpoint_server: protocol != "h3",
      policy_fallback_deferred: not is_nil(fallback),
      runtime: inspect(runtime),
      elixir: System.version(),
      otp: to_string(:erlang.system_info(:otp_release))
    })

    loop(runtime, ids, fallback)
  end

  defp loop(runtime, ids, fallback) do
    case IO.gets("") do
      :eof ->
        stop(runtime)

      line ->
        case JSON.decode!(line) do
          %{"command" => "sample"} ->
            admission =
              for id <- ids do
                Gaoxy.status(runtime, id)
                |> Map.take([:active, :retained_bytes, :cleanup_pending, :cleanup_failed])
                |> Map.put(:service, to_string(id))
              end

            Receipt.emit(%{event: "sample", admission: admission})
            loop(runtime, ids, fallback)

          %{"command" => "enable-policy-fallback"} when not is_nil(fallback) ->
            {:ok, _handle} = Gaoxy.add(runtime, fallback)

            Receipt.emit(%{
              event: "policy-fallback-ready",
              service: to_string(fallback.id),
              runtime: inspect(runtime)
            })

            loop(runtime, ids ++ [fallback.id], nil)

          %{"command" => "broadcast", "topic" => topic, "marker" => marker} ->
            :ok = PhoenixNative.Endpoint.broadcast(topic, "m5_push", %{marker: marker})
            Receipt.emit(%{event: "broadcast", topic: topic, marker: marker})
            loop(runtime, ids, fallback)

          %{"command" => "stop"} ->
            stop(runtime)
        end
    end
  end

  defp stop(runtime) do
    monitor = Process.monitor(runtime)
    :ok = Gaoxy.stop(runtime, 5_000)

    receive do
      {:DOWN, ^monitor, :process, ^runtime, _} -> :ok
    after
      1_000 -> raise "M5 browser runtime DOWN deadline"
    end

    :ok = Application.stop(:phoenix_native)
    Receipt.emit(%{event: "stopped", runtime_down: true})
  end
end

Gaoxy.M5BrowserFixture.run()
