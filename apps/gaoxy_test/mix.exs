defmodule GaoxyTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :gaoxy_test,
      version: "0.11.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      description: "Isolated HTTP test fixtures and request expectations for Gaoxy",
      package: [
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/gsmlg-dev/gaoxy"},
        files: ["lib", "priv", "mix.exs", "README.md", "LICENSE"]
      ],
      deps: [
        {:gaoxy_http, in_umbrella: true},
        {:gaoxy_http3, in_umbrella: true, optional: true},
        {:plug, "== 1.20.3"}
      ]
    ]
  end

  def application, do: [extra_applications: [:logger], mod: {Gaoxy.Test.Application, []}]
end
