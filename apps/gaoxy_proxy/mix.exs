defmodule GaoxyProxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :gaoxy_proxy,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      deps: [
        {:gaoxy, in_umbrella: true},
        {:gaoxy_http, in_umbrella: true},
        # TODO(upstream): gsmlg-dev/http_fetch#45 - preserve forwarded request bodies.
        {:http_fetch, "== 0.17.2"},
        # TODO(upstream): gsmlg-dev/http_fetch#38 - propagate valid WebSocket close codes.
        {:http_web_socket, "== 0.17.2"}
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
