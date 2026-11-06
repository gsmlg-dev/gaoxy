defmodule Gaoxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :gaoxy,
      version: "0.14.1",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      deps: [
        {:hell, "== 1.0.0-rc.4"},
        {:abyss, "== 1.0.0-rc.4"},
        {:telemetry, "~> 1.3"}
      ]
    ]
  end

  def application,
    do: [mod: {Gaoxy.Application, []}, extra_applications: [:logger, :ssl, :os_mon]]
end
