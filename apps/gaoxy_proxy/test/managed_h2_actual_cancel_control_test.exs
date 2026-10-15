defmodule Gaoxy.Proxy.ManagedH2ActualCancelControlTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.{ManagedH2GroupAccounting, UpstreamTransports}

  test "the actual public cancellation message is accounted with its original holder and operation" do
    operation = make_ref()
    assert :ok = UpstreamTransports.cancel(self(), operation)
    assert_receive {:cancel_pins, holder, ^operation} = original
    assert holder === self()
    assert :ok = ManagedH2GroupAccounting.validate({:control, :owner}, original)
  end

  test "expanded or incorrect actual cancellation shells remain refused" do
    operation = make_ref()

    for original <- [
          {:cancel_pins, self(), operation, :expanded},
          {:cancel_pins, :not_pid, operation},
          {:cancel_pins, self(), :not_ref}
        ] do
      assert {:error, :invalid_group_accounting} =
               ManagedH2GroupAccounting.validate({:control, :owner}, original)
    end
  end
end
