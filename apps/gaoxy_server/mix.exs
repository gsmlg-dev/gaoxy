defmodule GaoxyServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :gaoxy_server,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      deps: [{:gaoxy, in_umbrella: true}]
    ]
  end

  def application, do: [mod: {Gaoxy.Server.Application, []}, extra_applications: [:logger]]
end
