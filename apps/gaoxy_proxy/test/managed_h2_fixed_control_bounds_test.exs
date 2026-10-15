Code.require_file("support/managed_h2_control_projection.exs", __DIR__)

defmodule Gaoxy.Proxy.ManagedH2FixedControlBoundsTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: F
  alias Gaoxy.Proxy.ManagedH2ControlProjection, as: Bounds
  alias Gaoxy.Proxy.HTTP.Session
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports
  @timeout 5_000
  @moduletag :capture_log

  # pump/2 is an existing local seam, not a new observer or production API.
  # Capture its complete actual arguments; the helper measures every control
  # key and separately verifies each explicitly named payload before marking it.
  setup do
    Code.ensure_loaded!(Gaoxy.Proxy.HTTP)

    on_exit(fn ->
      for mfa <- [{Gaoxy.Proxy.HTTP, :pump, 2}, {Gaoxy.Proxy.HTTP, :dispatch, 2}],
          do: :erlang.trace_pattern(mfa, false, [:local])

      for arity <- [1, 2], do: :erlang.trace_pattern({:erlang, :cancel_timer, arity}, false, [])
    end)

    for mfa <- [{Gaoxy.Proxy.HTTP, :pump, 2}, {Gaoxy.Proxy.HTTP, :dispatch, 2}] do
      assert :erlang.trace_pattern(mfa, true, [:local]) >= 1
    end

    for arity <- [1, 2] do
      assert :erlang.trace_pattern(
               {:erlang, :cancel_timer, arity},
               [{:_, [], [{:return_trace}]}],
               []
             ) == 1
    end

    :ok
  end

  for protocol <- [:http2, :h2c] do
    @protocol protocol
    test "#{protocol} actual opening resolved DATA trailer and pump controls fit complete caps" do
      f = F.fixture(@protocol, :http1, ["--manual"])
      {socket, seen, guardian, completion} = F.hold(f)
      monitor = Process.monitor(guardian)
      opening = :sys.get_state(guardian)
      assert Bounds.session(opening)
      assert opening.original_request.completion === completion
      assert opening.request.completion === completion
      assert :erlang.external_size(Bounds.handle(opening.original_request)) <= 4_096
      assert :erlang.external_size(Bounds.handle(opening.request)) <= 4_096
      assert opening.managed_transport == nil and opening.request_options == nil

      largest_times = %{
        opening
        | started_at: -9_223_372_036_854_775_808,
          deadline: 9_223_372_036_854_775_807,
          cleanup_deadline: 9_223_372_036_854_775_807,
          cleanup_requested_deadline: 9_223_372_036_854_775_807,
          activated_at: -9_223_372_036_854_775_808,
          opening_deadline: 9_223_372_036_854_775_807
      }

      assert Bounds.session(largest_times)

      assert_raise ExUnit.AssertionError, fn ->
        Bounds.session(%{opening | deadline: 9_223_372_036_854_775_808})
      end

      assert :erlang.external_size(
               {Bounds.handle(opening.request), {:slot, :session_request_url}}
             ) -
               :erlang.external_size(Bounds.handle(opening.request)) <= 128

      pump = opening.owner
      assert :erlang.trace(pump, true, [:call, :send, :receive]) == 1
      assert :erlang.trace(guardian, true, [:call, :send, :receive]) == 1

      on_exit(fn ->
        for pid <- [pump, guardian], do: stop_trace(pid)
        safe_resume(guardian)
      end)

      :ok = :sys.suspend(guardian)

      F.command(f.peer, seen, "respond", %{
        "fields" => [["trailer", "x-check"]],
        "ended" => false
      })

      task = opening.original_request.promise.task

      F.eventually(fn ->
        {:messages, messages} = Process.info(guardian, :messages)
        match?({_, %HTTP.Response{}}, List.keyfind(messages, task.ref, 0))
      end)

      {:messages, messages} = Process.info(guardian, :messages)

      assert {ref, %HTTP.Response{stream: stream} = response} =
               List.keyfind(messages, task.ref, 0)

      assert ref == task.ref and is_pid(stream)
      assert {:task, _} = Bounds.message({ref, response}, opening.submitted_url)
      assert Bounds.session(:sys.get_state(guardian))
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)

      assert_all_families(opening, response, f)
      :ok = :sys.resume(guardian)
      F.eventually(fn -> :sys.get_state(guardian).headers end)
      resolved = :sys.get_state(guardian)
      assert Bounds.session(resolved)
      assert resolved.submitted_url == nil
      assert resolved.original_request === opening.original_request
      assert resolved.request.stream == stream
      assert resolved.original_request.completion === resolved.request.completion

      bytes = :binary.copy("d", 32_769)

      F.command(f.peer, seen, "data", %{
        "body64" => Base.encode64(bytes),
        "ended" => true,
        "trailers" => [["x-check", "first"], ["x-check", "second"]]
      })

      assert %{status: 200, body: ^bytes, trailers: [{"x-check", "first"}, {"x-check", "second"}]} =
               F.response(f, socket)

      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout

      synchronize_trace()
      traces = traces([])

      pumps =
        for {:trace, ^pump, :call, {Gaoxy.Proxy.HTTP, :pump, [state, _]}} <- traces,
            do: Bounds.pump(state)

      assert length(pumps) > 0
      assert Enum.any?(pumps, & &1.ready)
      assert Enum.any?(pumps, &(&1.response_policy == {:slot, :trailer_policies}))
      assert Enum.any?(pumps, &(&1.exchange.response != :unset))

      {actual, transient_timers} = classify_live_controls(traces, opening, guardian)
      assert Enum.all?(transient_timers, fn tuple -> :erlang.external_size(tuple) <= 2_048 end)

      IO.puts(
        "CONTROL_BOUNDS_TIMER_PROVENANCE " <>
          inspect(%{
            protocol: @protocol,
            verified: length(transient_timers),
            results: Enum.map(transient_timers, &elem(&1, 1))
          })
      )

      families = actual |> Enum.map(&elem(&1, 0)) |> MapSet.new()

      for family <- [:task, :data, :trailers, :stream_end, :delivery, :timer],
          do: assert(MapSet.member?(families, family), "missing live control family #{family}")

      assert Enum.all?(actual, fn {_, projection} ->
               :erlang.external_size(projection) <= 2_048
             end)

      :ok = :gen_tcp.close(socket)
      F.clean(f)
      F.close(f)
    end
  end

  test "transient timer replies require same-actor public call receive return provenance without a new retained family" do
    guardian = self()

    pump =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    on_exit(fn -> send(pump, :stop) end)
    task_ref = make_ref()
    timer = make_ref()
    reply = make_ref()

    opening = %{
      owner: pump,
      original_request: %{promise: %{task: %{ref: task_ref}}},
      submitted_url: nil
    }

    call = {:trace, guardian, :call, {:erlang, :cancel_timer, [timer]}}
    received = {:trace, guardian, :receive, {reply, false}}
    returned = {:trace, guardian, :return_from, {:erlang, :cancel_timer, 1}, false}

    assert {[], [{^reply, false}]} =
             classify_live_controls([call, received, returned], opening, guardian)

    call_with_options = {:trace, guardian, :call, {:erlang, :cancel_timer, [timer, []]}}
    returned_with_options = {:trace, guardian, :return_from, {:erlang, :cancel_timer, 2}, false}

    assert {[], [{^reply, false}]} =
             classify_live_controls(
               [call_with_options, received, returned_with_options],
               opening,
               guardian
             )

    assert {:timer, _} = Bounds.message(:poll)
    assert length(Bounds.families()) == 16
    assert :erlang.external_size({reply, false}) <= 2_048

    assert {[], [{^reply, 9_223_372_036_854_775_807}]} =
             classify_live_controls(
               [
                 call,
                 {:trace, guardian, :receive, {reply, 9_223_372_036_854_775_807}},
                 {:trace, guardian, :return_from, {:erlang, :cancel_timer, 1},
                  9_223_372_036_854_775_807}
               ],
               opening,
               guardian
             )

    for sequence <- [
          [received, returned],
          [
            {:trace, guardian, :call, {:erlang, :cancel_timer, [timer, [{:async, true}]]}},
            received,
            returned_with_options
          ],
          [call, returned, received],
          [call, received],
          [call, received, {:trace, pump, :return_from, {:erlang, :cancel_timer, 1}, false}],
          [call, received, {:trace, guardian, :return_from, {:erlang, :cancel_timer, 1}, 0}],
          [call, received, {:trace, guardian, :return_from, {:erlang, :cancel_timer, 2}, false}],
          [call, {:trace, pump, :receive, {reply, false}}, returned],
          [call, {:trace, guardian, :send, {reply, false}, pump}, returned],
          [
            call,
            {:trace, guardian, :receive, {reply, -1}},
            {:trace, guardian, :return_from, {:erlang, :cancel_timer, 1}, -1}
          ],
          [
            call,
            {:trace, guardian, :receive, {reply, 9_223_372_036_854_775_808}},
            {:trace, guardian, :return_from, {:erlang, :cancel_timer, 1},
             9_223_372_036_854_775_808}
          ],
          [call, {:trace, guardian, :receive, {reply, false, :extra}}, returned]
        ] do
      assert_raise ExUnit.AssertionError, fn ->
        classify_live_controls(sequence, opening, guardian)
      end
    end
  end

  test "authentic public stream diagnostics become finite outbound controls before request cleanup" do
    f = F.fixture(:h2c, :http1, ["--manual"])
    {socket, seen, guardian, completion} = F.hold(f)
    monitor = Process.monitor(guardian)
    F.command(f.peer, seen, "respond", %{"fields" => [["content-length", "1"]], "ended" => false})
    assert F.h1_head(socket) =~ "200 OK"
    F.eventually(fn -> :sys.get_state(guardian).headers end)
    state = :sys.get_state(guardian)
    assert Bounds.session(state)
    stream = state.request.stream
    assert is_pid(stream)
    assert :erlang.trace(guardian, true, [:send, :receive]) == 1
    on_exit(fn -> stop_trace(guardian) end)
    raw = %{exception: :binary.copy("x", 1_048_577), stacktrace: [{__MODULE__, :fake, []}]}
    send(guardian, {:stream_error, stream, raw})
    assert_receive {:trace, ^guardian, :receive, {:stream_error, ^stream, ^raw}}, @timeout

    assert_receive {:trace, ^guardian, :send,
                    {:gaoxy_proxy_http, ^guardian, {:error, :upstream_failure}} = emitted, pump},
                   @timeout

    assert pump == state.owner
    assert {:delivery, projection} = Bounds.message(emitted)
    assert projection == emitted
    assert :erlang.external_size(emitted) <= 2_048
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, @timeout
    assert {:ok, %{request_tokens: 0, helpers: 0}} = Transports.status(f.owner)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    :ok = :gen_tcp.close(socket)
    F.clean(f)
    F.close_aborted(f, 1)
  end

  test "an actual unactivated Session retains the exact finite schema and drops oversized unauthenticated diagnostics" do
    assert {:ok, config} =
             Gaoxy.Proxy.HTTP.init(%{
               upstream: "http://localhost:12345",
               upstream_protocol: :h2c,
               transport: %{
                 provider: Transports,
                 owner: self(),
                 owner_epoch: make_ref(),
                 resource: make_ref()
               }
             })

    request = %{
      protocol: :h2c,
      url: "http://localhost:12345/",
      target: "/",
      method: :get,
      fields: [],
      body_mode: :none,
      max_upload_bytes: 65_536,
      request_limits: %{
        max_headers: 256,
        max_header_bytes: 65_536,
        max_trailers: 128,
        max_trailer_bytes: 65_536
      }
    }

    args = %{
      owner: self(),
      service: self(),
      instance: self(),
      gate: self(),
      started_at: Gaoxy.Lifecycle.now(),
      deadline: F.deadline(),
      config: config,
      selector: {:fixed, config},
      transport_handoff: nil,
      request_options: request
    }

    assert {:ok, guardian} = Session.start_link(args)
    on_exit(fn -> if Process.alive?(guardian), do: GenServer.stop(guardian) end)
    initial = :sys.get_state(guardian)
    assert Bounds.session(initial)
    assert :erlang.trace(guardian, true, [:receive]) == 1

    diagnostic = %{
      raw_exception: :binary.copy("x", 1_048_577),
      stacktrace: [{__MODULE__, :fake, []}]
    }

    wrong_ref = make_ref()
    send(guardian, {:DOWN, wrong_ref, :process, self(), diagnostic})
    send(guardian, {:gaoxy_transport_handoff, wrong_ref, {:error, diagnostic}, F.deadline()})
    send(guardian, {:stream_error, self(), diagnostic})
    after_messages = :sys.get_state(guardian)
    assert after_messages == initial
    assert Bounds.session(after_messages)

    for shape <- [
          {:DOWN, wrong_ref, :process, self(), diagnostic},
          {:gaoxy_transport_handoff, wrong_ref, {:error, diagnostic}, F.deadline()},
          {:stream_error, self(), diagnostic}
        ] do
      assert {_, projection} = Bounds.message(shape)
      refute contains_binary?(projection, diagnostic.raw_exception)
      assert :erlang.external_size(projection) <= 2_048
    end

    assert_raise ExUnit.AssertionError, fn ->
      Bounds.session(Map.put(initial, :history, diagnostic))
    end

    assert_raise ExUnit.AssertionError, fn -> Bounds.session(%{initial | outcome: diagnostic}) end
    Session.cancel(guardian)
    monitor = Process.monitor(guardian)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, reason}, @timeout
    assert reason in [:normal, :noproc]
  end

  defp assert_all_families(state, response, f) do
    [pin] = state.transport_pins
    stream = response.stream
    task = state.original_request.promise.task
    # These are constructor-boundary specimens anchored to the captured real
    # actors/capabilities, distinct from the separately checked live traces.
    # Each family retains every wrapper/control scalar after named payload
    # extraction. Public completion/scope interiors are not serialized.
    messages = [
      {:gaoxy_cleanup_activate, state.token},
      {:gaoxy_cleanup_cancel, state.token, {:cleanup_failed, :cleanup_pending}, state.deadline},
      {:gaoxy_transport_handoff, make_ref(), {:ok, pin}, state.deadline},
      {:DOWN, task.ref, :process, task.pid, :normal},
      :poll,
      {:"$gen_cast", :consumed},
      {:"$gen_cast", {:acknowledge, make_ref()}},
      {task.ref, response},
      {:stream_chunk, stream, :binary.copy("d", 1_048_576), make_ref()},
      {:stream_trailers, stream, %HTTP.Headers{headers: List.duplicate({"x", "v"}, 128)}},
      {:stream_end, stream},
      {:stream_error, stream, :upstream_failure},
      {:gaoxy_proxy_http, state.owner, {:ready, nil, state.config.limits, state.deadline}},
      {:gaoxy_proxy_http, state.owner,
       {:transport_handoff, make_ref(), f.handle,
        %{origin: f.origin, upstream_protocol: f.protocol, instance: f.instance},
        state.deadline}},
      {:gaoxy_proxy_http, state.owner, {:headers, 599, List.duplicate({"x", ""}, 256)}},
      {:gaoxy_drain, state.gate, make_ref(), state.deadline}
    ]

    assert Enum.map(messages, fn message ->
             elem(Bounds.message(message, state.submitted_url), 0)
           end) ==
             Bounds.families()

    projections =
      Enum.map(messages, fn message -> elem(Bounds.message(message, state.submitted_url), 1) end)

    assert length(projections) == 16
    assert :erlang.external_size(projections) <= 16 * 2_048
    assert 16_384 + 8_192 + 2 * 4_096 + 16 * 2_048 == 65_536

    assert Gaoxy.Proxy.ManagedH2Reservation.activation_contract().components.closed_controls.ceiling_bytes ==
             65_536

    for timer <- [:opening_expired, :total_expired],
        do: assert({:timer, _} = Bounds.message(timer))

    for op <- [:cancel, :expire], do: assert({:cast, _} = Bounds.message({:"$gen_cast", op}))

    for reason <- [
          :cleanup_pending,
          {:cleanup_failed,
           {:transport_cleanup_failed, {:pin_release_failed, :invalid_resource_pin}}}
        ],
        do:
          assert(
            {:cleanup_cancel, _} =
              Bounds.message({:gaoxy_cleanup_cancel, state.token, reason, state.deadline})
          )

    assert {:task, _} = Bounds.message({task.ref, {:error, :upstream_task}})

    assert {:handoff, _} =
             Bounds.message(
               {:gaoxy_transport_handoff, make_ref(), {:error, :unavailable}, state.deadline}
             )

    for delivery <- [
          {:chunk, :binary.copy("d", 1_048_576), make_ref()},
          {:end, List.duplicate({"x", "v"}, 128)},
          {:error, :upstream_failure}
        ],
        do: assert({:delivery, _} = Bounds.message({:gaoxy_proxy_http, state.owner, delivery}))

    # Full payload/backing validation must happen BEFORE the marker. A large
    # field or backing cannot become a tiny successful control projection.
    excessive = :binary.copy("x", 1_048_577)

    for bytes <- [excessive, binary_part(excessive, 0, 100)] do
      assert_raise ExUnit.AssertionError, fn ->
        Bounds.message({:stream_chunk, stream, bytes, make_ref()})
      end

      assert_raise ExUnit.AssertionError, fn ->
        Bounds.message({:gaoxy_proxy_http, state.owner, {:chunk, bytes, make_ref()}})
      end
    end

    for fields <- [
          List.duplicate({"x", "v"}, 129),
          [{"x", :binary.copy("v", 65_536)}],
          [{"x", binary_part(:binary.copy("x", 65_537), 0, 100)}],
          [{"x", "v"} | :improper]
        ] do
      assert_raise ExUnit.AssertionError, fn ->
        Bounds.message({:stream_trailers, stream, %HTTP.Headers{headers: fields}})
      end
    end

    assert_raise ExUnit.AssertionError, fn ->
      Bounds.message({:gaoxy_cleanup_activate, state.token, :extra})
    end

    assert_raise ExUnit.AssertionError, fn ->
      Bounds.message({:stream_chunk, stream, nil, make_ref()})
    end

    assert_raise ExUnit.AssertionError, fn ->
      Bounds.handle(Map.put(state.request, :response, response))
    end
  end

  defp classify_live_controls(traces, opening, guardian) do
    pump = opening.owner
    initial = %{calls: %{}, controls: [], timers: []}

    final =
      Enum.reduce(traces, initial, fn
        {:trace, pid, :call, {:erlang, :cancel_timer, _}} = call, acc
        when pid == guardian or pid == pump ->
          Bounds.timer_call(call)
          stack = Map.get(acc.calls, pid, [])
          %{acc | calls: Map.put(acc.calls, pid, [{call, nil} | stack])}

        {:trace, pid, :return_from, {:erlang, :cancel_timer, arity}, result} = returned, acc
        when pid == guardian or pid == pump ->
          assert [{call, received} | rest] = Map.get(acc.calls, pid, [])
          {:trace, ^pid, :call, {:erlang, :cancel_timer, args}} = call
          assert length(args) == arity

          timers =
            if received do
              [
                Bounds.timer_receipt(
                  call,
                  received,
                  returned,
                  opening.original_request.promise.task.ref
                )
                | acc.timers
              ]
            else
              assert result == false or
                       (is_integer(result) and result in 0..9_223_372_036_854_775_807)

              acc.timers
            end

          %{acc | calls: Map.put(acc.calls, pid, rest), timers: timers}

        {:trace, pid, :receive, message} = received, acc when pid == guardian or pid == pump ->
          classify_received(acc, received, pid, message, :receive, opening, guardian)

        {:trace, pid, :send, message, _}, acc when pid == guardian or pid == pump ->
          classify_received(acc, nil, pid, message, :send, opening, guardian)

        _, acc ->
          acc
      end)

    assert Enum.all?(final.calls, fn {_, stack} -> stack == [] end),
           "public timer cancellation call/reply lacks matching return"

    {Enum.reverse(final.controls), Enum.reverse(final.timers)}
  end

  defp classify_received(acc, received, pid, message, direction, opening, guardian) do
    task_ref = opening.original_request.promise.task.ref

    non_task_reply =
      is_tuple(message) and tuple_size(message) > 0 and
        is_reference(elem(message, 0)) and elem(message, 0) !== task_ref

    if non_task_reply do
      assert tuple_size(message) == 2, "expanded non-Task reference reply wrapper"
      assert direction == :receive and received != nil

      case Map.get(acc.calls, pid, []) do
        [{call, nil} | rest] ->
          %{acc | calls: Map.put(acc.calls, pid, [{call, received} | rest])}

        _ ->
          flunk("non-Task reference reply has no matching public timer call")
      end
    else
      if control_message?(message) do
        value = checked_live_message(pid, direction, message, opening, guardian)
        %{acc | controls: [value | acc.controls]}
      else
        acc
      end
    end
  end

  defp checked_live_message(pid, direction, message, opening, guardian) do
    Bounds.message(message, opening.submitted_url)
  rescue
    error in ExUnit.AssertionError ->
      # Diagnostic-only: preserve the failure and its original stack. Describe
      # public wrapper constructors, never inspect/serialize the contents of
      # a completion, scope, socket, Response, exception or binary payload.
      context = %{
        actor: if(pid == guardian, do: :session, else: :pump),
        direction: direction,
        original_task_ref:
          is_tuple(message) and tuple_size(message) > 0 and
            elem(message, 0) === opening.original_request.promise.task.ref,
        shape: public_shape(message)
      }

      reraise %{
                error
                | message:
                    (error.message || "control bound assertion") <>
                      "; live wrapper context=" <> inspect(context)
              },
              __STACKTRACE__
  end

  defp public_shape(value) when is_tuple(value) do
    {:tuple, tuple_size(value),
     for(
       index <- 0..(min(tuple_size(value), 8) - 1),
       tuple_size(value) > 0,
       do: public_leaf(elem(value, index))
     )}
  end

  defp public_shape(value), do: public_leaf(value)
  defp public_leaf(value) when is_atom(value), do: {:atom, value}
  defp public_leaf(value) when is_reference(value), do: :reference
  defp public_leaf(value) when is_pid(value), do: :pid

  defp public_leaf(value) when is_binary(value),
    do: {:binary, byte_size(value), :binary.referenced_byte_size(value)}

  defp public_leaf(value) when is_tuple(value),
    do:
      {:tuple, tuple_size(value),
       if(tuple_size(value) > 0, do: public_tag(elem(value, 0)), else: :empty)}

  defp public_leaf(value) when is_map(value),
    do: {:map, map_size(value), public_tag(Map.get(value, :__struct__))}

  defp public_leaf(value) when is_list(value), do: :list
  defp public_leaf(value) when is_integer(value), do: :integer
  defp public_leaf(_), do: :other
  defp public_tag(value) when is_atom(value), do: value
  defp public_tag(_), do: :non_atom

  defp control_message?(message) when is_tuple(message) do
    elem(message, 0) in [
      :gaoxy_cleanup_activate,
      :gaoxy_cleanup_cancel,
      :gaoxy_transport_handoff,
      :DOWN,
      :"$gen_cast",
      :stream_chunk,
      :stream_trailers,
      :stream_end,
      :stream_error,
      :gaoxy_proxy_http,
      :gaoxy_drain
    ] or
      (tuple_size(message) == 2 and is_reference(elem(message, 0)))
  end

  defp control_message?(message), do: message in [:opening_expired, :total_expired, :poll]

  defp synchronize_trace do
    ref = :erlang.trace_delivered(:all)
    assert_receive {:trace_delivered, :all, ^ref}, @timeout
  end

  defp traces(acc) do
    receive do
      {:trace, _, _, _} = trace -> traces([trace | acc])
      {:trace, _, _, _, _} = trace -> traces([trace | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp stop_trace(pid) do
    if Process.alive?(pid), do: :erlang.trace(pid, false, [:all])
  end

  defp safe_resume(pid) do
    if Process.alive?(pid), do: :sys.resume(pid)
  catch
    :exit, _ -> :ok
  end

  defp contains_binary?(value, bytes) when is_binary(value), do: value == bytes

  defp contains_binary?(value, bytes) when is_tuple(value),
    do: value |> Tuple.to_list() |> Enum.any?(&contains_binary?(&1, bytes))

  defp contains_binary?(_, _), do: false
end
