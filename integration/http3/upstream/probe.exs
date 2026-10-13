defmodule Gaoxy.UpstreamPublicProbe do
  import ExUnit.Assertions

  @deadline 5_000
  @trailers [{"x-check", "one"}, {"x-check", "two"}]

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
    assert %HTTP.Response{status: 200, http_version: :http3, body: stream, headers: fields} =
             await({promise, monitor})

    assert Enum.filter(fields.headers, fn {name, _} -> name == "x-repeat" end) ==
             [{"x-repeat", "one"}, {"x-repeat", "two"}]

    assert is_pid(stream)
    {stream, Process.monitor(stream)}
  end

  def read(stream, chunks \\ [], trailers \\ [], deadline \\ nil) do
    deadline = deadline || System.monotonic_time(:millisecond) + @deadline
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:stream_chunk, ^stream, bytes, ref} ->
        send(stream, {:stream_chunk_ack, ref})
        read(stream, [bytes | chunks], trailers, deadline)

      {:stream_trailers, ^stream, fields} ->
        read(stream, chunks, fields.headers, deadline)

      {:stream_end, ^stream} ->
        {IO.iodata_to_binary(Enum.reverse(chunks)), trailers}

      {:stream_error, ^stream, reason} ->
        {:error, reason}
    after
      remaining -> flunk("response stream terminal event missing")
    end
  end

  def ordinary(origin) do
    promise = fetch(origin, "/ordinary")
    {stream, monitor} = response(promise)
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
    cleanup(promise, "/ordinary", origin)
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
    cleanup(promise, "/upload")
    emit("check", %{"name" => "ordinary_upload", "status" => "PASS"})
  end

  def trailers(zero?, declared?) do
    suffix = if declared?, do: "declared", else: "undeclared"
    size = if zero?, do: "zero", else: "three"
    path = "/echo-" <> size <> "-" <> suffix
    {:ok, source} = HTTP.Stream.start_link(0)
    monitor = Process.monitor(source)
    headers = if declared?, do: [{"trailer", "x-check"}], else: []
    promise = fetch("a", path, method: :post, body: source, duplex: :half, headers: headers)
    if not zero?, do: assert(:ok = HTTP.Stream.chunk(source, "abc", 1_000))
    barrier("trailer_before_finish", %{"origin" => "a", "path" => path, "zero" => zero?})
    assert :ok = HTTP.Stream.finish(source, @trailers)
    {stream, response_monitor} = response(promise)
    send(stream, {:read_chunk, self(), :ack})
    assert {"echo-finished", @trailers} = read(stream)
    assert down(stream, response_monitor) == ":normal"
    assert down(source, monitor) == ":normal"
    cleanup(promise, path)

    emit("check", %{
      "name" => "request_trailers_" <> size <> "_" <> suffix,
      "path" => path,
      "status" => "PASS",
      "finish_return" => ":ok",
      "public_task_down" => true,
      "upload_stream_down" => true,
      "response_stream_down" => true
    })
  end

  def cleanup({promise, _}, path, origin \\ "a") do
    result = HTTP.RequestCompletion.await(HTTP.Promise.completion(promise), @deadline)

    emit("normal_completion_result", %{
      "path" => path,
      "origin" => origin,
      "result" => inspect(result)
    })
  end

  def negative(name, extra, url_override \\ nil) do
    barrier("negative_before", %{"case" => name})
    old_url = System.fetch_env!("GAOXY_UPSTREAM_URL_A")
    if url_override, do: System.put_env("GAOXY_UPSTREAM_URL_A", url_override)

    result =
      try do
        await(fetch("a", "/negative-" <> name, extra))
      rescue
        error in ArgumentError -> {:argument_error, Exception.message(error)}
      after
        System.put_env("GAOXY_UPSTREAM_URL_A", old_url)
      end

    case name do
      "connect_address" ->
        assert result ==
                 {:argument_error,
                  "connect_address is unsupported with HTTP/3, Unix sockets or proxies"}

      "absent_trust" ->
        assert result == {:error, :ca_trust_required}

      "wrong_ca" ->
        assert result ==
                 {:error,
                  {:http3_not_established,
                   {:owner_down, {:shutdown, {:tls, :tls, :unknown_ca, :path_validation_failed}}}}}

      "wrong_hostname" ->
        assert result ==
                 {:error,
                  {:http3_not_established,
                   {:owner_down,
                    {:shutdown, {:tls, :tls, :certificate_unknown, :hostname_mismatch}}}}}
    end

    barrier("negative_after", %{"case" => name, "result" => inspect(result)})
    emit("check", %{"name" => name, "status" => "PASS", "result" => inspect(result)})
  end

  def cancel_headers do
    controller = HTTP.AbortController.new()
    controller_monitor = Process.monitor(controller)
    {promise, monitor} = fetch("a", "/delayed-headers", signal: controller)

    completion = HTTP.Promise.completion(promise)
    result = HTTP.RequestCompletion.await(completion, 0)
    emit("completion_diagnostic", %{"result" => inspect(result)})
    barrier("pending_headers", %{"origin" => "a", "path" => "/delayed-headers"})
    assert :ok = HTTP.AbortController.abort(controller)
    assert {:error, :aborted} = await({promise, monitor})
    cleanup = HTTP.RequestCompletion.await(completion, @deadline)
    emit("cleanup_result", %{"path" => "/delayed-headers", "result" => inspect(cleanup)})
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
    {promise, promise_monitor} = fetch("a", "/stalled-response", signal: controller)
    completion = HTTP.Promise.completion(promise)
    {stream, monitor} = response({promise, promise_monitor})
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

    emit("cleanup_result", %{
      "path" => "/stalled-response",
      "result" => inspect(HTTP.RequestCompletion.await(completion, @deadline))
    })

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

  def cancel_upload do
    controller = HTTP.AbortController.new()
    controller_monitor = Process.monitor(controller)
    {:ok, source} = HTTP.Stream.start_link(0)
    source_monitor = Process.monitor(source)

    {promise, promise_monitor} =
      fetch("a", "/blocked-upload",
        method: :post,
        body: source,
        duplex: :half,
        signal: controller
      )

    barrier("pause_upload", %{"origin" => "a", "path" => "/blocked-upload"})

    producer =
      Task.async(fn ->
        Enum.reduce_while(1..128, :ok, fn index, _ ->
          case HTTP.Stream.chunk(source, :binary.copy("x", 16_384), 300) do
            :ok -> {:cont, :ok}
            error -> {:halt, {:blocked, index, error}}
          end
        end)
      end)

    assert {:blocked, index, {:error, :timeout}} = Task.await(producer, @deadline)

    emit("blocked_write", %{
      "index" => index,
      "chunk_bytes" => 16_384,
      "result" => "{:error, :timeout}"
    })

    barrier("blocked_upload", %{"origin" => "a", "path" => "/blocked-upload"})
    assert :ok = HTTP.AbortController.abort(controller)
    assert {:error, :aborted} = await({promise, promise_monitor})
    assert down(source, source_monitor) == ":normal"

    emit("cleanup_result", %{
      "path" => "/blocked-upload",
      "result" =>
        inspect(HTTP.RequestCompletion.await(HTTP.Promise.completion(promise), @deadline))
    })

    :ok = Agent.stop(controller)
    assert down(controller, controller_monitor) == ":normal"
    barrier("resume_upload", %{"origin" => "a", "path" => "/blocked-upload"})

    emit("check", %{
      "name" => "abort_blocked_upload",
      "status" => "PASS",
      "public_task_down" => true,
      "upload_stream_down" => true,
      "producer_down" => true
    })
  end

  def owner_loss do
    parent = self()

    {owner, owner_monitor} =
      spawn_monitor(fn ->
        {promise, promise_monitor} = fetch("a", "/owner-loss")
        {stream, monitor} = response({promise, promise_monitor})
        send(stream, {:read_chunk, self(), :ack})

        receive do
          {:stream_chunk, ^stream, "unacknowledged", _ref} ->
            send(parent, {:owned_response, self(), stream, HTTP.Promise.completion(promise)})
        after
          @deadline -> flunk("owner-loss response missing")
        end

        receive do
          :lose_owner -> :ok
        after
          @deadline -> flunk("owner-loss control missing")
        end

        Process.demonitor(monitor, [:flush])
      end)

    receive do
      {:owned_response, ^owner, stream, completion} ->
        monitor = Process.monitor(stream)
        barrier("owner_loss", %{"origin" => "a", "path" => "/owner-loss"})
        send(owner, :lose_owner)
        assert down(owner, owner_monitor) == ":normal"
        assert down(stream, monitor) == ":normal"

        emit("cleanup_result", %{
          "path" => "/owner-loss",
          "result" => inspect(HTTP.RequestCompletion.await(completion, @deadline))
        })
    after
      @deadline -> flunk("downstream owner response missing")
    end

    emit("check", %{
      "name" => "downstream_owner_loss",
      "status" => "PASS",
      "owner_down" => true,
      "response_stream_down" => true
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
    for zero? <- [false, true], declared? <- [false, true], do: trailers(zero?, declared?)

    negative("wrong_ca",
      ssl: [cacertfile: System.fetch_env!("GAOXY_UPSTREAM_CA_B"), verify: :verify_peer]
    )

    url = System.fetch_env!("GAOXY_UPSTREAM_URL_A") |> String.replace("localhost", "127.0.0.1")
    negative("wrong_hostname", [], url)
    negative("absent_trust", ssl: [])
    negative("connect_address", connect_address: {127, 0, 0, 1})
    cancel_headers()
    cancel_response()
    cancel_upload()
    owner_loss()
    barrier("final_snapshot")

    emit("done", %{
      "checks" => 15,
      "status" => "PASS"
    })
  end
end

Gaoxy.UpstreamPublicProbe.run()
