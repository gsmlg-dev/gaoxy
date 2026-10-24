defmodule Gaoxy.HTTP.WebSocket.Stream do
  @moduledoc false
  alias Gaoxy.HTTP.{Exchange, WebSocket}
  alias Gaoxy.Lifecycle

  # This function remains on the admitted request worker. The connection owner
  # alone reads the wire, with one nonblocking input credit registered here.
  def run(exchange, service_limits) do
    case WebSocket.start(exchange, service_limits) do
      {:continue, ws} -> demand(ws)
      {:close, ws} -> finish(ws)
    end
  end

  defp demand(ws) do
    credit = min(16_384, ws.exchange.limits.max_read_chunk)
    ref = make_ref()

    with {:ok, ws} <- WebSocket.reserve_input(ws, credit),
         :ok <- ws.exchange.transport.websocket_demand(ws.exchange, credit, ref) do
      loop(ws, ref, credit)
    else
      {:error, reason} -> finish(%{ws | reason: {:error, reason}})
    end
  end

  defp loop(ws, ref, credit) do
    {owner, token} = identity(ws.exchange.transport_state)
    gate = ws.exchange.gate
    lease = ws.exchange.lease

    receive do
      {:gaoxy_websocket_data, ^token, ^ref, bytes, ended}
      when is_binary(bytes) and is_boolean(ended) and byte_size(bytes) <= credit ->
        result = WebSocket.data(bytes, ws)

        case {result, ended} do
          {{:continue, next}, false} ->
            demand(next)

          {{_, next}, _} ->
            case next.exchange.transport.websocket_demand(next.exchange, 0, ref) do
              :ok -> finish(%{next | reason: next.reason || :remote})
              {:error, reason} -> finish(%{next | reason: {:error, reason}})
            end
        end

      {:gaoxy_websocket_data, _, _, _, _} ->
        loop(ws, ref, credit)

      {:gaoxy_drain, ^gate, ^lease, deadline} ->
        continue(WebSocket.drain(ws, deadline), ref, credit)

      {:DOWN, _, :process, pid, reason} when pid == owner or pid == gate ->
        finish(%{ws | reason: {:error, {:owner_down, reason}}})

      message ->
        continue(WebSocket.info(message, ws), ref, credit)
    after
      Lifecycle.earlier(ws.limits.timeout, Lifecycle.remaining(ws.deadline)) ->
        continue(WebSocket.info({:gaoxy_websocket_lifetime, lease}, ws), ref, credit)
    end
  end

  defp identity({owner, _, token}), do: {owner, token}
  defp identity({owner, _, _, token}), do: {owner, token}

  defp continue({:continue, ws}, ref, credit), do: loop(ws, ref, credit)
  defp continue({:close, ws}, _, _), do: finish(ws)

  defp finish(ws) do
    reason = ws.reason || :remote
    WebSocket.terminate(ws, reason)

    case reason do
      {:error, reason} ->
        _ = Exchange.abort(ws.exchange, reason)
        {:error, reason, ws.exchange}

      _ ->
        case ws.exchange.transport.websocket_finish(ws.exchange) do
          :ok ->
            {:ok, ws.exchange}

          {:error, reason} ->
            _ = Exchange.abort(ws.exchange, reason)
            {:error, reason, ws.exchange}
        end
    end
  end
end
