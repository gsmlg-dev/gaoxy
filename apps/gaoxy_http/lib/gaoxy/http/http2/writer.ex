defmodule Gaoxy.HTTP.HTTP2.Writer do
  @moduledoc false
  alias Gaoxy.Admission
  alias Hell.Socket

  def run(owner, socket, gate, bytes, timeout) do
    # The socket owner can exit when send_timeout_close closes its socket.
    # Monitor it so the actual send result reaches admission before we stop.
    monitor = Process.monitor(owner)

    with {:ok, lease} <- Admission.acquire(gate, bytes, drain_notify: true) do
      send(owner, {:h2_writer_ready, self()})
      loop(owner, monitor, socket, gate, lease, timeout)
    else
      error -> send(owner, {:h2_writer_failed, error})
    end
  end

  defp loop(owner, monitor, socket, gate, lease, timeout) do
    receive do
      {:h2_write, ^owner, token, bytes, deadline} ->
        remaining = Gaoxy.Lifecycle.remaining(deadline)

        result =
          with true <- Process.alive?(owner) || {:error, :closed},
               true <- remaining > 0 || :expired,
               {:ok, operation} <- Admission.start_send(gate, lease, IO.iodata_length(bytes)) do
            result =
              with :ok <-
                     Socket.setopts(socket,
                       send_timeout: min(timeout, Gaoxy.Lifecycle.remaining(deadline)),
                       send_timeout_close: true
                     ) do
                cond do
                  not Process.alive?(owner) ->
                    {:error, :closed}

                  Gaoxy.Lifecycle.remaining(deadline) == 0 ->
                    :expired

                  true ->
                    send(owner, {:h2_write_started, self(), token})
                    Socket.send(socket, bytes)
                end
              end

            outcome = if result == :expired, do: {:error, :timeout}, else: result
            :ok = Admission.finish_send(gate, lease, operation, outcome)
            result
          end

        send(owner, {:h2_written, self(), token, result})
        if result in [:ok, :expired], do: loop(owner, monitor, socket, gate, lease, timeout)

      {:DOWN, ^monitor, :process, ^owner, _} ->
        :ok

      {:gaoxy_drain, _, ^lease, _} ->
        loop(owner, monitor, socket, gate, lease, timeout)

      :stop ->
        :ok

      _ ->
        loop(owner, monitor, socket, gate, lease, timeout)
    end
  end
end
