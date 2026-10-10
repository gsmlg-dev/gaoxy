defmodule Gaoxy.Proxy.HTTPFetchCompletionTest do
  use ExUnit.Case, async: true

  alias HTTP.{Promise, RequestCompletion}

  @timeout 3_000

  test "the public handle cancels before response headers and confirms peer closure" do
    {url, peer} =
      peer(fn socket, owner ->
        recv_head(socket)
        send(owner, {:request_headers, self()})
        :gen_tcp.recv(socket, 0, @timeout)
      end)

    promise = fetch(url)
    completion = Promise.completion(promise)
    assert_receive {:request_headers, ^peer}, @timeout
    assert {:error, :cleanup_pending} = RequestCompletion.await(completion, 0)
    assert :ok = RequestCompletion.abort_and_await(completion, @timeout)
    assert {:error, :aborted} = Promise.await(promise, @timeout)
    assert {:error, :closed} = peer_result(peer)
    assert :ok = RequestCompletion.abort_and_await(completion, 0)
  end

  test "post-header cancellation settles an outstanding ACK chunk and closes the peer" do
    {url, peer} =
      peer(fn socket, _owner ->
        recv_head(socket)

        :ok =
          :gen_tcp.send(
            socket,
            "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n4\r\nbody\r\n"
          )

        :gen_tcp.recv(socket, 0, @timeout)
      end)

    promise = fetch(url, stream_response: true)
    completion = Promise.completion(promise)
    assert %HTTP.Response{status: 200, stream: stream} = Promise.await(promise, @timeout)
    monitor = Process.monitor(stream)
    send(stream, {:read_chunk, self(), :ack})
    assert_receive {:stream_chunk, ^stream, "body", _ack}, @timeout
    assert {:error, :cleanup_pending} = RequestCompletion.await(completion, 0)

    assert :ok = RequestCompletion.abort_and_await(completion, @timeout)
    assert_receive {:stream_error, ^stream, :aborted}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^stream, :normal}, @timeout
    assert {:error, :closed} = peer_result(peer)
    assert :ok = RequestCompletion.await(completion, 0)
  end

  test "upload cancellation joins the source and its blocked library enumerable producer" do
    owner = self()

    enumerable =
      Stream.resource(
        fn ->
          send(owner, {:producer_started, self()})
          :ready
        end,
        fn state ->
          receive do
            :release_item -> {["body"], state}
          end
        end,
        fn _state -> :ok end
      )

    {:ok, upload} = HTTP.Stream.from_enumerable(enumerable)
    Process.unlink(upload)
    on_exit(fn -> stop_process(upload) end)
    upload_monitor = Process.monitor(upload)
    assert_receive {:producer_started, producer}, @timeout
    producer_monitor = Process.monitor(producer)

    {url, peer} =
      peer(fn socket, owner ->
        recv_head(socket)
        send(owner, {:upload_headers, self()})
        :gen_tcp.recv(socket, 0, @timeout)
      end)

    promise = fetch(url, method: :post, body: upload, duplex: :half)
    completion = Promise.completion(promise)
    assert_receive {:upload_headers, ^peer}, @timeout
    assert {:error, :cleanup_pending} = RequestCompletion.await(completion, 0)
    assert :ok = RequestCompletion.abort_and_await(completion, @timeout)
    assert_receive {:DOWN, ^upload_monitor, :process, ^upload, :normal}, @timeout
    assert_receive {:DOWN, ^producer_monitor, :process, ^producer, :killed}, @timeout
    assert {:error, :aborted} = Promise.await(promise, @timeout)
    assert {:error, :closed} = peer_result(peer)
  end

  test "the public handle cancels a stalled OTP TLS handshake before headers" do
    {url, peer} =
      peer(fn socket, owner ->
        {:ok, <<22, _client_hello::binary>>} = :gen_tcp.recv(socket, 0, @timeout)
        send(owner, {:tls_handshake_started, self()})
        :gen_tcp.recv(socket, 0, @timeout)
      end)

    promise = fetch(String.replace_prefix(url, "http:", "https:"))

    completion = Promise.completion(promise)
    assert_receive {:tls_handshake_started, ^peer}, @timeout
    assert {:error, :cleanup_pending} = RequestCompletion.await(completion, 0)
    assert :ok = RequestCompletion.abort_and_await(completion, @timeout)
    assert {:error, _handshake_reason} = Promise.await(promise, @timeout)
    assert {:error, :closed} = peer_result(peer)
    assert :ok = RequestCompletion.await(completion, 0)
  end

  test "completed requests support concurrent cross-process waits and repeated cancellation" do
    {url, peer} =
      peer(fn socket, _owner ->
        recv_head(socket)
        :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
        :gen_tcp.recv(socket, 0, @timeout)
      end)

    promise = fetch(url)
    completion = Promise.completion(promise)
    assert %HTTP.Response{status: 200, body: "ok"} = Promise.await(promise, @timeout)

    waiters =
      for operation <- [:await, :abort_and_await, :await] do
        Task.async(fn -> apply(RequestCompletion, operation, [completion, @timeout]) end)
      end

    assert [:ok, :ok, :ok] = Enum.map(waiters, &Task.await(&1, @timeout))
    assert :ok = RequestCompletion.await(completion, 0)
    assert :ok = RequestCompletion.abort_and_await(completion, 0)
    assert {:error, :closed} = peer_result(peer)
  end

  defp fetch(url, opts \\ []) do
    HTTP.fetch(
      url,
      Keyword.merge(
        [
          http_version: :http1,
          http1_reuse: false,
          tls_backend: :ssl,
          redirect: :manual,
          decode_body: false,
          request_mode: :proxy,
          timeout: @timeout
        ],
        opts
      )
    )
  end

  defp peer(fun) do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

    {:ok, {_, port}} = :inet.sockname(listener)
    owner = self()

    pid =
      spawn(fn ->
        try do
          {:ok, socket} = :gen_tcp.accept(listener, @timeout)

          try do
            send(owner, {:peer_result, self(), fun.(socket, owner)})
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

  defp peer_result(peer) do
    monitor = Process.monitor(peer)

    result =
      receive do
        {:peer_result, ^peer, result} -> result
        {:peer_error, ^peer, error} -> flunk("loopback peer failed: #{error}")
      after
        @timeout -> flunk("loopback peer did not complete")
      end

    assert_receive {:DOWN, ^monitor, :process, ^peer, reason} when reason in [:normal, :noproc],
                   @timeout

    result
  end

  defp recv_head(socket, bytes \\ "") do
    if :binary.match(bytes, "\r\n\r\n") == :nomatch do
      {:ok, chunk} = :gen_tcp.recv(socket, 0, @timeout)
      recv_head(socket, bytes <> chunk)
    else
      bytes
    end
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
end
