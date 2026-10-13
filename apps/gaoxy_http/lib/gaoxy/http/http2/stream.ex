defmodule Gaoxy.HTTP.HTTP2.Stream do
  @moduledoc false
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.Response

  def run(owner, id, token, gate, reserve, deadline) do
    Process.link(owner)
    monitor = Process.monitor(owner)

    with {:ok, lease} <- Admission.acquire(gate, reserve, drain_notify: true),
         :ok <- Admission.begin_request(gate, lease, reserve, deadline) do
      send(owner, {:h2_stream_ready, self(), id, token, lease})

      receive do
        {:h2_dispatch, ^owner, exchange, {module, options}} ->
          exchange = %{exchange | lease: lease}

          result =
            try do
              if exchange.request.method == "CONNECT",
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

        {:DOWN, ^monitor, :process, ^owner, _} ->
          :ok
      after
        Lifecycle.remaining(deadline) -> :ok
      end
    else
      error -> send(owner, {:h2_stream_failed, self(), id, token, error})
    end
  end
end
