defmodule Gaoxy.Test.ExUnit do
  @moduledoc false

  def register(handle) do
    ExUnit.Callbacks.on_exit({__MODULE__, handle.id}, fn ->
      report =
        Gaoxy.Test.Instance.call(handle, {:close, handle.timeout, true}, handle.timeout + 1_000)

      Gaoxy.Test.assert_report!(report)
    end)
  end
end
