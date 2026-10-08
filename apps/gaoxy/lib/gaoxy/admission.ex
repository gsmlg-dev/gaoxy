defmodule Gaoxy.Admission do
  @moduledoc false
  use GenServer
  alias Gaoxy.Telemetry

  def start_link({limits, scope}), do: GenServer.start_link(__MODULE__, {limits, scope})
  def acquire(gate, bytes), do: GenServer.call(gate, {:acquire, bytes})
  def begin(gate, lease, bytes), do: GenServer.call(gate, {:begin, lease, bytes})
  def retain(gate, lease, bytes), do: GenServer.call(gate, {:retain, lease, bytes})
  def update(gate, lease, bytes), do: GenServer.call(gate, {:update, lease, bytes})
  def adjust_bytes(gate, lease, delta), do: GenServer.call(gate, {:adjust_bytes, lease, delta})
  def start_send(gate, lease, bytes), do: GenServer.call(gate, {:start_send, lease, bytes})

  def finish_send(gate, lease, operation, result),
    do: GenServer.call(gate, {:finish_send, lease, operation, result})

  def mode(gate, mode), do: GenServer.call(gate, {:mode, mode})
  def status(gate), do: GenServer.call(gate, :status)

  @impl true
  def init({limits, scope}),
    do:
      {:ok,
       %{
         limits: limits,
         scope: scope,
         mode: :ready,
         leases: %{},
         bytes: 0,
         high_water: 0,
         rejected: 0
       }}

  @impl true
  def handle_call({:acquire, bytes}, {pid, _}, state) do
    cond do
      state.mode != :ready ->
        reject(state, state.mode)

      map_size(state.leases) >= state.limits.max_active ->
        reject(state, :active_limit)

      not is_integer(bytes) or bytes < 0 or state.bytes + bytes > state.limits.max_bytes ->
        reject(state, :byte_limit)

      true ->
        ref = make_ref()
        monitor = Process.monitor(pid)
        lease = %{pid: pid, monitor: monitor, bytes: bytes, token: nil, timer: nil, send: nil}
        state = %{state | leases: Map.put(state.leases, ref, lease), bytes: state.bytes + bytes}
        {:reply, {:ok, ref}, sample(state)}
    end
  end

  def handle_call({action, ref, bytes}, {pid, _}, state)
      when action in [:begin, :retain, :update] do
    case state.leases[ref] do
      %{pid: ^pid} = lease ->
        new_bytes = state.bytes - lease.bytes + bytes

        if is_integer(bytes) and bytes >= 0 and new_bytes <= state.limits.max_bytes do
          lease =
            case action do
              :begin ->
                cancel(lease)
                token = make_ref()

                timer =
                  Process.send_after(
                    self(),
                    {:expired, ref, token},
                    state.limits.callback_timeout
                  )

                %{lease | timer: timer, token: token, bytes: bytes}

              :retain ->
                cancel(lease)
                %{lease | timer: nil, token: nil, bytes: bytes}

              :update ->
                %{lease | bytes: bytes}
            end

          {:reply, :ok,
           sample(%{state | bytes: new_bytes, leases: Map.put(state.leases, ref, lease)})}
        else
          reject(state, :byte_limit)
        end

      _ ->
        {:reply, {:error, :stale_generation}, state}
    end
  end

  def handle_call({:mode, mode}, _from, state), do: {:reply, :ok, %{state | mode: mode}}

  def handle_call(:force, _from, state) do
    leases =
      Map.new(state.leases, fn {ref, lease} ->
        send_outcome(state, lease.send, {:unknown, :forced_cleanup})
        Process.exit(lease.pid, :kill)
        {ref, %{lease | send: nil}}
      end)

    {:reply, :ok, %{state | mode: :draining, leases: leases}}
  end

  def handle_call({:adjust_bytes, ref, delta}, {pid, _}, state) when is_integer(delta) do
    case state.leases[ref] do
      %{pid: ^pid} = lease ->
        if lease.bytes + delta >= 0 and state.bytes + delta <= state.limits.max_bytes do
          {:reply, :ok,
           sample(%{
             state
             | bytes: state.bytes + delta,
               leases: Map.put(state.leases, ref, %{lease | bytes: lease.bytes + delta})
           })}
        else
          reject(state, :byte_limit)
        end

      _ ->
        {:reply, {:error, :stale_generation}, state}
    end
  end

  def handle_call({:start_send, ref, bytes}, {pid, _}, state) do
    case state.leases[ref] do
      %{pid: ^pid, send: nil} = lease when is_integer(bytes) and bytes >= 0 ->
        operation = make_ref()
        pending = %{operation: operation, bytes: bytes}
        Telemetry.emit(:send_started, %{bytes: bytes}, state.scope, %{operation: operation})

        {:reply, {:ok, operation},
         %{state | leases: Map.put(state.leases, ref, %{lease | send: pending})}}

      _ ->
        {:reply, {:error, :stale_or_pending_send}, state}
    end
  end

  def handle_call({:finish_send, ref, operation, result}, {pid, _}, state) do
    case state.leases[ref] do
      %{pid: ^pid, send: %{operation: ^operation} = pending} = lease ->
        outcome =
          case result do
            {:error, :timeout} -> {:unknown, :timeout}
            {:error, {:timeout, _remaining}} -> {:unknown, :timeout}
            other -> other
          end

        send_outcome(state, pending, outcome)
        {:reply, :ok, %{state | leases: Map.put(state.leases, ref, %{lease | send: nil})}}

      _ ->
        {:reply, {:error, :stale_operation}, state}
    end
  end

  def handle_call(:status, _from, state) do
    {:reply,
     %{
       active: map_size(state.leases),
       retained_bytes: state.bytes,
       retained_high_water: state.high_water,
       rejected: state.rejected,
       queued_items: 0,
       queued_bytes: 0
     }, state}
  end

  @impl true
  def handle_info({:expired, ref, token}, state) do
    case state.leases[ref] do
      %{token: ^token, pid: pid} = lease ->
        Telemetry.emit(:timeout, %{count: 1}, state.scope, %{reason: :callback_or_send_timeout})
        send_outcome(state, lease.send, {:unknown, :watchdog_timeout})
        Process.exit(pid, :kill)
        {:noreply, %{state | leases: Map.put(state.leases, ref, %{lease | send: nil})}}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, monitor, :process, _pid, _reason}, state) do
    case Enum.find(state.leases, fn {_, lease} -> lease.monitor == monitor end) do
      {ref, lease} ->
        cancel(lease)
        send_outcome(state, lease.send, {:unknown, :owner_exit})

        {:noreply,
         sample(%{
           state
           | leases: Map.delete(state.leases, ref),
             bytes: state.bytes - lease.bytes
         })}

      nil ->
        {:noreply, state}
    end
  end

  def handle_info(_, state), do: {:noreply, state}
  @impl true
  def terminate(_, state),
    do:
      Enum.each(state.leases, fn {_, lease} ->
        send_outcome(state, lease.send, {:unknown, :forced_cleanup})
        Process.exit(lease.pid, :kill)
      end)

  defp send_outcome(_, nil, _), do: :ok

  defp send_outcome(state, pending, outcome),
    do:
      Telemetry.emit(:send, %{bytes: pending.bytes}, state.scope, %{
        operation: pending.operation,
        outcome: outcome
      })

  defp cancel(%{timer: nil}), do: :ok
  defp cancel(%{timer: timer}), do: Process.cancel_timer(timer)

  defp reject(state, reason) do
    Telemetry.emit(:admission_rejected, %{count: 1}, state.scope, %{reason: reason})
    {:reply, {:error, reason}, %{state | rejected: state.rejected + 1}}
  end

  defp sample(state) do
    Telemetry.emit(
      :work,
      %{active: map_size(state.leases), retained_bytes: state.bytes},
      state.scope
    )

    %{state | high_water: max(state.high_water, state.bytes)}
  end
end
