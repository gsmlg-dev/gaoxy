defmodule Gaoxy.UpstreamPublicProbe do
  import ExUnit.Assertions

  @deadline 3_000

  def emit(event, fields \\ %{}) do
    IO.puts("GAOXY_UPSTREAM_PROBE " <> JSON.encode!(Map.put(fields, "event", event)))
  end

  def barrier(name, fields \\ %{}) do
    emit("barrier", Map.put(fields, "name", name))
    assert IO.gets("") == "continue\n"
  end

  def fetch(origin, path, extra \\ []) do
    url = System.fetch_env!("GAOXY_UPSTREAM_URL_" <> String.upcase(origin))
    ca = System.fetch_env!("GAOXY_UPSTREAM_CA_" <> String.upcase(origin))

    opts = [
      http_version: :http3,
      http3_reuse: false,
      redirect: :manual,
      request_mode: :proxy,
      stream_response: true,
      decode_body: false,
      ssl: [cacertfile: ca, verify: :verify_peer],
      timeout: @deadline
    ]

    promise = HTTP.fetch(url <> path, Keyword.merge(opts, extra))
    {promise, Process.monitor(promise.task.pid)}
  end

  def down(pid, monitor) do
    receive do
      {:DOWN, ^monitor, :process, ^pid, reason} -> inspect(reason)
    after
      @deadline -> flunk("public process failed to terminate: #{inspect(pid)}")
    end
  end

  def await({promise, monitor}) do
    result = HTTP.Promise.await(promise, @deadline + 1_000)
    reason = down(promise.task.pid, monitor)
    assert reason == ":normal"
    result
  end

  def response({promise, monitor}) do
    assert %HTTP.Response{status: 200, http_version: :http3, body: stream} =
             await({promise, monitor})

    assert is_pid(stream)
    {stream, Process.monitor(stream)}
  end

  def read(stream, chunks \\ [], trailers \\ []) do
    receive do
      {:stream_chunk, ^stream, bytes, ref} ->
        send(stream, {:stream_chunk_ack, ref})
        read(stream, [bytes | chunks], trailers)

      {:stream_trailers, ^stream, fields} ->
        read(stream, chunks, fields.headers)

      {:stream_end, ^stream} ->
        {IO.iodata_to_binary(Enum.reverse(chunks)), trailers}

      {:stream_error, ^stream, reason} ->
        {:error, reason}
    after
      @deadline -> flunk("response stream terminal event missing")
    end
  end

  def ordinary(origin) do
    {stream, monitor} = response(fetch(origin, "/ordinary"))
    send(stream, {:read_chunk, self(), :ack})

    receive do
      {:stream_chunk, ^stream, "ordinary-", ref} ->
        send(stream, {:stream_chunk_ack, ref})
    after
      @deadline -> flunk("progressive response chunk missing")
    end

    barrier("ordinary_progress", %{"origin" => origin, "path" => "/ordinary"})
    assert {"response", [{"x-check", "one"}, {"x-check", "two"}]} = read(stream)
    assert down(stream, monitor) == ":normal"
    emit("check", %{"name" => "ordinary_stream_" <> origin, "status" => "PASS"})
  end

  def upload do
    {:ok, source} = HTTP.Stream.start_link(0)
    monitor = Process.monitor(source)
    promise = fetch("a", "/upload", method: :post, body: source, duplex: :half)
    assert :ok = HTTP.Stream.chunk(source, "abc", 1_000)
    barrier("upload_progress", %{"origin" => "a", "path" => "/upload"})
    assert :ok = HTTP.Stream.chunk(source, "def", 1_000)
    assert :ok = HTTP.Stream.finish(source)
    {stream, response_monitor} = response(promise)
    send(stream, {:read_chunk, self(), :ack})
    assert {"abcdef", []} = read(stream)
    assert down(stream, response_monitor) == ":normal"
    assert down(source, monitor) == ":normal"
    emit("check", %{"name" => "ordinary_upload", "status" => "PASS"})
  end

  def trailers(zero?) do
    path = if zero?, do: "/echo-zero", else: "/echo-three"
    {:ok, source} = HTTP.Stream.start_link(0)
    monitor = Process.monitor(source)

    # H3 permits trailing HEADERS without a Trailer declaration. The declared
    # form's separate pre-wire failure remains in run-1791792452444772174.
    promise = fetch("a", path, method: :post, body: source, duplex: :half)

    if not zero?, do: assert(:ok = HTTP.Stream.chunk(source, "abc", 1_000))
    barrier("trailer_before_finish", %{"origin" => "a", "path" => path, "zero" => zero?})
    # TODO(upstream): gsmlg-dev/http_fetch#101
    assert :ok = HTTP.Stream.finish(source, [{"x-check", "one"}, {"x-check", "two"}])
    result = await(promise)
    assert result == {:error, :request_trailers_unsupported}
    assert down(source, monitor) == ":normal"

    emit("check", %{
      "name" => if(zero?, do: "request_trailers_zero", else: "request_trailers_three"),
      "status" => "BLOCKED",
      "result" => inspect(result),
      "finish_return" => ":ok",
      "public_task_down" => true,
      "upload_stream_down" => true
    })
  end

  def cancel_headers do
    controller = HTTP.AbortController.new()
    controller_monitor = Process.monitor(controller)
    {promise, monitor} = fetch("a", "/delayed-headers", signal: controller)

    result = HTTP.RequestCompletion.await(HTTP.Promise.completion(promise), 0)
    assert result == {:error, {:unsupported_completion, :http_version}}
    barrier("pending_headers", %{"origin" => "a", "path" => "/delayed-headers"})
    assert :ok = HTTP.AbortController.abort(controller)
    assert {:error, :aborted} = await({promise, monitor})
    :ok = Agent.stop(controller)
    assert down(controller, controller_monitor) == ":normal"

    emit("check", %{
      "name" => "abort_pending_headers",
      "status" => "PASS",
      "completion_diagnostic" => inspect(result),
      "public_task_down" => true,
      "controller_down" => true
    })
  end

  def cancel_response do
    controller = HTTP.AbortController.new()
    controller_monitor = Process.monitor(controller)
    {stream, monitor} = response(fetch("a", "/stalled-response", signal: controller))
    send(stream, {:read_chunk, self(), :ack})

    receive do
      {:stream_chunk, ^stream, "unacknowledged", _ref} -> :ok
    after
      @deadline -> flunk("unacknowledged response chunk missing")
    end

    assert :ok = HTTP.AbortController.abort(controller)
    terminal = read(stream)
    assert terminal == {:error, :aborted}
    assert down(stream, monitor) == ":normal"
    :ok = Agent.stop(controller)
    assert down(controller, controller_monitor) == ":normal"

    emit("check", %{
      "name" => "abort_unacknowledged_response",
      "status" => "PASS",
      "result" => inspect(terminal),
      "response_stream_down" => true,
      "controller_down" => true
    })
  end

  def run do
    {:ok, _} = Application.ensure_all_started(:http_fetch)

    emit("environment", %{
      "elixir" => System.version(),
      "otp" => List.to_string(:erlang.system_info(:otp_release)),
      "http_fetch" => to_string(Application.spec(:http_fetch, :vsn)),
      "public_session_functions" =>
        Enum.map(QuicHttp3.Session.__info__(:functions), fn {name, arity} ->
          Atom.to_string(name) <> "/" <> Integer.to_string(arity)
        end)
    })

    ordinary("a")
    ordinary("b")
    upload()
    trailers(false)
    trailers(true)
    cancel_headers()
    cancel_response()
    barrier("final_snapshot")

    emit("done", %{
      "checks" => 7,
      "status" => "BLOCKED",
      "reason" => "required ordered request trailers unsupported in pinned HTTP Fetch"
    })
  end
end

Gaoxy.UpstreamPublicProbe.run()
