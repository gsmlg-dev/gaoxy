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
      # TODO(upstream): gsmlg-dev/http_fetch#27 - transparent raw response bytes.
      # TODO(upstream): gsmlg-dev/http_fetch#28 - responses before upload EOF.
      # TODO(upstream): gsmlg-dev/http_fetch#29 - bounded H1 trailer metadata.
      # TODO(upstream): gsmlg-dev/http_fetch#30 - public upgrade tunnel ownership.
      # Add the upstream client only after these required contracts are available.
      deps: [{:gaoxy, in_umbrella: true}, {:gaoxy_http, in_umbrella: true}]
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
