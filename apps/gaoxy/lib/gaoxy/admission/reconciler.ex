defmodule Gaoxy.Admission.Reconciler do
  @moduledoc false
  alias Gaoxy.{Lifecycle, ResourceBudget}

  # Only a live registered parent calls this after gate death and backend cleanup.
  # Pages and sequence are retained together; an ambiguous write retries identical
  # arguments, never a speculative subtraction or a new operation identity.
  def finish(budget, gate, guardians, deadline, native_terminal \\ true) do
    cond do
      Process.alive?(gate) ->
        {:error, :gate_alive}

      Lifecycle.remaining(deadline) == 0 ->
        {:error, :cleanup_unconfirmed}

      true ->
        ResourceBudget.set_registration_mode(
          budget.server,
          {:service, budget.service},
          :draining,
          1,
          budget_deadline(deadline)
        )

        result = page(budget.client, guardians, deadline, native_terminal, :start, nil)
        report(budget, result)
        result
    end
  end

  def retire_registration(budget, scope, sequence) do
    deadline = Lifecycle.deadline(50)

    with {:ok, _} <-
           ResourceBudget.set_registration_mode(
             budget.server,
             scope,
             :draining,
             sequence,
             deadline
           ),
         {:ok, _} <-
           ResourceBudget.retire_registration(
             budget.server,
             scope,
             %{terminal: :confirmed},
             sequence + 1,
             deadline
           ) do
      :ok
    end
  end

  defp page(client, guardians, deadline, native_terminal, cursor, sequence) do
    if Lifecycle.remaining(deadline) == 0 do
      {:error, :cleanup_unconfirmed}
    else
      with {:ok, page} <- ResourceBudget.allocations(client, cursor, deadline),
           {:ok, sequence} <-
             rows(
               client,
               page.allocations,
               guardians,
               deadline,
               native_terminal,
               sequence || page.next_operation
             ) do
        case page.cursor do
          :done ->
            write_deadline = budget_deadline(deadline)

            retry(
              fn ->
                ResourceBudget.retire(
                  client,
                  %{terminal: :confirmed, scope: :service},
                  sequence,
                  write_deadline
                )
              end,
              deadline
            )

          next ->
            page(client, guardians, deadline, native_terminal, next, sequence)
        end
      end
    end
  end

  defp rows(_, [], _, _, _, sequence), do: {:ok, sequence}

  defp rows(client, [row | rest], guardians, deadline, native_terminal, sequence) do
    confirmed =
      if row.kind == :guardian,
        do: Map.get(guardians, row.token) == :normal,
        else: native_terminal and confirm_terminal_pair(row.owner, deadline)

    if confirmed do
      proof = %{owner: row.owner, revision: row.revision, terminal: :confirmed}

      write_deadline = budget_deadline(deadline)

      with {:ok, _} <-
             retry(
               fn ->
                 ResourceBudget.release(
                   client,
                   row.token,
                   row.revision,
                   proof,
                   sequence,
                   write_deadline
                 )
               end,
               deadline
             ) do
        rows(client, rest, guardians, deadline, native_terminal, sequence + 1)
      end
    else
      {:error, :cleanup_unconfirmed}
    end
  end

  defp confirm_terminal_pair(pid, deadline) do
    # Native resources have already been closed. A live allocation owner or an
    # unavailable terminal pair remains charged. No DOWN-only refund occurs.
    if Process.alive?(pid) or pid == self() do
      false
    else
      monitor = Process.monitor(pid)
      Process.link(pid)

      down =
        receive do
          {:DOWN, ^monitor, :process, ^pid, _} -> true
        after
          Lifecycle.remaining(deadline) -> false
        end

      exited =
        receive do
          {:EXIT, ^pid, _} -> true
        after
          Lifecycle.remaining(deadline) -> false
        end

      Process.demonitor(monitor, [:flush])
      down and exited
    end
  end

  defp retry(fun, deadline) do
    case fun.() do
      {:error, reason} when reason in [:budget_timeout, :budget_unavailable] ->
        if Lifecycle.remaining(deadline) > 0,
          do: retry(fun, deadline),
          else: {:error, :cleanup_unconfirmed}

      result ->
        result
    end
  end

  defp budget_deadline(deadline), do: min(deadline, Lifecycle.deadline(50))

  defp report(budget, result) do
    Gaoxy.Telemetry.emit(:resource_budget_cleanup, %{count: 1}, %{instance: budget.instance}, %{
      result: result
    })
  end
end
