defmodule Gaoxy.Lifecycle do
  @moduledoc false
  @cleanup_headroom 1_000

  def cleanup_headroom, do: @cleanup_headroom
  def now, do: System.monotonic_time(:millisecond)
  def deadline(timeout), do: now() + timeout
  def remaining(deadline), do: max(0, deadline - now())

  def call(server, request, deadline) do
    GenServer.call(server, request, remaining(deadline))
  catch
    :exit, {:timeout, _} -> {:error, {:deadline_exceeded, :cleanup_pending}}
    :exit, {:noproc, _} -> {:error, :not_running}
    :exit, {:normal, _} -> {:error, :not_running}
    :exit, reason -> {:error, {:operation_exit, reason}}
  end

  def protect(fun) do
    fun.()
  rescue
    error -> {:error, {:exception, error.__struct__}}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  def bounded(fun, timeout) do
    owner = self()
    token = make_ref()

    {pid, monitor} =
      :erlang.spawn_opt(fn -> send(owner, {token, protect(fun)}) end, [:link, :monitor])

    receive do
      {^token, result} ->
        Process.demonitor(monitor, [:flush])
        result

      {:DOWN, ^monitor, :process, ^pid, reason} ->
        {:error, {:operation_exit, reason}}
    after
      timeout ->
        Process.exit(pid, :kill)
        Process.demonitor(monitor, [:flush])
        {:error, :outcome_unknown}
    end
  end

  def terminate_resources(resources, deadline) do
    monitors = Enum.map(resources, &{&1, Process.monitor(&1)})
    Enum.each(resources, &Process.exit(&1, :kill))

    Enum.reduce(monitors, :ok, fn {pid, monitor}, result ->
      receive do
        {:DOWN, ^monitor, :process, ^pid, _} -> result
      after
        remaining(deadline) ->
          Process.demonitor(monitor, [:flush])
          {:error, {:cleanup_failed, :termination_unconfirmed}}
      end
    end)
  end

  # Snapshot linked descendants owned by this service. OTP children inherit the
  # service in $ancestors. Only the QUIC host's direct raw reader is included
  # without ancestors. Never follow arbitrary handler links, a
  # Registry owner, an application supervisor, or another service's links.
  # This does not inspect private backend state or send supervisor queries that
  # could block while the supervisor is terminating its own children.
  def resources(backend, service, raw_children \\ false) do
    owner_name =
      case Process.info(backend, :dictionary) do
        {:dictionary, dictionary} -> List.first(Keyword.get(dictionary, :"$ancestors", []))
        nil -> nil
      end

    resources =
      descendants(
        [backend],
        service,
        MapSet.new([service]),
        if(raw_children, do: backend, else: nil),
        owner_name
      )

    [backend | List.delete(resources, backend)]
  end

  defp descendants([], service, seen, _raw_root, _owner_name),
    do: seen |> MapSet.delete(service) |> MapSet.to_list()

  defp descendants([pid | rest], service, seen, raw_root, owner_name) do
    if MapSet.member?(seen, pid) do
      descendants(rest, service, seen, raw_root, owner_name)
    else
      links =
        case Process.info(pid, :links) do
          {:links, links} -> Enum.filter(links, &owned?(&1, service, pid == raw_root, owner_name))
          nil -> []
        end

      descendants(links ++ rest, service, MapSet.put(seen, pid), raw_root, owner_name)
    end
  end

  defp owned?(pid, service, raw_child, owner_name) when is_pid(pid) and pid != service do
    case Process.info(pid, :dictionary) do
      {:dictionary, dictionary} ->
        case Keyword.get(dictionary, :"$ancestors") do
          nil -> raw_child
          ancestors -> service in ancestors or (owner_name != nil and owner_name in ancestors)
        end

      nil ->
        false
    end
  end

  defp owned?(_, _, _, _), do: false

  def force(resources, gate) do
    protect(fn -> GenServer.call(gate, :force, 50) end)
    Enum.each(Enum.uniq(resources ++ [gate]), &Process.exit(&1, :kill))
    :ok
  end

  def drain(transport, backend, gate, deadline) do
    case transport do
      :udp ->
        Abyss.stop(backend, remaining(deadline))

      :quic ->
        Abyss.QUIC.stop(backend, remaining(deadline))

      _ ->
        with :ok <- ThousandIsland.suspend(backend),
             :ok <- await_leases(gate, deadline) do
          Supervisor.stop(backend, :normal, remaining(deadline))
        end
    end
  end

  defp await_leases(gate, deadline) do
    case call(gate, :status, deadline) do
      %{active: 0} ->
        :ok

      %{active: _} ->
        if remaining(deadline) == 0 do
          {:error, :deadline_exceeded}
        else
          receive do
          after
            min(5, remaining(deadline)) -> await_leases(gate, deadline)
          end
        end

      error ->
        error
    end
  end

  # Dispatch every barrier before awaiting any service. Each service owns its
  # cleanup; caller death or a public timeout cannot abandon it.
  def drain_services(services, deadline) do
    requests =
      for {id, pid, generation} <- services do
        monitor = Process.monitor(pid)
        request = :gen_server.send_request(pid, {:drain, generation, deadline})
        {id, pid, monitor, request}
      end

    results =
      for {id, pid, monitor, request} <- requests do
        result =
          case :gen_server.receive_response(request, remaining(deadline)) do
            {:reply, result} ->
              receive do
                {:DOWN, ^monitor, :process, ^pid, _} -> result
              after
                remaining(deadline) -> {:error, {:deadline_exceeded, :cleanup_pending}}
              end

            {:error, {:noproc, _}} ->
              {:error, :not_running}

            {:error, reason} ->
              {:error, {:cleanup_failed, reason}}

            :timeout ->
              {:error, {:deadline_exceeded, :cleanup_pending}}
          end

        Process.demonitor(monitor, [:flush])
        {id, result}
      end

    case Enum.reject(results, fn {_, result} -> result == :ok end) do
      [] -> :ok
      errors -> {:error, {:services, errors}}
    end
  end
end
