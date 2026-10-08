defmodule Gaoxy.RuntimeTest do
  use ExUnit.Case, async: true

  @readiness_timeout 2_000

  defmodule Lines do
    @behaviour Gaoxy.StreamHandler
    def init(_, options), do: {:ok, {"", options}}

    def handle_data(bytes, {pending, options}) do
      case String.split(pending <> bytes, "\n", parts: 2) do
        [rest] -> {:continue, {rest, options}}
        [line, rest] -> {:send, line <> "\n", {rest, options}}
      end
    end
  end

  defmodule UDP do
    @behaviour Gaoxy.DatagramHandler
    def handle_datagram(packet, owner) do
      if is_pid(owner), do: send(owner, {:packet, self(), packet})

      case packet.data do
        "crash" ->
          raise "fixture crash"

        "wait" ->
          receive do
            :release -> {:reply, "done"}
          end

        bytes ->
          {:reply, bytes}
      end
    end
  end

  def spec(type, id \\ "echo", options \\ %{}),
    do:
      Map.merge(
        %{id: id, transport: type, handler: if(type == :udp, do: UDP, else: Lines)},
        options
      )

  def instance(services) do
    pid = start_supervised!({Gaoxy, services: services})
    on_exit(fn -> if Process.alive?(pid), do: Gaoxy.stop(pid, 0) end)
    pid
  end

  def endpoint(pid, id \\ "echo") do
    %{local: local} = Gaoxy.info(pid, id)

    case local do
      {:ok, address} -> address
      address -> address
    end
  end

  def eventually(fun, deadline \\ nil) do
    deadline = deadline || System.monotonic_time(:millisecond) + @readiness_timeout

    case fun.() do
      false ->
        assert System.monotonic_time(:millisecond) < deadline, "readiness condition timed out"

        receive do
        after
          5 -> eventually(fun, deadline)
        end

      result ->
        result
    end
  end

  defp ready_udp_endpoint(pid, id \\ "echo") do
    eventually(fn ->
      match?(
        %{state: :ready, backend: %{mode: :running, receive_credit: 1}},
        Gaoxy.status(pid, id)
      )
    end)

    endpoint(pid, id)
  end

  defp admit_waiting_packet(client, {ip, port}) do
    :ok = :gen_udp.send(client, ip, port, "wait")
    # A bound socket precedes asynchronous worker admission. Synchronize with the
    # callback's event before starting drain/overload, using the readiness budget.
    assert_receive {:packet, worker, %{data: "wait"}}, @readiness_timeout
    assert Process.alive?(worker)
    worker
  end

  @tag :loopback
  test "two instances reuse service identities and reconstruct fragmented streams independently" do
    a = instance([spec(:tcp)])
    b = instance([spec(:tcp)])
    {ip, port} = endpoint(a)
    {_, other_port} = endpoint(b)
    assert port > 0 and other_port > 0 and port != other_port
    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)
    :ok = :gen_tcp.send(client, "frag")
    :ok = :gen_tcp.send(client, "mented\n")
    assert {:ok, "fragmented\n"} = :gen_tcp.recv(client, 0, 1_000)
    :gen_tcp.close(client)
    assert :ok = Gaoxy.remove(a, "echo", 1_000)
    assert [] = Gaoxy.services(a)
    assert ["echo"] = Gaoxy.services(b)
    assert {:error, :not_running} = Gaoxy.info(a, "echo")
  end

  @tag :loopback
  test "binding failure rolls back an already opened sibling socket" do
    {:ok, occupied} = :gen_tcp.listen(0, ip: {127, 0, 0, 1}, active: false)
    {:ok, {_, port}} = :inet.sockname(occupied)
    {:ok, probe} = :gen_tcp.listen(0, ip: {127, 0, 0, 1}, active: false)
    {:ok, {_, free}} = :inet.sockname(probe)
    :gen_tcp.close(probe)

    assert {:error, _} =
             Gaoxy.start_link(
               services: [
                 spec(:tcp, "first", %{port: free}),
                 spec(:tcp, "occupied", %{port: port})
               ]
             )

    eventually(fn ->
      case :gen_tcp.listen(free, ip: {127, 0, 0, 1}, active: false) do
        {:ok, socket} ->
          :gen_tcp.close(socket)
          true

        _ ->
          false
      end
    end)

    :gen_tcp.close(occupied)
  end

  @tag :loopback
  test "UDP preserves empty packets and oversize rejection; crashes do not close the socket" do
    pid = instance([spec(:udp, "echo", %{handler_options: self(), limits: %{max_packet: 8}})])
    {ip, port} = ready_udp_endpoint(pid)
    {:ok, client} = :gen_udp.open(0, [:binary, active: false])

    for bytes <- ["", "hello"] do
      :ok = :gen_udp.send(client, ip, port, bytes)
      assert {:ok, {^ip, ^port, ^bytes}} = :gen_udp.recv(client, 0, 1_000)
      assert_receive {:packet, _, %{data: ^bytes, destination: :unknown, interface: :unknown}}
    end

    :ok = :gen_udp.send(client, ip, port, "oversized")
    eventually(fn -> Gaoxy.status(pid, "echo").backend.dropped > 0 end)
    :ok = :gen_udp.send(client, ip, port, "crash")
    assert_receive {:packet, _, %{data: "crash"}}
    :ok = :gen_udp.send(client, ip, port, "alive")
    assert {:ok, {^ip, ^port, "alive"}} = :gen_udp.recv(client, 0, 1_000)
    :gen_udp.close(client)
  end

  @tag :loopback
  test "paused UDP retains its endpoint and admitted work can reply during drain" do
    pid = instance([spec(:udp, "echo", %{handler_options: self()})])
    {ip, port} = ready_udp_endpoint(pid)
    {:ok, client} = :gen_udp.open(0, [:binary, active: false])
    worker = admit_waiting_packet(client, {ip, port})
    assert :ok = Gaoxy.pause(pid, "echo")
    assert {^ip, ^port} = endpoint(pid)
    assert :ok = Gaoxy.resume(pid, "echo")
    owner = self()
    remover = spawn(fn -> send(owner, {:removed, Gaoxy.remove(pid, "echo", 1_000)}) end)
    assert is_pid(remover)
    eventually(fn -> Gaoxy.status(pid, "echo").state == :draining end)
    send(worker, :release)
    assert {:ok, {^ip, ^port, "done"}} = :gen_udp.recv(client, 0, 1_000)
    assert_receive {:removed, :ok}, 1_500
    assert {:error, :not_running} = Gaoxy.info(pid, "echo")
    :gen_udp.close(client)
  end

  @tag :loopback
  test "deadline forces cleanup and intentionally removed child remains stopped" do
    pid = instance([spec(:udp, "echo", %{handler_options: self()})])
    {ip, port} = ready_udp_endpoint(pid)
    {:ok, client} = :gen_udp.open(0, [:binary, active: false])
    worker = admit_waiting_packet(client, {ip, port})
    monitor = Process.monitor(worker)
    assert {:error, {:deadline_exceeded, :cleanup_pending}} = Gaoxy.remove(pid, "echo", 10)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    eventually(fn -> Gaoxy.services(pid) == [] end)
    assert {:error, :not_running} = Gaoxy.handle(pid, "echo")
    :gen_udp.close(client)
  end

  @tag :loopback
  test "sustained UDP overload stays bounded and callback watchdog recovers capacity" do
    pid =
      instance([
        spec(:udp, "echo", %{
          handler_options: self(),
          limits: %{max_active: 2, max_packet: 1024, max_bytes: 4096, callback_timeout: 500}
        }),
        spec(:udp, "other")
      ])

    {ip, port} = ready_udp_endpoint(pid)
    {:ok, client} = :gen_udp.open(0, [:binary, active: false])
    first = admit_waiting_packet(client, {ip, port})
    second = admit_waiting_packet(client, {ip, port})
    assert %{active: 2, backend: %{active_handlers: 2}} = Gaoxy.status(pid, "echo")
    for _ <- 1..1_000, do: :gen_udp.send(client, ip, port, "wait")
    eventually(fn -> Gaoxy.status(pid, "echo").backend.dropped > 0 end)

    assert %{
             active: active,
             retained_bytes: retained,
             queued_items: 0,
             backend: %{active_high_water: high, starting: starting}
           } = Gaoxy.status(pid, "echo")

    assert active <= 2 and high <= 2 and starting <= 1 and retained <= 4096
    {_, other} = ready_udp_endpoint(pid, "other")
    :ok = :gen_udp.send(client, ip, other, "isolated")
    assert {:ok, {^ip, ^other, "isolated"}} = :gen_udp.recv(client, 0, 1_000)
    eventually(fn -> not Process.alive?(first) and not Process.alive?(second) end)
    :gen_udp.close(client)
  end

  @tag :loopback
  test "TCP pause unbinds while admitted connections continue; resume reports its actual port" do
    pid = instance([spec(:tcp)])
    {ip, port} = endpoint(pid)
    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false])
    eventually(fn -> Gaoxy.status(pid, "echo").active == 1 end)
    assert :ok = Gaoxy.pause(pid, "echo")
    assert {:error, _} = :gen_tcp.connect(ip, port, [:binary, active: false], 500)
    :ok = :gen_tcp.send(client, "admitted\n")
    assert {:ok, "admitted\n"} = :gen_tcp.recv(client, 0, 1_000)
    assert :ok = Gaoxy.resume(pid, "echo")
    {^ip, new_port} = endpoint(pid)
    assert new_port > 0
    :gen_tcp.close(client)
  end

  @tag :loopback
  @tag :membership
  @tag :capture_log
  test "multicast changes are idempotent and preserve identity and desired state across restart" do
    pid =
      instance([
        spec(:udp, "membership", %{
          mode: :multicast,
          ip: {0, 0, 0, 0},
          limits: %{max_memberships: 1}
        })
      ])

    membership = {{239, 192, 74, 1}, {127, 0, 0, 1}}
    other = {{239, 192, 74, 2}, {127, 0, 0, 1}}
    handle = Gaoxy.handle(pid, "membership")
    local = endpoint(pid, "membership")

    assert :ok = Gaoxy.leave(pid, handle, membership)
    assert [] = Gaoxy.memberships(pid, handle)
    assert ^handle = Gaoxy.handle(pid, "membership")

    for _ <- 1..2 do
      assert :ok = Gaoxy.join(pid, handle, membership)
      assert [^membership] = Gaoxy.memberships(pid, handle)
      assert ^handle = Gaoxy.handle(pid, "membership")
      assert ^local = endpoint(pid, "membership")
    end

    assert {:error, :membership_limit} = Gaoxy.join(pid, handle, other)
    assert [^membership] = Gaoxy.memberships(pid, handle)

    restart = fn previous ->
      # Resolve the owned service only to inject failure; verify recovery through public APIs.
      {:ok, service, _} = GenServer.call(pid, {:lookup, "membership"})
      GenServer.stop(service, :fixture_restart)

      eventually(fn ->
        case Gaoxy.handle(pid, "membership") do
          %{generation: generation} = current when generation != previous.generation -> current
          _ -> false
        end
      end)
    end

    recovered = restart.(handle)
    assert [^membership] = Gaoxy.memberships(pid, recovered)
    assert {:error, :stale_generation} = Gaoxy.memberships(pid, handle)

    for _ <- 1..2 do
      assert :ok = Gaoxy.leave(pid, recovered, membership)
      assert [] = Gaoxy.memberships(pid, recovered)
      assert ^recovered = Gaoxy.handle(pid, "membership")
    end

    empty = restart.(recovered)
    assert [] = Gaoxy.memberships(pid, empty)
    assert ["membership"] = Gaoxy.services(pid)
  end
end
