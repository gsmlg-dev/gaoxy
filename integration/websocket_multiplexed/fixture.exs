defmodule Gaoxy.M5Fixture.Receipt do
  def emit(value), do: IO.puts("GAOXY_M5_FIXTURE " <> JSON.encode!(value))

  def identity(exchange) do
    {owner, stream} =
      case exchange.transport_state do
        {owner, stream, _token} -> {owner, stream}
        {owner, _operations, key, _token} -> {owner, key.handle.id}
      end

    %{
      connection: inspect(owner),
      stream: stream,
      method: exchange.request.method,
      version: to_string(exchange.request.version),
      protocol: exchange.request.protocol,
      path: exchange.request.path,
      query: exchange.request.query_string
    }
  end
end

defmodule Gaoxy.M5Fixture.Transport do
  alias Gaoxy.M5Fixture.Receipt

  def websocket_open(exchange, headers, deadline) do
    case native(exchange).websocket_open(exchange, headers, deadline) do
      {:ok, next} = result ->
        Receipt.emit(
          Map.merge(Receipt.identity(exchange), %{
            event: "websocket-open",
            original_deadline: Process.get(:m5_original_deadline),
            requested_websocket_deadline: deadline,
            accepted_websocket_deadline: next.deadline,
            observed_at: Gaoxy.Lifecycle.now()
          })
        )

        result

      error ->
        error
    end
  end

  def websocket_demand(exchange, credit, ref),
    do: native(exchange).websocket_demand(exchange, credit, ref)

  def websocket_send(exchange, bytes), do: native(exchange).websocket_send(exchange, bytes)
  def websocket_finish(exchange), do: native(exchange).websocket_finish(exchange)
  def abort(exchange, reason), do: native(exchange).abort(exchange, reason)

  defp native(%{transport_state: {_, _, _, _}}), do: Gaoxy.HTTP.HTTP3.Transport
  defp native(_), do: Gaoxy.HTTP.HTTP2.Transport
end

defmodule Gaoxy.M5Fixture.Echo do
  @behaviour WebSock
  alias Gaoxy.M5Fixture.Receipt

  def init(state) do
    send(self(), :announce)
    {:ok, state}
  end

  def handle_in({bytes, opcode: opcode}, state) do
    if bytes == "after-deadline" do
      Receipt.emit(%{
        event: "post-deadline-message",
        stream: state.stream,
        original_deadline: state.original_deadline,
        observed_at: Gaoxy.Lifecycle.now()
      })
    end

    {:push, {opcode, state.label <> ":" <> bytes}, state}
  end

  def handle_info(:announce, state), do: {:push, {:text, "push:" <> state.label}, state}
  def handle_info(_, state), do: {:ok, state}

  def terminate(reason, state),
    do:
      Receipt.emit(%{event: "websocket-terminated", label: state.label, reason: inspect(reason)})
end

defmodule Gaoxy.M5Fixture.Endpoint do
  @behaviour Gaoxy.HTTP.Endpoint
  alias Gaoxy.HTTP.{Response, WebSocket}
  alias Gaoxy.M5Fixture.{Echo, Receipt, Transport}

  def init(options), do: {:ok, options}

  def call(exchange, _) do
    if exchange.request.path == "/websocket" do
      %{"label" => label} = URI.decode_query(exchange.request.query_string)
      true = label in ["one", "two"]
      Process.put(:m5_original_deadline, exchange.deadline)

      Receipt.emit(
        Map.merge(Receipt.identity(exchange), %{
          event: "request",
          original_deadline: exchange.deadline
        })
      )

      with {:ok, next} <-
             WebSocket.prepare(%{exchange | transport: Transport}, {
               Echo,
               %{
                 label: label,
                 stream: Receipt.identity(exchange).stream,
                 original_deadline: exchange.deadline
               },
               [timeout: 10_000, max_lifetime: 10_000, close_timeout: 500]
             }) do
        {:ok, WebSocket.response_headers(next, [{"sec-websocket-protocol", "m5.echo"}])}
      else
        {:error, reason} -> {:error, reason, exchange}
      end
    else
      Receipt.emit(Map.put(Receipt.identity(exchange), :event, "http-request"))
      Response.send_resp(exchange, 200, [], exchange.request.path)
    end
  end
end

defmodule Gaoxy.M5Fixture do
  alias Gaoxy.M5Fixture.{Endpoint, Receipt}

  def run do
    protocol = System.fetch_env!("GAOXY_M5_PROTOCOL")

    options = [
      ip: {127, 0, 0, 1},
      port: 0,
      endpoint: {Endpoint, []},
      extended_connect: true,
      http_limits: %{request_timeout: 1_000}
    ]

    options =
      case protocol do
        "h2" ->
          options ++
            [
              transport: :tls,
              tls: %{
                certfile: System.fetch_env!("GAOXY_M5_CERT"),
                keyfile: System.fetch_env!("GAOXY_M5_KEY")
              }
            ]

        "h2c" ->
          options ++ [protocols: [:http2], h2c: :prior_knowledge]

        "h3" ->
          options ++
            [
              tls: %{
                certfile: System.fetch_env!("GAOXY_M5_CERT"),
                keyfile: System.fetch_env!("GAOXY_M5_KEY")
              }
            ]
      end

    {starter, id} = if protocol == "h3", do: {Gaoxy.HTTP.HTTP3, :http3}, else: {Gaoxy.HTTP, :http}
    {:ok, runtime} = starter.start_link(options)
    {:ok, {{127, 0, 0, 1}, port}} = Gaoxy.info(runtime, id).local

    Receipt.emit(%{
      event: "ready",
      protocol: protocol,
      port: port,
      elixir: System.version(),
      otp: to_string(:erlang.system_info(:otp_release)),
      request_timeout_ms: 1_000,
      websocket_lifetime_ms: 10_000
    })

    loop(runtime, id)
  end

  defp loop(runtime, id) do
    case IO.gets("") do
      "sample\n" ->
        Receipt.emit(
          Map.put(
            Map.take(Gaoxy.status(runtime, id), [
              :active,
              :retained_bytes,
              :cleanup_pending,
              :cleanup_failed
            ]),
            :event,
            "sample"
          )
        )

        loop(runtime, id)

      value when value in ["stop\n", :eof] ->
        monitor = Process.monitor(runtime)
        :ok = Gaoxy.stop(runtime, 5_000)

        receive do
          {:DOWN, ^monitor, :process, ^runtime, _} -> :ok
        after
          5_000 -> raise "M5 fixture runtime DOWN deadline"
        end

        Receipt.emit(%{event: "stopped", runtime_down: true})
    end
  end
end

Gaoxy.M5Fixture.run()
