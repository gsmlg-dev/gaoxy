defmodule Gaoxy.HTTP.HTTP3.SupervisedShutdownBudgetTest do
  use ExUnit.Case, async: true
  @moduletag :unit

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: {:ok, exchange}
  end

  defmodule InitializationEndpoint do
    def init(owner) do
      send(owner, {:endpoint_initialized, self()})
      {:ok, owner}
    end

    def call(exchange, _), do: {:ok, exchange}
  end

  defmodule RaisingEndpoint do
    def init(_), do: raise("startup initialization")
    def call(exchange, _), do: {:ok, exchange}
  end

  @tag :child_spec_initialization
  test "HTTP3 child spec does not initialize endpoints or move startup exceptions" do
    options = [
      endpoint: {InitializationEndpoint, self()},
      tls: %{certfile: "cert.pem", keyfile: "key.pem"}
    ]

    assert %{start: {Gaoxy.HTTP.HTTP3, :start_link, [^options]}} =
             Gaoxy.HTTP.HTTP3.child_spec(options)

    refute_receive {:endpoint_initialized, _}, 20

    raising = Keyword.put(options, :endpoint, {RaisingEndpoint, []})

    assert %{start: {Gaoxy.HTTP.HTTP3, :start_link, [^raising]}} =
             Gaoxy.HTTP.HTTP3.child_spec(raising)

    assert_raise RuntimeError, "startup initialization", fn ->
      Gaoxy.HTTP.HTTP3.start_link(raising)
    end
  end

  test "HTTP3 child spec preserves the validated instance budget and deferred invalid startup errors" do
    for limits <- [%{}, %{drain_timeout: 5_500}] do
      options = [
        id: :h3_budget,
        endpoint: {Endpoint, []},
        tls: %{certfile: "cert.pem", keyfile: "key.pem"},
        limits: limits
      ]

      assert {:ok, service} = Gaoxy.HTTP.HTTP3.service_spec(options)
      expected = Gaoxy.child_spec(services: [service])
      actual = Gaoxy.HTTP.HTTP3.child_spec(options)
      assert Map.get(actual, :shutdown) == expected.shutdown
      assert actual.id == {Gaoxy.HTTP.HTTP3, :h3_budget}
      assert actual.start == {Gaoxy.HTTP.HTTP3, :start_link, [options]}
      assert actual.restart == :transient
    end

    invalid = [endpoint: {Endpoint, []}]

    assert %{shutdown: 7_000, start: {Gaoxy.HTTP.HTTP3, :start_link, [^invalid]}} =
             Gaoxy.HTTP.HTTP3.child_spec(invalid)

    assert {:error, _} = Gaoxy.HTTP.HTTP3.start_link(invalid)
  end
end
