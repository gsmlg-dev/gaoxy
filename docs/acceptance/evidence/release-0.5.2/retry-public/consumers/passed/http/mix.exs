defmodule HTTPConsumer.MixProject do
  use Mix.Project
  def project, do: [app: :http_consumer, version: "0.1.0", elixir: "~> 1.18", deps: [{:gaoxy_http, "== 0.5.2"}]]
  def application, do: [extra_applications: [:logger]]
end
