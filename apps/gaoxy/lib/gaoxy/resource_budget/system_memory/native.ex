defmodule Gaoxy.ResourceBudget.SystemMemory.Native do
  @moduledoc false
  @maximum 9_223_372_036_854_775_807
  @timeout 2_000
  @cleanup_timeout 1_000

  # OTP os_mon owns and supervises a reusable native helper. On macOS memsup
  # reports Mach HOST_BASIC_INFO.max_mem; on Windows it reports the TotPhys
  # value from GlobalMemoryStatusEx. system_total_memory excludes swap/free
  # memory on both. No executable is created for an individual capacity probe.
  def capacity(platform) when platform in [:darwin, :windows], do: probe()

  @doc false
  def probe(query \\ &:memsup.get_system_memory_data/0, timeout \\ @timeout)
      when is_function(query, 0) and is_integer(timeout) and timeout in 1..@timeout do
    reply = :erlang.alias([:explicit_unalias])
    caller = self()

    {worker, monitor} =
      spawn_monitor(fn -> run_probe(caller, reply, query, timeout) end)

    try do
      # The owner enforces the timeout and confirms query cleanup before sending
      # a result. It also monitors this caller, including abnormal termination
      # where an after block in this process cannot run.
      receive do
        {^reply, result} ->
          receive do
            {:DOWN, ^monitor, :process, ^worker, _} -> result
          end

        {:DOWN, ^monitor, :process, ^worker, _} ->
          {:error, :native_probe_failed}
      end
    after
      :erlang.unalias(reply)
      Process.demonitor(monitor, [:flush])
    end
  end

  defp run_probe(caller, reply, query, timeout) do
    Process.flag(:trap_exit, true)
    caller_monitor = Process.monitor(caller)
    owner = self()

    {worker, monitor} =
      :erlang.spawn_opt(
        fn ->
          result =
            try do
              physical(query.())
            rescue
              _ -> {:error, :native_probe_failed}
            catch
              _, _ -> {:error, :native_probe_failed}
            end

          send(owner, {:query_result, self(), result})
        end,
        [:link, :monitor]
      )

    {result, down?} =
      receive do
        {:query_result, ^worker, result} -> {result, false}
        {:DOWN, ^monitor, :process, ^worker, _} -> {{:error, :native_probe_failed}, true}
        {:DOWN, ^caller_monitor, :process, ^caller, _} -> {{:error, :caller_down}, false}
      after
        timeout -> {{:error, :timeout}, false}
      end

    result =
      case finish_worker(worker, monitor, down?) do
        :ok -> result
        {:error, _} = error -> error
      end

    # Caller-owned aliases are automatically revoked if that caller dies.
    # Query messages target only this short-lived owner, never the caller.
    send(reply, {reply, result})
  end

  defp finish_worker(_, _, true), do: :ok

  defp finish_worker(worker, monitor, false) do
    Process.exit(worker, :kill)

    receive do
      {:DOWN, ^monitor, :process, ^worker, _} -> :ok
    after
      @cleanup_timeout -> {:error, :native_cleanup_pending}
    end
  end

  defp physical(data) when is_list(data) do
    if Keyword.keyword?(data) and length(data) <= 64 do
      case Keyword.get_values(data, :system_total_memory) do
        [capacity] when is_integer(capacity) and capacity in 2..@maximum -> {:ok, capacity}
        _ -> {:error, :invalid_native_memory}
      end
    else
      {:error, :invalid_native_memory}
    end
  end

  defp physical(_), do: {:error, :invalid_native_memory}
end
