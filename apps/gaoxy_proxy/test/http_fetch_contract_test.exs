defmodule Gaoxy.Proxy.HTTPFetchContractTest do
  use ExUnit.Case, async: true
  import Bitwise

  alias HTTP.WebSocket.Event.{Close, Message, Open}

  @timeout 3_000

  test "published Fetch preserves buffered gzip bytes and duplicate fields" do
    encoded = :zlib.gzip("raw proxy response")

    {url, peer} =
      peer(fn socket, _owner ->
        {_head, _rest} = recv_head(socket)

        :ok =
          :gen_tcp.send(socket, [
            "HTTP/1.1 200 OK\r\n",
            "Content-Encoding: gzip\r\n",
            "Set-Cookie: a=1\r\nSet-Cookie: b=2\r\n",
            "Content-Length: #{byte_size(encoded)}\r\n\r\n",
            encoded
          ])
      end)

    assert %HTTP.Response{status: 200, body: ^encoded, stream: nil} =
             response =
             url
             |> HTTP.fetch(http_version: :http1, redirect: :manual, decode_body: false)
             |> HTTP.Promise.await(@timeout)

    assert HTTP.Headers.get(response.headers, "content-encoding") == "gzip"
    assert HTTP.Headers.get(response.headers, "content-length") == to_string(byte_size(encoded))
    assert HTTP.Headers.get_all(response.headers, "set-cookie") == ["a=1", "b=2"]
    assert_peer_done(peer)
  end

  test "published Fetch ACK stream preserves gzip bytes and delivers ordered trailers before end" do
    encoded = :zlib.gzip("streamed raw proxy response")
    midpoint = div(byte_size(encoded), 2)
    <<first::binary-size(midpoint), second::binary>> = encoded

    {url, peer} =
      peer(fn socket, _owner ->
        {_head, _rest} = recv_head(socket)

        :ok =
          :gen_tcp.send(socket, [
            "HTTP/1.1 200 OK\r\n",
            "Content-Encoding: gzip\r\n",
            "Set-Cookie: a=1\r\nSet-Cookie: b=2\r\n",
            "Transfer-Encoding: chunked\r\n",
            "Trailer: X-Trace\r\n\r\n",
            Integer.to_string(byte_size(first), 16),
            "\r\n",
            first,
            "\r\n",
            Integer.to_string(byte_size(second), 16),
            "\r\n",
            second,
            "\r\n",
            "0\r\nX-Trace: first\r\nX-Trace: second\r\n\r\n"
          ])
      end)

    assert %HTTP.Response{status: 200, body: stream} =
             response =
             url
             |> HTTP.fetch(http_version: :http1, redirect: :manual, decode_body: false)
             |> HTTP.Promise.await(@timeout)

    assert response.stream == stream
    assert HTTP.Headers.get(response.headers, "content-encoding") == "gzip"
    assert HTTP.Headers.get_all(response.headers, "set-cookie") == ["a=1", "b=2"]
    assert HTTP.Headers.to_list(response.trailers) == []

    send(stream, {:read_chunk, self(), :ack})
    {bytes, trailers} = read_ack_stream(stream, [])
    assert bytes == encoded

    assert Enum.map(HTTP.Headers.to_list(trailers), fn {name, value} ->
             {String.downcase(name), value}
           end) == [{"x-trace", "first"}, {"x-trace", "second"}]

    assert_peer_done(peer)
  end

  test "published Fetch returns an early 413 while upload remains open and stops its source" do
    {url, peer} =
      peer(fn socket, owner ->
        {head, _rest} = recv_head(socket)
        send(owner, {:request_head, self(), head})

        receive do
          :reply_413 -> :ok
        after
          @timeout -> raise "413 release barrier timed out"
        end

        :ok =
          :gen_tcp.send(
            socket,
            "HTTP/1.1 413 Payload Too Large\r\nContent-Length: 0\r\n\r\n"
          )

        receive do
          :close_peer -> :ok
        after
          @timeout -> raise "413 peer close barrier timed out"
        end
      end)

    {:ok, upload} = HTTP.Stream.start_link(0)
    Process.unlink(upload)
    upload_monitor = Process.monitor(upload)

    promise =
      HTTP.fetch(url,
        method: :post,
        body: upload,
        duplex: :half,
        http_version: :http1,
        redirect: :manual,
        timeout: @timeout
      )

    assert_receive {:request_head, ^peer, head}, @timeout
    assert head =~ "POST / HTTP/1.1\r\n"
    send(peer, :reply_413)
    assert %HTTP.Response{status: 413} = HTTP.Promise.await(promise, @timeout)
    assert_receive {:DOWN, ^upload_monitor, :process, ^upload, _reason}, @timeout
    send(peer, :close_peer)
    assert_peer_done(peer)
  end

  test "published Fetch emits declared, ordered upload trailers" do
    {url, peer} =
      peer(fn socket, _owner ->
        {head, rest} = recv_head(socket)
        {body, _tail} = recv_until(socket, rest, "\r\n\r\n")

        :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        {head, body}
      end)

    {:ok, upload} = HTTP.Stream.start_link(0)

    promise =
      HTTP.fetch(url,
        method: :post,
        body: upload,
        duplex: :half,
        headers: [{"Trailer", "X-Trace"}],
        http_version: :http1,
        redirect: :manual,
        timeout: @timeout
      )

    assert :ok = HTTP.Stream.chunk(upload, "data", @timeout)
    assert :ok = HTTP.Stream.finish(upload, [{"X-Trace", "first"}, {"X-Trace", "second"}])
    assert %HTTP.Response{status: 200} = HTTP.Promise.await(promise, @timeout)
    assert {head, body} = peer_result(peer)
    assert String.downcase(head) =~ "trailer: x-trace\r\n"
    assert String.downcase(head) =~ "transfer-encoding: chunked\r\n"
    refute String.downcase(head) =~ "content-length:"
    assert body == "4\r\ndata\r\n0\r\nX-Trace: first\r\nX-Trace: second\r\n\r\n"
  end

  test "published WebSocket handles coalesced 101 and frame with acknowledged messages and writes" do
    {url, peer} =
      peer(fn socket, owner ->
        {head, _rest} = recv_head(socket)
        [key] = Regex.run(~r/(?im)^sec-websocket-key: ([^\r]+)\r$/, head, capture: :all_but_first)
        accept = Base.encode64(:crypto.hash(:sha, key <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))

        :ok =
          :gen_tcp.send(socket, [
            "HTTP/1.1 101 Switching Protocols\r\n",
            "Upgrade: websocket\r\nConnection: Upgrade\r\n",
            "Sec-WebSocket-Accept: ",
            accept,
            "\r\n",
            "Sec-WebSocket-Protocol: chat.v1\r\n\r\n",
            <<0x81, 5, "hello">>
          ])

        send(owner, {:ws_request, self(), head})
        send(owner, {:ws_frame, self(), recv_client_frame(socket)})
        send(owner, {:ws_frame, self(), recv_client_frame(socket)})
        close_frame = recv_client_frame(socket)
        :ok = :gen_tcp.send(socket, <<0x88, 2, 1000::16>>)
        close_frame
      end)

    assert %HTTP.WebSocket{pid: pid} =
             socket =
             HTTP.WebSocket.new(String.replace_prefix(url, "http:", "ws:"), ["chat.v1"],
               http_version: :http1,
               delivery: :ack,
               binary_type: :array_buffer,
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

    socket_monitor = Process.monitor(pid)
    assert_receive {:ws_request, ^peer, request_head}, @timeout
    assert request_head =~ "Sec-WebSocket-Protocol: chat.v1\r\n"
    assert_receive {HTTP.WebSocket, ^socket, %Open{}}, @timeout
    assert HTTP.WebSocket.protocol(socket) == "chat.v1"
    assert_receive {HTTP.WebSocket, ^socket, %Message{data: "hello"}, delivery_ref}, @timeout
    assert :ok = HTTP.WebSocket.acknowledge(socket, delivery_ref)

    assert {:ok, text_ref} = HTTP.WebSocket.send_ack(socket, "outbound text")
    assert_receive {HTTP.WebSocket, ^socket, {:send_result, ^text_ref, :ok}}, @timeout
    assert_receive {:ws_frame, ^peer, {:text, "outbound text"}}, @timeout

    assert {:ok, binary_ref} =
             HTTP.WebSocket.send_ack(socket, HTTP.WebSocket.array_buffer(<<0, 1, 2>>))

    assert_receive {HTTP.WebSocket, ^socket, {:send_result, ^binary_ref, :ok}}, @timeout
    assert_receive {:ws_frame, ^peer, {:binary, <<0, 1, 2>>}}, @timeout

    assert :ok = HTTP.WebSocket.close(socket, 1000, "done")
    assert {:close, <<1000::16, "done">>} = peer_result(peer)
    assert_receive {HTTP.WebSocket, ^socket, %Close{code: 1000}}, @timeout
    assert_receive {:DOWN, ^socket_monitor, :process, ^pid, _reason}, @timeout
  end

  defp peer(fun) do
    {:ok, listener} =
      :gen_tcp.listen(0, [
        :binary,
        packet: :raw,
        active: false,
        ip: {127, 0, 0, 1},
        reuseaddr: true
      ])

    {:ok, {_, port}} = :inet.sockname(listener)
    owner = self()

    pid =
      spawn(fn ->
        try do
          {:ok, socket} = :gen_tcp.accept(listener, @timeout)

          try do
            send(owner, {:peer_done, self(), fun.(socket, owner)})
          after
            :gen_tcp.close(socket)
          end
        rescue
          error ->
            send(owner, {:peer_error, self(), Exception.format(:error, error, __STACKTRACE__)})
        after
          :gen_tcp.close(listener)
        end
      end)

    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :kill)
      :gen_tcp.close(listener)
    end)

    {"http://127.0.0.1:#{port}/", pid}
  end

  defp assert_peer_done(peer), do: assert(:ok == peer_result(peer))

  defp peer_result(peer) do
    receive do
      {:peer_done, ^peer, result} -> result
      {:peer_error, ^peer, error} -> flunk("loopback peer failed: #{error}")
    after
      @timeout -> flunk("loopback peer did not complete")
    end
  end

  defp recv_head(socket) do
    {head, rest} = recv_until(socket, "", "\r\n\r\n")
    {head, rest}
  end

  defp recv_until(socket, bytes, delimiter) when byte_size(bytes) < 65_536 do
    case :binary.match(bytes, delimiter) do
      {offset, length} ->
        end_offset = offset + length

        {binary_part(bytes, 0, end_offset),
         binary_part(bytes, end_offset, byte_size(bytes) - end_offset)}

      :nomatch ->
        {:ok, next} = :gen_tcp.recv(socket, 0, @timeout)
        recv_until(socket, bytes <> next, delimiter)
    end
  end

  defp recv_client_frame(socket) do
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
      1 -> {:text, payload}
      2 -> {:binary, payload}
      8 -> {:close, payload}
    end
  end

  defp read_ack_stream(stream, parts) do
    receive do
      {:stream_chunk, ^stream, bytes, ref} when is_binary(bytes) ->
        send(stream, {:stream_chunk_ack, ref})
        read_ack_stream(stream, [bytes | parts])

      {:stream_chunk, ^stream, _bytes} ->
        flunk("stream delivered an unacknowledged chunk")

      {:stream_trailers, ^stream, trailers} ->
        await_stream_end(stream)
        {IO.iodata_to_binary(Enum.reverse(parts)), trailers}

      {:stream_end, ^stream} ->
        flunk("stream ended before its trailers")

      {:stream_error, ^stream, reason} ->
        flunk("stream failed before its trailers: #{inspect(reason)}")
    after
      @timeout -> flunk("stream did not deliver its trailers")
    end
  end

  defp await_stream_end(stream) do
    receive do
      {:stream_end, ^stream} ->
        :ok

      {:stream_chunk, ^stream, _, _} ->
        flunk("stream delivered data after its trailers")

      {:stream_chunk, ^stream, _} ->
        flunk("stream delivered data after its trailers")

      {:stream_trailers, ^stream, _} ->
        flunk("stream delivered trailers twice")

      {:stream_error, ^stream, reason} ->
        flunk("stream failed after its trailers: #{inspect(reason)}")
    after
      @timeout -> flunk("stream did not end after its trailers")
    end
  end
end
