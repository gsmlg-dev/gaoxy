defmodule Gaoxy.Test.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [{DynamicSupervisor, strategy: :one_for_one, name: Gaoxy.Test.Supervisor}],
      strategy: :one_for_one
    )
  end
end
