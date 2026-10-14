defmodule Gaoxy.HTTP.Application do
  @moduledoc false
  use Application

  def start(_, _),
    do: Supervisor.start_link([{Task.Supervisor, name: Gaoxy.HTTP.Tasks}], strategy: :one_for_one)
end
