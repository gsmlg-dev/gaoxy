defmodule Gaoxy.DatagramBridge do
  @moduledoc false
  # Per-datagram `Abyss.DatagramHandler`: each admitted packet gets its own
  # worker process, which owns the Gaoxy admission lease and exits after the
  # callback, so the lease is released on every path (including a killed
  # callback). Output is sent through the endpoint send capability and awaited
  # so `Admission.finish_send/4` records the actual local outcome.
  @behaviour Abyss.DatagramHandler
  alias Gaoxy.{Admission, Lifecycle}

  # Matches Abyss's runtime `send_timeout` default for both writer admission
  # and outcome await; never beyond the remaining callback budget.
  @send_timeout 100

  @impl true
  def init(context, %{send: capability}), do: {:ok, %{context: context, send: capability}}

  @impl true
  def handle_datagram(%Abyss.Datagram{payload: bytes} = datagram, state) do
    %{spec: spec, gate: gate, scope: scope} = state.context
    deadline = Lifecycle.deadline(spec.limits.callback_timeout)

    with {:ok, lease} <-
           Admission.acquire(gate, byte_size(bytes),
             kind: :connection,
             memberships: %{connection: make_ref()}
           ),
         :ok <- Admission.begin(gate, lease, byte_size(bytes)) do
      packet = %{
        data: bytes,
        peer: {datagram.peer.addr, datagram.peer.port},
        local: datagram.local_endpoint,
        destination: :unknown,
        interface: :unknown,
        ancillary: datagram.ancillary
      }

      case spec.handler.handle_datagram(packet, spec.handler_options) do
        :ok ->
          :ok

        {:error, reason} ->
          Gaoxy.Telemetry.emit(:handler_error, %{count: 1}, scope, %{reason: reason})

        {:reply, output} ->
          send_output(
            reply_destination(datagram.peer),
            output,
            byte_size(bytes),
            lease,
            deadline,
            state
          )

        {:send, destination, output} ->
          send_output(destination, output, byte_size(bytes), lease, deadline, state)
      end
    end

    {:ok, state, []}
  end

  defp send_output(destination, output, input_size, lease, deadline, state) do
    %{spec: spec, gate: gate, scope: scope} = state.context
    size = IO.iodata_length(output)

    if size <= min(spec.limits.max_output, 65_507) do
      with :ok <- Admission.update(gate, lease, input_size + size) do
        case destination(destination, spec) do
          :ok ->
            with {:ok, operation} <- Admission.start_send(gate, lease, size) do
              result = transmit(state.send, destination, output, deadline)
              Admission.finish_send(gate, lease, operation, result)
            end

          error ->
            Gaoxy.Telemetry.emit(:send, %{bytes: size}, scope, %{outcome: error})
        end
      end
    else
      Gaoxy.Telemetry.emit(:admission_rejected, %{count: 1}, scope, %{reason: :output_limit})
    end
  end

  defp transmit(capability, destination, output, deadline) do
    with {:ok, ref} <-
           Abyss.Endpoint.send(
             capability,
             sockaddr(destination),
             IO.iodata_to_binary(output),
             send_timeout(deadline)
           ) do
      case Abyss.Endpoint.await(capability, ref, send_timeout(deadline)) do
        {:ok, _completed_at} -> :ok
        {:error, _reason} = error -> error
        # Admission records an awaited timeout as an unknown local outcome.
        {:unknown, ^ref} -> {:error, :timeout}
      end
    end
  end

  defp send_timeout(deadline), do: min(@send_timeout, Lifecycle.remaining(deadline))

  defp sockaddr({address, port}), do: Abyss.Datagram.sockaddr(address, port)
  defp sockaddr(%{} = scoped), do: scoped

  # Retain an observed IPv6 scope; otherwise reply exactly as an address/port.
  defp reply_destination(%{family: :inet6, scope_id: scope} = peer)
       when is_integer(scope) and scope > 0,
       do: Map.take(peer, [:family, :addr, :port, :scope_id])

  defp reply_destination(peer), do: {peer.addr, peer.port}

  defp destination({address, port}, spec) do
    if scope_required?(address),
      do: {:error, :destination_scope_required},
      else: address(address, port, spec)
  end

  defp destination(%{family: :inet6, addr: address, port: port, scope_id: scope} = target, spec)
       when is_integer(scope) and scope in 1..0xFFFFFFFF do
    if Map.keys(target) -- [:family, :addr, :port, :scope_id] == [] and
         tuple_size(spec.ip) == 8 and
         Abyss.Transport.UDP.Multicast.family(address) == :inet6 do
      address(address, port, spec)
    else
      {:error, :invalid_destination}
    end
  end

  defp destination(_, _), do: {:error, :invalid_destination}

  defp scope_required?({first, _, _, _, _, _, _, _}) when is_integer(first),
    do: Bitwise.band(first, 0xFFC0) == 0xFE80 or Bitwise.band(first, 0xFF00) == 0xFF00

  defp scope_required?(_), do: false

  defp address(address, port, spec) do
    family = Abyss.Transport.UDP.Multicast.family(address)

    cond do
      family == :invalid or not (is_integer(port) and port in 1..65_535) ->
        {:error, :invalid_destination}

      family != Abyss.Transport.UDP.Multicast.family(spec.ip) ->
        {:error, :destination_family_mismatch}

      Abyss.Transport.UDP.Multicast.multicast_address?(address) and spec.mode != :multicast ->
        {:error, :multicast_requires_multicast_mode}

      true ->
        :ok
    end
  end
end
