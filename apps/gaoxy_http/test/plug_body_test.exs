defmodule Gaoxy.PlugBodyTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.{Exchange, HTTP1.Body, HTTP1.Parser}

  # Preserve the strict deadline assertions while distinguishing fixture waits
  # from time spent off-scheduler on shared CI runners. No request data is traced.
  setup context do
    if context[:deadline_trace] do
      tracer = spawn(fn -> deadline_events([], 0) end)
      Process.put(:deadline_tracer, tracer)
      :erlang.trace_pattern({:gen, :do_call, 4}, [{:_, [], [{:exception_trace}]}], [:local])
      :erlang.trace(self(), true, [:running, :call, :monotonic_timestamp, {:tracer, tracer}])

      on_exit(fn ->
        monitor = Process.monitor(tracer)

        try do
          delivery = :erlang.trace_delivered(:all)

          receive do
            {:trace_delivered, :all, ^delivery} -> :ok
          after
            1_000 -> flunk("deadline trace delivery did not complete")
          end

          send(tracer, {:report, self()})

          receive do
            {:deadline_events, events, dropped} ->
              events = Enum.sort_by(events, &elem(&1, 0))
              origin = events |> hd() |> elem(0)

              events =
                Enum.map(events, fn {time, event} ->
                  {System.convert_time_unit(time - origin, :native, :microsecond), event}
                end)

              IO.puts(
                "DEADLINE_TRACE " <>
                  inspect(
                    %{
                      test: context.test,
                      events_us: events,
                      dropped: dropped,
                      witness:
                        if(Enum.any?(events, &match?({_, {:deadline_witness, _}}, &1)),
                          do: :observed,
                          else: :not_observed_before_report
                        ),
                      logical_processors: :erlang.system_info(:logical_processors_available),
                      schedulers: :erlang.system_info(:schedulers_online)
                    },
                    limit: :infinity
                  )
              )
          after
            1_000 -> flunk("deadline trace collector did not respond")
          end
        after
          :erlang.trace_pattern({:gen, :do_call, 4}, false, [:local])
          Process.exit(tracer, :kill)

          receive do
            {:DOWN, ^monitor, :process, ^tracer, _} -> :ok
          after
            1_000 -> flunk("deadline trace collector did not stop")
          end
        end
      end)
    end

    :ok
  end

  defp deadline_events(events, dropped) do
    receive do
      {:report, caller} ->
        send(caller, {:deadline_events, events, dropped})

      message ->
        event =
          case message do
            {:trace_ts, _, action, mfa, time} when action in [:in, :out] ->
              {time, {action, mfa}}

            {:deadline_stage, stage, time} ->
              {time, stage}

            {:trace_ts, _, :call, {:gen, :do_call, [_, _, request, timeout]}, time} ->
              operation =
                case request do
                  {:h2_operation, _, _, operation} -> operation
                  _ -> :fixture_call
                end

              {time, {:gen_call, timeout, operation}}

            {:trace_ts, _, :return_from, {:gen, :do_call, 4}, _, time} ->
              {time, :gen_return}

            {:trace_ts, _, :exception_from, {:gen, :do_call, 4}, exception, time} ->
              {time, {:gen_exception, exception}}

            {:deadline_witness, deadline} ->
              {System.monotonic_time(),
               {:deadline_witness,
                %{
                  late_ms: System.monotonic_time(:millisecond) - deadline,
                  run_queues: :erlang.statistics(:run_queue_lengths)
                }}}
          end

        if length(events) < 256,
          do: deadline_events([event | events], dropped),
          else: deadline_events(events, dropped + 1)
    end
  end

  def deadline_stage({:request_start, deadline}) do
    if tracer = Process.get(:deadline_tracer) do
      send(tracer, {:deadline_stage, :request_start, System.monotonic_time()})

      Process.send_after(
        tracer,
        {:deadline_witness, deadline},
        Gaoxy.Lifecycle.remaining(deadline)
      )
    end
  end

  def deadline_stage(stage) do
    if tracer = Process.get(:deadline_tracer),
      do: send(tracer, {:deadline_stage, stage, System.monotonic_time()})
  end

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: {:ok, exchange}
  end

  defmodule ScriptedTransport do
    def read_body_step(exchange, credit, wait) do
      send(self(), {:read, credit, wait, Gaoxy.Admission.status(exchange.gate).retained_bytes})
      [step | rest] = exchange.transport_state
      next = %{exchange | transport_state: rest}

      case step do
        {kind, bytes} -> {kind, bytes, next}
        :pending -> {:pending, next}
        {:error, reason, :step} -> {:error, reason, next}
      end
    end

    def body_complete?(_), do: false
  end

  defmodule GateDelayTransport do
    def read_body_step(exchange, credit, wait) do
      Gaoxy.PlugBodyTest.deadline_stage(:fixture_status_start)
      charged = Gaoxy.Admission.status(exchange.gate).retained_bytes
      Gaoxy.PlugBodyTest.deadline_stage(:fixture_status_done)
      :ok = :sys.suspend(exchange.gate)
      Gaoxy.PlugBodyTest.deadline_stage(:fixture_suspend_done)
      send(self(), {:native_gate_suspended, charged})
      result = Exchange.read_body_step(%{exchange | transport: nil}, credit, wait)
      Gaoxy.PlugBodyTest.deadline_stage(:native_read_done)
      send(self(), {:native_read_result, result})
      result
    end
  end

  defmodule ContinueSocket do
    def setopts(_, send_timeout: timeout, send_timeout_close: true) when timeout > 0, do: :ok

    def send(owner, bytes) do
      Kernel.send(owner, {:continue_wire, IO.iodata_to_binary(bytes)})
      :ok
    end
  end

  defmodule ReadOwner do
    use GenServer
    def start_link(_), do: GenServer.start_link(__MODULE__, nil)
    def init(state), do: {:ok, state}
    def handle_call(_, _, state), do: {:reply, :ok, state}
  end

  defmodule SocketTransport do
    def recv(owner, _length, timeout) do
      send(owner, {:socket_wait, timeout})

      receive do
        {:socket_input, bytes} ->
          {:ok, bytes}

        {:socket_input_after, bytes, delay} ->
          receive do
          after
            delay -> {:ok, bytes}
          end
      after
        timeout -> {:error, :timeout}
      end
    end
  end

  for size <- [0, 12, 16_384, 20_000, 65_537] do
    test "logical read aggregates #{size} buffered bytes" do
      bytes = :binary.copy("x", unquote(size))
      exchange = exchange({:length, byte_size(bytes)}, bytes)
      assert {:ok, ^bytes, next} = Gaoxy.PlugAdapter.read_req_body(exchange, [])
      assert Exchange.body_complete?(next)
      assert Gaoxy.Admission.status(next.gate).retained_bytes == Exchange.retained_bytes(next)
    end
  end

  test "logical length continues without consuming excess or losing cumulative count" do
    exchange = exchange({:length, 20_000}, :binary.copy("x", 20_000))
    assert {:more, first, next} = Gaoxy.PlugAdapter.read_req_body(exchange, length: 10_000)
    assert byte_size(first) == 10_000
    assert next.body.total == 10_000
    assert {:ok, second, final} = Gaoxy.PlugAdapter.read_req_body(next, length: 10_000)
    assert byte_size(second) == 10_000
    assert final.body.total == 20_000
  end

  test "chunked terminal framing and trailers preserve the next request" do
    suffix = "GET /next HTTP/1.1\r\nHost: localhost\r\n\r\n"
    exchange = exchange(:chunked, "5\r\nhello\r\n0\r\nx-check: ok\r\n\r\n" <> suffix)
    assert {:ok, "hello", final} = Gaoxy.PlugAdapter.read_req_body(exchange, [])
    assert final.buffer == suffix
    assert Exchange.request_trailers(final) == [{"x-check", "ok"}]
  end

  test "an unknown exact chunk boundary needs terminal continuation without an extra data read" do
    exchange = exchange(:chunked, "5\r\nhello\r\n0\r\n\r\nNEXT")
    assert {:more, "hello", next} = Gaoxy.PlugAdapter.read_req_body(exchange, length: 5)
    refute Exchange.body_complete?(next)
    assert next.buffer == "\r\n0\r\n\r\nNEXT"
    assert {:ok, "", final} = Gaoxy.PlugAdapter.read_req_body(next, length: 5)
    assert final.buffer == "NEXT"
  end

  test "whole-request limit is cumulative across logical calls" do
    exchange = exchange({:length, 12}, "abcdefghijkl", max_body_bytes: 10)
    assert {:more, "abcdef", next} = Gaoxy.PlugAdapter.read_req_body(exchange, length: 6)

    assert_raise Gaoxy.HTTP.RequestError, fn ->
      Gaoxy.PlugAdapter.read_req_body(next, length: 6)
    end

    assert Gaoxy.Admission.status(next.gate).retained_bytes == byte_size(next.buffer)
  end

  test "options validate before any transport demand" do
    exchange = scripted([{:ok, "x"}])

    for options <- [
          [length: 0],
          [length: :infinity],
          [read_length: -1],
          [read_timeout: 0],
          [read_timeout: :infinity]
        ] do
      assert {:error, reason} = Gaoxy.PlugAdapter.read_req_body(exchange, options)
      assert reason in [:invalid_read_length, :invalid_read_timeout]
      refute_received {:read, _, _, _}
    end
  end

  test "read_length is capped by native limit and remaining logical allowance with finite server waits" do
    exchange =
      scripted([{:more, "abcd"}, {:more, "ef"}, {:ok, "gh"}],
        max_read_chunk: 4,
        read_timeout: 250
      )

    assert {:more, "abcdef", next} =
             Gaoxy.PlugAdapter.read_req_body(exchange,
               length: 6,
               read_length: 100,
               read_timeout: 500
             )

    assert_receive {:read, 4, 250, _}
    assert_receive {:read, 2, 250, _}
    assert {:ok, "gh", _} = Gaoxy.PlugAdapter.read_req_body(next, [])
    assert_receive {:read, 4, 250, _}
  end

  test "default logical length and read demand follow Plug rather than native defaults" do
    exchange =
      scripted([{:more, "a"}, {:ok, "b"}], max_read_chunk: 2_000_000, read_timeout: 30_000)

    assert {:ok, "ab", _} = Gaoxy.PlugAdapter.read_req_body(exchange, [])
    assert_receive {:read, 1_000_000, 15_000, _}
    assert_receive {:read, 1_000_000, 15_000, _}
  end

  test "pending, zero progress and errors stop without spinning and release accumulator reservations" do
    for {step, reason} <- [
          {:pending, :timeout},
          {{:more, ""}, :no_body_progress},
          {{:error, :closed, :step}, :closed}
        ] do
      exchange = scripted([{:more, "abc"}, step])
      assert {:error, ^reason} = Gaoxy.PlugAdapter.read_req_body(exchange, [])
      assert Gaoxy.Admission.status(exchange.gate).retained_bytes == 0
    end
  end

  test "deadline expiry never invokes the transport" do
    exchange = %{scripted([{:ok, "x"}]) | deadline: Gaoxy.Lifecycle.deadline(0)}
    assert {:error, :timeout} = Gaoxy.PlugAdapter.read_req_body(exchange, [])
    refute_received {:read, _, _, _}
  end

  test "accumulator and flattening peak are admitted and released on transfer" do
    exchange = scripted([{:more, "abcd"}, {:ok, "efgh"}], max_read_chunk: 4)
    assert {:ok, "abcdefgh", next} = Gaoxy.PlugAdapter.read_req_body(exchange, [])
    assert_receive {:read, 4, _, first}
    assert_receive {:read, 4, _, second}
    assert first >= 8
    assert second >= first + 4
    assert Gaoxy.Admission.status(next.gate).retained_high_water >= 16
    assert Gaoxy.Admission.status(next.gate).retained_bytes == 0
  end

  test "socket waits are finite, capped and bounded by the absolute request deadline" do
    exchange = exchange({:length, 1}, "", read_timeout: 25)

    socket =
      struct!(Hell.Socket,
        socket: self(),
        transport_module: SocketTransport,
        read_timeout: 1_000,
        handshake_timeout: 1_000,
        silent_terminate_on_error: false,
        span: Hell.Telemetry.start_span(:connection, %{}, %{handler: __MODULE__})
      )

    exchange = %{exchange | socket: socket, deadline: Gaoxy.Lifecycle.deadline(10)}
    assert {:error, :timeout} = Gaoxy.PlugAdapter.read_req_body(exchange, read_timeout: 100)
    assert_receive {:socket_wait, wait}
    assert wait > 0 and wait <= 10
    assert Gaoxy.Admission.status(exchange.gate).retained_bytes == 0
  end

  test "framing-only reads use each socket wait and do not aggregate a total timeout" do
    exchange = exchange(:chunked, "", read_timeout: 100)

    socket =
      struct!(Hell.Socket,
        socket: self(),
        transport_module: SocketTransport,
        read_timeout: 1_000,
        handshake_timeout: 1_000,
        silent_terminate_on_error: false,
        span: Hell.Telemetry.start_span(:connection, %{}, %{handler: __MODULE__})
      )

    exchange = %{exchange | socket: socket}

    # Every receive completes within its own 100ms budget, but the framing
    # read as a whole spans more than one budget. The input order is explicit.
    for byte <- :binary.bin_to_list("1\r\nx\r\n0\r\n\r\n"),
        do: send(self(), {:socket_input_after, <<byte>>, 20})

    started = System.monotonic_time(:millisecond)
    assert {:ok, "x", final} = Gaoxy.PlugAdapter.read_req_body(exchange, read_timeout: 100)
    assert System.monotonic_time(:millisecond) - started >= 200
    assert final.deadline == exchange.deadline

    for _ <- 1..11 do
      assert_receive {:socket_wait, 100}
    end

    refute_received {:socket_wait, _}
  end

  test "a stale admission lease preserves Plug's error shape before reading" do
    exchange = %{scripted([{:ok, "x"}]) | lease: make_ref()}
    assert {:error, :stale_generation} = Gaoxy.PlugAdapter.read_req_body(exchange, [])
    refute_received {:read, _, _, _}
  end

  test "a stopped admission gate preserves Plug's closed error shape" do
    exchange = scripted([{:ok, "x"}])
    {stopped, monitor} = spawn_monitor(fn -> :ok end)
    assert_receive {:DOWN, ^monitor, :process, ^stopped, :normal}
    exchange = %{exchange | gate: stopped}
    assert {:error, :closed} = Gaoxy.PlugAdapter.read_req_body(exchange, [])
    refute_received {:read, _, _, _}
  end

  test "admission waits respect the absolute deadline and queued cleanup restores ownership" do
    exchange = scripted([{:ok, "x"}])
    :ok = :sys.suspend(exchange.gate)

    try do
      exchange = %{exchange | deadline: Gaoxy.Lifecycle.deadline(30)}
      started = System.monotonic_time(:millisecond)
      assert {:error, :timeout} = Gaoxy.PlugAdapter.read_req_body(exchange, [])
      assert System.monotonic_time(:millisecond) - started < 250
      refute_received {:read, _, _, _}
    after
      :ok = :sys.resume(exchange.gate)
    end

    assert Gaoxy.Admission.status(exchange.gate).retained_bytes == 0
  end

  test "native retention admission after Plug reservation respects the same deadline" do
    exchange = %{
      exchange({:length, 1}, "x")
      | transport: GateDelayTransport,
        deadline: Gaoxy.Lifecycle.deadline(40)
    }

    try do
      started = System.monotonic_time(:millisecond)
      assert {:error, :timeout} = Gaoxy.PlugAdapter.read_req_body(exchange, [])
      assert System.monotonic_time(:millisecond) - started < 250
      assert_receive {:native_gate_suspended, charged}
      assert charged > byte_size(exchange.buffer)
    after
      :ok = :sys.resume(exchange.gate)
    end

    assert Gaoxy.Admission.status(exchange.gate).retained_bytes == byte_size(exchange.buffer)
  end

  @tag :deadline_trace
  test "a suspended H2 body-read owner is bounded by the hard deadline and returns timeout" do
    owner = start_supervised!({ReadOwner, []})

    exchange = %{
      scripted([])
      | transport_state: {owner, 1, make_ref()},
        deadline: Gaoxy.Lifecycle.deadline(30)
    }

    :ok = :sys.suspend(owner)

    try do
      deadline_stage({:request_start, exchange.deadline})
      started = System.monotonic_time(:millisecond)

      assert {:error, :timeout} =
               Gaoxy.HTTP.HTTP2.Transport.operation(exchange, {:read, 1, 1_000})

      deadline_stage(:request_done)
      assert System.monotonic_time(:millisecond) - started < 100
    after
      :ok = :sys.resume(owner)
    end
  end

  @tag :deadline_trace
  test "read-triggered H1 Continue cannot wait past the deadline at a delayed gate" do
    exchange = exchange({:length, 1}, "x")

    exchange = %{
      exchange
      | request: %{exchange.request | expect_continue: true},
        transport: GateDelayTransport,
        deadline: Gaoxy.Lifecycle.deadline(30)
    }

    try do
      deadline_stage({:request_start, exchange.deadline})
      started = System.monotonic_time(:millisecond)
      assert {:error, :timeout} = Gaoxy.PlugAdapter.read_req_body(exchange, [])
      deadline_stage(:request_done)
      assert System.monotonic_time(:millisecond) - started < 250
      assert_receive {:native_read_result, {:error, :timeout, %{expect_sent: true}}}
    after
      :ok = :sys.resume(exchange.gate)
    end

    assert Gaoxy.Admission.status(exchange.gate).retained_bytes == byte_size(exchange.buffer)
    assert :sys.get_state(exchange.gate).leases[exchange.lease].send == nil
  end

  @tag :deadline_trace
  test "read-triggered H2 Continue cannot outwait the hard deadline at a suspended owner" do
    owner = start_supervised!({ReadOwner, []})
    exchange = exchange({:length, 1}, "x")

    exchange = %{
      exchange
      | request: %{exchange.request | expect_continue: true},
        transport: Gaoxy.HTTP.HTTP2.Transport,
        transport_state: {owner, 1, make_ref()},
        deadline: Gaoxy.Lifecycle.deadline(30)
    }

    :ok = :sys.suspend(owner)

    try do
      deadline_stage({:request_start, exchange.deadline})
      started = System.monotonic_time(:millisecond)
      assert {:error, :timeout} = Gaoxy.PlugAdapter.read_req_body(exchange, [])
      deadline_stage(:request_done)
      assert System.monotonic_time(:millisecond) - started < 100
    after
      :ok = :sys.resume(owner)
    end
  end

  test "a timed-out known send token is finished after late gate registration without unknown submission" do
    exchange = exchange(:none, "")
    operation = make_ref()
    attachment = make_ref()
    owner = self()

    :ok =
      :telemetry.attach_many(
        attachment,
        [[:gaoxy, :send_started], [:gaoxy, :send]],
        fn event, _, metadata, _ ->
          if metadata.operation == operation do
            case event do
              [:gaoxy, :send_started] ->
                send(owner, {:continue_start, operation})

                receive do
                  :allow_continue_registration -> :ok
                after
                  1_000 -> :ok
                end

              [:gaoxy, :send] ->
                send(owner, {:continue_outcome, operation, metadata.outcome})
            end
          end
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(attachment) end)

    try do
      assert {:error, :timeout} =
               Gaoxy.Admission.start_send_until(
                 exchange.gate,
                 exchange.lease,
                 25,
                 operation,
                 Gaoxy.Lifecycle.deadline(30)
               )

      assert_receive {:continue_start, ^operation}
    after
      send(exchange.gate, :allow_continue_registration)
    end

    assert Gaoxy.Admission.status(exchange.gate).retained_bytes == 0
    assert :sys.get_state(exchange.gate).leases[exchange.lease].send == nil
    assert_receive {:continue_outcome, ^operation, {:error, :not_submitted}}
    refute_received {:continue_outcome, ^operation, _}
  end

  test "successful H1 Continue obeys a tiny write cap and is never replayed" do
    exchange = exchange({:length, 1}, "x", max_write_chunk: 4)

    socket =
      struct!(Hell.Socket,
        socket: self(),
        transport_module: ContinueSocket,
        read_timeout: 1_000,
        handshake_timeout: 1_000,
        silent_terminate_on_error: false,
        span: Hell.Telemetry.start_span(:connection, %{}, %{handler: __MODULE__})
      )

    exchange = %{exchange | socket: socket, request: %{exchange.request | expect_continue: true}}
    assert {:ok, "x", next} = Gaoxy.PlugAdapter.read_req_body(exchange, [])

    chunks =
      for _ <- 1..7 do
        assert_receive {:continue_wire, bytes}
        assert byte_size(bytes) <= 4
        bytes
      end

    assert IO.iodata_to_binary(chunks) == "HTTP/1.1 100 Continue\r\n\r\n"
    assert next.expect_sent
    assert {:ok, "", final} = Gaoxy.PlugAdapter.read_req_body(next, [])
    refute_received {:continue_wire, _}
    assert Gaoxy.Admission.status(final.gate).retained_bytes == Exchange.retained_bytes(final)
    assert :sys.get_state(final.gate).leases[final.lease].send == nil
  end

  test "tunnel bodies retain their unsupported read result" do
    exchange = %{exchange(:none, "") | body: :tunnel}
    assert {:error, :unsupported_tunnel_body} = Gaoxy.PlugAdapter.read_req_body(exchange, [])
  end

  test "flatten admission failure releases all adapter reservations" do
    exchange = scripted([{:more, "abcd"}, {:ok, "efgh"}], max_read_chunk: 4, admission_bytes: 12)
    assert {:error, :byte_limit} = Gaoxy.PlugAdapter.read_req_body(exchange, [])
    assert Gaoxy.Admission.status(exchange.gate).retained_bytes == 0
  end

  defp scripted(steps, options \\ []) do
    exchange = exchange(:none, "", options)
    %{exchange | transport: ScriptedTransport, transport_state: steps}
  end

  defp exchange(framing, buffer, options \\ []) do
    {:ok, spec} = Gaoxy.HTTP.service_spec(endpoint: {Endpoint, []})

    limits =
      Map.merge(
        spec.handler_options.http_limits,
        Map.new(Keyword.drop(options, [:admission_bytes]))
      )

    {:ok, request, ""} = Parser.parse_head("POST / HTTP/1.1\r\nHost: localhost\r\n\r\n", limits)
    request = %{request | body: framing, head_bytes: 0}

    gate =
      start_supervised!(%{
        id: make_ref(),
        start:
          {Gaoxy.Admission, :start_link,
           [
             {%{spec.limits | max_bytes: options[:admission_bytes] || 32_000_000},
              %{instance: make_ref(), service: :test}}
           ]}
      })

    {:ok, lease} = Gaoxy.Admission.acquire(gate, byte_size(buffer))

    %Exchange{
      request: request,
      gate: gate,
      lease: lease,
      deadline: Gaoxy.Lifecycle.deadline(5_000),
      limits: limits,
      body: Body.new(framing, limits),
      buffer: buffer
    }
  end
end
