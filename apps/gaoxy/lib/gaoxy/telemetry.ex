defmodule Gaoxy.Telemetry do
  @moduledoc false
  def emit(event, measurements, scope, metadata \\ %{}) do
    :telemetry.execute([:gaoxy, event], measurements, Map.merge(scope, metadata))
  end

  def attach_backend do
    case :telemetry.attach(
           __MODULE__,
           [:abyss, :datagram, :dropped],
           &__MODULE__.forward_backend_drop/4,
           nil
         ) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end

  def bind_backend(backend, scope),
    do: Registry.register(Gaoxy.Registry, {__MODULE__, backend}, scope)

  def forward_backend_drop(_, measurements, %{server_id: backend, reason: reason}, _) do
    bindings =
      case Gaoxy.RegistryPolicy.lookup({__MODULE__, backend}) do
        {:ok, bindings} -> bindings
        {:error, :registry_unavailable} -> []
      end

    for {_, scope} <- bindings do
      reason = if reason == :suspended, do: :paused, else: reason

      reason =
        if reason in [:paused, :draining, :packet_too_large, :handler_limit, :starting_limit],
          do: reason,
          else: :backend_rejected

      emit(:admission_rejected, %{count: 1, bytes: measurements.bytes}, scope, %{
        source: :backend,
        reason: reason
      })
    end
  end
end
