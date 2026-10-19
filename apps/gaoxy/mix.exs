defmodule Gaoxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :gaoxy,
      version: "0.5.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      deps: [
        {:hell,
         git: "https://github.com/gsmlg-dev/hell.git",
         ref: "59eed42b019ca41413d1b8cd7a7dc3e344bb93ee"},
        {:abyss,
         git: "https://github.com/gsmlg-dev/abyss.git",
         ref: "9b710e6480900e16e304f40e63623aff8c922e19"},
        {:telemetry, "~> 1.3"}
      ]
    ]
  end

  def application, do: [mod: {Gaoxy.Application, []}, extra_applications: [:logger, :ssl]]
end
