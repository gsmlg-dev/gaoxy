defmodule H3Consumer.MixProject do
  use Mix.Project

  def project do
    [
      app: :h3_consumer,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: [
        {:gaoxy, path: "../../apps/gaoxy", override: true},
        {:gaoxy_http, path: "../../apps/gaoxy_http", override: true},
        {:gaoxy_http3, path: "../../apps/gaoxy_http3"},
        {:elixir_quic, "~> 1.0.0-rc.16"},
        {:ex_ssl, "~> 1.0.0-rc.16", override: true}
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
