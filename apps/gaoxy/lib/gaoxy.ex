defmodule Gaoxy do
  @moduledoc "Embedded multi-instance transport runtime. Service IDs are scoped to the returned instance PID."
  def start_link(options \\ []) do
    with {:ok, plan} <- Gaoxy.Config.validate(options), do: Gaoxy.Instance.start_link(plan)
  end

  def child_spec(options),
    do: %{
      id: {__MODULE__, make_ref()},
      start: {__MODULE__, :start_link, [options]},
      restart: :transient
    }

  def add(instance, spec), do: GenServer.call(instance, {:add, spec}, :infinity)
  def services(instance), do: GenServer.call(instance, :services)
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

  def remove(instance, id, timeout \\ 5_000) when is_integer(timeout) and timeout >= 0 do
    with {:ok, pid, generation} <- GenServer.call(instance, {:lookup, id}),
         :ok <- GenServer.call(pid, {:drain, generation, timeout}, :infinity) do
      GenServer.call(instance, {:remove, id, pid}, :infinity)
    end
  end

  def stop(instance, timeout \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout

    for id <- services(instance) do
      remove(instance, id, max(0, deadline - System.monotonic_time(:millisecond)))
    end

    GenServer.stop(instance, :normal)
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
    with {:ok, pid, generation} <- GenServer.call(instance, {:lookup, id}) do
      GenServer.call(pid, {:request, generation, request})
    end
  catch
    :exit, {:noproc, _} -> {:error, :not_running}
  end
end
