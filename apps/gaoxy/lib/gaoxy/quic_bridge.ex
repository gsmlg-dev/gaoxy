defmodule Gaoxy.QUICBridge do
  @moduledoc false
  @behaviour Abyss.QUIC.Handler
  alias Gaoxy.{Admission, QUIC}

  @impl true
  def init(handle, metadata, %{spec: spec, gate: gate, scope: scope} = context) do
    with {:ok, lease} <- Admission.acquire(gate, 0),
         :ok <- Admission.begin(gate, lease, 0) do
      connection = %QUIC.Connection{
        handle: handle,
        gate: gate,
        lease: lease,
        limits: spec.limits,
        scope: scope
      }

      with {:ok, app} <- spec.handler.init(connection, metadata, spec.handler_options),
           :ok <- retain(connection, app) do
        {:ok, Map.merge(context, %{connection: connection, app: app})}
      end
    end
  end

  @impl true
  def handle_event(event, %{connection: connection, app: app} = state) do
    with :ok <- Admission.begin(connection.gate, connection.lease, :erlang.external_size(app)) do
      case state.spec.handler.handle_event(event(event, connection), app) do
        {:ok, next} ->
          case retain(connection, next) do
            :ok -> {:ok, %{state | app: next}}
            {:error, reason} -> {:stop, reason, state}
          end

        {:stop, reason, next} ->
          case retain(connection, next) do
            :ok -> {:stop, reason, %{state | app: next}}
            {:error, failure} -> {:stop, failure, state}
          end
      end
    else
      {:error, reason} -> {:stop, reason, state}
    end
  end

  @impl true
  def terminate(reason, state) do
    if function_exported?(state.spec.handler, :terminate, 2) do
      :ok =
        Admission.begin(
          state.connection.gate,
          state.connection.lease,
          :erlang.external_size(state.app)
        )

      state.spec.handler.terminate(reason, state.app)
    end
  end

  defp event({:stream_open, handle, kind}, connection),
    do: {:stream_open, %QUIC.Stream{handle: handle, connection: connection}, kind}

  defp event({:readable, handle}, connection),
    do: {:readable, %QUIC.Stream{handle: handle, connection: connection}}

  defp event({:stopped, handle, code}, connection),
    do: {:stopped, %QUIC.Stream{handle: handle, connection: connection}, code}

  defp event(other, _), do: other

  defp retain(connection, app) do
    size = :erlang.external_size(app)

    if size <= connection.limits.max_state,
      do: Admission.retain(connection.gate, connection.lease, size),
      else: {:error, :state_limit}
  end
end
