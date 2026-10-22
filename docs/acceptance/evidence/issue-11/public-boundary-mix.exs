defmodule PublicBoundary.MixProject do
  use Mix.Project
  def project do
    [app: :public_boundary, version: "0.1.0", elixir: "~> 1.18",
     deps: [{:gaoxy_http, "== 0.11.1"}]]
  end
  def application, do: [extra_applications: [:logger]]
end
