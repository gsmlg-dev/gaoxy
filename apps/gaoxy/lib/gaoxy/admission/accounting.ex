defmodule Gaoxy.Admission.Accounting do
  @moduledoc false

  def categories(%{transport_bytes: transport, websocket_bytes: websocket}),
    do: %{transport_bytes: transport, websocket_bytes: websocket}

  def categories(%{bytes: bytes}), do: %{transport_bytes: bytes, websocket_bytes: 0}

  def replace(lease, %{transport_bytes: transport, websocket_bytes: websocket})
      when is_integer(transport) and transport >= 0 and is_integer(websocket) and websocket >= 0 do
    {:ok,
     Map.merge(lease, %{
       bytes: transport + websocket,
       transport_bytes: transport,
       websocket_bytes: websocket
     })}
  end

  # A scalar always means transport. It cannot erase an existing WS retention
  # owner when a transport queue returns or reserves credit.
  def replace(%{websocket_bytes: websocket} = lease, transport)
      when is_integer(transport) and transport >= 0,
      do: replace(lease, %{transport_bytes: transport, websocket_bytes: websocket})

  def replace(lease, bytes) when is_integer(bytes) and bytes >= 0,
    do: {:ok, %{lease | bytes: bytes}}

  def replace(_, _), do: {:error, :byte_limit}

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
