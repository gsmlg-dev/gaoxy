defmodule PhoenixNative.MixProject do
  use Mix.Project
  def project, do: [app: :phoenix_native, version: "0.1.0", elixir: "~> 1.18", deps: [
      {:gaoxy_http, "== 0.6.0"},
      {:websock_adapter, "== 0.6.0", hex: :gaoxy_websock_adapter, override: true},
      {:phoenix, "== 1.8.16"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:jason, "~> 1.4"}
    ], elixirc_paths: ["lib"], listeners: [Phoenix.CodeReloader]]
  def application, do: [mod: {PhoenixNative.Application, []}, extra_applications: [:logger, :ssl]]
end
