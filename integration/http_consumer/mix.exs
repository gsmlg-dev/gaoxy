defmodule HTTPConsumer.MixProject do
  use Mix.Project

  def project do
    [
      app: :http_consumer,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: [
        {:gaoxy, path: "../../apps/gaoxy", override: true},
        {:gaoxy_http, path: "../../apps/gaoxy_http"}
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
