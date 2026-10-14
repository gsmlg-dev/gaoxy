defmodule Gaoxy.Proxy.UDPRelay.Association do
  @moduledoc false
  use GenServer
  alias Gaoxy.{Admission, Lifecycle, Telemetry}

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def child_spec(args),
    do: %{
      id: make_ref(),
      start: {__MODULE__, :start_link, [args]},
      restart: :temporary,
      shutdown: 100
    }

  @impl true
  def init({owner, token, key, context, options}) do
    {:ok,
     %{
       owner: owner,
       token: token,
       key: key,
       context: context,
       options: options,
       owner_monitor: Process.monitor(owner),
       dispatcher_monitor: Process.monitor(context.dispatcher),
       socket: nil,
       lease: nil,
       lifetime_deadline: Lifecycle.deadline(options.limits.lifetime),
       idle: nil,
       pending: nil,
       deferred: nil,
       closing: false,
       drain_deadline: nil,
       grace: nil,
       packet_credit: 0,
       byte_credit: 0,
       rate_started: Lifecycle.now(),
       rate_packets: 0,
       rate_bytes: 0
     }, {:continue, :open}}
  end

  @impl true
  def handle_continue(:open, state) do
    {address, port} = state.options.upstream
    family = if tuple_size(address) == 4, do: :inet, else: :inet6

    with {:ok, lease} <-
           Admission.acquire(state.context.gate, state.options.reservation.worker,
             drain_notify: true
           ),
         {:ok, socket} <-
           :gen_udp.open(0, [:binary, family, active: false, recbuf: 65_536, buffer: 65_536]),
         :ok <- :gen_udp.connect(socket, address, port),
         :ok <- :inet.setopts(socket, active: :once) do
      Process.send_after(
        self(),
        {:lifetime, state.token},
        Lifecycle.remaining(state.lifetime_deadline)
      )

      send(state.owner, {:association_ready, self(), state.token})
      {:noreply, idle(%{state | socket: socket, lease: lease})}
    else
      {:error, reason} -> {:stop, {:upstream_setup, reason}, state}
    end
  end

  @impl true
  def handle_info(
        {:deliver, owner, token, operation, bytes},
        %{owner: owner, token: token} = state
      ) do
    cond do
      state.closing -> {:noreply, state}
      state.pending != nil -> {:noreply, %{state | deferred: {operation, bytes}}}
      true -> transmit_input(state, operation, bytes)
    end
  end

  def handle_info({:udp, socket, address, port, bytes}, %{socket: socket} = state) do
    cond do
      state.closing ->
        {:noreply, state}

      {address, port} != state.options.upstream ->
        {:noreply, rearm(drop(state, :upstream_source))}

      byte_size(bytes) > state.options.reservation.max_packet ->
        {:noreply, rearm(drop(state, :packet_too_large))}

      true ->
        return_datagram(state, bytes)
    end
  end

  def handle_info({:receipt, token, ref}, %{token: token, pending: %{ref: ref}} = state) do
    pending = state.pending
    remaining = Lifecycle.remaining(pending.deadline)

    if remaining == 0 do
      unknown(state, :receipt_deadline)
    else
      capability = state.context.send

      case Abyss.Dispatcher.Writer.await(capability.writer, capability, ref, min(10, remaining)) do
        {:ok, _at} = result ->
          settled(state, result)

        {:unknown, ^ref} ->
          Process.send_after(self(), {:receipt, token, ref}, 1)
          {:noreply, state}

        {:error, reason} = result when reason not in [:unknown_send, :writer_down] ->
          settled(state, result)

        {:error, reason} ->
          unknown(state, reason)
      end
    end
  end

  def handle_info({:seal, owner, token, deadline}, %{owner: owner, token: token} = state) do
    {:noreply, grace(%{state | drain_deadline: deadline})}
  end

  def handle_info({:close, owner, token}, %{owner: owner, token: token} = state), do: close(state)

  def handle_info({:idle, token, timer_token}, %{token: token, idle: {_, timer_token}} = state),
    do: close(state)

  def handle_info({:lifetime, token}, %{token: token} = state), do: close(state)

  def handle_info({:grace, token, timer_token}, %{token: token, grace: {_, timer_token}} = state),
    do: close(state)

  # Gate drain precedes the controller's ordered seal. Accepted deliveries must
  # remain valid until that seal identifies the final input packet.
  def handle_info({:gaoxy_drain, _, _, _}, state), do: {:noreply, state}

  def handle_info({:DOWN, monitor, :process, _, reason}, state)
      when monitor == state.owner_monitor or monitor == state.dispatcher_monitor,
      do: {:stop, {:owner_down, reason}, state}

  def handle_info({:udp_error, socket, reason}, %{socket: socket} = state),
    do: {:stop, {:upstream_error, reason}, state}

  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def terminate(_, state) do
    if state.socket, do: :gen_udp.close(state.socket)
    :ok
  end

  defp transmit_input(state, operation, bytes) do
    deadline = send_deadline(state)

    with true <- Lifecycle.remaining(deadline) > 0 || {:error, :deadline_exceeded},
         {:ok, send_operation} <-
           Admission.start_send(state.context.gate, state.lease, max(1, byte_size(bytes))) do
      result = :gen_udp.send(state.socket, bytes)
      Admission.finish_send(state.context.gate, state.lease, send_operation, result)

      case result do
        :ok ->
          send(state.owner, {:association_ack, self(), state.token, operation})

          state = %{
            state
            | packet_credit:
                min(
                  state.options.limits.rate_packets,
                  state.packet_credit + state.options.limits.packet_ratio
                ),
              byte_credit:
                min(
                  state.options.limits.rate_bytes,
                  state.byte_credit + max(1, byte_size(bytes)) * state.options.limits.byte_ratio
                )
          }

          {:noreply, idle(state)}

        {:error, reason} ->
          {:stop, {:upstream_send, reason}, state}
      end
    else
      {:error, reason} -> {:stop, reason, state}
    end
  end

  defp return_datagram(state, bytes) do
    state = rate_window(state)
    size = max(1, byte_size(bytes))
    limits = state.options.limits

    cond do
      state.packet_credit < 1 or state.byte_credit < size ->
        {:noreply, rearm(drop(state, :response_credit))}

      state.rate_packets >= limits.rate_packets or state.rate_bytes + size > limits.rate_bytes ->
        {:noreply, rearm(drop(state, :rate_limit))}

      Lifecycle.remaining(send_deadline(state)) < 2 ->
        close(state)

      true ->
        deadline = send_deadline(state)

        state = %{
          state
          | packet_credit: state.packet_credit - 1,
            byte_credit: state.byte_credit - size,
            rate_packets: state.rate_packets + 1,
            rate_bytes: state.rate_bytes + size
        }

        with {:ok, operation} <- Admission.start_send(state.context.gate, state.lease, size) do
          peer = {elem(state.key, 2), elem(state.key, 3)}
          # send/4 can spend one timeout reserving and another submitting. Both
          # fit in this absolute deadline; receipt polling uses what remains.
          timeout = min(25, div(Lifecycle.remaining(deadline), 2))

          case Abyss.Dispatcher.send(state.context.send, peer, bytes, timeout) do
            {:ok, ref} ->
              pending(state, ref, operation, deadline)

            {:unknown, ref} ->
              pending(state, ref, operation, deadline)

            {:error, reason} = result ->
              Admission.finish_send(state.context.gate, state.lease, operation, result)
              {:noreply, rearm(drop(state, reason))}
          end
        else
          {:error, reason} -> {:stop, reason, state}
        end
    end
  end

  defp pending(state, ref, operation, deadline) do
    send(self(), {:receipt, state.token, ref})
    {:noreply, idle(%{state | pending: %{ref: ref, operation: operation, deadline: deadline}})}
  end

  defp settled(state, result) do
    Admission.finish_send(state.context.gate, state.lease, state.pending.operation, result)
    state = %{state | pending: nil}

    cond do
      state.closing ->
        {:stop, :normal, state}

      state.deferred != nil ->
        {operation, bytes} = state.deferred
        transmit_input(rearm(%{state | deferred: nil}), operation, bytes)

      true ->
        {:noreply, rearm(state)}
    end
  end

  defp unknown(state, reason) do
    Telemetry.emit(:send, %{count: 1}, state.context.scope, %{outcome: {:unknown, reason}})
    send(state.owner, {:association_unknown, self(), state.token, reason})
    # The fixed host reservation survives this worker. Its controller fails the
    # relay closed instead of refunding an uncertain shared-writer submission.
    {:noreply, %{state | closing: true}}
  end

  defp rearm(%{closing: true} = state), do: state

  defp rearm(state) do
    :inet.setopts(state.socket, active: :once)
    state
  end

  defp close(state) do
    send(state.owner, {:association_closing, self(), state.token})

    if state.pending do
      {:noreply, %{state | closing: true}}
    else
      {:stop, :normal, %{state | closing: true}}
    end
  end

  defp idle(state) do
    if state.idle, do: Process.cancel_timer(elem(state.idle, 0))
    token = make_ref()
    timeout = min(state.options.limits.idle_timeout, Lifecycle.remaining(state.lifetime_deadline))
    timer = Process.send_after(self(), {:idle, state.token, token}, timeout)

    if state.drain_deadline,
      do: grace(%{state | idle: {timer, token}}),
      else: %{state | idle: {timer, token}}
  end

  defp grace(state) do
    if state.grace, do: Process.cancel_timer(elem(state.grace, 0))
    token = make_ref()
    timeout = min(state.options.limits.drain_grace, Lifecycle.remaining(state.drain_deadline))
    timer = Process.send_after(self(), {:grace, state.token, token}, timeout)
    %{state | grace: {timer, token}}
  end

  defp send_deadline(state) do
    deadline = min(Lifecycle.deadline(state.options.limits.send_timeout), state.lifetime_deadline)
    if state.drain_deadline, do: min(deadline, state.drain_deadline), else: deadline
  end

  defp rate_window(state) do
    if Lifecycle.now() - state.rate_started >= 1000,
      do: %{state | rate_started: Lifecycle.now(), rate_packets: 0, rate_bytes: 0},
      else: state
  end

  defp drop(state, reason) do
    Telemetry.emit(:admission_rejected, %{count: 1}, state.context.scope, %{
      reason: reason,
      source: :udp_return
    })

    state
  end
end
