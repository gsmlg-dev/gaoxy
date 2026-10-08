defmodule GaoxyProxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :gaoxy_proxy,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      deps: [{:gaoxy, in_umbrella: true}, {:gaoxy_http, in_umbrella: true}]
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
