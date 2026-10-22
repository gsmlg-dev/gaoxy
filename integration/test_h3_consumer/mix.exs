defmodule GaoxyTestH3Consumer.MixProject do
  use Mix.Project

  def project do
    [app: :gaoxy_test_h3_consumer, version: "0.1.0", elixir: "~> 1.18", deps: deps()]
  end

  def application, do: [extra_applications: [:logger, :ssl]]

  defp deps do
    version = System.fetch_env!("GAOXY_TEST_VERSION")

    case System.get_env("GAOXY_TEST_PACKAGES") do
      nil ->
        [
          {:gaoxy_test, "== " <> version, only: :test},
          {:gaoxy_http3, "== " <> version, only: :test}
        ]

      directory ->
        [
          {:gaoxy_test, path: Path.join(directory, "gaoxy_test"), only: :test},
          {:gaoxy_http3, path: Path.join(directory, "gaoxy_http3"), only: :test, override: true},
          {:gaoxy_http, path: Path.join(directory, "gaoxy_http"), only: :test, override: true},
          {:gaoxy, path: Path.join(directory, "gaoxy"), only: :test, override: true},
          {:websock_adapter,
           path: Path.join(directory, "gaoxy_websock_adapter"), only: :test, override: true}
        ]
    end
  end
end
