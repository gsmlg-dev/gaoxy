defmodule Gaoxy.HTTP.HTTP2.Writer do
  @moduledoc false
  alias Gaoxy.Admission
  alias ThousandIsland.Socket

  def run(owner, socket, gate, bytes, timeout) do
    Process.link(owner)
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
          with true <- remaining > 0 || {:error, :timeout},
               {:ok, operation} <- Admission.start_send(gate, lease, IO.iodata_length(bytes)) do
            result =
              with :ok <-
                     Socket.setopts(socket,
                       send_timeout: min(timeout, remaining),
                       send_timeout_close: true
                     ),
                   do: Socket.send(socket, bytes)

            :ok = Admission.finish_send(gate, lease, operation, result)
            result
          end

        send(owner, {:h2_written, self(), token, result})
        if result == :ok, do: loop(owner, monitor, socket, gate, lease, timeout)

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
