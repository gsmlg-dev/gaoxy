defmodule Gaoxy.HTTP.HTTP2.Transport do
  @moduledoc false
  alias Gaoxy.HTTP.Exchange
  alias Gaoxy.Lifecycle

  defdelegate send_resp(exchange, status, headers, body), to: Gaoxy.HTTP.HTTP2.Response

  defdelegate send_file(exchange, status, headers, filename, offset, length),
    to: Gaoxy.HTTP.HTTP2.Response

  defdelegate send_chunked(exchange, status, headers), to: Gaoxy.HTTP.HTTP2.Response
  defdelegate chunk(exchange, bytes), to: Gaoxy.HTTP.HTTP2.Response
  defdelegate inform(exchange, status, headers), to: Gaoxy.HTTP.HTTP2.Response
  defdelegate finish(exchange, trailers), to: Gaoxy.HTTP.HTTP2.Response

  def websocket_open(exchange, headers, lifetime) do
    deadline = Lifecycle.earlier(lifetime, Lifecycle.deadline(exchange.limits.write_timeout))

    case operation(exchange, {:websocket_open, headers, lifetime, deadline}) do
      :ok -> {:ok, %{exchange | deadline: lifetime, response: :upgraded}}
      error -> error
    end
  end

  def websocket_demand(exchange, credit, ref),
    do: operation(exchange, {:websocket_demand, credit, ref})

  def websocket_send(exchange, bytes), do: operation(exchange, {:data, bytes, false})

  def websocket_finish(exchange) do
    with :ok <- operation(exchange, :websocket_closing),
         :ok <- operation(exchange, {:data, "", true}) do
      # Keep the worker admitted until the peer's ordinary END_STREAM arrives.
      # Reuse the bounded read slot after cancelling the WS demand, so the
      # owner can finish this stream without resetting a valid half-close.
      wait =
        Lifecycle.earlier(exchange.limits.read_timeout, Lifecycle.remaining(exchange.deadline))

      case operation(exchange, {:read, 1, wait}) do
        {:ok, "", true, _} -> :ok
        {:error, _} = error -> error
        _ -> {:error, :websocket_close_incomplete}
      end
    end
  end

  def operation(exchange, {:read, _, wait} = operation) do
    {owner, id, token} = exchange.transport_state

    deadline =
      Lifecycle.earlier(
        exchange.deadline,
        Lifecycle.deadline(min(wait, exchange.limits.read_timeout) + 100)
      )

    case Lifecycle.remaining(deadline) do
      0 -> {:error, :timeout}
      remaining -> GenServer.call(owner, {:h2_operation, id, token, operation}, remaining)
    end
  catch
    :exit, {:timeout, _} -> {:error, :timeout}
    :exit, _ -> {:error, :closed}
  end

  def operation(exchange, :read_continue) do
    {operation, deadline} = write_operation(exchange, {:head, 100, [], false})
    {owner, id, token} = exchange.transport_state

    case Lifecycle.remaining(deadline) do
      0 -> {:error, :timeout}
      remaining -> GenServer.call(owner, {:h2_operation, id, token, operation}, remaining)
    end
  catch
    :exit, {:timeout, _} -> {:error, :timeout}
    :exit, _ -> {:error, :closed}
  end

  def operation(exchange, operation) do
    {owner, id, token} = exchange.transport_state

    {operation, deadline} =
      case operation do
        {:head, _, _, _} ->
          write_operation(exchange, operation)

        {:data, _, _} ->
          write_operation(exchange, operation)

        {:trailers, _} ->
          write_operation(exchange, operation)

        {:websocket_open, _, _, deadline} ->
          {operation, deadline}

        {:poll, wait} ->
          {operation, Lifecycle.earlier(exchange.deadline, Lifecycle.deadline(wait + 100))}

        _ ->
          {operation,
           Lifecycle.earlier(exchange.deadline, Lifecycle.deadline(exchange.limits.read_timeout))}
      end

    remaining = Lifecycle.remaining(deadline)

    if remaining == 0,
      do: {:error, :timeout},
      else: GenServer.call(owner, {:h2_operation, id, token, operation}, remaining + 100)
  catch
    :exit, _ -> {:error, :closed}
  end

  defp write_operation(exchange, operation) do
    deadline =
      Lifecycle.earlier(exchange.deadline, Lifecycle.deadline(exchange.limits.write_timeout))

    {{:write, deadline, operation}, deadline}
  end

  def read_body_step(exchange, credit, wait) do
    cond do
      not is_integer(credit) or credit <= 0 ->
        {:error, :invalid_read_length, exchange}

      not is_integer(wait) or wait < 0 ->
        {:error, :invalid_read_timeout, exchange}

      true ->
        credit = min(16_384, min(credit, exchange.limits.max_read_chunk))

        with {:ok, exchange} <- maybe_continue(exchange),
             :ok <-
               Exchange.reserve_body_retention(exchange, 2 * credit) do
          result =
            operation(
              exchange,
              {:read, credit, Lifecycle.earlier(wait, Lifecycle.remaining(exchange.deadline))}
            )

          case result do
            {kind, bytes, ended, trailers} when kind in [:ok, :more] ->
              body = %{
                exchange.body
                | phase: if(ended, do: :done, else: :data),
                  trailers: trailers,
                  trailer_bytes: Gaoxy.HTTP.HTTP2.Headers.bytes(trailers),
                  total: exchange.body.total + byte_size(bytes)
              }

              next = %{exchange | body: body}

              case Exchange.update_body_retention(next, Exchange.retained_bytes(next)) do
                :ok -> {kind, bytes, next}
                {:error, reason} -> {:error, reason, next}
              end

            :pending ->
              case Exchange.update_body_retention(
                     exchange,
                     Exchange.retained_bytes(exchange)
                   ) do
                :ok -> {:pending, exchange}
                {:error, reason} -> {:error, reason, exchange}
              end

            {:error, reason} ->
              _ =
                Exchange.update_body_retention(exchange, Exchange.retained_bytes(exchange))

              {:error, reason, exchange}
          end
        else
          {:error, reason, next} -> {:error, reason, next}
          {:error, reason} -> {:error, reason, exchange}
        end
    end
  end

  defp maybe_continue(%{request: %{expect_continue: true}, expect_sent: false} = exchange) do
    exchange = %{exchange | expect_sent: true}

    case operation(exchange, :read_continue) do
      :ok -> {:ok, exchange}
      {:error, reason} -> {:error, reason, exchange}
    end
  end

  defp maybe_continue(exchange), do: {:ok, exchange}

  def body_complete?(exchange), do: exchange.body.phase == :done

  def poll_connection(exchange, wait) when is_integer(wait) and wait >= 0 do
    case operation(
           exchange,
           {:poll, Lifecycle.earlier(wait, Lifecycle.remaining(exchange.deadline))}
         ) do
      :ok ->
        if Lifecycle.remaining(exchange.deadline) == 0,
          do: {:error, :timeout, exchange},
          else: {:pending, exchange}

      {:error, reason} ->
        {:error, reason, exchange}
    end
  end

  def poll_connection(exchange, _), do: {:error, :invalid_read_timeout, exchange}

  def abort(exchange, reason) do
    case operation(exchange, {:abort, reason}) do
      :ok -> {:ok, %{exchange | close: true}}
      error -> error
    end
  end
end
