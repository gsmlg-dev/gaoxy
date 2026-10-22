defmodule Gaoxy.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.12.1",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      package: [licenses: ["MIT"]],
      deps: [],
      releases: [gaoxy: [applications: [gaoxy_server: :permanent]]]
    ]
  end
end
