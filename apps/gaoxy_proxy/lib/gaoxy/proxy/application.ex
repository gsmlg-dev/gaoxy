defmodule Gaoxy.Proxy.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [
        {Registry, keys: :unique, name: Gaoxy.Proxy.Gateway.Registry},
        {Task.Supervisor, name: Gaoxy.Proxy.Gateway.Operations},
        {DynamicSupervisor, strategy: :one_for_one, name: Gaoxy.Proxy.SessionSupervisor},
        Supervisor.child_spec(
          {DynamicSupervisor, strategy: :one_for_one, name: Gaoxy.Proxy.ProbeSupervisor},
          id: Gaoxy.Proxy.ProbeSupervisor
        )
      ],
      strategy: :one_for_one,
      name: Gaoxy.Proxy.Supervisor
    )
  end
end
