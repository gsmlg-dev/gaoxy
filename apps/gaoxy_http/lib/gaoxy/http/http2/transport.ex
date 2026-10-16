defmodule Gaoxy.HTTP.HTTP2.Transport do
  @moduledoc false
  alias Gaoxy.HTTP.Exchange
  alias Gaoxy.{Admission, Lifecycle}

  defdelegate send_resp(exchange, status, headers, body), to: Gaoxy.HTTP.HTTP2.Response

  defdelegate send_file(exchange, status, headers, filename, offset, length),
    to: Gaoxy.HTTP.HTTP2.Response

  defdelegate send_chunked(exchange, status, headers), to: Gaoxy.HTTP.HTTP2.Response
  defdelegate chunk(exchange, bytes), to: Gaoxy.HTTP.HTTP2.Response
  defdelegate inform(exchange, status, headers), to: Gaoxy.HTTP.HTTP2.Response
  defdelegate finish(exchange, trailers), to: Gaoxy.HTTP.HTTP2.Response

  def operation(exchange, operation) do
    {owner, id, token} = exchange.transport_state

    {operation, deadline} =
      case operation do
        {:head, _, _, _} -> write_operation(exchange, operation)
        {:data, _, _} -> write_operation(exchange, operation)
        {:trailers, _} -> write_operation(exchange, operation)
        _ -> {operation, exchange.deadline}
      end

    remaining = Lifecycle.remaining(deadline)

    if remaining == 0,
      do: {:error, :timeout},
      else: GenServer.call(owner, {:h2_operation, id, token, operation}, remaining + 100)
  catch
    :exit, _ -> {:error, :closed}
  end

  defp write_operation(exchange, operation) do
    deadline = min(exchange.deadline, Lifecycle.deadline(exchange.limits.write_timeout))
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
               Admission.update(
                 exchange.gate,
                 exchange.lease,
                 Exchange.retained_bytes(exchange) + 2 * credit
               ) do
          result =
            operation(
              exchange,
              {:read, credit, min(wait, Lifecycle.remaining(exchange.deadline))}
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

              case Admission.update(next.gate, next.lease, Exchange.retained_bytes(next)) do
                :ok -> {kind, bytes, next}
                {:error, reason} -> {:error, reason, next}
              end

            :pending ->
              case Admission.update(
                     exchange.gate,
                     exchange.lease,
                     Exchange.retained_bytes(exchange)
                   ) do
                :ok -> {:pending, exchange}
                {:error, reason} -> {:error, reason, exchange}
              end

            {:error, reason} ->
              _ =
                Admission.update(exchange.gate, exchange.lease, Exchange.retained_bytes(exchange))

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

    case inform(exchange, 100, []) do
      :ok -> {:ok, exchange}
      {:error, reason} -> {:error, reason, exchange}
    end
  end

  defp maybe_continue(exchange), do: {:ok, exchange}

  def body_complete?(exchange), do: exchange.body.phase == :done

  def poll_connection(exchange, wait) when is_integer(wait) and wait >= 0 do
    case operation(exchange, {:poll, min(wait, Lifecycle.remaining(exchange.deadline))}) do
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
