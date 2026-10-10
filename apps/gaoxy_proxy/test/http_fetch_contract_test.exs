defmodule Gaoxy.Proxy.HTTPFetchContractTest do
  use ExUnit.Case, async: true
  import Bitwise

  alias HTTP.WebSocket.Event.{Close, Frame, Message, Open}

  @timeout 3_000

  test "per-request streaming resolves a small fixed response before body EOF" do
    {url, peer} =
      peer(fn socket, owner ->
        {_head, _rest} = recv_head(socket)
        :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n")
        send(owner, {:response_head, self()})

        receive do
          :send_body -> :gen_tcp.send(socket, "ok")
        after
          @timeout -> raise "body was not requested after headers"
        end
      end)

    promise =
      HTTP.fetch(url,
        http_version: :http1,
        http1_reuse: false,
        stream_response: true,
        request_mode: :proxy,
        decode_body: false,
        redirect: :manual
      )

    assert_receive {:response_head, ^peer}, @timeout

    assert %HTTP.Response{status: 200, body: stream, stream: stream} =
             HTTP.Promise.await(promise, @timeout)

    assert is_pid(stream)
    send(stream, {:read_chunk, self(), :ack})
    send(peer, :send_body)
    assert read_fixed_stream(stream, []) == "ok"
    assert_peer_done(peer)
  end

  for method <- [:get, :delete] do
    @method method

    test "published Fetch proxy preserves buffered #{@method} bodies" do
      method = @method
      bytes = <<"first", 0, "last">>

      {url, peer} =
        peer(fn socket, _owner ->
          {head, rest} = recv_head(socket)
          {body, ""} = recv_bytes(socket, rest, byte_size(bytes))
          send_fragmented(socket, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
          {head, body}
        end)

      assert %HTTP.Response{status: 200, body: "ok"} =
               url
               |> HTTP.fetch(
                 method: method,
                 body: bytes,
                 headers: [{"Content-Length", to_string(byte_size(bytes))}],
                 request_mode: :proxy,
                 http_version: :http1,
                 redirect: :manual,
                 timeout: @timeout
               )
               |> HTTP.Promise.await(@timeout)

      assert {head, ^bytes} = peer_result(peer)
      assert head =~ "#{String.upcase(to_string(method))} / HTTP/1.1\r\n"
      assert String.downcase(head) =~ "content-length: #{byte_size(bytes)}\r\n"
      refute String.downcase(head) =~ "transfer-encoding:"
    end

    test "published Fetch proxy preserves PID-streamed #{@method} bodies" do
      method = @method

      {url, peer} =
        peer(fn socket, owner ->
          {head, rest} = recv_head(socket)
          send(owner, {:request_head, self(), head})
          {body, ""} = recv_chunked(socket, rest, [])
          send_fragmented(socket, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
          body
        end)

      {:ok, upload} = HTTP.Stream.start_link(0)
      Process.unlink(upload)
      upload_monitor = Process.monitor(upload)
      on_exit(fn -> stop_process(upload) end)

      promise =
        HTTP.fetch(url,
          method: method,
          body: upload,
          duplex: :half,
          request_mode: :proxy,
          http_version: :http1,
          redirect: :manual,
          timeout: @timeout
        )

      assert_receive {:request_head, ^peer, head}, @timeout
      assert head =~ "#{String.upcase(to_string(method))} / HTTP/1.1\r\n"
      assert String.downcase(head) =~ "transfer-encoding: chunked\r\n"
      refute String.downcase(head) =~ "content-length:"
      assert :ok = HTTP.Stream.chunk(upload, "first", @timeout)
      assert :ok = HTTP.Stream.chunk(upload, <<0, "last">>, @timeout)
      assert :ok = HTTP.Stream.finish(upload)
      assert %HTTP.Response{status: 200, body: "ok"} = HTTP.Promise.await(promise, @timeout)
      assert <<"first", 0, "last">> == peer_result(peer)
      assert_receive {:DOWN, ^upload_monitor, :process, ^upload, :normal}, @timeout
    end
  end

  for code <- [1001, 1008, 1011] do
    @code code

    test "published WebSocket proxy preserves close #{@code} after acknowledged frame writes" do
      code = @code

      {url, peer} =
        peer(fn socket, owner ->
          {head, _rest} = recv_head(socket)

          [key] =
            Regex.run(~r/(?im)^sec-websocket-key: ([^\r]+)\r$/, head, capture: :all_but_first)

          accept =
            Base.encode64(:crypto.hash(:sha, key <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))

          send_fragmented(socket, [
            "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n",
            "Sec-WebSocket-Accept: ",
            accept,
            "\r\n\r\n",
            <<0x81, 5, "hello">>
          ])

          {:binary, <<0, 1, 2>>} = recv_client_frame(socket)
          send(owner, {:frame_received, self()})
          {:close, <<^code::16, "done">>} = recv_client_frame(socket)
          send_fragmented(socket, <<0x88, 6, code::16, "done">>)
        end)

      assert %HTTP.WebSocket{pid: pid} =
               socket =
               HTTP.WebSocket.new(String.replace_prefix(url, "http:", "ws:"), [],
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
      on_exit(fn -> stop_process(pid) end)
      assert_receive {HTTP.WebSocket, ^socket, %Open{}}, @timeout
      assert HTTP.WebSocket.http_version(socket) == :http1

      assert_receive {HTTP.WebSocket, ^socket, %Frame{opcode: :text, data: "hello"},
                      delivery_ref},
                     @timeout

      assert :ok = HTTP.WebSocket.acknowledge(socket, delivery_ref)
      assert {:ok, write_ref} = HTTP.WebSocket.send_frame_ack(socket, {:binary, <<0, 1, 2>>})
      assert_receive {HTTP.WebSocket, ^socket, {:send_result, ^write_ref, :ok}}, @timeout
      assert_receive {:frame_received, ^peer}, @timeout
      assert :ok = HTTP.WebSocket.close(socket, code, "done")

      assert_receive {HTTP.WebSocket, ^socket,
                      %Close{code: ^code, reason: "done", was_clean: true}},
                     @timeout

      assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, @timeout
      assert_peer_done(peer)
    end
  end

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
      stop_process(pid)
      :gen_tcp.close(listener)
    end)

    {"http://127.0.0.1:#{port}/", pid}
  end

  defp assert_peer_done(peer), do: assert(:ok == peer_result(peer))

  defp peer_result(peer) do
    monitor = Process.monitor(peer)

    result =
      receive do
        {:peer_done, ^peer, result} -> result
        {:peer_error, ^peer, error} -> flunk("loopback peer failed: #{error}")
      after
        @timeout -> flunk("loopback peer did not complete")
      end

    assert_receive {:DOWN, ^monitor, :process, ^peer, reason} when reason in [:normal, :noproc],
                   @timeout

    result
  end

  defp stop_process(pid) do
    monitor = Process.monitor(pid)
    if Process.alive?(pid), do: Process.exit(pid, :kill)

    receive do
      {:DOWN, ^monitor, :process, ^pid, _reason} -> :ok
    after
      @timeout -> raise "test process did not stop"
    end
  end

  defp send_fragmented(socket, bytes) do
    bytes
    |> IO.iodata_to_binary()
    |> :binary.bin_to_list()
    |> Enum.chunk_every(3)
    |> Enum.each(fn chunk -> :ok = :gen_tcp.send(socket, chunk) end)
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
    size = line |> String.trim_trailing("\r\n") |> String.to_integer(16)

    case size do
      0 ->
        {"\r\n", tail} = recv_bytes(socket, rest, 2)
        {parts |> Enum.reverse() |> IO.iodata_to_binary(), tail}

      size ->
        {chunk, rest} = recv_bytes(socket, rest, size)
        {"\r\n", rest} = recv_bytes(socket, rest, 2)
        recv_chunked(socket, rest, [chunk | parts])
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

  defp read_fixed_stream(stream, parts) do
    receive do
      {:stream_chunk, ^stream, bytes, ref} ->
        send(stream, {:stream_chunk_ack, ref})
        read_fixed_stream(stream, [bytes | parts])

      {:stream_end, ^stream} ->
        IO.iodata_to_binary(Enum.reverse(parts))

      {:stream_trailers, ^stream, _} ->
        read_fixed_stream(stream, parts)

      {:stream_error, ^stream, reason} ->
        flunk("fixed stream failed: #{inspect(reason)}")
    after
      @timeout -> flunk("fixed stream did not finish")
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
