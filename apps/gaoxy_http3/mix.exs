defmodule GaoxyHttp3.MixProject do
  use Mix.Project

  def project do
    [
      app: :gaoxy_http3,
      version: "0.2.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      deps: [
        {:gaoxy_http, in_umbrella: true},
        {:elixir_quic_http3, "== 0.21.4"}
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
