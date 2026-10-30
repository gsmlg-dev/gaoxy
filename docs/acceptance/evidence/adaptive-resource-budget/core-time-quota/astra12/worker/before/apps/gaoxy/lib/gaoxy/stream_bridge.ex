defmodule Gaoxy.StreamBridge do
  @moduledoc false
  use Hell.Handler
  alias Gaoxy.{Admission, Lifecycle}

  # Set before accept/TLS handshake, not after buffers may already be queued.
  @receive_buffer 2_048
  def receive_buffer, do: @receive_buffer

  @impl true
  def handle_connection(socket, %{spec: spec, gate: gate} = state) do
    with {:ok, delivery} <- delivery_bound(socket),
         funded = 2 * delivery + 2 * spec.limits.max_state + spec.limits.max_output,
         {:ok, lease} <-
           Admission.acquire(gate, %{temporary_bytes: funded, transport_bytes: funded},
             kind: :connection,
             memberships: %{connection: make_ref()}
           ),
         :ok <- Admission.begin(gate, lease, funded),
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
         state =
           Map.merge(state, %{
             lease: lease,
             app: app,
             funded: funded,
             delivery_limit: delivery,
             delivery_bytes: 0
           }),
         :ok <- retain(state) do
      {:continue, state}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  @impl true
  def handle_data(bytes, socket, %{spec: spec, gate: gate, lease: lease, app: app} = state) do
    with true <- byte_size(bytes) <= state.delivery_limit || {:error, :delivery_limit},
         :ok <- Admission.begin(gate, lease, state.funded),
         :ok <- account(state, byte_size(bytes) + :erlang.external_size(app)) do
      # Preserve arbitrary delivery boundaries and the entire backing binary until
      # all chunks finish. The next receive/copy floor cannot fund callback output.
      chunks(bytes, socket, %{state | delivery_bytes: byte_size(bytes)}, spec.limits.max_packet)
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp chunks(<<>>, _socket, state, _limit) do
    case retain(state) do
      :ok -> {:continue, %{state | delivery_bytes: 0}}
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
               account(
                 state,
                 state.delivery_bytes + :erlang.external_size(state.app) +
                   :erlang.external_size(app) + IO.iodata_length(output)
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
           account(state, state.delivery_bytes + :erlang.external_size(state.app)) do
      chunks(rest, socket, state, limit)
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp retain(state) do
    with :ok <- state_bound(state.app, state.spec),
         :ok <- account(state, :erlang.external_size(state.app)),
         do: Admission.retain(state.gate, state.lease, state.funded)
  end

  defp account(state, retained) do
    Admission.repartition_until(
      state.gate,
      state.lease,
      %{
        retained_bytes: retained,
        temporary_bytes: state.funded - retained,
        transport_bytes: state.funded
      },
      make_ref(),
      Lifecycle.deadline(50)
    )
  end

  defp delivery_bound(socket) do
    # The supported OTP active-once profile can batch 100 receive buffers and
    # one maximum TLS 1.2 record. Read back the effective buffer; never infer it
    # from max_packet, which bounds callbacks rather than native deliveries.
    # Preserve BackendOptions' finite socket range: larger supported tuning
    # needs proportionally larger paid credit, not a narrower hidden cap.
    case Hell.Socket.getopts(socket, [:buffer]) do
      {:ok, [buffer: buffer]} when buffer in 1..2_147_483_647 ->
        {:ok, 100 * buffer + 18_437}

      _ ->
        {:error, :receive_buffer_limit}
    end
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

  defp terminate_app(reason, %{spec: spec, app: app, gate: gate, lease: lease} = state) do
    if function_exported?(spec.handler, :terminate, 2) do
      :ok = Admission.begin(gate, lease, state.funded)
      spec.handler.terminate(reason, app)
    end
  end

  defp terminate_app(_, _), do: :ok
end
