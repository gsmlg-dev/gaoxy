defmodule Gaoxy.Server.RelayConfigTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Proxy.{StreamRelay, UDPRelay}
  alias Gaoxy.Server.RelayConfig

  test "stream JSON maps literal addresses, explicit modes and finite runtime options" do
    for {mode, expected} <- [
          {"tcp", :tcp},
          {"tls_termination", :tls_termination},
          {"tls_passthrough", :tls_passthrough}
        ] do
      assert {:ok, options} =
               RelayConfig.decode(StreamRelay, %{
                 "upstream" => %{"address" => "::1", "port" => 443},
                 "mode" => mode,
                 "max_chunk_bytes" => 1024,
                 "connect_timeout" => 200,
                 "idle_timeout" => 1000,
                 "max_lifetime" => 5000,
                 "write_timeout" => 300
               })

      assert options.upstream == {{0, 0, 0, 0, 0, 0, 0, 1}, 443}
      assert options.mode == expected
      assert options.max_chunk_bytes == 1024
      assert options.connect_timeout == 200
      assert options.idle_timeout == 1000
      assert options.max_lifetime == 5000
      assert options.write_timeout == 300
      assert {:ok, ^options} = StreamRelay.validate_options(options)
    end

    assert {:ok, %{mode: :tcp}} = RelayConfig.decode(StreamRelay, stream_options())
  end

  @tag :tmp_dir
  test "verified upstream TLS maps only explicit server identity and CA file", %{
    tmp_dir: directory
  } do
    ca = Path.join(directory, "ca.pem")
    File.write!(ca, "validation only checks that the CA file exists")

    options =
      Map.merge(stream_options(), %{
        "mode" => "tls_upstream",
        "upstream_tls" => %{"server_name" => "upstream.example", "cacertfile" => ca}
      })

    assert {:ok, %{mode: :tls_upstream, upstream_tls: tls}} =
             RelayConfig.decode(StreamRelay, options)

    assert tls == %{server_name: "upstream.example", cacertfile: ca}

    for invalid <- [
          Map.delete(options, "upstream_tls"),
          put_in(options, ["upstream_tls", "cacertfile"], Path.join(directory, "missing")),
          put_in(options, ["upstream_tls", "verify"], "verify_none"),
          put_in(options, ["upstream_tls", "server_name"], "bad/name"),
          Map.put(options, "upstream_tls", nil)
        ] do
      assert {:error, _} = RelayConfig.decode(StreamRelay, invalid)
    end
  end

  test "stream input rejects unknown keys, DNS destinations and unbounded runtime options" do
    for invalid <- [
          %{},
          nil,
          [],
          Map.put(stream_options(), "eval", "System.cmd"),
          Map.put(stream_options(), "mode", "mitm"),
          Map.put(stream_options(), "mode", :tcp),
          Map.put(stream_options(), "max_chunk_bytes", 16_385),
          Map.put(stream_options(), "idle_timeout", "infinity"),
          Map.put(stream_options(), "connect_timeout", 0),
          Map.put(stream_options(), "upstream_tls", %{"verify" => "verify_none"}),
          Map.put(stream_options(), "upstream", nil),
          put_in(stream_options(), ["upstream", "address"], "localhost"),
          put_in(stream_options(), ["upstream", "address"], {127, 0, 0, 1}),
          put_in(stream_options(), ["upstream", "port"], 0),
          put_in(stream_options(), ["upstream", "module"], "System")
        ] do
      assert {:error, _} = RelayConfig.decode(StreamRelay, invalid)
    end
  end

  test "UDP JSON retains ingress and destination policy and all finite limit options" do
    limits = %{
      "max_associations" => 2,
      "queue_items" => 2,
      "queue_bytes" => 2048,
      "max_packet" => 1024,
      "idle_timeout" => 1000,
      "lifetime" => 5000,
      "reservation_timeout" => 100,
      "send_timeout" => 200,
      "drain_grace" => 100,
      "rate_packets" => 16,
      "rate_bytes" => 2048,
      "packet_ratio" => 2,
      "byte_ratio" => 2
    }

    assert {:ok, options} = RelayConfig.decode(UDPRelay, Map.put(udp_options(), "limits", limits))
    assert options.upstream == {{127, 0, 0, 1}, 9000}
    assert options.ingress == [{{127, 0, 0, 0}, 8}]

    assert options.destination == %{
             allow: [{{127, 0, 0, 1}, 32}],
             deny: [],
             allow_reserved: true
           }

    assert Map.new(options.limits, fn {key, value} -> {Atom.to_string(key), value} end) == limits
    assert {:ok, ^options} = UDPRelay.validate_options(options)
  end

  test "UDP policies cannot be omitted, widened for reserved addresses or overridden" do
    for invalid <- [
          %{},
          nil,
          [],
          Map.delete(udp_options(), "ingress"),
          Map.put(udp_options(), "ingress", []),
          Map.put(udp_options(), "ingress", [{{127, 0, 0, 0}, 8}]),
          Map.put(udp_options(), "ingress", ["not-a-cidr"]),
          Map.delete(udp_options(), "destination"),
          Map.put(udp_options(), "destination", nil),
          put_in(udp_options(), ["destination", "allow"], ["0.0.0.0/0"]),
          put_in(udp_options(), ["destination", "allow_reserved"], false),
          put_in(udp_options(), ["destination", "deny"], ["127.0.0.1/32"]),
          put_in(udp_options(), ["destination", "module"], "System"),
          put_in(udp_options(), ["upstream", "address"], "224.0.0.1"),
          Map.put(udp_options(), "limits", nil),
          Map.put(udp_options(), "limits", %{"max_associations" => 257}),
          Map.put(udp_options(), "limits", %{"lifetime" => "infinity"}),
          Map.put(udp_options(), "limits", %{"writer_module" => "System"}),
          Map.put(udp_options(), "writer_module", "System")
        ] do
      assert {:error, _} = RelayConfig.decode(UDPRelay, invalid)
    end
  end

  test "only the two explicit relay handler modules are accepted" do
    assert {:error, :unsupported_relay_handler} = RelayConfig.decode(System, %{})
    assert {:error, :unsupported_relay_handler} = RelayConfig.decode("stream_relay", %{})
  end

  @tag :tmp_dir
  test "standalone stream relay mode must match its listener transport", %{tmp_dir: directory} do
    ca = Path.join(directory, "ca.pem")
    File.write!(ca, "configuration validation fixture")
    tls = %{"tls" => %{"certfile" => ca, "keyfile" => ca}}

    assert {:error, _} =
             decode_service(
               "tcp",
               "stream_relay",
               Map.put(stream_options(), "mode", "tls_termination")
             )

    for handler_options <- [
          stream_options(),
          Map.put(stream_options(), "mode", "tcp"),
          Map.put(stream_options(), "mode", "tls_passthrough"),
          Map.merge(stream_options(), %{
            "mode" => "tls_upstream",
            "upstream_tls" => %{"server_name" => "upstream.example", "cacertfile" => ca}
          })
        ] do
      assert {:error, _} = decode_service("tls", "stream_relay", handler_options, tls)
    end

    assert {:ok, _} =
             decode_service(
               "tls",
               "stream_relay",
               Map.put(stream_options(), "mode", "tls_termination"),
               tls
             )
  end

  test "standalone JSON starts a TCP relay and preserves binary bytes" do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_tcp.close(listener) end)
    {:ok, {_, port}} = :inet.sockname(listener)
    bytes = <<0, 255, "standalone TCP relay">>
    owner = self()

    {peer, monitor} =
      spawn_monitor(fn ->
        result =
          with {:ok, socket} <- :gen_tcp.accept(listener, 2000) do
            try do
              with {:ok, ^bytes} <- :gen_tcp.recv(socket, byte_size(bytes), 2000),
                   do: :gen_tcp.send(socket, bytes)
            after
              :gen_tcp.close(socket)
            end
          end

        send(owner, {:tcp_peer_result, self(), result})
      end)

    on_exit(fn -> if Process.alive?(peer), do: Process.exit(peer, :kill) end)
    options = put_in(stream_options(), ["upstream", "port"], port)
    assert {:ok, config} = decode_service("tcp", "stream_relay", options)
    assert {:ok, server} = Gaoxy.start_link(config)
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    assert {:ok, {ip, relay_port}} = Gaoxy.info(server, "relay").local
    assert {:ok, socket} = :gen_tcp.connect(ip, relay_port, [:binary, active: false], 2000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    assert :ok = :gen_tcp.send(socket, bytes)
    assert {:ok, ^bytes} = :gen_tcp.recv(socket, byte_size(bytes), 2000)
    assert_receive {:tcp_peer_result, ^peer, :ok}, 2000
    assert_receive {:DOWN, ^monitor, :process, ^peer, :normal}, 2000
    assert :ok = :gen_tcp.close(socket)
    assert :ok = Gaoxy.stop(server)
  end

  test "standalone JSON starts a UDP relay with explicit ingress and destination policy" do
    owner = self()
    bytes = <<0, 255, "standalone UDP relay">>

    {peer, monitor} =
      spawn_monitor(fn ->
        {:ok, socket} = :gen_udp.open(0, [:binary, active: false, ip: {127, 0, 0, 1}])
        {:ok, {_, port}} = :inet.sockname(socket)
        send(owner, {:udp_peer_ready, self(), port})

        result =
          try do
            with {:ok, {ip, source_port, ^bytes}} <- :gen_udp.recv(socket, 0, 2000),
                 do: :gen_udp.send(socket, ip, source_port, bytes)
          after
            :gen_udp.close(socket)
          end

        send(owner, {:udp_peer_result, self(), result})
      end)

    on_exit(fn -> if Process.alive?(peer), do: Process.exit(peer, :kill) end)
    assert_receive {:udp_peer_ready, ^peer, port}, 2000
    options = put_in(udp_options(), ["upstream", "port"], port)
    assert {:ok, config} = decode_service("udp", "udp_relay", options)
    assert {:ok, server} = Gaoxy.start_link(config)
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    assert {ip, relay_port} = Gaoxy.info(server, "relay").local
    assert {:ok, socket} = :gen_udp.open(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_udp.close(socket) end)
    assert :ok = :gen_udp.send(socket, ip, relay_port, bytes)
    assert {:ok, {^ip, ^relay_port, ^bytes}} = :gen_udp.recv(socket, 0, 2000)
    assert_receive {:udp_peer_result, ^peer, :ok}, 2000
    assert_receive {:DOWN, ^monitor, :process, ^peer, :normal}, 2000
    assert :ok = Gaoxy.stop(server)
  end

  defp decode_service(transport, handler, handler_options, extra \\ %{}) do
    %{
      "version" => 1,
      "services" => [
        Map.merge(
          %{
            "id" => "relay",
            "transport" => transport,
            "handler" => handler,
            "handler_options" => handler_options,
            "limits" => %{"max_bytes" => 4_194_304}
          },
          extra
        )
      ]
    }
    |> JSON.encode!()
    |> JSON.decode!()
    |> Gaoxy.Server.Config.decode()
  end

  defp stream_options, do: %{"upstream" => %{"address" => "127.0.0.1", "port" => 9000}}

  defp udp_options do
    Map.merge(stream_options(), %{
      "ingress" => ["127.0.0.0/8"],
      "destination" => %{"allow" => ["127.0.0.1/32"], "allow_reserved" => true}
    })
  end
end
