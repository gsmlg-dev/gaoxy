defmodule Gaoxy.Admission do
  @moduledoc false
  use GenServer
  alias Gaoxy.{Lifecycle, Telemetry}
  alias Gaoxy.Admission.WorkerBootstrap

  def start_link({limits, scope}), do: GenServer.start_link(__MODULE__, {limits, scope})
  def acquire(gate, bytes), do: acquire(gate, bytes, [])
  def acquire(gate, bytes, options), do: GenServer.call(gate, {:acquire, bytes, options})

  def spawn_request(gate, parent_lease, token, bytes, deadline, mfa),
    do:
      :gen_server.send_request(gate, {:spawn_request, parent_lease, token, bytes, deadline, mfa})

  def cancel_spawn(gate, parent_lease, token),
    do: :gen_server.send_request(gate, {:cancel_spawn, parent_lease, token})

  def begin_request(gate, lease, bytes, deadline),
    do: GenServer.call(gate, {:begin_request, lease, bytes, deadline})

  def begin_callback(gate, lease, bytes, deadline),
    do: GenServer.call(gate, {:begin_callback, lease, bytes, deadline})

  def upgrade(gate, lease, bytes, deadline),
    do: GenServer.call(gate, {:upgrade, lease, bytes, deadline})

  def begin_stream(gate, lease, bytes, deadline, timeout),
    do: GenServer.call(gate, {:begin_stream, lease, bytes, deadline}, timeout)

  def request_deadline(gate, lease, timeout) when is_integer(timeout) and timeout in 1..50,
    do: GenServer.call(gate, {:request_deadline, lease}, timeout)

  def drain(gate, deadline), do: GenServer.call(gate, {:drain, deadline})
  def begin(gate, lease, bytes), do: GenServer.call(gate, {:begin, lease, bytes})
  def retain(gate, lease, bytes), do: GenServer.call(gate, {:retain, lease, bytes})
  def update(gate, lease, bytes), do: GenServer.call(gate, {:update, lease, bytes})

  def update(gate, lease, bytes, timeout) when is_integer(timeout) and timeout > 0,
    do: GenServer.call(gate, {:update, lease, bytes}, timeout)

  def adjust_bytes(gate, lease, delta), do: GenServer.call(gate, {:adjust_bytes, lease, delta})
  def start_send(gate, lease, bytes), do: GenServer.call(gate, {:start_send, lease, bytes})

  # Read-triggered informational output needs a caller-known operation token:
  # a late reply must never leave an operation whose token the caller lost.
  def start_send_until(gate, lease, bytes, operation, deadline) do
    case Lifecycle.remaining(deadline) do
      0 ->
        {:error, :timeout}

      remaining ->
        GenServer.call(gate, {:start_send_until, lease, bytes, operation, deadline}, remaining)
    end
  catch
    :exit, {:timeout, _} ->
      _ = finish_send_async(gate, lease, operation, {:error, :not_submitted})
      {:error, :timeout}

    :exit, _ ->
      {:error, :closed}
  end

  def finish_send_async(gate, lease, operation, result) do
    request = :gen_server.send_request(gate, {:finish_send, lease, operation, result})
    _ = :gen_server.receive_response(request, 0)
    :ok
  catch
    :exit, _ -> {:error, :closed}
  end

  def finish_send(gate, lease, operation, result),
    do: GenServer.call(gate, {:finish_send, lease, operation, result})

  def mode(gate, mode), do: GenServer.call(gate, {:mode, mode})
  def status(gate), do: GenServer.call(gate, :status)

  def attach_cleanup(gate, owner, lease, guardian, bytes, deadline, token),
    do:
      GenServer.call(
        gate,
        {:attach_cleanup, owner, lease, guardian, bytes, deadline, token},
        min(50, Gaoxy.Lifecycle.remaining(deadline))
      )

  def complete_cleanup(gate, token), do: GenServer.call(gate, {:complete_cleanup, token}, 50)

  @impl true
  def init({limits, scope}) do
    Process.flag(:trap_exit, true)

    {:ok,
     %{
       limits: limits,
       scope: Map.delete(scope, :service_pid),
       service: Map.get(scope, :service_pid),
       mode: :ready,
       drain_deadline: nil,
       leases: %{},
       cleanups: %{},
       spawns: %{},
       bytes: 0,
       high_water: 0,
       rejected: 0
     }}
  end

  @impl true
  def handle_call(
        {:spawn_request, parent_lease, token, bytes, deadline, mfa},
        {owner, _} = from,
        state
      ) do
    cond do
      not parent_owned?(state, parent_lease, owner) ->
        {:reply, {:error, :stale_generation}, state}

      not is_reference(token) or Map.has_key?(state.spawns, token) or not scalar_mfa?(mfa) ->
        reject(state, :invalid_spawn_request)

      state.mode != :ready ->
        reject(state, spawn_mode(state.mode))

      not is_integer(deadline) or deadline <= Lifecycle.now() ->
        reject(state, :deadline_exceeded)

      map_size(state.leases) >= state.limits.max_active ->
        reject(state, :active_limit)

      not is_integer(bytes) or bytes < 0 or state.bytes + bytes > state.limits.max_bytes ->
        reject(state, :byte_limit)

      true ->
        # This callback cannot interleave another admission. Commit this exact
        # reserved byte/slot transition before the separate activation callback.
        reserved = %{bytes: state.bytes + bytes, active: map_size(state.leases) + 1}
        activation = make_ref()
        ref = make_ref()
        watchdog = make_ref()
        gate = self()

        spawned =
          try do
            :erlang.spawn_opt(WorkerBootstrap, :run, [gate, owner, activation, deadline, mfa], [
              :link,
              :monitor
            ])
          catch
            _, _ -> :error
          end

        case spawned do
          {worker, monitor} ->
            lease = %{
              pid: worker,
              monitor: monitor,
              bytes: bytes,
              token: watchdog,
              timer: nil,
              send: nil,
              drain_notify: true,
              request_active: true,
              cleanup: nil,
              deadline: deadline
            }

            operation = %{
              owner: owner,
              parent_lease: parent_lease,
              worker: worker,
              lease: ref,
              activation: activation,
              from: from,
              deadline: deadline,
              phase: :pending_activation,
              exit_seen: false,
              down_seen: false
            }

            state = %{
              state
              | bytes: reserved.bytes,
                leases: Map.put(state.leases, ref, lease),
                spawns: Map.put(state.spawns, token, operation)
            }

            case spawn_timer(ref, watchdog, deadline) do
              {:ok, timer} ->
                state = put_in(state.leases[ref].timer, timer)
                send(self(), {:activate_spawn, token})
                {:noreply, sample(state)}

              :error ->
                # A PID already exists: retain its ordinary lease through its
                # real terminal pair even if arming the watchdog fails.
                {:noreply, sample(cancel_operation(state, token, :worker_capacity))}
            end

          :error ->
            reject(state, :worker_capacity)
        end
    end
  end

  def handle_call({:cancel_spawn, parent_lease, token}, {owner, _}, state) do
    case state.spawns[token] do
      %{owner: ^owner, parent_lease: ^parent_lease} ->
        if parent_owned?(state, parent_lease, owner),
          do: {:reply, :ok, cancel_operation(state, token, :cancelled)},
          else: {:reply, {:error, :stale_generation}, state}

      _ ->
        {:reply, {:error, :stale_generation}, state}
    end
  end

  def handle_call({:acquire, bytes, options}, {pid, _}, state) do
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

        lease = %{
          pid: pid,
          monitor: monitor,
          bytes: bytes,
          token: nil,
          timer: nil,
          send: nil,
          drain_notify: Keyword.get(options, :drain_notify, false),
          request_active: false,
          cleanup: nil,
          deadline: nil
        }

        state = %{state | leases: Map.put(state.leases, ref, lease), bytes: state.bytes + bytes}
        {:reply, {:ok, ref}, sample(state)}
    end
  end

  def handle_call({action, ref, bytes, deadline}, {pid, _}, state)
      when action in [:begin_request, :begin_callback, :upgrade, :begin_stream] do
    case state.leases[ref] do
      %{pid: ^pid} = lease ->
        deadline =
          if action == :begin_callback and lease.deadline != nil and is_integer(deadline),
            do: min(deadline, lease.deadline),
            else: deadline

        cond do
          action in [:upgrade, :begin_stream] and
              (not lease.request_active or not lease.drain_notify) ->
            reject(state, :inactive_request)

          action in [:upgrade, :begin_stream] and lease.deadline <= Gaoxy.Lifecycle.now() ->
            reject(state, :deadline_exceeded)

          action == :begin_request and lease.cleanup != nil ->
            reject(state, :cleanup_pending)

          action in [:begin_request, :upgrade, :begin_stream] and state.mode != :ready ->
            reject(state, state.mode)

          action == :begin_callback and lease.deadline == nil and state.mode != :ready ->
            reject(state, state.mode)

          not is_integer(bytes) or bytes < 0 or
              state.bytes - lease.bytes + bytes > state.limits.max_bytes ->
            reject(state, :byte_limit)

          not (action == :begin_stream and deadline == :infinity) and
              (not is_integer(deadline) or deadline <= Gaoxy.Lifecycle.now()) ->
            reject(state, :deadline_exceeded)

          true ->
            cancel(lease)
            token = if deadline == :infinity, do: nil, else: make_ref()

            timer =
              if deadline != :infinity do
                Process.send_after(
                  self(),
                  {:expired, ref, token},
                  Gaoxy.Lifecycle.remaining(deadline)
                )
              end

            request_deadline =
              if action in [:begin_request, :upgrade, :begin_stream] or lease.deadline == nil,
                do: deadline,
                else: lease.deadline

            lease = %{
              lease
              | bytes: bytes,
                deadline: request_deadline,
                request_active: action == :begin_request or lease.request_active,
                token: token,
                timer: timer
            }

            {:reply, :ok,
             sample(%{
               state
               | bytes: state.bytes - state.leases[ref].bytes + bytes,
                 leases: Map.put(state.leases, ref, lease)
             })}
        end

      _ ->
        {:reply, {:error, :stale_generation}, state}
    end
  end

  def handle_call(
        {:attach_cleanup, owner, ref, guardian, bytes, deadline, token},
        {service, _},
        %{service: service} = state
      )
      when is_pid(service) do
    case state.leases[ref] do
      %{pid: ^owner} = lease ->
        cond do
          state.mode != :ready ->
            reject(state, state.mode)

          not lease.request_active or not lease.drain_notify ->
            reject(state, :inactive_request)

          lease.cleanup != nil ->
            reject(state, :cleanup_attached)

          not is_integer(deadline) or deadline != lease.deadline or
              deadline <= Gaoxy.Lifecycle.now() ->
            reject(state, :deadline_exceeded)

          not is_pid(guardian) or guardian == owner or not is_reference(token) or
              not Process.alive?(guardian) ->
            reject(state, :invalid_guardian)

          not is_integer(bytes) or bytes < 0 or state.bytes + bytes > state.limits.max_bytes ->
            reject(state, :byte_limit)

          true ->
            cleanup = %{
              monitor: Process.monitor(guardian),
              bytes: bytes,
              lease: ref,
              receipt: false
            }

            {:reply, :ok,
             sample(%{
               state
               | cleanups: Map.put(state.cleanups, token, cleanup),
                 leases: Map.put(state.leases, ref, %{lease | cleanup: token}),
                 bytes: state.bytes + bytes
             })}
        end

      _ ->
        {:reply, {:error, :stale_generation}, state}
    end
  end

  def handle_call({:attach_cleanup, _, _, _, _, _, _}, _, state),
    do: {:reply, {:error, :unauthorized_service}, state}

  def handle_call({:complete_cleanup, token}, {service, _}, %{service: service} = state)
      when is_pid(service) do
    case state.cleanups[token] do
      nil -> {:reply, {:error, :stale_cleanup}, state}
      cleanup -> {:reply, :ok, put_in(state.cleanups[token], %{cleanup | receipt: true})}
    end
  end

  def handle_call({:complete_cleanup, _}, _, state),
    do: {:reply, {:error, :unauthorized_service}, state}

  def handle_call({:drain, deadline}, _from, %{drain_deadline: nil} = state) do
    Enum.each(state.leases, fn {ref, lease} ->
      if lease.drain_notify, do: send(lease.pid, {:gaoxy_drain, self(), ref, deadline})
    end)

    {:reply, :ok, %{state | mode: :draining, drain_deadline: deadline}}
  end

  def handle_call({:drain, _deadline}, _from, state), do: {:reply, :ok, state}

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

  def handle_call({:mode, _mode}, _from, %{drain_deadline: deadline} = state)
      when not is_nil(deadline),
      do: {:reply, :ok, state}

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

  def handle_call({:start_send_until, ref, bytes, operation, deadline}, {pid, _}, state)
      when is_reference(operation) and is_integer(deadline) do
    case state.leases[ref] do
      %{pid: ^pid, send: nil} = lease when is_integer(bytes) and bytes >= 0 ->
        if Lifecycle.remaining(deadline) == 0 do
          {:reply, {:error, :timeout}, state}
        else
          pending = %{operation: operation, bytes: bytes}
          Telemetry.emit(:send_started, %{bytes: bytes}, state.scope, %{operation: operation})
          {:reply, :ok, %{state | leases: Map.put(state.leases, ref, %{lease | send: pending})}}
        end

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

  def handle_call({:request_deadline, ref}, {owner, _}, state) do
    result =
      case state.leases[ref] do
        %{pid: ^owner, request_active: true, deadline: deadline} -> {:ok, deadline}
        _ -> {:error, :stale_lease}
      end

    {:reply, result, state}
  end

  def handle_call(:status, _from, state) do
    {:reply,
     %{
       active: map_size(state.leases),
       cleanup_pending: map_size(state.cleanups),
       retained_bytes: state.bytes,
       retained_high_water: state.high_water,
       rejected: state.rejected,
       queued_items: 0,
       queued_bytes: 0
     }, state}
  end

  @impl true
  def handle_info({:activate_spawn, token}, state) do
    case state.spawns[token] do
      %{phase: :pending_activation} = operation ->
        reason =
          cond do
            not parent_owned?(state, operation.parent_lease, operation.owner) ->
              :stale_generation

            state.mode != :ready ->
              spawn_mode(state.mode)

            operation.deadline <= Lifecycle.now() ->
              :deadline_exceeded

            operation.down_seen or operation.exit_seen or not Process.alive?(operation.worker) ->
              :worker_capacity

            true ->
              nil
          end

        if reason do
          {:noreply, cancel_operation(state, token, reason)}
        else
          send(
            operation.worker,
            {:gaoxy_admitted_worker_activate, operation.activation, operation.lease}
          )

          GenServer.reply(operation.from, {:ok, operation.worker, operation.lease})
          running = %{operation | phase: :running, from: nil, activation: nil}
          {:noreply, put_in(state.spawns[token], running)}
        end

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:EXIT, pid, reason}, state) do
    case Enum.find(state.spawns, fn {_, operation} -> operation.worker == pid end) do
      {token, operation} ->
        state = put_in(state.spawns[token], %{operation | exit_seen: true})
        {:noreply, settle_spawn(state, token)}

      nil when reason == :normal ->
        {:noreply, state}

      nil ->
        {:stop, reason, state}
    end
  end

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

  def handle_info({:DOWN, monitor, :process, pid, reason}, state) do
    case Enum.find(state.leases, fn {_, lease} ->
           lease.monitor == monitor and lease.pid == pid
         end) do
      {ref, lease} ->
        cancel(lease)
        send_outcome(state, lease.send, {:unknown, :owner_exit})

        state = kill_owned_children(state, ref, lease.pid)

        case Enum.find(state.spawns, fn {_, operation} -> operation.lease == ref end) do
          {token, operation} ->
            state = put_in(state.leases[ref], %{lease | timer: nil, send: nil})
            state = put_in(state.spawns[token], %{operation | down_seen: true})
            {:noreply, settle_spawn(state, token)}

          nil ->
            {:noreply,
             sample(%{
               state
               | leases: Map.delete(state.leases, ref),
                 bytes: state.bytes - lease.bytes
             })}
        end

      nil ->
        case Enum.find(state.cleanups, fn {_, cleanup} -> cleanup.monitor == monitor end) do
          {token, cleanup} ->
            leases =
              case state.leases[cleanup.lease] do
                nil -> state.leases
                lease -> Map.put(state.leases, cleanup.lease, %{lease | cleanup: nil})
              end

            {:noreply,
             sample(%{
               state
               | cleanups: Map.delete(state.cleanups, token),
                 leases: leases,
                 mode: if(cleanup.receipt and reason == :normal, do: state.mode, else: :failed),
                 bytes: state.bytes - cleanup.bytes
             })}

          nil ->
            {:noreply, state}
        end
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

  defp parent_owned?(state, ref, owner) do
    case state.leases[ref] do
      %{pid: ^owner} -> node(owner) == node() and Process.alive?(owner)
      _ -> false
    end
  end

  defp scalar_mfa?({module, function, args}) when is_atom(module) and is_atom(function),
    do: scalar_args?(args)

  defp scalar_mfa?(_), do: false
  defp scalar_args?([]), do: true

  defp scalar_args?([arg | rest])
       when is_atom(arg) or is_integer(arg) or is_pid(arg) or is_reference(arg),
       do: scalar_args?(rest)

  defp scalar_args?(_), do: false

  defp spawn_mode(mode) when mode in [:paused, :draining, :failed], do: mode
  defp spawn_mode(_), do: :invalid_spawn_request

  defp spawn_timer(ref, token, deadline) do
    try do
      {:ok, Process.send_after(self(), {:expired, ref, token}, Lifecycle.remaining(deadline))}
    catch
      _, _ -> :error
    end
  end

  defp cancel_operation(state, token, reason) do
    operation = state.spawns[token]
    Process.exit(operation.worker, :kill)
    if operation.from, do: GenServer.reply(operation.from, {:error, reason})
    put_in(state.spawns[token], %{operation | from: nil, activation: nil, phase: :cancelled})
  end

  defp kill_owned_children(state, parent_lease, owner) do
    Enum.reduce(state.spawns, state, fn
      {token, %{parent_lease: ^parent_lease, owner: ^owner}}, state ->
        cancel_operation(state, token, :stale_generation)

      _, state ->
        state
    end)
  end

  defp settle_spawn(state, token) do
    operation = state.spawns[token]

    if operation.down_seen and operation.exit_seen do
      if operation.from, do: GenServer.reply(operation.from, {:error, :worker_capacity})
      lease = state.leases[operation.lease]

      sample(%{
        state
        | spawns: Map.delete(state.spawns, token),
          leases: Map.delete(state.leases, operation.lease),
          bytes: state.bytes - lease.bytes
      })
    else
      state
    end
  end

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
