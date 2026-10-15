ExUnit.start(seed: 33011, max_cases: 1)

defmodule GaoxyPublicPreHeadCancelRepeatProbe do
  use ExUnit.Case, async: false
  alias HTTP.{Promise, RequestCompletion}
  @timeout 3_000

  # Exactly32 distinct tests; retain every result and all failures. No retry-to-green.
  for index <- 1..32 do
    @probe_index index
    test "public pre-head cancellation round #{index}" do
      {url, peer} = peer(fn socket, owner ->
        recv_head(socket)
        send(owner, {:request_headers, self()})
        :gen_tcp.recv(socket, 0, @timeout)
      end)
      promise = fetch(url)
      completion = Promise.completion(promise)
      headers = receive do
        {:request_headers, ^peer} -> :received
      after
        @timeout -> :request_headers_timeout
      end
      before_abort = capture(fn -> RequestCompletion.await(completion, 0) end)
      abort = capture(fn -> RequestCompletion.abort_and_await(completion, @timeout) end)
      promise_result = capture(fn -> Promise.await(promise, @timeout) end)

      # Capture both peer result and real owned-peer DOWN even if Promise is unexpected.
      peer_monitor = Process.monitor(peer)
      peer_terminal = receive do
        {:peer_result, ^peer, value} -> value
        {:peer_error, ^peer, error} -> {:peer_error, error}
      after
        @timeout -> :peer_result_timeout
      end
      peer_down = receive do
        {:DOWN, ^peer_monitor, :process, ^peer, reason} -> reason
      after
        @timeout -> :peer_down_timeout
      end
      Process.demonitor(peer_monitor, [:flush])
      repeated = capture(fn -> RequestCompletion.abort_and_await(completion, 0) end)
      row = %{round: @probe_index, request_headers: inspect(headers),
        cleanup_before_abort: inspect(before_abort), abort_and_await: inspect(abort),
        promise: inspect(promise_result), peer_result: inspect(peer_terminal),
        peer_down: inspect(peer_down), repeated_original_completion: inspect(repeated)}
      IO.puts("PUBLIC_CANCEL_REPEAT " <> JSON.encode!(row))

      assert headers == :received
      assert {:error, :cleanup_pending} = before_abort
      assert :ok = abort
      assert {:error, :aborted} = promise_result
      assert {:error, :closed} = peer_terminal
      assert peer_down in [:normal, :noproc]
      assert :ok = repeated
    end
  end

  defp capture(fun) do
    try do
      fun.()
    rescue
      error -> {:exception, error.__struct__, Exception.message(error)}
    catch
      kind, reason -> {:caught, kind, reason}
    end
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
