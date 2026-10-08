defmodule Gaoxy.DatagramHandler do
  @moduledoc """
  One isolated invocation per admitted packet, including empty packets.

  `{:reply, bytes}` sends to the received peer. `{:send, destination, bytes}`
  sends from the same owned endpoint to an explicit address/port or scoped IPv6
  sockaddr. Multicast requires multicast mode. No shared socket is exposed.
  Local send outcomes are telemetry, not proof of delivery; actions never retry.
  """
  @type destination ::
          {:inet.ip_address(), :inet.port_number()}
          | %{
              family: :inet6,
              addr: :inet.ip6_address(),
              port: :inet.port_number(),
              scope_id: pos_integer()
            }
  @callback handle_datagram(map(), term()) ::
              :ok | {:reply, iodata()} | {:send, destination(), iodata()} | {:error, term()}
end
