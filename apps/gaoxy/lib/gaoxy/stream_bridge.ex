defmodule Gaoxy.StreamBridge do
  @moduledoc false
  use Hell.Handler
  alias Gaoxy.Admission

  @impl true
  def handle_connection(socket, %{spec: spec, gate: gate} = state) do
    with {:ok, lease} <-
           Admission.acquire(gate, 0, kind: :connection, memberships: %{connection: make_ref()}),
         :ok <- Admission.begin(gate, lease, 0),
         {:ok, local} <- Hell.Socket.sockname(socket),
         {:ok, peer} <- Hell.Socket.peername(socket),
         {:ok, app} <-
           spec.handler.init(
             %{
               local: local,
               peer: peer,
               transport: spec.transport,
               service: state.service,
               instance: state.instance,
               alpn: Hell.Socket.negotiated_protocol(socket)
             },
             spec.handler_options
           ),
         :ok <- retain(gate, lease, app, spec) do
      {:continue, Map.merge(state, %{lease: lease, app: app})}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  @impl true
  def handle_data(bytes, socket, %{spec: spec, gate: gate, lease: lease, app: app} = state) do
    with :ok <- Admission.begin(gate, lease, byte_size(bytes) + :erlang.external_size(app)) do
      # Delivery boundaries are arbitrary; split a large OS delivery without dropping stream bytes.
      chunks(bytes, socket, state, spec.limits.max_packet)
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp chunks(<<>>, _socket, state, _limit) do
    case retain(state.gate, state.lease, state.app, state.spec) do
      :ok -> {:continue, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp chunks(bytes, socket, state, limit) do
    size = min(byte_size(bytes), limit)
    <<chunk::binary-size(^size), rest::binary>> = bytes

    case state.spec.handler.handle_data(chunk, state.app) do
      {:continue, app} ->
        next(rest, socket, %{state | app: app}, limit)

      {:send, output, app} ->
        new_state = %{state | app: app}

        with :ok <- state_bound(app, state.spec),
             :ok <- output_bound(output, state.spec),
             :ok <-
               Admission.update(
                 state.gate,
                 state.lease,
                 byte_size(bytes) + :erlang.external_size(app) + IO.iodata_length(output)
               ),
             {:ok, operation} <-
               Admission.start_send(state.gate, state.lease, IO.iodata_length(output)),
             :ok <- send_output(socket, output, state, operation) do
          next(rest, socket, new_state, limit)
        else
          {:error, reason} -> {:error, reason, new_state}
        end

      {:close, app} ->
        {:close, %{state | app: app}}

      {:error, reason, app} ->
        {:error, reason, %{state | app: app}}
    end
  end

  defp send_output(socket, output, state, operation) do
    result = Hell.Socket.send(socket, output)
    :ok = Admission.finish_send(state.gate, state.lease, operation, result)
    result
  end

  defp next(rest, socket, state, limit) do
    with :ok <- state_bound(state.app, state.spec),
         :ok <-
           Admission.update(
             state.gate,
             state.lease,
             byte_size(rest) + :erlang.external_size(state.app)
           ) do
      chunks(rest, socket, state, limit)
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp retain(gate, lease, app, spec) do
    with :ok <- state_bound(app, spec),
         do: Admission.retain(gate, lease, :erlang.external_size(app))
  end

  defp state_bound(app, spec) do
    if :erlang.external_size(app) <= spec.limits.max_state, do: :ok, else: {:error, :state_limit}
  end

  defp output_bound(output, spec) do
    if IO.iodata_length(output) <= spec.limits.max_output, do: :ok, else: {:error, :output_limit}
  end

  @impl true
  def handle_close(_socket, state), do: terminate_app(:closed, state)
  @impl true
  def handle_error(reason, _socket, state), do: terminate_app(reason, state)
  @impl true
  def handle_shutdown(_socket, state), do: terminate_app(:shutdown, state)
  @impl true
  def handle_timeout(_socket, state), do: terminate_app(:idle_timeout, state)

  defp terminate_app(reason, %{spec: spec, app: app, gate: gate, lease: lease}) do
    if function_exported?(spec.handler, :terminate, 2) do
      :ok = Admission.begin(gate, lease, :erlang.external_size(app))
      spec.handler.terminate(reason, app)
    end
  end

  defp terminate_app(_, _), do: :ok
end
