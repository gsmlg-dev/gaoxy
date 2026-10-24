defmodule Gaoxy.HTTP.HTTP3.Transport do
  @moduledoc false
  alias Gaoxy.Lifecycle
  alias Gaoxy.HTTP.{Exchange, HTTP2.Headers}
  alias Gaoxy.HTTP.HTTP3.Operations

  defdelegate send_resp(exchange, status, headers, body), to: Gaoxy.HTTP.HTTP3.Response

  defdelegate send_file(exchange, status, headers, filename, offset, length),
    to: Gaoxy.HTTP.HTTP3.Response

  defdelegate send_chunked(exchange, status, headers), to: Gaoxy.HTTP.HTTP3.Response
  defdelegate chunk(exchange, bytes), to: Gaoxy.HTTP.HTTP3.Response
  defdelegate inform(exchange, status, headers), to: Gaoxy.HTTP.HTTP3.Response
  defdelegate finish(exchange, trailers), to: Gaoxy.HTTP.HTTP3.Response

  def websocket_open(exchange, headers, lifetime) do
    {_, table, key, token} = exchange.transport_state

    with {:ok, %{deadline: original}} <- Operations.status(table, key, token),
         deadline =
           Lifecycle.earlier(
             original,
             Lifecycle.earlier(lifetime, Lifecycle.deadline(exchange.limits.write_timeout))
           ),
         :ok <- operation_until(exchange, {:websocket_open, headers, lifetime}, deadline) do
      {:ok, %{exchange | deadline: lifetime, response: :upgraded}}
    end
  end

  def websocket_demand(exchange, credit, ref) do
    {_, table, key, token} = exchange.transport_state
    Operations.demand(table, key, token, credit, ref)
  end

  def websocket_send(exchange, bytes), do: operation(exchange, {:data, bytes, false})

  def websocket_finish(exchange) do
    {_, table, key, token} = exchange.transport_state

    with :ok <- Operations.close_demand(table, key, token),
         do: operation(exchange, {:websocket_finish})
  end

  def operation(exchange, operation) do
    operation_until(exchange, operation, operation_deadline(exchange, operation))
  end

  defp operation_until(exchange, operation, deadline) do
    {owner, table, key, token} = exchange.transport_state
    monitor = Process.monitor(owner)

    try do
      with {:ok, ref} <- Operations.submit(table, key, token, {operation, deadline}) do
        await(owner, monitor, table, key, token, ref, deadline)
      end
    after
      Process.demonitor(monitor, [:flush])
    end
  end

  defp operation_deadline(exchange, {:read, _, {:until, deadline}}),
    do: Lifecycle.earlier(exchange.deadline, deadline + exchange.limits.write_timeout)

  defp operation_deadline(exchange, {:poll, {:until, deadline}}),
    do: Lifecycle.earlier(exchange.deadline, deadline + exchange.limits.write_timeout)

  defp operation_deadline(exchange, _),
    do: Lifecycle.earlier(exchange.deadline, Lifecycle.deadline(exchange.limits.write_timeout))

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
    deadline = Lifecycle.earlier(exchange.deadline, Lifecycle.deadline(wait))

    with {:ok, exchange} <- maybe_continue(exchange),
         :ok <-
           Exchange.update_body_retention(
             exchange,
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

          case Exchange.update_body_retention(next, Exchange.retained_bytes(next)) do
            :ok -> {kind, bytes, next}
            {:error, reason} -> {:error, reason, next}
          end

        :pending ->
          _ = Exchange.update_body_retention(exchange, Exchange.retained_bytes(exchange))
          {:pending, exchange}

        {:error, reason} ->
          _ = Exchange.update_body_retention(exchange, Exchange.retained_bytes(exchange))
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
        poll_now(exchange)

      true ->
        deadline = Lifecycle.earlier(exchange.deadline, Lifecycle.deadline(wait))

        case operation(exchange, {:poll, {:until, deadline}}) do
          result when result in [:ok, :pending] -> {:pending, exchange}
          {:error, reason} -> {:error, reason, exchange}
        end
    end
  end

  defp poll_now(exchange) do
    {owner, table, key, token} = exchange.transport_state

    with true <- Process.alive?(owner) and :ets.info(table, :owner) == owner,
         {:ok, %{worker: worker, status: :idle, deadline: deadline}} when worker == self() <-
           Operations.status(table, key, token) do
      if Lifecycle.remaining(deadline) == 0,
        do: {:error, :timeout, exchange},
        else: {:pending, exchange}
    else
      _ -> {:error, :closed, exchange}
    end
  end

  def abort(exchange, reason) do
    case operation(exchange, {:abort, reason}) do
      :ok -> {:ok, %{exchange | close: true}}
      error -> error
    end
  end
end
