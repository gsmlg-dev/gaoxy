defmodule Gaoxy.Server.DatagramEcho do
  @moduledoc "Allowlisted standalone complete-datagram echo example."
  @behaviour Gaoxy.DatagramHandler
  @impl true
  def handle_datagram(%{data: bytes}, _options), do: {:reply, bytes}
end
