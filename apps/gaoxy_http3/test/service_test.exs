defmodule Gaoxy.HTTP.HTTP3.ServiceTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.HTTP3

  defmodule Endpoint do
    def init(observer) do
      send(observer, :initialized)
      {:ok, observer}
    end

    def call(exchange, _), do: {:ok, exchange}
  end

  defp options do
    [endpoint: {Endpoint, self()}, tls: %{certfile: "fixture.pem", keyfile: "key.pem"}]
  end

  test "invalid activation leaves the requested UDP endpoint available" do
    {:ok, socket} = :gen_udp.open(0, [:binary, ip: {127, 0, 0, 1}])
    {:ok, {ip, port}} = :inet.sockname(socket)
    :gen_udp.close(socket)

    assert {:error, :missing_credentials} =
             HTTP3.start_link(endpoint: {Endpoint, self()}, ip: ip, port: port)

    {:ok, probe} = :gen_udp.open(port, [:binary, ip: ip])
    :gen_udp.close(probe)
    refute_received :initialized
  end

  test "H3 service specification selects the Gaoxy QUIC connection owner" do
    assert {:ok, spec} = HTTP3.service_spec(options())
    assert %{transport: :quic, handler: Gaoxy.HTTP.HTTP3.Connection, quic: %{alpn: ["h3"]}} = spec
    assert %{initialized: true, endpoint: {Endpoint, observer}} = spec.handler_options
    assert observer == self()
    assert_receive :initialized
    refute_receive :initialized
    assert {:ok, _} = Gaoxy.Config.service(spec)
    refute_receive :initialized
  end

  test "child spec uses explicit H3 selection and preserves the service identity" do
    assert %{id: {HTTP3, :test_h3}, start: {HTTP3, :start_link, [input]}, restart: :transient} =
             HTTP3.child_spec(Keyword.put(options(), :id, :test_h3))

    assert input[:id] == :test_h3
    assert {:error, :invalid_http3_options} = HTTP3.service_spec(%{})
  end
end
