defmodule Gaoxy.ShutdownHardeningTest do
  use ExUnit.Case, async: true
  @moduletag :loopback
  @moduletag :capture_log

  defmodule Stream do
    def init(_, owner), do: {:ok, owner}
    def handle_data("close", owner), do: {:close, owner}

    def handle_data(bytes, owner) do
      send(owner, {:admitted, self(), bytes})

      receive do
        :release -> {:send, "completed", owner}
      end
    end
  end

  defmodule Datagram do
    def handle_datagram(packet, owner) do
      send(owner, {:admitted, self(), packet.data})

      receive do
        :release -> {:reply, "completed"}
      end
    end
  end

  def spec(transport, id \\ "service") do
    %{
      id: id,
      transport: transport,
      handler: if(transport == :udp, do: Datagram, else: Stream),
      handler_options: self(),
      limits: %{drain_timeout: 500, callback_timeout: 5_000}
    }
  end

  for transport <- [:tcp, :udp, :tls], outcome <- [:graceful, :forced] do
    @tag :tmp_dir
    @tag transport: transport, outcome: outcome
    test "parent shutdown handles #{outcome} #{transport} work", %{
      tmp_dir: directory,
      transport: transport,
      outcome: outcome
    } do
      service_spec = spec(transport)

      service_spec =
        if transport == :tls do
          root = Path.expand("../../..", __DIR__)

          assert {_, 0} =
                   System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), directory])

          Map.put(service_spec, :tls, %{
            certfile: Path.join(directory, "cert.pem"),
            keyfile: Path.join(directory, "key.pem"),
            alpn: ["gaoxy-test"]
          })
        else
          service_spec
        end

      parent =
        start_supervised!(%{
          id: make_ref(),
          start:
            {Supervisor, :start_link,
             [[{Gaoxy, services: [service_spec]}], [strategy: :one_for_one]]},
          type: :supervisor
        })

      [{_, runtime, _, _}] = Supervisor.which_children(parent)
      {:ok, service, _} = GenServer.call(runtime, {:lookup, "service"})
      state = :sys.get_state(service)
      local = Gaoxy.info(runtime, "service").local
      {ip, port} = if match?({:ok, _}, local), do: elem(local, 1), else: local
      client = connect(transport, ip, port, directory)
      send_data(transport, client, ip, port, "pending")
      assert_receive {:admitted, worker, "pending"}, 2_000
      worker_monitor = Process.monitor(worker)
      owner = self()
      attach_lifecycle(state.scope, owner)
      spawn(fn -> send(owner, {:parent_stopped, Supervisor.stop(parent)}) end)
      assert_receive {:lifecycle, :draining}, 2_000
      assert Process.alive?(worker)

      if outcome == :graceful do
        send(worker, :release)

        assert receive_data(transport, client) ==
                 if(transport == :udp,
                   do: {:ok, {ip, port, "completed"}},
                   else: {:ok, "completed"}
                 )

        if transport != :udp, do: send_data(transport, client, ip, port, "close")
      end

      assert_receive {:parent_stopped, :ok}, 2_000
      assert_receive {:DOWN, ^worker_monitor, :process, ^worker, _}, 1_000
      refute Process.alive?(state.backend)
      refute Process.alive?(state.gate)
      refute Process.alive?(runtime)
      close(transport, client)

      if transport == :udp do
        assert {:ok, rebound} = :gen_udp.open(port, ip: ip, active: false)
        :gen_udp.close(rebound)
      else
        assert {:error, _} = :gen_tcp.connect(ip, port, [:binary, active: false], 100)
      end
    end
  end

  test "drain helper death cannot report successful cleanup while backend is live" do
    runtime = start_supervised!({Gaoxy, services: [spec(:tcp)]})
    {:ok, service, _} = GenServer.call(runtime, {:lookup, "service"})
    {:ok, {ip, port}} = Gaoxy.info(runtime, "service").local
    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false])
    :ok = :gen_tcp.send(client, "pending")
    assert_receive {:admitted, _, "pending"}, 2_000
    owner = self()
    spawn(fn -> send(owner, {:removed, Gaoxy.remove(runtime, "service", 1_000)}) end)
    eventually(fn -> :sys.get_state(service).drain != nil end)
    drain = :sys.get_state(service).drain
    Process.exit(drain.pid, :kill)
    assert_receive {:removed, {:error, {:cleanup_failed, _}}}, 1_500
    eventually(fn -> not Process.alive?(service) end)
    assert {:error, :closed} = :gen_tcp.recv(client, 0, 1_000)
    :gen_tcp.close(client)
  end

  test "backend pause failure cannot advertise ready with a closed gate" do
    runtime = start_supervised!({Gaoxy, services: [spec(:tcp)]})
    {:ok, service, _} = GenServer.call(runtime, {:lookup, "service"})
    %{backend: backend, gate: gate} = :sys.get_state(service)
    assert :ok = Supervisor.terminate_child(backend, :shutdown_listener)
    assert :ok = Supervisor.delete_child(backend, :shutdown_listener)
    assert {:error, {:transition_failed, :pause, _}} = Gaoxy.pause(runtime, "service")
    assert %{state: :failed} = Gaoxy.status(runtime, "service")
    assert :paused = :sys.get_state(gate).mode
    assert {:error, :failed} = Gaoxy.resume(runtime, "service")
  end

  defp attach_lifecycle(scope, owner) do
    id = make_ref()

    :ok =
      :telemetry.attach(
        id,
        [:gaoxy, :lifecycle],
        fn _, _, metadata, _ ->
          if metadata.instance == scope.instance and metadata.service == scope.service,
            do: send(owner, {:lifecycle, metadata.state})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(id) end)
  end

  defp connect(:tcp, ip, port, _),
    do: elem(:gen_tcp.connect(ip, port, [:binary, active: false]), 1)

  defp connect(:udp, _, _, _), do: elem(:gen_udp.open(0, [:binary, active: false]), 1)

  defp connect(:tls, ip, port, directory) do
    {:ok, socket} =
      :ssl.connect(
        ip,
        port,
        [
          :binary,
          active: false,
          verify: :verify_peer,
          alpn_advertised_protocols: ["gaoxy-test"],
          cacertfile: String.to_charlist(Path.join(directory, "ca.pem")),
          server_name_indication: ~c"localhost",
          customize_hostname_check: [
            match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
          ]
        ],
        2_000
      )

    socket
  end

  defp send_data(:tcp, socket, _, _, bytes), do: :gen_tcp.send(socket, bytes)
  defp send_data(:tls, socket, _, _, bytes), do: :ssl.send(socket, bytes)
  defp send_data(:udp, socket, ip, port, bytes), do: :gen_udp.send(socket, ip, port, bytes)
  defp receive_data(:tcp, socket), do: :gen_tcp.recv(socket, 0, 1_000)
  defp receive_data(:tls, socket), do: :ssl.recv(socket, 0, 1_000)
  defp receive_data(:udp, socket), do: :gen_udp.recv(socket, 0, 1_000)
  defp close(:tcp, socket), do: :gen_tcp.close(socket)
  defp close(:tls, socket), do: :ssl.close(socket)
  defp close(:udp, socket), do: :gen_udp.close(socket)

  defp eventually(predicate, deadline \\ nil) do
    deadline = deadline || System.monotonic_time(:millisecond) + 2_000

    if predicate.() do
      :ok
    else
      assert System.monotonic_time(:millisecond) < deadline

      receive do
      after
        5 -> eventually(predicate, deadline)
      end
    end
  end
end
