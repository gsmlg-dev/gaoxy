defmodule GaoxyTestHTTPFetchConsumer.MixProject do
  use Mix.Project

  def project do
    [app: :gaoxy_test_http_fetch_consumer, version: "0.1.0", elixir: "~> 1.18", deps: deps()]
  end

  def application, do: [extra_applications: [:logger, :ssl]]

  defp deps do
    fixtures =
      case System.get_env("GAOXY_TEST_PACKAGES") do
        nil ->
          [{:gaoxy_test, "== " <> System.fetch_env!("GAOXY_TEST_VERSION"), only: :test}]

        directory ->
          [
            {:gaoxy_test, path: Path.join(directory, "gaoxy_test"), only: :test},
            {:gaoxy_http, path: Path.join(directory, "gaoxy_http"), only: :test, override: true},
            {:gaoxy, path: Path.join(directory, "gaoxy"), only: :test, override: true},
            {:websock_adapter,
             path: Path.join(directory, "gaoxy_websock_adapter"), only: :test, override: true}
          ]
      end

    [{:http_fetch, "~> 0.21", only: :test} | fixtures]
  end
end
