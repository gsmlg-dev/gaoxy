defmodule Gaoxy.Test.Handle do
  @moduledoc "An opaque identity for one fixture. Obtain handles with `Gaoxy.Test.open/1`."
  @enforce_keys [:pid, :id, :timeout]
  defstruct [:pid, :id, :timeout]
  @opaque t :: %__MODULE__{pid: pid(), id: reference(), timeout: pos_integer()}
end
