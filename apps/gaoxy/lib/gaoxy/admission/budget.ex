defmodule Gaoxy.Admission.Budget do
  @moduledoc false
  alias Gaoxy.{Lifecycle, ResourceBudget}

  def register(nil), do: {:ok, nil}

  def register(context) do
    with {:ok, client} <-
           ResourceBudget.register_gate(
             context.server,
             context.service,
             self(),
             Lifecycle.deadline(50)
           ) do
      {:ok, %{client: client, sequence: 1, pending: nil}}
    end
  end

  def deadline(:infinity), do: Lifecycle.deadline(50)
  def deadline(nil), do: Lifecycle.deadline(50)
  def deadline(value) when is_integer(value), do: min(value, Lifecycle.deadline(50))
  def deadline(_), do: Lifecycle.now() - 1

  # The commit callback requires a successful canonical receipt. Rejection records
  # a definite failure, never a transient pending result. Both callbacks survive
  # ambiguous calls with their exact sequence/arguments through reconciliation.
  # No five-second inspection API is used by Admission.
  def run(state, name, arguments, limit, commit, reject \\ fn state, _ -> state end)

  def run(%{budget: nil} = state, _, _, _, commit, _),
    do: {:ok, commit.(state, nil, false)}

  def run(%{budget: %{pending: pending}} = state, _, _, _, _, _) when not is_nil(pending),
    do: {:error, :budget_pending, state}

  def run(state, name, arguments, limit, commit, reject) do
    limit = deadline(limit)

    if Lifecycle.remaining(limit) == 0 do
      {:error, :deadline_exceeded, reject.(state, :deadline_exceeded)}
    else
      operation = %{
        name: name,
        arguments: arguments,
        deadline: limit,
        sequence: state.budget.sequence,
        commit: commit,
        reject: reject
      }

      finish(state, operation, invoke(state.budget.client, operation), false)
    end
  end

  def reconcile(%{budget: %{pending: operation}} = state) when not is_nil(operation),
    do: finish(state, operation, invoke(state.budget.client, operation), true)

  def reconcile(state), do: {:ok, state}

  defp invoke(client, operation),
    do:
      apply(
        ResourceBudget,
        operation.name,
        [client | operation.arguments] ++ [operation.sequence, operation.deadline]
      )

  defp finish(state, operation, {:error, reason}, _)
       when reason in [:budget_timeout, :budget_unavailable] do
    Process.send_after(self(), :budget_reconcile, 10)
    {:error, reason, put_in(state.budget.pending, operation)}
  end

  defp finish(state, operation, result, late) do
    state = %{state | budget: %{state.budget | sequence: operation.sequence + 1, pending: nil}}
    if late, do: send(self(), :budget_retry_terminals)

    case result do
      {:ok, receipt} -> {:ok, operation.commit.(state, receipt, late)}
      {:error, reason} -> {:error, reason, operation.reject.(state, reason)}
    end
  end

  def receipt(lease, nil), do: lease
  def receipt(lease, receipt), do: Map.put(lease, :budget_receipt, receipt)
  def owner(lease), do: Map.get(lease, :budget_owner, lease.pid)

  def proof(lease),
    do: %{owner: owner(lease), revision: lease.budget_receipt.revision, terminal: :confirmed}

  def arguments(lease, accounting),
    do: [lease.budget_receipt.token, lease.budget_receipt.revision, accounting]

  def release(state, lease, commit) do
    args = if state.budget, do: arguments(lease, proof(lease)), else: []
    run(state, :release, args, nil, commit)
  end
end
