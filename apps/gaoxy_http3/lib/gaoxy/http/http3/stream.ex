defmodule Gaoxy.HTTP.HTTP3.Stream do
  @moduledoc false
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, Response}
  alias Gaoxy.HTTP.HTTP3.Operations

  def run_admitted(lease, owner, table, token, gate, deadline) do
    monitor = Process.monitor(owner)
    gate_monitor = Process.monitor(gate)

    try do
      receive do
        {:h3_start, ^owner, ^token} ->
          with true <- Process.alive?(owner) and Process.alive?(gate),
               {:ok, key, ^deadline} <- Operations.resolve(table, token),
               :ok <- Operations.ready(table, key, token, lease) do
            dispatch(owner, monitor, table, key, token, lease, deadline, gate)
          end

        {:DOWN, ^monitor, :process, ^owner, _} ->
          :ok

        {:DOWN, ^gate_monitor, :process, ^gate, _} ->
          :ok
      after
        Lifecycle.remaining(deadline) -> :ok
      end
    catch
      :exit, _ -> :ok
    after
      Process.demonitor(monitor, [:flush])
      Process.demonitor(gate_monitor, [:flush])
    end
  end

  def run(owner, table, key, token, gate, reserve, deadline) do
    monitor = Process.monitor(owner)

    try do
      receive do
        {:h3_start, ^owner, ^key, ^token} ->
          with {:ok, %{worker: worker, deadline: ^deadline, status: :starting}}
               when worker == self() <- Operations.status(table, key, token),
               true <- Process.alive?(owner),
               {:ok, lease} <- Admission.acquire(gate, reserve, drain_notify: true),
               :ok <- Admission.begin_request(gate, lease, reserve, deadline),
               :ok <- Operations.ready(table, key, token, lease) do
            dispatch(owner, monitor, table, key, token, lease, deadline, nil)
          end

        {:DOWN, ^monitor, :process, ^owner, _} ->
          :ok
      after
        Lifecycle.remaining(deadline) -> :ok
      end
    catch
      :exit, _ -> :ok
    after
      Process.demonitor(monitor, [:flush])
    end
  end

  defp dispatch(owner, monitor, table, key, token, lease, deadline, gate) do
    receive do
      {:h3_dispatch, ^owner, ^key, ^token, %{deadline: ^deadline} = exchange, endpoint} ->
        with {:ok, %{worker: worker, status: :idle}} when worker == self() <-
               Operations.status(table, key, token),
             true <- Process.alive?(owner) do
          {result, final} = execute(%{exchange | lease: lease}, endpoint)

          if gate == nil do
            Operations.finish(table, key, token, result)
          else
            Operations.finish(
              table,
              key,
              token,
              result,
              gate,
              %{transport_bytes: Exchange.retained_bytes(final), websocket_bytes: 0},
              terminal_deadline(final.deadline)
            )
          end
        end

      {:DOWN, ^monitor, :process, ^owner, _} ->
        :ok
    after
      Lifecycle.remaining(deadline) -> :ok
    end
  end

  defp terminal_deadline(:infinity), do: Lifecycle.deadline(Lifecycle.cleanup_headroom())
  defp terminal_deadline(deadline), do: deadline + Lifecycle.cleanup_headroom()

  defp execute(exchange, {module, options}) do
    result =
      try do
        if exchange.request.method == "CONNECT" and exchange.request.protocol != "websocket",
          do: Response.send_resp(exchange, 501, [], ""),
          else: module.call(exchange, options)
      catch
        _, _ -> {:error, :endpoint_failed, exchange}
      end

    final =
      case result do
        {:ok, final} -> final
        {:error, _, final} -> final
        _ -> exchange
      end

    completed =
      case {result, final.response} do
        {{:ok, _}, {:websocket, _, _, _, _}} ->
          Gaoxy.HTTP.WebSocket.Stream.run(final, %{})

        {{:error, _, _}, :chunked} ->
          {:error, :endpoint_failed}

        {{:error, _, _}, {:fixed_stream, remaining}}
        when is_integer(remaining) and remaining >= 0 ->
          {:error, :endpoint_failed}

        {_, :unset} ->
          Response.send_resp(final, 500, [], "")

        _ ->
          Response.finish(final)
      end

    retained =
      case completed do
        {:ok, exchange} -> exchange
        {:error, _, exchange} -> exchange
        _ -> final
      end

    result =
      case completed do
        {:ok, _} -> :ok
        {:error, :endpoint_failed} -> {:error, :endpoint_failed}
        _ -> {:error, :response_failed}
      end

    {result, retained}
  end
end
