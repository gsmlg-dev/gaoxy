defmodule Gaoxy.Server.UpstreamSupervisor do
  @moduledoc false
  defdelegate start_link(context), to: Gaoxy.Proxy.Gateway.RuntimeSupervisor
end
