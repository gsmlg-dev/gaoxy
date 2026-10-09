defmodule PhoenixNative.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_native,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: ["lib"],
      listeners: [Phoenix.CodeReloader],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [mod: {PhoenixNative.Application, []}, extra_applications: [:logger, :ssl]]
  end

  defp deps do
    [
      {:gaoxy, path: "../../apps/gaoxy", override: true},
      {:gaoxy_http, path: "../../apps/gaoxy_http"},
      {:websock_adapter, path: "../../vendor/websock_adapter", override: true},
      {:phoenix, "== 1.8.15"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:jason, "~> 1.4"}
    ]
  end
end
