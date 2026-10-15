# Independent public-API qualification. Requiring this file with the library flag
# shares only fixture helpers with the disposable empty-continuation diagnostic.
defmodule HTTPFetchPublicProbe do
  @timeout 6_000

  def start_apps do
    for app <- [:http_core, :http_runtime, :http_fetch] do
      {:ok, _} = Application.ensure_all_started(app)
    end

    IO.inspect(
      %{
        http_fetch: Application.spec(:http_fetch, :vsn),
        elixir: System.version(),
        otp: System.otp_release(),
        erts: :erlang.system_info(:version)
      },
      label: "PUBLIC_PROBE_ENV"
    )
  end

  def with_peer(protocol, fun) do
    python = System.get_env("HTTP_FETCH_PEER_PYTHON") || System.find_executable("python3")
    if is_nil(python), do: raise("BLOCKED_ENV: Python h2 peer unavailable")
    script = Path.join(__DIR__, "upstream_peer.py")

    port =
      Port.open({:spawn_executable, python}, [
        :binary,
        :exit_status,
        {:line, 2_000_000},
        args: [script, "--protocol", protocol]
      ])

    Process.put({__MODULE__, port}, [])
    Process.put({:completions, port}, [])

    try do
      ready = event(port, &(&1["event"] == "ready"))

      peer = %{
        port: port,
        ready: ready,
        protocol: protocol,
        scope: "gaoxy-public-#{protocol}-#{System.unique_integer([:positive])}"
      }

      fun.(peer)
    after
      try do
        for completion <- Process.get({:completions, port}, []) do
          :ok = HTTP.RequestCompletion.abort_and_await(completion, 2_000)
        end
      after
        stop_peer(port)
      end
    end
  end

  defp stop_peer(port) do
    command(port, %{"command" => "stop"})
    %{"live_threads" => 0} = stopped = event(port, &(&1["event"] == "stopped"))

    receive do
      {^port, {:exit_status, 0}} -> :ok
      {^port, {:exit_status, status}} -> raise "peer exit #{status}"
    after
      @timeout -> raise "peer shutdown deadline exceeded"
    end

    IO.inspect(stopped, label: "PUBLIC_PEER_STOPPED")
    Process.delete({__MODULE__, port})
    Process.delete({:completions, port})
  end

  def fetch(peer, path, extra \\ []) do
    tls = peer.protocol == "tls"
    scheme = if tls, do: "https", else: "http"
    host = if tls, do: "localhost", else: "127.0.0.1"

    version =
      case peer.protocol do
        "h1" -> :http1
        "h2c" -> :h2c
        "tls" -> :http2
      end

    opts = [
      http_version: version,
      request_mode: :proxy,
      redirect: :manual,
      stream_response: true,
      decode_body: false,
      tls_backend: :ssl,
      timeout: @timeout,
      connect_timeout: 2_000,
      connect_address: {127, 0, 0, 1},
      telemetry: false,
      socket_opts: [send_timeout: 2_000]
    ]

    protocol_opts =
      if version == :http1 do
        [
          http1_reuse: true,
          http1_scope: peer.scope,
          http1_pool_size: 1,
          http1_idle_timeout: 2_000
        ]
      else
        [http2_reuse: true, http2_scope: peer.scope, http2_profile: :native_v1]
      end

    opts = opts ++ protocol_opts

    opts =
      if tls,
        do: Keyword.put(opts, :ssl, cacertfile: peer.ready["ca"], verify: :verify_peer),
        else: opts

    promise =
      HTTP.fetch("#{scheme}://#{host}:#{peer.ready["port"]}#{path}", Keyword.merge(opts, extra))

    completion = HTTP.Promise.completion(promise)
    Process.put({:completions, peer.port}, [completion | Process.get({:completions, peer.port})])
    {promise, completion}
  end

  def command(port, item), do: true = Port.command(port, JSON.encode!(item) <> "\n")

  def event(port, predicate, timeout \\ @timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    event_until(port, predicate, deadline)
  end

  defp event_until(port, predicate, deadline) do
    saved = Process.get({__MODULE__, port}, [])

    case Enum.split_while(saved, &(not predicate.(&1))) do
      {before, [found | rest]} ->
        Process.put({__MODULE__, port}, before ++ rest)
        found

      _ ->
        remaining = max(deadline - System.monotonic_time(:millisecond), 0)

        receive do
          {^port, {:data, {:eol, line}}} ->
            item = JSON.decode!(line)
            if item["event"] == "failure", do: raise("independent peer failed: #{inspect(item)}")
            Process.put({__MODULE__, port}, saved ++ [item])
            event_until(port, predicate, deadline)

          {^port, {:data, {:noeol, _}}} ->
            raise "peer control-line bound exceeded"

          {^port, {:exit_status, status}} ->
            raise "peer exited before barrier: #{status}"
        after
          remaining -> raise "peer barrier deadline exceeded"
        end
    end
  end

  def barrier(peer, type, path) do
    event(peer.port, &(&1["event"] == type and &1["path"] == path))
  end

  def snapshot(peer) do
    command(peer.port, %{"command" => "snapshot"})
    event(peer.port, &(&1["event"] == "snapshot"))["events"]
  end

  def response(promise, expected, expected_trailers \\ []) do
    %HTTP.Response{status: 200, body: stream} = HTTP.Promise.await(promise, @timeout)
    consume(stream, expected, expected_trailers)
  end

  def consume(stream, expected, expected_trailers \\ []) do
    send(stream, {:read_chunk, self(), :ack})
    consume_next(stream, expected, expected_trailers, false)
  end

  defp consume_next(stream, remaining, expected_trailers, seen) do
    receive do
      {:stream_chunk, ^stream, bytes, ack} ->
        size = byte_size(bytes)
        <<^bytes::binary-size(size), rest::binary>> = remaining
        send(stream, {:stream_chunk_ack, ack})
        consume_next(stream, rest, expected_trailers, seen)

      {:stream_trailers, ^stream, %HTTP.Headers{headers: fields}} ->
        false = seen
        ^expected_trailers = fields
        "" = remaining
        consume_next(stream, remaining, expected_trailers, true)

      {:stream_end, ^stream} ->
        "" = remaining
        true = seen or expected_trailers == []
        :ok

      {:stream_error, ^stream, reason} ->
        raise "response stream failed: #{inspect(reason)}"
    after
      @timeout -> raise "response ACK/EOF deadline exceeded"
    end
  end

  def complete(completion) do
    parent = self()

    {pid, monitor} =
      spawn_monitor(fn ->
        send(
          parent,
          {:completion_result, self(), HTTP.RequestCompletion.await(completion, 2_000)}
        )
      end)

    :ok = HTTP.RequestCompletion.await(completion, 2_000)

    receive do
      {:completion_result, ^pid, :ok} -> :ok
    after
      @timeout -> raise "cross-process completion deadline exceeded"
    end

    receive do
      {:DOWN, ^monitor, :process, ^pid, :normal} -> :ok
    after
      @timeout -> raise "completion waiter shutdown deadline exceeded"
    end

    :ok = HTTP.RequestCompletion.await(completion, 0)
  end

  def requests(events), do: Enum.filter(events, &(&1["event"] == "request"))
  def accepts(events), do: Enum.count(events, &(&1["event"] == "accept"))

  def report(name, details),
    do: IO.inspect(Map.merge(%{case: name, result: :pass}, details), label: "PUBLIC_CASE")

  def h1 do
    with_peer("h1", fn peer ->
      for path <- ["/one", "/two"] do
        {promise, completion} = fetch(peer, path)
        response(promise, "ok")
        complete(completion)
      end

      events = snapshot(peer)
      1 = accepts(events)

      [%{"path" => "/one", "connection" => 1}, %{"path" => "/two", "connection" => 1}] =
        requests(events)

      report("h1_sequential_reuse", %{accepts: 1, requests: 2, cross_process_completion: true})
    end)

    with_peer("h1", fn peer ->
      {promise, completion} = fetch(peer, "/stall")
      barrier(peer, "request", "/stall")
      %HTTP.Response{status: 200} = HTTP.Promise.await(promise, @timeout)
      :ok = HTTP.RequestCompletion.abort_and_await(completion, 2_000)
      complete(completion)
      event(peer.port, &(&1["event"] == "closed"))
      events = snapshot(peer)
      1 = accepts(events)
      [%{"path" => "/stall"}] = requests(events)
      report("h1_stalled_cancel_no_replay", %{requests: 1, socket_closed: true})
    end)

    with_peer("h1", fn peer ->
      {promise, completion} = fetch(peer, "/warm")
      response(promise, "ok")
      complete(completion)
      command(peer.port, %{"command" => "close"})
      event(peer.port, &(&1["event"] == "closed"))
      {promise, completion} = fetch(peer, "/stale")
      response(promise, "ok")
      complete(completion)
      events = snapshot(peer)
      2 = accepts(events)

      [%{"path" => "/warm", "connection" => 1}, %{"path" => "/stale", "connection" => 2}] =
        requests(events)

      report("h1_stale_before_write_no_replay", %{accepts: 2, requests: 2})
    end)

    upload("h1", "/trailers", "firstlast", [{"x-upload", "first"}, {"x-upload", "second"}])
  end

  def h2(protocol) do
    with_peer(protocol, fn peer ->
      {a, ca} = fetch(peer, "/a")
      %{"connection" => 1, "stream" => sa} = barrier(peer, "request", "/a")
      %HTTP.Response{status: 200} = HTTP.Promise.await(a, @timeout)
      {b, cb} = fetch(peer, "/b")
      %{"connection" => 1, "stream" => sb} = barrier(peer, "request", "/b")
      true = sa != sb
      %HTTP.Response{status: 200} = rb = HTTP.Promise.await(b, @timeout)
      :ok = HTTP.RequestCompletion.abort_and_await(ca, 2_000)
      complete(ca)
      %{"connection" => 1, "stream" => ^sa} = barrier(peer, "reset", "/a")
      command(peer.port, %{"command" => "finish", "path" => "/b", "body" => "body-B"})
      consume(rb.body, "body-B")
      complete(cb)
      {c, cc} = fetch(peer, "/c")
      response(c, "ok")
      complete(cc)
      events = snapshot(peer)
      1 = accepts(events)

      [
        %{"path" => "/a", "connection" => 1},
        %{"path" => "/b", "connection" => 1},
        %{"path" => "/c", "connection" => 1}
      ] = requests(events)

      report("#{protocol}_live_sibling_cancel_reuse", %{
        accepts: 1,
        requests: 3,
        streams: [sa, sb],
        reset: true
      })
    end)

    upload(protocol, "/upload", "firstlast", [{"x-upload", "first"}, {"x-upload", "second"}])
    upload(protocol, "/upload-empty", "", [{"x-upload", "empty"}])

    upload(protocol, "/upload-split", "data", [
      {"x-upload", String.duplicate("0123456789abcdef", 2_000)}
    ])

    early(protocol)

    with_peer(protocol, fn peer ->
      {promise, completion} = fetch(peer, "/goaway")
      barrier(peer, "request", "/goaway")
      command(peer.port, %{"command" => "goaway", "path" => "/goaway"})
      {:error, reason} = HTTP.Promise.await(promise, @timeout)
      complete(completion)
      events = snapshot(peer)
      1 = accepts(events)
      [%{"path" => "/goaway"}] = requests(events)
      report("#{protocol}_goaway_no_replay", %{requests: 1, error: reason})
    end)
  end

  def upload(protocol, path, bytes, trailers) do
    with_peer(protocol, fn peer ->
      {:ok, upload} = HTTP.Stream.start_link(0)
      Process.unlink(upload)
      monitor = Process.monitor(upload)

      {promise, completion} =
        fetch(peer, path,
          method: :post,
          body: upload,
          duplex: :half,
          headers: if(protocol == "h1", do: [{"trailer", "x-upload"}], else: [])
        )

      barrier(peer, "request", path)
      if bytes != "", do: :ok = HTTP.Stream.chunk(upload, bytes, 2_000)
      :ok = HTTP.Stream.finish(upload, trailers)
      wire = barrier(peer, "upload_end", path)
      ^bytes = wire["body"]

      if protocol == "h1" do
        ^trailers = Enum.map(wire["trailers"], &List.to_tuple/1)
      else
        fields = barrier(peer, "trailers", path)
        true = fields["end_stream"]
        ^trailers = Enum.map(fields["headers"], &List.to_tuple/1)
      end

      %HTTP.Response{status: 200, body: response_stream} = HTTP.Promise.await(promise, @timeout)
      {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
      consume(response_stream, "ok", [{"x-result", "first"}, {"x-result", "second"}])
      complete(completion)

      receive do
        {:DOWN, ^monitor, :process, ^upload, :normal} -> :ok
      after
        @timeout -> raise "upload did not terminate"
      end

      events = snapshot(peer)
      [_] = requests(events)

      if path == "/upload-split" do
        true = Enum.any?(events, &(&1["event"] == "header_frame" and &1["type"] == 9))
      end

      report("#{protocol}#{path}", %{
        requests: 1,
        upload_bytes: byte_size(bytes),
        trailer_fields: length(trailers),
        ordered_duplicate_response_trailers: true,
        split_header_block: path == "/upload-split"
      })
    end)
  end

  def early(protocol) do
    with_peer(protocol, fn peer ->
      {sibling, cs} = fetch(peer, "/sibling")
      barrier(peer, "request", "/sibling")
      %HTTP.Response{status: 200} = rs = HTTP.Promise.await(sibling, @timeout)
      {:ok, upload} = HTTP.Stream.start_link(0)
      Process.unlink(upload)
      upload_monitor = Process.monitor(upload)
      {promise, completion} = fetch(peer, "/early", method: :post, body: upload, duplex: :half)
      barrier(peer, "request", "/early")

      {producer, producer_monitor} =
        spawn_monitor(fn ->
          Enum.reduce_while(1..16, :ok, fn _, :ok ->
            case HTTP.Stream.chunk(upload, String.duplicate("x", 65_536), 3_000) do
              :ok -> {:cont, :ok}
              {:error, _} -> {:halt, :stopped}
            end
          end)
        end)

      %{"bytes" => 16} = barrier(peer, "data", "/early")
      :ok = HTTP.Stream.finish(upload, [{"x-unsent", "forbidden-late-write"}])

      command(peer.port, %{
        "command" => "finish",
        "path" => "/early",
        "body" => "early",
        "early" => true
      })

      %HTTP.Response{status: 413} = HTTP.Promise.await(promise, @timeout)
      :ok = HTTP.RequestCompletion.abort_and_await(completion, 2_000)
      complete(completion)
      barrier(peer, "reset", "/early")

      for {pid, monitor} <- [{producer, producer_monitor}, {upload, upload_monitor}] do
        receive do
          {:DOWN, ^monitor, :process, ^pid, _reason} -> :ok
        after
          @timeout -> raise "early response producer/stream did not terminate"
        end
      end

      command(peer.port, %{"command" => "finish", "path" => "/sibling", "body" => "sibling-live"})
      consume(rs.body, "sibling-live")
      complete(cs)
      events = snapshot(peer)
      1 = accepts(events)
      [%{"path" => "/sibling"}, %{"path" => "/early"}] = requests(events)
      false = Enum.any?(events, &(&1["event"] == "trailers" and &1["path"] == "/early"))

      report("#{protocol}_early_final_flow_barrier", %{
        window_bytes: 16,
        requests: 2,
        producer_down: true,
        sibling_live: true,
        late_trailers: 0
      })
    end)
  end

  def run do
    start_apps()
    h1()
    h2("tls")
    h2("h2c")

    IO.puts(
      "PUBLIC_PROBE_PASS cases=16; request qualification only; managed retirement BLOCKED #78"
    )
  end
end

if System.get_env("HTTP_FETCH_PROBE_LIBRARY") != "1", do: HTTPFetchPublicProbe.run()
