defmodule WebSocketCloseProbe.Echo do
  def init(state), do: {:ok, state}
  def handle_in({data, [opcode: opcode]}, state), do: {:push, {opcode, data}, state}
  def handle_info(_, state), do: {:ok, state}
end

defmodule WebSocketCloseProbe.Plug do
  def init(options), do: options

  def call(conn, _options) do
    WebSockAdapter.upgrade(conn, WebSocketCloseProbe.Echo, nil, [])
  end
end

{:ok, server} = Gaoxy.HTTP.start_link(plug: {WebSocketCloseProbe.Plug, []})
{:ok, {_ip, port}} = Gaoxy.info(server, :http).local

results =
  for code <- [1000, 1001, 1008, 1011] do
    %HTTP.WebSocket{pid: pid} =
      socket =
      HTTP.WebSocket.new("ws://127.0.0.1:#{port}/", [],
        http_version: :http1,
        delivery: :ack,
        opening_timeout: 2_000,
        idle_timeout: 2_000,
        write_timeout: 2_000,
        close_timeout: 1_000
      )

    monitor = Process.monitor(pid)

    receive do
      {HTTP.WebSocket, ^socket, %HTTP.WebSocket.Event.Open{}} -> :ok
    after
      3_000 -> raise "WebSocket did not open"
    end

    # TODO(upstream): gsmlg-dev/http_fetch#38 - preserve valid proxy close codes.
    result = HTTP.WebSocket.close(socket, code, "probe")
    IO.puts(JSON.encode!(%{code: code, expected: ":ok", actual: inspect(result)}))
    if result != :ok, do: :ok = HTTP.WebSocket.close(socket, 1000, "cleanup")

    receive do
      {HTTP.WebSocket, ^socket, %HTTP.WebSocket.Event.Close{}} -> :ok
    after
      3_000 -> raise "WebSocket did not close"
    end

    receive do
      {:DOWN, ^monitor, :process, ^pid, _reason} -> :ok
    after
      3_000 -> raise "WebSocket owner did not stop"
    end

    result == :ok
  end

:ok = Gaoxy.stop(server, 2_000)
if not Enum.all?(results), do: System.halt(1)
