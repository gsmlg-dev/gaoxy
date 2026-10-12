defmodule Gaoxy.HTTP.HTTP3.ConnectionTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.Exchange
  alias Gaoxy.HTTP.HTTP3.{Connection, Headers, Operations, Options, Protocol}
  alias QuicHttp3.{Frame, Qpack}

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(_, _), do: raise("endpoint callbacks must not run inside the QUIC owner")
  end

  defp init do
    {:ok, spec} =
      Options.normalize(
        endpoint: {Endpoint, %{profile: :minimal}},
        tls: %{certfile: "fixture.pem", keyfile: "key.pem"}
      )

    connection = %{gate: self(), limits: spec.limits}

    options = %{
      spec.handler_options
      | endpoint: {Gaoxy.HTTP3Fixture.Endpoint, %{profile: :minimal, observer: self(), id: :main}}
    }

    Connection.init(
      connection,
      %{alpn: "h3", tls_complete: false, parameters_valid: false},
      options
    )
  end

  test "init and ticks do not perform I/O before authenticated readiness" do
    assert {:ok, state} = init()
    assert_receive {:http3_fixture_connection, :main, gate}
    assert gate == self()
    assert {:ok, ^state} = Connection.handle_event(:tick, state)
    assert {:ok, ^state} = Connection.handle_event(:writable, state)
  end

  test "pre-ready peer streams retain opaque keys without reading or assigning IDs" do
    {:ok, state} = init()
    key = make_ref()
    assert {:ok, state} = Connection.handle_event({:stream_open, key, :bidi}, state)
    assert Map.has_key?(state.protocol.streams, key)
    assert {:ok, ^state} = Connection.handle_event({:readable, key}, state)
  end

  test "late open event for the local control stream never enters the peer parser" do
    {:ok, state} = init()
    key = make_ref()
    state = %{state | control: key}
    assert {:ok, ^state} = Connection.handle_event({:stream_open, key, :uni}, state)
    refute Map.has_key?(state.protocol.streams, key)
  end

  test "response owners remain bounded after receive FIN frees parser slots" do
    {:ok, state} = init()

    state =
      Enum.reduce(1..8, state, fn _, acc ->
        {:ok, next} = Connection.handle_event({:stream_open, make_ref(), :bidi}, acc)
        next
      end)

    # Receive FIN releases pure parsers; blocked response owners retain their slots.
    state = %{state | protocol: %{state.protocol | streams: %{}}}
    key = make_ref()
    {:ok, next} = Connection.handle_event({:stream_open, key, :bidi}, state)
    refute Map.has_key?(next.protocol.streams, key)
    assert next.streams[key].cancel == [{:reset, 0x107}, {:stop, 0x107}]
    assert map_size(state.streams) == 8
  end

  test "wrong negotiated ALPN is rejected before control stream activation" do
    {:ok, state} = init()

    assert {:stop, :unsupported_http3_alpn, _} =
             Connection.handle_event(
               {:ready, %{alpn: "h2", tls_complete: true, parameters_valid: true}},
               state
             )
  end

  test "incomplete authentication cannot activate the owner" do
    {:ok, state} = init()

    assert {:stop, :http3_not_authenticated, _} =
             Connection.handle_event(
               {:ready, %{alpn: "h3", tls_complete: false, parameters_valid: false}},
               state
             )
  end

  test "arbitrary application events do not execute endpoints" do
    {:ok, state} = init()
    assert {:ok, ^state} = Connection.handle_event({:application_call, :payload}, state)
  end

  test "validated empty-body FIN before dispatch preserves repeated ordered request trailers" do
    {:ok, spec} =
      Options.normalize(endpoint: {Endpoint, %{}}, tls: %{certfile: "c", keyfile: "k"})

    metadata = %{remote: {{127, 0, 0, 1}, 1234}, local: {{127, 0, 0, 1}, 4321}}

    connection = %{
      gate: self(),
      limits: spec.limits,
      service: self(),
      instance: self(),
      scope: %{service: :listener, instance: make_ref()}
    }

    {:ok, state} =
      Connection.init(connection, metadata, spec.handler_options)

    key = make_ref()
    {:ok, state} = Connection.handle_event({:stream_open, key, :bidi}, state)
    trailers = [{"x-empty", "first"}, {"x-empty", "second"}]

    {:ok, head} =
      Qpack.encode_header_block([
        {":method", "POST"},
        {":scheme", "https"},
        {":authority", "localhost"},
        {":path", "/zero-trailers"},
        {"content-length", "0"}
      ])

    {:ok, tail} = Qpack.encode_header_block(trailers)

    {:ok, protocol, [{:headers, ^key, request}, {:trailers, ^key, ^trailers}]} =
      Protocol.feed(
        state.protocol,
        key,
        Frame.encode!(:headers, head) <> Frame.encode!(:headers, tail)
      )

    {:ok, protocol, [{:complete, ^key}]} = Protocol.fin(protocol, key)

    entry = %{
      state.streams[key]
      | request: request,
        input: "",
        recv_fin: true,
        trailers: trailers
    }

    state = %{state | protocol: protocol, streams: Map.put(state.streams, key, entry)}
    lease = make_ref()

    exchange = Connection.exchange(state, key, lease)
    assert Exchange.body_complete?(exchange)
    assert Exchange.request_trailers(exchange) == trailers
    assert exchange.body.trailer_bytes == Headers.bytes(trailers)
    assert exchange.body.total == 0
    assert exchange.lease == lease
    assert exchange.service == self()
    assert exchange.instance == self()
    assert exchange.peer == metadata.remote
    assert exchange.local == metadata.local

    # Retained DATA still needs credited reads before trailers become visible.
    state = %{state | streams: Map.put(state.streams, key, %{entry | input: "body"})}
    exchange = Connection.exchange(state, key, lease)
    refute Exchange.body_complete?(exchange)
    assert Exchange.request_trailers(exchange) == []
    assert exchange.body.trailer_bytes == 0
    :ok = Connection.terminate(:test_complete, state)
  end

  test "retained parser input resumes before shared new-read credit with an accepted single-quantum buffer" do
    {:ok, spec} =
      Options.normalize(
        endpoint: {Endpoint, %{}},
        http_limits: %{max_buffer_bytes: 16_384},
        tls: %{certfile: "c", keyfile: "k"}
      )

    gate =
      start_supervised!(
        {Gaoxy.Admission, {spec.limits, %{instance: make_ref(), service: :resume}}}
      )

    {:ok, state} = Connection.init(%{gate: gate, limits: spec.limits}, %{}, spec.handler_options)
    key = make_ref()
    {:ok, state} = Connection.handle_event({:stream_open, key, :bidi}, state)

    {:ok, head} =
      Qpack.encode_header_block([
        {":method", "GET"},
        {":scheme", "https"},
        {":authority", "localhost"},
        {":path", "/ok"}
      ])

    bytes = :binary.copy(<<0x21, 0>>, 12) <> Frame.encode!(:headers, head)
    {:ok, protocol, []} = Protocol.feed(state.protocol, key, bytes)
    assert byte_size(protocol.streams[key].buffer) > 0
    state = %{state | protocol: protocol}

    fenced = %{state | pending: %{{key, :write} => {make_ref(), Gaoxy.Lifecycle.deadline(1_000)}}}
    assert {:ok, ^fenced} = Connection.receive_stream(fenced, key)

    assert {:ok, resumed} = Connection.receive_stream(state, key)
    assert resumed.streams[key].request.method == "GET"
    assert resumed.protocol.streams[key].buffer == ""
    worker = resumed.streams[key].worker
    assert is_pid(worker)
    monitor = Process.monitor(worker)
    :ok = Connection.terminate(:test_complete, resumed)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    assert :ets.info(state.operations) == :undefined
  end

  test "a claimed read losing its reply CAS retains ingress and visibly cancels its worker" do
    {:ok, spec} =
      Options.normalize(endpoint: {Endpoint, %{}}, tls: %{certfile: "c", keyfile: "k"})

    {:ok, state} =
      Connection.init(%{gate: self(), limits: spec.limits}, %{}, spec.handler_options)

    key = make_ref()
    token = make_ref()
    deadline = Gaoxy.Lifecycle.deadline(1_000)
    {:ok, state} = Connection.handle_event({:stream_open, key, :bidi}, state)
    table = state.operations
    :ok = Operations.register(table, key, token, deadline)
    observer = self()

    worker =
      spawn(fn ->
        receive do
          :bound -> :ok
        end

        :ok = Operations.ready(table, key, token, make_ref())
        send(observer, {:read_ready, self()})

        receive do
          :activated -> :ok
        end

        operation = {:read, 3, {:until, deadline}}
        {:ok, ref} = Operations.submit(table, key, token, {operation, deadline})
        send(observer, {:read_submitted, self(), ref, operation})

        receive do
          :expire_caller -> :ok
        end

        :ok = Operations.timeout(table, key, token, ref)
        send(observer, {:read_tombstoned, self(), ref})

        receive do
          :unreleased -> :ok
        end
      end)

    on_exit(fn -> if Process.alive?(worker), do: Process.exit(worker, :kill) end)
    monitor = Process.monitor(worker)
    :ok = Operations.bind(table, key, token, worker)
    send(worker, :bound)
    assert_receive {:read_ready, ^worker}, 1_000
    :ok = Operations.activate(table, key, token, worker)
    send(worker, :activated)
    assert_receive {:read_submitted, ^worker, ref, operation}, 1_000
    assert {:ok, ^worker, ^ref, ^operation, ^deadline} = Operations.claim(table, key, token)
    send(worker, :expire_caller)
    assert_receive {:read_tombstoned, ^worker, ^ref}, 1_000

    entry = %{
      state.streams[key]
      | token: token,
        worker: worker,
        deadline: deadline,
        operation: {ref, operation, deadline},
        input: "retained",
        recv_fin: true
    }

    state = %{state | streams: Map.put(state.streams, key, entry)}

    assert {:ok, cancelled} = Connection.reply_read(state, key, 3)
    assert cancelled.streams[key].input == "retained"
    assert cancelled.streams[key].cancel == [{:reset, 0x10C}, {:stop, 0x10C}]
    assert {:error, :closed} = Operations.status(table, key, token)
    assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, 1_000
    refute_received {:http3_operation, _, _, :pending}
    :ok = Connection.terminate(:test_complete, cancelled)
    assert :ets.info(table) == :undefined
  end

  for bytes <- ["ready", ""] do
    test "a short read poll consumes buffered #{inspect(bytes)} and FIN after its soft wait" do
      {:ok, spec} =
        Options.normalize(endpoint: {Endpoint, %{}}, tls: %{certfile: "c", keyfile: "k"})

      {:ok, state} =
        Connection.init(%{gate: self(), limits: spec.limits}, %{}, spec.handler_options)

      key = make_ref()
      token = make_ref()
      deadline = Gaoxy.Lifecycle.deadline(2_000)
      {:ok, state} = Connection.handle_event({:stream_open, key, :bidi}, state)
      table = state.operations
      :ok = Operations.register(table, key, token, deadline)
      observer = self()

      {worker, monitor} =
        spawn_monitor(fn ->
          receive do
            :bound -> :ok
          end

          :ok = Operations.ready(table, key, token, make_ref())
          send(observer, {:short_read_ready, self()})

          receive do
            :activated -> :ok
          end

          operation = {:read, 16_384, {:until, Gaoxy.Lifecycle.now() - 1}}
          {:ok, ref} = Operations.submit(table, key, token, {operation, deadline})
          send(observer, {:short_read_submitted, self(), ref})

          receive do
            {:http3_operation, ^token, ^ref, result} ->
              :ok = Operations.ack(table, key, token, ref)
              send(observer, {:short_read_result, self(), result})
          end
        end)

      on_exit(fn -> if Process.alive?(worker), do: Process.exit(worker, :kill) end)
      :ok = Operations.bind(table, key, token, worker)
      send(worker, :bound)
      assert_receive {:short_read_ready, ^worker}, 1_000
      :ok = Operations.activate(table, key, token, worker)
      send(worker, :activated)
      assert_receive {:short_read_submitted, ^worker, _}, 1_000

      entry = %{
        state.streams[key]
        | token: token,
          worker: worker,
          deadline: deadline,
          input: unquote(bytes),
          recv_fin: true,
          trailers: [{"x-final", "seen"}]
      }

      state = %{
        state
        | ready: true,
          control: :opened_control,
          control_bytes: <<>>,
          streams: Map.put(state.streams, key, entry)
      }

      assert {:ok, next} = Connection.handle_event(:tick, state)

      assert_receive {:short_read_result, ^worker,
                      {:ok, unquote(bytes), true, [{"x-final", "seen"}]}},
                     1_000

      assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, 1_000
      assert next.streams[key].input == <<>>
      assert next.streams[key].operation == nil
      :ok = Connection.terminate(:test_complete, next)
    end
  end
end
