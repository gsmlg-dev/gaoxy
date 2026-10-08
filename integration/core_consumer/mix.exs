defmodule CoreConsumer.MixProject do
  use Mix.Project

  def project do
    [
      app: :core_consumer,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: [{:gaoxy, path: "../../apps/gaoxy"}]
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
