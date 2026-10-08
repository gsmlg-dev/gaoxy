defmodule Gaoxy.NetworkFixture.Handler do
  @behaviour Gaoxy.DatagramHandler
  def handle_datagram(%{data: "SEND " <> request}, _) do
    %{"address" => text, "port" => port, "payload" => payload} = action = JSON.decode!(request)
    address = Gaoxy.NetworkFixture.Control.address(text)

    destination =
      if tuple_size(address) == 8 do
        {:ok, scope} =
          Abyss.Transport.UDP.Multicast.resolve_interface(action["interface"], :inet6)

        %{family: :inet6, addr: address, port: port, scope_id: scope}
      else
        {address, port}
      end

    {:send, destination, Base.decode64!(payload)}
  end

  def handle_datagram(%{data: bytes, peer: {peer, _}}, _) do
    family = if tuple_size(peer) == 4, do: 4, else: 6
    encoded = if bytes == "", do: "-", else: Base.encode64(bytes)
    IO.puts("WIRE RX#{family} #{encoded}")
    {:reply, "reply:" <> bytes}
  end
end

defmodule Gaoxy.NetworkFixture.Control do
  def address(text) do
    {:ok, ip} = :inet.parse_address(String.to_charlist(text))
    ip
  end

  def start(port4, port6, broadcast_port) do
    backend =
      case System.fetch_env!("GAOXY_UDP_BACKEND") do
        "inet" -> :inet
        "socket" -> :socket
      end

    services = [
      %{
        id: "broadcast",
        transport: :udp,
        mode: :broadcast,
        port: broadcast_port,
        ip: {0, 0, 0, 0},
        handler: Gaoxy.NetworkFixture.Handler,
        udp: %{inet_backend: backend}
      },
      %{
        id: "4",
        transport: :udp,
        mode: :multicast,
        port: port4,
        ip: {0, 0, 0, 0},
        handler: Gaoxy.NetworkFixture.Handler,
        limits: %{max_memberships: 4},
        udp: %{
          inet_backend: backend,
          memberships: [
            {address("239.192.74.1"), "eth0"},
            {address("239.192.74.2"), "eth0"}
          ],
          multicast_if: "eth0",
          multicast_ttl: 7,
          multicast_loop: true
        }
      }
    ]

    services =
      if System.get_env("GAOXY_NETWORK_IPV6") == "1" do
        services ++
          [
            %{
              id: "6",
              transport: :udp,
              mode: :multicast,
              port: port6,
              ip: {0, 0, 0, 0, 0, 0, 0, 0},
              handler: Gaoxy.NetworkFixture.Handler,
              limits: %{max_memberships: 4},
              udp: %{
                inet_backend: backend,
                memberships: [{address("ff02::114"), "eth0"}, {address("ff02::115"), "eth0"}],
                multicast_if: "eth0",
                multicast_ttl: 7,
                multicast_loop: true
              }
            }
          ]
      else
        services
      end

    # Independent egress endpoints select the second fabric and disable local
    # loopback; the original endpoints above retain loopback on the first fabric.
    outgoing =
      for service <- services, service.mode == :multicast do
        %{
          service
          | id: service.id <> "-out",
            port: service.port + 10,
            udp: %{
              inet_backend: backend,
              memberships: [],
              multicast_if: "eth1",
              multicast_ttl: 9,
              multicast_loop: false
            }
        }
      end

    :telemetry.attach(
      "network-send-results",
      [:gaoxy, :send],
      fn _, _, metadata, _ ->
        IO.puts("WIRE SEND #{metadata.service} #{inspect(metadata.outcome)}")
      end,
      nil
    )

    {:ok, runtime} = Gaoxy.start_link(services: services ++ outgoing)
    runtime
  end

  def execute(["JOIN", family, group, interface], runtime),
    do: Gaoxy.join(runtime, family, {address(group), interface})

  def execute(["LEAVE", family, group, interface], runtime),
    do: Gaoxy.leave(runtime, family, {address(group), interface})

  def execute(["LIMIT", family], runtime) do
    groups =
      if family == "4",
        do: ["239.192.74.3", "239.192.74.4", "239.192.74.5"],
        else: ["ff02::116", "ff02::117", "ff02::118"]

    [first, second, third] = Enum.map(groups, &{address(&1), "eth0"})
    :ok = Gaoxy.join(runtime, family, first)
    :ok = Gaoxy.join(runtime, family, second)
    {:error, :membership_limit} = Gaoxy.join(runtime, family, third)
    :ok = Gaoxy.leave(runtime, family, first)
    :ok = Gaoxy.leave(runtime, family, second)
    :ok
  end

  def execute(["ROLLBACK", family], runtime) do
    # Public activation must fail and leave its requested port available.
    {ip, group} =
      if family == "4",
        do: {{0, 0, 0, 0}, address("239.192.74.9")},
        else: {{0, 0, 0, 0, 0, 0, 0, 0}, address("ff02::119")}

    port = if family == "4", do: 38749, else: 38750

    invalid = %{
      id: "rollback",
      transport: :udp,
      mode: :multicast,
      ip: ip,
      port: port,
      handler: Gaoxy.NetworkFixture.Handler,
      udp: %{memberships: [{group, "gaoxy-interface-does-not-exist"}]}
    }

    {:error, _} = Gaoxy.add(runtime, invalid)
    {:error, :not_running} = Gaoxy.info(runtime, "rollback")
    valid = put_in(invalid.udp.memberships, [{group, "eth0"}])
    {:ok, _} = Gaoxy.add(runtime, valid)
    :ok = Gaoxy.remove(runtime, "rollback", 1_000)
    :ok
  end

  def execute(["PAUSE", family], runtime) do
    local = Gaoxy.info(runtime, family).local
    memberships = Gaoxy.memberships(runtime, family)
    :ok = Gaoxy.pause(runtime, family)
    ^local = Gaoxy.info(runtime, family).local
    ^memberships = Gaoxy.memberships(runtime, family)
    :ok
  end

  def execute(["DROPPED", family], runtime) do
    deadline = System.monotonic_time(:millisecond) + 5_000
    until(fn -> Gaoxy.status(runtime, family).backend.dropped > 0 end, deadline)
  end

  def execute(["RESUME", family], runtime), do: Gaoxy.resume(runtime, family)

  def execute(["RESTART", family], runtime) do
    previous = Gaoxy.handle(runtime, family)
    memberships = Gaoxy.memberships(runtime, family)
    local = Gaoxy.info(runtime, family).local
    sibling = Gaoxy.handle(runtime, "broadcast")
    # Fault injection alone resolves the owned process. Recovery assertions use
    # public generation, membership, binding and status operations.
    {:ok, service, _} = GenServer.call(runtime, {:lookup, family})
    GenServer.stop(service, :fixture_restart)

    :ok =
      until(
        fn ->
          case Gaoxy.handle(runtime, family) do
            %{generation: generation} when generation != previous.generation -> true
            _ -> false
          end
        end,
        System.monotonic_time(:millisecond) + 5_000
      )

    ^memberships = Gaoxy.memberships(runtime, family)
    ^local = Gaoxy.info(runtime, family).local
    ^sibling = Gaoxy.handle(runtime, "broadcast")
    {:error, :stale_generation} = Gaoxy.memberships(runtime, previous)
    :ok
  end

  def execute(["BARRIER"], _), do: :ok
  def execute(["STOP"], runtime), do: Gaoxy.stop(runtime, 1_000)

  def run(runtime) do
    case IO.gets("") do
      :eof ->
        Gaoxy.stop(runtime, 1_000)

      line ->
        [id | command] = String.split(String.trim(line))

        case execute(command, runtime) do
          :ok ->
            IO.puts("WIRE OK #{id}")

          error ->
            IO.puts("WIRE ERROR #{id} #{inspect(error)}")
            raise "fixture operation failed"
        end

        if command != ["STOP"], do: run(runtime)
    end
  end

  defp until(predicate, deadline) do
    cond do
      predicate.() ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        {:error, :paused_receive_deadline}

      true ->
        receive do
        after
          5 -> until(predicate, deadline)
        end
    end
  end
end

[port4, port6, broadcast_port] = Enum.map(System.argv(), &String.to_integer/1)
runtime = Gaoxy.NetworkFixture.Control.start(port4, port6, broadcast_port)

IO.puts(
  "WIRE RUNTIME " <>
    inspect(%{
      otp: to_string(:erlang.system_info(:otp_release)),
      elixir: System.version(),
      backend: System.fetch_env!("GAOXY_UDP_BACKEND")
    })
)

IO.puts("WIRE READY")
Gaoxy.NetworkFixture.Control.run(runtime)
