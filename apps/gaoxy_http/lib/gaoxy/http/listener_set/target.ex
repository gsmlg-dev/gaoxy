defmodule Gaoxy.HTTP.ListenerSet.PreparedTarget do
  @moduledoc false
  defstruct [:endpoint, :discovery]
end

defmodule Gaoxy.HTTP.ListenerSet.Target do
  @moduledoc false
  @behaviour Gaoxy.HTTP.Endpoint
  alias Gaoxy.HTTP.ListenerSet.PreparedTarget

  def init(:planned), do: {:ok, :planned}
  def init(%PreparedTarget{} = target), do: {:ok, target}
  def init(_), do: {:error, :invalid_prepared_target}

  def call(exchange, %PreparedTarget{endpoint: {module, state}, discovery: discovery}),
    do: module.call(%{exchange | discovery: discovery}, state)

  def resources(:planned), do: []

  def resources(%PreparedTarget{endpoint: {module, state}}) do
    if function_exported?(module, :resources, 1), do: module.resources(state), else: []
  end

  def snapshot_bytes(%PreparedTarget{endpoint: {Gaoxy.HTTP.Generation, %{snapshot_bytes: bytes}}})
      when is_integer(bytes) and bytes >= 0,
      do: bytes

  def snapshot_bytes(_), do: 0

  def absolute_form_scheme?(scheme, %PreparedTarget{endpoint: {module, _}}) do
    function_exported?(module, :absolute_form_scheme?, 1) and module.absolute_form_scheme?(scheme)
  end
end
