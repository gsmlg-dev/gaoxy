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

          if final.response == :unset do
            _ = Response.send_resp(final, 500, [], "")
          else
            _ = Response.finish(final)
          end

          send(owner, {:h2_stream_done, self(), id, token})

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
