defmodule Gaoxy.Server.GatewayListenerSetTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.Gateway
  alias Gaoxy.Proxy.Gateway.Upstream
  @moduletag :capture_log

  defmodule Endpoint do
    def init(body), do: {:ok, body}

    def call(exchange, body) do
      if exchange.request.path == "/held" do
        send(Process.whereis(Gaoxy.Server.GatewayListenerSetTest.Gate), {:captured, self(), body})

        receive do
          :release -> :ok
        after
          10_000 -> exit(:held_request_timeout)
        end
      end

      Gaoxy.HTTP.Response.send_resp(exchange, 200, [{"alt-svc", "upstream-owned"}], body)
    end
  end

  @tag :tmp_dir
  test "H1/H2/H3 share a commit, proxy discovery, and an old in-flight snapshot", %{tmp_dir: dir} do
    certificates(dir)
    Process.register(self(), Gaoxy.Server.GatewayListenerSetTest.Gate)
    gateway = start_supervised!({Gateway, unified(dir, "old")})
    origin = start_supervised!({Gaoxy.HTTP, id: :origin, endpoint: {Endpoint, "new"}})
    {:ok, {_, origin_port}} = Gaoxy.info(origin, :origin).local
    assert {:ok, upstream} = Upstream.fixed(%{upstream: "http://127.0.0.1:#{origin_port}"})

    assert %{phase: :ready, listener_sets: %{"web" => %{revision: 1}}, listeners: listeners} =
             Gateway.info(gateway)

    assert length(listeners) == 2

    ports =
      Map.new(listeners, fn listener ->
        {:ok, {_, port}} = listener.local
        {listener.transport, port}
      end)

    peer(dir, ports, "old")
    held = Task.async(fn -> peer(dir, ports, "old", "held") end)
    assert_receive {:captured, worker, "old"}, 3000

    assert {:ok, %{revision: 2}} =
             Gateway.reload_routes(gateway, "web", [%{target: upstream}],
               expected_revision: 1,
               timeout: 3000
             )

    peer(dir, ports, "new")
    send(worker, :release)
    assert Task.await(held, 3000) == :ok
    assert %{phase: :ready, listener_sets: %{"web" => %{revision: 2}}} = Gateway.info(gateway)
    assert :ok = Gateway.stop(gateway, 3000)
  end

  @tag :tmp_dir
  test "accepted upstream trust survives deleted input files and owner recovery", %{tmp_dir: dir} do
    certificates(dir)

    origin =
      start_supervised!(
        {Gaoxy.HTTP,
         id: :origin,
         transport: :tls,
         protocols: [:http1],
         tls: %{certfile: Path.join(dir, "cert.pem"), keyfile: Path.join(dir, "key.pem")},
         endpoint: {Endpoint, "trusted"}}
      )

    {:ok, {_, port}} = Gaoxy.info(origin, :origin).local

    assert {:ok, upstream} =
             Upstream.fixed(%{
               upstream: "https://localhost:#{port}",
               connect_address: {127, 0, 0, 1},
               cacertfile: Path.join(dir, "ca.pem")
             })

    gateway =
      start_supervised!(
        {Gateway,
         id: :trust,
         listener_sets: [
           [
             id: "web",
             endpoint: {Gaoxy.HTTP.Router, [%{target: {Endpoint, "startup"}}]},
             listeners: [http: [port: 0]]
           ]
         ]}
      )

    assert {:ok, %{revision: 2}} =
             Gateway.reload_routes(gateway, "web", [%{target: upstream}],
               expected_revision: 1,
               timeout: 3000
             )

    assert body(gateway) == "trusted"
    before = Gateway.info(gateway)
    %{transports: owner} = :sys.get_state(before.coordinator)
    File.rm!(Path.join(dir, "ca.pem"))
    Process.exit(owner, :kill)

    await(fn ->
      case Gateway.info(gateway) do
        %{phase: :ready, runtime_epoch: epoch} -> epoch != before.runtime_epoch
        _ -> false
      end
    end)

    assert body(gateway) == "trusted"
    assert %{listener_sets: %{"web" => %{revision: 2}}} = Gateway.info(gateway)

    assert {:ok, %{revision: 3}} =
             Gateway.reload_routes(gateway, "web", [%{target: {Endpoint, "final"}}],
               expected_revision: 2,
               timeout: 3000
             )

    assert body(gateway) == "final"
  end

  defp unified(dir, body),
    do: [
      id: :unified,
      listener_sets: [
        [
          id: "web",
          endpoint: {Gaoxy.HTTP.Router, [%{target: {Endpoint, body}}]},
          listeners: [https: secure(dir), http3: secure(dir)],
          discovery: [port: :bound]
        ]
      ]
    ]

  defp secure(dir),
    do: [
      ip: {127, 0, 0, 1},
      port: 0,
      certfile: Path.join(dir, "cert.pem"),
      keyfile: Path.join(dir, "key.pem")
    ]

  defp root, do: Path.expand("../../..", __DIR__)

  defp certificates(dir) do
    assert {_, 0} =
             System.cmd("bash", [Path.join(root(), "scripts/generate-fixtures.sh"), dir],
               stderr_to_stdout: true
             )
  end

  defp peer(dir, ports, body, mode \\ "all") do
    python = System.get_env("GAOXY_QUIC_PYTHON") || Path.join(root(), ".audit/h2peer/bin/python")

    {output, code} =
      System.cmd(
        python,
        [
          Path.join(root(), "integration/gateway/peer.py"),
          mode,
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
    :ok
  end

  defp body(gateway) do
    %{listeners: [%{local: {:ok, {ip, port}}}]} = Gateway.info(gateway)
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    :ok = :gen_tcp.send(socket, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    bytes = read(socket, "")
    :gen_tcp.close(socket)
    assert String.starts_with?(bytes, "HTTP/1.1 200"), bytes
    [_, body] = String.split(bytes, "\r\n\r\n", parts: 2)
    body
  end

  defp read(socket, acc) do
    case :gen_tcp.recv(socket, 0, 3000) do
      {:ok, bytes} -> read(socket, acc <> bytes)
      {:error, :closed} -> acc
    end
  end

  defp await(fun, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(4000)

    unless fun.() do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, "recovery deadline"

      receive do
      after
        5 -> await(fun, deadline)
      end
    end
  end
end
