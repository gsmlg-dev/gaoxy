defmodule MethodBodyProbe do
  @timeout 3_000

  def run(method, kind) do
    owner = self()
    expected = <<"first", 0, "last">>

    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

    {:ok, {_, port}} = :inet.sockname(listener)

    {peer, monitor} =
      spawn_monitor(fn ->
        {:ok, socket} = :gen_tcp.accept(listener, @timeout)

        try do
          {head, rest} = recv_until(socket, "", "\r\n\r\n")
          send(owner, {:head, self(), head})

          {body, ""} =
            case kind do
              :buffered -> recv_bytes(socket, rest, byte_size(expected))
              :streamed -> recv_chunked(socket, rest, [])
            end

          send(owner, {:wire, self(), head, body})

          :ok =
            :gen_tcp.send(
              socket,
              "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"
            )
        after
          :gen_tcp.close(socket)
        end
      end)

    {body, headers, upload_monitor} =
      case kind do
        :buffered ->
          {expected, [{"Content-Length", to_string(byte_size(expected))}], nil}

        :streamed ->
          {:ok, stream} = HTTP.Stream.start_link(0)
          Process.unlink(stream)
          {stream, [], Process.monitor(stream)}
      end

    try do
      promise =
        HTTP.fetch("http://127.0.0.1:#{port}/",
          method: method,
          request_mode: :proxy,
          headers: headers,
          body: body,
          duplex: :half,
          redirect: :manual,
          http_version: :http1,
          telemetry: false,
          timeout: @timeout
        )

      receive do
        {:head, ^peer, head} ->
          true = String.starts_with?(head, "#{String.upcase(to_string(method))} / HTTP/1.1\r\n")

          if kind == :streamed do
            true = String.contains?(String.downcase(head), "transfer-encoding: chunked\r\n")
            false = String.contains?(String.downcase(head), "content-length:")
            :ok = HTTP.Stream.chunk(body, "first", @timeout)
            :ok = HTTP.Stream.chunk(body, <<0, "last">>, @timeout)
            :ok = HTTP.Stream.finish(body)
          end
      after
        @timeout -> raise "peer did not report request head"
      end

      %HTTP.Response{status: 200, body: "ok"} = HTTP.Promise.await(promise, @timeout)

      receive do
        {:wire, ^peer, head, actual} ->
          IO.puts(
            JSON.encode!(%{
              method: method,
              body_kind: kind,
              request_mode: :proxy,
              status: 200,
              received_head: head,
              expected_body: expected,
              actual_body: actual,
              preserved: actual == expected
            })
          )

          true = actual == expected
      after
        @timeout -> raise "peer did not report request body"
      end

      await_down(peer, monitor)
      if upload_monitor, do: await_down(body, upload_monitor)
    after
      :gen_tcp.close(listener)
      stop(peer)
      if is_pid(body), do: stop(body)
    end
  end

  defp recv_until(socket, bytes, delimiter) when byte_size(bytes) < 65_536 do
    case :binary.match(bytes, delimiter) do
      {offset, length} ->
        split = offset + length
        <<head::binary-size(split), rest::binary>> = bytes
        {head, rest}

      :nomatch ->
        {:ok, next} = :gen_tcp.recv(socket, 0, @timeout)
        recv_until(socket, bytes <> next, delimiter)
    end
  end

  defp recv_bytes(_socket, bytes, size) when byte_size(bytes) >= size do
    <<body::binary-size(size), rest::binary>> = bytes
    {body, rest}
  end

  defp recv_bytes(socket, bytes, size) do
    {:ok, next} = :gen_tcp.recv(socket, 0, @timeout)
    recv_bytes(socket, bytes <> next, size)
  end

  defp recv_chunked(socket, bytes, parts) do
    {line, rest} = recv_until(socket, bytes, "\r\n")

    case line |> String.trim_trailing("\r\n") |> String.to_integer(16) do
      0 ->
        {"\r\n", tail} = recv_bytes(socket, rest, 2)
        {parts |> Enum.reverse() |> IO.iodata_to_binary(), tail}

      size ->
        {chunk, rest} = recv_bytes(socket, rest, size)
        {"\r\n", rest} = recv_bytes(socket, rest, 2)
        recv_chunked(socket, rest, [chunk | parts])
    end
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

for method <- [:post, :delete, :get], kind <- [:buffered, :streamed] do
  MethodBodyProbe.run(method, kind)
end
