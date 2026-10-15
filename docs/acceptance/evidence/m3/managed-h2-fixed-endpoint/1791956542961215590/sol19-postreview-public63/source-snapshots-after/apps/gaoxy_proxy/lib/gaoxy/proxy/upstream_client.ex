defmodule Gaoxy.Proxy.UpstreamClient do
  @moduledoc "The bounded request, delivery and cleanup boundary used by the HTTP proxy."

  @callback host_supported?() :: boolean()
  @callback reservation_bytes(list(), non_neg_integer(), pos_integer()) :: non_neg_integer()
  @callback open(map()) :: {:ok, term(), term() | nil} | {:error, term()}
  @callback poll_headers(term()) :: {term(), term()}
  @callback event(term(), term()) :: {term(), term()}
  @callback subscribe(term()) :: :ok
  @callback write_body(term(), binary(), non_neg_integer()) :: :ok | {:error, term()}
  @callback finish_body(term(), list()) :: :ok | {:error, term()}
  @callback acknowledge(term(), reference()) :: :ok | {:ok, term()}
  @callback begin_cleanup(term(), boolean(), integer()) :: {:ok, term()}
  @callback cleanup(term(), boolean()) ::
              :ok
              | {:error, term()}
              | {:pending, term()}
              | {:ok, term()}
              | {:error, term(), term()}
  @optional_callbacks begin_cleanup: 3
  @callback completion(term()) :: term()
  @callback await_completion(term(), boolean()) :: :ok | {:error, term()}
end
