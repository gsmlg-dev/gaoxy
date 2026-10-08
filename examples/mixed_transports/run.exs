defmodule MixedTransports.Stream do
  @behaviour Gaoxy.StreamHandler
  def init(metadata, _), do: {:ok, %{transport: metadata.transport}}
  def handle_data(bytes, state), do: {:send, bytes, state}
end

defmodule MixedTransports.Datagram do
  @behaviour Gaoxy.DatagramHandler
  def handle_datagram(%{data: bytes}, _), do: {:reply, bytes}
end

unless System.get_env("GAOXY_FIXTURE_CONFIRM") == "isolated" do
  raise "run only in an isolated fixture; set GAOXY_FIXTURE_CONFIRM=isolated"
end

interface = System.fetch_env!("GAOXY_FIXTURE_INTERFACE")

{:ok, address} =
  :inet.parse_address(String.to_charlist(System.fetch_env!("GAOXY_FIXTURE_ADDRESS")))

certificate = System.fetch_env!("GAOXY_FIXTURE_CERT")
key = System.fetch_env!("GAOXY_FIXTURE_KEY")

{:ok, runtime} =
  Gaoxy.start_link(
    services: [
      %{id: "tcp", transport: :tcp, ip: address, handler: MixedTransports.Stream},
      %{
        id: "tls",
        transport: :tls,
        ip: address,
        handler: MixedTransports.Stream,
        tls: %{provider: :otp, certfile: certificate, keyfile: key, alpn: ["gaoxy-echo-v1"]}
      },
      %{id: "unicast", transport: :udp, ip: address, handler: MixedTransports.Datagram},
      %{
        id: "broadcast",
        transport: :udp,
        mode: :broadcast,
        ip: {0, 0, 0, 0},
        handler: MixedTransports.Datagram
      },
      %{
        id: "multicast",
        transport: :udp,
        mode: :multicast,
        ip: {0, 0, 0, 0},
        handler: MixedTransports.Datagram,
        udp: %{
          memberships: [{{239, 192, 74, 1}, interface}, {{239, 192, 74, 2}, interface}],
          multicast_if: interface,
          multicast_loop: true,
          multicast_ttl: 1
        }
      }
    ]
  )

bound =
  for id <- Gaoxy.services(runtime) do
    {ip, port} =
      case Gaoxy.info(runtime, id).local do
        {:ok, address} -> address
        address -> address
      end

    %{id: id, address: ip |> :inet.ntoa() |> to_string(), port: port}
  end

IO.puts("MIXED_READY " <> JSON.encode!(%{services: bound}))
IO.puts("Mixed transports ready. Use the isolated fixture's independent peers.")
Process.sleep(:infinity)
