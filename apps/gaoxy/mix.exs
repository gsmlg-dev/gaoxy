defmodule Gaoxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :gaoxy,
      version: "0.13.1",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      deps: [
        {:hell,
         git: "https://github.com/gsmlg-dev/hell.git",
         ref: "4fb5d53a1b2acfb5afc9b1ceba65fdc52d61ef83"},
        {:abyss, "== 0.10.0"},
        {:telemetry, "~> 1.3"}
      ]
    ]
  end

  def application, do: [mod: {Gaoxy.Application, []}, extra_applications: [:logger, :ssl]]
end
