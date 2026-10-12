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
        {:elixir_quic, "== 0.21.4"},
        {:ex_ssl, "== 0.21.4", override: true}
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
