defmodule Gaoxy.HTTP.HTTP3 do
  @moduledoc "Explicit opt-in native HTTP/3 service over Gaoxy's public QUIC host."
  alias Gaoxy.HTTP.HTTP3.{Connection, Options}

  def start_link(options) do
    with {:ok, spec} <- service_spec(options), do: Gaoxy.start_link(services: [spec])
  end

  def child_spec(options) do
    %{
      id: {__MODULE__, Keyword.get(options, :id, :http3)},
      start: {__MODULE__, :start_link, [options]},
      restart: :transient
    }
  end

  def service_spec(options) do
    with {:ok, service} <- Options.normalize(options),
         do: Gaoxy.Config.service(Map.put(service, :handler, Connection))
  end
end
