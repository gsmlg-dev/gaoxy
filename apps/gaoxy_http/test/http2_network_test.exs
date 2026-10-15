defmodule Gaoxy.HTTP2NetworkTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Exchange, Response}

  defmodule Endpoint do
    def init(options), do: {:ok, options}

    def call(exchange, options) do
      case exchange.request.path do
        "/identity-hold" ->
          send(options[:owner], {:identity, self(), exchange.transport_state})

          receive do
            :release -> Response.send_resp(exchange, 200, [], "released")
          after
            1_000 -> {:error, :timeout, exchange}
          end

        path when path in ["/queued", "/blocked"] ->
          if options[:owner],
            do: send(options[:owner], {:response_started, path, self(), exchange.transport_state})

          Response.send_resp(exchange, 200, [], path)

        "/fragmented" ->
          send(options[:owner], {:fragmented, self()})

          value =
            String.duplicate(
              "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz",
              450
            )

          Response.send_resp(exchange, 200, [{"x-large", value}], "fragmented")

        "/hold" ->
          send(options[:owner], {:held, self()})

          receive do
            :release -> Response.send_resp(exchange, 200, [], "released")
          after
            1_000 -> {:error, :timeout, exchange}
          end

        "/echo" ->
          case read(exchange, "") do
            {:ok, body, exchange} ->
              Response.send_resp(exchange, 200, [{"x-protocol", "h2"}], body)

            {:error, reason, exchange} ->
              {:error, reason, exchange}
          end

        "/large-credit" ->
          case Exchange.read_body_step(exchange, 65_536, 500) do
            {:ok, bytes, next} -> Response.send_resp(next, 200, [], bytes)
            {:more, bytes, next} -> Response.send_resp(next, 200, [], bytes)
            {:error, reason, next} -> {:error, reason, next}
          end

        "/poll" ->
          send(options[:owner], {:polling, self()})
          started = System.monotonic_time(:millisecond)
          result = Exchange.poll_connection(exchange, 180)
          send(options[:owner], {:polled, result, System.monotonic_time(:millisecond) - started})

          case result do
            {:pending, next} -> Response.send_resp(next, 200, [], "polled")
            {:error, reason, next} -> {:error, reason, next}
          end

        "/stream" ->
          with {:ok, exchange} <- Response.send_chunked(exchange, 200, [{"trailer", "x-check"}]),
               {:ok, exchange} <- Response.chunk(exchange, "one"),
               {:ok, exchange} <- Response.chunk(exchange, "two"),
               {:ok, exchange} <- Response.finish(exchange, [{"x-check", "value"}]),
               do: {:ok, exchange}

        "/renderer-hold" ->
          renderer_hold(exchange, options)

        path
        when path in ["/renderer-head255", "/renderer-trailer128", "/renderer-empty-trailers"] ->
          renderer_cardinality(exchange, options)

        "/returned-error" ->
          {:ok, committed} = Response.send_chunked(exchange, 200, [])
          {:ok, committed} = Response.chunk(committed, "progress-prefix")
          send(options[:owner], {:returned_error_ready, self()})

          receive do
            :return_error ->
              send(options[:owner], {:returned_error_released, self()})
              {:error, :intentional_endpoint_error, committed}
          after
            1_000 -> {:error, :release_timeout, committed}
          end

        "/prehead-error" ->
          {:error, :intentional_endpoint_error, exchange}

        path when path in ["/deadline-data", "/deadline-head", "/deadline-trailers"] ->
          deadline_write(exchange, options)

        "/deadline-fragmented" ->
          exchange = %{exchange | limits: %{exchange.limits | write_timeout: 80}}
          send(options[:owner], {:fragment_deadline_ready, self(), exchange.transport_state})

          receive do
            :write ->
              value =
                String.duplicate(
                  "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz",
                  450
                )

              result = Response.send_chunked(exchange, 200, [{"x-large", value}])
              send(options[:owner], {:fragment_deadline_result, self(), result})
              deadline_outcome(result, exchange)
          after
            2_000 -> {:error, :write_release_timeout, exchange}
          end

        "/full-window-sibling" ->
          Response.send_resp(exchange, 200, [], :binary.copy("c", 65_535))

        "/deadline-socket" ->
          exchange = %{exchange | limits: %{exchange.limits | write_timeout: 80}}
          {:ok, exchange} = Response.send_chunked(exchange, 200, [])
          send(options[:owner], {:socket_deadline_ready, self(), exchange.transport_state})

          receive do
            :write ->
              bytes = List.duplicate(:binary.copy("s", 65_536), 256)
              result = Response.chunk(exchange, bytes)
              send(options[:owner], {:socket_deadline_result, self(), result})
              deadline_outcome(result, exchange)
          after
            2_000 -> {:error, :write_release_timeout, exchange}
          end

        path when path in ["/completed-502", "/completed-504"] ->
          status = if path == "/completed-502", do: 502, else: 504
          {:ok, sent} = Response.send_resp(exchange, status, [], "completed-#{status}")
          {:error, :intentional_endpoint_error, sent}

        _ ->
          Response.send_resp(exchange, 200, [], exchange.request.path)
      end
    end

    defp read(exchange, body) do
      case Exchange.read_body(exchange, 4, 500) do
        {:ok, bytes, exchange} -> {:ok, body <> bytes, exchange}
        {:more, bytes, exchange} -> read(exchange, body <> bytes)
        {:error, reason} -> {:error, reason, exchange}
      end
    end

    defp renderer_hold(exchange, options) do
      send(options[:owner], {:renderer_ready, self(), exchange.transport_state})

      receive do
        :head ->
          value =
            String.duplicate(
              "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz",
              450
            )

          {:ok, streaming} =
            Response.send_chunked(exchange, 200, [{"x-large", value}, {"trailer", "x-check"}])

          send(options[:owner], {:renderer_written, :head, self()})

          receive do
            :trailers ->
              trailers = [{"x-check", "value"}]
              {:ok, finished} = Response.finish(streaming, trailers)
              send(options[:owner], {:renderer_written, :trailers, self()})

              receive do
                :retry ->
                  results = [
                    Response.send_chunked(exchange, 201, []),
                    Response.finish(streaming, trailers),
                    Response.finish(streaming, trailers)
                  ]

                  send(options[:owner], {:renderer_retries, self(), results})

                  receive do
                    :release -> {:ok, finished}
                  after
                    2_000 -> {:error, :release_timeout, finished}
                  end
              after
                2_000 -> {:error, :retry_timeout, finished}
              end
          after
            2_000 -> {:error, :trailers_timeout, streaming}
          end
      after
        2_000 -> {:error, :head_timeout, exchange}
      end
    end

    defp renderer_cardinality(exchange, options) do
      send(options[:owner], {:renderer_cardinality_ready, self(), exchange.transport_state})

      receive do
        :write ->
          fields =
            case exchange.request.path do
              "/renderer-head255" ->
                for index <- 1..255, do: {"x-check", Integer.to_string(index)}

              "/renderer-trailer128" ->
                [{"trailer", "x-check"}]

              "/renderer-empty-trailers" ->
                []
            end

          {result, current} =
            case Response.send_chunked(exchange, 200, fields) do
              {:ok, streaming} ->
                result =
                  case exchange.request.path do
                    "/renderer-head255" ->
                      Response.finish(streaming)

                    "/renderer-trailer128" ->
                      Response.finish(
                        streaming,
                        for(index <- 1..128, do: {"x-check", Integer.to_string(index)})
                      )

                    "/renderer-empty-trailers" ->
                      case streaming.transport.operation(streaming, {:trailers, []}) do
                        :ok -> {:ok, %{streaming | response: :sent}}
                        error -> error
                      end
                  end

                {result, streaming}

              error ->
                {error, exchange}
            end

          outcome =
            case result do
              {:ok, _} -> :ok
              error -> error
            end

          send(options[:owner], {:renderer_cardinality_result, self(), outcome})

          case result do
            {:ok, _} -> result
            {:error, reason} -> {:error, reason, current}
          end
      after
        1_000 -> {:error, :write_release_timeout, exchange}
      end
    end

    defp deadline_write(exchange, options) do
      exchange = %{exchange | limits: %{exchange.limits | write_timeout: 80}}

      exchange =
        if exchange.request.path == "/deadline-head" do
          exchange
        else
          fields =
            if exchange.request.path == "/deadline-trailers",
              do: [{"trailer", "x-check"}],
              else: []

          {:ok, exchange} = Response.send_chunked(exchange, 200, fields)
          exchange
        end

      send(
        options[:owner],
        {:deadline_ready, exchange.request.path, self(), exchange.transport_state}
      )

      receive do
        :write ->
          result = deadline_operation(exchange, "blocked")
          send(options[:owner], {:deadline_result, self(), result})

          receive do
            :retry ->
              send(
                options[:owner],
                {:deadline_retry_result, self(), deadline_operation(exchange, "late")}
              )

              receive do
                :settle -> deadline_outcome(result, exchange)
              after
                2_000 -> {:error, :settle_timeout, exchange}
              end

            :settle ->
              deadline_outcome(result, exchange)
          after
            2_000 -> {:error, :settle_timeout, exchange}
          end
      after
        2_000 -> {:error, :write_release_timeout, exchange}
      end
    end

    defp deadline_operation(%{request: %{path: "/deadline-data"}} = exchange, bytes),
      do: Response.chunk(exchange, bytes)

    defp deadline_operation(%{request: %{path: "/deadline-head"}} = exchange, _),
      do: Response.send_resp(exchange, 200, [], "")

    defp deadline_operation(exchange, _), do: Response.finish(exchange, [{"x-check", "value"}])

    defp deadline_outcome({:error, reason}, exchange), do: {:error, reason, exchange}
    defp deadline_outcome(result, _exchange), do: result
  end

  test "prior knowledge is explicit and rejects the insufficient core byte budget" do
    assert {:error, :http2_byte_budget} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               protocols: [:http2],
               h2c: :prior_knowledge
             )

    assert {:error, :invalid_http_protocols} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               protocols: [:http2, :http1],
               h2c: :prior_knowledge
             )
  end

  test "two concurrent streams preserve bodies and response semantics" do
    {socket, _} = connect()
    send_headers(socket, 1, "/echo", false, [{"content-length", "6"}])
    send_headers(socket, 3, "/other", true)
    :ok = :gen_tcp.send(socket, frame(0, 1, 1, "abcdef"))
    results = responses(socket, [1, 3])
    assert results[1].body == "abcdef"
    assert results[3].body == "/other"
    assert {":status", "200"} in results[1].headers

    refute Enum.any?(results[1].headers, fn {name, _} ->
             name in ["connection", "transfer-encoding"]
           end)
  end

  test "a stalled endpoint does not block a sibling and reset terminates only its worker" do
    {socket, _} = connect(owner: self())
    send_headers(socket, 1, "/hold", true)
    assert_receive {:held, worker}, 1_000
    monitor = Process.monitor(worker)
    send_headers(socket, 3, "/live", true)
    assert responses(socket, [3])[3].body == "/live"
    :ok = :gen_tcp.send(socket, frame(3, 0, 1, <<8::32>>))
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    send_headers(socket, 5, "/again", true)
    assert responses(socket, [5])[5].body == "/again"
  end

  test "zero stream write window leaves a ready sibling and control traffic live" do
    {socket, _} = connect()
    :ok = :gen_tcp.send(socket, frame(4, 0, 0, <<4::16, 0::32>>))
    send_headers(socket, 1, "/blocked", true)
    send_headers(socket, 3, "/ready", true)
    :ok = :gen_tcp.send(socket, frame(8, 0, 3, <<0::1, 32::31>>))
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "12345678"))
    assert responses(socket, [3])[3].body == "/ready"
    :ok = :gen_tcp.send(socket, frame(8, 0, 1, <<0::1, 32::31>>))
    assert responses(socket, [1])[1].body == "/blocked"
  end

  @tag :write_deadline
  test "zero flow credit expires a narrowed DATA write without killing its cleanup owner or replaying" do
    {socket, server} = connect(owner: self(), http_limits: %{request_timeout: 5_000})
    :ok = :gen_tcp.send(socket, frame(4, 0, 0, <<4::16, 0::32>>))
    send_headers(socket, 1, "/deadline-data", true)
    assert_receive {:deadline_ready, "/deadline-data", worker, {owner, 1, _}}, 1_000
    assert_status(socket, 1, "200")
    monitor = Process.monitor(worker)
    started = System.monotonic_time(:millisecond)
    send(worker, :write)
    assert_receive {:deadline_result, ^worker, {:error, :timeout}}, 1_000
    assert System.monotonic_time(:millisecond) - started < 1_000
    assert Process.alive?(worker)
    {_, pending} = :sys.get_state(owner)
    assert pending.streams[1].worker == worker

    :ok = :gen_tcp.send(socket, frame(8, 0, 1, <<0::1, 32::31>>))
    send(worker, :retry)
    assert_receive {:deadline_retry_result, ^worker, {:error, _}}, 1_000
    send(worker, :settle)
    assert_reset(socket, 1, 0x8)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    send_headers(socket, 3, "/sibling-after-write-timeout", true)
    :ok = :gen_tcp.send(socket, frame(8, 0, 3, <<0::1, 64::31>>))
    result = responses(socket, [3], %{}, [1])
    assert result[3].body == "/sibling-after-write-timeout"
    refute Map.has_key?(result, 1), inspect(result)
    await_stream_completion(server, Gaoxy.Lifecycle.deadline(1_000))
  end

  for path <- ["/deadline-head", "/deadline-trailers"] do
    @tag :write_deadline
    test "#{path} expires while queued behind a writer operation without late response or fallback" do
      path = unquote(path)
      {socket, server} = connect(owner: self(), http_limits: %{request_timeout: 5_000})
      send_headers(socket, 1, path, true)
      assert_receive {:deadline_ready, ^path, worker, {owner, 1, _}}, 1_000

      if path == "/deadline-trailers" do
        assert {1, 4, 1, bytes} = recv_response_head(socket)
        assert {:ok, fields, _} = HPAX.decode(bytes, HPAX.new(4_096))
        assert {":status", "200"} in fields
        assert {"trailer", "x-check"} in fields
      end

      await_h2(owner, fn state ->
        state.writer_ready and state.inflight == nil and :queue.is_empty(state.output)
      end)

      writer = writer_for(owner, worker)
      assert :erlang.suspend_process(writer)
      on_exit(fn -> resume_writer(writer) end)
      :ok = :gen_tcp.send(socket, frame(6, 0, 0, "deadline"))
      await_h2(owner, fn state -> match?({_, nil}, state.inflight) end)
      monitor = Process.monitor(worker)
      send(worker, :write)
      await_h2(owner, fn state -> :queue.len(state.output) > 0 end)
      assert_receive {:deadline_result, ^worker, {:error, :timeout}}, 1_000
      assert Process.alive?(worker)
      {_, expired} = :sys.get_state(owner)
      assert expired.streams[1].worker == worker

      refute Enum.any?(:queue.to_list(expired.output), fn
               {_, {:headers, 1, _}, _} -> true
               {_, {:header_fragment, 1}, _} -> true
               _ -> false
             end)

      send(worker, :retry)
      assert_receive {:deadline_retry_result, ^worker, {:error, _}}, 1_000
      assert :erlang.resume_process(writer)
      assert_ping(socket, "deadline")
      send(worker, :settle)
      assert_reset(socket, 1, 0x8)
      assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
      send_headers(socket, 3, "/sibling-after-queued-timeout", true)
      result = responses(socket, [3], %{}, [1])
      assert result[3].body == "/sibling-after-queued-timeout"
      refute Map.has_key?(result, 1), inspect(result)
      await_stream_completion(server, Gaoxy.Lifecycle.deadline(1_000))
    end
  end

  @tag :write_deadline
  test "an expired head in the Writer mailbox rejects a stale success callback and preserves its sibling" do
    {socket, server} = connect(owner: self(), http_limits: %{request_timeout: 5_000})
    send_headers(socket, 1, "/deadline-head", true)
    assert_receive {:deadline_ready, "/deadline-head", worker, {owner, 1, _}}, 1_000

    await_h2(owner, fn state ->
      state.writer_ready and state.inflight == nil and :queue.is_empty(state.output)
    end)

    writer = writer_for(owner, worker)
    assert :erlang.suspend_process(writer)
    on_exit(fn -> resume_writer(writer) end)
    send(worker, :write)
    await_h2(owner, fn state -> match?({_, {:headers, 1, _}}, state.inflight) end)
    {_, pending} = :sys.get_state(owner)
    {token, _callback} = pending.inflight
    assert_receive {:deadline_result, ^worker, {:error, :timeout}}, 1_000
    assert Process.alive?(worker)

    # The operation has expired. A delayed success notification for that exact
    # frame must not revive it, acknowledge it, or admit a fallback response.
    send(owner, {:h2_written, writer, token, :ok})
    send(worker, :retry)
    assert_receive {:deadline_retry_result, ^worker, {:error, _}}, 1_000
    assert :erlang.resume_process(writer)
    send(worker, :settle)
    assert_reset(socket, 1, 0x8)
    assert Process.alive?(writer)
    send_headers(socket, 3, "/sibling-after-mailbox-timeout", true)
    result = responses(socket, [3], %{}, [1])
    assert result[3].body == "/sibling-after-mailbox-timeout"
    refute Map.has_key?(result, 1), inspect(result)
    await_stream_completion(server, Gaoxy.Lifecycle.deadline(1_000))
  end

  @tag :write_deadline
  test "expiry after a physical HEADERS fragment closes without late CONTINUATION or success" do
    {socket, server} = connect(owner: self(), http_limits: %{request_timeout: 5_000})
    send_headers(socket, 1, "/deadline-fragmented", true)
    assert_receive {:fragment_deadline_ready, worker, {owner, 1, _}}, 1_000
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "fragtime"))
    assert_ping(socket, "fragtime")

    await_h2(owner, fn state ->
      state.writer_ready and state.inflight == nil and :queue.is_empty(state.output)
    end)

    writer = writer_for(owner, worker)
    assert :erlang.suspend_process(writer)
    on_exit(fn -> resume_writer(writer) end)
    send(worker, :write)
    await_h2(owner, fn state -> match?({_, {:header_fragment, 1}}, state.inflight) end)
    :ok = :sys.suspend(owner)
    on_exit(fn -> resume_owner(owner) end)
    assert :erlang.resume_process(writer)

    # The owner cannot schedule a CONTINUATION until resumed. Observing this
    # complete first frame establishes real socket progress before expiry.
    assert {1, 0, 1, first} = recv_frame(socket)
    assert byte_size(first) == 16_384
    assert :erlang.suspend_process(writer)
    owner_monitor = Process.monitor(owner)
    worker_monitor = Process.monitor(worker)
    writer_monitor = Process.monitor(writer)
    :ok = :sys.resume(owner)
    assert {:error, :closed} = :gen_tcp.recv(socket, 9, 1_000)
    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, _}, 1_000
    assert_receive {:DOWN, ^worker_monitor, :process, ^worker, _}, 1_000
    resume_writer(writer)
    assert_receive {:DOWN, ^writer_monitor, :process, ^writer, _}, 1_000
    refute_receive {:fragment_deadline_result, ^worker, {:ok, _}}, 0
    await_restored(server)
    assert Gaoxy.info(server, :http).mode == :ready
  end

  @tag :write_deadline
  test "DATA expiry in the Writer mailbox returns full flow credit to a healthy sibling" do
    {socket, server} = connect(owner: self(), http_limits: %{request_timeout: 5_000})
    send_headers(socket, 1, "/deadline-data", true)
    assert_receive {:deadline_ready, "/deadline-data", worker, {owner, 1, _}}, 1_000
    assert_status(socket, 1, "200")

    await_h2(owner, fn state ->
      state.writer_ready and state.inflight == nil and :queue.is_empty(state.output)
    end)

    {_, initial} = :sys.get_state(owner)
    assert initial.send_window == 65_535
    stream_credit = initial.streams[1].send_window
    writer = writer_for(owner, worker)
    assert :erlang.suspend_process(writer)
    on_exit(fn -> resume_writer(writer) end)
    send(worker, :write)
    await_h2(owner, fn state -> match?({_, {:data, 1, true, _}}, state.inflight) end)
    {_, pending} = :sys.get_state(owner)
    assert pending.send_window == initial.send_window - byte_size("blocked")
    assert pending.streams[1].send_window == stream_credit - byte_size("blocked")
    assert_receive {:deadline_result, ^worker, {:error, :timeout}}, 1_000
    assert Process.alive?(worker)
    assert :erlang.resume_process(writer)
    await_h2(owner, fn state -> state.inflight == nil end)
    {_, restored} = :sys.get_state(owner)
    assert restored.send_window == initial.send_window
    assert restored.streams[1].send_window == stream_credit
    assert Process.alive?(writer)
    send(worker, :settle)
    assert_reset(socket, 1, 0x8)

    # No connection or stream WINDOW_UPDATE is sent. The sibling consumes the
    # entire original connection credit and must still reach END_STREAM.
    send_headers(socket, 3, "/full-window-sibling", true)
    result = responses(socket, [3], %{}, [1])
    assert result[3].body == :binary.copy("c", 65_535)
    refute Map.has_key?(result, 1), inspect(result)
    await_stream_completion(server, Gaoxy.Lifecycle.deadline(1_000))
  end

  @tag :write_deadline
  test "a real blocked H2 socket send times out fatally before request expiry and keeps its listener healthy" do
    {socket, server} =
      connect(
        owner: self(),
        http_limits: %{request_timeout: 5_000},
        client_socket_options: [recbuf: 1_024, buffer: 1_024]
      )

    bytes = 16_777_216
    :ok = :gen_tcp.send(socket, frame(4, 0, 0, <<4::16, bytes::32>>))
    :ok = :gen_tcp.send(socket, frame(8, 0, 0, <<0::1, bytes - 65_535::31>>))
    send_headers(socket, 1, "/deadline-socket", true)
    assert_receive {:socket_deadline_ready, worker, {owner, 1, _}}, 1_000
    assert_status(socket, 1, "200")
    owner_monitor = Process.monitor(owner)
    reference = make_ref()
    generation = Gaoxy.info(server, :http).generation

    :ok =
      :telemetry.attach(
        reference,
        [:gaoxy, :send],
        &__MODULE__.observe_socket_send/4,
        {self(), generation}
      )

    on_exit(fn -> :telemetry.detach(reference) end)
    started = System.monotonic_time(:millisecond)
    send(worker, :write)

    # Sufficient peer credit covers the whole body; only the non-reading TCP
    # peer can stall transmission. Public telemetry records the actual send.
    assert_socket_send_timeout(Gaoxy.Lifecycle.deadline(2_000))
    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, _}, 1_000
    assert System.monotonic_time(:millisecond) - started < 3_000
    refute_receive {:socket_deadline_result, ^worker, {:ok, _}}, 0
    :ok = :gen_tcp.close(socket)
    await_restored(server)

    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, healthy} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)
    on_exit(fn -> :gen_tcp.close(healthy) end)
    :ok = :gen_tcp.send(healthy, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", frame(4, 0, 0, "")])
    send_headers(healthy, 1, "/healthy-after-socket-timeout", true)
    assert responses(healthy, [1])[1].body == "/healthy-after-socket-timeout"
  end

  test "response trailers terminate streaming without H1 chunk framing" do
    {socket, _} = connect()
    send_headers(socket, 1, "/stream", true)
    result = responses(socket, [1])[1]
    assert result.body == "onetwo"
    assert {"x-check", "value"} in result.headers
    refute {"transfer-encoding", "chunked"} in result.headers
  end

  test "a returned endpoint error resets its committed response without success END_STREAM" do
    {socket, server} = connect(owner: self())
    send_headers(socket, 1, "/returned-error", true)
    assert_receive {:returned_error_ready, worker}, 1_000
    monitor = Process.monitor(worker)
    assert_status(socket, 1, "200")
    assert {0, 0, 1, "progress-prefix"} = recv_frame(socket)

    send(worker, :return_error)
    assert_receive {:returned_error_released, ^worker}, 1_000
    assert_reset(socket, 1, 0x8)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    send_headers(socket, 3, "/sibling-after-error", true)
    sibling = responses(socket, [3], %{}, [1])[3]
    assert sibling.body == "/sibling-after-error"
    assert Enum.filter(sibling.headers, &(elem(&1, 0) == ":status")) == [{":status", "200"}]
    await_stream_completion(server, Gaoxy.Lifecycle.deadline(1_000))
  end

  test "a returned endpoint error before headers produces a complete 500 and keeps its sibling live" do
    {socket, _} = connect()
    send_headers(socket, 1, "/prehead-error", true)
    result = responses(socket, [1], %{}, [1])[1]
    assert result.body == ""
    assert Enum.filter(result.headers, &(elem(&1, 0) == ":status")) == [{":status", "500"}]
    send_headers(socket, 3, "/sibling-after-prehead-error", true)
    assert responses(socket, [3], %{}, [1])[3].body == "/sibling-after-prehead-error"
  end

  test "a returned endpoint error preserves already completed 502 and 504 responses" do
    {socket, _} = connect()

    for {status, id} <- [{502, 1}, {504, 5}] do
      send_headers(socket, id, "/completed-#{status}", true)
      result = responses(socket, [id], %{}, [id])[id]
      assert result.body == "completed-#{status}"

      assert Enum.filter(result.headers, &(elem(&1, 0) == ":status")) ==
               [{":status", Integer.to_string(status)}]

      send_headers(socket, id + 2, "/sibling-after-#{status}", true)
      assert responses(socket, [id + 2], %{}, [id])[id + 2].body == "/sibling-after-#{status}"
    end
  end

  test "continuation exclusivity is a connection error" do
    {socket, _} = connect()
    :ok = :gen_tcp.send(socket, frame(1, 0, 1, <<0x82>>))
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "12345678"))
    assert goaway(socket) == 1
  end

  @tag :idle_window
  test "WINDOW_UPDATE on an idle stream is a connection error even with a zero increment" do
    for increment <- [0, 1] do
      {socket, _} = connect()
      :ok = :gen_tcp.send(socket, frame(8, 0, 1, <<increment::32>>))
      assert goaway(socket) == 1
    end
  end

  @tag :priority_length
  test "malformed PRIORITY length resets its stream while the exact sibling survives" do
    {socket, _} = connect(owner: self())
    send_headers(socket, 1, "/hold", true)
    assert_receive {:held, _}, 1_000
    :ok = :gen_tcp.send(socket, frame(2, 0, 1, "x"))
    assert_reset(socket, 1, 6)
    send_headers(socket, 3, "/sibling", true)
    assert responses(socket, [3])[3].body == "/sibling"
  end

  test "a closed stream consumes HPACK changes before resetting and a sibling can use them" do
    {socket, server} = connect()
    send_headers(socket, 1, "/first", true)
    assert responses(socket, [1])[1].body == "/first"
    await_stream_completion(server, Gaoxy.Lifecycle.deadline(1_000))

    {closed_block, encoder} = HPAX.encode(:store, [{"x-context", "kept"}], HPAX.new(4_096))
    :ok = :gen_tcp.send(socket, frame(1, 5, 1, closed_block))
    assert {3, _, 1, <<5::32>>} = recv_frame(socket)

    {next_block, _} =
      HPAX.encode(
        :no_store,
        [
          {":method", "GET"},
          {":scheme", "http"},
          {":authority", "localhost"},
          {":path", "/sibling"},
          {"x-context", "kept"}
        ],
        encoder
      )

    :ok = :gen_tcp.send(socket, frame(1, 5, 3, next_block))
    assert responses(socket, [3])[3].body == "/sibling"
  end

  test "an oversized first compressed fragment is rejected before CONTINUATION arrives" do
    {socket, _} = connect(h2_limits: %{max_header_block: 64, frame_timeout: 250})
    :ok = :gen_tcp.send(socket, frame(1, 0, 1, :binary.copy(<<0>>, 65)))
    assert goaway(socket) == 11
  end

  test "body credit above the H2 transport window is clamped while preserving the payload" do
    {socket, _} = connect(http_limits: %{max_read_chunk: 65_536, max_buffer_bytes: 131_072})
    send_headers(socket, 1, "/large-credit", false, [{"content-length", "5"}])
    :ok = :gen_tcp.send(socket, frame(0, 1, 1, "hello"))
    assert responses(socket, [1])[1].body == "hello"
  end

  test "a finite connection poll waits without delaying another stream or control frames" do
    {socket, _} = connect(owner: self())
    send_headers(socket, 1, "/poll", true)
    assert_receive {:polling, _}, 1_000
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "pollping"))
    assert_ping(socket, "pollping")
    send_headers(socket, 3, "/live", true)
    assert responses(socket, [3])[3].body == "/live"
    assert_receive {:polled, {:pending, _}, elapsed}, 1_000
    assert elapsed >= 150
    assert elapsed < 800
    assert responses(socket, [1])[1].body == "polled"
  end

  test "a self-dependent HEADERS priority still updates HPACK before its stream error" do
    {socket, _} = connect()

    {block, encoder} =
      HPAX.encode(
        :store,
        [
          {":method", "GET"},
          {":scheme", "http"},
          {":authority", "localhost"},
          {":path", "/rejected"},
          {"x-context", "kept"}
        ],
        HPAX.new(4_096)
      )

    :ok = :gen_tcp.send(socket, frame(1, 37, 1, [<<0::1, 1::31, 0>>, block]))
    assert_reset(socket, 1, 1)

    {next, _} =
      HPAX.encode(
        :no_store,
        [
          {":method", "GET"},
          {":scheme", "http"},
          {":authority", "localhost"},
          {":path", "/sibling"},
          {"x-context", "kept"}
        ],
        encoder
      )

    :ok = :gen_tcp.send(socket, frame(1, 5, 3, next))
    assert responses(socket, [3])[3].body == "/sibling"
  end

  test "body demand emits H2 Continue once before the peer uploads" do
    {socket, _} = connect()
    send_headers(socket, 1, "/echo", false, [{"content-length", "5"}, {"expect", "100-continue"}])
    assert_status(socket, 1, "100")
    :ok = :gen_tcp.send(socket, frame(0, 1, 1, "hello"))
    result = responses(socket, [1])[1]
    assert result.body == "hello"
    assert Enum.filter(result.headers, &(elem(&1, 0) == ":status")) == [{":status", "200"}]
  end

  test "pause refuses new streams while admitted work and PING continue on the existing connection" do
    {socket, server} = connect(owner: self())
    local = Gaoxy.info(server, :http).local
    send_headers(socket, 1, "/hold", true)
    assert_receive {:held, worker}, 1_000
    assert Gaoxy.info(server, :http).pause == :unbind_rebind
    assert :ok = Gaoxy.pause(server, :http)
    assert Gaoxy.info(server, :http).local == :error
    {:ok, {ip, port}} = local
    assert {:error, :econnrefused} = :gen_tcp.connect(ip, port, [:binary, active: false], 100)
    send_headers(socket, 3, "/refused", true)
    assert_reset(socket, 3, 7)
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "pausedok"))
    assert_ping(socket, "pausedok")
    send(worker, :release)
    assert responses(socket, [1])[1].body == "released"
    assert :ok = Gaoxy.resume(server, :http)
    assert {:ok, {^ip, resumed_port}} = Gaoxy.info(server, :http).local

    assert {:ok, resumed_socket} =
             :gen_tcp.connect(ip, resumed_port, [:binary, active: false], 100)

    :gen_tcp.close(resumed_socket)
    send_headers(socket, 5, "/resumed", true)
    assert responses(socket, [5])[5].body == "/resumed"
  end

  test "drain emits GOAWAY and finishes admitted work before its single service deadline" do
    {socket, server} = connect(owner: self())
    send_headers(socket, 1, "/hold", true)
    assert_receive {:held, worker}, 1_000
    task = Task.async(fn -> Gaoxy.stop(server, 500) end)
    assert_goaway(socket, 1, 0)
    send(worker, :release)
    assert responses(socket, [1])[1].body == "released"
    assert :ok = Task.await(task, 1_000)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1_000)
  end

  for kind <- [:head255, :trailer128, :empty_trailers] do
    @renderer_kind kind
    @renderer_trailers if(kind == :trailer128,
                         do: for(index <- 1..128, do: {"x-check", Integer.to_string(index)}),
                         else: []
                       )
    @tag :renderer_proof
    test "native H2 #{@renderer_kind} preserves exact public HPAX bytes and ordered fields within existing renderer bounds" do
      {socket, server} =
        connect(
          owner: self(),
          http_limits: %{
            max_headers: 256,
            max_header_bytes: 65_536,
            max_trailers: 128,
            max_trailer_bytes: 65_536
          }
        )

      path =
        case @renderer_kind do
          :head255 -> "/renderer-head255"
          :trailer128 -> "/renderer-trailer128"
          :empty_trailers -> "/renderer-empty-trailers"
        end

      send_headers(socket, 1, path, true)
      assert_receive {:renderer_cardinality_ready, worker, {owner, 1, _}}, 1_000
      worker_monitor = Process.monitor(worker)
      owner_monitor = Process.monitor(owner)
      writer = writer_for(owner, worker)
      writer_monitor = Process.monitor(writer)
      server_monitor = Process.monitor(server)
      send(worker, :write)
      assert_receive {:renderer_cardinality_result, ^worker, outcome}, 1_000
      assert :ok = outcome

      fields =
        case @renderer_kind do
          :head255 -> for index <- 1..255, do: {"x-check", Integer.to_string(index)}
          :trailer128 -> [{"trailer", "x-check"}]
          :empty_trailers -> []
        end

      expected_head = [{":status", "200"} | fields]
      {expected_block, _} = HPAX.encode(:never_store, expected_head, HPAX.resize(HPAX.new(0), 0))
      assert {1, 4, 1, head} = recv_response_head(socket)
      assert head == IO.iodata_to_binary(expected_block)
      assert {:ok, ^expected_head, decoder} = HPAX.decode(head, HPAX.new(4_096))

      case @renderer_kind do
        :head255 ->
          assert {0, 1, 1, ""} = recv_frame(socket)

        kind when kind in [:trailer128, :empty_trailers] ->
          trailers = @renderer_trailers

          {expected_terminal, _} =
            HPAX.encode(:never_store, trailers, HPAX.resize(HPAX.new(0), 0))

          assert {1, 5, 1, terminal} = recv_frame(socket)
          assert terminal == IO.iodata_to_binary(expected_terminal)
          assert {:ok, ^trailers, _} = HPAX.decode(terminal, decoder)
      end

      assert_receive {:DOWN, ^worker_monitor, :process, ^worker, :normal}, 1_000
      await_stream_completion(server, Gaoxy.Lifecycle.deadline(1_000))
      assert :ok = :gen_tcp.close(socket)
      assert_receive {:DOWN, ^owner_monitor, :process, ^owner, _}, 1_000
      assert_receive {:DOWN, ^writer_monitor, :process, ^writer, _}, 1_000
      assert :ok = Gaoxy.stop(server, 1_000)
      assert_receive {:DOWN, ^server_monitor, :process, ^server, :normal}, 1_000
    end
  end

  @tag :renderer_proof
  test "full header writes release renderer projections before worker exit and reject repeated terminals" do
    {socket, _server} = connect(owner: self(), http_limits: %{request_timeout: 10_000})
    send_headers(socket, 1, "/renderer-hold", true)
    assert_receive {:renderer_ready, worker, {owner, 1, _}}, 1_000
    monitor = Process.monitor(worker)
    writer = writer_for(owner, worker)
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "render01"))
    assert_ping(socket, "render01")
    await_h2(owner, fn state -> state.inflight == nil and :queue.is_empty(state.output) end)
    assert :erlang.suspend_process(writer)
    on_exit(fn -> resume_writer(writer) end)

    send(worker, :head)
    await_h2(owner, fn state -> match?({_, {:header_fragment, 1}}, state.inflight) end)
    assert_renderer_projection(owner, writer, worker, 1, 2)
    refute_receive {:renderer_written, :head, ^worker}, 0
    assert :erlang.resume_process(writer)
    assert {1, 0, 1, first} = recv_response_head(socket)
    assert {9, 4, 1, last} = recv_frame(socket)
    assert {:ok, fields, _} = HPAX.decode(first <> last, HPAX.new(4_096))

    value =
      String.duplicate("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", 450)

    assert Enum.sort(fields) ==
             Enum.sort([{":status", "200"}, {"x-large", value}, {"trailer", "x-check"}])

    assert_receive {:renderer_written, :head, ^worker}, 1_000
    assert_renderer_released(owner, worker, 1)
    refute_receive {:DOWN, ^monitor, :process, ^worker, _}, 0

    assert :erlang.suspend_process(writer)
    send(worker, :trailers)
    await_h2(owner, fn state -> match?({_, {:headers, 1, _}}, state.inflight) end)
    assert_renderer_projection(owner, writer, worker, 1, 1)
    refute_receive {:renderer_written, :trailers, ^worker}, 0
    assert :erlang.resume_process(writer)
    assert {1, 5, 1, terminal} = recv_frame(socket)
    assert {:ok, [{"x-check", "value"}], _} = HPAX.decode(terminal, HPAX.new(4_096))
    assert_receive {:renderer_written, :trailers, ^worker}, 1_000
    assert_renderer_released(owner, worker, 1)
    refute_receive {:DOWN, ^monitor, :process, ^worker, _}, 0

    send(worker, :retry)

    assert_receive {:renderer_retries, ^worker,
                    [
                      {:error, :invalid_response_state},
                      {:error, :invalid_response_state},
                      {:error, :invalid_response_state}
                    ]},
                   1_000

    assert_renderer_released(owner, worker, 1)
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "render02"))
    assert_ping(socket, "render02")
    send_headers(socket, 3, "/renderer-sibling", true)
    assert {1, 4, 3, sibling_head} = recv_frame(socket)

    assert {:ok, [{":status", "200"}, {"content-length", "17"}], _} =
             HPAX.decode(sibling_head, HPAX.new(4_096))

    assert {0, 1, 3, "/renderer-sibling"} = recv_frame(socket)
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "render03"))
    assert_ping(socket, "render03")
    send(worker, :release)
    assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, 1_000
  end

  test "reset removes a response waiting behind another writer operation and preserves its sibling" do
    {socket, server} = connect(owner: self())
    send_headers(socket, 1, "/identity-hold", true)
    assert_receive {:identity, worker, {owner, 1, _token}}, 1_000
    writer = writer_for(owner, worker)
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "queuebar"))
    assert_ping(socket, "queuebar")
    await_h2(owner, fn state -> state.inflight == nil and :queue.is_empty(state.output) end)
    assert :erlang.suspend_process(writer)
    on_exit(fn -> resume_writer(writer) end)

    send_headers(socket, 3, "/blocked", true)
    assert_receive {:response_started, "/blocked", _, {^owner, 3, _}}, 1_000
    await_h2(owner, fn state -> match?({_, {:headers, 3, _}}, state.inflight) end)
    send_headers(socket, 5, "/queued", true)
    assert_receive {:response_started, "/queued", queued, {^owner, 5, _}}, 1_000
    await_h2(owner, fn state -> :queue.len(state.output) > 0 end)
    {_, pending} = :sys.get_state(owner)
    assert pending.streams[3].renderer_blocks == 1
    assert pending.streams[5].renderer_blocks == 1
    assert pending.streams[3].renderer_projection_bytes in 1..73_728
    assert pending.streams[5].renderer_projection_bytes in 1..73_728
    assert :erlang.external_size({pending.output, 5}) <= 73_728

    for {bytes, {:headers, 5, _}, _} <- :queue.to_list(pending.output) do
      assert is_binary(bytes)
      assert :binary.referenced_byte_size(bytes) == byte_size(bytes)
    end

    monitor = Process.monitor(queued)
    :ok = :gen_tcp.send(socket, frame(3, 0, 5, <<8::32>>))
    assert_receive {:DOWN, ^monitor, :process, ^queued, _}, 1_000
    {_, cancelled} = :sys.get_state(owner)
    refute Map.has_key?(cancelled.streams, 5)

    refute Enum.any?(:queue.to_list(cancelled.output), fn
             {_, {:headers, 5, _}, _} -> true
             {_, {:header_fragment, 5}, _} -> true
             _ -> false
           end)

    assert :erlang.resume_process(writer)
    result = responses(socket, [3])
    assert result[3].body == "/blocked"
    refute Map.has_key?(result, 5), inspect(result)
    send(worker, :release)
    assert responses(socket, [1])[1].body == "released"
    await_stream_completion(server, Gaoxy.Lifecycle.deadline(1_000))
  end

  test "reset preserves END_HEADERS for a header block already handed to the writer" do
    {socket, _server} = connect(owner: self())
    send_headers(socket, 1, "/identity-hold", true)
    assert_receive {:identity, worker, {owner, 1, _}}, 1_000
    writer = writer_for(owner, worker)
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "fragment"))
    assert_ping(socket, "fragment")
    await_h2(owner, fn state -> state.inflight == nil and :queue.is_empty(state.output) end)
    assert :erlang.suspend_process(writer)
    on_exit(fn -> resume_writer(writer) end)
    send_headers(socket, 3, "/fragmented", true)
    assert_receive {:fragmented, fragmented}, 1_000
    await_h2(owner, fn state -> state.inflight != nil and :queue.len(state.output) > 0 end)
    {_, pending} = :sys.get_state(owner)
    assert pending.streams[3].renderer_blocks == 1
    assert pending.streams[3].renderer_projection_bytes in 1..73_728
    assert :erlang.external_size({pending.output, 3}) <= 73_728

    queued_headers =
      for {bytes, {:headers, 3, _}, _} <- :queue.to_list(pending.output), do: bytes

    assert [_ | _] = queued_headers

    for bytes <- queued_headers do
      assert is_binary(bytes)
      assert :binary.referenced_byte_size(bytes) == byte_size(bytes)
    end

    monitor = Process.monitor(fragmented)
    :ok = :gen_tcp.send(socket, frame(3, 0, 3, <<8::32>>))
    assert_receive {:DOWN, ^monitor, :process, ^fragmented, _}, 1_000
    assert :erlang.resume_process(writer)
    assert {1, 0, 3, first} = recv_frame(socket)
    assert {9, 4, 3, last} = recv_frame(socket)
    assert {:ok, fields, _} = HPAX.decode(first <> last, HPAX.new(4_096))

    value =
      String.duplicate("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", 450)

    assert {"x-large", value} in fields
    send_headers(socket, 5, "/live-after-fragment", true)
    result = responses(socket, [5])
    assert result[5].body == "/live-after-fragment"
    refute Map.has_key?(result, 3), inspect(result)
    send(worker, :release)
    assert responses(socket, [1])[1].body == "released"
  end

  test "writer crash closes the owner and its admitted worker without affecting the listener" do
    {socket, server} = connect(owner: self())
    send_headers(socket, 1, "/identity-hold", true)
    assert_receive {:identity, worker, {owner, 1, _}}, 1_000
    writer = writer_for(owner, worker)
    monitors = for pid <- [owner, worker, writer], do: {pid, Process.monitor(pid)}
    Process.exit(writer, :kill)

    for {pid, monitor} <- monitors,
        do: assert_receive({:DOWN, ^monitor, :process, ^pid, _}, 1_000)

    until_closed(socket)
    await_restored(server)
    assert Gaoxy.info(server, :http).mode == :ready
  end

  test "owner crash closes its writer and stream and stale operations cannot commit a response" do
    {socket, server} = connect(owner: self())
    send_headers(socket, 1, "/identity-hold", true)
    assert_receive {:identity, worker, {owner, 1, token}}, 1_000

    assert {:error, :closed} =
             GenServer.call(owner, {:h2_operation, 1, token, {:head, 200, [], true}})

    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "stalecal"))
    assert_ping(socket, "stalecal")
    writer = writer_for(owner, worker)
    monitors = for pid <- [owner, worker, writer], do: {pid, Process.monitor(pid)}
    Process.exit(owner, :kill)

    for {pid, monitor} <- monitors,
        do: assert_receive({:DOWN, ^monitor, :process, ^pid, _}, 1_000)

    until_closed(socket)
    await_restored(server)
    assert Gaoxy.info(server, :http).mode == :ready
  end

  @tag :write_deadline
  test "a queued Writer operation cannot start after its owner dies and joins within its deadline" do
    {socket, server} = connect(owner: self(), http_limits: %{request_timeout: 5_000})
    send_headers(socket, 1, "/identity-hold", true)
    assert_receive {:identity, worker, {owner, 1, _}}, 1_000
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "deadowns"))
    assert_ping(socket, "deadowns")
    await_h2(owner, fn state -> state.inflight == nil and :queue.is_empty(state.output) end)
    writer = writer_for(owner, worker)
    assert :erlang.suspend_process(writer)
    on_exit(fn -> resume_writer(writer) end)
    send(worker, :release)
    await_h2(owner, fn state -> match?({_, {:headers, 1, _}}, state.inflight) end)
    {_, queued} = :sys.get_state(owner)
    assert Gaoxy.Lifecycle.remaining(queued.inflight_write.deadline) > 1_000
    generation = Gaoxy.info(server, :http).generation
    reference = make_ref()

    :ok =
      :telemetry.attach_many(
        reference,
        [[:gaoxy, :send_started], [:gaoxy, :send]],
        &__MODULE__.observe_dead_owner_send/4,
        {self(), generation, reference}
      )

    on_exit(fn -> :telemetry.detach(reference) end)
    owner_monitor = Process.monitor(owner)
    writer_monitor = Process.monitor(writer)
    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, _}, 1_000
    resume_writer(writer)
    assert_receive {:DOWN, ^writer_monitor, :process, ^writer, :normal}, 1_000
    assert {:error, :closed} = :gen_tcp.recv(socket, 9, 1_000)
    await_restored(server)
    refute_receive {^reference, _, _}, 0
    assert Gaoxy.info(server, :http).mode == :ready
  end

  @tag :tmp_dir
  test "independent Python h2 qualifies TCP and TLS ALPN with cross-process writes", %{
    tmp_dir: dir
  } do
    root = Path.expand("../../..", __DIR__)
    python = Path.join(root, ".audit/h2peer/bin/python")

    assert File.exists?(python),
           "install the pinned independent peer from test/support/h2-requirements.txt"

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), dir],
               stderr_to_stdout: true
             )

    for mode <- [:tcp, :tls] do
      options = [
        endpoint: {Endpoint, []},
        protocols: [:http2],
        limits: %{max_bytes: 536_870_912, max_active: 128},
        http_limits: %{request_timeout: 10_000}
      ]

      options =
        if mode == :tcp,
          do: Keyword.put(options, :h2c, :prior_knowledge),
          else:
            options ++
              [
                transport: :tls,
                tls: %{certfile: Path.join(dir, "cert.pem"), keyfile: Path.join(dir, "key.pem")}
              ]

      {:ok, server} = Gaoxy.HTTP.start_link(options)
      on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
      {:ok, {_, port}} = Gaoxy.info(server, :http).local

      assert {output, 0} =
               System.cmd(
                 python,
                 [
                   Path.join(__DIR__, "support/h2_peer.py"),
                   Integer.to_string(port),
                   if(mode == :tcp, do: "tcp", else: "tls"),
                   Path.join(dir, "ca.pem")
                 ],
                 stderr_to_stdout: true
               )

      assert output =~ "PASS independent Python h2"
    end
  end

  defp connect(options \\ []) do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint:
          {Endpoint, Keyword.drop(options, [:http_limits, :h2_limits, :client_socket_options])},
        protocols: [:http2],
        h2c: :prior_knowledge,
        limits: %{max_bytes: 536_870_912, max_active: 128},
        http_limits:
          Map.merge(%{request_timeout: 2_000}, Keyword.get(options, :http_limits, %{})),
        h2_limits: Keyword.get(options, :h2_limits, %{})
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    socket_options = [:binary, active: false] ++ Keyword.get(options, :client_socket_options, [])
    {:ok, socket} = :gen_tcp.connect(ip, port, socket_options, 1_000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    :ok = :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", frame(4, 0, 0, "")])
    {socket, server}
  end

  defp send_headers(socket, id, path, ended, extra \\ []) do
    fields =
      [
        {":method", if(path == "/echo", do: "POST", else: "GET")},
        {":scheme", "http"},
        {":authority", "localhost"},
        {":path", path}
      ] ++ extra

    {bytes, _} = HPAX.encode(:never_store, fields, HPAX.new(4_096))
    :ok = :gen_tcp.send(socket, frame(1, if(ended, do: 5, else: 4), id, bytes))
  end

  defp frame(type, flags, id, bytes) do
    [<<IO.iodata_length(bytes)::24, type, flags, 0::1, id::31>>, bytes]
  end

  defp recv_frame(socket) do
    {:ok, <<size::24, type, flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, 2_000)
    payload = if size == 0, do: "", else: elem(:gen_tcp.recv(socket, size, 2_000), 1)
    {type, flags, id, payload}
  end

  defp responses(socket, pending, result \\ %{}, forbidden_resets \\ []) do
    if pending == [] do
      result
    else
      {type, flags, id, payload} = recv_frame(socket)
      current = Map.get(result, id, %{body: "", headers: []})
      done = type in [0, 1] and Bitwise.band(flags, 1) == 1

      if done and id in forbidden_resets and id not in pending do
        flunk("unexpected successful END_STREAM on a settled response: #{inspect(id)}")
      end

      current =
        case type do
          1 ->
            {:ok, fields, _} = HPAX.decode(payload, HPAX.new(4_096))
            %{current | headers: current.headers ++ fields}

          0 ->
            %{current | body: current.body <> payload}

          4 when flags == 0 ->
            :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))
            current

          3 ->
            refute id in forbidden_resets,
                   "completed response was reset: #{inspect({id, payload})}"

            current

          _ ->
            current
        end

      responses(
        socket,
        if(done, do: List.delete(pending, id), else: pending),
        Map.put(result, id, current),
        forbidden_resets
      )
    end
  end

  defp goaway(socket) do
    case recv_frame(socket) do
      {7, _, 0, <<_::32, code::32, _::binary>>} ->
        code

      {4, 0, 0, _} ->
        :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))
        goaway(socket)

      _ ->
        goaway(socket)
    end
  end

  defp assert_ping(socket, payload) do
    case recv_frame(socket) do
      {6, 1, 0, ^payload} ->
        :ok

      {4, 0, 0, _} ->
        :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))
        assert_ping(socket, payload)

      {4, 1, 0, ""} ->
        assert_ping(socket, payload)

      other ->
        flunk("expected PING progress during poll, got #{inspect(other)}")
    end
  end

  defp assert_status(socket, id, status) do
    case recv_frame(socket) do
      {1, 4, ^id, payload} ->
        assert {:ok, [{":status", ^status}], _} = HPAX.decode(payload, HPAX.new(4_096))

      {4, 0, 0, _} ->
        :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))
        assert_status(socket, id, status)

      {4, 1, 0, ""} ->
        assert_status(socket, id, status)

      other ->
        flunk("expected informational status, got #{inspect(other)}")
    end
  end

  defp recv_response_head(socket) do
    case recv_frame(socket) do
      {4, 0, 0, _} ->
        :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))
        recv_response_head(socket)

      {4, 1, 0, ""} ->
        recv_response_head(socket)

      response ->
        response
    end
  end

  defp assert_reset(socket, id, code) do
    case recv_frame(socket) do
      {3, _, ^id, <<^code::32>>} ->
        :ok

      {4, 0, 0, _} ->
        :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))
        assert_reset(socket, id, code)

      {4, 1, 0, ""} ->
        assert_reset(socket, id, code)

      other ->
        flunk("expected stream reset, got #{inspect(other)}")
    end
  end

  defp assert_goaway(socket, last, code) do
    case recv_frame(socket) do
      {7, _, 0, <<^last::32, ^code::32, _::binary>>} ->
        :ok

      {4, 0, 0, _} ->
        :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))
        assert_goaway(socket, last, code)

      {4, 1, 0, ""} ->
        assert_goaway(socket, last, code)

      other ->
        flunk("expected GOAWAY, got #{inspect(other)}")
    end
  end

  defp await_stream_completion(server, deadline) do
    status = Gaoxy.status(server, :http)

    if status.active != 2 do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)

      receive do
      after
        1 -> await_stream_completion(server, deadline)
      end
    end
  end

  defp resume_writer(writer) do
    :erlang.resume_process(writer)
  rescue
    ArgumentError -> :ok
  end

  defp resume_owner(owner) do
    :sys.resume(owner)
  catch
    :exit, _ -> :ok
  end

  def observe_socket_send(
        _,
        measurements,
        %{generation: generation} = metadata,
        {caller, selected}
      )
      when generation == selected,
      do: send(caller, {:socket_send_outcome, measurements.bytes, metadata.outcome})

  def observe_socket_send(_, _, _, _), do: :ok

  def observe_dead_owner_send(
        event,
        measurements,
        %{generation: generation},
        {caller, selected, reference}
      )
      when generation == selected,
      do: send(caller, {reference, event, measurements.bytes})

  def observe_dead_owner_send(_, _, _, _), do: :ok

  defp assert_socket_send_timeout(deadline) do
    receive do
      {:socket_send_outcome, bytes, {:unknown, :timeout}} ->
        assert bytes in 10..16_393

      {:socket_send_outcome, _, :ok} ->
        assert_socket_send_timeout(deadline)

      {:socket_send_outcome, _, other} ->
        flunk("unexpected actual H2 socket send outcome: #{inspect(other)}")
    after
      Gaoxy.Lifecycle.remaining(deadline) -> flunk("actual H2 socket send did not time out")
    end
  end

  defp writer_for(owner, worker) do
    {_, state} = :sys.get_state(owner)
    writer = state.writer
    assert is_pid(writer) and writer != worker

    assert Enum.any?(Supervisor.which_children(Gaoxy.HTTP.Tasks), fn {_, pid, _, _} ->
             pid == writer
           end)

    writer
  end

  defp assert_renderer_projection(owner, writer, worker, id, frame_count) do
    {_, state} = :sys.get_state(owner)
    stream = state.streams[id]
    assert stream.worker == worker
    assert stream.renderer_blocks == 1
    assert stream.renderer_projection_bytes in 1..73_728
    assert %{kind: :headers, from: {^worker, _} = from, deadline: deadline} = stream.write
    assert {token, callback} = state.inflight
    assert %{id: ^id, deadline: ^deadline} = state.inflight_write
    assert state.inflight_started == false

    assert {:messages, [{:h2_write, ^owner, ^token, bytes, ^deadline}]} =
             Process.info(writer, :messages)

    entries = [{bytes, callback, deadline} | :queue.to_list(state.output)]

    case frame_count do
      1 ->
        assert [{_, {:headers, ^id, ^from}, ^deadline}] = entries

      2 ->
        assert [
                 {_, {:header_fragment, ^id}, ^deadline},
                 {_, {:headers, ^id, ^from}, ^deadline}
               ] = entries
    end

    assert stream.renderer_projection_bytes ==
             :erlang.external_size({:queue.from_list(entries), id})

    assert :erlang.external_size(entries) <= 73_728

    for {wire, callback, ^deadline} <- entries do
      assert is_binary(wire)
      assert :binary.referenced_byte_size(wire) == byte_size(wire)
      assert <<size::24, type, _flags, 0::1, ^id::31, payload::binary>> = wire
      assert size == byte_size(payload)
      assert size in 1..16_384
      assert type in [1, 9]
      assert callback == {:header_fragment, id} or callback == {:headers, id, from}
    end
  end

  defp assert_renderer_released(owner, worker, id) do
    await_h2(owner, fn state -> state.inflight == nil and :queue.is_empty(state.output) end)
    {_, state} = :sys.get_state(owner)

    assert %{worker: ^worker, write: nil, renderer_blocks: 0, renderer_projection_bytes: 0} =
             state.streams[id]

    assert Process.alive?(worker)
    assert state.outgoing_block == nil
    assert {:messages, []} = Process.info(state.writer, :messages)
  end

  defp await_h2(owner, predicate, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(1_000)
    {_, state} = :sys.get_state(owner)

    unless predicate.(state) do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0

      receive do
      after
        1 -> await_h2(owner, predicate, deadline)
      end
    end
  end

  defp until_closed(socket) do
    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, _} -> until_closed(socket)
      {:error, :closed} -> :ok
    end
  end

  defp await_restored(server, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(1_000)
    status = Gaoxy.status(server, :http)

    unless match?(%{active: 0, retained_bytes: 0, cleanup_pending: 0}, status) do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)

      receive do
      after
        1 -> await_restored(server, deadline)
      end
    end
  end
end
