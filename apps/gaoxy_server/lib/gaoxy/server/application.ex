defmodule Gaoxy.Server.Application do
  @moduledoc false
  use Application
  @impl true
  def start(_, _) do
    case System.get_env("GAOXY_CONFIG") do
      nil ->
        Supervisor.start_link([], strategy: :one_for_one)

      path ->
        with {:ok, options} <- Gaoxy.Server.Config.load(path),
             {:ok, supervisor} <- Gaoxy.Server.Supervisor.start_link(options) do
          %{phase: :ready, listeners: listeners} = Gaoxy.Proxy.Gateway.info(supervisor)

          ready =
            for info <- listeners do
              local =
                case info.local do
                  {:ok, address} -> address
                  address -> address
                end

              {ip, port} = local

              %{
                id: info.id,
                address: to_string(:inet.ntoa(ip)),
                port: port,
                transport: Atom.to_string(info.transport)
              }
            end

          json = JSON.encode!(%{version: 1, services: ready})
          if output = System.get_env("GAOXY_READY_FILE"), do: File.write!(output, json)
          IO.puts("GAOXY_READY " <> json)
          {:ok, supervisor}
        end
    end
  end

  @impl true
  def prep_stop(state) do
    if pid = Process.whereis(Gaoxy.Server.Supervisor), do: Gaoxy.Proxy.Gateway.stop(pid, 5_000)
    state
  end
end
