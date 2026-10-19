defmodule Gaoxy.HTTP.HTTP3.Stream do
  @moduledoc false
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.Response
  alias Gaoxy.HTTP.HTTP3.Operations

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
            dispatch(owner, monitor, table, key, token, lease, deadline)
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

  defp dispatch(owner, monitor, table, key, token, lease, deadline) do
    receive do
      {:h3_dispatch, ^owner, ^key, ^token, %{deadline: ^deadline} = exchange, endpoint} ->
        with {:ok, %{worker: worker, status: :idle}} when worker == self() <-
               Operations.status(table, key, token),
             true <- Process.alive?(owner) do
          result = execute(%{exchange | lease: lease}, endpoint)
          Operations.finish(table, key, token, result)
        end

      {:DOWN, ^monitor, :process, ^owner, _} ->
        :ok
    after
      Lifecycle.remaining(deadline) -> :ok
    end
  end

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
          Gaoxy.HTTP.WebSocket.Stream.run(final, final.limits.websocket_limits)

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

    case completed do
      {:ok, _} -> :ok
      {:error, :endpoint_failed} -> {:error, :endpoint_failed}
      _ -> {:error, :response_failed}
    end
  end
end
