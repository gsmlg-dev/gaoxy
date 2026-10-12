defmodule Gaoxy.HTTP.HTTP3.Transport do
  @moduledoc false
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, HTTP2.Headers}
  alias Gaoxy.HTTP.HTTP3.Operations

  defdelegate send_resp(exchange, status, headers, body), to: Gaoxy.HTTP.HTTP3.Response

  defdelegate send_file(exchange, status, headers, filename, offset, length),
    to: Gaoxy.HTTP.HTTP3.Response

  defdelegate send_chunked(exchange, status, headers), to: Gaoxy.HTTP.HTTP3.Response
  defdelegate chunk(exchange, bytes), to: Gaoxy.HTTP.HTTP3.Response
  defdelegate inform(exchange, status, headers), to: Gaoxy.HTTP.HTTP3.Response
  defdelegate finish(exchange, trailers), to: Gaoxy.HTTP.HTTP3.Response

  def operation(exchange, operation) do
    {owner, table, key, token} = exchange.transport_state
    monitor = Process.monitor(owner)
    deadline = operation_deadline(exchange, operation)

    try do
      with {:ok, ref} <- Operations.submit(table, key, token, {operation, deadline}) do
        await(owner, monitor, table, key, token, ref, deadline)
      end
    after
      Process.demonitor(monitor, [:flush])
    end
  end

  defp operation_deadline(exchange, {:read, _, {:until, deadline}}),
    do: min(exchange.deadline, deadline + exchange.limits.write_timeout)

  defp operation_deadline(exchange, {:poll, {:until, deadline}}),
    do: min(exchange.deadline, deadline + exchange.limits.write_timeout)

  defp operation_deadline(exchange, _),
    do: min(exchange.deadline, Lifecycle.deadline(exchange.limits.write_timeout))

  defp await(owner, monitor, table, key, token, ref, deadline) do
    receive do
      {:http3_operation, ^token, ^ref, result} ->
        if Lifecycle.remaining(deadline) == 0 do
          expire(table, key, token, ref)
        else
          case Operations.ack(table, key, token, ref) do
            :ok -> result
            error -> error
          end
        end

      {:DOWN, ^monitor, :process, ^owner, _} ->
        {:error, :closed}
    after
      Lifecycle.remaining(deadline) -> expire(table, key, token, ref)
    end
  end

  defp expire(table, key, token, ref) do
    _ = Operations.timeout(table, key, token, ref)
    {:error, :timeout}
  end

  def read_body_step(exchange, credit, wait) do
    cond do
      not is_integer(credit) or credit <= 0 ->
        {:error, :invalid_read_length, exchange}

      not is_integer(wait) or wait < 0 ->
        {:error, :invalid_read_timeout, exchange}

      Lifecycle.remaining(exchange.deadline) == 0 ->
        {:error, :timeout, exchange}

      wait == 0 ->
        {:pending, exchange}

      true ->
        read(exchange, min(16_384, min(credit, exchange.limits.max_read_chunk)), wait)
    end
  end

  defp read(exchange, credit, wait) do
    deadline = min(exchange.deadline, Lifecycle.deadline(wait))

    with {:ok, exchange} <- maybe_continue(exchange),
         :ok <-
           Admission.update(
             exchange.gate,
             exchange.lease,
             Exchange.retained_bytes(exchange) + 2 * credit
           ) do
      result = operation(exchange, {:read, credit, {:until, deadline}})

      case result do
        {kind, bytes, ended, trailers} when kind in [:ok, :more] ->
          body = %{
            exchange.body
            | phase: if(ended, do: :done, else: :data),
              trailers: trailers,
              trailer_bytes: Headers.bytes(trailers),
              total: exchange.body.total + byte_size(bytes)
          }

          next = %{exchange | body: body}

          case Admission.update(next.gate, next.lease, Exchange.retained_bytes(next)) do
            :ok -> {kind, bytes, next}
            {:error, reason} -> {:error, reason, next}
          end

        :pending ->
          _ = Admission.update(exchange.gate, exchange.lease, Exchange.retained_bytes(exchange))
          {:pending, exchange}

        {:error, reason} ->
          _ = Admission.update(exchange.gate, exchange.lease, Exchange.retained_bytes(exchange))
          {:error, reason, exchange}
      end
    else
      {:error, reason, next} -> {:error, reason, next}
      {:error, reason} -> {:error, reason, exchange}
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

  def poll_connection(exchange, wait) do
    cond do
      not is_integer(wait) or wait < 0 ->
        {:error, :invalid_read_timeout, exchange}

      Lifecycle.remaining(exchange.deadline) == 0 ->
        {:error, :timeout, exchange}

      wait == 0 ->
        {:pending, exchange}

      true ->
        deadline = min(exchange.deadline, Lifecycle.deadline(wait))

        case operation(exchange, {:poll, {:until, deadline}}) do
          result when result in [:ok, :pending] -> {:pending, exchange}
          {:error, reason} -> {:error, reason, exchange}
        end
    end
  end

  def abort(exchange, reason) do
    case operation(exchange, {:abort, reason}) do
      :ok -> {:ok, %{exchange | close: true}}
      error -> error
    end
  end
end
