defmodule H3GatewayConsumer.MixProject do
  use Mix.Project

  def project do
    [
      app: :h3_gateway_consumer,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: [
        {:gaoxy, path: "../../apps/gaoxy", override: true},
        {:gaoxy_http, path: "../../apps/gaoxy_http", override: true},
        {:gaoxy_proxy, path: "../../apps/gaoxy_proxy"},
        {:gaoxy_http3, path: "../../apps/gaoxy_http3"}
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
