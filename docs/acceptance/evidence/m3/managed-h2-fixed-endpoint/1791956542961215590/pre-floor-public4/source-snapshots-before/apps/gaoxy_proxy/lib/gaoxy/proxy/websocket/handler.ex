defmodule Gaoxy.Proxy.WebSocket.Handler do
  @moduledoc false
  @behaviour WebSock
  alias Gaoxy.Proxy.WebSocket.Session

  @impl true
  def init(state) do
    monitor = Process.monitor(state.session)
    Session.downstream_ready(state.session, state.token)
    {:ok, Map.put(state, :monitor, monitor)}
  end

  @impl true
  def handle_in({bytes, opcode: opcode}, state) do
    case Session.forward(state.session, opcode, bytes, state.write_timeout) do
      :ok -> {:ok, state}
      {:error, _} -> {:stop, :upstream_write_failed, 1011, state}
    end
  end

  @impl true
  def handle_info({:gaoxy_proxy_frame, session, ref, opcode, bytes}, %{session: session} = state),
    do: {:gaoxy_push, {opcode, bytes}, {session, ref}, state}

  def handle_info({:gaoxy_proxy_close, session, code, reason}, %{session: session} = state),
    do: {:stop, :normal, {code, reason}, state}

  def handle_info({:DOWN, monitor, :process, _, _}, %{monitor: monitor} = state),
    do: {:stop, :upstream_closed, 1011, state}

  def handle_info(_, state), do: {:ok, state}

  def gaoxy_close(detail, state) do
    Session.close(state.session, detail)
    {:ok, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Owner DOWN remains authoritative when termination callbacks cannot run.
    Session.cancel(state.session)
    :ok
  end
end
