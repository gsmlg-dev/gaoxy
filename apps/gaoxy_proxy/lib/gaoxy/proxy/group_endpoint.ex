defmodule Gaoxy.Proxy.GroupEndpoint do
  @moduledoc "Dedicated HTTP/1 proxy endpoint for an explicitly prepared immutable group."
  @behaviour Gaoxy.HTTP.Endpoint
  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Proxy.{HTTP, UpstreamGroups}
  defstruct [:group, :limits]

  @impl true
  def init(%__MODULE__{group: handle, limits: limits}), do: init(Map.put(limits, :group, handle))

  def init(%{group: handle} = options) do
    with true <- UpstreamGroups.valid_handle?(handle),
         {:ok, limits} <- HTTP.group_limits(Map.delete(options, :group)) do
      {:ok, %__MODULE__{group: handle, limits: limits}}
    else
      _ -> {:error, :invalid_group_endpoint_options}
    end
  end

  def init(_), do: {:error, :invalid_group_endpoint_options}

  @impl true
  def resources(config), do: [config.group]

  @impl true
  def call(exchange, config) do
    if Enum.any?(exchange.resource_pins, fn pin -> config.group in Map.get(pin, :handles, []) end) do
      HTTP.call(exchange, config)
    else
      with {:ok, pins} <- Resources.pin_many([config.group], self(), :request, exchange.deadline) do
        try do
          HTTP.call(%{exchange | resource_pins: pins ++ exchange.resource_pins}, config)
        after
          Resources.release(pins)
        end
      else
        {:error, _} -> HTTP.unavailable(exchange)
      end
    end
  end
end
