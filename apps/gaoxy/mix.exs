defmodule Gaoxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :gaoxy,
      version: "0.5.5",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      deps: [
        {:hell,
         git: "https://github.com/gsmlg-dev/hell.git",
         ref: "59eed42b019ca41413d1b8cd7a7dc3e344bb93ee"},
        {:abyss, "== 0.9.0"},
        {:telemetry, "~> 1.3"}
      ]
    ]
  end

  def application, do: [mod: {Gaoxy.Application, []}, extra_applications: [:logger, :ssl]]
end
