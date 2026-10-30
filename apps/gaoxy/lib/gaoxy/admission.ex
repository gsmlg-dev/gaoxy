defmodule Gaoxy.Admission do
  @moduledoc false
  use GenServer
  alias Gaoxy.{Lifecycle, Telemetry}
  alias Gaoxy.Admission.{Accounting, Budget, WorkerBootstrap}

  def start_link({limits, scope}), do: GenServer.start_link(__MODULE__, {limits, scope})
  def acquire(gate, bytes), do: acquire(gate, bytes, [])
  def acquire(gate, bytes, options), do: GenServer.call(gate, {:acquire, bytes, options})

  def spawn_request(gate, parent_lease, token, bytes, deadline, mfa),
    do: spawn_request(gate, parent_lease, token, bytes, deadline, mfa, [])

  def spawn_request(gate, parent_lease, token, bytes, deadline, mfa, metadata),
    do:
      :gen_server.send_request(
        gate,
        {:spawn_request, parent_lease, token, bytes, deadline, mfa, metadata}
      )

  # The original response alias scopes this optional proof to this attempt.
  # Only expiry before any reservation can return :not_reserved. Ordinary
  # errors (including activation expiry) never prove absent resource ownership.
  def spawn_request(gate, parent_lease, token, bytes, deadline, mfa, metadata, :phase_receipt),
    do:
      :gen_server.send_request(
        gate,
        {:spawn_request, parent_lease, token, bytes, deadline, mfa, metadata, :phase_receipt}
      )

  def update_until(gate, lease, accounting, operation, deadline),
    do: GenServer.call(gate, {:update_until, lease, accounting, operation, deadline}, 50)

  # Explicitly reuse an admitted completion envelope. Omitted fields retain
  # their existing values; memberships/process credits cannot change here.
  # Ordinary scalar updates keep their historical replacement semantics.
  def repartition_until(gate, lease, accounting, operation, deadline),
    do: GenServer.call(gate, {:repartition_until, lease, accounting, operation, deadline}, 50)

  def end_request(gate, lease, accounting, deadline),
    do: GenServer.call(gate, {:end_request, lease, accounting, deadline}, 50)

  def end_stream(gate, parent_lease, kind, stream_id, deadline),
    do: GenServer.call(gate, {:end_stream, parent_lease, kind, stream_id, deadline}, 50)

  # Records the exact parent's output/buffer terminal proof. This does not refund
  # a live worker: its DOWN/EXIT pair and the canonical mutation must also finish.
  def finish_stream_resources(gate, parent_lease, worker_lease, operation, deadline),
    do:
      GenServer.call(
        gate,
        {:finish_stream_resources, parent_lease, worker_lease, operation, deadline},
        50
      )

  # The caller's single-use spawn token remains addressable when its asynchronous
  # success alias was abandoned. The index lives only as long as the stream lease;
  # terminal retries use the same bounded receipt cache as other local operations.
  # Cancellation alone is never an output, native-resource or guardian receipt.
  def finish_spawn_resources(gate, parent_lease, spawn_token, operation, deadline),
    do: finish_stream_resources(gate, parent_lease, {:spawn, spawn_token}, operation, deadline)

  def budget_client(gate), do: GenServer.call(gate, :budget_client, 50)

  def cancel_spawn(gate, parent_lease, token),
    do: :gen_server.send_request(gate, {:cancel_spawn, parent_lease, token})

  def begin_request(gate, lease, bytes, deadline),
    do: GenServer.call(gate, {:begin_request, lease, bytes, deadline})

  def begin_callback(gate, lease, bytes, deadline),
    do: GenServer.call(gate, {:begin_callback, lease, bytes, deadline})

  def begin_native_cleanup(gate, lease, bytes, deadline),
    do: GenServer.call(gate, {:begin_native_cleanup, lease, bytes, deadline}, 100)

  # Transfer the returned state/output into retained ownership before sending.
  # The callback watchdog cannot also own a progressing output batch.
  def end_websocket_callback(gate, lease, accounting),
    do: GenServer.call(gate, {:end_websocket_callback, lease, accounting})

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

  def reserve_native(gate, owner, lease, token, native, overhead, deadline),
    do:
      GenServer.call(
        gate,
        {:reserve_native, owner, lease, token, native, overhead, deadline},
        100
      )

  def split_native(gate, token, guardian, deadline),
    do: GenServer.call(gate, {:split_native, token, guardian, deadline}, 100)

  def update_native(gate, lease, native, deadline),
    do: GenServer.call(gate, {:update_native, lease, native, deadline}, 100)

  @impl true
  def init({limits, scope}) do
    Process.flag(:trap_exit, true)

    with {:ok, budget} <- Budget.register(Map.get(scope, :budget)) do
      {:ok,
       %{
         budget: budget,
         limits: limits,
         scope: Map.drop(scope, [:service_pid, :budget]),
         service: Map.get(scope, :service_pid),
         mode: :ready,
         drain_deadline: nil,
         leases: %{},
         cleanups: %{},
         spawns: %{},
         stream_spawns: %{},
         update_receipts: %{},
         update_order: :queue.new(),
         update_pending: nil,
         bytes: 0,
         high_water: 0,
         temporary_high_water: 0,
         usage_high_water: 0,
         transport_high_water: 0,
         websocket_high_water: 0,
         rejected: 0
       }}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call(
        {:spawn_request, parent_lease, token, bytes, deadline, mfa, metadata},
        from,
        state
      ),
      do:
        handle_call(
          {:spawn_request, parent_lease, token, bytes, deadline, mfa, metadata, :legacy},
          from,
          state
        )

  def handle_call(
        {:spawn_request, parent_lease, token, bytes, deadline, mfa, metadata, reply_mode},
        {owner, _} = from,
        state
      )
      when reply_mode in [:legacy, :phase_receipt] do
    cond do
      not parent_owned?(state, parent_lease, owner) ->
        {:reply, {:error, :stale_generation}, state}

      not is_reference(token) or Map.has_key?(state.spawns, token) or
        Map.has_key?(state.stream_spawns, token) or
        Map.has_key?(state.update_receipts, {:cancel_spawn, token}) or not scalar_mfa?(mfa) ->
        reject(state, :invalid_spawn_request)

      state.mode != :ready ->
        reject(state, spawn_mode(state.mode))

      reply_mode == :phase_receipt and
          (state.update_pending != nil or
             match?(%{pending: pending} when not is_nil(pending), state.budget)) ->
        reject(state, :budget_pending)

      not is_integer(deadline) or deadline <= Lifecycle.now() ->
        {:reply, error, state} = reject(state, :deadline_exceeded)

        if reply_mode == :phase_receipt and is_integer(deadline),
          do: {:reply, {:error, {:not_reserved, token, :deadline_exceeded}}, state},
          else: {:reply, error, state}

      true ->
        ref = make_ref()

        case reserve_lease(state, ref, self(), bytes, metadata, deadline, 1) do
          {:error, reason, state} ->
            reject(state, reason)

          {:ok, state} ->
            activation = make_ref()
            gate = self()

            spawned =
              try do
                :erlang.spawn_opt(
                  WorkerBootstrap,
                  :run,
                  [gate, owner, activation, deadline, mfa],
                  [:link, :monitor]
                )
              catch
                _, _ -> :error
              end

            case spawned do
              {worker, monitor} ->
                watchdog = make_ref()

                lease =
                  Map.merge(state.leases[ref], %{
                    pid: worker,
                    monitor: monitor,
                    token: watchdog,
                    drain_notify: true,
                    request_active: true,
                    deadline: deadline
                  })

                lease =
                  if lease.kind in [:h2_stream, :h3_stream],
                    do:
                      Map.merge(lease, %{
                        spawn_token: token,
                        stream_parent: {parent_lease, owner},
                        stream_resources_terminal: false
                      }),
                    else: lease

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
                  | leases: Map.put(state.leases, ref, lease),
                    spawns: Map.put(state.spawns, token, operation),
                    stream_spawns:
                      if(Map.has_key?(lease, :spawn_token),
                        do: Map.put(state.stream_spawns, token, ref),
                        else: state.stream_spawns
                      )
                }

                case spawn_timer(ref, watchdog, deadline) do
                  {:ok, timer} ->
                    state = put_in(state.leases[ref].timer, timer)
                    args = if state.budget, do: Budget.arguments(lease, worker), else: []

                    commit = fn state, receipt, _late ->
                      lease = Budget.receipt(state.leases[ref], receipt)

                      lease = %{
                        lease
                        | budget_owner: worker,
                          accounting: %{lease.accounting | pending_processes: 0}
                      }

                      send(self(), {:activate_spawn, token})
                      put_in(state.leases[ref], lease)
                    end

                    case Budget.run(state, :activate, args, deadline, commit) do
                      {:ok, state} ->
                        {:noreply, sample(state)}

                      {:error, reason, state} ->
                        {:noreply, sample(cancel_operation(state, token, reason))}
                    end

                  :error ->
                    {:noreply, sample(cancel_operation(state, token, :worker_capacity))}
                end

              :error ->
                case release_lease(state, ref) do
                  {:ok, state} -> reject(state, :worker_capacity)
                  {:error, reason, state} -> reject(state, reason)
                end
            end
        end
    end
  end

  def handle_call({:cancel_spawn, parent_lease, token}, {owner, _}, state) do
    fingerprint = cancel_fingerprint(parent_lease, owner, token)
    cached = state.update_receipts[{:cancel_spawn, token}]

    cond do
      not parent_owned?(state, parent_lease, owner) ->
        {:reply, {:error, :stale_generation}, state}

      cached && cached.fingerprint != fingerprint ->
        {:reply, {:error, :stale_generation}, state}

      cached ->
        {:reply, cached.result, state}

      true ->
        case state.spawns[token] do
          %{owner: ^owner, parent_lease: ^parent_lease} ->
            state = cancel_operation(state, token, :cancelled)
            {:reply, :ok, remember_cancel(state, parent_lease, owner, token)}

          _ ->
            case state.leases[state.stream_spawns[token]] do
              %{stream_parent: {^parent_lease, ^owner}} ->
                {:reply, :ok, remember_cancel(state, parent_lease, owner, token)}

              _ ->
                {:reply, {:error, :stale_generation}, state}
            end
        end
    end
  end

  def handle_call({:acquire, bytes, options}, {pid, _}, state) do
    ref = make_ref()

    case reserve_lease(
           state,
           ref,
           pid,
           bytes,
           options,
           if(Keyword.keyword?(options), do: Keyword.get(options, :deadline)),
           0
         ) do
      {:ok, state} -> {:reply, {:ok, ref}, sample(state)}
      {:error, reason, state} -> reject(state, reason)
    end
  end

  def handle_call(:budget_client, {service, _}, %{service: service} = state),
    do: {:reply, if(state.budget, do: {:ok, state.budget.client}, else: {:ok, nil}), state}

  def handle_call({:end_request, ref, bytes, deadline}, {pid, _}, state) do
    case state.leases[ref] do
      %{pid: ^pid} = lease ->
        with {:ok, replacement} <- replace_accounting(state, lease, bytes) do
          replacement = request_membership(replacement, :end_request, ref)

          commit_lease(state, ref, replacement, deadline, fn lease ->
            cancel(lease)
            %{lease | timer: nil, token: nil, deadline: nil, request_active: false}
          end)
        else
          {:error, reason} -> reject(state, reason)
        end

      _ ->
        {:reply, {:error, :stale_generation}, state}
    end
  end

  def handle_call({action, ref, bytes, operation, deadline}, {pid, _}, state)
      when action in [:update_until, :repartition_until] do
    fingerprint = :crypto.hash(:sha256, :erlang.term_to_binary({action, pid, ref, bytes}))
    cached = state.update_receipts[operation]

    cond do
      not is_reference(operation) ->
        reject(state, :invalid_operation)

      cached && cached.fingerprint != fingerprint ->
        reject(state, :operation_conflict)

      cached ->
        {:reply, cached.result, state}

      state.update_pending == {operation, fingerprint} ->
        {:reply, {:error, :budget_pending}, state}

      state.update_pending != nil and elem(state.update_pending, 0) == operation ->
        reject(state, :operation_conflict)

      not is_integer(deadline) or Lifecycle.remaining(deadline) == 0 ->
        reject(state, :deadline_exceeded)

      true ->
        case state.leases[ref] do
          %{pid: ^pid} = lease ->
            result =
              if action == :repartition_until,
                do: repartition_accounting(state, lease, bytes),
                else: replace_accounting(state, lease, bytes)

            case result do
              {:ok, replacement} ->
                commit_lease(
                  state,
                  ref,
                  replacement,
                  deadline,
                  &Function.identity/1,
                  {operation, fingerprint},
                  if(action == :repartition_until, do: :repartition, else: :replace)
                )

              {:error, reason} ->
                reject(state, reason)
            end

          _ ->
            {:reply, {:error, :stale_generation}, state}
        end
    end
  end

  def handle_call({:end_stream, parent, kind, id, deadline}, {pid, _}, state) do
    if parent_owned?(state, parent, pid) and kind in [:h2_stream, :h3_stream] do
      case Enum.find(state.leases, fn {_, lease} ->
             lease.accounting.memberships[kind] == {parent, id}
           end) do
        {ref, lease} ->
          accounting = %{
            lease.accounting
            | memberships: Map.delete(lease.accounting.memberships, kind)
          }

          {:ok, replacement} = Accounting.replace(lease, accounting)

          if lease.kind == :stream_retention and not stream_membership?(accounting) and
               (lease.bytes == 0 or Map.get(lease, :stream_resources_terminal, false)) do
            release_reply(state, ref, deadline)
          else
            commit_lease(state, ref, replacement, deadline)
          end

        nil ->
          {:reply, :ok, state}
      end
    else
      {:reply, {:error, :stale_generation}, state}
    end
  end

  def handle_call(
        {:finish_stream_resources, parent, ref, operation, deadline},
        {pid, _},
        state
      ) do
    fingerprint =
      :crypto.hash(:sha256, :erlang.term_to_binary({pid, :finish_stream_resources, parent, ref}))

    cached = state.update_receipts[operation]

    cond do
      not is_reference(operation) ->
        reject(state, :invalid_operation)

      cached && cached.fingerprint != fingerprint ->
        reject(state, :operation_conflict)

      state.update_pending != nil and elem(state.update_pending, 0) == operation ->
        reject(state, :operation_conflict)

      not parent_owned?(state, parent, pid) ->
        reject(state, :stale_generation)

      cached ->
        {:reply, cached.result, state}

      not is_integer(deadline) or Lifecycle.remaining(deadline) == 0 ->
        reject(state, :deadline_exceeded)

      true ->
        ref = stream_lease(state, ref)

        case state.leases[ref] do
          %{stream_parent: {^parent, ^pid}} = lease ->
            state = put_in(state.leases[ref], %{lease | stream_resources_terminal: true})
            state = remember_update(state, {operation, fingerprint}, :ok)
            send(self(), :budget_retry_terminals)
            {:reply, :ok, state}

          _ ->
            reject(state, :stale_generation)
        end
    end
  end

  def handle_call({action, ref, bytes, deadline}, {pid, _}, state)
      when action in [
             :begin_request,
             :begin_callback,
             :begin_native_cleanup,
             :upgrade,
             :begin_stream
           ] do
    case state.leases[ref] do
      %{pid: ^pid} = lease ->
        deadline =
          if action == :begin_callback and lease.deadline != nil and is_integer(deadline),
            do: Lifecycle.earlier(deadline, lease.deadline),
            else: deadline

        replacement = replace_accounting(state, lease, bytes, action == :upgrade)

        cond do
          action == :begin_native_cleanup and
              (not Map.get(lease, :native_connection, false) or
                 not is_integer(bytes) or bytes > lease.bytes) ->
            reject(state, :invalid_native_cleanup)

          action == :begin_native_cleanup and state.mode not in [:ready, :draining] ->
            reject(state, state.mode)

          action in [:upgrade, :begin_stream] and
              (not lease.request_active or not lease.drain_notify) ->
            reject(state, :inactive_request)

          action in [:upgrade, :begin_stream] and Lifecycle.remaining(lease.deadline) == 0 ->
            reject(state, :deadline_exceeded)

          action == :begin_request and lease.cleanup != nil ->
            reject(state, :cleanup_pending)

          action in [:begin_request, :upgrade, :begin_stream] and state.mode != :ready ->
            reject(state, state.mode)

          action == :begin_callback and lease.deadline == nil and state.mode != :ready ->
            reject(state, state.mode)

          not match?({:ok, _}, replacement) ->
            reject(state, :byte_limit)

          not (action in [:begin_request, :upgrade, :begin_stream] and deadline == :infinity) and
              (not is_integer(deadline) or deadline <= Gaoxy.Lifecycle.now()) ->
            reject(state, :deadline_exceeded)

          true ->
            {:ok, replacement} = replacement
            replacement = request_membership(replacement, action, ref)

            commit_lease(state, ref, replacement, deadline, fn replacement ->
              cancel(lease)
              token = if deadline == :infinity, do: nil, else: make_ref()

              timer =
                if deadline != :infinity,
                  do:
                    Process.send_after(
                      self(),
                      {:expired, ref, token},
                      Lifecycle.remaining(deadline)
                    )

              request_deadline =
                if action in [:begin_request, :upgrade, :begin_stream] or lease.deadline == nil,
                  do: deadline,
                  else: lease.deadline

              %{
                replacement
                | deadline: request_deadline,
                  request_active: action == :begin_request or lease.request_active,
                  token: token,
                  timer: timer
              }
            end)
        end

      _ ->
        {:reply, {:error, :stale_generation}, state}
    end
  end

  def handle_call(
        {:reserve_native, owner, ref, token, native, overhead, deadline},
        {service, _},
        %{service: service} = state
      )
      when is_pid(service) do
    with true <-
           (is_pid(owner) and is_reference(ref) and is_reference(token) and
              not Map.has_key?(state.cleanups, token)) || {:error, :invalid_native_reservation},
         true <-
           (is_integer(native) and native >= 0 and is_integer(overhead) and overhead > 0) ||
             {:error, :byte_limit},
         {:ok, accounting} <-
           Gaoxy.ResourceBudget.normalize_accounting(%{
             retained_bytes: native + overhead,
             temporary_bytes: 0,
             transport_bytes: native + overhead,
             websocket_bytes: 0,
             memberships: %{connection: token},
             pending_processes: 1
           }),
         :ok <- local_reserve_check(state, accounting) do
      commit = fn state, receipt, _late ->
        cleanup = %{
          pid: service,
          monitor: nil,
          bytes: native + overhead,
          native_bytes: native,
          overhead: overhead,
          native_owner: owner,
          native_phase: :pending,
          lease: ref,
          receipt: false,
          accounting: accounting,
          budget_owner: service,
          down_seen: false,
          down_reason: nil
        }

        cleanup = Budget.receipt(cleanup, receipt)
        send(service, {:gaoxy_native_reserved, token, receipt})

        sample(%{
          state
          | cleanups: Map.put(state.cleanups, token, cleanup),
            bytes: state.bytes + cleanup.bytes
        })
      end

      rejected = fn state, reason ->
        send(service, {:gaoxy_native_rejected, token, reason})
        state
      end

      reply_mutation(
        Budget.run(state, :reserve_native, [service, accounting], deadline, commit, rejected)
      )
    else
      {:error, reason} -> reject(state, reason)
    end
  end

  def handle_call({:reserve_native, _, _, _, _, _, _}, _, state),
    do: {:reply, {:error, :unauthorized_service}, state}

  def handle_call(
        {:split_native, token, guardian, deadline},
        {service, _},
        %{service: service} = state
      )
      when is_pid(service) do
    case state.cleanups[token] do
      %{native_phase: :pending} = cleanup when is_pid(guardian) ->
        if guardian != cleanup.native_owner and Process.alive?(guardian) do
          # Bind the terminal observer before the canonical split. If the split
          # fails or its receipt is delayed, the Service-pinned reservation is
          # still releasable only by this guardian's exact terminal handshake.
          cleanup = %{
            cleanup
            | pid: guardian,
              monitor: Process.monitor(guardian),
              native_phase: :splitting
          }

          state = put_in(state.cleanups[token], cleanup)

          args =
            if state.budget,
              do: [
                cleanup.budget_receipt.token,
                cleanup.budget_receipt.revision,
                guardian,
                cleanup.native_owner
              ],
              else: []

          commit = fn state, receipts, _late ->
            cleanup = state.cleanups[token]
            owner = cleanup.native_owner
            if state.budget, do: Process.link(owner)
            {:ok, empty} = Gaoxy.ResourceBudget.normalize_accounting(0)

            lease = %{
              pid: owner,
              monitor: Process.monitor(owner),
              bytes: 0,
              token: nil,
              timer: nil,
              send: nil,
              drain_notify: false,
              request_active: false,
              cleanup: token,
              deadline: nil,
              accounting: empty,
              kind: :transport,
              native_connection: true,
              budget_owner: owner,
              down_seen: false,
              exit_seen: false
            }

            lease = Budget.receipt(lease, receipts && receipts.callback)

            cleanup = %{
              cleanup
              | native_phase: :active,
                budget_owner: guardian,
                accounting: %{cleanup.accounting | pending_processes: 0}
            }

            cleanup = Budget.receipt(cleanup, receipts && receipts.native)

            send(
              service,
              {:gaoxy_native_activated, token, cleanup.lease, receipts && receipts.native}
            )

            sample(%{
              state
              | cleanups: Map.put(state.cleanups, token, cleanup),
                leases: Map.put(state.leases, cleanup.lease, lease)
            })
          end

          rejected = fn state, reason ->
            send(service, {:gaoxy_native_split_failed, token, reason})
            state
          end

          reply_mutation(Budget.run(state, :split_native, args, deadline, commit, rejected))
        else
          reject(state, :invalid_guardian)
        end

      _ ->
        reject(state, :stale_cleanup)
    end
  end

  def handle_call({:split_native, _, _, _}, _, state),
    do: {:reply, {:error, :unauthorized_service}, state}

  def handle_call({:update_native, ref, native, deadline}, {owner, _}, state) do
    with %{pid: ^owner, cleanup: token} <- state.leases[ref],
         %{native_phase: :active} = cleanup <- state.cleanups[token],
         true <- (is_integer(native) and native >= 0) || {:error, :byte_limit},
         {:ok, replacement} <- replace_accounting(state, cleanup, native + cleanup.overhead) do
      args = if state.budget, do: Budget.arguments(cleanup, replacement.accounting), else: []

      commit = fn state, receipt, _ ->
        current = state.cleanups[token]

        replacement =
          current
          |> Map.merge(Map.take(replacement, [:bytes, :accounting]))
          |> Map.put(:native_bytes, native)
          |> Budget.receipt(receipt)

        sample(%{
          state
          | cleanups: Map.put(state.cleanups, token, replacement),
            bytes: state.bytes - current.bytes + replacement.bytes
        })
      end

      reply_mutation(Budget.run(state, :replace, args, deadline, commit))
    else
      {:error, reason} -> reject(state, reason)
      _ -> reject(state, :stale_cleanup)
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

          not is_integer(bytes) or bytes < 0 ->
            reject(state, :byte_limit)

          is_nil(state.budget) and transport_bytes(state) + bytes > state.limits.max_bytes ->
            reject(state, :byte_limit)

          true ->
            {:ok, accounting} = Gaoxy.ResourceBudget.normalize_accounting(bytes)

            commit = fn state, receipt, late ->
              if late do
                send(self(), {:budget_unused, receipt, guardian})
                state
              else
                cleanup = %{
                  pid: guardian,
                  monitor: Process.monitor(guardian),
                  bytes: bytes,
                  lease: ref,
                  receipt: false,
                  accounting: accounting,
                  budget_owner: guardian,
                  down_seen: false,
                  down_reason: nil
                }

                cleanup = Budget.receipt(cleanup, receipt)
                if receipt, do: send(state.service, {:gaoxy_cleanup_budget, token, receipt})
                state = put_in(state.leases[ref].cleanup, token)

                sample(%{
                  state
                  | cleanups: Map.put(state.cleanups, token, cleanup),
                    bytes: state.bytes + bytes
                })
              end
            end

            reply_mutation(
              Budget.run(state, :reserve, [guardian, :guardian, accounting], deadline, commit)
            )
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
    commit_mode(state, :draining, fn state ->
      Enum.each(state.leases, fn {ref, lease} ->
        if lease.drain_notify, do: send(lease.pid, {:gaoxy_drain, self(), ref, deadline})
      end)

      %{state | drain_deadline: deadline}
    end)
  end

  def handle_call({:drain, _deadline}, _from, state), do: {:reply, :ok, state}

  def handle_call({action, ref, bytes}, {pid, _}, state)
      when action in [:begin, :retain, :update, :end_websocket_callback] do
    case state.leases[ref] do
      %{pid: ^pid} = lease ->
        cond do
          action == :end_websocket_callback and not Map.has_key?(lease, :websocket_bytes) ->
            {:reply, {:error, :not_websocket}, state}

          true ->
            case replace_accounting(state, lease, bytes) do
              {:ok, replacement} ->
                commit_lease(state, ref, replacement, nil, fn replacement ->
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

                      %{replacement | timer: timer, token: token}

                    action when action in [:retain, :end_websocket_callback] ->
                      cancel(lease)
                      %{replacement | timer: nil, token: nil}

                    :update ->
                      replacement
                  end
                end)

              {:error, reason} ->
                reject(state, reason)
            end
        end

      _ ->
        {:reply, {:error, :stale_generation}, state}
    end
  end

  def handle_call({:mode, _mode}, _from, %{drain_deadline: deadline} = state)
      when not is_nil(deadline),
      do: {:reply, :ok, state}

  def handle_call({:mode, mode}, _from, state), do: commit_mode(state, mode)

  def handle_call(:force, _from, state) do
    leases =
      Map.new(state.leases, fn {ref, lease} ->
        send_outcome(state, lease.send, {:unknown, :forced_cleanup})
        Process.exit(lease.pid, :kill)
        {ref, %{lease | send: nil}}
      end)

    state = %{state | leases: leases}

    case Budget.run(state, :set_mode, [:draining], nil, fn state, _, _ ->
           %{state | mode: :draining}
         end) do
      {:ok, state} -> {:reply, :ok, state}
      {:error, _, state} -> {:reply, :ok, %{state | mode: :draining}}
    end
  end

  def handle_call({:adjust_bytes, ref, delta}, {pid, _}, state) when is_integer(delta) do
    case state.leases[ref] do
      %{pid: ^pid} = lease ->
        transport = Accounting.categories(lease).transport_bytes

        case replace_accounting(state, lease, transport + delta) do
          {:ok, replacement} ->
            commit_lease(state, ref, replacement, nil)

          {:error, reason} ->
            reject(state, reason)
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

          lease =
            if Map.has_key?(lease, :websocket_bytes) do
              cancel(lease)
              token = make_ref()

              timer =
                Process.send_after(self(), {:expired, ref, token}, Lifecycle.remaining(deadline))

              %{lease | timer: timer, token: token, send: pending}
            else
              %{lease | send: pending}
            end

          Telemetry.emit(:send_started, %{bytes: bytes}, state.scope, %{operation: operation})
          {:reply, :ok, %{state | leases: Map.put(state.leases, ref, lease)}}
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

        lease =
          if Map.has_key?(lease, :websocket_bytes) do
            cancel(lease)
            %{lease | send: nil, timer: nil, token: nil}
          else
            %{lease | send: nil}
          end

        {:reply, :ok, %{state | leases: Map.put(state.leases, ref, lease)}}

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
    accounting = Accounting.totals(state.leases, state.cleanups)

    {:reply,
     %{
       active: map_size(state.leases),
       cleanup_pending: map_size(state.cleanups),
       retained_bytes: accounting.retained_bytes,
       temporary_bytes: accounting.temporary_bytes,
       usage: accounting.usage,
       retained_high_water: state.high_water,
       temporary_high_water: state.temporary_high_water,
       usage_high_water: state.usage_high_water,
       transport_bytes: accounting.transport_bytes,
       websocket_bytes: accounting.websocket_bytes,
       transport_high_water: state.transport_high_water,
       websocket_high_water: state.websocket_high_water,
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

      nil ->
        refs = for {ref, lease} <- state.leases, lease.pid == pid, do: ref

        if state.budget && refs != [] do
          state =
            Enum.reduce(refs, state, fn ref, state ->
              put_in(state.leases[ref].exit_seen, true)
            end)

          {:noreply, Enum.reduce(refs, state, &settle_lease(&2, &1))}
        else
          if reason == :normal, do: {:noreply, state}, else: {:stop, reason, state}
        end
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
            state =
              put_in(
                state.leases[ref],
                Map.merge(lease, %{down_seen: true, timer: nil, send: nil})
              )

            {:noreply, settle_lease(state, ref)}
        end

      nil ->
        case Enum.find(state.cleanups, fn {_, cleanup} -> cleanup.monitor == monitor end) do
          {token, cleanup} ->
            state =
              put_in(state.cleanups[token], %{cleanup | down_seen: true, down_reason: reason})

            {:noreply, settle_cleanup(state, token)}

          nil ->
            {:noreply, state}
        end
    end
  end

  def handle_info(:budget_reconcile, state) do
    case Budget.reconcile(state) do
      {:ok, state} -> {:noreply, sample(state)}
      {:error, _, state} -> {:noreply, state}
    end
  end

  def handle_info({:budget_unused, receipt, owner}, state) do
    lease = %{budget_receipt: receipt, budget_owner: owner, pid: owner}

    case Budget.release(state, lease, fn state, _, _ -> state end) do
      {:ok, state} ->
        {:noreply, state}

      {:error, :budget_pending, state} ->
        Process.send_after(self(), {:budget_unused, receipt, owner}, 10)
        {:noreply, state}

      {:error, _, state} ->
        {:noreply, state}
    end
  end

  def handle_info(:budget_retry_terminals, state) do
    state = Enum.reduce(Map.keys(state.spawns), state, &settle_spawn(&2, &1))
    state = Enum.reduce(Map.keys(state.leases), state, &settle_lease(&2, &1))
    state = Enum.reduce(Map.keys(state.cleanups), state, &settle_cleanup(&2, &1))
    {:noreply, state}
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

  defp stream_lease(state, {:spawn, token}) when is_reference(token),
    do: state.stream_spawns[token]

  defp stream_lease(_, ref) when is_reference(ref), do: ref
  defp stream_lease(_, _), do: nil

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

      retain? =
        not is_nil(state.budget) and lease.kind in [:h2_stream, :h3_stream] and
          parent_owned?(state, operation.parent_lease, operation.owner) and
          (stream_membership?(lease.accounting) or not lease.stream_resources_terminal)

      commit = fn state, receipt, _ ->
        state = %{state | spawns: Map.delete(state.spawns, token)}

        if retain? do
          lease = Budget.receipt(state.leases[operation.lease], receipt)

          accounting = %{
            lease.accounting
            | memberships: Map.delete(lease.accounting.memberships, :request),
              pending_processes: 0
          }

          lease = %{
            lease
            | pid: operation.owner,
              budget_owner: operation.owner,
              kind: :stream_retention,
              accounting: accounting,
              monitor: Process.monitor(operation.owner),
              request_active: false,
              token: nil,
              timer: nil,
              down_seen: false,
              exit_seen: false
          }

          send(self(), :budget_retry_terminals)
          put_in(state.leases[operation.lease], lease)
        else
          remove_lease(state, operation.lease)
        end
      end

      result =
        if retain?,
          do:
            Budget.run(
              state,
              :retain_stream,
              Budget.arguments(lease, operation.owner) ++ [Budget.proof(lease)],
              nil,
              commit
            ),
          else: Budget.release(state, lease, commit)

      terminal_result(result)
    else
      state
    end
  end

  defp reserve_lease(state, ref, pid, bytes, options, deadline, pending) do
    with true <- Keyword.keyword?(options) || {:error, :invalid_options},
         true <- length(options) == map_size(Map.new(options)) || {:error, :invalid_options},
         true <-
           Keyword.keys(options) -- [:kind, :memberships, :deadline, :drain_notify] == [] ||
             {:error, :invalid_options},
         kind = Keyword.get(options, :kind, if(pending == 1, do: :request, else: :transport)),
         true <-
           kind in [:connection, :request, :h2_stream, :h3_stream, :writer, :transport] ||
             {:error, :invalid_options},
         {:ok, accounting} <- Gaoxy.ResourceBudget.normalize_accounting(bytes),
         members = Keyword.get(options, :memberships, accounting.memberships),
         members = if(kind == :request and members == %{}, do: %{request: ref}, else: members),
         {:ok, accounting} <-
           Gaoxy.ResourceBudget.normalize_accounting(%{
             accounting
             | memberships: members,
               pending_processes: pending
           }),
         :ok <- local_reserve_check(state, accounting) do
      commit = fn state, receipt, late ->
        if late do
          send(self(), {:budget_unused, receipt, pid})
          state
        else
          if state.budget && pid != self(), do: Process.link(pid)

          lease = %{
            pid: pid,
            monitor: if(pid != self(), do: Process.monitor(pid)),
            bytes: accounting.retained_bytes + accounting.temporary_bytes,
            token: nil,
            timer: nil,
            send: nil,
            drain_notify: Keyword.get(options, :drain_notify, false),
            request_active: false,
            cleanup: nil,
            deadline: nil,
            accounting: accounting,
            kind: kind,
            budget_owner: pid,
            down_seen: false,
            exit_seen: false
          }

          lease =
            if accounting.websocket_bytes > 0,
              do: Map.merge(lease, Map.take(accounting, [:transport_bytes, :websocket_bytes])),
              else: lease

          lease = Budget.receipt(lease, receipt)

          lease =
            if is_nil(state.budget) and pending == 0,
              do: Map.drop(lease, [:accounting, :kind, :budget_owner, :down_seen, :exit_seen]),
              else: lease

          sample(%{
            state
            | leases: Map.put(state.leases, ref, lease),
              bytes: state.bytes + lease.bytes
          })
        end
      end

      Budget.run(state, :reserve, [pid, kind, accounting], deadline, commit)
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp local_reserve_check(%{mode: mode}, _) when mode != :ready, do: {:error, mode}

  defp local_reserve_check(%{budget: nil} = state, accounting) do
    cond do
      map_size(state.leases) >= state.limits.max_active ->
        {:error, :active_limit}

      transport_bytes(state) + accounting.transport_bytes > state.limits.max_bytes ->
        {:error, :byte_limit}

      true ->
        :ok
    end
  end

  defp local_reserve_check(state, _) do
    if map_size(state.leases) + map_size(state.cleanups) >= Gaoxy.Config.lease_safety_limit(),
      do: {:error, :lease_capacity},
      else: :ok
  end

  defp request_membership(lease, action, ref) do
    members = lease.accounting.memberships

    members =
      case action do
        :begin_request -> Map.put_new(members, :request, ref)
        action when action in [:upgrade, :end_request] -> Map.delete(members, :request)
        _ -> members
      end

    %{lease | accounting: %{lease.accounting | memberships: members}}
  end

  defp stream_membership?(accounting),
    do: Enum.any?([:h2_stream, :h3_stream], &Map.has_key?(accounting.memberships, &1))

  defp commit_lease(
         state,
         ref,
         replacement,
         deadline,
         after_commit \\ &Function.identity/1,
         operation \\ nil,
         mutation \\ :replace
       ) do
    lease = state.leases[ref]
    args = if state.budget, do: Budget.arguments(lease, replacement.accounting), else: []

    commit = fn state, receipt, _ ->
      state = remember_update(state, operation, :ok)
      current = state.leases[ref]
      # Preserve terminal observations and send metadata received while reconciling.
      replacement =
        Map.merge(
          current,
          Map.take(replacement, [:bytes, :accounting, :transport_bytes, :websocket_bytes])
        )

      replacement = replacement |> Budget.receipt(receipt) |> after_commit.()

      sample(%{
        state
        | leases: Map.put(state.leases, ref, replacement),
          bytes: state.bytes - current.bytes + replacement.bytes
      })
    end

    remember_rejection = fn state, reason ->
      remember_update(state, operation, {:error, reason})
    end

    case Budget.run(state, mutation, args, deadline, commit, remember_rejection) do
      {:error, reason, state} when reason in [:budget_timeout, :budget_unavailable] ->
        state = if operation, do: %{state | update_pending: operation}, else: state
        reject(state, reason)

      result ->
        reply_mutation(result)
    end
  end

  defp remember_update(state, nil, _), do: state

  defp remember_update(state, {operation, fingerprint}, result) do
    receipts =
      Map.put(state.update_receipts, operation, %{fingerprint: fingerprint, result: result})

    order = :queue.in(operation, state.update_order)

    {receipts, order} =
      if map_size(receipts) > 64 do
        {{:value, expired}, order} = :queue.out(order)
        {Map.delete(receipts, expired), order}
      else
        {receipts, order}
      end

    pending =
      if state.update_pending == {operation, fingerprint}, do: nil, else: state.update_pending

    %{state | update_receipts: receipts, update_order: order, update_pending: pending}
  end

  defp cancel_fingerprint(parent, owner, token),
    do: :crypto.hash(:sha256, :erlang.term_to_binary({owner, :cancel_spawn, parent, token}))

  defp remember_cancel(state, parent, owner, token) do
    operation = {:cancel_spawn, token}

    if Map.has_key?(state.update_receipts, operation),
      do: state,
      else: remember_update(state, {operation, cancel_fingerprint(parent, owner, token)}, :ok)
  end

  defp commit_mode(state, mode, after_commit \\ &Function.identity/1) do
    commit = fn state, _, _ -> after_commit.(%{state | mode: mode}) end
    reply_mutation(Budget.run(state, :set_mode, [mode], nil, commit))
  end

  defp release_reply(state, ref, deadline) do
    lease = state.leases[ref]
    args = if state.budget, do: Budget.arguments(lease, Budget.proof(lease)), else: []

    reply_mutation(
      Budget.run(state, :release, args, deadline, fn state, _, _ -> remove_lease(state, ref) end)
    )
  end

  defp release_lease(state, ref),
    do: Budget.release(state, state.leases[ref], fn state, _, _ -> remove_lease(state, ref) end)

  defp remove_lease(state, ref) do
    lease = state.leases[ref]
    if lease.monitor, do: Process.demonitor(lease.monitor, [:flush])

    state =
      case lease do
        %{spawn_token: token, stream_parent: {parent, owner}} ->
          state = %{state | stream_spawns: Map.delete(state.stream_spawns, token)}
          remember_cancel(state, parent, owner, token)

        _ ->
          state
      end

    sample(%{state | leases: Map.delete(state.leases, ref), bytes: state.bytes - lease.bytes})
  end

  defp settle_lease(state, ref) do
    lease = state.leases[ref]

    cond do
      is_nil(lease) ->
        state

      Enum.any?(state.spawns, fn {_, op} -> op.lease == ref end) ->
        state

      lease.down_seen and (is_nil(state.budget) or lease.exit_seen) ->
        terminal_result(release_lease(state, ref))

      Map.get(lease, :kind) == :stream_retention and lease.stream_resources_terminal ->
        settle_stream_resources(state, ref)

      true ->
        state
    end
  end

  defp settle_stream_resources(state, ref) do
    lease = state.leases[ref]

    cond do
      not stream_membership?(lease.accounting) ->
        terminal_result(release_lease(state, ref))

      lease.bytes == 0 ->
        state

      true ->
        accounting = %{
          lease.accounting
          | retained_bytes: 0,
            temporary_bytes: 0,
            transport_bytes: 0,
            websocket_bytes: 0,
            pending_processes: 0
        }

        commit = fn state, receipt, _ ->
          current = state.leases[ref]
          {:ok, replacement} = Accounting.replace(current, accounting)
          replacement = Budget.receipt(replacement, receipt)

          sample(%{
            state
            | leases: Map.put(state.leases, ref, replacement),
              bytes: state.bytes - current.bytes
          })
        end

        terminal_result(
          Budget.run(state, :replace, Budget.arguments(lease, accounting), nil, commit)
        )
    end
  end

  defp settle_cleanup(state, token) do
    cleanup = state.cleanups[token]

    cond do
      is_nil(cleanup) or not cleanup.down_seen ->
        state

      state.budget && not (cleanup.receipt and cleanup.down_reason == :normal) ->
        %{state | mode: :failed}

      true ->
        commit = fn state, _, _ ->
          state =
            case state.leases[cleanup.lease] do
              nil -> state
              lease -> put_in(state.leases[cleanup.lease], %{lease | cleanup: nil})
            end

          sample(%{
            state
            | cleanups: Map.delete(state.cleanups, token),
              bytes: state.bytes - cleanup.bytes,
              mode:
                if(cleanup.receipt and cleanup.down_reason == :normal,
                  do: state.mode,
                  else: :failed
                )
          })
        end

        terminal_result(Budget.release(state, cleanup, commit))
    end
  end

  defp terminal_result({:ok, state}), do: state

  defp terminal_result({:error, :budget_pending, state}) do
    Process.send_after(self(), :budget_retry_terminals, 10)
    state
  end

  defp terminal_result({:error, _, state}), do: state
  defp reply_mutation({:ok, state}), do: {:reply, :ok, state}
  defp reply_mutation({:error, reason, state}), do: reject(state, reason)

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

  defp replace_accounting(state, lease, bytes, classify? \\ false) do
    if is_nil(state.budget) and is_map(bytes) and not classify? and
         not Map.has_key?(lease, :websocket_bytes) do
      {:error, :byte_limit}
    else
      with {:ok, replacement} <- Accounting.replace(lease, bytes),
           do: validate_accounting(state, lease, replacement)
    end
  end

  defp repartition_accounting(state, lease, bytes) do
    with {:ok, replacement} <- Accounting.repartition(lease, bytes),
         do: validate_accounting(state, lease, replacement)
  end

  defp validate_accounting(state, lease, replacement) do
    with :ok <-
           Accounting.validate(
             state.leases,
             state.cleanups,
             lease,
             replacement,
             if(state.budget, do: 9_223_372_036_854_775_807, else: state.limits.max_bytes)
           ),
         do: {:ok, replacement}
  end

  defp transport_bytes(state),
    do: Accounting.totals(state.leases, state.cleanups).transport_bytes

  defp sample(state) do
    accounting = Accounting.totals(state.leases, state.cleanups)

    state = %{
      state
      | high_water: max(state.high_water, accounting.retained_bytes),
        temporary_high_water: max(state.temporary_high_water, accounting.temporary_bytes),
        usage_high_water: max(state.usage_high_water, accounting.usage),
        transport_high_water: max(state.transport_high_water, accounting.transport_bytes),
        websocket_high_water: max(state.websocket_high_water, accounting.websocket_bytes)
    }

    Telemetry.emit(
      :work,
      Map.merge(accounting, %{
        active: map_size(state.leases),
        retained_high_water: state.high_water,
        temporary_high_water: state.temporary_high_water,
        usage_high_water: state.usage_high_water,
        transport_high_water: state.transport_high_water,
        websocket_high_water: state.websocket_high_water
      }),
      state.scope
    )

    state
  end
end
