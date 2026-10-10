defmodule WebSocketCloseProbe do
  import Bitwise

  alias HTTP.WebSocket.Event.{Close, Frame, Open}

  @timeout 3_000

  def run(code) do
    owner = self()

    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

    {:ok, {_, port}} = :inet.sockname(listener)

    {peer, peer_monitor} =
      spawn_monitor(fn ->
        {:ok, tcp} = :gen_tcp.accept(listener, @timeout)

        try do
          head = recv_head(tcp, "")

          [key] =
            Regex.run(~r/(?im)^sec-websocket-key: ([^\r]+)\r$/, head, capture: :all_but_first)

          accept =
            Base.encode64(:crypto.hash(:sha, key <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))

          send_fragmented(tcp, [
            "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n",
            "Sec-WebSocket-Accept: ",
            accept,
            "\r\n\r\n",
            <<0x81, 5, "hello">>
          ])

          {:binary, <<0, 1, 2>>} = recv_frame(tcp)
          send(owner, {:frame_received, self()})
          {:close, <<^code::16, "probe">>} = recv_frame(tcp)
          send(owner, {:wire_close, self(), code, "probe"})
          send_fragmented(tcp, <<0x88, 7, code::16, "probe">>)
        after
          :gen_tcp.close(tcp)
        end
      end)

    %HTTP.WebSocket{pid: pid} =
      socket =
      HTTP.WebSocket.new("ws://127.0.0.1:#{port}/", [],
        mode: :proxy,
        http_version: :http1,
        delivery: :ack,
        automatic_pong: false,
        opening_timeout: @timeout,
        idle_timeout: @timeout,
        write_timeout: @timeout,
        close_timeout: @timeout,
        max_message_size: 1024,
        max_queue_bytes: 2048,
        max_queue_events: 4,
        max_send_queue: 2048,
        max_send_frames: 4
      )

    monitor = Process.monitor(pid)

    try do
      receive do
        {HTTP.WebSocket, ^socket, %Open{}} -> :ok
      after
        @timeout -> raise "WebSocket did not open"
      end

      :http1 = HTTP.WebSocket.http_version(socket)

      receive do
        {HTTP.WebSocket, ^socket, %Frame{opcode: :text, data: "hello"}, ref} ->
          :ok = HTTP.WebSocket.acknowledge(socket, ref)
      after
        @timeout -> raise "WebSocket did not deliver proxy frame"
      end

      {:ok, write_ref} = HTTP.WebSocket.send_frame_ack(socket, {:binary, <<0, 1, 2>>})

      receive do
        {HTTP.WebSocket, ^socket, {:send_result, ^write_ref, :ok}} -> :ok
      after
        @timeout -> raise "WebSocket frame write did not complete"
      end

      receive do
        {:frame_received, ^peer} -> :ok
      after
        @timeout -> raise "peer did not receive completed write"
      end

      :ok = HTTP.WebSocket.close(socket, code, "probe")

      receive do
        {:wire_close, ^peer, ^code, "probe"} -> :ok
      after
        @timeout -> raise "peer did not receive preserved close code"
      end

      receive do
        {HTTP.WebSocket, ^socket, %Close{code: ^code, reason: "probe", was_clean: true}} -> :ok
      after
        @timeout -> raise "WebSocket did not exchange a clean preserved close"
      end

      await_down(pid, monitor)
      await_down(peer, peer_monitor)

      IO.puts(
        JSON.encode!(%{code: code, mode: :proxy, wire_code: code, clean: true, preserved: true})
      )
    after
      :gen_tcp.close(listener)
      stop(pid)
      stop(peer)
    end
  end

  defp recv_head(socket, bytes) when byte_size(bytes) < 65_536 do
    case :binary.split(bytes, "\r\n\r\n") do
      [head, ""] ->
        head <> "\r\n\r\n"

      [_] ->
        {:ok, next} = :gen_tcp.recv(socket, 0, @timeout)
        recv_head(socket, bytes <> next)
    end
  end

  defp recv_frame(socket) do
    {:ok, <<first, second>>} = :gen_tcp.recv(socket, 2, @timeout)
    true = (first &&& 0x80) != 0
    true = (second &&& 0x80) != 0
    size = second &&& 0x7F
    true = size < 126
    {:ok, <<m1, m2, m3, m4>>} = :gen_tcp.recv(socket, 4, @timeout)
    {:ok, masked} = :gen_tcp.recv(socket, size, @timeout)

    payload =
      for {byte, index} <- Enum.with_index(:binary.bin_to_list(masked)), into: <<>> do
        <<bxor(byte, elem({m1, m2, m3, m4}, rem(index, 4)))>>
      end

    case first &&& 0x0F do
      2 -> {:binary, payload}
      8 -> {:close, payload}
    end
  end

  defp send_fragmented(socket, bytes) do
    bytes
    |> IO.iodata_to_binary()
    |> :binary.bin_to_list()
    |> Enum.chunk_every(3)
    |> Enum.each(fn chunk -> :ok = :gen_tcp.send(socket, chunk) end)
  end

  defp await_down(pid, monitor) do
    receive do
      {:DOWN, ^monitor, :process, ^pid, :normal} -> :ok
      {:DOWN, ^monitor, :process, ^pid, reason} -> raise "process failed: #{inspect(reason)}"
    after
      @timeout -> raise "process did not stop"
    end
  end

  defp stop(pid) do
    monitor = Process.monitor(pid)
    if Process.alive?(pid), do: Process.exit(pid, :kill)

    receive do
      {:DOWN, ^monitor, :process, ^pid, _reason} -> :ok
    after
      @timeout -> raise "cleanup did not stop process"
    end
  end
end

for code <- [1000, 1001, 1008, 1011], do: WebSocketCloseProbe.run(code)
