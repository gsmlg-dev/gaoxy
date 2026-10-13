defmodule Gaoxy do
  @moduledoc "Embedded multi-instance transport runtime. Service IDs are scoped to the returned instance PID."
  def start_link(options \\ []) do
    with {:ok, plan} <- Gaoxy.Config.validate(options), do: Gaoxy.Instance.start_link(plan)
  end

  def child_spec(options),
    do: %{
      id: {__MODULE__, make_ref()},
      start: {__MODULE__, :start_link, [options]},
      restart: :transient,
      shutdown: shutdown_timeout(options)
    }

  def add(instance, spec),
    do: Gaoxy.Lifecycle.call(instance, {:add, spec}, Gaoxy.Lifecycle.deadline(5_000))

  def services(instance),
    do: Gaoxy.Lifecycle.call(instance, :services, Gaoxy.Lifecycle.deadline(5_000))

  @doc "Registers the calling process as an instance-lifetime cleanup participant before it allocates resources. A timeout does not authorize allocation."
  def register_lifecycle_participant(instance, timeout_ms)
      when is_integer(timeout_ms) and timeout_ms >= 0 do
    deadline = Gaoxy.Lifecycle.deadline(timeout_ms)
    Gaoxy.Lifecycle.call(instance, {:register_lifecycle_participant, deadline}, deadline)
  end

  def handle(instance, id), do: service_call(instance, id, :handle)
  def info(instance, id), do: service_call(instance, id, :info)
  def status(instance, id), do: service_call(instance, id, :status)
  def pause(instance, id), do: service_call(instance, id, :pause)
  def resume(instance, id), do: service_call(instance, id, :resume)
  def memberships(instance, id), do: service_call(instance, id, :memberships)

  def join(instance, id, membership),
    do: service_call(instance, id, {:membership, :join, membership})

  def leave(instance, id, membership),
    do: service_call(instance, id, {:membership, :leave, membership})

  @doc "Removes one service within a total operation budget. Deadline errors mean cleanup remains owned and may still be in progress."
  def remove(instance, id, timeout \\ 5_000) when is_integer(timeout) and timeout >= 0 do
    deadline = Gaoxy.Lifecycle.deadline(timeout)
    Gaoxy.Lifecycle.call(instance, {:remove, id, deadline}, deadline)
  end

  @doc "Stops admission across all services and registered cleanup participants, sharing one deadline."
  def stop(instance, timeout \\ 5_000) when is_integer(timeout) and timeout >= 0 do
    deadline = Gaoxy.Lifecycle.deadline(timeout)
    monitor = Process.monitor(instance)
    result = Gaoxy.Lifecycle.call(instance, {:stop, deadline}, deadline)

    result =
      if result == :ok do
        receive do
          {:DOWN, ^monitor, :process, _, _} -> :ok
        after
          Gaoxy.Lifecycle.remaining(deadline) -> {:error, {:deadline_exceeded, :cleanup_pending}}
        end
      else
        result
      end

    Process.demonitor(monitor, [:flush])
    result
  end

  defp shutdown_timeout(options) do
    case Gaoxy.Config.validate(options) do
      {:ok, plan} ->
        Gaoxy.Instance.drain_timeout(plan.services) + 2 * Gaoxy.Lifecycle.cleanup_headroom()

      _ ->
        7_000
    end
  end

  def capabilities do
    %{
      tcp: :supported,
      tls_otp: :supported,
      udp_unicast: :supported,
      udp_broadcast_ipv4: :supported,
      udp_multicast_ipv4: :supported,
      udp_multicast_ipv6: if(:os.type() == {:unix, :linux}, do: :not_tested, else: :unsupported),
      tls_ex_ssl: :unsupported,
      quic: if(Code.ensure_loaded?(Quic), do: :experimental, else: :unsupported),
      http: :unsupported,
      mtls: :unsupported,
      metadata_destination: :not_tested
    }
  end

  defp service_call(instance, id, request) do
    deadline = Gaoxy.Lifecycle.deadline(5_000)

    with {:ok, pid, generation} <- Gaoxy.Lifecycle.call(instance, {:lookup, id}, deadline) do
      Gaoxy.Lifecycle.call(pid, {:request, generation, request}, deadline)
    end
  end
end
