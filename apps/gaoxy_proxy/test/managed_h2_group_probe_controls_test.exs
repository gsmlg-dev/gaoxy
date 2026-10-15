defmodule Gaoxy.Proxy.ManagedH2GroupProbeControlsTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.{ManagedH2Client, UpstreamTransports}
  alias Gaoxy.Proxy.ManagedH2GroupAccounting, as: Accounting
  alias Gaoxy.Proxy.UpstreamGroups.Probe
  @timeout 5_000

  setup do
    modules = [Accounting, Probe, ManagedH2Client, GenServer]
    for module <- modules, do: Code.ensure_loaded!(module)

    patterns = [
      {{Accounting, :validate, 2}, [:local]},
      {{Accounting, :preflight_control, 2}, [:local]},
      {{ManagedH2Client, :poll_headers, 1}, [:local]},
      {{ManagedH2Client, :event, 2}, [:local]},
      {{ManagedH2Client, :subscribe, 1}, [:local]},
      {{ManagedH2Client, :acknowledge, 2}, [:local]},
      {{ManagedH2Client, :cleanup, 2}, [:local]},
      {{GenServer, :call, 3}, [:local]}
    ]

    for {mfa, flags} <- patterns, do: :erlang.trace_pattern(mfa, true, flags)
    on_exit(fn -> for {mfa, flags} <- patterns, do: :erlang.trace_pattern(mfa, false, flags) end)
    :ok
  end

  for protocol <- [:http2, :h2c] do
    test "#{protocol} binding preflights actual owner I and accounts its original reply before scheduling" do
      state = fixture(unquote(protocol)) |> opened(false)
      {{:noreply, retained}, calls} = traced(fn -> Probe.handle_continue(:group_bind, state) end)
      {handle, token} = state.transport_selection
      request = {:bind_completion, handle, token, state.original_request.completion}
      assert_call(calls, Accounting, :validate, [{:owner_call, :transport, :bind}, request])
      assert_call(calls, Accounting, :preflight_control, [{:owner, :transport, :bind}, request])
      assert_call(calls, Accounting, :validate, [{:owner_reply, :transport, :bind}, :ok])

      assert_call(calls, Accounting, :validate, [
        {:control, :probe},
        {:bind_probe, state.token, state.original_request.completion}
      ])

      assert before?(calls, {Accounting, :preflight_control}, {GenServer, :call})
      assert retained.transport_selection === state.transport_selection
      assert retained.transport_pins === state.transport_pins
      assert_call(calls, Accounting, :validate, [{:state, :probe}, retained])
      assert_call(calls, Accounting, :validate, [{:control, :timer}, :poll])
    end

    test "#{protocol} completion accounts actual finish and release calls, replies and outgoing S" do
      state = fixture(unquote(protocol)) |> unopened_terminal()
      {{:stop, :normal, retained}, calls} = traced(fn -> Probe.handle_info(:poll, state) end)
      {handle, token} = state.transport_selection
      [pin] = state.transport_pins

      for {operation, request} <- [finish: {:finish, handle, token}, release: {:release, pin}] do
        assert_call(calls, Accounting, :preflight_control, [
          {:owner, :transport, operation},
          request
        ])

        assert_call(calls, Accounting, :validate, [{:owner_reply, :transport, operation}, :ok])
      end

      assert retained.transport_selection === nil
      assert retained.transport_pins === []
      assert_call(calls, Accounting, :validate, [{:state, :probe}, retained])

      assert_call(calls, Accounting, :validate, [
        {:control, :probe},
        {:probe_finished, state.token, state.outcome}
      ])
    end

    test "#{protocol} polling validates incoming S and timer then preflights actual task before adapter receive" do
      state = fixture(unquote(protocol)) |> opened(false)
      {{:noreply, retained}, calls} = traced(fn -> Probe.handle_info(:poll, state) end)
      task = state.request.promise.task
      assert_call(calls, Accounting, :validate, [{:state, :probe}, state])
      assert_call(calls, Accounting, :validate, [{:control, :timer}, :poll])
      assert_call(calls, Accounting, :preflight_control, [:task, {task.ref, task.pid}])
      assert before?(calls, {Accounting, :preflight_control}, {ManagedH2Client, :poll_headers})
      assert_call(calls, Accounting, :validate, [{:state, :probe}, retained])
    end

    test "#{protocol} original task response and actual subscription are accounted before public send" do
      state = fixture(unquote(protocol)) |> opened(false)

      response = %HTTP.Response{
        status: 204,
        ok: true,
        http_version: :http2,
        stream: self(),
        body: self()
      }

      task = state.request.promise.task
      send(task.pid, {:respond, response})
      assert_receive {ref, ^response} = original, @timeout
      assert ref === task.ref
      {{:noreply, retained}, calls} = traced(fn -> Probe.handle_info(original, state) end)
      assert_receive {:read_chunk, subscriber, :ack} = subscription, @timeout
      assert is_pid(subscriber)

      assert_call(calls, Accounting, :validate, [
        {:control, {:task, state.submitted_url}},
        original
      ])

      assert_call(calls, Accounting, :validate, [{:control, :acknowledge}, subscription])

      assert before?(
               calls,
               {Accounting, :validate, [{:control, :acknowledge}, subscription]},
               {ManagedH2Client, :subscribe}
             )

      assert retained.headers and retained.outcome === :success and retained.submitted_url === nil
      assert_call(calls, Accounting, :validate, [{:state, :probe}, retained])
    end

    test "#{protocol} actual chunk and ACK retain originals before HEAD rejection cleanup" do
      state = fixture(unquote(protocol)) |> opened(true)
      reference = make_ref()
      original = {:stream_chunk, state.request.stream, :binary.copy("unexpected body"), reference}
      {{:stop, :normal, retained}, calls} = traced(fn -> Probe.handle_info(original, state) end)
      assert_receive {:stream_chunk_ack, ^reference} = acknowledgement, @timeout
      assert_call(calls, Accounting, :validate, [{:control, :data}, original])
      assert_call(calls, Accounting, :validate, [{:control, :acknowledge}, acknowledgement])
      assert before?(calls, {ManagedH2Client, :acknowledge}, {ManagedH2Client, :cleanup})
      assert retained.cancelled and retained.terminal and retained.outcome === :failure
      assert retained.original_request === state.original_request
    end
  end

  for {family, event} <- [stream_end: :end, trailers: :trailers, stream_error: :error] do
    test "actual #{family} message is accounted before adapter and outgoing state" do
      state = fixture() |> opened(true)

      original =
        case unquote(event) do
          :end -> {:stream_end, state.request.stream}
          :trailers -> {:stream_trailers, state.request.stream, %HTTP.Headers{}}
          :error -> {:stream_error, state.request.stream, {:diagnostic, fn -> :opaque end}}
        end

      {result, calls} = traced(fn -> Probe.handle_info(original, state) end)
      assert elem(result, 0) in [:stop, :noreply]
      retained = elem(result, tuple_size(result) - 1)
      assert_call(calls, Accounting, :validate, [{:control, unquote(family)}, original])

      assert before?(
               calls,
               {Accounting, :validate, [{:control, unquote(family)}, original]},
               {ManagedH2Client, :event}
             )

      assert_call(calls, Accounting, :validate, [{:state, :probe}, retained])
    end
  end

  test "owner monitor reference with a foreign PID cannot cancel Probe or recovery" do
    state = fixture() |> opened(true)
    assert state.owner !== self()
    original = {:DOWN, state.owner_monitor, :process, self(), :killed}
    {{:noreply, retained}, calls} = traced(fn -> Probe.handle_info(original, state) end)
    assert retained === state
    refute Enum.any?(calls, &match?({ManagedH2Client, :cleanup, _}, &1))
    refute Enum.any?(calls, &match?({GenServer, :call, _}, &1))

    recovery = %{
      owner: state.owner,
      completion: state.original_request.completion,
      deadline: state.deadline,
      recovery: {:probe, state.token},
      owner_monitor: state.owner_monitor
    }

    assert Probe.handle_info(original, recovery) === {:noreply, recovery}
  end

  test "a refused incoming S still enters original cleanup and preserves live ledgers" do
    state = fixture() |> opened(true) |> Map.put(:extra, :expanded)
    original = {:stream_end, state.request.stream}
    {result, calls} = traced(fn -> Probe.handle_info(original, state) end)
    assert elem(result, 0) === :stop
    retained = elem(result, tuple_size(result) - 1)
    assert retained.original_request === state.original_request
    assert retained.transport_selection === state.transport_selection
    assert retained.transport_pins === state.transport_pins
    assert_call(calls, Accounting, :validate, [{:state, :probe}, state])
    assert Enum.any?(calls, &match?({ManagedH2Client, :cleanup, _}, &1))
    refute Enum.any?(calls, &match?({ManagedH2Client, :event, _}, &1))
  end

  for event <- [:cancel, :expired] do
    test "actual #{event} control is accounted while preserving owed cancellation cleanup" do
      state = fixture() |> unopened_terminal()

      callback = fn ->
        case unquote(event) do
          :cancel -> Probe.handle_cast(:cancel, state)
          :expired -> Probe.handle_info(:expired, state)
        end
      end

      {{:stop, :normal, retained}, calls} = traced(callback)
      family = if unquote(event) == :cancel, do: :cast, else: :timer
      original = if family == :cast, do: {:"$gen_cast", :cancel}, else: :expired
      assert_call(calls, Accounting, :validate, [{:control, family}, original])
      assert retained.cancelled and retained.terminal
      assert_call(calls, Accounting, :validate, [{:state, :probe}, retained])
    end
  end

  test "a genuine owner DOWN is accounted and cleanup is not discarded" do
    state = fixture() |> opened(true)
    state = %{state | transport_selection: nil, transport_pins: []}
    Process.exit(state.owner, :kill)
    assert_receive {:DOWN, ref, :process, pid, :killed} = original, @timeout
    assert ref === state.owner_monitor and pid === state.owner

    {{:stop, :owner_unavailable, retained}, calls} =
      traced(fn -> Probe.handle_info(original, state) end)

    assert retained.cancelled and retained.terminal
    assert_call(calls, Accounting, :validate, [{:control, :down}, original])
    assert_call(calls, ManagedH2Client, :cleanup, [state.original_request, true])
  end

  test "recovery validates exact state and finite original notification before send" do
    owner = self()
    completion = completed_completion()

    state = %{
      owner: owner,
      recovery: {:probe, make_ref()},
      completion: completion,
      deadline: Gaoxy.Lifecycle.deadline(2_000),
      owner_monitor: Process.monitor(owner)
    }

    {{:stop, :normal, retained}, calls} = traced(fn -> Probe.handle_info(:recover, state) end)
    assert_receive {:recovered, :probe, token, pid, :ok} = notification, @timeout
    assert token === elem(state.recovery, 1) and is_pid(pid)
    assert retained === state
    assert_call(calls, Accounting, :validate, [{:state, :recovery}, state])
    assert_call(calls, Accounting, :validate, [{:control, :probe}, notification])
  end

  test "failed transport finish preserves the original selection and pins" do
    state = fixture(:http2, %{finish: {:error, :cleanup_pending}}) |> unopened_terminal()
    {{:noreply, retained}, calls} = traced(fn -> Probe.handle_info(:poll, state) end)
    assert retained.transport_selection === state.transport_selection
    assert retained.transport_pins === state.transport_pins

    assert_call(calls, Accounting, :validate, [
      {:owner_reply, :transport, :finish},
      {:error, :cleanup_pending}
    ])
  end

  test "failed pin release preserves the original pins after confirmed selection finish" do
    state = fixture(:http2, %{release: {:error, :unavailable}}) |> unopened_terminal()

    {{:stop, {:cleanup_failed, {:pin_release_failed, :unavailable}}, retained}, calls} =
      traced(fn -> Probe.handle_info(:poll, state) end)

    assert retained.transport_selection === nil
    assert retained.transport_pins === state.transport_pins

    assert_call(calls, Accounting, :validate, [
      {:owner_reply, :transport, :release},
      {:error, :unavailable}
    ])
  end

  defp fixture(protocol \\ :http2, replies \\ %{}) do
    owner = spawn(fn -> owner_loop(replies) end)
    monitor = Process.monitor(owner)

    on_exit(fn ->
      join = Process.monitor(owner)
      if Process.alive?(owner), do: Process.exit(owner, :kill)
      assert_receive {:DOWN, ^join, :process, ^owner, _}, @timeout
    end)

    transport = %{
      provider: UpstreamTransports,
      owner: owner,
      owner_epoch: make_ref(),
      resource: make_ref()
    }

    pin = %{
      provider: UpstreamTransports,
      owner: owner,
      owner_epoch: transport.owner_epoch,
      operation: make_ref(),
      ref: make_ref(),
      handles: [transport],
      kind: :request,
      holder: self()
    }

    deadline = Gaoxy.Lifecycle.deadline(4_000)
    timer = Process.send_after(self(), :fixture_timeout, 30_000)

    on_exit(fn ->
      Process.cancel_timer(timer)
      Process.demonitor(monitor, [:flush])
    end)

    %{
      owner: owner,
      token: make_ref(),
      member: nil,
      deadline: deadline,
      health: nil,
      url: nil,
      group: nil,
      cleanup_deadline: deadline + 1_000,
      owner_monitor: monitor,
      timer: timer,
      request: nil,
      original_request: nil,
      managed_transport: nil,
      transport_selection: {transport, make_ref()},
      transport_pins: [pin],
      terminal: false,
      cancelled: false,
      headers: false,
      outcome: :failure,
      client: ManagedH2Client,
      limits: %{
        max_chunk_bytes: 1_024,
        opening_timeout: 4_000,
        idle_timeout: 3_000,
        write_timeout: 700,
        max_lifetime: 10_000
      },
      request_options: nil,
      submitted_url: nil
    }
    |> then(fn state ->
      assert protocol in [:http2, :h2c]
      state
    end)
  end

  defp owner_loop(replies) do
    receive do
      {:"$gen_call", from, request} ->
        GenServer.reply(from, Map.get(replies, elem(request, 0), :ok))
        owner_loop(replies)
    end
  end

  defp opened(state, resolved) do
    handle = %{
      public_handle(completed_completion())
      | resolved: resolved,
        stream: if(resolved, do: self(), else: nil)
    }

    %{
      state
      | request: handle,
        original_request: handle,
        submitted_url: if(resolved, do: nil, else: :binary.copy("https://upstream.test/health")),
        headers: resolved
    }
  end

  defp unopened_terminal(state), do: %{state | terminal: true}

  defp completed_completion do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

    {:ok, {_, port}} = :inet.sockname(listener)
    owner = self()

    peer =
      spawn(fn ->
        try do
          {:ok, socket} = :gen_tcp.accept(listener, @timeout)

          try do
            recv_fixture_head(socket, "")

            result =
              :gen_tcp.send(
                socket,
                "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
              )

            send(owner, {:completion_peer_result, self(), result})
          after
            :gen_tcp.close(socket)
          end
        after
          :gen_tcp.close(listener)
        end
      end)

    peer_monitor = Process.monitor(peer)

    on_exit(fn ->
      :gen_tcp.close(listener)
      join = Process.monitor(peer)
      if Process.alive?(peer), do: Process.exit(peer, :kill)
      assert_receive {:DOWN, ^join, :process, ^peer, _}, @timeout
    end)

    promise =
      HTTP.fetch("http://127.0.0.1:#{port}/completion",
        http_version: :http1,
        http1_reuse: false,
        tls_backend: :ssl,
        redirect: :manual,
        decode_body: false,
        request_mode: :proxy,
        timeout: @timeout
      )

    worker = promise.task.pid
    worker_monitor = Process.monitor(worker)
    completion = HTTP.Promise.completion(promise)
    on_exit(fn -> HTTP.RequestCompletion.abort_and_await(completion, @timeout) end)
    assert %HTTP.Response{status: 204} = HTTP.Promise.await(promise, @timeout)
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
    assert_receive {:completion_peer_result, ^peer, :ok}, @timeout
    assert_receive {:DOWN, ^peer_monitor, :process, ^peer, peer_reason}, @timeout
    assert peer_reason in [:normal, :noproc]
    assert_receive {:DOWN, ^worker_monitor, :process, ^worker, worker_reason}, @timeout
    assert worker_reason in [:normal, :noproc]
    completion
  end

  defp recv_fixture_head(socket, bytes) when byte_size(bytes) <= 16_384 do
    if :binary.match(bytes, "\r\n\r\n") == :nomatch do
      {:ok, next} = :gen_tcp.recv(socket, 0, @timeout)
      recv_fixture_head(socket, bytes <> next)
    else
      :ok
    end
  end

  defp assert_call(calls, module, function, args), do: assert({module, function, args} in calls)

  defp before?(calls, first, second) do
    first_index = Enum.find_index(calls, &trace_match?(&1, first))
    second_index = Enum.find_index(calls, &trace_match?(&1, second))
    is_integer(first_index) and is_integer(second_index) and first_index < second_index
  end

  defp trace_match?({module, function, _}, {module, function}), do: true
  defp trace_match?(call, expected), do: call === expected

  defp traced(fun) do
    parent = self()

    worker =
      spawn(fn ->
        receive do
          :run ->
            result =
              try do
                fun.()
              catch
                kind, reason -> {:unexpected_exception, kind, reason, __STACKTRACE__}
              end

            send(parent, {:callback_result, self(), result})

            receive do
              :finish -> :ok
            after
              @timeout -> exit(:callback_join_timeout)
            end
        after
          @timeout -> exit(:callback_start_timeout)
        end
      end)

    monitor = Process.monitor(worker)
    on_exit(fn -> if Process.alive?(worker), do: Process.exit(worker, :kill) end)
    :erlang.trace(worker, true, [:call, {:tracer, parent}])
    send(worker, :run)
    assert_receive {:callback_result, ^worker, result}, @timeout
    barrier = :erlang.trace_delivered(worker)
    assert_receive {:trace_delivered, ^worker, ^barrier}, @timeout
    calls = trace_calls(worker, [])
    :erlang.trace(worker, false, [:all])
    send(worker, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, @timeout
    {result, calls}
  end

  defp trace_calls(worker, acc) do
    receive do
      {:trace, ^worker, :call, {module, function, args}} ->
        trace_calls(worker, [{module, function, args} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp public_handle(completion) do
    task =
      Task.async(fn ->
        receive do
          {:respond, value} -> value
        after
          30_000 -> exit(:fixture_task_timeout)
        end
      end)

    Process.unlink(task.pid)

    on_exit(fn ->
      join = Process.monitor(task.pid)
      if Process.alive?(task.pid), do: Process.exit(task.pid, :kill)
      assert_receive {:DOWN, ^join, :process, _, _}, @timeout
    end)

    %{
      promise: %HTTP.Promise{task: task, completion: completion},
      completion: completion,
      stream: nil,
      resolved: false
    }
  end
end
