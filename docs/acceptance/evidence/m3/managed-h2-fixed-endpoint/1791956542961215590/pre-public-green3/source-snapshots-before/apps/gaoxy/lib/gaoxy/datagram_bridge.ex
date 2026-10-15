defmodule Gaoxy.DatagramBridge do
  @moduledoc false
  use Abyss.Handler
  alias Gaoxy.Admission

  @impl true
  def handle_data({peer, port, bytes}, state) do
    %{spec: spec, gate: gate, scope: scope} = state.server_config.handler_options

    with {:ok, lease} <- Admission.acquire(gate, byte_size(bytes)),
         :ok <- Admission.begin(gate, lease, byte_size(bytes)) do
      metadata = state.connection_span.start_metadata

      packet = %{
        data: bytes,
        peer: {peer, port},
        local: metadata[:local_info],
        destination: :unknown,
        interface: :unknown,
        ancillary: Map.get(metadata, :ancillary, [])
      }

      case spec.handler.handle_datagram(packet, spec.handler_options) do
        :ok ->
          :ok

        {:error, reason} ->
          Gaoxy.Telemetry.emit(:handler_error, %{count: 1}, scope, %{reason: reason})

        {:reply, output} ->
          send_output({peer, port}, output, byte_size(bytes), lease, state)

        {:send, destination, output} ->
          send_output(destination, output, byte_size(bytes), lease, state)
      end
    end

    {:close, state}
  end

  defp send_output(destination, output, input_size, lease, state) do
    %{spec: spec, gate: gate, scope: scope} = state.server_config.handler_options
    size = IO.iodata_length(output)

    if size <= min(spec.limits.max_output, 65_507) do
      with :ok <- Admission.update(gate, lease, input_size + size) do
        case destination(destination, spec) do
          :ok ->
            with {:ok, operation} <- Admission.start_send(gate, lease, size) do
              result = transmit(state, destination, output)
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

  defp transmit(state, {address, port}, output),
    do: state.server_config.transport_module.send(state.socket, address, port, output)

  defp transmit(state, address, output),
    do: state.server_config.transport_module.send(state.socket, address, output)

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
