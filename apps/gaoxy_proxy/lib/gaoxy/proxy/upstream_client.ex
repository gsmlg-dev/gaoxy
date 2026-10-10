defmodule Gaoxy.Proxy.UpstreamClient do
  @moduledoc "The bounded request, delivery and cleanup boundary used by the HTTP proxy."

  @callback open(map()) :: {:ok, term(), term() | nil} | {:error, term()}
  @callback poll_headers(term()) :: {term(), term()}
  @callback event(term(), term()) :: {term(), term()}
  @callback subscribe(term()) :: :ok
  @callback write_body(term(), binary(), non_neg_integer()) :: :ok | {:error, term()}
  @callback finish_body(term(), list()) :: :ok | {:error, term()}
  @callback acknowledge(term(), reference()) :: :ok
  @callback cleanup(term(), boolean()) :: :ok | {:error, term()}
end
