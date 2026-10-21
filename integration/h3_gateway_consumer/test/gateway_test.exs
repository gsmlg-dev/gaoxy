defmodule H3GatewayConsumerTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.Gateway

  defmodule Endpoint do
    def init(body), do: {:ok, body}

    def call(exchange, body),
      do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [{"alt-svc", "upstream-owned"}], body)
  end

  @tag :tmp_dir
  @tag timeout: 60_000
  test "optional H3 consumer manages H1/H2/H3 reload and stop without Server", %{tmp_dir: dir} do
    refute File.exists?(Path.join(root(), "apps/gaoxy_server"))
    refute Code.ensure_loaded?(Gaoxy.Server.Application)
    assert Code.ensure_loaded?(Gaoxy.HTTP.HTTP3)

    assert {_, 0} =
             System.cmd("bash", [Path.join(root(), "scripts/generate-fixtures.sh"), dir],
               stderr_to_stdout: true
             )

    origin = start_supervised!({Gaoxy.HTTP, id: :origin, endpoint: {Endpoint, "origin"}})
    {:ok, {_, origin_port}} = Gaoxy.info(origin, :origin).local

    assert {:ok, target} =
             Gateway.Upstream.fixed(%{upstream: "http://127.0.0.1:#{origin_port}"})

    secure = [
      ip: {127, 0, 0, 1},
      port: 0,
      certfile: Path.join(dir, "cert.pem"),
      keyfile: Path.join(dir, "key.pem")
    ]

    gateway =
      start_supervised!(
        {Gateway,
         id: :consumer,
         listener_sets: [
           [
             id: "web",
             endpoint: {Gaoxy.HTTP.Router, [%{target: target}]},
             listeners: [https: secure, http3: secure],
             discovery: [port: :bound]
           ]
         ]}
      )

    assert %{
             phase: :ready,
             listener_sets: %{"web" => %{revision: 1}},
             listeners: listeners
           } = Gateway.info(gateway)

    assert length(listeners) == 2

    ports =
      Map.new(listeners, fn listener ->
        {:ok, {_, port}} = listener.local
        {listener.transport, port}
      end)

    peer(dir, ports, "origin")

    assert {:ok, %{revision: 2}} =
             Gateway.reload_routes(gateway, "web", [%{target: {Endpoint, "reloaded"}}],
               expected_revision: 1,
               timeout: 3000
             )

    peer(dir, ports, "reloaded")
    assert %{phase: :ready, listener_sets: %{"web" => %{revision: 2}}} = Gateway.info(gateway)
    assert :ok = Gateway.stop(gateway, 3000)
    refute Process.alive?(gateway)
    assert {:error, :econnrefused} = :gen_tcp.connect({127, 0, 0, 1}, ports.tls, [], 1000)
    assert {:ok, socket} = :gen_udp.open(ports.quic, ip: {127, 0, 0, 1}, active: false)
    :ok = :gen_udp.close(socket)
    refute Code.ensure_loaded?(Gaoxy.Server.Application)
    refute :gaoxy_server in Enum.map(Application.loaded_applications(), &elem(&1, 0))
  end

  defp root, do: Path.expand("../../..", __DIR__)

  defp peer(dir, ports, body) do
    python = System.fetch_env!("GAOXY_QUIC_PYTHON")

    {output, code} =
      System.cmd(
        python,
        [
          Path.join(root(), "integration/gateway/peer.py"),
          "all",
          to_string(ports.tls),
          to_string(ports.quic),
          Path.join(dir, "ca.pem"),
          body
        ],
        cd: root(),
        stderr_to_stdout: true
      )

    assert code == 0, output
    assert output =~ ~s("result": "PASS")
    assert output =~ ~s("versions": ["HTTP/1.1", "HTTP/2", "HTTP/3"])
  end
end
