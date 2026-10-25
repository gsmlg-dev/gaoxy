defmodule PublicReleaseConsumer.MixProject do
  use Mix.Project
  def project do
    [app: :phoenix_native, version: "0.1.0", elixir: "~> 1.18",
     elixirc_paths: ["lib"], deps: [
      {:gaoxy, "== 0.13.0", override: true},
      {:gaoxy_http, "== 0.13.0"},
      {:websock_adapter, "== 0.13.0", hex: :gaoxy_websock_adapter, override: true},
      {:phoenix, "== 1.8.16"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:jason, "~> 1.4"}
    ]]
  end
  def application, do: [mod: {PhoenixNative.Application, []}, extra_applications: [:logger, :ssl]]
end
