defmodule Gaoxy do
  @moduledoc "Embedded multi-instance transport runtime. Service IDs are scoped to the returned instance PID."
  @doc """
  Starts an instance. `activation: :deferred` validates and retains the complete
  planned service set and shutdown budgets without opening listeners. Activate
  its finalized services with `activate/3`. The default is `:immediate`.
  """
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

  @doc "Returns shared memory policy, usage, quotas and sampling availability for an instance."
  def resource_budget(instance) do
    with %{server: server, instance: ref} <-
           Gaoxy.Lifecycle.call(instance, :resource_budget_context, Gaoxy.Lifecycle.deadline(50)) do
      Gaoxy.ResourceBudget.snapshot(server, ref)
    end
  end

  def services(instance),
    do: Gaoxy.Lifecycle.call(instance, :services, Gaoxy.Lifecycle.deadline(5_000))

  @doc """
  Activates the complete finalized set of a deferred instance under one deadline.

  IDs, bindings, transports and fixed options must match the planned services;
  resource/shutdown ceilings may decrease, and `handler_options` may be prepared
  for this instance. Every final specification is validated before the first bind.

  Options are a finite `:timeout` in milliseconds (default 5000), an optional
  absolute monotonic-millisecond `:deadline` which can only shorten it, and an
  `:operation_id` reference or bounded string. A confirmed success returns
  `{:ok, handles}`. Timeout returns `{:error, {:activation_pending, operation_id}}`;
  the instance retains late startup and rollback ownership. Inspect that identity
  with `activation_status/2` before retrying. Conflicting identity reuse fails.
  At most the in-flight and most recent terminal receipt are retained.
  """
  def activate(instance, services, options \\ []) do
    with {:ok, operation, deadline} <- activation_options(options) do
      case Gaoxy.Lifecycle.call(instance, {:activate, services, operation, deadline}, deadline) do
        {:error, {:deadline_exceeded, :cleanup_pending}} ->
          {:error, {:activation_pending, operation}}

        result ->
          result
      end
    end
  end

  @doc """
  Returns a bounded activation receipt, including `:pending`, `:committed` or
  `:rejected` status, its result and `:pending`/`:complete` cleanup state.
  An evicted identity is `{:error, :unknown_operation}`; loss of the instance is
  `{:error, :not_running}`, neither of which proves a rejected activation.
  """
  def activation_status(instance, operation_id),
    do:
      Gaoxy.Lifecycle.call(
        instance,
        {:activation_status, operation_id},
        Gaoxy.Lifecycle.deadline(5_000)
      )

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
        Gaoxy.Config.shutdown_timeout(%{
          drain_timeout: Gaoxy.Instance.drain_timeout(plan.services)
        })

      _ ->
        Gaoxy.Config.shutdown_timeout(%{})
    end
  end

  defp activation_options(options) do
    with true <- Keyword.keyword?(options),
         true <- length(options) == map_size(Map.new(options)),
         true <- Keyword.keys(options) -- [:timeout, :deadline, :operation_id] == [],
         timeout = Keyword.get(options, :timeout, 5_000),
         true <- is_integer(timeout) and timeout >= 0,
         relative = Gaoxy.Lifecycle.deadline(timeout),
         deadline = Keyword.get(options, :deadline, relative),
         true <- is_integer(deadline),
         operation = Keyword.get_lazy(options, :operation_id, &make_ref/0),
         true <-
           is_reference(operation) or
             (is_binary(operation) and byte_size(operation) in 1..128) do
      {:ok, operation, min(relative, deadline)}
    else
      _ -> {:error, :invalid_activation_options}
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
      mtls: :supported,
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
