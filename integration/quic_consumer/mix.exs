defmodule GaoxyQUICConsumer.MixProject do
  use Mix.Project

  def project do
    [
      app: :gaoxy_quic_consumer,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: [
        {:gaoxy, path: "../../apps/gaoxy"},
        {:elixir_quic, "== 0.21.4"},
        {:ex_ssl, "== 0.21.4", override: true}
      ]
    ]
  end

  def application, do: [extra_applications: [:gaoxy, :elixir_quic]]
end
