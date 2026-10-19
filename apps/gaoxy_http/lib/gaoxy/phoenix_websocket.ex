defmodule Gaoxy.PhoenixWebSocket do
  @moduledoc """
  Presents validated extended WebSocket CONNECT requests to Phoenix socket routes.

  Mount with `{Endpoint, ["/socket/websocket", "/live/websocket"]}`. Paths are
  exact and opt in individually. The native request and HTTP version are kept
  in the adapter; only the method visible during the Endpoint call becomes GET.
  """
  @behaviour Plug

  def init({endpoint, paths}) when is_atom(endpoint), do: init({{endpoint, []}, paths})

  # The adapter supplies its existing SyncCodeReloadPlug composition here.
  def init({{module, options}, paths}) when is_atom(module) and is_list(paths) do
    valid_paths =
      Enum.all?(paths, fn
        "/" <> _ = path ->
          not String.contains?(path, ["*", "?", "#", "\\"]) and
            Enum.all?(:binary.bin_to_list(path), &(&1 in 33..126))

        _ ->
          false
      end)

    if valid_paths and Enum.uniq(paths) == paths and Code.ensure_loaded?(module) and
         function_exported?(module, :init, 1) and function_exported?(module, :call, 2) do
      {module, module.init(options), paths}
    else
      raise ArgumentError, "invalid Phoenix WebSocket endpoint or exact paths"
    end
  end

  def init(_), do: raise(ArgumentError, "invalid Phoenix WebSocket endpoint or exact paths")

  def call(conn, {module, options, paths}) do
    compatible = conn.request_path in paths and native_websocket?(conn)
    method = conn.method
    result = module.call(if(compatible, do: %{conn | method: "GET"}, else: conn), options)
    if compatible, do: %{result | method: method}, else: result
  end

  defp native_websocket?(%{adapter: {Gaoxy.PlugAdapter, exchange}}),
    do: Gaoxy.PlugAdapter.websocket_request?(exchange)

  defp native_websocket?(_), do: false
end
