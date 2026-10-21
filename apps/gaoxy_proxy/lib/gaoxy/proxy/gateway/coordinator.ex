defmodule Gaoxy.Proxy.Gateway.Coordinator do
  @moduledoc false
  use GenServer
  require Logger
  alias Gaoxy.HTTP.Generation
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.{GroupEndpoint, UpstreamGroups, UpstreamTransports}
  alias Gaoxy.Proxy.Gateway.{Control, Declaration, Upstream}

  @transport_limits %{
    max_resources: 64,
    max_pins: 4096,
    max_request_tokens: 2048,
    max_owned_payload_bytes: 67_108_864
  }
  @cleanup_slice 100

  def child_spec(options),
    do: %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [options]},
      restart: :transient,
      shutdown:
        Gaoxy.Instance.drain_timeout(options.planned) +
          2 * Lifecycle.cleanup_headroom()
    }

  def start_link(context),
    do: GenServer.start_link(__MODULE__, context, name: context.coordinator)

  def activate(coordinator, store, expected, router, deadline) do
    Lifecycle.call(coordinator, {:activate, store, expected, router, deadline}, deadline)
  end

  @impl true
  def init(context) do
    Process.flag(:trap_exit, true)
    instance = GenServer.whereis(context.instance)
    epoch = make_ref()

    state = %{
      instance: instance,
      instance_monitor: Process.monitor(instance),
      transports: nil,
      groups: nil,
      monitors: %{},
      pending_pins: [],
      drain_timeout: Gaoxy.Instance.drain_timeout(context.planned),
      context: context,
      owner_supervisor: context.owners,
      epoch: epoch
    }

    deadline = Lifecycle.deadline(context.plan.startup_timeout)
    operation = make_ref()

    result =
      with :ok <- Control.recovering(context.control, epoch, deadline),
           {:ok, services, state} <- prepare_sets(state, operation, deadline),
           {:ok, _} <-
             Gaoxy.activate(instance, services,
               timeout: max(1, Lifecycle.remaining(deadline)),
               deadline: deadline,
               operation_id: operation
             ),
           :ok <- Control.ready(context.control, epoch, deadline),
           do: {:ok, state}

    case result do
      {:ok, state} ->
        {:ok, state}

      {:error, reason, failed} ->
        terminate(reason, failed)
        {:stop, reason}

      {:error, reason} ->
        terminate(reason, state)
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:activate, store, expected, router, deadline}, _from, state) do
    {result, state} = prepare_and_activate(store, expected, router, deadline, state)
    {:reply, result, state}
  end

  def handle_call({:reload, set_id, operation, revision, epoch, routes, deadline}, _, state) do
    store = state.context.stores[set_id]
    {result, state} = reload(store, operation, revision, epoch, routes, deadline, state)
    {:reply, result, state}
  end

  def handle_call(:cleanup_status, _, state),
    do: {:reply, %{preparation_pins: length(state.pending_pins)}, state}

  @impl true
  def handle_info(:reconcile_preparations, state) do
    {:noreply,
     release_preparations(state.pending_pins, state, Lifecycle.deadline(@cleanup_slice))}
  end

  def handle_info({:DOWN, ref, :process, _, reason}, state) do
    cond do
      ref == state.instance_monitor -> {:stop, :normal, state}
      Map.has_key?(state.monitors, ref) -> {:stop, {:upstream_owner_down, reason}, state}
      true -> {:noreply, state}
    end
  end

  # Bounded preparation workers are linked so owner loss also cancels them.
  # Their result/monitor has already been joined by Lifecycle.bounded/2.
  def handle_info({:EXIT, _, _}, state), do: {:noreply, state}

  @impl true
  def terminate(_, state) do
    deadline = Lifecycle.deadline(state.drain_timeout)
    release_preparations(state.pending_pins, state, deadline)

    # This child stops before UpstreamOwners. Drain registered participants
    # while their owners can still join the custodians they allocated.
    result = if Process.alive?(state.instance), do: stop_runtime(state, deadline), else: :ok

    if result not in [:ok, {:error, :not_running}],
      do: Logger.error("Gateway upstream shutdown remains unconfirmed: #{inspect(result)}")

    :ok
  end

  defp stop_runtime(state, deadline) do
    case Gaoxy.stop(state.instance, Lifecycle.remaining(deadline)) do
      {:error, :stopping} ->
        # An explicit stop may already own the drain. Keep upstream owners
        # alive until that operation finishes, within the same shutdown budget.
        receive do
          {:DOWN, ref, :process, instance, _}
          when ref == state.instance_monitor and instance == state.instance ->
            :ok
        after
          Lifecycle.remaining(deadline) -> {:error, {:deadline_exceeded, :cleanup_pending}}
        end

      result ->
        result
    end
  end

  defp prepare_sets(state, operation, deadline) do
    Enum.reduce_while(state.context.plan.sets, {:ok, state.context.plan.services, state}, fn set,
                                                                                             {:ok,
                                                                                              specs,
                                                                                              state} ->
      store = state.context.stores[set.id]

      result =
        with :ok <-
               Generation.begin_epoch(store, state.epoch, max(1, Lifecycle.remaining(deadline))),
             {:ok, accepted} <- Generation.accepted(store, max(1, Lifecycle.remaining(deadline))),
             routes = accepted.declaration || set.routes,
             {:ok, routes} <- bounded_prepare(fn -> Declaration.materialize(routes) end, deadline) do
          {result, state} = resolve_and_compile(store, routes, state, deadline)

          case result do
            {:ok, router, pins} ->
              result =
                with {:ok, _} <-
                       Generation.materialize(store, state.epoch, router, routes, deadline),
                     {:ok, services} <-
                       bounded_prepare(
                         fn -> prepare_listeners(set, store, state, operation) end,
                         deadline
                       ),
                     do: {:ok, services}

              state = release_preparations(pins, state, deadline)

              case result do
                {:ok, services} -> {:ok, services, state}
                {:error, reason} -> {:error, reason, state}
              end

            {:error, reason, pins} ->
              {:error, reason, release_preparations(pins, state, deadline)}
          end
        end

      case result do
        {:ok, services, next} -> {:cont, {:ok, specs ++ services, next}}
        {:error, reason, failed} -> {:halt, {:error, reason, failed}}
        {:error, reason} -> {:halt, {:error, reason, state}}
      end
    end)
  end

  defp prepare_listeners(%{listener: nil, service: spec}, store, _state, _operation) do
    with {:ok, endpoint} <- Generation.init(store),
         spec = %{
           spec
           | handler_options:
               Map.merge(spec.handler_options, %{
                 endpoint: {Generation, endpoint},
                 initialized: true
               })
         },
         {:ok, spec} <- Gaoxy.Config.service(spec),
         do: {:ok, [spec]}
  end

  defp prepare_listeners(%{listener: plan}, store, state, operation) do
    control = state.context.control

    Gaoxy.HTTP.ListenerSet.prepare(plan,
      target: {Generation, store},
      instance: state.instance,
      activation_id: operation,
      discovery_guard: fn -> Control.phase(control) == :ready end
    )
  end

  defp resolve_and_compile(store, routes, state, deadline) do
    case resolve(routes, state, deadline) do
      {:ok, resolved, pins, state} ->
        # Generation's owned, finite preparation worker contains user init calls.
        case Generation.prepare(
               store,
               Enum.map(resolved, &route_input/1),
               max(1, Lifecycle.remaining(deadline))
             ) do
          {:ok, router} -> {{:ok, router, pins}, state}
          {:error, reason} -> {{:error, reason, pins}, state}
        end

      {:error, reason, pins, state} ->
        {{:error, reason, pins}, state}
    end
  end

  defp reload(store, operation, _, _, _, _, %{pending_pins: [_ | _]} = state) do
    Generation.reject(store, operation, :resource_release_pending)
    {{:error, :resource_release_pending}, state}
  end

  defp reload(store, operation, revision, epoch, routes, deadline, state) do
    with {:ok, accepted} <- bounded_prepare(fn -> Declaration.materialize(routes) end, deadline) do
      {result, state} = resolve_and_compile(store, accepted, state, deadline)

      case result do
        {:ok, router, pins} ->
          result =
            Generation.commit(store, operation, revision, epoch, router, accepted, deadline)

          {result, release_preparations(pins, state, deadline)}

        {:error, reason, pins} ->
          Generation.reject(store, operation, reason)
          {{:error, reason}, release_preparations(pins, state, deadline)}
      end
    else
      {:error, reason} ->
        Generation.reject(store, operation, reason)
        {{:error, reason}, state}
    end
  end

  defp prepare_and_activate(_, _, _, _, %{pending_pins: [_ | _]} = state),
    do: {{:error, :resource_release_pending}, state}

  defp prepare_and_activate(store, expected, router, deadline, state) do
    case resolve(router.routes, state, deadline) do
      {:ok, routes, pins, state} ->
        declaration = Enum.map(router.routes, &route_input/1)
        operation = make_ref()

        result =
          with {:ok, accepted} <-
                 Generation.accepted(store, max(1, Lifecycle.remaining(deadline))),
               true <- accepted.generation == expected || {:error, :stale_generation},
               {:ok, :admitted} <-
                 Generation.admit(store, operation, accepted.revision, declaration, deadline),
               {:ok, resolved} <-
                 Generation.prepare(
                   store,
                   Enum.map(routes, &route_input/1),
                   max(1, Lifecycle.remaining(deadline))
                 ),
               {:ok, %{generation: generation}} <-
                 Generation.commit(
                   store,
                   operation,
                   accepted.revision,
                   state.epoch,
                   resolved,
                   declaration,
                   deadline
                 ),
               do: {:ok, generation}

        if match?({:error, _}, result), do: Generation.reject(store, operation, elem(result, 1))

        {result, release_preparations(pins, state, deadline)}

      {:error, reason, pins, state} ->
        {{:error, reason}, release_preparations(pins, state, deadline)}
    end
  end

  defp route_input(route) do
    route
    |> Map.update(:path, :any, fn
      {:exact, path} -> path
      path -> path
    end)
    |> Map.update(:methods, :any, fn
      %MapSet{} = methods -> Enum.sort(methods)
      methods -> methods
    end)
  end

  defp release_preparations(pins, state, deadline) do
    deadline = min(deadline, Lifecycle.deadline(@cleanup_slice))

    pending =
      Enum.reject(Enum.uniq(state.pending_pins ++ pins), fn pin ->
        Lifecycle.protect(fn -> pin.provider.release(pin, deadline) end) == :ok
      end)

    if pending != [], do: Process.send_after(self(), :reconcile_preparations, @cleanup_slice)
    %{state | pending_pins: pending}
  end

  # Only owner-independent file material and finalized listener specifications
  # cross this worker. Upstream preparation and its pins stay with this owner.
  defp bounded_prepare(fun, deadline) do
    if Lifecycle.remaining(deadline) > 0,
      do: Lifecycle.bounded(fun, Lifecycle.remaining(deadline)),
      else: {:error, :preparation_timeout}
  end

  defp resolve(routes, state, deadline) do
    Enum.reduce_while(routes, {:ok, [], [], state}, fn route, {:ok, acc, pins, state} ->
      case resolve_target(route.target, state, deadline) do
        {:ok, target, acquired, state} ->
          {:cont, {:ok, [Map.put(route, :target, target) | acc], acquired ++ pins, state}}

        {:error, reason, acquired, state} ->
          {:halt, {:error, reason, acquired ++ pins, state}}
      end
    end)
    |> case do
      {:ok, routes, pins, state} -> {:ok, Enum.reverse(routes), pins, state}
      error -> error
    end
  end

  defp resolve_target(
         {_module, %Upstream{kind: :fixed, options: source}},
         state,
         deadline
       ) do
    with {:ok, state} <- owners(state) do
      case prepare_member(source, state, deadline) do
        {:ok, config, pins} -> {:ok, {Gaoxy.Proxy.HTTP, config}, pins, state}
        {:error, reason, pins} -> {:error, reason, pins, state}
      end
    else
      {:error, reason} -> {:error, reason, [], state}
    end
  end

  defp resolve_target(
         {_module, %Upstream{kind: :group, options: options}},
         state,
         deadline
       ) do
    with {:ok, state} <- owners(state) do
      case prepare_members(options.members, state, deadline) do
        {:ok, members, pins} ->
          result =
            with {:ok, group} <-
                   UpstreamGroups.compile(
                     Map.merge(Map.drop(options, [:limits]), %{members: members})
                   ),
                 {:ok, handle, acquired} <-
                   UpstreamGroups.prepare(state.groups, group, self(), deadline) do
              case GroupEndpoint.init(Map.put(options.limits, :group, handle)) do
                {:ok, config} -> {:ok, {GroupEndpoint, config}, acquired ++ pins, state}
                {:error, reason} -> {:error, reason, acquired ++ pins, state}
              end
            end

          case result do
            {:error, reason} -> {:error, reason, pins, state}
            result -> result
          end

        {:error, reason, pins} ->
          {:error, reason, pins, state}
      end
    else
      {:error, reason} -> {:error, reason, [], state}
    end
  end

  defp resolve_target(target, state, _), do: {:ok, target, [], state}

  defp prepare_member(member, state, deadline) do
    case UpstreamTransports.prepare(state.transports, member.source, self(), deadline) do
      {:ok, handle, pins} ->
        case Gaoxy.Proxy.HTTP.init(Map.put(member.endpoint, :transport, handle)) do
          {:ok, config} -> {:ok, config, pins}
          {:error, reason} -> {:error, reason, pins}
        end

      {:error, reason} ->
        {:error, reason, []}
    end
  end

  defp prepare_members(members, state, deadline) do
    Enum.reduce_while(members, {:ok, [], []}, fn member, {:ok, acc, pins} ->
      case prepare_member(member, state, deadline) do
        {:ok, config, acquired} ->
          options =
            Map.merge(member.endpoint, %{
              id: member.id,
              max_inflight: member.max_inflight,
              transport: config.transport
            })

          {:cont, {:ok, [options | acc], acquired ++ pins}}

        {:error, reason, acquired} ->
          {:halt, {:error, reason, acquired ++ pins}}
      end
    end)
    |> case do
      {:ok, members, pins} -> {:ok, Enum.reverse(members), pins}
      error -> error
    end
  end

  defp owners(%{transports: pid} = state) when is_pid(pid), do: {:ok, state}

  defp owners(state) do
    with {:ok, transports} <-
           DynamicSupervisor.start_child(
             state.owner_supervisor,
             {UpstreamTransports, instance: state.instance, limits: @transport_limits}
           ),
         {:ok, groups} <-
           DynamicSupervisor.start_child(
             state.owner_supervisor,
             {UpstreamGroups, instance: state.instance}
           ) do
      monitors = Map.new([transports, groups], &{Process.monitor(&1), &1})
      {:ok, %{state | transports: transports, groups: groups, monitors: monitors}}
    end
  end
end
