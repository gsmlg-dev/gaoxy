defmodule Gaoxy.Proxy.UDPRelay.Controller do
  @moduledoc false
  use GenServer
  alias Gaoxy.{Admission, Lifecycle, Telemetry}
  alias Gaoxy.Proxy.UDPRelay.{Association, Options}

  def start_link(context, options), do: GenServer.start_link(__MODULE__, {context, options})
  @impl true
  def init({context, options}) do
    Process.flag(:trap_exit, true)
    # Service explicitly owns this root. The dispatcher can be killed by a
    # normal host stop after associations drain, so its monitor (rather than a
    # parent link) decides whether that shutdown is expected.
    Process.unlink(context.dispatcher)

    with {:ok, lease} <- Admission.acquire(context.gate, options.reservation.infrastructure),
         {:ok, supervisor} <-
           DynamicSupervisor.start_link(strategy: :one_for_one, max_restarts: 0) do
      {:ok,
       %{
         context: context,
         options: options,
         lease: lease,
         supervisor: supervisor,
         dispatcher_monitor: Process.monitor(context.dispatcher),
         gate_monitor: Process.monitor(context.gate),
         mode: :ready,
         associations: %{},
         permits: %{},
         bytes: 0,
         items: 0,
         drain: nil,
         rejected: 0
       }}
    end
  end

  @impl true
  def handle_call(:offer_context, {producer, _}, %{context: %{dispatcher: producer}} = state),
    do:
      {:reply,
       {:ok, state.options, Map.take(state.context, [:generation, :writer_generation]),
        state.context.spec.dispatcher.handoff_timeout}, state}

  def handle_call(:offer_context, _, state), do: {:reply, {:error, :unauthorized_producer}, state}

  def handle_call(:status, _, state) do
    {:reply,
     %{
       mode: state.mode,
       associations: Map.new(state.associations, fn {key, value} -> {key, value.pid} end),
       reserved_items: state.items,
       reserved_bytes: state.bytes,
       permits: map_size(state.permits),
       rejected: state.rejected
     }, state}
  end

  def handle_call({:control, action, generation}, _, state) do
    cond do
      generation != state.context.generation -> {:reply, {:error, :stale_generation}, state}
      state.mode not in [:ready, :paused] -> {:reply, {:error, state.mode}, state}
      action == :pause -> {:reply, :ok, %{state | mode: :paused}}
      action == :resume -> {:reply, :ok, %{state | mode: :ready}}
      true -> {:reply, {:error, :invalid_control}, state}
    end
  end

  def handle_call(
        {:reserve, operation, key, bytes, generation, writer_generation, deadline},
        {producer, _},
        state
      ) do
    existing = state.associations[key]

    cond do
      not is_integer(deadline) or Lifecycle.remaining(deadline) == 0 ->
        reject(state, :handoff_timeout)

      producer != state.context.dispatcher ->
        reject(state, :unauthorized_producer)

      state.mode != :ready ->
        reject(state, state.mode)

      generation != state.context.generation or
          writer_generation != state.context.writer_generation ->
        reject(state, :stale_generation)

      not valid_key?(key, generation, writer_generation, state.options) ->
        reject(state, :source_denied)

      not is_reference(operation) or Map.has_key?(state.permits, operation) ->
        reject(state, :invalid_operation)

      not is_integer(bytes) or bytes not in 1..state.options.reservation.max_packet ->
        reject(state, :packet_too_large)

      existing != nil and existing.closing ->
        reject(state, :association_closing)

      existing != nil and
          (existing.items >= state.options.limits.queue_items or
             existing.bytes + bytes > state.options.limits.queue_bytes) ->
        reject(state, :queue_limit)

      existing == nil and
          map_size(state.associations) >= state.options.reservation.max_associations ->
        reject(state, :association_limit)

      true ->
        with :ok <- Admission.adjust_bytes(state.context.gate, state.lease, bytes),
             {:ok, association, state} <- admitted_association(state, key, bytes) do
          permit = make_ref()

          timer =
            Process.send_after(
              self(),
              {:permit_expired, operation, permit},
              state.options.limits.reservation_timeout
            )

          record = %{
            permit: permit,
            key: key,
            bytes: bytes,
            producer: producer,
            timer: timer,
            expires_at:
              min(deadline, Lifecycle.deadline(state.options.limits.reservation_timeout))
          }

          association = %{
            association
            | items: association.items + 1,
              bytes: association.bytes + bytes
          }

          state = %{
            state
            | permits: Map.put(state.permits, operation, record),
              associations: Map.put(state.associations, key, association),
              bytes: state.bytes + bytes,
              items: state.items + 1
          }

          {:reply, {:ok, permit, association.pid}, state}
        else
          {:error, reason} -> reject(state, reason)
        end
    end
  end

  def handle_call({:submit, operation, permit, packet}, {producer, _}, state) do
    case state.permits[operation] do
      %{permit: ^permit, producer: ^producer} = record ->
        key =
          {packet.generation, packet.writer_generation, elem(packet.peer, 0),
           elem(packet.peer, 1)}

        if key == record.key and max(1, byte_size(packet.data)) == record.bytes and
             Lifecycle.remaining(record.expires_at) > 0 and state.mode in [:ready, :paused] do
          Process.cancel_timer(record.timer)
          association = state.associations[key]
          queue = :queue.in({operation, packet.data, record.bytes}, association.queue)

          state = %{
            state
            | permits: Map.delete(state.permits, operation),
              associations: Map.put(state.associations, key, %{association | queue: queue})
          }

          {:reply, {:ok, association.pid}, dispatch(state, key)}
        else
          {:reply, {:error, :invalid_permit}, cancel(state, operation)}
        end

      _ ->
        {:reply, {:error, :invalid_permit}, state}
    end
  end

  def handle_call({:drain, _}, _, %{mode: mode} = state) when mode in [:failed, :drained],
    do: {:reply, if(mode == :drained, do: :ok, else: {:error, :failed}), state}

  def handle_call({:drain, deadline}, from, %{drain: nil} = state) do
    state = Enum.reduce(Map.keys(state.permits), %{state | mode: :draining}, &cancel(&2, &1))
    timer = Process.send_after(self(), {:drain_deadline, deadline}, Lifecycle.remaining(deadline))
    state = %{state | drain: %{from: from, deadline: deadline, timer: timer}}
    state = Enum.reduce(Map.keys(state.associations), state, &dispatch(&2, &1))
    {:noreply, drained(state)}
  end

  def handle_call({:drain, _}, _, state), do: {:reply, {:error, :already_draining}, state}

  @impl true
  def handle_info({:association_ready, pid, token}, state) do
    case find(state, pid, token) do
      nil ->
        {:noreply, state}

      {key, association} ->
        {:noreply, dispatch(put_in(state.associations[key], %{association | ready: true}), key)}
    end
  end

  def handle_info({:association_ack, pid, token, operation}, state) do
    case find(state, pid, token) do
      {key, %{busy: {^operation, bytes, timer}}} ->
        Process.cancel_timer(timer)
        state = refund(state, key, bytes)
        state = put_in(state.associations[key], %{state.associations[key] | busy: nil})
        {:noreply, dispatch(state, key)}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:association_closing, pid, token}, state) do
    case find(state, pid, token) do
      nil ->
        {:noreply, state}

      {key, association} ->
        state = put_in(state.associations[key], %{association | closing: true})
        {:noreply, Enum.reduce(permit_operations(state, key), state, &cancel(&2, &1))}
    end
  end

  def handle_info({:cancel, producer, operation}, state) do
    case state.permits[operation] do
      %{producer: ^producer} -> {:noreply, cancel(state, operation)}
      _ -> {:noreply, state}
    end
  end

  def handle_info({:permit_expired, operation, permit}, state) do
    case state.permits[operation] do
      %{permit: ^permit} -> {:noreply, cancel(state, operation)}
      _ -> {:noreply, state}
    end
  end

  def handle_info({:handoff_deadline, pid, token, operation}, state) do
    case find(state, pid, token) do
      {key, %{busy: {^operation, _, _}} = association} ->
        Telemetry.emit(:send, %{count: 1}, state.context.scope, %{
          outcome: {:unknown, :upstream_watchdog}
        })

        Process.exit(pid, :kill)
        {:noreply, put_in(state.associations[key], %{association | closing: true})}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:drain_deadline, deadline}, %{drain: %{deadline: deadline}} = state) do
    send(
      state.context.service,
      {:gaoxy_dispatcher_failed, self(), state.context.generation, :udp_drain_deadline}
    )

    GenServer.reply(state.drain.from, {:error, :deadline_exceeded})
    {:noreply, %{state | mode: :failed, drain: nil}}
  end

  def handle_info(
        {:DOWN, monitor, :process, _pid, reason},
        %{dispatcher_monitor: monitor} = state
      ) do
    if state.mode == :drained do
      {:noreply, state}
    else
      fail(state, {:dispatcher_down, reason})
    end
  end

  def handle_info({:DOWN, monitor, :process, _, reason}, %{gate_monitor: monitor} = state),
    do: fail(state, {:admission_down, reason})

  def handle_info({:DOWN, monitor, :process, pid, _reason}, state) do
    case Enum.find(state.associations, fn {_, association} ->
           association.monitor == monitor and association.pid == pid
         end) do
      nil ->
        {:noreply, state}

      {key, association} ->
        if association.busy, do: Process.cancel_timer(elem(association.busy, 2))
        state = Enum.reduce(permit_operations(state, key), state, &cancel(&2, &1))
        association = state.associations[key]
        :ok = Admission.adjust_bytes(state.context.gate, state.lease, -association.bytes)

        state = %{
          state
          | associations: Map.delete(state.associations, key),
            bytes: state.bytes - association.bytes,
            items: state.items - association.items
        }

        {:noreply, drained(state)}
    end
  end

  def handle_info({:association_unknown, pid, token, reason}, state) do
    if find(state, pid, token), do: fail(state, {:unknown_send, reason}), else: {:noreply, state}
  end

  def handle_info({:EXIT, supervisor, reason}, %{supervisor: supervisor} = state),
    do: fail(state, {:worker_supervisor_down, reason})

  def handle_info({:gaoxy_dispatcher_terminated, _, _}, state), do: {:noreply, state}
  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def terminate(_, state) do
    if Process.alive?(state.supervisor), do: Process.exit(state.supervisor, :shutdown)
    :ok
  end

  defp valid_key?({generation, writer, ip, port}, generation, writer, options),
    do: is_integer(port) and port in 1..65_535 and Options.source?(options, ip) == true

  defp valid_key?(_, _, _, _), do: false

  defp reject(state, reason),
    do: {:reply, {:error, reason}, %{state | rejected: state.rejected + 1}}

  defp admitted_association(state, key, bytes) do
    case association(state, key) do
      {:ok, _, _} = result ->
        result

      {:error, _} = error ->
        Admission.adjust_bytes(state.context.gate, state.lease, -bytes)
        error
    end
  end

  defp association(state, key) do
    case state.associations[key] do
      nil ->
        token = make_ref()

        case DynamicSupervisor.start_child(
               state.supervisor,
               {Association, {self(), token, key, state.context, state.options}}
             ) do
          {:ok, pid} ->
            association = %{
              pid: pid,
              token: token,
              monitor: Process.monitor(pid),
              ready: false,
              closing: false,
              sealed: false,
              queue: :queue.new(),
              items: 0,
              bytes: 0,
              busy: nil
            }

            {:ok, association,
             %{state | associations: Map.put(state.associations, key, association)}}

          {:error, reason} ->
            {:error, {:association_start, reason}}
        end

      association ->
        {:ok, association, state}
    end
  end

  defp find(state, pid, token),
    do:
      Enum.find(state.associations, fn {_, value} -> value.pid == pid and value.token == token end)

  defp permit_operations(state, key),
    do: for({operation, %{key: ^key}} <- state.permits, do: operation)

  defp cancel(state, operation) do
    case Map.pop(state.permits, operation) do
      {nil, _} ->
        state

      {record, permits} ->
        Process.cancel_timer(record.timer)
        state = refund(%{state | permits: permits}, record.key, record.bytes)
        association = state.associations[record.key]

        if association.items == 0 and association.busy == nil and
             :queue.is_empty(association.queue) and state.mode != :draining do
          send(association.pid, {:close, self(), association.token})
          put_in(state.associations[record.key], %{association | closing: true})
        else
          state
        end
    end
  end

  defp refund(state, key, bytes) do
    :ok = Admission.adjust_bytes(state.context.gate, state.lease, -bytes)
    association = state.associations[key]

    %{
      state
      | bytes: state.bytes - bytes,
        items: state.items - 1,
        associations:
          Map.put(state.associations, key, %{
            association
            | bytes: association.bytes - bytes,
              items: association.items - 1
          })
    }
  end

  defp dispatch(state, key) do
    association = state.associations[key]

    cond do
      not association.ready or association.busy != nil or association.closing ->
        state

      not :queue.is_empty(association.queue) ->
        {{:value, {operation, data, bytes}}, queue} = :queue.out(association.queue)
        send(association.pid, {:deliver, self(), association.token, operation, data})

        timer =
          Process.send_after(
            self(),
            {:handoff_deadline, association.pid, association.token, operation},
            state.options.limits.send_timeout + state.options.limits.reservation_timeout
          )

        put_in(state.associations[key], %{
          association
          | busy: {operation, bytes, timer},
            queue: queue
        })

      state.mode == :draining and not association.sealed ->
        send(association.pid, {:seal, self(), association.token, state.drain.deadline})
        put_in(state.associations[key], %{association | sealed: true})

      true ->
        state
    end
  end

  defp drained(%{mode: :draining, associations: associations, drain: drain} = state)
       when map_size(associations) == 0 do
    Process.cancel_timer(drain.timer)
    GenServer.reply(drain.from, :ok)
    %{state | mode: :drained, drain: nil}
  end

  defp drained(state), do: state

  defp fail(%{mode: :failed} = state, _reason), do: {:noreply, state}

  defp fail(state, reason) do
    send(
      state.context.service,
      {:gaoxy_dispatcher_failed, self(), state.context.generation, reason}
    )

    if state.drain do
      Process.cancel_timer(state.drain.timer)
      GenServer.reply(state.drain.from, {:error, reason})
    end

    associations =
      Map.new(state.associations, fn {key, association} ->
        send(association.pid, {:close, self(), association.token})
        {key, %{association | closing: true}}
      end)

    state = %{state | mode: :failed, drain: nil, associations: associations}
    state = Enum.reduce(Map.keys(state.permits), state, &cancel(&2, &1))
    # Keep the fixed host lease until Service confirms or forces host teardown.
    {:noreply, state}
  end
end
