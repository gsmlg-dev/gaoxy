defmodule GaoxyGroupGateCompileProbe do
  def activation, do: {:error, :accounting_not_ready}
end

defmodule GaoxyGroupGateConsumerCompileProbe do
  def run do
    case apply(GaoxyGroupGateCompileProbe, :activation, []) do
      :ok -> :future_open
      {:error, :accounting_not_ready} -> :denied
    end
  end
end
