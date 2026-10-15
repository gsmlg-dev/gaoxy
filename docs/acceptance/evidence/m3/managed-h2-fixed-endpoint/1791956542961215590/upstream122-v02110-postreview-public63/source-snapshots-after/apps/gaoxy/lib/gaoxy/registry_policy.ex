defmodule Gaoxy.RegistryPolicy do
  @moduledoc false
  @recovery_timeout 1_000
  @retry_interval 25

  def watch_name({:via, Registry, {Gaoxy.Registry, key}}), do: watch_registry_name(key, nil)

  def watch_name({:via, Registry, {Gaoxy.Registry, key, value}}),
    do: watch_registry_name(key, value)

  def watch_name(_), do: {:ok, nil}

  defp watch_registry_name(key, value) do
    # The via-name was registered by GenServer before init. Re-register only
    # this process's key to obtain the public registration-owner PID.
    Registry.unregister(Gaoxy.Registry, key)

    case Registry.register(Gaoxy.Registry, key, value) do
      {:ok, owner} -> {:ok, Process.monitor(owner)}
      {:error, _} -> {:error, :registry_unavailable}
    end
  rescue
    ArgumentError -> {:error, :registry_unavailable}
  catch
    :exit, _ -> {:error, :registry_unavailable}
  end

  def register(scope) do
    policy = %{scope: scope, backend: nil, owners: %{}, recovery: nil}

    case register_key(policy, {scope.instance, scope.service}, scope.generation) do
      {:ok, policy} ->
        {:ok, policy}

      {:error, policy} ->
        cancel(policy)
        {:error, :registry_unavailable}
    end
  end

  def bind(policy, backend) do
    case register_key(policy, {Gaoxy.Telemetry, backend}, policy.scope) do
      {:ok, policy} ->
        {:ok, %{policy | backend: backend}}

      {:error, policy} ->
        cancel(policy)
        {:error, :registry_unavailable}
    end
  end

  def lookup(key) do
    {:ok, Registry.lookup(Gaoxy.Registry, key)}
  rescue
    ArgumentError -> {:error, :registry_unavailable}
  catch
    :exit, _ -> {:error, :registry_unavailable}
  end

  def loss(policy, monitor) do
    cond do
      not Map.has_key?(policy.owners, monitor) ->
        :ignore

      policy.recovery != nil ->
        {:recovering, policy}

      true ->
        token = make_ref()
        timer = Process.send_after(self(), {:registry_recover, token}, 0)
        recovery = %{token: token, deadline: now() + @recovery_timeout, timer: timer}
        {:recovering, %{policy | recovery: recovery}}
    end
  end

  def recover(%{recovery: %{token: token}} = policy, token) do
    if now() >= policy.recovery.deadline do
      {:expired, policy}
    else
      scope = policy.scope

      result =
        with {:ok, next} <-
               register_key(policy, {scope.instance, scope.service}, scope.generation),
             {:ok, next} <- register_key(next, {Gaoxy.Telemetry, policy.backend}, scope) do
          {:ok, next}
        end

      case result do
        {:ok, next} ->
          {:ok, %{next | recovery: nil}}

        {:error, next} ->
          delay = min(@retry_interval, max(0, next.recovery.deadline - now()))
          timer = Process.send_after(self(), {:registry_recover, token}, delay)
          {:retry, put_in(next.recovery.timer, timer)}
      end
    end
  end

  def recover(_, _), do: :ignore

  def cancel(policy) do
    if policy.recovery, do: Process.cancel_timer(policy.recovery.timer)
    for {monitor, _} <- policy.owners, do: Process.demonitor(monitor, [:flush])
    # A caller confirming process death need not wait for a Registry partition's
    # asynchronous DOWN processing. unregister only removes this caller's keys.
    unregister({policy.scope.instance, policy.scope.service})
    if policy.backend, do: unregister({Gaoxy.Telemetry, policy.backend})
    :ok
  end

  defp unregister(key) do
    Registry.unregister(Gaoxy.Registry, key)
  rescue
    ArgumentError -> :ok
  catch
    :exit, _ -> :ok
  end

  defp register_key(policy, key, value) do
    result =
      try do
        case Registry.register(Gaoxy.Registry, key, value) do
          {:error, {:already_registered, pid}} when pid == self() ->
            # A previous partial reconciliation may have restored this key.
            # Re-register our own key to obtain its public owner PID again.
            Registry.unregister(Gaoxy.Registry, key)
            Registry.register(Gaoxy.Registry, key, value)

          result ->
            result
        end
      rescue
        ArgumentError -> {:error, :registry_unavailable}
      catch
        :exit, _ -> {:error, :registry_unavailable}
      end

    case result do
      {:ok, owner} ->
        owners =
          Enum.reduce(policy.owners, %{}, fn {monitor, pid}, acc ->
            if Process.alive?(pid) do
              Map.put(acc, monitor, pid)
            else
              Process.demonitor(monitor, [:flush])
              acc
            end
          end)

        owners =
          if owner in Map.values(owners),
            do: owners,
            else: Map.put(owners, Process.monitor(owner), owner)

        {:ok, %{policy | owners: owners}}

      {:error, _} ->
        {:error, policy}
    end
  end

  defp now, do: System.monotonic_time(:millisecond)
end
