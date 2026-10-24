defmodule Gaoxy.HTTP.HTTP2.Stream do
  @moduledoc false
  alias Gaoxy.Lifecycle
  alias Gaoxy.HTTP.Exchange
  alias Gaoxy.HTTP.Response

  def run(lease, owner, id, token, gate, protocol_bytes, deadline) do
    Process.link(owner)
    monitor = Process.monitor(owner)
    gate_monitor = Process.monitor(gate)

    if Process.alive?(owner) and Process.alive?(gate) and Lifecycle.remaining(deadline) != 0 do
      receive do
        {:h2_dispatch, ^owner,
         %Exchange{
           gate: ^gate,
           lease: ^lease,
           deadline: ^deadline,
           protocol_bytes: ^protocol_bytes,
           transport_state: {^owner, ^id, ^token}
         } = exchange, {module, options}} ->
          with true <-
                 Process.alive?(owner) and Process.alive?(gate) and
                   Lifecycle.remaining(deadline) != 0,
               {:ok, exchange} <- request_lifetime(exchange) do
            result =
              try do
                if exchange.request.method == "CONNECT" and
                     exchange.request.protocol != "websocket",
                   do: Response.send_resp(exchange, 501, [], ""),
                   else: module.call(exchange, options)
              catch
                kind, reason -> {:error, {kind, reason}, exchange}
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

            outcome =
              case completed do
                {:ok, _} -> :ok
                {:error, :endpoint_failed} -> {:error, :endpoint_failed}
                _ -> {:error, :response_failed}
              end

            send(owner, {:h2_stream_done, self(), id, token, outcome})
          end

        {:DOWN, ^monitor, :process, ^owner, _} ->
          :ok

        {:DOWN, ^gate_monitor, :process, ^gate, _} ->
          :ok
      after
        Lifecycle.remaining(deadline) -> :ok
      end
    end

    :ok
  end

  defp request_lifetime(%{limits: %{request_timeout: :infinity}} = exchange) do
    with :ok <-
           Gaoxy.Admission.begin_request(
             exchange.gate,
             exchange.lease,
             Exchange.retained_bytes(exchange),
             :infinity
           ),
         :ok <- Gaoxy.HTTP.HTTP2.Transport.operation(exchange, :infinite_request) do
      {:ok, %{exchange | deadline: :infinity}}
    end
  end

  defp request_lifetime(exchange), do: {:ok, exchange}
end
