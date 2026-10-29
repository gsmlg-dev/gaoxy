defmodule Gaoxy.ResourceBudget.Supervisor do
  @moduledoc false
  use Supervisor
  def start_link(options \\ []), do: Supervisor.start_link(__MODULE__, options)
  @impl true
  def init(options) do
    identity = Keyword.get(options, :identity, :gaoxy)
    options = Keyword.put(options, :identity, identity)

    Supervisor.init(
      [
        {Gaoxy.ResourceBudget.Ledger, options},
        {Gaoxy.ResourceBudget.Authority, options},
        {Gaoxy.ResourceBudget.Sampler, options}
      ],
      strategy: :one_for_one
    )
  end

  def name(module, identity), do: {:global, {node(), module, identity}}
end
