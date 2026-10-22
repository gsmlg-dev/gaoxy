defmodule PeerCloseConsumer.MixProject do
  use Mix.Project
  def project, do: [app: :peer_close_consumer, version: "0.1.0", elixir: "~> 1.18",
                    deps: [{:gaoxy_http, "== 0.12.2"}]]
  def application, do: [extra_applications: [:logger, :ssl]]
end
