defmodule GaoxyHttp.MixProject do
  use Mix.Project

  def project do
    [
      app: :gaoxy_http,
      version: "0.16.1",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      deps: [
        {:gaoxy, in_umbrella: true},
        {:plug, "~> 1.20"},
        {:http_core, "~> 1.0.0-rc.16"},
        {:websock, "~> 0.5"},
        {:websock_adapter, path: "../../vendor/websock_adapter", override: true}
      ]
    ]
  end

  def application, do: [extra_applications: [:logger], mod: {Gaoxy.HTTP.Application, []}]
end
