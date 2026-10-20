defmodule Gaoxy.Server.RouteResources do
  @moduledoc false
  use GenServer
  require Logger
  alias Gaoxy.HTTP.{Generation, Router}
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.{GroupEndpoint, UpstreamGroups, UpstreamTransports}
  alias Gaoxy.Server.{Supervisor, UpstreamEndpoint}

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
        Gaoxy.Instance.drain_timeout(options[:services]) +
          2 * Lifecycle.cleanup_headroom()
    }

  def start_link(options), do: GenServer.start_link(__MODULE__, options, name: __MODULE__)

  def activate(store, expected, router, deadline) do
    Lifecycle.call(__MODULE__, {:activate, store, expected, router, deadline}, deadline)
  end

  @impl true
  def init(options) do
    Process.flag(:trap_exit, true)
    instance = Process.whereis(Gaoxy.Server.Runtime)

    state = %{
      instance: instance,
      instance_monitor: Process.monitor(instance),
      transports: nil,
      groups: nil,
      monitors: %{},
      pending_pins: [],
      drain_timeout: Gaoxy.Instance.drain_timeout(options[:services])
    }

    deadline = Lifecycle.deadline(5000)

    Enum.reduce_while(options[:services], {:ok, state}, fn spec, {:ok, state} ->
      case install(spec, state, deadline) do
        {:ok, state} ->
          {:cont, {:ok, state}}

        {:error, reason, state} ->
          terminate(reason, state)
          {:halt, {:stop, reason}}
      end
    end)
  end

  @impl true
  def handle_call({:activate, store, expected, router, deadline}, _from, state) do
    {result, state} = prepare_and_activate(store, expected, router, deadline, state)
    {:reply, result, state}
  end

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

  @impl true
  def terminate(_, state) do
    deadline = Lifecycle.deadline(state.drain_timeout)
    release_preparations(state.pending_pins, state, deadline)

    # This child stops before UpstreamOwners. Drain registered participants
    # while their owners can still join the custodians they allocated.
    result = if Process.alive?(state.instance), do: stop_runtime(state, deadline), else: :ok

    if result not in [:ok, {:error, :not_running}],
      do: Logger.error("Standalone upstream shutdown remains unconfirmed: #{inspect(result)}")

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

  defp install(%{handler_options: %{endpoint: {Router, _router}}} = spec, state, deadline) do
    store = Supervisor.route_store(spec.id)

    with {:ok, expected, router} <-
           Generation.declared_snapshot(store, Lifecycle.remaining(deadline)) do
      case prepare_and_activate(store, expected, router, deadline, state) do
        {{:ok, _}, state} ->
          options = %{spec.handler_options | endpoint: {Generation, store}, initialized: false}
          spec = %{spec | handler_options: options}

          with {:ok, spec} <- Supervisor.initialize_generation(spec),
               {:ok, _} <- Gaoxy.add(state.instance, spec) do
            {:ok, state}
          else
            {:error, reason} -> {:error, reason, state}
          end

        {{:error, reason}, state} ->
          {:error, reason, state}
      end
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp install(spec, state, _deadline) do
    case Gaoxy.add(state.instance, spec) do
      {:ok, _} -> {:ok, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp prepare_and_activate(_, _, _, _, %{pending_pins: [_ | _]} = state),
    do: {{:error, :resource_release_pending}, state}

  defp prepare_and_activate(store, expected, router, deadline, state) do
    case resolve(router.routes, state, deadline) do
      {:ok, routes, pins, state} ->
        result =
          with {:ok, resolved} <- Router.compile(Enum.map(routes, &route_input/1)),
               do:
                 Generation.activate_declared(
                   store,
                   expected,
                   resolved,
                   router,
                   Lifecycle.remaining(deadline)
                 )

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
      Enum.reject(pins, fn pin ->
        Lifecycle.protect(fn -> pin.provider.release(pin, deadline) end) == :ok
      end)

    if pending != [], do: Process.send_after(self(), :reconcile_preparations, @cleanup_slice)
    %{state | pending_pins: pending}
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
         {UpstreamEndpoint, %UpstreamEndpoint{kind: :fixed, options: source}},
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
         {UpstreamEndpoint, %UpstreamEndpoint{kind: :group, options: options}},
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
             Gaoxy.Server.UpstreamOwners,
             {UpstreamTransports, instance: state.instance, limits: @transport_limits}
           ),
         {:ok, groups} <-
           DynamicSupervisor.start_child(
             Gaoxy.Server.UpstreamOwners,
             {UpstreamGroups, instance: state.instance}
           ) do
      monitors = Map.new([transports, groups], &{Process.monitor(&1), &1})
      {:ok, %{state | transports: transports, groups: groups, monitors: monitors}}
    end
  end
end
