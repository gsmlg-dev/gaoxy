defmodule Gaoxy.HTTP.PlugEndpoint do
  @behaviour Gaoxy.HTTP.Endpoint
  alias Gaoxy.HTTP.Exchange

  def init({module, options}) when is_atom(module) do
    endpoint = original_endpoint(module, options)

    if Code.ensure_loaded?(endpoint) and function_exported?(endpoint, :__sockets__, 0) and
         function_exported?(endpoint, :config, 1) and
         apply(Phoenix.Endpoint, :server?, [endpoint.config(:otp_app), endpoint]) do
      {:error, :duplicate_endpoint_listener}
    else
      init({module, options, :endpoint_managed})
    end
  end

  def init({module, options, :endpoint_managed}) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :init, 1) and
         function_exported?(module, :call, 2) do
      {:ok, {module, module.init(options)}}
    else
      {:error, :invalid_plug}
    end
  end

  def init(_), do: {:error, :invalid_plug}

  defp original_endpoint(Gaoxy.PhoenixWebSocket, {endpoint, _}) when is_atom(endpoint),
    do: endpoint

  defp original_endpoint(Gaoxy.PhoenixWebSocket, {{module, options}, _}),
    do: original_endpoint(module, options)

  defp original_endpoint(Phoenix.Endpoint.SyncCodeReloadPlug, {endpoint, _}), do: endpoint
  defp original_endpoint(module, _), do: module

  def call(exchange, {module, options}) do
    conn = Exchange.plug_conn(exchange)

    try do
      conn = module.call(conn, options)
      conn = if conn.state == :set, do: Plug.Conn.send_resp(conn), else: conn
      exchange = elem(conn.adapter, 1)
      flush_sent()

      case conn.state do
        :upgraded -> {:ok, Gaoxy.HTTP.WebSocket.response_headers(exchange, conn.resp_headers)}
        :unset -> {:error, :response_not_sent, exchange}
        _ -> {:ok, exchange}
      end
    rescue
      error ->
        exchange =
          if flush_sent() do
            %{exchange | response: :sent, close: true}
          else
            case Gaoxy.HTTP.Response.send_resp(
                   %{exchange | close: true},
                   Plug.Exception.status(error),
                   [],
                   ""
                 ) do
              {:ok, next} -> next
              _ -> %{exchange | response: :sent, close: true}
            end
          end

        {:error, {:plug_exception, error}, exchange}
    end
  end

  defp flush_sent do
    receive do
      {:plug_conn, :sent} ->
        flush_sent()
        true
    after
      0 -> false
    end
  end
end
