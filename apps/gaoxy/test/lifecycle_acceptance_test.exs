defmodule Gaoxy.LifecycleAcceptanceTest do
  use ExUnit.Case, async: true
  @moduletag :loopback

  defmodule Stream do
    def init(_, _), do: {:ok, nil}
    def handle_data(bytes, state), do: {:send, bytes, state}
  end

  defmodule Datagram do
    def handle_datagram(packet, owner) do
      send(owner, {:waiting, self(), packet})

      receive do
        :release -> {:reply, "completed"}
      end
    end
  end

  @tag :tmp_dir
  test "backend initialization failure removes sockets and registrations", %{tmp_dir: directory} do
    {:ok, probe} = :gen_tcp.listen(0, ip: {127, 0, 0, 1}, active: false)
    {:ok, {ip, port}} = :inet.sockname(probe)
    :gen_tcp.close(probe)
    id = "rollback-#{System.unique_integer([:positive])}"
    name = {__MODULE__, make_ref()}

    assert {:error, _} =
             Gaoxy.start_link(
               name: {:via, Registry, {Gaoxy.Registry, name}},
               services: [
                 %{id: id, transport: :tcp, port: port, handler: Stream},
                 %{
                   id: "bad-credentials",
                   transport: :tls,
                   handler: Stream,
                   tls: %{
                     certfile: Path.join(directory, "absent.pem"),
                     keyfile: Path.join(directory, "absent-key.pem")
                   }
                 }
               ]
             )

    eventually(fn -> Registry.lookup(Gaoxy.Registry, name) == [] end)
    assert [] = Registry.select(Gaoxy.Registry, [{{{:"$1", id}, :"$2", :"$3"}, [], [:"$_"]}])

    eventually(fn ->
      case :gen_tcp.listen(port, ip: ip, active: false) do
        {:ok, socket} ->
          :gen_tcp.close(socket)
          true

        {:error, _} ->
          false
      end
    end)
  end

  test "old lease/timer/teardown messages cannot affect a re-added generation" do
    spec = %{id: "udp", transport: :udp, handler: Datagram, handler_options: self()}
    runtime = start_supervised!({Gaoxy, services: [spec]})
    old = Gaoxy.handle(runtime, "udp")
    {:ok, service, _} = GenServer.call(runtime, {:lookup, "udp"})
    gate = :sys.get_state(service).gate
    {ip, port} = Gaoxy.info(runtime, old).local
    {:ok, client} = :gen_udp.open(0, [:binary, active: false])
    on_exit(fn -> :gen_udp.close(client) end)
    :ok = :gen_udp.send(client, ip, port, "hold-old")
    assert_receive {:waiting, old_worker, _}, 2000
    [{lease, %{token: token, monitor: monitor}}] = Map.to_list(:sys.get_state(gate).leases)
    assert {:error, {:deadline_exceeded, :cleanup_pending}} = Gaoxy.remove(runtime, old, 10)
    eventually(fn -> not Process.alive?(old_worker) and Gaoxy.services(runtime) == [] end)
    assert {:ok, current} = Gaoxy.add(runtime, spec)
    assert current.generation != old.generation
    assert {:error, :stale_generation} = Gaoxy.remove(runtime, old, 10)
    {:ok, current_service, _} = GenServer.call(runtime, {:lookup, "udp"})
    current_gate = :sys.get_state(current_service).gate
    {^ip, current_port} = Gaoxy.info(runtime, current).local
    :ok = :gen_udp.send(client, ip, current_port, "hold-current")
    assert_receive {:waiting, current_worker, _}, 2000
    send(current_gate, {:expired, lease, token})
    send(current_gate, {:DOWN, monitor, :process, old_worker, :killed})
    send(current_service, {:drain_deadline, token})
    send(current_service, {:drained, old_worker, :ok})
    assert %{state: :ready, active: 1} = Gaoxy.status(runtime, current)
    assert Process.alive?(current_worker)
    send(current_worker, :release)
    assert {:ok, {^ip, ^current_port, "completed"}} = :gen_udp.recv(client, 0, 2000)
    eventually(fn -> Gaoxy.status(runtime, current).active == 0 end)
    assert %{retained_bytes: 0} = Gaoxy.status(runtime, current)
    assert :ok = Gaoxy.remove(runtime, current, 1000)
    assert [] = Gaoxy.services(runtime)
  end

  @tag :tmp_dir
  test "independent TLS keeps admitted traffic during pause and drain, then resumes", %{
    tmp_dir: directory
  } do
    root = Path.expand("../../..", __DIR__)
    {_, 0} = System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), directory])

    runtime =
      start_supervised!(
        {Gaoxy,
         services: [
           %{
             id: "tls",
             transport: :tls,
             handler: Stream,
             tls: %{
               provider: :otp,
               certfile: Path.join(directory, "cert.pem"),
               keyfile: Path.join(directory, "key.pem"),
               alpn: ["gaoxy-echo-v1"]
             }
           }
         ]}
      )

    {:ok, {ip, port}} = Gaoxy.info(runtime, "tls").local

    peer =
      Port.open({:spawn_executable, System.find_executable("python3")}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        {:line, 1024},
        {:args,
         [
           Path.join(root, "integration/tls_peer.py"),
           Integer.to_string(port),
           Path.join(directory, "ca.pem"),
           "interactive"
         ]}
      ])

    on_exit(fn -> if Port.info(peer), do: Port.close(peer) end)
    assert_receive {^peer, {:data, {:eol, "READY_TLS"}}}, 2000
    eventually(fn -> Gaoxy.status(runtime, "tls").active == 1 end)
    assert :ok = Gaoxy.pause(runtime, "tls")
    assert %{mode: :paused, pause: :unbind_rebind} = Gaoxy.info(runtime, "tls")

    # Listener-owner termination and TCP refusal are distinct barriers.
    # Wait for the actual network barrier and close every transient probe.
    eventually(fn ->
      case :gen_tcp.connect(ip, port, [:binary, active: false], 500) do
        {:error, :econnrefused} ->
          true

        {:error, :econnreset} ->
          false

        {:ok, socket} ->
          :gen_tcp.close(socket)
          false
      end
    end)

    assert %{state: :paused, active: 1} = Gaoxy.status(runtime, "tls")
    assert Port.command(peer, "admitted-during-pause\n")
    assert_receive {^peer, {:data, {:eol, "PASS admitted-during-pause"}}}, 2000
    assert :ok = Gaoxy.resume(runtime, "tls")
    {:ok, {^ip, resumed}} = Gaoxy.info(runtime, "tls").local
    assert resumed > 0

    assert {output, 0} =
             System.cmd(
               "python3",
               [
                 Path.join(root, "integration/tls_peer.py"),
                 Integer.to_string(resumed),
                 Path.join(directory, "ca.pem")
               ],
               stderr_to_stdout: true
             )

    assert output =~ "PASS TLS exchange"
    owner = self()
    spawn(fn -> send(owner, {:removed_tls, Gaoxy.remove(runtime, "tls", 1000)}) end)
    eventually(fn -> Gaoxy.status(runtime, "tls").state == :draining end)
    assert Port.command(peer, "admitted-during-drain\n")
    assert_receive {^peer, {:data, {:eol, "PASS admitted-during-drain"}}}, 1000
    assert Port.command(peer, "close\n")
    assert_receive {^peer, {:exit_status, 0}}, 2000
    assert_receive {:removed_tls, :ok}, 1500
    assert {:error, :not_running} = Gaoxy.info(runtime, "tls")
  end

  defp eventually(predicate, deadline \\ nil) do
    deadline = deadline || System.monotonic_time(:millisecond) + 2000

    if predicate.() do
      :ok
    else
      assert System.monotonic_time(:millisecond) < deadline, "readiness condition timed out"

      receive do
      after
        5 -> eventually(predicate, deadline)
      end
    end
  end
end
