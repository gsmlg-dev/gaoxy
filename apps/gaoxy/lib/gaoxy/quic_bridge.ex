defmodule Gaoxy.QUICBridge do
  @moduledoc false
  @behaviour Abyss.QUIC.Handler
  alias Gaoxy.{Admission, Lifecycle, QUIC, Service}

  @native_byte_metrics [
    :queued_bytes,
    :ready_bytes,
    :receive_buffered_bytes,
    :io_queue_bytes,
    :operation_result_bytes
  ]

  @impl true
  def init(handle, metadata, %{spec: spec, gate: gate, scope: scope} = context) do
    deadline = Lifecycle.deadline(spec.limits.callback_timeout)

    connection = %QUIC.Connection{
      handle: handle,
      gate: gate,
      lease: make_ref(),
      limits: spec.limits,
      scope: scope,
      service: Map.get(context, :service),
      instance: Map.get(context, :instance)
    }

    with {:ok, native} <- native_bytes({:ok, metadata}),
         {:ok, lease, cleanup} <-
           Service.acquire_native(connection.service, connection, native, deadline),
         true <- Lifecycle.remaining(deadline) > 0 || {:error, :deadline_exceeded},
         :ok <- Admission.begin_callback(gate, lease, 0, deadline) do
      connection = %{connection | lease: lease, native_cleanup: cleanup}

      with {:ok, app} <- spec.handler.init(connection, metadata, spec.handler_options),
           {:ok, bytes} <- retain(connection, app, native, deadline) do
        {:ok, Map.merge(context, %{connection: connection, app: app, accounted_bytes: bytes})}
      end
    end
  end

  @impl true
  def handle_event(event, %{connection: connection, app: app} = state) do
    deadline = Lifecycle.deadline(connection.limits.callback_timeout)
    closed = match?({:closed, _}, event)

    with {:ok, before_native} <- inspect_native(connection, deadline, closed),
         :ok <- update_native(connection, before_native, deadline),
         :ok <-
           Admission.begin_callback(
             connection.gate,
             connection.lease,
             :erlang.external_size(app),
             deadline
           ) do
      case state.spec.handler.handle_event(event(event, connection), app) do
        {:ok, next} -> retain_result(:ok, state, next, deadline, closed)
        {:stop, reason, next} -> retain_result({:stop, reason}, state, next, deadline, closed)
      end
    else
      {:error, reason} -> {:stop, reason, state}
    end
  catch
    :exit, _ -> {:stop, :admission_unavailable, state}
  end

  defp retain_result(result, state, next, deadline, closed) do
    with {:ok, native} <- inspect_native(state.connection, deadline, closed),
         {:ok, bytes} <- retain(state.connection, next, native, deadline) do
      state = %{state | app: next, accounted_bytes: bytes}

      case result do
        :ok -> {:ok, state}
        {:stop, reason} -> {:stop, reason, state}
      end
    else
      {:error, reason} -> {:stop, reason, state}
    end
  end

  @impl true
  def terminate(reason, state) do
    # Admission can enter draining before the host delivers its shutdown event.
    # Close through the public API before callback DOWN makes the engine stop;
    # the guardian still requires exact terminal proof before releasing bytes.
    if reason == :draining, do: QUIC.close(state.connection)

    if function_exported?(state.spec.handler, :terminate, 2) do
      # The owner keeps its last complete charge during teardown. Its actual
      # terminal pair releases it; unavailable inspection never becomes zero.
      deadline = Lifecycle.deadline(state.connection.limits.callback_timeout)

      case Admission.begin_native_cleanup(
             state.connection.gate,
             state.connection.lease,
             state.accounted_bytes,
             deadline
           ) do
        :ok -> state.spec.handler.terminate(reason, state.app)
        _ -> :ok
      end
    end
  catch
    :exit, _ -> :ok
  end

  defp event({:stream_open, handle, kind}, connection),
    do: {:stream_open, %QUIC.Stream{handle: handle, connection: connection}, kind}

  defp event({:readable, handle}, connection),
    do: {:readable, %QUIC.Stream{handle: handle, connection: connection}}

  defp event({:stopped, handle, code}, connection),
    do: {:stopped, %QUIC.Stream{handle: handle, connection: connection}, code}

  defp event(other, _), do: other

  # These public counters describe disjoint queued ownership: scheduler payloads,
  # ready receives, out-of-order receives, native I/O queue and operation results.
  # Packet/stream counts and crypto cursors are deliberately not memory sizes.
  @doc false
  def native_bytes({:ok, %{resources: resources}}) when is_map(resources) do
    Enum.reduce_while(@native_byte_metrics, {:ok, 0}, fn key, {:ok, bytes} ->
      case Map.fetch(resources, key) do
        {:ok, value} when is_integer(value) and value >= 0 -> {:cont, {:ok, bytes + value}}
        _ -> {:halt, {:error, :native_resources_unavailable}}
      end
    end)
  end

  def native_bytes(_), do: {:error, :native_resources_unavailable}

  # A callback notification only asks the independent observer to inspect the
  # original handle. It cannot refund native memory or connection membership.
  defp inspect_native(connection, deadline, true) do
    {guardian, token} = connection.native_cleanup
    send(guardian, {:gaoxy_native_closed, token})
    if Lifecycle.remaining(deadline) > 0, do: {:ok, :closed}, else: {:error, :deadline_exceeded}
  end

  defp inspect_native(connection, deadline, false) do
    if Lifecycle.remaining(deadline) > 0 do
      result = QUIC.info(connection)

      if Lifecycle.remaining(deadline) > 0,
        do: native_bytes(result),
        else: {:error, :deadline_exceeded}
    else
      {:error, :deadline_exceeded}
    end
  catch
    :exit, _ -> {:error, :native_resources_unavailable}
  end

  defp retain(connection, app, native, deadline) do
    size = :erlang.external_size(app)

    cond do
      Lifecycle.remaining(deadline) == 0 ->
        {:error, :deadline_exceeded}

      size > connection.limits.max_state ->
        {:error, :state_limit}

      true ->
        with :ok <- update_native(connection, native, deadline),
             :ok <- Admission.end_request(connection.gate, connection.lease, size, deadline) do
          {:ok, size}
        end
    end
  end

  defp update_native(_, :closed, _), do: :ok

  defp update_native(connection, native, deadline),
    do: Admission.update_native(connection.gate, connection.lease, native, deadline)
end
