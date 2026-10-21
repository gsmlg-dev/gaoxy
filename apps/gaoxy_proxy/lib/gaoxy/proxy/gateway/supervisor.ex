defmodule Gaoxy.Proxy.Gateway.Supervisor do
  @moduledoc false
  use Supervisor
  alias Gaoxy.HTTP.Generation
  alias Gaoxy.Proxy.Gateway.{Control, RuntimeSupervisor}

  def start_link({plan, planned, host}) do
    name = Keyword.get(host, :name, plan.name)
    token = make_ref()
    previous = Process.flag(:trap_exit, true)

    try do
      result =
        Supervisor.start_link(
          __MODULE__,
          {plan, planned, host, self(), token},
          if(name, do: [name: name], else: [])
        )

      root =
        receive do
          {:gateway_starting, ^token, root} -> root
        after
          0 -> nil
        end

      # Keep the real caller as the OTP parent. A separate startup custodian
      # would make later host-supervisor shutdown signals an unknown-child EXIT.
      # Only the failed root's startup EXIT is consumed here.
      if match?({:error, _}, result) and is_pid(root) do
        receive do
          {:EXIT, ^root, _} -> :ok
        after
          # proc_lib may already have unlinked/flushed this EXIT before the
          # supported Supervisor.start_link/3 call returned its startup error.
          0 -> :ok
        end
      end

      result
    after
      Process.flag(:trap_exit, previous)
      unless previous, do: replay_untrapped_exits()
    end
  end

  @impl true
  def init({plan, planned, host, caller, token}) do
    send(caller, {:gateway_starting, token, self()})
    token = make_ref()
    via = fn role -> {:via, Registry, {Gaoxy.Proxy.Gateway.Registry, {token, role}}} end

    stores =
      Map.new(plan.sets, fn set ->
        name =
          case host[:store_registry] do
            nil -> via.({:store, set.id})
            registry -> {:via, Registry, {registry, set.id, profile(set)}}
          end

        {set.id, name}
      end)

    context = %{
      plan: plan,
      planned: planned,
      root: self(),
      control: via.(:control),
      instance: Keyword.get(host, :runtime_name, via.(:instance)),
      owners: Keyword.get(host, :owner_name, via.(:owners)),
      coordinator: Keyword.get(host, :coordinator_name, via.(:coordinator)),
      stores: stores,
      host: host
    }

    {:ok, _} =
      Registry.register(Gaoxy.Proxy.Gateway.Registry, {:control_of, self()}, context.control)

    registry =
      if host[:store_registry],
        do: [{Registry, keys: :unique, name: host[:store_registry]}],
        else: []

    generations =
      Enum.map(plan.sets, fn set ->
        Supervisor.child_spec({Generation, name: stores[set.id]}, id: {:routes, set.id})
      end)

    runtime =
      Supervisor.child_spec({RuntimeSupervisor, context},
        id: Keyword.get(host, :runtime_group_id, RuntimeSupervisor)
      )

    Supervisor.init(registry ++ [{Control, context}] ++ generations ++ [runtime],
      strategy: :rest_for_one
    )
  end

  defp replay_untrapped_exits do
    receive do
      {:EXIT, _, :normal} -> replay_untrapped_exits()
      {:EXIT, _, reason} -> Process.exit(self(), reason)
    after
      0 -> :ok
    end
  end

  defp profile(%{service: nil}), do: nil

  defp profile(%{service: %{handler: handler, handler_options: options}}) do
    profile = Map.take(options, [:protocols, :http_limits])

    if handler == Gaoxy.HTTP.HTTP3.Connection,
      do: Map.put(profile, :protocols, [:http3]),
      else: profile
  end
end

defmodule Gaoxy.Proxy.Gateway.RuntimeSupervisor do
  @moduledoc false
  use Supervisor
  alias Gaoxy.Proxy.Gateway.Coordinator
  def start_link(context), do: Supervisor.start_link(__MODULE__, context)
  @impl true
  def init(context) do
    instance = {Gaoxy, name: context.instance, services: context.planned, activation: :deferred}
    owners = {DynamicSupervisor, strategy: :one_for_one, name: context.owners}

    coordinator =
      Supervisor.child_spec({Coordinator, context},
        id: Keyword.get(context.host, :coordinator_id, Coordinator)
      )

    Supervisor.init([instance, owners, coordinator], strategy: :one_for_all)
  end
end
