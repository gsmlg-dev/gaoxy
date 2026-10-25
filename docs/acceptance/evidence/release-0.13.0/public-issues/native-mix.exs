defmodule PublicReleaseConsumer.MixProject do
  use Mix.Project
  def project do
    [app: :public_native_consumer, version: "0.1.0", elixir: "~> 1.18",
     elixirc_paths: ["lib"], deps: [
      {:gaoxy, "== 0.13.0", override: true},
      {:gaoxy_http, "== 0.13.0"},
      {:websock_adapter, "== 0.13.0", hex: :gaoxy_websock_adapter, override: true}
    ]]
  end
  def application, do: [extra_applications: [:logger, :ssl]]
end
