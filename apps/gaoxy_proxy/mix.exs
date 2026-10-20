defmodule GaoxyProxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :gaoxy_proxy,
      version: "0.5.3",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      deps: [
        {:gaoxy, in_umbrella: true},
        {:gaoxy_http, in_umbrella: true},
        {:http_fetch, "== 0.21.10"},
        {:http_web_socket, "== 0.21.10"}
      ]
    ]
  end

  def application, do: [extra_applications: [:logger], mod: {Gaoxy.Proxy.Application, []}]
end
