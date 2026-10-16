defmodule Gaoxy.HTTP.Generation.Accounting do
  @moduledoc "Optional finite accounting contract for checked request-generation capture."

  @type reason :: atom()
  @callback reservation(pos_integer(), tuple()) ::
              {:ok,
               {:native_generation_capture_v1, pos_integer(), 65_536, 65_536, non_neg_integer()}}
              | {:error, reason()}
  @callback validate_manifest(list()) :: :ok | {:error, reason()}
  @callback correlate(map(), tuple(), pid()) :: :ok | {:error, reason()}
  @callback preflight_cons(map(), list()) ::
              {:ok, %{count: non_neg_integer(), bytes: non_neg_integer()}} | {:error, reason()}
  @callback preflight_append(list(), list()) ::
              {:ok, %{count: non_neg_integer(), bytes: non_neg_integer()}} | {:error, reason()}
  @callback finite_checked_reason(term()) :: reason()
  @callback release(map(), integer()) :: :ok | {:error, reason()}
end
