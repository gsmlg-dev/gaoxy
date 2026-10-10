defmodule GaoxyHttp.MixProject do
  use Mix.Project

  def project do
    [
      app: :gaoxy_http,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      deps: [
        {:gaoxy, in_umbrella: true},
        {:plug, "== 1.20.3"},
        {:hpax, "== 1.1.0"},
        {:websock, "== 0.5.3"},
        {:websock_adapter, path: "../../vendor/websock_adapter", override: true}
      ]
    ]
  end

  def application, do: [extra_applications: [:logger], mod: {Gaoxy.HTTP.Application, []}]
end
