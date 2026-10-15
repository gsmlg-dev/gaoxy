support = Path.join(__DIR__, "support/managed_h2_group_startup_projection.exs")
if File.regular?(support), do: Code.require_file(support)

defmodule Gaoxy.Proxy.ManagedH2GroupStartupProjectionTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Proxy.{HTTPFetchClient, ManagedH2Client, UpstreamGroups}
  alias Gaoxy.Proxy.UpstreamGroups.Probe

  @projection Gaoxy.Proxy.ManagedH2GroupStartupProjection
  @modes [:h1, :h2, :recovery]
  @kinds [
    :arguments,
    :initial_state,
    :caller,
    :generated_spec,
    :normalized_child,
    :start_call,
    :apply_mfa,
    :gen_start,
    :gen_init_args,
    :proc_start,
    :proc_spawn,
    :proc_init,
    :gen_init_call,
    :callback_input,
    :callback_return,
    :otp_return,
    :init_ack,
    :child_start_result,
    :supervisor_return,
    :start_reply,
    :saved_entry,
    :child_loop_call
  ]
  @containing_arguments [
    :arguments,
    :initial_state,
    :caller,
    :generated_spec,
    :normalized_child,
    :start_call,
    :apply_mfa,
    :gen_start,
    :gen_init_args,
    :proc_start,
    :proc_spawn,
    :proc_init,
    :gen_init_call,
    :callback_input,
    :callback_return,
    :otp_return,
    :child_loop_call
  ]
  @project_keys [
    :projection,
    :projected_etf_bytes,
    :payload_etf_bytes,
    :completion_shells,
    :unmeasured,
    :bound
  ]
  @signed_min -9_223_372_036_854_775_808
  @signed_max 9_223_372_036_854_775_807
  @invalid {:error, :invalid_startup_projection}

  test "contract is closed and preserves the partial per-instance disposition" do
    actual = contract()

    assert actual == %{
             version: 1,
             unit: :external_term_payload_bytes,
             disposition: :partial_success_startup_catalog,
             modes: @modes,
             kinds: @kinds,
             phase_keys: @kinds,
             reservation_bytes: nil,
             startup_maximum: :unproved,
             recovery_release_order: :unproved,
             fixed_reservation_bytes: 9_444_956
           }

    assert apply(@projection, :__info__, [:functions]) ==
             [contract: 0, phase: 2, project: 2]
  end

  for mode <- @modes, kind <- @kinds do
    test "#{mode} #{kind} preserves its complete modeled source representation" do
      mode = unquote(mode)
      kind = unquote(kind)
      context = context(mode)
      input = original(kind, context)
      assert {:ok, result} = project(mode, kind, input)
      assert_constructor(mode, context.args)
      assert map_size(context.args) == argument_count(mode)
      assert map_size(context.state) == state_count(mode)
      expected = expected_projection(kind, context)
      expected_bytes = 1 + expected_nested(kind, context)

      assert Enum.sort(Map.keys(result)) == Enum.sort(@project_keys)
      assert result == %{
               projection: expected,
               projected_etf_bytes: expected_bytes,
               payload_etf_bytes: expected_payloads(mode, kind, context.args),
               completion_shells: if(mode == :recovery and kind in @containing_arguments, do: 1, else: 0),
               unmeasured: expected_unmeasured(kind),
               bound: :per_instance_only
             }

      # Independent wrapper algebra is the oracle. Encoding the independently
      # built expected term is a secondary grammar/version-byte sanity check.
      assert :erlang.external_size(expected) == expected_bytes
      assert byte_size(:erlang.term_to_binary(expected)) == expected_bytes
    end
  end

  test "invalid dispatch and arbitrary inputs have one finite payload-free error" do
    for {selector, input} <- [
          {:arguments, %{}},
          {{:other, :arguments}, %{}},
          {{:h1, :other}, fn -> :opaque end},
          {{:h1, :child_state_action}, {%{}, :infinity}},
          {{:h1, :arguments, :extra}, %{}},
          {[:h1, :arguments], %{}},
          {nil, %{}},
          {{:recovery, :arguments}, nil}
        ] do
      assert @invalid == apply(@projection, :project, [selector, input])
    end
  end

  for mode <- @modes do
    test "#{mode} rejects malformed syntax for every named source row" do
      mode = unquote(mode)
      context = context(mode)

      for kind <- @kinds, bad <- syntax_negatives(kind, context) do
        assert @invalid == project(mode, kind, bad)
      end
    end
  end

  for mode <- [:h1, :h2] do
    test "#{mode} rejects original constructor failures without normalizing payloads" do
      mode = unquote(mode)
      args = fixture(mode)

      for bad <- invalid_normal_arguments(args) do
        assert @invalid == project(mode, :arguments, bad)
        assert {:error, :invalid_probe_arguments} == start_arguments(bad)
      end
    end

    test "#{mode} rejects expanded and legacy direct-init members in the strict producer cohort" do
      mode = unquote(mode)
      args = fixture(mode)
      expanded = Map.merge(args.member, %{inflight: 0, probe: nil, checked: fn -> :opaque end})

      for member <- [expanded, %{config: args.member.config}, Map.put(args.member, :extra, :value)] do
        bad = %{args | member: member}
        assert @invalid == project(mode, :arguments, bad)
        assert {:error, :invalid_probe_arguments} == start_arguments(bad)
      end

      legacy = %{args | member: %{config: args.member.config}, health: %{timeout: 2_000}}
      assert @invalid == project(mode, :arguments, legacy)
      # Rejection here says nothing about the broader legacy Probe.init clause.
    end

    test "#{mode} exact initial-state additions reject missing extra and noninitial values" do
      mode = unquote(mode)
      context = context(mode)

      for key <- Map.keys(context.state) do
        assert @invalid == project(mode, :initial_state, Map.delete(context.state, key))
      end

      for {key, value} <- [
            extra: fn -> :opaque end,
            cleanup_deadline: context.args.deadline + 1_001,
            owner_monitor: nil,
            timer: nil,
            request: %{opaque: :handle},
            original_request: %{opaque: :original},
            managed_transport: :client,
            transport_selection: {:transport, make_ref()},
            transport_pins: [make_ref()],
            terminal: true,
            cancelled: true,
            headers: true,
            outcome: :success
          ] do
        assert @invalid == project(mode, :initial_state, Map.put(context.state, key, value))
      end
    end
  end

  test "H2 state retains the repeated finite limits control and rejects stale aliases" do
    context = context(:h2)
    assert {:ok, result} = project(:h2, :initial_state, context.state)
    assert result.projection.limits === context.args.member.config.limits
    assert result.projection.client === ManagedH2Client
    assert result.projection.request_options == nil
    assert result.projection.submitted_url == nil
    assert result.payload_etf_bytes.config == [:erlang.external_size(context.args.member.config)]

    for {key, value} <- [
          client: HTTPFetchClient,
          limits: %{context.state.limits | idle_timeout: context.state.limits.idle_timeout + 1},
          request_options: %{},
          submitted_url: context.args.url
        ] do
      assert @invalid == project(:h2, :initial_state, Map.put(context.state, key, value))
    end
  end

  test "H1 H2 and recovery original/state cohorts cannot be relabeled" do
    for {mode, wrong} <- [{:h1, :h2}, {:h2, :h1}, {:h1, :recovery}, {:recovery, :h2}] do
      context = context(mode)
      assert @invalid == project(wrong, :arguments, context.args)
      assert @invalid == project(wrong, :initial_state, context.state)
    end
  end

  test "both H2 protocols are constructor-admissible prospective fixtures" do
    for protocol <- [:http2, :h2c] do
      context = context(:h2, normal_arguments(protocol))
      assert {:ok, result} = project(:h2, :arguments, context.args)
      assert_constructor(:h2, context.args)
      assert result.projection.group === context.args.group
      assert result.bound == :per_instance_only
      assert result.payload_etf_bytes.config == [:erlang.external_size(context.args.member.config)]
    end

    # These are pure constructor/descriptor fixtures, never an activated child.
  end

  test "H2 group ownership manifest selection URL and finite inputs remain original" do
    args = fixture(:h2)
    outside = transport()
    backed_url = slice(args.url <> :binary.copy("p", 100), 4_096)

    for bad <- [
          %{args | owner: other_pid()},
          %{args | group: %{args.group | transports: [args.member.config.transport, args.member.config.transport]}},
          %{args | group: %{args.group | transports: [outside]}},
          %{args | group: Map.put(args.group, :extra, fn -> :opaque end)},
          %{args | group: %{args.group | execution_profile: :http1}},
          %{args | url: args.url <> "?different"},
          %{args | url: backed_url},
          %{args | deadline: @signed_max - 999},
          %{args | deadline: @signed_min - 1},
          %{args | member: %{args.member | config: %{args.member.config | limits: %{args.member.config.limits | opening_timeout: 86_400_001}}}}
        ] do
      assert @invalid == project(:h2, :arguments, bad)
      assert {:error, :invalid_probe_arguments} == start_arguments(bad)
    end
  end

  test "normal complete payload occurrences are measured once and removed from controls" do
    for mode <- [:h1, :h2], kind <- @containing_arguments do
      context = context(mode)
      assert {:ok, result} = project(mode, kind, original(kind, context))
      assert result.payload_etf_bytes == expected_payloads(mode, kind, context.args)
      assert result.completion_shells == 0
      assert result.projection === expected_projection(kind, context)
      encoded = :erlang.term_to_binary(result.projection)
      assert :binary.match(encoded, context.args.url) == :nomatch
      assert :binary.match(encoded, context.args.health.path) == :nomatch
      assert :binary.match(encoded, context.args.member.config.uri.authority) == :nomatch
    end
  end

  test "caller-supplied payload and opaque markers never certify bounded originals" do
    for mode <- [:h1, :h2] do
      args = fixture(mode)

      for bad <- [
            %{args | url: {:payload, :url}},
            %{args | health: %{args.health | path: {:payload, :health_path}}},
            %{args | member: %{args.member | config: {:payload, :config}}}
          ] do
        assert @invalid == project(mode, :arguments, bad)
      end
    end

    args = fixture(:recovery)
    assert @invalid == project(:recovery, :arguments, %{args | completion: {:opaque, HTTP.RequestCompletion}})
  end

  test "recovery accepts both kinds and signed64 originals without cleanup headroom" do
    for kind <- [:selection, :probe], deadline <- [@signed_min, -1, 0, @signed_max] do
      args = %{fixture(:recovery) | recovery: {kind, make_ref()}, deadline: deadline}
      assert {:ok, result} = project(:recovery, :arguments, args)
      assert_constructor(:recovery, args)
      assert result.projection.deadline === deadline
      assert result.projection.recovery === args.recovery
      assert result.projection.completion == {:opaque, HTTP.RequestCompletion}
      assert result.payload_etf_bytes == empty_payloads()
    end
  end

  test "recovery rejects malformed originals and exact-shell changes without retaining diagnostics" do
    args = fixture(:recovery)

    invalid =
      [nil, [], %{}, Map.put(args, :extra, fn -> :opaque end)] ++
        Enum.map(Map.keys(args), &Map.delete(args, &1)) ++
        [
          %{args | owner: make_ref()},
          %{args | recovery: {:other, make_ref()}},
          %{args | recovery: {:probe, nil}},
          %{args | recovery: {:probe, make_ref(), :extra}},
          %{args | completion: Map.from_struct(args.completion)},
          %{args | completion: Map.put(args.completion, :extra, fn -> :opaque end)},
          %{args | completion: %{args.completion | __struct__: HTTP.Promise}},
          %{args | deadline: @signed_min - 1},
          %{args | deadline: @signed_max + 1}
        ]

    for bad <- invalid do
      assert @invalid == project(:recovery, :arguments, bad)
      assert {:error, :invalid_probe_arguments} == recovery_arguments(bad)
    end

    context = context(:recovery)
    assert @invalid == project(:recovery, :initial_state, Map.put(context.state, :timer, make_ref()))
    assert @invalid == project(:recovery, :initial_state, %{context.state | owner_monitor: nil})
  end

  test "opaque completion interiors never contribute ETF bytes in any containing row" do
    baseline = context(:recovery)
    large = :binary.copy("opaque-completion-sentinel", 8_192)
    hidden = fn -> raise "opaque completion interior must not execute: #{byte_size(large)}" end
    completion = %HTTP.RequestCompletion{tracker: hidden, latch: [large | :opaque_tail], unsupported: %{hidden: hidden}}
    changed = with_arguments(baseline, %{baseline.args | completion: completion})

    for kind <- @containing_arguments do
      assert {:ok, first} = project(:recovery, kind, original(kind, baseline))
      assert {:ok, second} = project(:recovery, kind, original(kind, changed))
      assert second === first
      assert second.completion_shells == 1
      assert second.projection === expected_projection(kind, changed)
      assert second.payload_etf_bytes == empty_payloads()
      assert :binary.match(:erlang.term_to_binary(second.projection), large) == :nomatch
    end

    assert {:ok, returned} = recovery_arguments(changed.args)
    assert returned === changed.args
    assert returned.completion === completion
  end

  test "raw ancestor interiors are excluded in both proc descriptors before encoding" do
    baseline = context(:h1)
    large = :binary.copy("opaque-ancestors-sentinel", 8_192)
    hidden = fn -> raise "ancestor interior must not execute: #{byte_size(large)}" end
    changed = %{baseline | ancestors: [hidden, %{large: large}]}

    for kind <- [:proc_spawn, :proc_init] do
      assert {:ok, first} = project(:h1, kind, original(kind, baseline))
      assert {:ok, second} = project(:h1, kind, original(kind, changed))
      assert second === first
      assert second.unmeasured == [:proc_ancestors]
      assert second.projection === expected_projection(kind, changed)
      assert :binary.match(:erlang.term_to_binary(second.projection), large) == :nomatch
    end
  end

  test "private supervisor map contents are excluded rather than counted as zero" do
    baseline = context(:h2)
    large = :binary.copy("opaque-supervisor-sentinel", 8_192)
    hidden = fn -> raise "supervisor interior must not execute: #{byte_size(large)}" end
    changed = %{baseline | supervisor_state: %{unbounded: [large, hidden]}}
    assert {:ok, first} = project(:h2, :supervisor_return, original(:supervisor_return, baseline))
    assert {:ok, second} = project(:h2, :supervisor_return, original(:supervisor_return, changed))
    assert second === first
    assert second.projection == {:reply, {:ok, baseline.child}, {:UNMEASURED, :dynamic_supervisor_state}}
    assert second.unmeasured == [:dynamic_supervisor_state]
  end

  test "loop descriptor excludes source record internals and retains actual default debug and action" do
    for mode <- @modes do
      baseline = context(mode)
      changed = %{baseline | server_data: put_elem(baseline.server_data, 2, make_ref())}
      assert {:ok, first} = project(mode, :child_loop_call, original(:child_loop_call, baseline))
      assert {:ok, second} = project(mode, :child_loop_call, original(:child_loop_call, changed))
      assert second === first
      assert second.unmeasured == [:child_private_runtime]
      assert second.projection == {:gen_server, :loop, [{:UNMEASURED, :child_private_runtime}, projected_state(baseline), loop_action(mode), []]}
      assert tuple_size(baseline.server_data) == 10
      assert elem(baseline.server_data, 6) === Function.capture(Probe, :handle_call, 3)
      assert elem(baseline.server_data, 7) === Function.capture(Probe, :handle_cast, 2)
      assert elem(baseline.server_data, 8) === Function.capture(Probe, :handle_info, 2)
      assert elem(baseline.server_data, 9) === Function.capture(Probe, :handle_continue, 2)
      assert @invalid == project(mode, :child_loop_call, {baseline.state, loop_action(mode)})
    end
  end

  test "loop record validation rejects opaque payloads in source-constrained slots" do
    context = context(:h1)
    large = :binary.copy("invalid-private-slot", 8_192)
    hidden = fn -> large end

    for server_data <- [
          put_elem(context.server_data, 0, :wrong_record),
          Tuple.append(context.server_data, :extra),
          put_elem(context.server_data, 1, make_ref()),
          put_elem(context.server_data, 2, large),
          put_elem(context.server_data, 2, hidden),
          put_elem(context.server_data, 3, make_ref()),
          put_elem(context.server_data, 4, UpstreamGroups),
          put_elem(context.server_data, 5, 5_000),
          put_elem(context.server_data, 6, hidden),
          put_elem(context.server_data, 7, Function.capture(Probe, :handle_info, 2)),
          put_elem(context.server_data, 8, Function.capture(Probe, :handle_cast, 2)),
          put_elem(context.server_data, 9, Function.capture(Probe, :handle_info, 2))
        ] do
      bad = {:gen_server, :loop, [server_data, context.state, {:continue, :open}, []]}
      assert @invalid == project(:h1, :child_loop_call, bad)
    end
  end

  test "H1 arbitrary URLs remain parameterized and complete payload sizes grow" do
    baseline = context(:h1)
    assert {:ok, first} = project(:h1, :arguments, baseline.args)

    for url <- ["", :binary.copy("long-url-sentinel", 8_192)] do
      args = %{baseline.args | url: url}
      assert {:ok, result} = project(:h1, :arguments, args)
      assert_constructor(:h1, args)
      assert result.projection === first.projection
      assert result.projected_etf_bytes == first.projected_etf_bytes
      assert result.payload_etf_bytes.url == [1 + 5 + byte_size(url)]
      assert result.bound == :per_instance_only
    end

    longer = %{baseline.args | url: :binary.copy("u", 131_072)}
    assert {:ok, result} = project(:h1, :arguments, longer)
    assert hd(result.payload_etf_bytes.url) > hd(first.payload_etf_bytes.url)
  end

  test "H1 positive config bignums grow complete config payload without adding an H2 cap" do
    baseline = context(:h1)
    assert {:ok, first} = project(:h1, :arguments, baseline.args)
    huge = Integer.pow(256, 255)

    for key <- [:opening_timeout, :idle_timeout, :write_timeout, :max_lifetime] do
      limits = Map.put(baseline.args.member.config.limits, key, huge)
      config = %{baseline.args.member.config | limits: limits}
      args = %{baseline.args | member: %{baseline.args.member | config: config}}
      assert {:ok, result} = project(:h1, :arguments, args)
      assert_constructor(:h1, args)
      assert result.projection === first.projection
      assert result.payload_etf_bytes.config == [:erlang.external_size(config)]
      assert hd(result.payload_etf_bytes.config) > hd(first.payload_etf_bytes.config)
    end
  end

  test "H1 arbitrary deadline integers and cleanup additions use exact bignum formulas" do
    baseline = context(:h1)
    assert {:ok, small} = project(:h1, :initial_state, baseline.state)

    for deadline <- [@signed_min - 1, @signed_max + 1, -Integer.pow(256, 255), Integer.pow(256, 255)] do
      context = with_arguments(baseline, %{baseline.args | deadline: deadline})
      assert {:ok, result} = project(:h1, :initial_state, context.state)
      assert_constructor(:h1, context.args)
      assert result.projection.deadline === deadline
      assert result.projection.cleanup_deadline === deadline + 1_000
      assert result.projected_etf_bytes == 1 + expected_nested(:initial_state, context)

      if abs(deadline) >= Integer.pow(256, 255) do
        assert result.projected_etf_bytes > small.projected_etf_bytes
      end
    end
  end

  test "H1 existing backed binaries and query paths keep original constructor acceptance" do
    args = fixture(:h1)
    path = slice("/health?query=%2f" <> :binary.copy("p", 80), 4_096)
    url = slice("http://upstream.test" <> path, 4_096)
    id = slice(:binary.copy("i", 100), 4_096)
    args = %{args | health: %{args.health | path: path}, url: url, member: %{args.member | id: id}}
    assert {:ok, result} = project(:h1, :arguments, args)
    assert_constructor(:h1, args)
    assert :binary.referenced_byte_size(path) > byte_size(path)
    assert :binary.referenced_byte_size(url) > byte_size(url)
    assert :binary.referenced_byte_size(id) > byte_size(id)
    assert result.payload_etf_bytes == expected_payloads(:h1, :arguments, args)
  end

  test "ETF independent integer algebra covers small signed32 and 255-digit transitions" do
    assert contract().unit == :external_term_payload_bytes

    for integer <- [
          0, 1, 255, 256, -1, -2_147_483_648, 2_147_483_647,
          -2_147_483_649, 2_147_483_648, @signed_min, @signed_max,
          Integer.pow(256, 254), -Integer.pow(256, 254),
          Integer.pow(256, 255), -Integer.pow(256, 255)
        ] do
      assert :erlang.external_size(integer) == 1 + integer_nested(integer)
    end

    assert integer_nested(255) == 2
    assert integer_nested(256) == 5
    assert integer_nested(2_147_483_647) == 5
    assert integer_nested(2_147_483_648) == 7
    assert integer_nested(Integer.pow(256, 254)) == 258
    assert integer_nested(Integer.pow(256, 255)) == 262
  end

  test "ETF constructor algebra counts the whole version once and distinguishes STRING_EXT" do
    assert contract().unit == :external_term_payload_bytes
    binary = :binary.copy("b", 300)
    tuple = {:ok, binary}
    list = [:ok, tuple]
    map = %{one: binary, two: tuple}
    assert :erlang.external_size(binary) == 1 + binary_nested(binary)
    assert :erlang.external_size(tuple) == 1 + tuple_nested([leaf(:ok), binary_nested(binary)])
    assert :erlang.external_size(list) == 1 + proper_list_nested([leaf(:ok), tuple_nested([leaf(:ok), binary_nested(binary)])])
    assert :erlang.external_size(map) == 1 + map_nested(one: binary_nested(binary), two: tuple_nested([leaf(:ok), binary_nested(binary)]))
    assert :erlang.external_size([]) == 2
    assert :erlang.external_size([0, 127, 255]) == 1 + 3 + 3
    assert :erlang.external_size([0, 127, 255]) != 1 + proper_list_nested([2, 2, 2])
    assert :erlang.external_size(tuple) != 1 + 2 + :erlang.external_size(:ok) + :erlang.external_size(binary)
  end

  test "public generated child-spec oracles preserve the exact marker and three-key shape" do
    assert contract().startup_maximum == :unproved
    marker = :opaque_startup_argument_marker
    expected = %{id: Probe, start: {Probe, :start_link, [marker]}, restart: :temporary}
    assert Probe.child_spec(marker) === expected
    assert Supervisor.child_spec({Probe, marker}, []) === expected
    assert map_size(expected) == 3
  end

  defp contract, do: apply(@projection, :contract, [])
  defp project(mode, kind, value), do: apply(@projection, :project, [{mode, kind}, value])
  defp start_arguments(args), do: apply(UpstreamGroups, :probe_start_arguments, [args])
  defp recovery_arguments(args), do: apply(UpstreamGroups, :probe_recovery_arguments, [args])

  defp assert_constructor(:recovery, args), do: assert({:ok, args} === recovery_arguments(args))
  defp assert_constructor(_, args), do: assert({:ok, args} === start_arguments(args))
  defp argument_count(:h1), do: 6
  defp argument_count(:h2), do: 7
  defp argument_count(:recovery), do: 4
  defp state_count(:h1), do: 18
  defp state_count(:h2), do: 23
  defp state_count(:recovery), do: 5
  defp loop_action(:recovery), do: :infinity
  defp loop_action(_), do: {:continue, :open}

  defp context(mode), do: context(mode, fixture(mode))

  defp context(mode, args) do
    supervisor = self()
    child = self()

    %{
      mode: mode,
      args: args,
      state: initial_state(mode, args),
      supervisor: supervisor,
      child: child,
      start_reference: make_ref(),
      ancestors: [],
      supervisor_state: %{children: %{}, extra_arguments: []},
      server_data: {
        :server_data, supervisor, make_ref(), child, Probe, :infinity,
        Function.capture(Probe, :handle_call, 3),
        Function.capture(Probe, :handle_cast, 2),
        Function.capture(Probe, :handle_info, 2),
        Function.capture(Probe, :handle_continue, 2)
      }
    }
  end

  defp initial_state(:recovery, args), do: Map.put(args, :owner_monitor, make_ref())

  defp initial_state(mode, args) do
    state = Map.merge(args, %{
      cleanup_deadline: args.deadline + 1_000,
      owner_monitor: make_ref(),
      timer: make_ref(),
      request: nil,
      original_request: nil,
      managed_transport: nil,
      transport_selection: nil,
      transport_pins: [],
      terminal: false,
      cancelled: false,
      headers: false,
      outcome: :failure
    })

    if mode == :h2 do
      Map.merge(state, %{client: ManagedH2Client, limits: args.member.config.limits,
                         request_options: nil, submitted_url: nil})
    else
      state
    end
  end

  defp with_arguments(context, args) do
    state = Map.merge(context.state, args)
    state = if context.mode == :recovery, do: state, else: %{state | cleanup_deadline: args.deadline + 1_000}
    state = if context.mode == :h2, do: %{state | limits: args.member.config.limits}, else: state
    %{context | args: args, state: state}
  end

  # These descriptors are supplied models of source calls, not executed calls
  # or assertions that the source constructs their enclosing tuple/list objects.
  defp original(kind, context) do
    a = context.args
    s = context.state
    d = context.supervisor
    c = context.child
    r = context.start_reference
    normalized = {{Probe, :start_link, [a]}, :temporary, 5_000, :worker, [Probe]}
    gen_args = [:gen_server, d, d, Probe, a, []]
    callback = if context.mode == :recovery, do: {:ok, s}, else: {:ok, s, {:continue, :open}}

    case kind do
      :arguments -> a
      :initial_state -> s
      :caller -> {Probe, a}
      :generated_spec -> %{id: Probe, start: {Probe, :start_link, [a]}, restart: :temporary}
      :normalized_child -> normalized
      :start_call -> {:'$gen_call', {a.owner, r}, {:start_child, normalized}}
      :apply_mfa -> {Probe, :start_link, [a]}
      :gen_start -> {:gen, :start, [:gen_server, :link, Probe, a, []]}
      :gen_init_args -> gen_args
      :proc_start -> {:proc_lib, :start_link, [:gen, :init_it, gen_args, :infinity, []]}
      :proc_spawn -> {:erlang, :spawn_opt, [:proc_lib, :init_p, [Gaoxy.Proxy.ProbeSupervisor, context.ancestors, :gen, :init_it, gen_args], [:link, :monitor]]}
      :proc_init -> {:proc_lib, :init_p, [Gaoxy.Proxy.ProbeSupervisor, context.ancestors, :gen, :init_it, gen_args]}
      :gen_init_call -> {:gen_server, :init_it, [d, d, c, Probe, a, []]}
      :callback_input -> {Probe, :init, [a]}
      :callback_return -> callback
      :otp_return -> {:ok, callback}
      :init_ack -> {:ack, c, {:ok, c}}
      :child_start_result -> {:ok, c}
      :supervisor_return -> {:reply, {:ok, c}, context.supervisor_state}
      :start_reply -> {r, {:ok, c}}
      :saved_entry -> {c, {{Probe, :start_link, :undefined}, :temporary, 5_000, :worker, [Probe]}}
      :child_loop_call -> {:gen_server, :loop, [context.server_data, s, loop_action(context.mode), []]}
    end
  end

  defp projected_arguments(%{mode: :recovery, args: args}) do
    %{args | completion: {:opaque, HTTP.RequestCompletion}}
  end

  defp projected_arguments(context) do
    %{context.args |
      member: %{context.args.member | config: {:payload, :config}},
      health: %{context.args.health | path: {:payload, :health_path}},
      url: {:payload, :url}
    }
  end

  defp projected_state(context), do: Map.merge(context.state, projected_arguments(context))

  # Independently specified safe expected terms, separate from the original
  # row constructor and from the module under test. No original opaque value
  # is passed to an ETF size/encoding function.
  defp expected_projection(kind, context) do
    a = projected_arguments(context)
    s = projected_state(context)
    d = context.supervisor
    c = context.child
    r = context.start_reference
    normalized = {{Probe, :start_link, [a]}, :temporary, 5_000, :worker, [Probe]}
    gen_args = [:gen_server, d, d, Probe, a, []]
    callback = if context.mode == :recovery, do: {:ok, s}, else: {:ok, s, {:continue, :open}}

    case kind do
      :arguments -> a
      :initial_state -> s
      :caller -> {Probe, a}
      :generated_spec -> %{id: Probe, start: {Probe, :start_link, [a]}, restart: :temporary}
      :normalized_child -> normalized
      :start_call -> {:'$gen_call', {a.owner, r}, {:start_child, normalized}}
      :apply_mfa -> {Probe, :start_link, [a]}
      :gen_start -> {:gen, :start, [:gen_server, :link, Probe, a, []]}
      :gen_init_args -> gen_args
      :proc_start -> {:proc_lib, :start_link, [:gen, :init_it, gen_args, :infinity, []]}
      :proc_spawn -> {:erlang, :spawn_opt, [:proc_lib, :init_p, [Gaoxy.Proxy.ProbeSupervisor, {:UNMEASURED, :proc_ancestors}, :gen, :init_it, gen_args], [:link, :monitor]]}
      :proc_init -> {:proc_lib, :init_p, [Gaoxy.Proxy.ProbeSupervisor, {:UNMEASURED, :proc_ancestors}, :gen, :init_it, gen_args]}
      :gen_init_call -> {:gen_server, :init_it, [d, d, c, Probe, a, []]}
      :callback_input -> {Probe, :init, [a]}
      :callback_return -> callback
      :otp_return -> {:ok, callback}
      :init_ack -> {:ack, c, {:ok, c}}
      :child_start_result -> {:ok, c}
      :supervisor_return -> {:reply, {:ok, c}, {:UNMEASURED, :dynamic_supervisor_state}}
      :start_reply -> {r, {:ok, c}}
      :saved_entry -> {c, {{Probe, :start_link, :undefined}, :temporary, 5_000, :worker, [Probe]}}
      :child_loop_call -> {:gen_server, :loop, [{:UNMEASURED, :child_private_runtime}, s, loop_action(context.mode), []]}
    end
  end

  defp expected_payloads(mode, kind, args) when mode in [:h1, :h2] and kind in @containing_arguments do
    %{
      config: [:erlang.external_size(args.member.config)],
      url: [1 + binary_nested(args.url)],
      health_path: [1 + binary_nested(args.health.path)]
    }
  end

  defp expected_payloads(_, _, _), do: empty_payloads()
  defp empty_payloads, do: %{config: [], url: [], health_path: []}
  defp expected_unmeasured(:apply_mfa), do: [:vm_call_stack]
  defp expected_unmeasured(kind) when kind in [:proc_spawn, :proc_init], do: [:proc_ancestors]
  defp expected_unmeasured(:supervisor_return), do: [:dynamic_supervisor_state]
  defp expected_unmeasured(:child_loop_call), do: [:child_private_runtime]
  defp expected_unmeasured(_), do: []

  # Integer and wrapper formulas use ETF constructors, not whole-row encoding.
  # leaf/1 is deliberately limited to scalar atoms/PIDs/refs; it is not a term
  # walker, size oracle for A/S, or encoder for opaque/private source values.
  defp leaf(term) when is_atom(term) or is_pid(term) or is_reference(term), do: :erlang.external_size(term) - 1
  defp binary_nested(binary), do: 5 + byte_size(binary)
  defp tuple_nested(sizes), do: 2 + Enum.sum(sizes)
  defp proper_list_nested(sizes), do: 6 + Enum.sum(sizes)
  defp map_nested(entries), do: 5 + Enum.sum(Enum.map(entries, fn {key, size} -> leaf(key) + size end))

  defp integer_nested(value) when value >= 0 and value <= 255, do: 2
  defp integer_nested(value) when value >= -2_147_483_648 and value <= 2_147_483_647, do: 5

  defp integer_nested(value) do
    digits = byte_size(:binary.encode_unsigned(abs(value)))
    if digits <= 255, do: 3 + digits, else: 6 + digits
  end

  defp marker_nested(role), do: tuple_nested([leaf(:UNMEASURED), leaf(role)])
  defp payload_nested(role), do: tuple_nested([leaf(:payload), leaf(role)])
  defp action_nested(:recovery), do: leaf(:infinity)
  defp action_nested(_), do: tuple_nested([leaf(:continue), leaf(:open)])

  defp arguments_nested(%{mode: :recovery, args: a}) do
    {kind, token} = a.recovery
    map_nested(owner: leaf(a.owner), recovery: tuple_nested([leaf(kind), leaf(token)]),
               completion: tuple_nested([leaf(:opaque), leaf(HTTP.RequestCompletion)]),
               deadline: integer_nested(a.deadline))
  end

  defp arguments_nested(context) do
    a = context.args
    health = a.health
    selected = map_nested(id: binary_nested(a.member.id), config: payload_nested(:config),
                          max_inflight: integer_nested(a.member.max_inflight))
    health_size = map_nested(path: payload_nested(:health_path), interval: integer_nested(health.interval),
                            timeout: integer_nested(health.timeout), stale_after: integer_nested(health.stale_after),
                            failure_threshold: integer_nested(health.failure_threshold),
                            recovery_threshold: integer_nested(health.recovery_threshold), jitter: integer_nested(health.jitter))
    entries = [owner: leaf(a.owner), token: leaf(a.token), member: selected,
               deadline: integer_nested(a.deadline), health: health_size, url: payload_nested(:url)]
    entries = if context.mode == :h2, do: entries ++ [group: group_nested(a.group)], else: entries
    map_nested(entries)
  end

  defp state_nested(%{mode: :recovery} = context) do
    arguments_nested(context) + leaf(:owner_monitor) + leaf(context.state.owner_monitor)
  end

  defp state_nested(context) do
    s = context.state
    additions = [cleanup_deadline: integer_nested(s.cleanup_deadline), owner_monitor: leaf(s.owner_monitor),
                 timer: leaf(s.timer), request: leaf(nil), original_request: leaf(nil),
                 managed_transport: leaf(nil), transport_selection: leaf(nil), transport_pins: 1,
                 terminal: leaf(false), cancelled: leaf(false), headers: leaf(false), outcome: leaf(:failure)]
    additions = if context.mode == :h2 do
      additions ++ [client: leaf(ManagedH2Client), limits: limits_nested(s.limits),
                    request_options: leaf(nil), submitted_url: leaf(nil)]
    else
      additions
    end
    arguments_nested(context) + map_nested(additions) - 5
  end

  defp limits_nested(limits) do
    map_nested(max_chunk_bytes: integer_nested(limits.max_chunk_bytes),
               opening_timeout: integer_nested(limits.opening_timeout),
               idle_timeout: integer_nested(limits.idle_timeout),
               write_timeout: integer_nested(limits.write_timeout),
               max_lifetime: integer_nested(limits.max_lifetime))
  end

  defp transport_nested(transport) do
    map_nested(provider: leaf(transport.provider), owner: leaf(transport.owner),
               owner_epoch: leaf(transport.owner_epoch), resource: leaf(transport.resource))
  end

  defp group_nested(group) do
    map_nested(provider: leaf(group.provider), owner: leaf(group.owner),
               owner_epoch: leaf(group.owner_epoch), group: binary_nested(group.group),
               generation: leaf(group.generation), max_url_bytes: integer_nested(group.max_url_bytes),
               transports: proper_list_nested(Enum.map(group.transports, &transport_nested/1)),
               execution_profile: leaf(group.execution_profile))
  end

  defp expected_nested(kind, context) do
    a = arguments_nested(context)
    s = state_nested(context)
    p = leaf(Probe)
    d = leaf(context.supervisor)
    c = leaf(context.child)
    r = leaf(context.start_reference)
    mfa = tuple_nested([p, leaf(:start_link), proper_list_nested([a])])
    normalized = tuple_nested([mfa, leaf(:temporary), integer_nested(5_000), leaf(:worker), proper_list_nested([p])])
    gen_args = proper_list_nested([leaf(:gen_server), d, d, p, a, 1])
    callback = if context.mode == :recovery,
      do: tuple_nested([leaf(:ok), s]),
      else: tuple_nested([leaf(:ok), s, action_nested(context.mode)])
    success = tuple_nested([leaf(:ok), c])

    case kind do
      :arguments -> a
      :initial_state -> s
      :caller -> tuple_nested([p, a])
      :generated_spec -> map_nested(id: p, start: mfa, restart: leaf(:temporary))
      :normalized_child -> normalized
      :start_call -> tuple_nested([leaf(:'$gen_call'), tuple_nested([leaf(context.args.owner), r]), tuple_nested([leaf(:start_child), normalized])])
      :apply_mfa -> mfa
      :gen_start -> tuple_nested([leaf(:gen), leaf(:start), proper_list_nested([leaf(:gen_server), leaf(:link), p, a, 1])])
      :gen_init_args -> gen_args
      :proc_start -> tuple_nested([leaf(:proc_lib), leaf(:start_link), proper_list_nested([leaf(:gen), leaf(:init_it), gen_args, leaf(:infinity), 1])])
      :proc_spawn -> tuple_nested([leaf(:erlang), leaf(:spawn_opt), proper_list_nested([leaf(:proc_lib), leaf(:init_p), proper_list_nested([leaf(Gaoxy.Proxy.ProbeSupervisor), marker_nested(:proc_ancestors), leaf(:gen), leaf(:init_it), gen_args]), proper_list_nested([leaf(:link), leaf(:monitor)])])])
      :proc_init -> tuple_nested([leaf(:proc_lib), leaf(:init_p), proper_list_nested([leaf(Gaoxy.Proxy.ProbeSupervisor), marker_nested(:proc_ancestors), leaf(:gen), leaf(:init_it), gen_args])])
      :gen_init_call -> tuple_nested([leaf(:gen_server), leaf(:init_it), proper_list_nested([d, d, c, p, a, 1])])
      :callback_input -> tuple_nested([p, leaf(:init), proper_list_nested([a])])
      :callback_return -> callback
      :otp_return -> tuple_nested([leaf(:ok), callback])
      :init_ack -> tuple_nested([leaf(:ack), c, success])
      :child_start_result -> success
      :supervisor_return -> tuple_nested([leaf(:reply), success, marker_nested(:dynamic_supervisor_state)])
      :start_reply -> tuple_nested([r, success])
      :saved_entry -> tuple_nested([c, tuple_nested([tuple_nested([p, leaf(:start_link), leaf(:undefined)]), leaf(:temporary), integer_nested(5_000), leaf(:worker), proper_list_nested([p])])])
      :child_loop_call -> tuple_nested([leaf(:gen_server), leaf(:loop), proper_list_nested([marker_nested(:child_private_runtime), s, action_nested(context.mode), 1])])
    end
  end

  defp syntax_negatives(kind, context) do
    a = context.args
    s = context.state
    d = context.supervisor
    c = context.child
    r = context.start_reference
    normalized = original(:normalized_child, context)
    gen_args = original(:gen_init_args, context)
    callback = original(:callback_return, context)
    bad_arguments = Map.put(a, :extra, fn -> :opaque end)

    specific = case kind do
      :arguments -> [Map.delete(a, :owner), bad_arguments]
      :initial_state -> [Map.delete(s, :owner_monitor), Map.put(s, :extra, :opaque)]
      :caller -> [{UpstreamGroups, a}, {Probe, a, :extra}, {Probe, bad_arguments}]
      :generated_spec -> [
        %{id: UpstreamGroups, start: {Probe, :start_link, [a]}, restart: :temporary},
        %{id: Probe, start: {Probe, :start_link, [a]}, restart: :permanent},
        %{id: Probe, start: {Probe, :start_link, a}, restart: :temporary},
        %{id: Probe, start: {Probe, :start_link, [a]}, restart: :temporary, shutdown: 5_000}
      ]
      :normalized_child -> [
        {{Probe, :start_link, [a]}, :permanent, 5_000, :worker, [Probe]},
        {{Probe, :start_link, [a]}, :temporary, :infinity, :worker, [Probe]},
        {{Probe, :start_link, [a]}, :temporary, 5_000, :supervisor, [Probe]},
        {{Probe, :start_link, [a]}, :temporary, 5_000, :worker, [UpstreamGroups]},
        {{Probe, :start_link, [bad_arguments]}, :temporary, 5_000, :worker, [Probe]},
        {Probe, {Probe, :start_link, [a]}, :temporary, 5_000, :worker, [Probe]}
      ]
      :start_call -> [
        {:'$gen_call', {a.owner, [:alias | r]}, {:start_child, normalized}},
        {:'$gen_call', {other_pid(), r}, {:start_child, normalized}},
        {:'$gen_call', {a.owner, nil}, {:start_child, normalized}},
        {:'$gen_call', {a.owner, r}, {:other, normalized}},
        {:'$gen_cast', {a.owner, r}, {:start_child, normalized}}
      ]
      :apply_mfa -> [{UpstreamGroups, :start_link, [a]}, {Probe, :init, [a]}, {Probe, :start_link, [a, :extra]}, {Probe, :start_link, [bad_arguments]}]
      :gen_start -> [
        {:gen, :start, [:gen_server, :link, Probe, a, [debug: [:trace]]]},
        {:gen, :start, [:gen_server, :nolink, Probe, a, []]},
        {:gen, :start, [:gen_server, :link, :named, Probe, a, []]},
        {:gen, :other, [:gen_server, :link, Probe, a, []]}
      ]
      :gen_init_args -> [
        [:gen_server, d, other_pid(), Probe, a, []],
        [:gen_server, d, d, Probe, a, [debug: []]],
        [:gen_server, d, d, Probe, bad_arguments, []],
        [:gen_server, d, d, Probe, a]
      ]
      :proc_start -> [
        {:proc_lib, :start_link, [:gen, :init_it, gen_args, 5_000, []]},
        {:proc_lib, :start_link, [:gen, :init_it, gen_args, :infinity, [:link]]},
        {:proc_lib, :start, [:gen, :init_it, gen_args, :infinity, []]},
        {:proc_lib, :start_link, [:gen, :other, gen_args, :infinity, []]}
      ]
      :proc_spawn -> [
        {:erlang, :spawn_opt, [:proc_lib, :init_p, [Gaoxy.Proxy.ProbeSupervisor, :not_a_list, :gen, :init_it, gen_args], [:link, :monitor]]},
        {:erlang, :spawn_opt, [:proc_lib, :init_p, [UpstreamGroups, [], :gen, :init_it, gen_args], [:link, :monitor]]},
        {:erlang, :spawn_opt, [:proc_lib, :init_p, [Gaoxy.Proxy.ProbeSupervisor, [], :gen, :init_it, gen_args], [:monitor, :link]]},
        {:erlang, :spawn_opt, [:proc_lib, :init_p, [Gaoxy.Proxy.ProbeSupervisor, [], :gen, :init_it, gen_args], [:link]]}
      ]
      :proc_init -> [
        {:proc_lib, :init_p, [Gaoxy.Proxy.ProbeSupervisor, :not_a_list, :gen, :init_it, gen_args]},
        {:proc_lib, :init_p, [UpstreamGroups, [], :gen, :init_it, gen_args]},
        {:proc_lib, :init_p, [Gaoxy.Proxy.ProbeSupervisor, [], :gen, :other, gen_args]},
        {:proc_lib, :init_p, [Gaoxy.Proxy.ProbeSupervisor, [], :gen, :init_it, gen_args, :extra]}
      ]
      :gen_init_call -> [
        {:gen_server, :init_it, [d, other_pid(), c, Probe, a, []]},
        {:gen_server, :init_it, [d, d, make_ref(), Probe, a, []]},
        {:gen_server, :init_it, [d, d, c, Probe, a, [debug: []]]},
        {:gen_server, :init_it, [d, d, c, UpstreamGroups, a, []]}
      ]
      :callback_input -> [{Probe, :other, [a]}, {Probe, :init, a}, {Probe, :init, [a, :extra]}, {Probe, :init, [bad_arguments]}]
      :callback_return -> if context.mode == :recovery do
        [{:ok, s, {:continue, :open}}, {:ok, s, :infinity}, {:ok, Map.put(s, :extra, :opaque)}, {:stop, :normal}]
      else
        [{:ok, s}, {:ok, s, :infinity}, {:ok, s, {:continue, :other}}, {:ok, Map.put(s, :extra, :opaque), {:continue, :open}}]
      end
      :otp_return -> [callback, {:ok, callback, :extra}, {:other, callback}, {:ok, {:stop, :normal}}]
      :init_ack -> [{:ack, c, {:ok, other_pid()}}, {:ack, make_ref(), {:ok, c}}, {:ack, c, {:ok, c, :extra}}, {:ok, c}]
      :child_start_result -> [{:ok, c, :extra}, {:ok, make_ref()}, :ignore, {:error, fn -> :opaque end}]
      :supervisor_return -> [{:reply, {:ok, c}, []}, {:reply, {:ok, c, :extra}, %{}}, {:noreply, {:ok, c}, %{}}, {:reply, {:ok, make_ref()}, %{}}]
      :start_reply -> [{[:alias | r], {:ok, c}}, {r, {:ok, c, :extra}}, {nil, {:ok, c}}, {r, {:ok, make_ref()}}]
      :saved_entry -> [
        {c, {{Probe, :start_link, [a]}, :temporary, 5_000, :worker, [Probe]}},
        {c, {{Probe, :start_link, []}, :temporary, 5_000, :worker, [Probe]}},
        {c, {{Probe, :start_link, :undefined}, :permanent, 5_000, :worker, [Probe]}},
        {c, {{Probe, :start_link, :undefined}, :temporary, 5_000, :worker, [UpstreamGroups]}}
      ]
      :child_loop_call -> [
        {s, loop_action(context.mode)},
        {:gen_server, :loop, [context.server_data, s, loop_action(context.mode), [:trace]]},
        {:gen_server, :loop, [context.server_data, s, {:continue, :other}, []]},
        {:gen_server, :loop, [Map.from_struct(%URI{}), s, loop_action(context.mode), []]},
        {:gen_server, :other, [context.server_data, s, loop_action(context.mode), []]}
      ]
    end

    [nil, :invalid, fn -> :opaque end | specific]
  end

  defp invalid_normal_arguments(args) do
    [nil, [], %{}, Map.put(args, :extra, fn -> :opaque end)] ++
      Enum.map(Map.keys(args), &Map.delete(args, &1)) ++
      [
        %{args | owner: make_ref()},
        %{args | token: self()},
        %{args | deadline: :infinity},
        %{args | url: []},
        %{args | member: Map.put(args.member, :extra, fn -> :opaque end)},
        %{args | member: %{args.member | id: ""}},
        %{args | member: %{args.member | max_inflight: 0}},
        %{args | member: %{args.member | config: Map.from_struct(args.member.config)}},
        %{args | member: %{args.member | config: Map.put(args.member.config, :extra, fn -> :opaque end)}},
        %{args | health: Map.put(args.health, :extra, fn -> :opaque end)},
        %{args | health: %{args.health | timeout: 5_001}},
        %{args | health: %{args.health | path: "/health#fragment"}}
      ]
  end

  defp fixture(:h1), do: normal_arguments(:http1)
  defp fixture(:h2), do: normal_arguments(:http2)

  defp fixture(:recovery) do
    %{
      owner: self(),
      recovery: {:probe, make_ref()},
      completion: %HTTP.RequestCompletion{tracker: self(), latch: make_ref(), unsupported: nil},
      deadline: -1
    }
  end

  defp normal_arguments(protocol) do
    transport = if protocol == :http1, do: nil, else: transport()
    scheme = if protocol == :http2, do: "https", else: "http"
    config = %Gaoxy.Proxy.HTTP{
      uri: compact_uri(scheme <> "://upstream.test"),
      upstream_protocol: protocol,
      client: if(protocol == :http1, do: HTTPFetchClient, else: ManagedH2Client),
      transport: transport,
      limits: limits(),
      cacertfile: nil,
      connect_address: nil
    }
    args = %{
      owner: self(), token: make_ref(), member: %{id: "member", config: config, max_inflight: 1},
      deadline: 12_000, health: health(), url: :binary.copy(scheme <> "://upstream.test/health")
    }
    if protocol == :http1, do: args, else: Map.put(args, :group, group(transport))
  end

  defp health do
    %{path: "/health", interval: 5_000, timeout: 2_000, stale_after: 15_000,
      failure_threshold: 3, recovery_threshold: 2, jitter: 500}
  end

  defp limits do
    %{max_chunk_bytes: 65_536, opening_timeout: 5_000, idle_timeout: 60_000,
      write_timeout: 3_000, max_lifetime: 30_000}
  end

  defp transport do
    %{provider: Gaoxy.Proxy.UpstreamTransports, owner: self(), owner_epoch: make_ref(), resource: make_ref()}
  end

  defp group(transport) do
    %{provider: UpstreamGroups, owner: self(), owner_epoch: make_ref(), group: "group",
      generation: make_ref(), max_url_bytes: 8_192, transports: [transport], execution_profile: :managed_h2}
  end

  defp compact_uri(value) do
    Map.new(Map.to_list(URI.parse(value)), fn
      {key, value} when is_binary(value) -> {key, :binary.copy(value)}
      pair -> pair
    end)
  end

  defp slice(value, backing_bytes) do
    backing = :binary.copy(value <> :binary.copy("p", backing_bytes - byte_size(value)))
    binary_part(backing, 0, byte_size(value))
  end

  # Pure scalar fixture construction; this neither starts nor contacts a PID.
  # The init PID differs from this ExUnit test's self() for coherence negatives.
  defp other_pid, do: :erlang.list_to_pid(~c"<0.0.0>")
end
