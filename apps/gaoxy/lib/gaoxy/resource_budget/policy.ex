defmodule Gaoxy.ResourceBudget.Policy do
  @moduledoc "Pure capacity calculations and projected memory admission boundaries."
  @maximum 9_223_372_036_854_775_807
  @fallback 268_435_456

  @doc "Returns a 50% soft budget and twice that threshold, or the finite fallback."
  def limits(%{capacity: capacity}), do: limits(capacity)

  def limits(capacity) when is_integer(capacity) and capacity in 2..@maximum do
    # Divide before multiplying: the hard threshold fits even a signed 64-bit
    # consumer, and an odd capacity never rounds above the detected ceiling.
    soft = div(capacity, 2)
    %{soft_limit: soft, hard_limit: 2 * soft}
  end

  def limits(_), do: %{soft_limit: @fallback, hard_limit: 2 * @fallback}

  @doc "Classifies accounted usage, including the exact soft and hard boundaries."
  def state(usage, soft, hard)
      when is_integer(usage) and usage >= 0 and is_integer(soft) and soft > 0 and
             is_integer(hard) and hard >= soft do
    cond do
      usage <= soft -> :normal
      usage <= hard -> :warning
      true -> :over_limit
    end
  end

  @doc "Checks new projected usage; valid releases remain possible above the threshold."
  def admit(current, delta, hard)
      when is_integer(current) and current >= 0 and is_integer(delta) and
             is_integer(hard) and hard in 1..@maximum do
    cond do
      delta < -current -> {:error, :invalid_usage}
      delta < 0 -> :ok
      current > hard or delta > hard - current -> {:error, :memory_hard_limit}
      true -> :ok
    end
  end

  def admit(_, _, _), do: {:error, :invalid_usage}
end
