defmodule Gaoxy.RuntimeInstanceNetworkTest do
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
    eventually(fn ->
      %{local: local} = Gaoxy.info(pid, id)

      address =
        case local do
          {:ok, address} -> address
          address -> address
        end

      case address do
        {ip, port} when is_integer(port) and port in 1..65_535 ->
          if :inet.is_ip_address(ip), do: address, else: false

        _ ->
          false
      end
    end)
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
end
