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
         # Old/new state, its encoded and decoded forms can overlap. Output
         # retains its original, flattened and detached forms while normalizing.
         funded = 2 * delivery + 4 * spec.limits.max_state + 3 * spec.limits.max_output,
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
           ) do
      state =
        Map.merge(state, %{
          lease: lease,
          app: app,
          funded: funded,
          delivery_limit: delivery,
          delivery_bytes: 0
        })

      case normalize_app(app, spec) do
        {:ok, app} ->
          state = %{state | app: app}

          case retain(state) do
            :ok -> {:continue, state}
            {:error, reason} -> {:error, reason, state}
          end

        {:error, reason} ->
          # Initialization returned this original state, so its cleanup hook
          # must still own it even when it cannot enter retained accounting.
          {:error, reason, state}
      end
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

    result = state.spec.handler.handle_data(chunk, state.app)
    finish_callback(result, rest, socket, state, limit)
  end

  defp finish_callback(result, rest, socket, state, limit) do
    original_app = elem(result, tuple_size(result) - 1)

    case normalize_app(original_app, state.spec) do
      {:ok, app} ->
        next_state = %{state | app: app}

        case result do
          {:continue, _} ->
            next(rest, socket, next_state, limit)

          {:send, output, _} ->
            case normalize_output(output, state.spec) do
              {:ok, owned_output} ->
                # Tail handoff drops the callback's borrowed output and original
                # app before starting a send or retaining the next callback state.
                send_prepared(rest, socket, next_state, limit, owned_output)

              {:error, reason} ->
                {:error, reason, next_state}
            end

          {:close, _} ->
            {:close, next_state}

          {:error, reason, _} ->
            {:error, reason, next_state}
        end

      {:error, reason} ->
        # Never adopt a decoded state whose identity changed. Preserve the exact
        # callback-returned state for terminal cleanup, not for another callback.
        {:error, reason, %{state | app: original_app}}
    end
  end

  defp send_prepared(rest, socket, state, limit, output) do
    with :ok <-
           account(
             state,
             state.delivery_bytes + :erlang.external_size(state.app) + byte_size(output)
           ),
         {:ok, operation} <- Admission.start_send(state.gate, state.lease, byte_size(output)),
         :ok <- send_output(socket, output, state, operation) do
      next(rest, socket, state, limit)
    else
      {:error, reason} -> {:error, reason, state}
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

  defp normalize_app(app, spec) do
    with :ok <- state_bound(app, spec),
         encoded = :erlang.term_to_binary(app),
         true <- byte_size(encoded) <= spec.limits.max_state || {:error, :state_limit},
         detached = :erlang.binary_to_term(encoded),
         true <- detached === app || {:error, :state_identity_changed} do
      {:ok, detached}
    end
  rescue
    ArgumentError -> {:error, :state_encoding_failed}
    SystemLimitError -> {:error, :state_encoding_failed}
  end

  defp normalize_output(output, spec) do
    if IO.iodata_length(output) <= spec.limits.max_output do
      # iodata_to_binary alone may return the original borrowed binary unchanged.
      {:ok, output |> IO.iodata_to_binary() |> :binary.copy()}
    else
      {:error, :output_limit}
    end
  rescue
    ArgumentError -> {:error, :invalid_output}
    SystemLimitError -> {:error, :output_limit}
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
