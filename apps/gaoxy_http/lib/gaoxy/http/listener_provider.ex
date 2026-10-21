defmodule Gaoxy.HTTP.ListenerProvider do
  @moduledoc """
  Versioned listener materialization contract. Providers normalize data without
  I/O and build one service without binding it. H3 is resolved only on explicit use.
  """
  @callback version() :: 1
  @callback normalize(atom(), keyword()) :: {:ok, keyword()} | {:error, term()}
  @callback capabilities(atom()) :: map()
  @callback materialize(atom(), keyword(), term()) :: {:ok, map()} | {:error, term()}

  @doc false
  def resolve(role) when role in [:http, :https], do: check(Gaoxy.HTTP.ListenerProvider.HTTP)

  def resolve(:http3) do
    # A fixed module identifier is intentional: HTTP never depends on the H3 app.
    module = Gaoxy.HTTP.HTTP3.ListenerProvider

    if Code.ensure_loaded?(module),
      do: check(module),
      else: {:error, {:missing_optional_dependency, :gaoxy_http3}}
  end

  defp check(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :version, 0) and
         module.version() == 1 and function_exported?(module, :normalize, 2) and
         function_exported?(module, :capabilities, 1) and
         function_exported?(module, :materialize, 3),
       do: {:ok, module},
       else: {:error, :invalid_listener_provider}
  end
end
