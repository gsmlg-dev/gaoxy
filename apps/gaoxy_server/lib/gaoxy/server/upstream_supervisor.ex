defmodule Gaoxy.Server.UpstreamSupervisor do
  @moduledoc false
  use Supervisor

  def start_link(options), do: Supervisor.start_link(__MODULE__, options)

  @impl true
  def init(options) do
    runtime_options = [name: Gaoxy.Server.Runtime, services: Keyword.fetch!(options, :services)]

    runtime =
      runtime_options
      |> Gaoxy.child_spec()
      |> Map.put(:start, {__MODULE__, :start_runtime, [runtime_options]})

    children = [
      runtime,
      {DynamicSupervisor, strategy: :one_for_one, name: Gaoxy.Server.UpstreamOwners},
      {Gaoxy.Server.RouteResources, options}
    ]

    # A resource-owner failure invalidates instance-bound handles. Restart the
    # complete runtime together before making a listener available again.
    Supervisor.init(children, strategy: :one_for_all)
  end

  @doc false
  def start_runtime(options) do
    with {:ok, plan} <- Gaoxy.Config.validate(options),
         do: Gaoxy.Instance.start_link(Map.put(plan, :defer_services, true))
  end
end
