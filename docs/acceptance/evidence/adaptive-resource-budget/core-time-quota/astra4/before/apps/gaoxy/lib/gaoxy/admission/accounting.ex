defmodule Gaoxy.Admission.Accounting do
  @moduledoc false

  def categories(%{accounting: accounting}),
    do: Map.take(accounting, [:transport_bytes, :websocket_bytes])

  def categories(%{transport_bytes: transport, websocket_bytes: websocket}),
    do: %{transport_bytes: transport, websocket_bytes: websocket}

  def categories(%{bytes: bytes}), do: %{transport_bytes: bytes, websocket_bytes: 0}

  def replace(lease, input) do
    previous =
      Map.get(
        lease,
        :accounting,
        Map.merge(categories(lease), %{temporary_bytes: 0, memberships: %{}, pending_processes: 0})
      )

    input =
      cond do
        is_integer(input) and input >= 0 ->
          previous
          |> Map.put(:transport_bytes, input)
          |> Map.put(:retained_bytes, input + previous.websocket_bytes - previous.temporary_bytes)

        is_map(input) and Map.keys(input) -- [:transport_bytes, :websocket_bytes] == [] and
          Map.has_key?(input, :transport_bytes) and Map.has_key?(input, :websocket_bytes) ->
          previous
          |> Map.merge(input)
          |> Map.put(
            :retained_bytes,
            input.transport_bytes + input.websocket_bytes - previous.temporary_bytes
          )

        true ->
          input
      end

    with {:ok, accounting} <- Gaoxy.ResourceBudget.normalize_accounting(input) do
      replacement =
        Map.merge(lease, %{
          bytes: accounting.retained_bytes + accounting.temporary_bytes,
          accounting: accounting
        })

      replacement =
        if is_map(input) and
             (accounting.websocket_bytes > 0 or Map.has_key?(lease, :websocket_bytes)),
           do: Map.merge(replacement, Map.take(accounting, [:transport_bytes, :websocket_bytes])),
           else: replacement

      {:ok, replacement}
    else
      _ -> {:error, :byte_limit}
    end
  end

  def totals(leases, cleanups) do
    initial = %{
      transport_bytes: Enum.reduce(cleanups, 0, fn {_, cleanup}, sum -> sum + cleanup.bytes end),
      websocket_bytes: 0
    }

    Enum.reduce(leases, initial, fn {_, lease}, totals ->
      accounting = categories(lease)

      %{
        transport_bytes: totals.transport_bytes + accounting.transport_bytes,
        websocket_bytes: totals.websocket_bytes + accounting.websocket_bytes
      }
    end)
  end

  def validate(leases, cleanups, old, replacement, max_bytes) do
    totals = totals(leases, cleanups)
    old = categories(old)
    replacement = categories(replacement)
    transport = totals.transport_bytes - old.transport_bytes + replacement.transport_bytes

    if transport >= 0 and transport <= max_bytes,
      do: :ok,
      else: {:error, :byte_limit}
  end
end
