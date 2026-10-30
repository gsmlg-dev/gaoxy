defmodule Gaoxy.HTTP.HTTP3.ResourceBudgetH3Test do
  use ExUnit.Case, async: true
  @moduletag :component
  alias Gaoxy.{Admission, Lifecycle, QUICBridge}
  alias Gaoxy.HTTP.{Exchange, Request}
  alias Gaoxy.HTTP.HTTP3.{Connection, Operations, Options, Stream}

  defmodule Endpoint do
    def init(options), do: {:ok, options}

    def call(exchange, observer) do
      send(observer, {:endpoint, self(), exchange})
      {:ok, %{exchange | response: :sent}}
    end
  end

  defmodule CompletedTransport do
    def finish(exchange, []), do: {:ok, exchange}
  end

  defp deadline, do: Lifecycle.deadline(2_000)

  defp gate do
    identity = make_ref()

    start_supervised!(
      {Gaoxy.ResourceBudget.Supervisor,
       identity: identity,
       capacity_probe: fn -> %{capacity: 1_000_000_000, fallback?: false, source: :controlled} end,
       safety_probe: fn _ ->
         {:ok,
          %{
            available_bytes: 1_000_000_000,
            cgroup_headroom_bytes: nil,
            sampled_at: Lifecycle.now(),
            high_pressure?: false
          }}
       end,
       processes: fn -> %{count: 1, limit: 1000} end}
    )

    server = Gaoxy.ResourceBudget.Supervisor.name(Gaoxy.ResourceBudget.Authority, identity)
    assert :ok = Gaoxy.ResourceBudget.refresh(server)

    {:ok, instance} =
      Gaoxy.ResourceBudget.register_instance(
        server,
        self(),
        %{soft_limit: 16_777_216, hard_limit: 33_554_432},
        deadline()
      )

    id = make_ref()

    {:ok, service} =
      Gaoxy.ResourceBudget.register_service(
        server,
        instance,
        %{id: id, owner: self(), generation: make_ref()},
        %{
          max_active: nil,
          max_bytes: nil,
          max_connections: 10,
          max_requests: 10,
          max_streams: 10,
          provenance: %{}
        },
        deadline()
      )

    start_supervised!(
      {Admission,
       {%{max_active: 20, max_bytes: 16_777_216, callback_timeout: 5_000},
        %{
          service: id,
          service_pid: self(),
          budget: %{server: server, instance: instance, service: service}
        }}}
    )
  end

  defp eventually(fun, until \\ nil) do
    until = until || deadline()

    if fun.() do
      :ok
    else
      assert Lifecycle.remaining(until) > 0

      receive do
      after
        1 -> eventually(fun, until)
      end
    end
  end

  test "native accounting sums disjoint byte metrics and never treats counts or cursors as bytes" do
    metrics = %{
      queued_bytes: 1,
      ready_bytes: 2,
      receive_buffered_bytes: 4,
      io_queue_bytes: 8,
      operation_result_bytes: 16,
      recovery_packets: 999_999,
      stream_records: 999_999,
      application_crypto_bytes: 999_999,
      datagram_ready_bytes: 999_999
    }

    assert {:ok, 31} = apply(QUICBridge, :native_bytes, [{:ok, %{resources: metrics}}])
  end

  test "failed missing or malformed native byte inspection is unavailable" do
    assert {:error, :native_resources_unavailable} =
             apply(QUICBridge, :native_bytes, [{:error, :closed}])

    assert {:error, :native_resources_unavailable} =
             apply(QUICBridge, :native_bytes, [{:ok, %{resources: %{}}}])

    metrics = %{
      queued_bytes: 0,
      ready_bytes: -1,
      receive_buffered_bytes: 0,
      io_queue_bytes: 0,
      operation_result_bytes: 0
    }

    assert {:error, :native_resources_unavailable} =
             apply(QUICBridge, :native_bytes, [{:ok, %{resources: metrics}}])
  end

  test "opaque stream resolution requires the bound admitted worker and uses no index rows" do
    table = Operations.new()
    token = make_ref()
    key = %{opaque: make_ref(), payload: :binary.copy("x", 128)}
    until = deadline()
    assert :ok = Operations.register(table, key, token, until)
    assert {:error, :closed} = apply(Operations, :resolve, [table, token])
    observer = self()

    worker =
      spawn(fn ->
        receive do
          :resolve -> send(observer, {:resolved, apply(Operations, :resolve, [table, token])})
        end
      end)

    assert :ok = Operations.bind(table, key, token, worker)
    assert {:error, :closed} = apply(Operations, :resolve, [table, token])
    send(worker, :resolve)
    assert_receive {:resolved, {:ok, ^key, ^until}}, 1_000
    assert :ets.info(table, :size) == 1
    assert :ets.info(table, :memory) > 0
  end

  test "canonical scalar worker is inert until Operations binding and keeps stream ownership after request completion" do
    Process.flag(:trap_exit, true)
    g = gate()

    {:ok, parent} =
      Admission.acquire(g, 0, kind: :connection, memberships: %{connection: make_ref()})

    table = Operations.new()
    token = make_ref()
    key = %{opaque: make_ref()}
    until = deadline()
    assert :ok = Operations.register(table, key, token, until)

    request =
      Admission.spawn_request(
        g,
        parent,
        token,
        256,
        until,
        {Stream, :run_admitted, [self(), table, token, g, until]},
        kind: :h3_stream,
        memberships: %{request: token, h3_stream: {parent, token}}
      )

    assert {:reply, {:ok, worker, lease}} = :gen_server.receive_response(request, 1_000)
    assert {:ok, %{worker: nil, status: :starting}} = Operations.status(table, key, token)
    refute_receive {:endpoint, _, _}, 20
    assert :ok = Operations.bind(table, key, token, worker)
    send(worker, {:h3_start, self(), token})
    eventually(fn -> match?({:ok, %{status: :ready}}, Operations.status(table, key, token)) end)
    assert :ok = Operations.activate(table, key, token, worker)

    exchange = %Exchange{
      request: %Request{method: "GET", version: :"HTTP/3", path: "/", headers: [], head_bytes: 0},
      gate: g,
      lease: lease,
      deadline: until,
      limits: %{write_timeout: 1000},
      body: %{phase: :done, total: 0, trailers: [], trailer_bytes: 0},
      buffer: "",
      transport: CompletedTransport,
      protocol_bytes: 64,
      transport_state: {self(), table, key, token}
    }

    monitor = Process.monitor(worker)
    send(worker, {:h3_dispatch, self(), key, token, exchange, {Endpoint, self()}})
    assert_receive {:endpoint, ^worker, _}, 1_000
    assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, 1_000
    assert {:ok, %{status: {:finished, :ok}}} = Operations.status(table, key, token)
    assert Admission.status(g).active == 2
    state = :sys.get_state(g)
    assert state.leases[lease].accounting.memberships == %{h3_stream: {parent, token}}
    assert state.leases[lease].request_active == false
    assert state.leases[lease].bytes == 64
    assert :ok = Admission.end_stream(g, parent, :h3_stream, token, deadline())
    assert :ok = Admission.finish_spawn_resources(g, parent, token, make_ref(), deadline())
    eventually(fn -> Admission.status(g).active == 1 end)
  end

  test "dynamic exchange credit follows retained request metadata instead of the configured request maximum" do
    {:ok, spec} =
      Options.normalize(endpoint: {Endpoint, self()}, tls: %{certfile: "c", keyfile: "k"})

    {:ok, state} = Connection.init(%{gate: nil, limits: spec.limits}, %{}, spec.handler_options)
    key = make_ref()
    {:ok, state} = Connection.handle_event({:stream_open, key, :bidi}, state)
    request = %Request{method: "GET", version: :"HTTP/3", headers: [], head_bytes: 10}
    state = put_in(state.streams[key].request, request)
    exchange = Connection.exchange(state, key, make_ref())
    assert exchange.protocol_bytes > 0
    assert Exchange.retained_bytes(exchange) < Options.reservation(state.options).request
    :ok = Connection.terminate(:test, state)
  end

  test "a delayed admitted startup reply survives empty owner polls without replay" do
    {state, key, token, gate} = polling_state()
    startup = :gen_server.send_request(gate, :held_startup)
    assert_receive {:held_reply, :held_startup, from}, 1_000

    state = update_in(state.streams[key], &%{&1 | startup: startup, admission: :pending})
    assert {:ok, polled} = Connection.handle_event(:tick, state)
    assert polled.streams[key].startup == startup
    assert polled.streams[key].admission == :pending

    observer = self()

    worker =
      spawn(fn ->
        receive do
          {:h3_start, ^observer, ^token} ->
            send(observer, {:startup_observed, self()})

            receive do
              :stop -> :ok
            end
        end
      end)

    on_exit(fn -> if Process.alive?(worker), do: Process.exit(worker, :kill) end)
    lease = make_ref()
    GenServer.reply(from, {:ok, worker, lease})

    assert {:ok, resumed} = Connection.handle_event(:tick, polled)
    assert resumed.streams[key].startup == nil
    assert resumed.streams[key].admission == :admitted
    assert resumed.streams[key].worker == worker
    assert resumed.streams[key].lease == lease
    assert_receive {:startup_observed, ^worker}, 1_000
    refute_receive {:held_reply, :held_startup, _}, 0
    :ok = Connection.terminate(:test_complete, resumed)
  end

  test "a delayed stale cancellation survives polling and cannot prove absent reservation" do
    {state, key, token, _gate} = polling_state()
    state = put_in(state.streams[key].admission, :rejected)
    assert {:ok, cancelled} = Connection.handle_event({:stopped, key, 0x10C}, state)
    assert_receive {:held_reply, {:cancel_spawn, _, ^token}, from}, 1_000
    {:pending, cancellation} = cancelled.streams[key].spawn_cancel

    # The native cleanup is terminal in this controlled fixture. The canonical
    # cancellation receipt is still pending and must survive a nonblocking poll.
    retiring = update_in(cancelled.streams[key], &%{&1 | retiring: true, cancel: []})
    assert {:ok, pending} = Connection.handle_event(:tick, retiring)
    assert pending.streams[key].spawn_cancel == {:pending, cancellation}
    refute pending.streams[key].resources_terminal
    assert pending.streams[key].stream_terminal
    GenServer.reply(from, {:error, :stale_generation})

    assert {:ok, settled} = Connection.handle_event(:tick, pending)
    assert Map.has_key?(settled.streams, key)
    refute settled.streams[key].resources_terminal
    assert {:error, :closed} = Operations.status(settled.operations, key, token)
    refute_receive {:held_reply, {:cancel_spawn, _, ^token}, _}, 0
    :ok = Connection.terminate(:test_complete, settled)
  end

  test "only exact pre-reservation proof on the original spawn alias retires an absent worker" do
    for match_token <- [false, true] do
      {state, key, token, gate} = polling_state()
      startup = :gen_server.send_request(gate, :held_startup)
      assert_receive {:held_reply, :held_startup, from}, 1_000
      state = update_in(state.streams[key], &%{&1 | startup: startup, admission: :pending})
      assert {:ok, cancelled} = Connection.handle_event({:stopped, key, 0x10C}, state)
      assert_receive {:held_reply, {:cancel_spawn, _, ^token}, _}, 1_000
      retiring = update_in(cancelled.streams[key], &%{&1 | retiring: true, cancel: []})
      assert {:ok, pending} = Connection.handle_event(:tick, retiring)
      refute pending.streams[key].resources_terminal
      proof_token = if match_token, do: token, else: make_ref()
      GenServer.reply(from, {:error, {:not_reserved, proof_token, :deadline_exceeded}})
      assert {:ok, settled} = Connection.handle_event(:tick, pending)

      if match_token do
        refute Map.has_key?(settled.streams, key)
      else
        assert settled.streams[key].admission == :rejected
        refute settled.streams[key].resources_terminal
      end

      assert {:error, :closed} = Operations.status(settled.operations, key, token)
      :ok = Connection.terminate(:test_complete, settled)
    end
  end

  defp polling_state do
    observer = self()
    gate = spawn(fn -> reply_gate(observer) end)
    on_exit(fn -> if Process.alive?(gate), do: Process.exit(gate, :kill) end)

    {:ok, spec} =
      Options.normalize(endpoint: {Endpoint, observer}, tls: %{certfile: "c", keyfile: "k"})

    {:ok, state} =
      Connection.init(
        %{gate: gate, lease: make_ref(), limits: spec.limits},
        %{},
        spec.handler_options
      )

    key = make_ref()
    token = make_ref()
    {:ok, state} = Connection.handle_event({:stream_open, key, :bidi}, state)
    entry = state.streams[key]
    :ok = Operations.register(state.operations, key, token, entry.deadline)
    request = %Request{method: "GET", version: :"HTTP/3", path: "/", headers: [], head_bytes: 0}
    state = put_in(state.streams[key], %{entry | token: token, request: request, recv_fin: true})
    {%{state | ready: true, control: make_ref(), control_bytes: <<>>}, key, token, gate}
  end

  defp reply_gate(observer) do
    receive do
      {:"$gen_call", from, request} when request == :held_startup ->
        send(observer, {:held_reply, request, from})

      {:"$gen_call", from, {:cancel_spawn, _, _} = request} ->
        send(observer, {:held_reply, request, from})

      {:"$gen_call", from, {:finish_stream_resources, _, _, _, _}} ->
        GenServer.reply(from, {:error, :stale_generation})

      {:"$gen_call", from, {:end_stream, _, :h3_stream, _, _}} ->
        GenServer.reply(from, :ok)
    end

    reply_gate(observer)
  end
end
