defmodule Gaoxy.WebSocketAccountingTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.Admission.Accounting

  test "ordinary scalar leases retain their exact shape" do
    lease = %{bytes: 12, owner: :unchanged}
    assert {:ok, %{bytes: 20, owner: :unchanged}} = Accounting.replace(lease, 20)
    assert %{transport_bytes: 12, websocket_bytes: 0} = Accounting.categories(lease)
  end

  test "classified replacements observe unlimited websocket retention" do
    lease = %{bytes: 12, owner: :unchanged}
    accounting = %{transport_bytes: 8, websocket_bytes: 1_000_000}
    assert {:ok, classified} = Accounting.replace(lease, accounting)
    assert classified.bytes == 1_000_008
    assert {:ok, updated} = Accounting.replace(classified, 4)
    assert Accounting.categories(updated) == %{transport_bytes: 4, websocket_bytes: 1_000_000}
    assert updated.owner == :unchanged
  end

  test "transport replacement validates the shared finite capacity including cleanups" do
    leases = %{one: %{bytes: 20}, two: %{bytes: 5, transport_bytes: 5, websocket_bytes: 0}}
    cleanups = %{guardian: %{bytes: 10}}
    assert %{transport_bytes: 35, websocket_bytes: 0} = Accounting.totals(leases, cleanups)
    old = leases.two

    assert {:ok, retained} =
             Accounting.replace(old, %{transport_bytes: 70, websocket_bytes: 2_000_000})

    assert :ok = Accounting.validate(leases, cleanups, old, retained, 100)
    assert {:ok, excess} = Accounting.replace(retained, 71)
    assert {:error, :byte_limit} = Accounting.validate(leases, cleanups, old, excess, 100)
  end

  test "invalid and partially classified retention cannot enter the ledger" do
    for value <- [
          -1,
          :infinity,
          %{transport_bytes: -1, websocket_bytes: 0},
          %{transport_bytes: 0, websocket_bytes: -1},
          %{transport_bytes: 1},
          %{transport_bytes: 1, websocket_bytes: 1.0}
        ] do
      assert {:error, :byte_limit} = Accounting.replace(%{bytes: 0}, value)
    end
  end
end
