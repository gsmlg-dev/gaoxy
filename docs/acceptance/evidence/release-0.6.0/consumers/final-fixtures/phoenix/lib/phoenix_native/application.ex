defmodule PhoenixNative.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: PhoenixNative.PubSub},
      PhoenixNative.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: PhoenixNative.Supervisor)
  end
end
