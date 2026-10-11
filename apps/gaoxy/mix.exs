defmodule Gaoxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :gaoxy,
      version: "0.2.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      deps: [
        {:thousand_island,
         git: "https://github.com/mtrudel/thousand_island.git",
         ref: "6146e1bfdd1a85c5c16c3c92ad98ff5f11066820"},
        {:abyss,
         git: "https://github.com/gsmlg-dev/abyss.git",
         ref: "9b710e6480900e16e304f40e63623aff8c922e19"},
        {:telemetry, "~> 1.3"}
      ]
    ]
  end

  def application, do: [mod: {Gaoxy.Application, []}, extra_applications: [:logger, :ssl]]
end
