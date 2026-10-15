defmodule Gaoxy.Proxy.ManagedH2GroupProbeIntegrationTest do
  use ExUnit.Case, async: false

  alias Gaoxy.Proxy.{ManagedH2Client, ManagedH2Preparation, UpstreamGroups, UpstreamTransports}
  alias Gaoxy.Proxy.ManagedH2GroupAccounting, as: Accounting
  alias Gaoxy.Proxy.UpstreamGroups.Probe

  @timeout 5_000
  @normal_keys ~w(owner token member deadline health url group)a
  @state_keys @normal_keys ++
                ~w(cleanup_deadline owner_monitor timer request original_request managed_transport transport_selection transport_pins terminal cancelled headers outcome client limits request_options submitted_url)a

  setup do
    for module <- [Accounting, Probe, GenServer], do: Code.ensure_loaded!(module)

    patterns = [
      {{Accounting, :startup, 2}, [:local]},
      {{Accounting, :validate, 2}, [:local]},
      {{Accounting, :preflight_control, 2}, [:local]},
      {{:erlang, :monitor, 2}, []},
      {{GenServer, :call, 3}, [:local]}
    ]

    for {mfa, flags} <- patterns, do: :erlang.trace_pattern(mfa, true, flags)

    on_exit(fn ->
      for {mfa, flags} <- patterns, do: :erlang.trace_pattern(mfa, false, flags)
    end)

    :ok
  end

  for protocol <- [:http2, :h2c] do
    test "#{protocol} normal init accounts original A before genuine monitor and exact initial S" do
      f = fixture(unquote(protocol))
      args = Map.take(f, @normal_keys)
      {{:ok, state, {:continue, :open}}, calls} = traced(fn -> Probe.init(args) end)
      assert Enum.sort(Map.keys(state)) === Enum.sort(@state_keys)
      assert state.owner === args.owner
      assert state.group === args.group
      assert state.member === args.member
      assert state.token === args.token
      assert state.deadline === args.deadline
      assert state.cleanup_deadline === args.deadline + 1_000
      assert state.request_options === nil and state.request === nil
      assert state.original_request === nil and state.transport_selection === nil
      assert state.transport_pins === [] and state.managed_transport === nil
      assert is_reference(state.owner_monitor) and is_reference(state.timer)
      assert_call(calls, Accounting, :startup, [Probe, args])
      assert_call(calls, Accounting, :preflight_control, [:monitor, args.owner])
      assert_call(calls, Accounting, :validate, [{:state, :probe}, state])
      assert before?(calls, {Accounting, :startup}, {:erlang, :monitor, [:process, args.owner]})

      assert before?(
               calls,
               {Accounting, :preflight_control},
               {:erlang, :monitor, [:process, args.owner]}
             )

      assert before?(
               calls,
               {:erlang, :monitor, [:process, args.owner]},
               {Accounting, :validate, [{:state, :probe}, state]}
             )

      refute Enum.any?(calls, &match?({GenServer, :call, _}, &1))
    end

    test "#{protocol} actual preparation validates all original boundary roles and sanitized S" do
      state = fixture(unquote(protocol))

      {{:ok, staged, :group_open}, calls} =
        traced(fn -> Probe.prepare_group_open(state, self(), 2_000) end)

      assert {:group_prepared, options} = staged.request_options
      assert options.request.method === :head
      assert options.request.fields === []
      assert options.request.body_mode === :none and options.request.max_upload_bytes === 1
      assert options.request.url === state.url
      assert options.deadline === state.deadline and options.opening_deadline === state.deadline
      assert options.timeout === 2_000 and options.opening_timeout === 2_000
      assert options.managed_transport === state.managed_transport
      assert staged.owner_monitor === state.owner_monitor and staged.timer === state.timer
      assert staged.transport_selection === state.transport_selection
      assert staged.transport_pins === state.transport_pins

      for field <- [:member, :group, :health, :url, :managed_transport, :submitted_url],
          do: assert(Map.fetch!(staged, field) === nil)

      assert_call(calls, Accounting, :validate, [{:state, :probe}, state])
      assert_call(calls, Accounting, :validate, [:selected, state.member])
      assert_call(calls, Accounting, :validate, [:checked, state.managed_transport])
      assert Enum.any?(calls, &match?({Accounting, :validate, [:neutral, _]}, &1))
      assert Enum.any?(calls, &match?({Accounting, :validate, [:context, _]}, &1))
      assert_call(calls, Accounting, :validate, [:request, options.request])
      assert_call(calls, Accounting, :validate, [:options, options])
      assert_call(calls, Accounting, :validate, [{:state, :probe}, staged])
      refute owner_monitor?(calls, state.owner)
      refute Enum.any?(calls, &match?({GenServer, :call, _}, &1))
    end

    test "#{protocol} open result accounts U and S while retaining original completion and ledgers" do
      assert {:ok, staged, :group_open} =
               Probe.prepare_group_open(fixture(unquote(protocol)), self(), 2_000)

      completion = %HTTP.RequestCompletion{
        tracker: fn -> :opaque end,
        latch: fn -> :opaque end,
        unsupported: nil
      }

      handle = public_handle(completion)
      result = {:ok, handle, nil}

      {{:ok, bound, :group_bind}, calls} =
        traced(fn -> Probe.group_open_result(staged, result, 2_000) end)

      assert bound.request === handle and bound.original_request === handle
      assert bound.original_request.completion === completion
      assert bound.transport_selection === staged.transport_selection
      assert bound.transport_pins === staged.transport_pins
      assert bound.request_options === nil and bound.managed_transport === nil
      assert bound.submitted_url === elem(staged.request_options, 1).request.url
      assert_call(calls, Accounting, :validate, [:open_result, result])
      assert_call(calls, Accounting, :validate, [{:state, :probe}, bound])
      refute Enum.any?(calls, &match?({GenServer, :call, _}, &1))
    end
  end

  for kind <- [:selection, :probe] do
    test "#{kind} recovery init keeps original opaque completion in exact5 state without owner call" do
      completion = %HTTP.RequestCompletion{
        tracker: fn -> :opaque end,
        latch: fn -> :opaque end,
        unsupported: fn -> :opaque end
      }

      args = %{
        owner: self(),
        recovery: {unquote(kind), make_ref()},
        completion: completion,
        deadline: 9_000
      }

      {{:ok, state}, calls} = traced(fn -> Probe.init(args) end)

      assert Enum.sort(Map.keys(state)) ===
               Enum.sort([:owner, :recovery, :completion, :deadline, :owner_monitor])

      assert Map.delete(state, :owner_monitor) === args
      assert state.completion === completion
      assert is_reference(state.owner_monitor)
      assert_call(calls, Accounting, :startup, [Probe, args])
      assert_call(calls, Accounting, :preflight_control, [:monitor, args.owner])
      assert_call(calls, Accounting, :validate, [{:state, :recovery}, state])
      assert before?(calls, {Accounting, :startup}, {:erlang, :monitor, [:process, args.owner]})

      assert before?(
               calls,
               {Accounting, :preflight_control},
               {:erlang, :monitor, [:process, args.owner]}
             )

      refute Enum.any?(calls, &match?({GenServer, :call, _}, &1))
    end
  end

  test "invalid normal startup creates no monitor and no owner call" do
    args = fixture() |> Map.take(@normal_keys) |> Map.put(:extra, fn -> :unbounded end)
    {{:stop, :invalid_probe_arguments}, calls} = traced(fn -> Probe.init(args) end)
    refute owner_monitor?(calls, args.owner)
    refute Enum.any?(calls, &match?({GenServer, :call, _}, &1))
  end

  test "invalid recovery shell creates no monitor and keeps producer refusal" do
    args = %{
      owner: self(),
      recovery: {:probe, make_ref()},
      completion: %HTTP.RequestCompletion{},
      deadline: 9_000,
      extra: nil
    }

    {{:stop, :invalid_probe_arguments}, calls} = traced(fn -> Probe.init(args) end)
    refute owner_monitor?(calls, args.owner)
    refute Enum.any?(calls, &match?({GenServer, :call, _}, &1))
  end

  test "invalid original S is rejected before boundary and preserves genuine cleanup ledger fields" do
    original = Map.put(fixture(), :extra, fn -> :unbounded end)

    {{:error, :invalid_request, dropped}, calls} =
      traced(fn -> Probe.prepare_group_open(original, self(), 2_000) end)

    assert dropped.original_request === original.original_request
    assert dropped.transport_selection === original.transport_selection
    assert dropped.transport_pins === original.transport_pins
    assert_call(calls, Accounting, :validate, [{:state, :probe}, original])
    refute Enum.any?(calls, &match?({Accounting, :validate, [:options, _]}, &1))
    refute Enum.any?(calls, &match?({GenServer, :call, _}, &1))
  end

  test "a late supported success captures the original handle before rejecting and retains both ledgers" do
    assert {:ok, staged, :group_open} = Probe.prepare_group_open(fixture(), self(), 2_000)
    handle = public_handle()
    result = {:ok, handle, nil}

    {{:error, :request_timeout, dropped}, calls} =
      traced(fn -> Probe.group_open_result(staged, result, staged.deadline) end)

    assert dropped.request === handle and dropped.original_request === handle
    assert dropped.transport_selection === staged.transport_selection
    assert dropped.transport_pins === staged.transport_pins
    assert_call(calls, Accounting, :validate, [:open_result, result])
  end

  test "expanded success envelope keeps supported original capability and an unconfirmed cleanup discriminator" do
    assert {:ok, staged, :group_open} = Probe.prepare_group_open(fixture(), self(), 2_000)
    handle = public_handle()
    result = {:ok, handle, nil, :expanded}

    {{:error, {:cleanup_unconfirmed, :invalid_response}, dropped}, calls} =
      traced(fn -> Probe.group_open_result(staged, result, 2_000) end)

    assert dropped.request === handle and dropped.original_request === handle
    assert dropped.transport_selection === staged.transport_selection
    assert dropped.transport_pins === staged.transport_pins
    assert_call(calls, Accounting, :validate, [:open_result, result])
  end

  defp assert_call(calls, module, function, args), do: assert({module, function, args} in calls)

  defp before?(calls, first, second) do
    first_index = Enum.find_index(calls, &trace_match?(&1, first))
    second_index = Enum.find_index(calls, &trace_match?(&1, second))
    is_integer(first_index) and is_integer(second_index) and first_index < second_index
  end

  defp owner_monitor?(calls, owner),
    do: Enum.any?(calls, &(&1 === {:erlang, :monitor, [:process, owner]}))

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

  defp fixture(protocol \\ :http2, raw_port? \\ false) do
    scheme = if protocol == :http2, do: "https", else: "http"
    port = if protocol == :http2, do: "00443", else: "00080"
    root = :binary.copy(scheme <> "://upstream.test" <> if(raw_port?, do: ":" <> port, else: ""))

    transport = %{
      provider: UpstreamTransports,
      owner: self(),
      owner_epoch: make_ref(),
      resource: make_ref()
    }

    group = %{
      provider: UpstreamGroups,
      owner: self(),
      owner_epoch: make_ref(),
      group: "health",
      generation: make_ref(),
      max_url_bytes: 8_192,
      transports: [transport],
      execution_profile: :managed_h2
    }

    limits = %{
      max_chunk_bytes: 1_024,
      opening_timeout: 4_000,
      idle_timeout: 3_000,
      write_timeout: 700,
      max_lifetime: 10_000
    }

    config = %Gaoxy.Proxy.HTTP{
      uri: URI.parse(root),
      upstream_protocol: protocol,
      client: ManagedH2Client,
      transport: transport,
      cacertfile: nil,
      connect_address: nil,
      limits: limits
    }

    health = %{
      path: "/health%2fready",
      interval: 1_000,
      timeout: 3_000,
      stale_after: 2_000,
      failure_threshold: 3,
      recovery_threshold: 2,
      jitter: 0
    }

    pin = %{
      provider: UpstreamTransports,
      owner: transport.owner,
      owner_epoch: transport.owner_epoch,
      operation: make_ref(),
      ref: make_ref(),
      handles: [transport],
      kind: :request,
      holder: self()
    }

    %{
      owner: self(),
      token: make_ref(),
      member: %{id: "member", config: config, max_inflight: 32},
      deadline: 4_000,
      health: health,
      url: :binary.copy(root <> health.path),
      group: group,
      cleanup_deadline: 5_000,
      owner_monitor: make_ref(),
      timer: make_ref(),
      request: nil,
      original_request: nil,
      managed_transport: checked_client(protocol, scheme <> "://upstream.test"),
      transport_selection: {transport, make_ref()},
      transport_pins: [pin],
      terminal: false,
      cancelled: false,
      headers: false,
      outcome: :failure,
      client: ManagedH2Client,
      limits: limits,
      request_options: nil,
      submitted_url: nil
    }
  end

  defp checked_client(protocol, origin) do
    {:ok, policy, _} =
      ManagedH2Preparation.prepare_policy(%{
        protocol: protocol,
        origin: origin,
        connect_address: {127, 0, 0, 1},
        trust: if(protocol == :http2, do: [<<48, 3, 2, 1, 1>>], else: nil)
      })

    %{
      policy: policy,
      transport_scope: struct(HTTP.ManagedTransport),
      fetch_options: [
        http_version: protocol,
        tls_backend: :ssl,
        http2_profile: :native_v1,
        http2_reuse: true,
        redirect: :manual,
        request_mode: :proxy,
        decode_body: false,
        stream_response: true,
        telemetry: false
      ]
    }
  end

  defp public_handle(
         completion \\ %HTTP.RequestCompletion{
           tracker: self(),
           latch: make_ref(),
           unsupported: nil
         }
       ) do
    task = %Task{owner: self(), pid: self(), ref: make_ref(), mfa: {:erlang, :apply, 2}}

    %{
      promise: %HTTP.Promise{task: task, completion: completion},
      completion: completion,
      stream: nil,
      resolved: false
    }
  end
end
