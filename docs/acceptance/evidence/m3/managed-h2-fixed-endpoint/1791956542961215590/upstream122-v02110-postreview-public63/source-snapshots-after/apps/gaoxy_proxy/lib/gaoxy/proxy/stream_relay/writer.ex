defmodule Gaoxy.Proxy.StreamRelay.Writer do
  @moduledoc false
  use GenServer, restart: :temporary
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.Proxy.StreamRelay.Upstream
  alias ThousandIsland.Socket

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  @impl true
  def init(args) do
    with {:ok, lease} <- Admission.acquire(args.gate, args.reserve, drain_notify: true),
         :ok <- Admission.begin_callback(args.gate, lease, args.reserve, args.deadline) do
      Process.link(args.owner)
      {:ok, Map.merge(args, %{lease: lease, owner_monitor: Process.monitor(args.owner)})}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_info(
        {:relay_write, capability, token, bytes, deadline},
        %{capability: capability} = state
      )
      when is_binary(bytes) and byte_size(bytes) <= state.max_chunk do
    result =
      with true <- Lifecycle.remaining(deadline) > 0 || {:error, :timeout},
           :ok <- Admission.begin_callback(state.gate, state.lease, state.reserve, deadline),
           {:ok, operation} <- Admission.start_send(state.gate, state.lease, byte_size(bytes)) do
        timeout = min(state.write_timeout, Lifecycle.remaining(deadline))
        result = send_bytes(state.target, bytes, timeout)
        :ok = Admission.finish_send(state.gate, state.lease, operation, result)
        :ok = Admission.retain(state.gate, state.lease, state.reserve)
        result
      end

    send(state.owner, {:relay_written, self(), capability, token, result})
    if result == :ok, do: {:noreply, state}, else: {:stop, :normal, state}
  end

  def handle_info({:gaoxy_drain, _, _, deadline}, state),
    do: {:noreply, %{state | deadline: min(state.deadline, deadline)}}

  def handle_info({:DOWN, ref, :process, _, _}, %{owner_monitor: ref} = state),
    do: {:stop, :normal, state}

  def handle_info(:stop, state), do: {:stop, :normal, state}
  def handle_info(_, state), do: {:noreply, state}

  defp send_bytes({:downstream, socket}, bytes, timeout) do
    with :ok <- Socket.setopts(socket, send_timeout: timeout, send_timeout_close: false),
         do: Socket.send(socket, bytes)
  end

  defp send_bytes({:upstream, socket}, bytes, timeout), do: Upstream.send(socket, bytes, timeout)
end
