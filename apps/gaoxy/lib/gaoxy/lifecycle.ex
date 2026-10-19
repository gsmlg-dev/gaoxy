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
        with :ok <- Hell.suspend(backend),
             :ok <- await_leases(gate, deadline) do
          Supervisor.stop(backend, :normal, remaining(deadline))
        end
    end
  end

  defp await_leases(gate, deadline) do
    case call(gate, :status, deadline) do
      %{active: 0, cleanup_pending: 0} ->
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
  def drain_services(services, deadline), do: drain_all(services, %{}, deadline)

  def drain_all(services, participants, deadline) do
    services =
      Map.new(services, fn {id, pid, generation} ->
        monitor = Process.monitor(pid)
        request = :gen_server.send_request(pid, {:drain, generation, deadline})

        {id,
         %{pid: pid, monitor: monitor, request: request, reply: nil, down: false, outcome: nil}}
      end)

    participants =
      Map.new(participants, fn {registration, participant} ->
        operation = make_ref()
        monitor = Process.monitor(participant.pid)

        send(
          participant.pid,
          {:gaoxy_lifecycle_drain, registration, operation, self(), deadline}
        )

        {registration,
         Map.merge(participant, %{monitor: monitor, operation: operation, down: false})}
      end)

    {services, participants} = collect(services, participants, deadline)

    Enum.each(services, fn {_, service} ->
      Process.demonitor(service.monitor, [:flush])
      # Abandon any unanswered request alias after the original deadline.
      if service.reply == nil, do: :gen_server.receive_response(service.request, 0)
    end)

    Enum.each(participants, fn {_, participant} ->
      Process.demonitor(participant.monitor, [:flush])
    end)

    result = shutdown_result(services, participants)

    if result == :ok && map_size(participants) > 0 && remaining(deadline) == 0,
      do: pending_result(),
      else: result
  end

  defp collect(services, participants, deadline) do
    cond do
      Enum.all?(services, fn {_, entry} -> entry.outcome != nil end) &&
          Enum.all?(participants, fn {_, entry} -> entry.outcome != nil end) ->
        {services, participants}

      remaining(deadline) == 0 ->
        expire(services, participants)

      true ->
        receive do
          message ->
            {services, participants} = collect_message(message, services, participants)
            collect(services, participants, deadline)
        after
          remaining(deadline) -> expire(services, participants)
        end
    end
  end

  defp collect_message(
         {:gaoxy_lifecycle_result, registration, operation, pid, result},
         services,
         participants
       ) do
    participants =
      case participants do
        %{^registration => %{pid: ^pid, operation: ^operation, outcome: nil} = participant} ->
          Map.put(participants, registration, %{participant | outcome: participant_result(result)})

        _ ->
          participants
      end

    {services, participants}
  end

  defp collect_message({:DOWN, monitor, :process, pid, _} = message, services, participants) do
    participants =
      Map.new(participants, fn
        {registration, %{monitor: ^monitor, pid: ^pid} = participant} ->
          # DOWN is provisional: the private-capability receipt may follow it.
          {registration, %{participant | down: true}}

        entry ->
          entry
      end)

    services =
      Map.new(services, fn
        {id, %{monitor: ^monitor, pid: ^pid} = service} ->
          {id, settle_service(%{service | down: true})}

        entry ->
          entry
      end)

    {service_response(message, services), participants}
  end

  defp collect_message(message, services, participants),
    do: {service_response(message, services), participants}

  defp service_response(message, services) do
    Map.new(services, fn
      {id, %{reply: nil, outcome: nil} = service} ->
        service =
          case :gen_server.check_response(message, service.request) do
            {:reply, result} -> settle_service(%{service | reply: {:received, result}})
            {:error, {:noproc, _}} -> %{service | outcome: {:error, :not_running}}
            {:error, reason} -> %{service | outcome: {:error, {:cleanup_failed, reason}}}
            :no_reply -> service
          end

        {id, service}

      entry ->
        entry
    end)
  end

  defp settle_service(%{reply: {:received, result}, down: true} = service),
    do: %{service | outcome: result}

  defp settle_service(service), do: service

  defp participant_result(:ok), do: :ok

  defp participant_result({:error, reason}) do
    if :erlang.external_size(reason) <= 1_024 do
      # Copy small terms so sub-binary backing cannot retain an oversized payload.
      {:error, reason |> :erlang.term_to_binary() |> :erlang.binary_to_term()}
    else
      {:error, :cleanup_unconfirmed}
    end
  end

  defp participant_result(_), do: {:error, :cleanup_unconfirmed}

  defp expire(services, participants) do
    services =
      Map.new(services, fn {id, service} ->
        {id, %{service | outcome: service.outcome || pending_result()}}
      end)

    participants =
      Map.new(participants, fn {registration, participant} ->
        result = if participant.down, do: {:error, :cleanup_unconfirmed}, else: pending_result()
        {registration, %{participant | outcome: participant.outcome || result}}
      end)

    {services, participants}
  end

  defp shutdown_result(services, participants) do
    service_errors = errors(services)
    resource_errors = errors(participants)

    cond do
      map_size(participants) == 0 ->
        if service_errors == [], do: :ok, else: {:error, {:services, service_errors}}

      Enum.any?(service_errors ++ resource_errors, fn {_, error} -> error == pending_result() end) ->
        pending_result()

      service_errors == [] && resource_errors == [] ->
        :ok

      true ->
        {:error, {:shutdown, service_errors, resource_errors}}
    end
  end

  defp errors(entries),
    do: for({id, %{outcome: result}} <- entries, result != :ok, do: {id, result})

  defp pending_result, do: {:error, {:deadline_exceeded, :cleanup_pending}}
end
