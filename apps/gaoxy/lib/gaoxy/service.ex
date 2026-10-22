defmodule Gaoxy.Service do
  @moduledoc false
  use GenServer, restart: :transient
  alias Gaoxy.{Admission, Lifecycle, RegistryPolicy, Telemetry}
  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def attach_cleanup(service, gate, lease, guardian, reserved_bytes, deadline),
    do:
      Lifecycle.call(
        service,
        {:attach_cleanup, gate, lease, guardian, reserved_bytes, deadline},
        deadline
      )

  def complete_cleanup(service, token),
    do: Lifecycle.call(service, {:complete_cleanup, token}, Lifecycle.deadline(1_000))

  def child_spec({table, _live, id, _scope} = args) do
    [{^id, spec}] = :ets.lookup(table, id)

    %{
      id: id,
      start: {__MODULE__, :start_link, [args]},
      restart: :transient,
      shutdown: spec.limits.drain_timeout + 2 * Lifecycle.cleanup_headroom()
    }
  end

  @impl true
  def init({table, live, id, instance}) do
    Process.flag(:trap_exit, true)
    service = self()
    [{^id, spec}] = :ets.lookup(table, id)
    generation = make_ref()
    scope = %{instance: instance, service: id, generation: generation}

    with {:ok, spec} <- prepare_dispatcher(spec),
         {:ok, policy} <- RegistryPolicy.register(scope) do
      {:ok, gate} = Admission.start_link({spec.limits, Map.put(scope, :service_pid, self())})

      context = %{
        spec: spec,
        gate: gate,
        scope: scope,
        service: self(),
        instance: :ets.info(table, :owner),
        startup_token: make_ref()
      }

      result =
        Lifecycle.protect(fn ->
          with {:ok, backend} <- start_backend(spec, context),
               do: attach_dispatcher(backend, context)
        end)

      case result do
        {:ok, backend, dispatcher_owner} ->
          case RegistryPolicy.bind(policy, backend) do
            {:ok, policy} ->
              :ets.insert(live, {id, self(), generation})
              Telemetry.emit(:lifecycle, %{count: 1}, scope, %{state: :ready})

              {:ok,
               %{
                 spec: spec,
                 table: table,
                 live: live,
                 backend: backend,
                 dispatcher_owner: dispatcher_owner,
                 dispatcher_monitor: if(dispatcher_owner, do: Process.monitor(dispatcher_owner)),
                 gate: gate,
                 scope: scope,
                 generation: generation,
                 mode: :ready,
                 drain: nil,
                 control: nil,
                 cleanups: %{},
                 cleanup_failed: nil,
                 registry_policy: policy,
                 drain_fun: fn transport, backend, gate, deadline ->
                   Lifecycle.drain(transport, backend, gate, deadline, fn ->
                     Lifecycle.call(service, {:retain_drain_resources, backend}, deadline)
                   end)
                 end,
                 backend_control: &backend_control/3
               }}

            {:error, reason} ->
              close_resources(backend, gate, spec.transport, dispatcher_owner)
              RegistryPolicy.cancel(policy)
              {:stop, reason}
          end

        {:error, reason} ->
          close_dispatcher_start(context)
          if Process.alive?(gate), do: GenServer.stop(gate)
          RegistryPolicy.cancel(policy)
          {:stop, reason}
      end
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call({:attach_cleanup, _, _, _, _, _}, _, %{mode: mode} = state)
      when mode != :ready,
      do: {:reply, {:error, mode}, state}

  def handle_call({:attach_cleanup, gate, lease, guardian, bytes, deadline}, {owner, _}, state)
      when gate == state.gate do
    token = make_ref()

    result =
      Lifecycle.protect(fn ->
        Admission.attach_cleanup(gate, owner, lease, guardian, bytes, deadline, token)
      end)

    case result do
      :ok ->
        cleanup = %{guardian: guardian, monitor: Process.monitor(guardian), receipt: false}
        state = %{state | cleanups: Map.put(state.cleanups, token, cleanup)}
        send(guardian, {:gaoxy_cleanup_activate, token})
        {:reply, {:ok, token}, state}

      error ->
        state = if match?({:error, {:exit, _}}, error), do: fail_gate(state), else: state
        {:reply, error, state}
    end
  end

  def handle_call({:attach_cleanup, _, _, _, _, _}, _, state),
    do: {:reply, {:error, :stale_generation}, state}

  def handle_call({:complete_cleanup, token}, {guardian, _}, state) do
    case state.cleanups[token] do
      %{guardian: ^guardian} = cleanup ->
        state = put_in(state.cleanups[token], %{cleanup | receipt: true})

        result = Lifecycle.protect(fn -> Admission.complete_cleanup(state.gate, token) end)

        state =
          if result != :ok and Process.alive?(state.gate), do: fail_gate(state), else: state

        {:reply, :ok, state}

      _ ->
        {:reply, {:error, :stale_cleanup}, state}
    end
  end

  def handle_call({:request, generation, _}, _, state)
      when not is_nil(generation) and generation != state.generation,
      do: {:reply, {:error, :stale_generation}, state}

  def handle_call({:request, _, _}, _, %{registry_policy: %{recovery: recovery}} = state)
      when not is_nil(recovery),
      do: {:reply, {:error, :registry_unavailable}, state}

  def handle_call({:request, _, :handle}, _, state),
    do: {:reply, %{id: state.spec.id, generation: state.generation}, state}

  def handle_call({:request, _, :info}, _, state) do
    {:reply,
     %{
       id: state.spec.id,
       generation: state.generation,
       transport: state.spec.transport,
       mode: state.mode,
       local: Lifecycle.bounded(fn -> local(state) end, 50),
       pause:
         case state.spec.transport do
           :udp -> :admission_only
           :quic -> :unsupported
           _ -> :unbind_rebind
         end,
       drain: if(state.spec.transport == :quic, do: :local_host_cleanup, else: :admitted_work)
     }, state}
  end

  def handle_call({:request, _, :status}, _, state) do
    status = Lifecycle.call(state.gate, :status, Lifecycle.deadline(50))
    status = if is_map(status), do: status, else: %{admission: status}

    {:reply,
     Map.merge(status, %{
       state: state.mode,
       cleanup_pending: map_size(state.cleanups),
       cleanup_failed: state.cleanup_failed,
       backend: Lifecycle.bounded(fn -> backend_status(state) end, 50)
     }), state}
  end

  def handle_call({:request, _, operation}, _, %{mode: mode} = state)
      when operation in [:pause, :resume] and mode in [:draining, :stopped, :failed],
      do: {:reply, {:error, mode}, state}

  def handle_call({:request, _, operation}, _, %{spec: %{transport: :quic}} = state)
      when operation in [:pause, :resume],
      do: {:reply, {:error, {:unsupported_capability, :quic_pause}}, state}

  def handle_call({:request, _, operation}, _, %{control: control} = state)
      when operation in [:pause, :resume] and not is_nil(control),
      do: {:reply, {:error, :transition_in_progress}, state}

  def handle_call({:request, _, :pause}, _, %{mode: :paused} = state), do: {:reply, :ok, state}
  def handle_call({:request, _, :resume}, _, %{mode: :ready} = state), do: {:reply, :ok, state}

  def handle_call({:request, _, operation}, from, state) when operation in [:pause, :resume] do
    # The service alone commits admission reopening. A late backend result can
    # never reopen a gate after a drain or a failed coordination step.
    case gate_mode(state, :paused) do
      :ok ->
        owner = self()
        token = make_ref()

        {pid, monitor} =
          :erlang.spawn_opt(
            fn ->
              result =
                Lifecycle.protect(fn ->
                  dispatcher_control(state, operation)
                end)

              send(owner, {:controlled, state.generation, token, self(), result})
            end,
            [:link, :monitor]
          )

        timer =
          Process.send_after(
            self(),
            {:control_deadline, token},
            min(state.spec.limits.callback_timeout, 1_000)
          )

        control = %{
          pid: pid,
          monitor: monitor,
          timer: timer,
          token: token,
          from: from,
          operation: operation
        }

        {:noreply,
         %{
           transition(state, if(operation == :pause, do: :pausing, else: :resuming))
           | control: control
         }}

      error ->
        {:reply, {:error, {:transition_failed, operation, error}}, fail_gate(state)}
    end
  end

  def handle_call({:request, _, :memberships}, _, state),
    do: {:reply, membership_list(state), state}

  def handle_call({:request, _, {:membership, operation, membership}}, _, state) do
    result = membership_change(state, operation, membership)

    if result == :ok do
      spec = put_in(state.spec, [:udp, :memberships], Abyss.memberships(state.backend))
      :ets.insert(state.table, {spec.id, spec})
      {:reply, :ok, %{state | spec: spec}}
    else
      {:reply, result, state}
    end
  end

  def handle_call(
        {:retain_drain_resources, backend},
        {helper, _},
        %{backend: backend, drain: %{pid: helper, phase: :draining} = drain} = state
      ) do
    added = owned_resources(state) -- drain.resources

    drain = %{
      drain
      | resources: drain.resources ++ added,
        monitors: drain.monitors ++ Enum.map(added, &Process.monitor/1)
    }

    {:reply, :ok, %{state | drain: drain}}
  end

  def handle_call({:retain_drain_resources, _}, _, state),
    do: {:reply, {:error, :not_draining}, state}

  def handle_call({:drain, generation, _deadline}, _, state)
      when not is_nil(generation) and generation != state.generation,
      do: {:reply, {:error, :stale_generation}, state}

  def handle_call({:drain, _, deadline}, from, %{drain: nil} = state) do
    state = cancel_control(state, :draining)

    barrier =
      Lifecycle.protect(fn -> GenServer.call(state.gate, {:drain, deadline}, 50) end)

    state = start_drain(state, deadline, [from])

    state =
      if barrier == :ok,
        do: state,
        else: force_drain(state, {:cleanup_failed, {:admission_barrier, barrier}})

    {:noreply, state}
  end

  def handle_call({:drain, _, _deadline}, from, state) do
    # At most the removal coordinator and the instance shutdown coordinator.
    if length(state.drain.waiters) < 2 do
      {:noreply, put_in(state.drain.waiters, [from | state.drain.waiters])}
    else
      {:reply, {:error, :already_draining}, state}
    end
  end

  @impl true
  def handle_info(
        {:controlled, generation, token, pid, result},
        %{generation: generation, control: %{token: token, pid: pid}} = state
      ) do
    control = state.control
    Process.cancel_timer(control.timer)
    Process.demonitor(control.monitor, [:flush])
    target = if control.operation == :pause, do: :paused, else: :ready
    backend_result = result
    result = if result == :ok, do: gate_mode(state, target), else: result

    if result == :ok do
      GenServer.reply(control.from, :ok)
      {:noreply, %{transition(state, target) | control: nil}}
    else
      GenServer.reply(control.from, {:error, {:transition_failed, control.operation, result}})
      state = %{transition(state, :failed) | control: nil}

      {:noreply,
       if(backend_result == :ok or not Process.alive?(state.gate),
         do: fail_gate(state),
         else: state
       )}
    end
  end

  def handle_info({:control_deadline, token}, %{control: %{token: token}} = state) do
    state = cancel_control(state, {:transition_failed, state.control.operation, :outcome_unknown})
    {:noreply, transition(state, :failed)}
  end

  def handle_info(
        {:drained, generation, token, pid, result},
        %{generation: generation, drain: %{token: token, pid: pid, phase: :draining}} = state
      ) do
    outcome =
      case result do
        :ok -> :completed
        error -> {:cleanup_failed, error}
      end

    {:noreply, force_drain(state, outcome)}
  end

  def handle_info({:drain_deadline, token}, %{drain: %{token: token, phase: :draining}} = state),
    do: {:noreply, force_drain(state, :forced)}

  def handle_info(
        {:cleanup_check, generation, token},
        %{generation: generation, drain: %{token: token, phase: :confirming}} = state
      ) do
    if cleanup_done?(state) do
      finish_drain(state)
    else
      if Lifecycle.remaining(state.drain.cleanup_deadline) == 0 do
        outcome =
          if native_cleanup_done?(state) and map_size(state.cleanups) > 0,
            do: {:deadline_exceeded, :cleanup_pending},
            else: {:cleanup_failed, :termination_unconfirmed}

        Enum.each(state.drain.waiters, &GenServer.reply(&1, {:error, outcome}))

        Telemetry.emit(:drain, %{count: 1}, state.scope, %{outcome: :termination_unconfirmed})

        {:noreply,
         %{transition(state, :failed) | drain: %{state.drain | waiters: [], phase: :unconfirmed}}}
      else
        Process.send_after(self(), {:cleanup_check, generation, token}, 1)
        {:noreply, state}
      end
    end
  end

  def handle_info(
        {:DOWN, monitor, :process, _pid, reason},
        %{drain: %{monitor: monitor, phase: :draining}} = state
      ),
      do: {:noreply, force_drain(state, {:cleanup_failed, {:helper_exit, reason}})}

  def handle_info(
        {:DOWN, monitor, :process, _pid, reason},
        %{control: %{monitor: monitor}} = state
      ) do
    {:noreply,
     state
     |> cancel_control({:transition_failed, state.control.operation, {:helper_exit, reason}})
     |> transition(:failed)}
  end

  def handle_info(
        {:DOWN, monitor, :process, _pid, reason},
        %{dispatcher_monitor: monitor} = state
      )
      when not is_nil(monitor) do
    if state.drain do
      {:noreply, state}
    else
      state = start_drain(cancel_control(state, :failed), Lifecycle.now(), [])
      {:noreply, force_drain(state, {:cleanup_failed, {:dispatcher_owner_failed, reason}})}
    end
  end

  def handle_info(
        {:gaoxy_dispatcher_failed, owner, generation, reason},
        %{dispatcher_owner: owner, generation: generation} = state
      ) do
    state =
      if state.drain,
        do: state,
        else: start_drain(cancel_control(state, :failed), Lifecycle.now(), [])

    {:noreply, force_drain(state, {:cleanup_failed, reason})}
  end

  def handle_info({:DOWN, monitor, :process, _pid, reason}, state) do
    case Enum.find(state.cleanups, fn {_, cleanup} -> cleanup.monitor == monitor end) do
      {token, cleanup} ->
        cleanup_down(state, token, cleanup, reason)

      nil ->
        registry_down(state, monitor)
    end
  end

  def handle_info({:registry_recover, token}, state) do
    case RegistryPolicy.recover(state.registry_policy, token) do
      :ignore ->
        {:noreply, state}

      {result, policy} when result in [:ok, :retry] ->
        {:noreply, %{state | registry_policy: policy}}

      {:expired, policy} ->
        state = %{state | registry_policy: policy}

        state =
          if state.drain,
            do: state,
            else: start_drain(cancel_control(state, :registry_unavailable), Lifecycle.now(), [])

        {:noreply, force_drain(state, {:cleanup_failed, :registry_unavailable})}
    end
  end

  def handle_info({:EXIT, pid, _}, %{drain: drain} = state)
      when not is_nil(drain) and (pid == state.backend or pid == state.gate),
      do: {:noreply, state}

  def handle_info({:EXIT, pid, reason}, state)
      when (pid == state.backend or pid == state.gate) and map_size(state.cleanups) > 0 do
    state = start_drain(cancel_control(state, :failed), Lifecycle.now(), [])
    {:noreply, force_drain(state, {:cleanup_failed, {:backend_failed, reason}})}
  end

  def handle_info({:EXIT, pid, reason}, state) when pid == state.backend or pid == state.gate,
    do: {:stop, {:backend_failed, reason}, state}

  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def terminate(_, state) do
    RegistryPolicy.cancel(state.registry_policy)
    if state.control, do: Process.exit(state.control.pid, :kill)

    if state.drain do
      Process.cancel_timer(state.drain.timer)
      if state.drain.pid, do: Process.exit(state.drain.pid, :kill)
    end

    close_resources(state.backend, state.gate, state.spec.transport, state.dispatcher_owner)
    deadline = Lifecycle.deadline(Lifecycle.cleanup_headroom())
    cancel_cleanups(state, :service_terminating, deadline)
    await_cleanup_termination(state.cleanups, deadline)

    # The instance owns this table and may exit while guardian cleanup continues.
    try do
      :ets.match_delete(state.live, {state.spec.id, self(), :_})
    catch
      :error, :badarg -> :ok
    end
  end

  defp registry_down(state, monitor) do
    case RegistryPolicy.loss(state.registry_policy, monitor) do
      {:recovering, policy} ->
        {:noreply, %{state | registry_policy: policy}}

      :ignore ->
        if state.drain && state.drain.phase == :unconfirmed &&
             cleanup_done?(state) do
          finish_drain(state)
        else
          {:noreply, state}
        end
    end
  end

  defp cleanup_down(state, token, cleanup, reason) do
    state = %{state | cleanups: Map.delete(state.cleanups, token)}

    state =
      if cleanup.receipt and reason == :normal do
        state
      else
        failure = if cleanup.receipt, do: {:guardian_exit, reason}, else: :cleanup_receipt_missing
        state = %{state | cleanup_failed: failure}
        state = if state.drain, do: state, else: start_drain(state, Lifecycle.now(), [])
        state = force_drain(state, {:cleanup_failed, failure})

        %{
          transition(state, :failed)
          | drain: %{state.drain | outcome: {:cleanup_failed, failure}}
        }
      end

    if state.drain && state.drain.phase == :unconfirmed && cleanup_done?(state),
      do: finish_drain(state),
      else: {:noreply, state}
  end

  defp start_drain(state, deadline, waiters) do
    cancel_cleanups(state, :draining, deadline)
    owner = self()
    token = make_ref()

    resources =
      Enum.uniq([
        state.gate | owned_resources(state)
      ])

    monitors = Enum.map(resources, &Process.monitor/1)

    {pid, monitor} =
      :erlang.spawn_opt(
        fn ->
          result =
            Lifecycle.protect(fn ->
              dispatcher_drain(state, deadline)
            end)

          send(owner, {:drained, state.generation, token, self(), result})
        end,
        [:link, :monitor]
      )

    timer = Process.send_after(self(), {:drain_deadline, token}, Lifecycle.remaining(deadline))

    drain = %{
      pid: pid,
      monitor: monitor,
      token: token,
      timer: timer,
      deadline: deadline,
      waiters: waiters,
      resources: resources,
      monitors: monitors,
      phase: :draining,
      outcome: nil,
      cleanup_deadline: nil
    }

    %{transition(state, :draining) | drain: drain}
  end

  defp force_drain(%{drain: %{phase: phase}} = state, _) when phase != :draining, do: state

  defp force_drain(state, outcome) do
    drain = state.drain

    outcome =
      if outcome == :completed and
           Enum.any?(List.delete(drain.resources, state.gate), &Process.alive?/1),
         do: :forced,
         else: outcome

    Process.cancel_timer(drain.timer)
    Process.exit(drain.pid, :kill)

    resources =
      Enum.uniq([
        drain.pid
        | drain.resources ++
            owned_resources(state)
      ])

    # The gate emits pending send uncertainty before any owned work is killed.
    cancel_cleanups(state, :forced, drain.deadline)
    Lifecycle.force(resources, state.gate)
    send(self(), {:cleanup_check, state.generation, drain.token})

    %{
      state
      | drain: %{
          drain
          | resources: resources,
            phase: :confirming,
            outcome: outcome,
            cleanup_deadline: Lifecycle.deadline(Lifecycle.cleanup_headroom())
        }
    }
  end

  defp finish_drain(state) do
    drain = state.drain
    Enum.each(drain.monitors, &Process.demonitor(&1, [:flush]))
    Process.demonitor(drain.monitor, [:flush])

    result =
      case drain.outcome do
        {:cleanup_failed, reason} ->
          {:error, {:cleanup_failed, reason}}

        _ ->
          if Lifecycle.remaining(drain.deadline) > 0,
            do: :ok,
            else: {:error, {:deadline_exceeded, :cleanup_pending}}
      end

    Telemetry.emit(:drain, %{count: 1}, state.scope, %{outcome: drain.outcome})
    :ets.delete(state.table, state.spec.id)
    Enum.each(drain.waiters, &GenServer.reply(&1, result))
    {:stop, :normal, %{transition(state, :stopped) | drain: nil}}
  end

  defp native_cleanup_done?(state),
    do: Enum.all?(state.drain.resources, &(not Process.alive?(&1)))

  defp cleanup_done?(state),
    do: native_cleanup_done?(state) and map_size(state.cleanups) == 0

  defp cancel_cleanups(state, reason, deadline) do
    Enum.each(state.cleanups, fn {token, cleanup} ->
      send(cleanup.guardian, {:gaoxy_cleanup_cancel, token, reason, deadline})
    end)
  end

  # A terminating service cannot run handle_call/3. Authenticate and acknowledge
  # receipts here so a guardian can finish without waiting for service death.
  defp await_cleanup_termination(cleanups, deadline) when map_size(cleanups) > 0 do
    receive do
      {:"$gen_call", {guardian, _} = from, {:complete_cleanup, token}} ->
        case cleanups[token] do
          %{guardian: ^guardian} = cleanup ->
            GenServer.reply(from, :ok)

            await_cleanup_termination(
              Map.put(cleanups, token, %{cleanup | receipt: true}),
              deadline
            )

          _ ->
            GenServer.reply(from, {:error, :stale_cleanup})
            await_cleanup_termination(cleanups, deadline)
        end

      {:DOWN, monitor, :process, _, _} ->
        cleanups = Map.reject(cleanups, fn {_, cleanup} -> cleanup.monitor == monitor end)
        await_cleanup_termination(cleanups, deadline)
    after
      Lifecycle.remaining(deadline) -> :ok
    end
  end

  defp await_cleanup_termination(_, _), do: :ok

  defp close_resources(backend, gate, transport, dispatcher_owner \\ nil) do
    extra = if dispatcher_owner, do: Lifecycle.resources(dispatcher_owner, self()), else: []

    resources =
      Enum.uniq([gate | extra ++ Lifecycle.resources(backend, self(), transport == :quic)])

    monitors = Enum.map(resources, &{&1, Process.monitor(&1)})
    Lifecycle.force(resources, gate)
    deadline = Lifecycle.deadline(Lifecycle.cleanup_headroom())

    Enum.each(monitors, fn {pid, monitor} ->
      receive do
        {:DOWN, ^monitor, :process, ^pid, _} -> :ok
      after
        Lifecycle.remaining(deadline) -> Process.demonitor(monitor, [:flush])
      end
    end)
  end

  defp fail_gate(state) do
    state = if state.drain, do: state, else: start_drain(state, Lifecycle.now(), [])
    state |> force_drain({:cleanup_failed, :admission_unavailable}) |> transition(:failed)
  end

  defp gate_mode(state, mode),
    do: Lifecycle.protect(fn -> GenServer.call(state.gate, {:mode, mode}, 50) end)

  defp cancel_control(%{control: nil} = state, _), do: state

  defp cancel_control(state, reason) do
    Process.cancel_timer(state.control.timer)
    Process.exit(state.control.pid, :kill)
    Process.demonitor(state.control.monitor, [:flush])
    GenServer.reply(state.control.from, {:error, reason})
    %{state | control: nil}
  end

  defp prepare_dispatcher(%{handler_mode: :datagram_dispatcher} = spec) do
    if function_exported?(spec.handler, :prepare_service, 2) do
      case Lifecycle.bounded(
             fn -> spec.handler.prepare_service(spec.handler_options, spec) end,
             spec.limits.callback_timeout
           ) do
        {:ok, options} -> {:ok, %{spec | handler_options: options}}
        {:error, reason} -> {:error, {:handler_preflight, reason}}
        _ -> {:error, {:handler_preflight, :invalid_result}}
      end
    else
      {:ok, spec}
    end
  end

  defp prepare_dispatcher(spec), do: {:ok, spec}

  defp close_dispatcher_start(context) do
    generation = context.scope.generation
    token = context.startup_token

    receive do
      {:gaoxy_dispatcher_ready, ^generation, ^token, owner} when is_pid(owner) ->
        resources = Lifecycle.resources(owner, self())
        Lifecycle.terminate_resources(resources, Lifecycle.deadline(Lifecycle.cleanup_headroom()))
    after
      0 -> :ok
    end
  end

  defp attach_dispatcher(backend, %{spec: %{handler_mode: :datagram_dispatcher}} = context) do
    generation = context.scope.generation
    token = context.startup_token

    receive do
      {:gaoxy_dispatcher_ready, ^generation, ^token, owner} when is_pid(owner) ->
        if Process.alive?(owner) do
          {:ok, backend, owner}
        else
          close_resources(backend, context.gate, :udp, owner)
          {:error, :dispatcher_start_failed}
        end
    after
      context.spec.limits.callback_timeout ->
        close_resources(backend, context.gate, :udp)
        {:error, :dispatcher_start_timeout}
    end
  end

  defp attach_dispatcher(backend, _context), do: {:ok, backend, nil}

  defp owned_resources(state) do
    extra =
      if state.dispatcher_owner, do: Lifecycle.resources(state.dispatcher_owner, self()), else: []

    Enum.uniq(extra ++ Lifecycle.resources(state.backend, self(), state.spec.transport == :quic))
  end

  defp dispatcher_control(%{dispatcher_owner: nil} = state, operation),
    do: state.backend_control.(operation, state.spec.transport, state.backend)

  defp dispatcher_control(state, :pause) do
    with :ok <- state.spec.handler.control(state.dispatcher_owner, :pause, state.generation),
         do: state.backend_control.(:pause, state.spec.transport, state.backend)
  end

  defp dispatcher_control(state, :resume) do
    with :ok <- state.backend_control.(:resume, state.spec.transport, state.backend),
         do: state.spec.handler.control(state.dispatcher_owner, :resume, state.generation)
  end

  defp dispatcher_drain(%{dispatcher_owner: nil} = state, deadline),
    do: state.drain_fun.(state.spec.transport, state.backend, state.gate, deadline)

  defp dispatcher_drain(state, deadline) do
    with :ok <- Abyss.suspend(state.backend),
         :ok <- state.spec.handler.drain(state.dispatcher_owner, deadline),
         :ok <- Abyss.stop(state.backend, Lifecycle.remaining(deadline)) do
      if Process.alive?(state.dispatcher_owner),
        do: GenServer.stop(state.dispatcher_owner, :normal, Lifecycle.remaining(deadline)),
        else: :ok
    end
  end

  defp backend_control(operation, transport, backend) do
    host = if transport == :udp, do: Abyss, else: Hell
    apply(host, if(operation == :pause, do: :suspend, else: :resume), [backend])
  end

  defp transition(state, mode) do
    Telemetry.emit(:lifecycle, %{count: 1}, state.scope, %{state: mode})
    %{state | mode: mode}
  end

  defp local(%{mode: :stopped}), do: {:error, :stopped}
  defp local(%{spec: %{transport: :quic}} = state), do: Abyss.QUIC.local(state.backend)

  defp local(%{spec: %{transport: :udp}} = state) do
    case Abyss.Listener.for_server(state.backend) do
      [listener] -> Abyss.Listener.listener_info(listener)
      _ -> {:error, :not_ready}
    end
  end

  defp local(state), do: Hell.listener_info(state.backend)
  defp backend_status(%{mode: :stopped}), do: :stopped
  defp backend_status(%{spec: %{transport: :quic}}), do: :quic_connection_host

  defp backend_status(%{spec: %{transport: :udp}} = state) do
    case Abyss.Listener.for_server(state.backend) do
      [listener] -> Abyss.Listener.status(listener)
      _ -> :not_ready
    end
  end

  defp backend_status(_), do: :stream

  defp membership_list(%{spec: %{transport: :udp, mode: :multicast}} = state),
    do: Abyss.memberships(state.backend)

  defp membership_list(_), do: {:error, {:unsupported_capability, :memberships}}

  defp membership_change(
         %{spec: %{transport: :udp, mode: :multicast}, mode: mode} = state,
         operation,
         membership
       )
       when mode in [:ready, :paused] do
    with true <-
           Gaoxy.Config.valid_membership?(membership, state.spec.ip) ||
             {:error, :invalid_membership},
         {:ok, canonical} <- Abyss.Transport.UDP.Multicast.normalize_membership(membership) do
      current = Abyss.memberships(state.backend)

      if operation == :join and canonical not in current and
           length(current) >= state.spec.limits.max_memberships do
        {:error, :membership_limit}
      else
        apply(Abyss, operation, [state.backend, membership])
      end
    end
  end

  defp membership_change(_, _, _), do: {:error, {:unsupported_capability, :memberships}}

  defp start_backend(%{transport: :udp} = spec, context) do
    transport =
      case spec.mode do
        :unicast -> Abyss.Transport.UDP.Unicast
        :broadcast -> Abyss.Transport.UDP.Broadcast
        :multicast -> Abyss.Transport.UDP.Multicast
      end

    options =
      Enum.map(Map.get(spec.udp, :memberships, []), &{:add_membership, &1}) ++
        Map.to_list(Map.drop(spec.udp, [:memberships, :inet_backend]))

    options = [
      {:inet_backend, Map.get(spec.udp, :inet_backend, :inet)},
      if(tuple_size(spec.ip) == 8, do: :inet6, else: :inet),
      {:ip, spec.ip} | options
    ]

    host_options = [
      handler_module: Gaoxy.DatagramBridge,
      handler_options: context,
      port: spec.port,
      transport_module: transport,
      transport_options: options,
      num_listeners: 1,
      num_connections: spec.limits.max_active,
      max_packet_size: spec.limits.max_packet,
      admission_start_timeout: spec.limits.callback_timeout,
      read_timeout: spec.limits.idle_timeout,
      shutdown_timeout: spec.limits.drain_timeout,
      connection_telemetry_sample_rate: 1.0
    ]

    host_options =
      if spec.handler_mode == :datagram_dispatcher do
        Keyword.merge(host_options,
          datagram_dispatcher: {Gaoxy.DatagramDispatcherBridge, gaoxy: context},
          dispatcher_max_queue: spec.dispatcher.max_queue,
          dispatcher_max_queue_bytes: spec.dispatcher.max_bytes
        )
      else
        host_options
      end

    Abyss.start_link(host_options)
  end

  defp start_backend(%{transport: :quic} = spec, context) do
    with {:ok, tls} <- quic_credentials(spec.tls) do
      Abyss.QUIC.start_link(
        handler: {Gaoxy.QUICBridge, context},
        ip: spec.ip,
        port: spec.port,
        alpn: spec.quic.alpn,
        poll_interval: spec.quic.poll_interval,
        tls: tls,
        max_connections: spec.limits.max_active,
        init_timeout: spec.limits.callback_timeout,
        callback_timeout: spec.limits.callback_timeout,
        shutdown_timeout: spec.limits.drain_timeout,
        writer_timeout: spec.limits.callback_timeout,
        writer_max_queue: spec.limits.max_active,
        writer_max_bytes: spec.limits.max_bytes,
        quic_options: [
          streams: [
            max_data: spec.limits.max_bytes,
            max_stream_data: spec.limits.max_bytes,
            max_buffer: spec.limits.max_bytes,
            max_ready_bytes: spec.limits.max_bytes,
            max_streams_bidi: spec.limits.max_active,
            max_streams_uni: spec.limits.max_active,
            # The engine reserves both peer quotas before allocating local streams.
            max_stream_records: spec.limits.max_active * 3,
            max_recv_ranges: 128
          ]
        ]
      )
    end
  end

  defp start_backend(spec, context) do
    tls =
      if spec.transport == :tls do
        credentials = [
          certfile: spec.tls.certfile,
          keyfile: spec.tls.keyfile,
          versions: Map.get(spec.tls, :versions, [:"tlsv1.3"])
        ]

        credentials =
          credentials ++
            Map.to_list(Map.take(spec.tls, [:verify, :cacertfile, :fail_if_no_peer_cert]))

        case Map.get(spec.tls, :alpn, []) do
          [] -> credentials
          protocols -> [{:alpn_preferred_protocols, protocols} | credentials]
        end
      else
        []
      end

    Hell.start_link(
      handler_module:
        if(spec.handler_mode == :native, do: spec.handler, else: Gaoxy.StreamBridge),
      handler_options: context,
      port: spec.port,
      transport_module:
        if(spec.transport == :tls,
          do: Hell.Transports.SSL,
          else: Hell.Transports.TCP
        ),
      transport_options: [
        if(tuple_size(spec.ip) == 8, do: :inet6, else: :inet),
        {:ip, spec.ip},
        {:send_timeout, spec.limits.callback_timeout},
        {:send_timeout_close, true} | tls
      ],
      num_acceptors: 1,
      num_connections: spec.limits.max_active,
      max_connections_retry_count: 0,
      read_timeout: spec.limits.idle_timeout,
      handshake_timeout: spec.limits.callback_timeout,
      shutdown_timeout: spec.limits.drain_timeout
    )
  end

  defp quic_credentials(tls) do
    with {:ok, certificate} <- File.read(tls.certfile),
         {:ok, key} <- File.read(tls.keyfile),
         certificates when certificates != [] <-
           for(
             {:Certificate, der, :not_encrypted} <- :public_key.pem_decode(certificate),
             do: der
           ),
         [{type, der, :not_encrypted}] <- :public_key.pem_decode(key) do
      {:ok, [cert: certificates, key: {type, der}]}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_quic_credentials}
    end
  end
end
