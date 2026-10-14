# Qualification-only public H2 error retention; run in a dedicated parent-owned VM.
defmodule HTTPFetchH20214FunctionalSupplement do
  alias HTTP.{AbortController, Promise, RequestCompletion, Response}

  @design "docs/designs/m3-managed-h2-preparation.md"
  @design_hash "1b4e9e24a75aa44529074fba4fa2f3f3e29c4c9f97e5870d5ca309f40ecd1865"
  @preserved_sources %{
    "integration/http_fetch_contract/h2_functional_supplement.exs" =>
      "89cd7237a5864d86e9ffbd7f5f323a275ec9cad1d36cd4f03fc8881842cccbef",
    "integration/http_fetch_contract/h2_functional_supplement_peer.py" =>
      "b1bcff8b19eba8c7bccb315ecd3ee66be860816128e76b2a15b5a36e0968f170",
    "integration/http_fetch_contract/managed_transport_probe.exs" =>
      "0e266d6c278682e23d2611d053c8d155bb19d4354c6a5dfa2f411dc177c49520",
    "integration/http_fetch_contract/pooled_completion_probe.exs" =>
      "f681723ff58754cb6169d0b42fb681a8439eeaa6c7ec7e94c752894405ce1e30",
    "integration/http_fetch_contract/upstream_peer.py" =>
      "f2e40b0e72362f06b4c933b14f45d49e768b2133bee4281c4241bbd122d9b95f",
    "integration/http_fetch_contract/managed_peer.py" =>
      "319e9c9f2832ddf2ab9cc84aedd519bfe33f36e2152d24bb47bf5fcde8169d79",
    "docs/plans/m3-h2-0.21.3-functional-supplement.md" =>
      "25fdfb876f7e83f65b97414816a6a82c258ec8f789f0d0eb7f4e07f627ad7270"
  }
  @packages ~w(http_core http_runtime http_fetch http_web_socket ex_ssl elixir_quic elixir_quic_http3)
  @cases [
    {"TLS98_LATE", "tls", :late},
    {"TLS98_EARLY", "tls", :early},
    {"TLS100_ABORT", "tls", :abort},
    {"TLS100_DEADLINE", "tls", :deadline},
    {"H2C98_LATE", "h2c", :late},
    {"H2C98_EARLY", "h2c", :early},
    {"H2C100_ABORT", "h2c", :abort},
    {"H2C100_DEADLINE", "h2c", :deadline}
  ]

  def run do
    ["--evidence", directory] = System.argv()
    File.mkdir_p!(Path.dirname(directory))
    File.mkdir!(directory)
    Process.flag(:trap_exit, true)
    Process.put({__MODULE__, :results}, [])
    before = source_hashes()

    result =
      capture(fn ->
        @design_hash = before[@design]
        verify_design_sources!()

        for app <- [:http_core, :http_runtime, :http_fetch] do
          {:ok, _} = Application.ensure_all_started(app)
        end

        versions =
          Map.new(@packages, fn package ->
            app = String.to_atom(package)
            loaded = Application.load(app)
            true = loaded in [:ok, {:error, {:already_loaded, app}}]
            "0.21.4" = version = to_string(Application.spec(app, :vsn))
            {package, version}
          end)

        60_000 = HTTP.Config.streaming_timeout()

        identity = %{
          cohort: versions,
          elixir: System.version(),
          otp: System.otp_release(),
          erts: to_string(:erlang.system_info(:version)),
          streaming_timeout_ms: HTTP.Config.streaming_timeout(),
          loaded_modules: loaded_modules(),
          parent_native_identity_receipt_required: true
        }

        write(directory, "identity.json", identity)
        Process.put({__MODULE__, :identity}, identity)
        invocation = "#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"

        Enum.each(@cases, fn registered ->
          outcome = run_case(registered, invocation)
          results = Process.get({__MODULE__, :results}) ++ [outcome]
          Process.put({__MODULE__, :results}, results)
          write(directory, outcome.case <> ".json", outcome)
          IO.puts("H2_FUNCTIONAL_CASE " <> JSON.encode!(outcome))
          if outcome.status != "PASS", do: raise("case failed: #{outcome.case}")
        end)

        :ok
      end)

    after_sources = source_hashes()
    results = Process.get({__MODULE__, :results})
    failed = Enum.count(results, &(&1.status != "PASS"))
    shutdowns = Enum.count(results, & &1.peer_shutdown)
    stable = before == after_sources
    python = Process.get({__MODULE__, :python_identity})
    python_stable = is_map(python) and python["python_sha256"] == hash(python["python"])

    passed =
      result == {:ok, :ok} and stable and python_stable and
        length(results) == 8 and failed == 0 and shutdowns == 8

    blocked_env =
      String.contains?(inspect(result), "BLOCKED_ENV") or
        Enum.any?(results, &(&1.status == "BLOCKED_ENV"))

    blocked_handoff = Enum.any?(results, &(&1.status == "BLOCKED_HANDOFF"))

    summary = %{
      status:
        cond do
          passed -> "PASS"
          blocked_handoff -> "BLOCKED_HANDOFF"
          blocked_env -> "BLOCKED_ENV"
          true -> "FAIL"
        end,
      executed: length(results),
      tls: Enum.count(results, &(&1.protocol == "tls")),
      h2c: Enum.count(results, &(&1.protocol == "h2c")),
      skipped: 0,
      failed: failed,
      peer_shutdowns: shutdowns,
      source_stable: stable,
      python_identity: python,
      python_stable: python_stable,
      invocation_result: inspect(result),
      argv: System.argv(),
      environment:
        Map.new(~w(ERL_FLAGS MIX_ENV HTTP_FETCH_PEER_PYTHON), &{&1, System.get_env(&1)}),
      source_before: before,
      source_after: after_sources,
      cases: Enum.map(results, & &1.case),
      exit: if(passed, do: 0, else: 1),
      qualification:
        "selected public functional cases; no managed accounting or full M3 acceptance"
    }

    write(directory, "results.json", summary)
    IO.puts("H2_FUNCTIONAL_SUMMARY " <> JSON.encode!(summary))
    if not passed, do: System.halt(1)
    :ok
  end

  defp run_case({name, protocol, kind}, invocation) do
    start = now()

    Process.put({__MODULE__, :case}, %{
      name: name,
      protocol: protocol,
      kind: kind,
      start: start,
      ready_deadline: start + 45_000,
      startup_cleanup_deadline: start + 60_000,
      oracle_deadline: nil,
      cleanup_deadline: nil,
      port: nil,
      port_monitor: nil,
      port_exit: nil,
      port_down: nil,
      ready: nil,
      stream: nil,
      stream_monitor: nil,
      stream_down: nil,
      controller: nil,
      controller_monitor: nil,
      controller_down: nil,
      promise: nil,
      promise_await: :unawaited,
      completion: nil,
      failure_completion: nil,
      reader_registered: false,
      jobs: [],
      controls: [],
      events: [],
      queue: [],
      operations: [],
      forced: [],
      peer_shutdown: false
    })

    primary =
      capture(fn ->
        python = System.get_env("HTTP_FETCH_PEER_PYTHON") || System.find_executable("python3")
        if is_nil(python), do: raise("BLOCKED_ENV: Python peer unavailable")

        port =
          Port.open({:spawn_executable, python}, [
            :binary,
            :exit_status,
            {:line, 4097},
            args: [
              "-B",
              Path.join(__DIR__, "h2_functional_supplement_peer.py"),
              "--protocol",
              protocol
            ]
          ])

        update(%{port: port, port_monitor: Port.monitor(port), os_pid: Port.info(port, :os_pid)})
        ready = event("ready", state().ready_deadline)
        ^protocol = ready["protocol"]
        true = is_integer(ready["port"]) and ready["port"] > 0

        %{"h2" => "4.3.0", "hpack" => "4.1.0", "hyperframe" => "6.1.0"} =
          ready["identity"]["packages"]

        python_hash = hash(ready["identity"]["python"])
        ^python_hash = ready["identity"]["python_sha256"]

        python =
          Map.take(
            ready["identity"],
            ~w(python python_sha256 python_version packages python_openssl)
          )

        if previous = Process.get({__MODULE__, :python_identity}), do: true = previous == python
        Process.put({__MODULE__, :python_identity}, python)
        update(%{ready: ready})

        if kind in [:abort, :deadline] do
          controller = AbortController.new()
          update(%{controller: controller, controller_monitor: Process.monitor(controller)})
        end

        t0 = now()
        update(%{t0: t0, oracle_deadline: t0 + 10_000, cleanup_deadline: t0 + 15_000})
        opts = options(protocol, kind, invocation <> "-" <> name, ready)
        scheme = if protocol == "tls", do: "https", else: "http"
        promise = HTTP.fetch("#{scheme}://127.0.0.1:#{ready["port"]}/target", opts)
        update(%{promise: promise, options: inspect(opts)})
        completion = Promise.completion(promise)
        update(%{completion: completion})
        deadline = state().oracle_deadline

        if kind in [:abort, :deadline] do
          {:error, {:unsupported_completion, :redirect}} =
            observe(
              "unsupported_completion",
              deadline,
              0,
              &RequestCompletion.await(completion, &1)
            )
        end

        %Response{status: 200, http_version: :http2, body: stream} =
          observe("response", deadline, 2_000, &await_response/1)

        true = is_pid(stream)
        %{"connection" => 1} = event("accept", capped(deadline))
        request = event("request", capped(deadline))
        %{"connection" => 1, "end_stream" => true, "upload_bytes" => 0} = request
        sid = request["stream"]
        true = is_integer(sid) and sid > 0
        update(%{sid: sid})

        if protocol == "tls" do
          %{"connection" => 1, "alpn" => "h2"} = event("tls", capped(deadline))
        end

        if kind == :early do
          register_reader()
          command("reader_sentinel")
          wire = event("reader_sentinel", capped(deadline))
          expected_wire = frame_hex(0, 0, sid, "r")

          %{
            "connection" => 1,
            "stream" => ^sid,
            "wire_hex" => ^expected_wire,
            "successful_send" => true
          } = wire

          receive do
            {:stream_chunk, ^stream, "r", ref} when is_reference(ref) ->
              send(stream, {:stream_chunk_ack, ref})
              operation("reader_attached_and_sentinel_acked", :ok, deadline)
          after
            budget(deadline, 2_000) -> raise "sentinel reader barrier failed"
          end
        end

        if kind in [:early, :late] do
          command("malformed_trailers")
          expected_wire = frame_hex(1, 4, sid, <<0, 1, ?x, 1, ?v>>)

          %{
            "connection" => 1,
            "stream" => ^sid,
            "wire_hex" => ^expected_wire,
            "successful_send" => true
          } = event("malformed_trailers", capped(deadline))
        end

        if kind == :abort do
          :ok =
            observe("abort", deadline, 2_000, fn timeout ->
              abort_bounded(state().controller, now() + timeout)
            end)
        end

        reset_deadline = if kind == :deadline, do: deadline, else: capped(deadline)
        reset_code = if kind in [:early, :late], do: 1, else: 8

        %{"connection" => 1, "stream" => ^sid, "code" => ^reset_code} =
          event("reset", reset_deadline)

        operation("matching_peer_reset_before_late_read", reset_code, deadline)

        if kind == :late do
          {:error, :cleanup_pending} =
            observe(
              "original_completion_before_reader",
              deadline,
              0,
              &RequestCompletion.await(completion, &1)
            )
        end

        if kind != :early, do: register_reader()

        reason =
          if kind in [:early, :late],
            do: :invalid_headers_transition,
            else: if(kind == :abort, do: :aborted, else: :request_timeout)

        receive do
          {:stream_error, ^stream, ^reason} -> operation("exact_terminal_error", reason, deadline)
          {:stream_error, ^stream, other} -> raise "wrong terminal reason: #{inspect(other)}"
          {:stream_end, ^stream} -> raise "unexpected stream_end"
        after
          budget(deadline, 2_000) -> raise "terminal error deadline exceeded"
        end

        :normal = await_stream_down(deadline)
        reject_extra_stream_messages!(stream)
        operation("exactly_one_terminal_error_and_normal_stream_down", :ok, deadline)

        if kind in [:early, :late] do
          :ok =
            observe(
              "original_completion_after_reader",
              deadline,
              2_000,
              &RequestCompletion.await(completion, &1)
            )

          :ok =
            observe(
              "original_completion_repeated",
              deadline,
              0,
              &RequestCompletion.await(completion, &1)
            )
        end

        :ok
      end)

    cleanup = cleanup(primary)
    current = state()

    status =
      cond do
        primary == {:ok, :ok} and cleanup == [] and current.forced == [] ->
          "PASS"

        String.contains?(inspect({cleanup, current.forced}), "BLOCKED_HANDOFF") ->
          "BLOCKED_HANDOFF"

        String.contains?(inspect(primary), "BLOCKED_ENV") ->
          "BLOCKED_ENV"

        true ->
          "FAIL"
      end

    %{
      case: name,
      protocol: protocol,
      status: status,
      primary: inspect(primary),
      cleanup_errors: cleanup,
      forced_cleanup: current.forced,
      peer_shutdown: current.peer_shutdown,
      peer_os_pid: inspect(Map.get(current, :os_pid)),
      peer_exit: current.port_exit,
      peer_port_down: inspect(current.port_down),
      ready: current.ready,
      events: current.events,
      controls: current.controls,
      operations: current.operations,
      promise_acquired: not is_nil(current.promise),
      promise_await: current.promise_await,
      options: Map.get(current, :options),
      elapsed_ms: now() - start,
      oracle_deadline_ms: current.oracle_deadline,
      cleanup_deadline_ms: current.cleanup_deadline,
      cleanup_scope:
        if(kind in [:early, :late],
          do: "original request completion",
          else: "wire/reader/owned-process observations; completion unsupported"
        )
    }
  end

  defp options(protocol, kind, scope, ready) do
    opts = [
      method: :get,
      request_mode: :fetch,
      body: nil,
      stream_response: true,
      decode_body: false,
      error_mode: :raw,
      http2_profile: :native_v1,
      http2_reuse: true,
      http2_scope: scope,
      tls_backend: :ssl,
      timeout: 6_000,
      connect_timeout: 2_000,
      telemetry: false,
      socket_opts: [send_timeout: 2_000, send_timeout_close: true],
      http_version: if(protocol == "tls", do: :http2, else: :h2c),
      redirect: if(kind in [:early, :late], do: :manual, else: :follow)
    ]

    opts = if state().controller, do: Keyword.put(opts, :signal, state().controller), else: opts

    if protocol == "tls",
      do: Keyword.put(opts, :ssl, cacertfile: ready["ca"], verify: :verify_peer),
      else: opts
  end

  defp register_reader do
    false = state().reader_registered
    send(state().stream, {:read_chunk, self(), :ack})
    update(%{reader_registered: true})
    operation("first_reader_registered", :ok, state().oracle_deadline)
  end

  defp await_response(timeout) do
    update(%{promise_await: :awaiting})

    result =
      try do
        Promise.await(state().promise, timeout)
      catch
        kind, reason ->
          update(%{promise_await: :failed})
          :erlang.raise(kind, reason, __STACKTRACE__)
      end

    update(%{promise_await: :resolved})

    case result do
      %Response{body: stream} when is_pid(stream) ->
        update(%{stream: stream, stream_monitor: Process.monitor(stream)})

      _ ->
        :ok
    end

    result
  end

  defp abort_bounded(controller, deadline) do
    parent = self()
    token = make_ref()

    {pid, monitor} =
      spawn_monitor(fn ->
        send(parent, {token, self(), AbortController.abort(controller)})
      end)

    update(%{jobs: [{pid, monitor} | state().jobs]})

    result =
      receive do
        {^token, ^pid, result} ->
          result

        {:DOWN, ^monitor, :process, ^pid, reason} ->
          update(%{jobs: List.delete(state().jobs, {pid, monitor})})
          raise "abort helper failed: #{inspect(reason)}"
      after
        budget(deadline) -> raise "abort public call exceeded original operation deadline"
      end

    receive do
      {:DOWN, ^monitor, :process, ^pid, :normal} ->
        :ok

      {:DOWN, ^monitor, :process, ^pid, reason} ->
        update(%{jobs: List.delete(state().jobs, {pid, monitor})})
        raise "abort helper join failed: #{inspect(reason)}"
    after
      budget(deadline) -> raise "abort helper join deadline exceeded"
    end

    update(%{jobs: List.delete(state().jobs, {pid, monitor})})
    result
  end

  defp cleanup(primary) do
    deadline = state().cleanup_deadline || state().startup_cleanup_deadline

    actions = [
      fn ->
        for {pid, monitor} <- state().jobs do
          Process.exit(pid, :kill)
          update(%{forced: ["abort helper killed" | state().forced]})

          receive do
            {:DOWN, ^monitor, :process, ^pid, _} ->
              update(%{jobs: List.delete(state().jobs, {pid, monitor})})
          after
            budget(deadline) -> raise "BLOCKED_HANDOFF: helper shutdown unconfirmed"
          end
        end
      end,
      fn ->
        if primary != {:ok, :ok} and not is_nil(state().promise) do
          if state().kind in [:early, :late] do
            completion = state().completion

            result =
              observe(
                "failure_abort_and_await",
                deadline,
                2_000,
                &RequestCompletion.abort_and_await(completion, &1)
              )

            update(%{failure_completion: result})
          else
            :ok =
              observe("failure_abort", deadline, 2_000, fn timeout ->
                abort_bounded(state().controller, now() + timeout)
              end)
          end
        end
      end,
      fn ->
        if primary != {:ok, :ok} and not is_nil(state().promise) and
             state().promise_await == :unawaited do
          # Task.await loses its reply alias on timeout; never retry a failed await.
          _ = observe("failure_response", deadline, 2_000, &await_response/1)
        end
      end,
      fn ->
        if primary != {:ok, :ok} and is_pid(state().stream) and is_nil(state().stream_down) do
          if not state().reader_registered do
            send(state().stream, {:read_chunk, self(), :ack})
            update(%{reader_registered: true})
          end

          operation("failure_stream_down", drain_stream(deadline), deadline)
        end
      end,
      fn ->
        if primary != {:ok, :ok} and not is_nil(state().promise) do
          if state().kind in [:early, :late] do
            result =
              capture(fn ->
                if state().failure_completion == :ok do
                  :ok
                else
                  observe(
                    "failure_completion",
                    deadline,
                    2_000,
                    &RequestCompletion.await(state().completion, &1)
                  )
                end
              end)

            if result != {:ok, :ok},
              do:
                raise("BLOCKED_HANDOFF: original request cleanup unconfirmed: #{inspect(result)}")
          else
            if is_nil(state().stream) and state().promise_await != :resolved do
              raise "BLOCKED_HANDOFF: original Promise response ownership unconfirmed; dedicated VM must end"
            end
          end
        end
      end,
      fn ->
        if controller = state().controller do
          :ok = Agent.stop(controller, :normal, budget(deadline, 2_000))
          monitor = state().controller_monitor

          receive do
            {:DOWN, ^monitor, :process, ^controller, :normal} ->
              update(%{controller_down: :normal})
          after
            budget(deadline) -> raise "BLOCKED_HANDOFF: controller shutdown unconfirmed"
          end
        end
      end,
      fn ->
        if state().port do
          command("stop")
          stopped = event("stopped", deadline, true)
          %{"live_threads" => 0} = stopped
          await_port_exit(deadline)

          if primary == {:ok, :ok} do
            %{"accepts" => 1, "requests" => 1, "resets" => 1, "failed" => false} = stopped
            true = stopped["controls"] == length(state().controls)
            true = Enum.count(state().events, &(&1["event"] == "accept")) == 1
            true = Enum.count(state().events, &(&1["event"] == "request")) == 1
            true = Enum.count(state().events, &(&1["event"] == "reset")) == 1

            true =
              Enum.count(
                state().events,
                &(&1["event"] == "closed" and
                    &1["owned_shutdown"] == true)
              ) == 1

            false = Enum.any?(state().events, &(&1["event"] == "failure"))
            0 = state().port_exit
            :normal = state().port_down

            if state().protocol == "tls",
              do: false = File.exists?(Path.dirname(state().ready["ca"]))

            update(%{peer_shutdown: true})
          end
        end
      end
    ]

    errors =
      Enum.flat_map(actions, fn action ->
        case capture(action) do
          {:ok, _} -> []
          error -> [inspect(error)]
        end
      end)

    if errors != [], do: force_owned_cleanup(deadline)
    errors
  end

  defp force_owned_cleanup(deadline) do
    owned =
      [
        {state().stream, state().stream_monitor, state().stream_down},
        {state().controller, state().controller_monitor, state().controller_down}
      ] ++
        Enum.map(state().jobs, fn {pid, monitor} -> {pid, monitor, nil} end)

    for {pid, monitor, down} <- owned, is_pid(pid), is_nil(down) do
      if Process.alive?(pid) do
        Process.exit(pid, :kill)
        update(%{forced: ["exposed owned process killed: #{inspect(pid)}" | state().forced]})
      end

      result =
        capture(fn ->
          receive do
            {:DOWN, ^monitor, :process, ^pid, _} -> :ok
          after
            budget(deadline) -> raise "BLOCKED_HANDOFF: forced owned-process shutdown unconfirmed"
          end
        end)

      if result != {:ok, :ok},
        do: update(%{forced: [inspect(result) | state().forced]})
    end

    if not is_nil(state().port) and is_nil(state().port_down) do
      capture(fn -> await_port_exit(capped(deadline)) end)

      if is_nil(state().port_down) do
        capture(fn -> Port.close(state().port) end)

        update(%{
          forced: [
            "BLOCKED_HANDOFF: peer port forcibly closed; parent must confirm OS-group shutdown"
            | state().forced
          ]
        })

        capture(fn -> await_port_exit(deadline) end)
      end
    end
  end

  defp command(name) do
    current = state()
    true = length(current.controls) < 3 and name not in current.controls
    true = name in ["reader_sentinel", "malformed_trailers", "stop"]
    line = JSON.encode!(%{command: name}) <> "\n"
    true = byte_size(line) <= 4096
    update(%{controls: current.controls ++ [name]})
    true = Port.command(current.port, line)
  end

  defp event(name, deadline, cleanup \\ false) do
    case Enum.split_while(state().queue, &(&1["event"] != name)) do
      {before, [found | rest]} ->
        update(%{queue: before ++ rest})
        found

      _ ->
        read_port(deadline, cleanup)
        event(name, deadline, cleanup)
    end
  end

  defp read_port(deadline, cleanup) do
    port = state().port
    monitor = state().port_monitor

    receive do
      {^port, {:data, {:eol, line}}} ->
        true = byte_size(line) + 1 <= 4096 and length(state().events) < 128
        item = JSON.decode!(line)
        true = is_map(item) and is_binary(item["event"])
        update(%{events: state().events ++ [item], queue: state().queue ++ [item]})
        if not cleanup and item["event"] == "failure", do: raise("peer failure: #{inspect(item)}")

        if item["event"] == "closed" and item["owned_shutdown"] != true,
          do: raise("unexpected client connection closure")

      {^port, {:data, {:noeol, _}}} ->
        raise "oversized or nonterminated peer line"

      {^port, {:exit_status, exit}} ->
        update(%{port_exit: exit})
        if not cleanup, do: raise("peer exited before barrier: #{exit}")

      {:DOWN, ^monitor, :port, ^port, reason} ->
        update(%{port_down: reason})
        if not cleanup, do: raise("peer port DOWN before barrier: #{inspect(reason)}")
    after
      budget(deadline) -> raise "peer barrier deadline exceeded"
    end
  end

  defp await_port_exit(deadline) do
    if is_nil(state().port_exit) or is_nil(state().port_down) do
      read_port(deadline, true)
      await_port_exit(deadline)
    end
  end

  defp await_stream_down(deadline) do
    stream = state().stream
    monitor = state().stream_monitor

    receive do
      {:DOWN, ^monitor, :process, ^stream, reason} ->
        update(%{stream_down: reason})
        reason
    after
      budget(deadline, 2_000) -> raise "response stream DOWN deadline exceeded"
    end
  end

  defp drain_stream(deadline) do
    stream = state().stream
    monitor = state().stream_monitor

    receive do
      {:stream_chunk, ^stream, _, ref} when is_reference(ref) ->
        send(stream, {:stream_chunk_ack, ref})
        drain_stream(deadline)

      {tag, ^stream, _} when tag in [:stream_chunk, :stream_error, :stream_trailers] ->
        drain_stream(deadline)

      {:stream_end, ^stream} ->
        drain_stream(deadline)

      {:DOWN, ^monitor, :process, ^stream, reason} ->
        update(%{stream_down: reason})
        reason
    after
      budget(deadline, 2_000) -> raise "response stream drain/DOWN deadline exceeded"
    end
  end

  defp reject_extra_stream_messages!(stream) do
    receive do
      {tag, ^stream} when tag == :stream_end ->
        raise "extra stream terminal"

      {tag, ^stream, _} when tag in [:stream_error, :stream_chunk, :stream_trailers] ->
        raise "extra stream message: #{tag}"

      {:stream_chunk, ^stream, _, _} ->
        raise "extra stream chunk"
    after
      0 -> :ok
    end
  end

  defp observe(name, deadline, cap, fun) do
    start = now()

    case capture(fn -> fun.(budget(deadline, cap)) end) do
      {:ok, result} ->
        operation(name, result, deadline, start)
        result

      {:error, failure} ->
        operation(name, {:error, failure}, deadline, start)
        raise failure
    end
  end

  defp operation(name, result, deadline, start \\ nil) do
    update(%{
      operations:
        state().operations ++
          [
            %{
              operation: name,
              start_ms: start || now(),
              end_ms: now(),
              deadline_ms: deadline,
              result: inspect(result, limit: 10, printable_limit: 512)
            }
          ]
    })
  end

  defp capture(fun) do
    try do
      {:ok, fun.()}
    rescue
      error -> {:error, Exception.format(:error, error, __STACKTRACE__)}
    catch
      kind, reason -> {:error, Exception.format(kind, reason, __STACKTRACE__)}
    end
  end

  defp verify_design_sources! do
    Enum.each(@preserved_sources, fn {path, expected} ->
      ^expected = hash(path)
    end)
  end

  defp loaded_modules do
    modules = [
      HTTP,
      Promise,
      RequestCompletion,
      HTTP.Stream,
      AbortController,
      HTTP.Config,
      HTTP.RequestLifecycle,
      HTTP.HTTP2.StreamState,
      HTTP.HTTP2.ConnectionOwner,
      HTTP.Transport.SSL,
      :ssl,
      :public_key,
      :crypto
    ]

    Map.new(modules, fn module ->
      Code.ensure_loaded!(module)
      {^module, bytes, path} = :code.get_object_code(module)
      {:ok, {^module, md5}} = :beam_lib.md5(bytes)
      ^md5 = module.module_info(:md5)

      {to_string(module),
       %{path: to_string(path), beam_sha256: digest(bytes), md5: Base.encode16(md5, case: :lower)}}
    end)
  end

  defp source_hashes do
    sources =
      Enum.flat_map(@packages, fn package ->
        Path.wildcard("deps/#{package}/lib/**/*") |> Enum.filter(&File.regular?/1)
      end)

    files =
      sources ++
        Map.keys(@preserved_sources) ++
        [
          "mix.lock",
          @design,
          __ENV__.file,
          Path.join(__DIR__, "h2_functional_supplement_peer.py"),
          "integration/h2_gateway/requirements.txt",
          "integration/http_fetch_contract/pooled_completion_probe.exs",
          "integration/http_fetch_contract/upstream_peer.py"
        ]

    Map.new(files, &{&1, hash(&1)})
  end

  defp frame_hex(type, flags, sid, bytes),
    do: Base.encode16(<<byte_size(bytes)::24, type, flags, sid::32, bytes::binary>>, case: :lower)

  defp write(directory, name, data),
    do: File.write!(Path.join(directory, name), JSON.encode!(data) <> "\n")

  defp hash(path), do: digest(File.read!(path))
  defp digest(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
  defp now, do: System.monotonic_time(:millisecond)
  defp capped(deadline), do: min(deadline, now() + 2_000)

  defp budget(deadline, cap \\ nil) do
    remaining = max(deadline - now(), 0)
    if remaining == 0, do: raise("original fixture deadline exceeded")
    if cap, do: min(cap, remaining), else: remaining
  end

  defp state, do: Process.get({__MODULE__, :case})
  defp update(fields), do: Process.put({__MODULE__, :case}, Map.merge(state(), fields))
end

HTTPFetchH20214FunctionalSupplement.run()
