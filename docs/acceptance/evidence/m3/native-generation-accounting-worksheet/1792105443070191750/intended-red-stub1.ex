defmodule Gaoxy.Proxy.ManagedGenerationAccounting do
  @moduledoc false

  # TDD placeholder: no constructor/accounting behavior implemented.
  def worksheet(_, _), do: {:error, :invalid_generation_capture}
  def preflight_cons(_, _), do: {:error, :invalid_generation_capture}
  def preflight_append(_, _), do: {:error, :invalid_generation_capture}
  def finite_checked_reason(_), do: :generation_unavailable
end
