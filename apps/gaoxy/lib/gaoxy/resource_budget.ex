defmodule Gaoxy.ResourceBudget do
  @moduledoc """
  Shared VM budget ownership, independent of listeners and protocol runtimes.

  Operations use positive gate-local sequences and absolute monotonic-millisecond
  deadlines. A timeout is ambiguous; reconcile with the same operation identity.
  Never allocate on an unconfirmed reservation. Token revisions fence stale writes.
  Mutation/registration waits are bounded by the supplied deadline (at most five
  seconds). An already expired deadline permits a 50ms receipt reconciliation
  window; it never permits a fresh mutation.

  Instance policy is `%{soft_limit: nil, hard_limit: nil, provenance: %{}}` for
  adaptive defaults, or two positive ordered explicit limits. Service policy has
  optional `max_active`/`max_bytes` legacy caps and positive `max_connections`,
  `max_requests`, `max_streams` quotas (omitted quotas use a finite safety ceiling).
  Accounting uses orthogonal retained/temporary and transport/WebSocket byte sums,
  logical quota memberships and pending process credits. Both byte sums must agree.
  Membership identities are service-scoped; connection-local IDs can be pairs.

  `allocations/2` returns up to 64 canonical rows plus an integer cursor or `:done`,
  the gate's `watermark`, and `next_operation`. After confirming gate death, one
  live registered service/instance reconciler reads that sequence and serializes
  cleanup operations from it. Retain the sequence across pages and ambiguous calls;
  DOWN alone is not a terminal receipt. Release proof binds `owner`, `revision`,
  and `terminal: :confirmed`; the reconciler must first establish the real terminal
  boundary (including normal guardian completion or worker DOWN/EXIT pairs).

  `set_mode/4` accepts a gate mode or `{:service | :instance, mode}`. Drain is
  irreversible. `retire/4` takes confirmed proof with optional `scope: :gate |
  :service | :instance` and retires only empty final child scopes. Empty instances
  and services failing before gate creation use the registration lifecycle APIs,
  with a separate positive operation sequence for each registration. Confirmed
  retirement prunes policies, indices, counters and monitoring. Up to 64 retired
  scope identities retain at most 64 receipts each: matching retry returns the
  original receipt; other mutations fail, and eviction never reopens a handle.
  """

  def server, do: Gaoxy.ResourceBudget.Supervisor.name(Gaoxy.ResourceBudget.Authority, :gaoxy)

  def set_registration_mode(server, scope, mode, operation, deadline),
    do: registration_mutation(server, scope, operation, deadline, {:mode, mode})

  def retire_registration(server, scope, proof, operation, deadline),
    do: registration_mutation(server, scope, operation, deadline, {:retire, proof})

  def register_instance(server, pid, policy, deadline),
    do: call(server, {:register_instance, pid, policy, deadline}, deadline)

  def register_service(server, instance, scope, policy, deadline),
    do: call(server, {:register_service, instance, scope, policy, deadline}, deadline)

  def register_gate(server, service, pid, deadline),
    do: call(server, {:register_gate, service, pid, deadline}, deadline)

  def reserve(client, owner, kind, accounting, operation, deadline),
    do: mutation(client, operation, deadline, {:reserve, owner, kind, accounting})

  def replace(client, token, revision, accounting, operation, deadline),
    do: mutation(client, operation, deadline, {:replace, token, revision, accounting})

  def transfer(client, token, revision, owner, operation, deadline),
    do: mutation(client, operation, deadline, {:transfer, token, revision, owner})

  def release(client, token, revision, receipt, operation, deadline),
    do: mutation(client, operation, deadline, {:release, token, revision, receipt})

  def set_mode(client, mode, operation, deadline),
    do: mutation(client, operation, deadline, {:set_mode, mode})

  def retire(client, receipt, operation, deadline),
    do: mutation(client, operation, deadline, {:retire, receipt})

  def allocations(client, cursor \\ :start),
    do: call(client.server, {:allocations, client, cursor})

  def operation_status(client, operation),
    do: call(client.server, {:operation_status, client, operation})

  def snapshot(server, instance), do: call(server, {:snapshot, instance})

  def refresh(server) do
    with {:ok, sampler} <- call(server, :sampler),
         do: Gaoxy.ResourceBudget.Sampler.refresh(sampler)
  end

  # Hash outside the state owners: receipts retain fixed-size fingerprints,
  # including rejected inputs, instead of retaining arbitrary caller arguments.
  defp mutation(client, operation, deadline, action),
    do:
      call(
        client.server,
        {:mutate, client, operation, deadline, action, fingerprint(action)},
        deadline
      )

  defp registration_mutation(server, scope, operation, deadline, action),
    do:
      call(
        server,
        {:registration_mutation, scope, operation, deadline, action, fingerprint(action)},
        deadline
      )

  defp fingerprint(action), do: :crypto.hash(:sha256, :erlang.term_to_binary(action))

  defp call(server, request, deadline \\ nil) do
    timeout =
      cond do
        is_nil(deadline) -> 5000
        not is_integer(deadline) -> 50
        deadline <= System.monotonic_time(:millisecond) -> 50
        true -> max(1, min(5000, deadline - System.monotonic_time(:millisecond)))
      end

    GenServer.call(server, request, timeout)
  catch
    :exit, {:timeout, _} -> {:error, :budget_timeout}
    :exit, _ -> {:error, :budget_unavailable}
  end

  @doc false
  def normalize_accounting(bytes) when is_integer(bytes) and bytes >= 0,
    do:
      normalize_accounting(%{
        retained_bytes: bytes,
        temporary_bytes: 0,
        transport_bytes: bytes,
        websocket_bytes: 0
      })

  def normalize_accounting(input) when is_map(input) do
    defaults = %{
      retained_bytes: 0,
      temporary_bytes: 0,
      transport_bytes: 0,
      websocket_bytes: 0,
      memberships: %{},
      pending_processes: 0
    }

    row = Map.merge(defaults, input)

    nums =
      Map.take(row, [
        :retained_bytes,
        :temporary_bytes,
        :transport_bytes,
        :websocket_bytes,
        :pending_processes
      ])

    valid_ids =
      is_map(row.memberships) and map_size(row.memberships) <= 4 and
        Enum.all?(row.memberships, fn {k, id} ->
          k in [:connection, :request, :h2_stream, :h3_stream] and valid_id?(id)
        end)

    if Map.keys(input) -- Map.keys(defaults) == [] and valid_ids and
         Enum.all?(nums, fn {_, n} ->
           is_integer(n) and n >= 0 and n <= 9_223_372_036_854_775_807
         end) and
         row.retained_bytes + row.temporary_bytes == row.transport_bytes + row.websocket_bytes,
       do: {:ok, row},
       else: {:error, :invalid_accounting}
  end

  def normalize_accounting(_), do: {:error, :invalid_accounting}
  defp valid_id?({connection, local}), do: scalar_id?(connection) and scalar_id?(local)
  defp valid_id?(id), do: scalar_id?(id)

  defp scalar_id?(id),
    do:
      not is_nil(id) and
        (is_reference(id) or is_integer(id) or is_atom(id) or
           (is_binary(id) and byte_size(id) in 1..128))
end
