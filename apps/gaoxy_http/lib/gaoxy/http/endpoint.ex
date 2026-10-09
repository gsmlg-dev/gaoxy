defmodule Gaoxy.HTTP.Endpoint do
  @moduledoc "Application dispatch for one admitted HTTP request."
  @callback init(term()) :: {:ok, term()} | {:error, term()}
  @callback call(Gaoxy.HTTP.Exchange.t(), term()) ::
              {:ok, Gaoxy.HTTP.Exchange.t()} | {:error, term(), Gaoxy.HTTP.Exchange.t()}
end
