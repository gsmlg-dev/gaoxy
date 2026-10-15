defmodule Gaoxy.HTTP.Endpoint do
  @moduledoc "Application dispatch for one admitted HTTP request."
  @callback init(term()) :: {:ok, term()} | {:error, term()}
  @callback call(Gaoxy.HTTP.Exchange.t(), term()) ::
              {:ok, Gaoxy.HTTP.Exchange.t()} | {:error, term(), Gaoxy.HTTP.Exchange.t()}
  @callback absolute_form_scheme?(atom()) :: boolean()
  @callback resources(term()) :: list()
  @callback generation_validate(term()) :: :ok | {:error, atom()}
  @optional_callbacks absolute_form_scheme?: 1, resources: 1, generation_validate: 1
end
