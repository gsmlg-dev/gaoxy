defmodule Gaoxy.QUICCleanup do
  @moduledoc false
  use GenServer
  alias Gaoxy.{Lifecycle, QUIC, Service}

  def prepare(connection, owner, token) do
    %{
      connection: connection,
      owner: owner,
      token: token,
      owner_monitor: make_ref(),
      service_monitor: make_ref(),
      probe: &QUIC.info/1,
      active: false,
      deadline: nil,
      timer: make_ref()
    }
  end

  def start_link(state), do: GenServer.start_link(__MODULE__, state)

  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)

    {:ok,
     %{
       state
       | owner_monitor: Process.monitor(state.owner),
         service_monitor: Process.monitor(state.connection.service),
         timer: nil
     }}
  end

  @impl true
  def handle_info({:gaoxy_cleanup_activate, token}, %{token: token} = state) do
    state = %{state | active: true}
    {:noreply, schedule(state)}
  end

  def handle_info({:gaoxy_cleanup_cancel, token, _, deadline}, %{token: token} = state),
    do: {:noreply, state |> Map.put(:active, true) |> trigger(deadline)}

  def handle_info({:gaoxy_native_closed, token}, %{token: token} = state),
    do: {:noreply, trigger(state, cleanup_deadline(state))}

  def handle_info({:DOWN, monitor, :process, _, _}, %{owner_monitor: monitor} = state),
    do: {:noreply, trigger(state, cleanup_deadline(state))}

  def handle_info({:DOWN, monitor, :process, _, _}, %{service_monitor: monitor} = state),
    do: {:stop, :service_unavailable, state}

  def handle_info({:EXIT, service, _}, %{connection: %{service: service}} = state),
    do: {:noreply, trigger(state, cleanup_deadline(state))}

  def handle_info(:probe, %{active: true, deadline: deadline} = state)
      when is_integer(deadline) do
    # This supported public call may itself wait five seconds. It must run in
    # this funded observer, never in Service or Admission's critical handlers.
    result = Lifecycle.protect(fn -> state.probe.(state.connection) end)
    state = %{state | timer: nil}

    cond do
      result == {:error, :closed} ->
        case Service.complete_cleanup(state.connection.service, state.token) do
          :ok -> {:stop, :normal, state}
          _ -> {:stop, :cleanup_receipt_unconfirmed, state}
        end

      Lifecycle.remaining(state.deadline) == 0 ->
        {:stop, :native_termination_unconfirmed, state}

      true ->
        {:noreply, schedule(state)}
    end
  end

  def handle_info(_, state), do: {:noreply, state}

  defp trigger(state, deadline) do
    deadline = if state.deadline, do: min(state.deadline, deadline), else: deadline
    schedule(%{state | deadline: deadline})
  end

  defp schedule(%{active: true, deadline: deadline, timer: nil} = state)
       when is_integer(deadline),
       do: %{state | timer: Process.send_after(self(), :probe, 1)}

  defp schedule(state), do: state

  defp cleanup_deadline(state),
    do: Lifecycle.deadline(state.connection.limits.drain_timeout + Lifecycle.cleanup_headroom())
end
