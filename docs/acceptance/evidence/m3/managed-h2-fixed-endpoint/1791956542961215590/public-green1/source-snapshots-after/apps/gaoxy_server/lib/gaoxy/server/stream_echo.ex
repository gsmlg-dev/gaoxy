defmodule Gaoxy.Server.StreamEcho do
  @moduledoc "Allowlisted standalone byte-stream echo example."
  @behaviour Gaoxy.StreamHandler
  @impl true
  def init(_metadata, _options), do: {:ok, nil}
  @impl true
  def handle_data(bytes, state), do: {:send, bytes, state}
end
