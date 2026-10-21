defmodule Gaoxy.Server.RouteResources do
  @moduledoc false
  def activate(store, expected, router, deadline),
    do: Gaoxy.Proxy.Gateway.Coordinator.activate(__MODULE__, store, expected, router, deadline)
end
