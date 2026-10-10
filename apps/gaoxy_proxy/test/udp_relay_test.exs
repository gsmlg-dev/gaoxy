defmodule Gaoxy.Proxy.UDPRelayTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Proxy.UDPRelay

  defmodule BlockingWriter do
    def send(owner, ip, port, bytes) do
      send(owner, {:writer_blocked, self(), {ip, port}, bytes})

      receive do
        :release -> :ok
      end
    end
  end

  def options(port, extra \\ %{}) do
    Map.merge(
      %{
        upstream: {{127, 0, 0, 1}, port},
        ingress: ["127.0.0.0/8"],
        destination: %{allow: ["127.0.0.1/32"], allow_reserved: true}
      },
      extra
    )
  end

  test "requires explicit ingress and narrow destination exceptions with finite limits" do
    assert {:ok, normalized} = UDPRelay.validate_options(options(1234))
    assert {:ok, ^normalized} = UDPRelay.validate_options(normalized)
    assert {:error, _} = UDPRelay.validate_options(%{upstream: {{127, 0, 0, 1}, 1234}})
    assert {:error, _} = UDPRelay.validate_options(options(1234, %{ingress: []}))

    assert {:error, _} =
             UDPRelay.validate_options(
               options(1234, %{destination: %{allow: ["0.0.0.0/0"], allow_reserved: true}})
             )

    assert {:error, _} =
             UDPRelay.validate_options(options(1234, %{upstream: {{224, 0, 0, 1}, 1234}}))

    assert {:error, _} =
             UDPRelay.validate_options(
               options(1234, %{
                 upstream: {{127, 0, 0, 1}, 1234},
                 destination: %{
                   allow: ["127.0.0.1/32"],
                   deny: ["127.0.0.1/32"],
                   allow_reserved: true
                 }
               })
             )

    assert {:error, _} =
             UDPRelay.validate_options(options(1234, %{limits: %{max_associations: :infinity}}))
  end

  test "independent peers preserve empty packets and reply from the original listener" do
    {upstream, port} = upstream()
    instance = instance(port)
    {ip, relay_port} = endpoint(instance)
    a = client()
    b = client()

    for {socket, bytes} <- [{a, "first"}, {b, "other"}, {a, ""}, {a, "last"}] do
      :ok = :gen_udp.send(socket, ip, relay_port, bytes)
      assert {:ok, {^ip, ^relay_port, ^bytes}} = :gen_udp.recv(socket, 0, 1_500)
    end

    assert_receive {:upstream_peer, peer_a}
    assert_receive {:upstream_peer, peer_b}
    refute peer_a == peer_b
    assert :ok = Gaoxy.remove(instance, "relay", 1_000)
    assert {:error, :not_running} = Gaoxy.info(instance, "relay")
    send(upstream, :stop)
  end

  test "pause preserves ephemeral binding and resume permits new traffic" do
    {_upstream, port} = upstream()
    instance = instance(port)
    {ip, relay_port} = endpoint(instance)
    socket = client()
    :ok = :gen_udp.send(socket, ip, relay_port, "before")
    assert {:ok, {^ip, ^relay_port, "before"}} = :gen_udp.recv(socket, 0, 1_500)
    assert :ok = Gaoxy.pause(instance, "relay")
    assert {^ip, ^relay_port} = endpoint(instance)
    assert :ok = Gaoxy.resume(instance, "relay")
    :ok = :gen_udp.send(socket, ip, relay_port, "after")
    assert {:ok, {^ip, ^relay_port, "after"}} = :gen_udp.recv(socket, 0, 1_500)
  end

  test "source policy rejects before association creation and bounded count isolates peers" do
    {upstream, port} = upstream()

    instance =
      instance(port, %{handler_options: options(port, %{limits: %{max_associations: 1}})})

    {ip, relay_port} = endpoint(instance)
    a = client()
    b = client()
    :ok = :gen_udp.send(a, ip, relay_port, "admitted")
    assert {:ok, {^ip, ^relay_port, "admitted"}} = :gen_udp.recv(a, 0, 1_500)
    :ok = :gen_udp.send(b, ip, relay_port, "rejected")
    assert {:error, :timeout} = :gen_udp.recv(b, 0, 100)
    :ok = :gen_udp.send(a, ip, relay_port, "retained")
    assert {:ok, {^ip, ^relay_port, "retained"}} = :gen_udp.recv(a, 0, 1_500)
    send(upstream, :stop)
  end

  test "idle expiry releases owned upstream socket and creates a fresh association" do
    {_upstream, port} = upstream()

    instance =
      instance(port, %{
        handler_options: options(port, %{limits: %{idle_timeout: 60, lifetime: 500}})
      })

    {ip, relay_port} = endpoint(instance)
    socket = client()
    :ok = :gen_udp.send(socket, ip, relay_port, "before")
    assert {:ok, {^ip, ^relay_port, "before"}} = :gen_udp.recv(socket, 0, 1_500)
    assert_receive {:upstream_peer, old_peer}
    {:ok, service, _} = GenServer.call(instance, {:lookup, "relay"})
    owner = :sys.get_state(service).dispatcher_owner
    [worker] = Map.values(UDPRelay.status(owner).associations)
    monitor = Process.monitor(worker)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    :ok = :gen_udp.send(socket, ip, relay_port, "after")
    assert {:ok, {^ip, ^relay_port, "after"}} = :gen_udp.recv(socket, 0, 1_500)
    assert_receive {:upstream_peer, new_peer}
    refute old_peer == new_peer
  end

  test "metadata permits expire without retaining payload and cannot refund twice" do
    {_upstream, port} = upstream()

    assert {:ok, spec} =
             Gaoxy.Config.service(%{
               id: "direct",
               transport: :udp,
               handler_mode: :datagram_dispatcher,
               handler: UDPRelay,
               handler_options: options(port, %{limits: %{reservation_timeout: 30}}),
               limits: %{max_packet: 128, max_output: 128, max_bytes: 4_194_304}
             })

    generation = make_ref()
    writer_generation = make_ref()
    scope = %{generation: generation}
    gate = start_supervised!({Gaoxy.Admission, {spec.limits, scope}})

    context = %{
      spec: spec,
      gate: gate,
      scope: scope,
      service: self(),
      instance: self(),
      generation: generation,
      writer_generation: writer_generation,
      dispatcher: self(),
      local_info: {{127, 0, 0, 1}, 1234},
      send: nil
    }

    {:ok, owner} = UDPRelay.start_link(context, spec.handler_options)
    on_exit(fn -> if Process.alive?(owner), do: Process.exit(owner, :kill) end)
    key = {generation, writer_generation, {127, 0, 0, 1}, 9000}
    operation = make_ref()

    assert {:ok, _permit, worker} =
             GenServer.call(
               owner,
               {:reserve, operation, key, 128, generation, writer_generation,
                Gaoxy.Lifecycle.deadline(50)}
             )

    assert %{reserved_items: 1, reserved_bytes: 128} = UDPRelay.status(owner)
    monitor = Process.monitor(worker)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    assert %{reserved_items: 0, reserved_bytes: 0} = UDPRelay.status(owner)
    send(owner, {:cancel, self(), operation})
    assert %{reserved_items: 0, reserved_bytes: 0} = UDPRelay.status(owner)
    GenServer.stop(owner)
  end

  test "maximum datagram is intact and denied ingress creates no upstream traffic" do
    {_upstream, port} = upstream()
    instance = instance(port)
    {ip, relay_port} = endpoint(instance)
    socket = client()
    bytes = :binary.copy(<<42>>, 65_507)
    :ok = :gen_udp.send(socket, ip, relay_port, bytes)
    assert {:ok, {^ip, ^relay_port, ^bytes}} = :gen_udp.recv(socket, 0, 1_500)
    assert_receive {:upstream_peer, _}

    denied =
      instance(port, %{id: "denied", handler_options: options(port, %{ingress: ["192.0.2.0/24"]})})

    {ip, denied_port} = endpoint(denied, "denied")
    :ok = :gen_udp.send(socket, ip, denied_port, "no")
    assert {:error, :timeout} = :gen_udp.recv(socket, 0, 100)
    refute_receive {:upstream_peer, _}, 50
  end

  test "insufficient reservation budgets reject before binding" do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {ip, port}} = :inet.sockname(socket)
    :gen_udp.close(socket)

    assert {:error, {:handler_options, :udp_relay_budget_too_small}} =
             Gaoxy.start_link(
               services: [
                 %{
                   id: "small",
                   transport: :udp,
                   ip: ip,
                   port: port,
                   handler_mode: :datagram_dispatcher,
                   handler: UDPRelay,
                   handler_options: options(1234),
                   limits: %{max_bytes: 1000}
                 }
               ]
             )

    assert {:ok, probe} = :gen_udp.open(port, [:binary, active: false, ip: ip])
    :gen_udp.close(probe)
  end

  test "independent Python peer enforces return credits and the egress rate" do
    {python, port} = python_peer("double")
    instance = instance(port, %{handler_options: options(port, %{limits: %{rate_packets: 1}})})
    {ip, relay_port} = endpoint(instance)
    socket = client()
    :ok = :gen_udp.send(socket, ip, relay_port, "one")
    assert {:ok, {^ip, ^relay_port, "one"}} = :gen_udp.recv(socket, 0, 1_500)
    assert_receive {^python, {:data, {:eol, "seen " <> _}}}
    assert {:error, :timeout} = :gen_udp.recv(socket, 0, 100)
    :ok = :gen_udp.send(socket, ip, relay_port, "two")
    assert_receive {^python, {:data, {:eol, "seen " <> _}}}
    assert {:error, :timeout} = :gen_udp.recv(socket, 0, 100)
  end

  test "delayed independent response drains within grace and all owned sockets close" do
    {python, port} = python_peer("gate")
    instance = instance(port)
    {ip, relay_port} = endpoint(instance)
    socket = client()
    :ok = :gen_udp.send(socket, ip, relay_port, "delayed")
    assert_receive {^python, {:data, {:eol, "seen " <> seen}}}, 1_500
    [upstream_port, "7"] = String.split(seen)
    upstream_port = String.to_integer(upstream_port)
    {:ok, service, _} = GenServer.call(instance, {:lookup, "relay"})
    state = :sys.get_state(service)
    [worker] = Map.values(UDPRelay.status(state.dispatcher_owner).associations)

    monitors =
      for pid <- [worker, state.dispatcher_owner, state.gate, state.backend],
          do: {pid, Process.monitor(pid)}

    caller = self()
    spawn(fn -> send(caller, {:removed, Gaoxy.remove(instance, "relay", 1_000)}) end)
    eventually(fn -> Gaoxy.status(instance, "relay").state == :draining end)
    true = Port.command(python, "reply\n")
    assert {:ok, {^ip, ^relay_port, "delayed"}} = :gen_udp.recv(socket, 0, 1_000)
    assert_receive {:removed, :ok}, 1_500

    for {pid, monitor} <- monitors,
        do: assert_receive({:DOWN, ^monitor, :process, ^pid, _}, 1_000)

    for port <- [relay_port, upstream_port] do
      assert {:ok, probe} = :gen_udp.open(port, [:binary, active: false, ip: ip])
      :gen_udp.close(probe)
    end
  end

  test "listener force-stop kills controller and association without affecting sibling service" do
    {_upstream, port} = upstream()
    instance = instance(port)
    sibling = instance(port)
    {ip, relay_port} = endpoint(instance)
    socket = client()
    :ok = :gen_udp.send(socket, ip, relay_port, "ready")
    assert {:ok, {^ip, ^relay_port, "ready"}} = :gen_udp.recv(socket, 0, 1_500)
    {:ok, service, _} = GenServer.call(instance, {:lookup, "relay"})
    state = :sys.get_state(service)
    [worker] = Map.values(UDPRelay.status(state.dispatcher_owner).associations)
    owner_monitor = Process.monitor(state.dispatcher_owner)
    worker_monitor = Process.monitor(worker)
    Process.exit(state.backend, :kill)
    assert_receive {:DOWN, ^owner_monitor, :process, _, _}, 1_500
    assert_receive {:DOWN, ^worker_monitor, :process, ^worker, _}, 1_500
    {ip, sibling_port} = endpoint(sibling)
    :ok = :gen_udp.send(socket, ip, sibling_port, "alive")
    assert {:ok, {^ip, ^sibling_port, "alive"}} = :gen_udp.recv(socket, 0, 1_500)
  end

  test "blocked public writer has one submission and unknown settlement fails controller closed" do
    {_upstream, port} = upstream()
    {owner, context, writer} = controller(port, %{send_timeout: 80}, BlockingWriter)
    owner_monitor = Process.monitor(owner)
    packet = packet(context, "only")
    assert {:ok, worker} = UDPRelay.offer(owner, packet)
    worker_monitor = Process.monitor(worker)
    assert_receive {:writer_blocked, ^writer, _, "only"}, 1_000

    assert_receive {:gaoxy_dispatcher_failed, ^owner, _, {:unknown_send, :receipt_deadline}},
                   1_000

    assert %{mode: :failed} = UDPRelay.status(owner)

    assert Gaoxy.Admission.status(context.gate).retained_bytes >=
             context.spec.handler_options.reservation.infrastructure

    assert Process.alive?(writer)
    assert {:error, :failed} = UDPRelay.offer(owner, packet)
    assert {:error, :failed} = UDPRelay.drain(owner, Gaoxy.Lifecycle.deadline(100))
    assert {:error, :failed} = UDPRelay.control(owner, :resume, context.generation)
    # The fixture acts as Service only after verifying the host reservation is
    # retained. It tears down the writer and all explicit application roots.
    Gaoxy.Lifecycle.force([owner, writer, worker], context.gate)
    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, _}, 1_000
    assert_receive {:DOWN, ^worker_monitor, :process, ^worker, _}, 1_000
    refute_receive {:writer_blocked, _, _, _}, 50
    assert {:error, _} = UDPRelay.offer(owner, packet)
  end

  test "payload queued before the timer still rejects an absolutely expired permit" do
    {_upstream, port} = upstream()
    {owner, context, _writer} = controller(port, %{reservation_timeout: 30}, BlockingWriter)
    operation = make_ref()
    key = {context.generation, context.writer_generation, {127, 0, 0, 1}, 9000}

    assert {:ok, permit, _worker} =
             GenServer.call(
               owner,
               {:reserve, operation, key, 1, context.generation, context.writer_generation,
                Gaoxy.Lifecycle.deadline(50)}
             )

    :ok = :sys.suspend(owner)
    request = :gen_server.send_request(owner, {:submit, operation, permit, packet(context, "")})
    # Suspend provides deterministic mailbox order: the payload is enqueued
    # before the timer, but cannot run until beyond the reservation deadline.
    deadline = Gaoxy.Lifecycle.deadline(31)

    receive do
    after
      Gaoxy.Lifecycle.remaining(deadline) -> :ok
    end

    :ok = :sys.resume(owner)
    assert {:reply, {:error, :invalid_permit}} = :gen_server.receive_response(request, 100)
    assert %{reserved_items: 0, reserved_bytes: 0} = UDPRelay.status(owner)
    GenServer.stop(owner)
  end

  test "configured handoff budget includes delayed control lookup without an implicit 50 ms cap" do
    {_upstream, port} = upstream()
    {owner, context, _writer} = controller(port, %{}, BlockingWriter, %{handoff_timeout: 200})
    :ok = :sys.suspend(owner)

    resumer =
      spawn(fn ->
        receive do
          :resume -> :sys.resume(owner)
        end
      end)

    Process.send_after(resumer, :resume, 80)
    assert {:ok, _worker} = UDPRelay.offer(owner, packet(context, "budget"))
    GenServer.stop(owner)
  end

  test "directed broadcast vectors cover non /24 masks without denying valid .255 unicast" do
    alias Gaoxy.Proxy.UDPRelay.Options
    networks = [{{10, 0, 0, 1}, {255, 255, 255, 252}}, {{192, 168, 0, 1}, {255, 255, 255, 128}}]
    assert Options.directed_broadcast?({10, 0, 0, 3}, networks)
    assert Options.directed_broadcast?({192, 168, 0, 127}, networks)
    refute Options.directed_broadcast?({10, 0, 0, 2}, networks)

    refute Options.directed_broadcast?({192, 168, 0, 255}, [
             {{192, 168, 0, 1}, {255, 255, 254, 0}}
           ])

    assert {:ok, _} =
             UDPRelay.validate_options(
               options(1234, %{
                 upstream: {{192, 168, 0, 255}, 1234},
                 destination: %{allow: ["192.168.0.255/32"], allow_reserved: true}
               })
             )
  end

  test "actual local directed broadcast preflight fails before the listener bind" do
    {:ok, guard} = :gen_udp.open(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {ip, port}} = :inet.sockname(guard)

    assert {:error, {:handler_preflight, :directed_broadcast}} =
             Gaoxy.start_link(
               services: [
                 %{
                   id: "broadcast-denied",
                   ip: ip,
                   port: port,
                   transport: :udp,
                   handler_mode: :datagram_dispatcher,
                   handler: UDPRelay,
                   handler_options:
                     options(1234, %{
                       upstream: {{127, 255, 255, 255}, 1234},
                       destination: %{allow: ["127.255.255.255/32"], allow_reserved: true}
                     }),
                   limits: %{max_bytes: 4_194_304}
                 }
               ]
             )

    assert {:ok, {^ip, ^port}} = :inet.sockname(guard)
    :gen_udp.close(guard)
  end

  test "duplicate, mismatched and stale permits cannot retain or refund data twice" do
    {_upstream, port} = upstream()
    {owner, context, _writer} = controller(port, %{queue_items: 1}, BlockingWriter)
    key = {context.generation, context.writer_generation, {127, 0, 0, 1}, 9000}
    operation = make_ref()

    request =
      {:reserve, operation, key, 1, context.generation, context.writer_generation,
       Gaoxy.Lifecycle.deadline(50)}

    assert {:ok, permit, _worker} = GenServer.call(owner, request)
    assert {:error, :invalid_operation} = GenServer.call(owner, request)
    assert {:error, :queue_limit} = GenServer.call(owner, put_elem(request, 1, make_ref()))
    assert {:error, :stale_generation} = GenServer.call(owner, put_elem(request, 4, make_ref()))

    assert {:error, :invalid_permit} =
             GenServer.call(owner, {:submit, operation, permit, packet(context, "mismatch")})

    assert {:error, :invalid_permit} =
             GenServer.call(owner, {:submit, operation, permit, packet(context, "")})

    assert %{reserved_items: 0, reserved_bytes: 0} = UDPRelay.status(owner)
    GenServer.stop(owner)
  end

  defp packet(context, data),
    do: %{
      peer: {{127, 0, 0, 1}, 9000},
      data: data,
      generation: context.generation,
      writer_generation: context.writer_generation,
      handoff_timeout: context.spec.dispatcher.handoff_timeout
    }

  defp controller(port, limits, transport, dispatcher \\ %{}) do
    assert {:ok, spec} =
             Gaoxy.Config.service(%{
               id: "controlled",
               transport: :udp,
               handler_mode: :datagram_dispatcher,
               handler: UDPRelay,
               handler_options: options(port, %{limits: limits}),
               limits: %{max_packet: 128, max_output: 128, max_bytes: 4_194_304},
               dispatcher: dispatcher
             })

    generation = make_ref()
    writer_generation = make_ref()
    scope = %{generation: generation}
    gate = start_supervised!({Gaoxy.Admission, {spec.limits, scope}})

    {:ok, writer} =
      Abyss.Dispatcher.Writer.start_link(
        socket: self(),
        transport: transport,
        owner: self(),
        generation: writer_generation,
        max_queue: 1,
        max_bytes: 128
      )

    Process.unlink(writer)
    on_exit(fn -> if Process.alive?(writer), do: Process.exit(writer, :kill) end)

    context = %{
      spec: spec,
      gate: gate,
      scope: scope,
      service: self(),
      instance: self(),
      generation: generation,
      writer_generation: writer_generation,
      dispatcher: self(),
      local_info: {{127, 0, 0, 1}, 1234},
      send: %Abyss.Dispatcher.SendCapability{writer: writer, generation: writer_generation}
    }

    {:ok, owner} = UDPRelay.start_link(context, spec.handler_options)
    on_exit(fn -> if Process.alive?(owner), do: Process.exit(owner, :kill) end)
    {owner, context, writer}
  end

  defp python_peer(mode) do
    executable =
      System.find_executable("python3") || flunk("python3 required for independent UDP peer")

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        {:line, 1024},
        args: [Path.join(__DIR__, "support/udp_peer.py"), mode]
      ])

    on_exit(fn -> if Port.info(port), do: Port.close(port) end)
    assert_receive {^port, {:data, {:eol, number}}}, 1_000
    {port, String.to_integer(number)}
  end

  defp eventually(fun, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(1_000)

    if fun.() do
      :ok
    else
      assert Gaoxy.Lifecycle.remaining(deadline) > 0

      receive do
      after
        1 -> eventually(fun, deadline)
      end
    end
  end

  defp instance(port, extra \\ %{}) do
    spec =
      Map.merge(
        %{
          id: "relay",
          transport: :udp,
          handler_mode: :datagram_dispatcher,
          handler: UDPRelay,
          handler_options: options(port),
          limits: %{max_bytes: 4_194_304}
        },
        extra
      )

    pid = start_supervised!({Gaoxy, services: [spec]}, id: make_ref())
    on_exit(fn -> if Process.alive?(pid), do: Gaoxy.stop(pid, 0) end)
    pid
  end

  defp endpoint(instance, id \\ "relay") do
    case Gaoxy.info(instance, id).local do
      {:ok, endpoint} -> endpoint
      endpoint -> endpoint
    end
  end

  defp client do
    {:ok, socket} =
      :gen_udp.open(0, [
        :binary,
        active: false,
        ip: {127, 0, 0, 1},
        recbuf: 65_536,
        buffer: 65_536
      ])

    on_exit(fn -> :gen_udp.close(socket) end)
    socket
  end

  defp upstream do
    owner = self()

    pid =
      spawn(fn ->
        {:ok, socket} =
          :gen_udp.open(0, [
            :binary,
            active: true,
            ip: {127, 0, 0, 1},
            recbuf: 65_536,
            buffer: 65_536
          ])

        {:ok, {_, port}} = :inet.sockname(socket)
        send(owner, {:upstream_ready, port})
        echo(socket, owner)
      end)

    on_exit(fn -> if Process.alive?(pid), do: Process.exit(pid, :kill) end)
    assert_receive {:upstream_ready, port}
    {pid, port}
  end

  defp echo(socket, owner) do
    receive do
      {:udp, ^socket, ip, port, bytes} ->
        send(owner, {:upstream_peer, {ip, port}})
        :gen_udp.send(socket, ip, port, bytes)
        echo(socket, owner)

      :stop ->
        :gen_udp.close(socket)
    end
  end
end
