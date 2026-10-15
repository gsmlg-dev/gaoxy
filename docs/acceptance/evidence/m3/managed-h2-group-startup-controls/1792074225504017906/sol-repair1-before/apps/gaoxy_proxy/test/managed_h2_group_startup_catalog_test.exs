support = Path.join(__DIR__, "support/managed_h2_group_startup_projection.exs")
if File.regular?(support), do: Code.require_file(support)

defmodule Gaoxy.Proxy.ManagedH2GroupStartupCatalogTest do
  use ExUnit.Case, async: true

  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Proxy.{HTTPFetchClient, ManagedH2Client, UpstreamGroups, UpstreamTransports}
  alias Gaoxy.Proxy.UpstreamGroups.Probe

  @projection Gaoxy.Proxy.ManagedH2GroupStartupProjection
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
  @containing [
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
  # DATA shapes, CALL_DESCRIPTOR syntax and ENTRY_DESCRIPTOR syntax are modeled
  # separately. The catalog never asserts 22 allocations or simultaneous copies.
  @data [
    :arguments,
    :initial_state,
    :caller,
    :generated_spec,
    :normalized_child,
    :start_call,
    :gen_init_args,
    :callback_return,
    :otp_return,
    :init_ack,
    :child_start_result,
    :supervisor_return,
    :start_reply
  ]
  @calls [
    :apply_mfa,
    :gen_start,
    :proc_start,
    :proc_spawn,
    :proc_init,
    :gen_init_call,
    :callback_input,
    :child_loop_call
  ]
  @entries [:saved_entry]
  @unmeasured [
    :proc_ancestors,
    :dynamic_supervisor_state,
    :child_private_runtime,
    :vm_call_stack
  ]
  @phase_keys [
    :disposition,
    :mode,
    :representation_count,
    :projected_etf_bytes,
    :payload_etf_bytes,
    :safe_catalog_bytes,
    :completion_shells,
    :unmeasured,
    :bound,
    :startup_maximum,
    :reservation_bytes
  ]

  test "contract fixes the partial catalog, its order and the unchanged reserve" do
    assert contract() == %{
             version: 1,
             unit: :external_term_payload_bytes,
             disposition: :partial_success_startup_catalog,
             modes: [:h1, :h2, :recovery],
             kinds: @kinds,
             phase_keys: @kinds,
             reservation_bytes: nil,
             startup_maximum: :unproved,
             recovery_release_order: :unproved,
             fixed_reservation_bytes: 9_444_956
           }

    assert length(@data) == 13
    assert length(@calls) == 8
    assert length(@entries) == 1
    assert Enum.sort(@data ++ @calls ++ @entries) == Enum.sort(@kinds)
  end

  test "H1 full catalog matches every independent row grammar and phase sum" do
    args = fixture(:http1)
    assert_catalog(:h1, args, roles())
  end

  test "http2 and h2c each admit coherent one and 32 transport catalogs" do
    for protocol <- [:http2, :h2c], count <- [1, 32] do
      args = fixture(protocol, count)
      assert_catalog(:h2, args, roles())
    end
  end

  test "both original recovery kinds match all 22 safe rows and shell occurrences" do
    for kind <- [:selection, :probe] do
      args = recovery(kind)
      {_, result} = assert_catalog(:recovery, args, roles())
      assert result.completion_shells == 17
      assert result.payload_etf_bytes == %{config: [], url: [], health_path: []}
    end
  end

  test "full flattened H2 resources and B T arithmetic use the same selected manifest" do
    for protocol <- [:http2, :h2c], count <- [1, 32] do
      args = fixture(protocol, count)
      group = args.group
      transports = group.transports
      flattened = [group | transports]
      selected = args.member.config.transport
      assert length(transports) == count
      assert length(Enum.uniq(transports)) == count
      assert selected === List.last(transports)
      assert args.owner === group.owner
      assert args.url === root(args) <> args.health.path
      assert args.member.config.upstream_protocol === protocol
      assert {:ok, ^flattened} = Resources.validate(flattened)

      b = f_group_without_transports_value(group)
      t = Enum.sum(Enum.map(transports, &f_transport/1))
      assert f_group(group) == b + 6 + t

      assert 1 + f_list([f_group(group) | Enum.map(transports, &f_transport/1)]) ==
               b + 13 + 2 * t

      # Secondary ETF sanity only: the expected arithmetic above has no whole
      # manifest measurement as an input or independent-max sidecar.
      assert byte_size(:erlang.term_to_binary(group)) == 1 + b + 6 + t
      assert byte_size(:erlang.term_to_binary(flattened)) == b + 13 + 2 * t
      assert b + 13 + 2 * t <= 65_536
      assert_catalog(:h2, args, roles())
    end
  end

  test "each phase rejects every omitted row and any additional row" do
    for mode <- [:h1, :h2, :recovery] do
      args = mode_fixture(mode)
      bundle = bundle(mode, args, roles())

      for key <- @kinds do
        assert_invalid_phase(mode, Map.delete(bundle, key))
      end

      assert_invalid_phase(mode, Map.put(bundle, :extra, fn -> :opaque end))
      assert_invalid_phase(mode, Map.put(bundle, :__struct__, URI))
    end
  end

  test "phase rejects nonmaps unknown names and every mismatched mode cohort" do
    bundle = bundle(:h1, fixture(:http1), roles())

    for bad <- [nil, [], @kinds, :catalog, %{}] do
      assert {:error, :invalid_startup_projection} == phase(:h1_startup, bad)
    end

    for name <- [:h1, :h2, :recovery, :unknown, nil, "h1_startup"] do
      assert {:error, :invalid_startup_projection} == phase(name, bundle)
    end

    for source <- [:h1, :h2, :recovery], target <- [:h1, :h2, :recovery], source != target do
      original = bundle(source, mode_fixture(source), roles())
      assert_invalid_phase(target, original)
    end
  end

  test "each args or state containing row must belong to the same original startup" do
    for mode <- [:h1, :h2, :recovery] do
      args = mode_fixture(mode)
      r = roles()
      first = bundle(mode, args, r)
      changed = %{args | deadline: args.deadline + 1}
      second = bundle(mode, changed, r)
      assert_original(mode, changed)

      for key <- @containing do
        # Both complete rows are separately source-valid. Only cross-row
        # coherence rejects mixing them in one catalog.
        assert {:ok, _} = project(mode, key, second[key])
        assert_invalid_phase(mode, Map.put(first, key, second[key]))
      end
    end
  end

  test "cross-row owner supervisor child reference and ancestor identities are required" do
    for mode <- [:h1, :h2, :recovery] do
      args = mode_fixture(mode)
      r = roles()
      first = bundle(mode, args, r)
      alien = other_pid()
      different_d = bundle(mode, args, %{r | supervisor: alien})
      different_c = bundle(mode, args, %{r | child: alien})
      different_r = bundle(mode, args, %{r | call_ref: make_ref()})
      different_an = bundle(mode, args, %{r | ancestors: [:another_ancestor]})

      for {key, row} <- [
            {:gen_init_args, different_d.gen_init_args},
            {:proc_start, different_d.proc_start},
            {:gen_init_call, different_d.gen_init_call},
            {:init_ack, different_c.init_ack},
            {:child_start_result, different_c.child_start_result},
            {:saved_entry, different_c.saved_entry},
            {:start_reply, different_r.start_reply},
            {:proc_init, different_an.proc_init}
          ] do
        assert {:ok, _} = project(mode, key, row)
        assert_invalid_phase(mode, Map.put(first, key, row))
      end

      # O is constrained by the embedded A as well as phase-wide coherence.
      {tag, {_owner, call_ref}, request} = first.start_call
      wrong_owner = {tag, {alien, call_ref}, request}
      assert_invalid_phase(mode, %{first | start_call: wrong_owner})
    end
  end

  test "same-sized changed payload and H2 selected transport cannot drift between rows" do
    for protocol <- [:http1, :http2, :h2c] do
      mode = if protocol == :http1, do: :h1, else: :h2
      args = fixture(protocol, if(protocol == :http1, do: 1, else: 32))
      r = roles()
      original = bundle(mode, args, r)
      path = "/status"

      changed = %{
        args
        | health: %{args.health | path: path},
          url: :binary.copy(root(args) <> path)
      }

      assert byte_size(path) == byte_size(args.health.path)
      assert_original(mode, changed)
      second = bundle(mode, changed, r)
      assert_invalid_phase(mode, %{original | callback_input: second.callback_input})

      if mode == :h2 do
        config = %{args.member.config | transport: hd(args.group.transports)}
        changed = %{args | member: %{args.member | config: config}}
        assert_original(mode, changed)
        second = bundle(mode, changed, r)
        assert_invalid_phase(mode, %{original | arguments: second.arguments})
      end
    end
  end

  test "initial state defaults and complete callbacks cannot be changed or expanded" do
    for mode <- [:h1, :h2, :recovery] do
      args = mode_fixture(mode)
      original = bundle(mode, args, roles())
      state = original.initial_state
      assert_invalid_phase(mode, %{original | initial_state: Map.put(state, :extra, [])})
      assert_invalid_phase(mode, %{original | initial_state: Map.delete(state, :owner_monitor)})
      assert_invalid_phase(mode, %{original | callback_return: {:ok, state, :extra}})
      assert_invalid_phase(mode, %{original | otp_return: {:ok, {:ok, state, :extra}}})

      if mode == :recovery do
        assert_invalid_phase(mode, %{original | callback_return: {:ok, state, {:continue, :open}}})

        assert_invalid_phase(mode, %{original | initial_state: Map.put(state, :timer, make_ref())})
      else
        for {key, value} <- [
              cleanup_deadline: args.deadline + 999,
              request: %{},
              original_request: %{},
              managed_transport: %{},
              transport_selection: {:token, make_ref()},
              transport_pins: [:pin],
              terminal: true,
              cancelled: true,
              headers: true,
              outcome: :success,
              timer: nil,
              owner_monitor: nil
            ] do
          assert_invalid_phase(mode, %{original | initial_state: Map.put(state, key, value)})
        end

        assert_invalid_phase(mode, %{original | callback_return: {:ok, state}})

        if mode == :h2 do
          for {key, value} <- [
                client: HTTPFetchClient,
                limits: %{state.limits | write_timeout: state.limits.write_timeout + 1},
                request_options: %{},
                submitted_url: args.url
              ] do
            assert_invalid_phase(mode, %{original | initial_state: Map.put(state, key, value)})
          end
        end
      end
    end
  end

  test "local infinity defaults ack replies and temporary saved args are exact" do
    for mode <- [:h1, :h2, :recovery] do
      args = mode_fixture(mode)
      r = roles()
      original = bundle(mode, args, r)
      {mfa, restart, _shutdown, type, modules} = original.normalized_child

      malformed = [
        {:generated_spec, Map.put(original.generated_spec, :shutdown, 5_000)},
        {:normalized_child, {mfa, restart, 5_001, type, modules}},
        {:start_call,
         {:"$gen_call", {args.owner, [:alias | r.call_ref]},
          {:start_child, original.normalized_child}}},
        {:gen_start, {:gen, :start, [:gen_server, :link, Probe, args, [timeout: 5_000]]}},
        {:proc_start,
         {:proc_lib, :start_link, [:gen, :init_it, original.gen_init_args, 5_000, []]}},
        {:init_ack, {:ack, r.child, {:ok, r.child, :extra}}},
        {:child_start_result, {:ok, r.child, :extra}},
        {:supervisor_return, {:reply, {:ok, r.child, :extra}, r.ds}},
        {:start_reply, {[:alias | r.call_ref], {:ok, r.child}}},
        {:saved_entry,
         {r.child, {{Probe, :start_link, [args]}, :temporary, 5_000, :worker, [Probe]}}}
      ]

      for {key, row} <- malformed, do: assert_invalid_phase(mode, Map.put(original, key, row))
    end
  end

  test "child loop uses source record10 callback identities default debug and real action" do
    for mode <- [:h1, :h2, :recovery] do
      args = mode_fixture(mode)
      r = roles()
      original = bundle(mode, args, r)
      {:gen_server, :loop, [server_data, state, action, []]} = original.child_loop_call
      assert tuple_size(server_data) == 10
      assert elem(server_data, 0) == :server_data
      assert action == if(mode == :recovery, do: :infinity, else: {:continue, :open})
      assert_invalid_phase(mode, %{original | child_loop_call: {state, action}})

      for changed <- [
            put_elem(server_data, 0, :wrong_record),
            Tuple.delete_at(server_data, 9),
            Tuple.append(server_data, :extra),
            put_elem(server_data, 1, other_pid()),
            put_elem(server_data, 2, :not_a_reference),
            put_elem(server_data, 3, other_pid()),
            put_elem(server_data, 4, GenServer),
            put_elem(server_data, 5, 5_000),
            put_elem(server_data, 6, Function.capture(Probe, :handle_cast, 3)),
            put_elem(server_data, 7, Function.capture(Probe, :handle_info, 2)),
            put_elem(server_data, 8, fn _, _ -> :opaque end),
            put_elem(server_data, 9, Function.capture(GenServer, :handle_continue, 2))
          ] do
        row = {:gen_server, :loop, [changed, state, action, []]}
        assert_invalid_phase(mode, %{original | child_loop_call: row})
      end

      for debug <- [nil, [:trace], [opaque: fn -> :opaque end]],
          do:
            assert_invalid_phase(mode, %{
              original
              | child_loop_call: {:gen_server, :loop, [server_data, state, action, debug]}
            })

      wrong_action = if mode == :recovery, do: {:continue, :open}, else: :infinity
      row = {:gen_server, :loop, [server_data, state, wrong_action, []]}
      assert_invalid_phase(mode, %{original | child_loop_call: row})
    end
  end

  test "recovery original completion identity is preserved and required across rows" do
    args = recovery(:probe)
    r = roles()
    original_completion = args.completion
    assert {:ok, returned} = apply(UpstreamGroups, :probe_recovery_arguments, [args])
    assert returned === args
    assert returned.completion === original_completion
    {first, result} = assert_catalog(:recovery, args, r)

    opaque = fn -> raise "opaque recovery interior must never execute" end

    replacement = %HTTP.RequestCompletion{
      tracker: opaque,
      latch: [make_ref() | {:opaque_tail, :binary.copy("x", 100_000)}],
      unsupported: %{opaque: opaque}
    }

    changed = %{args | completion: replacement}
    assert {:ok, returned} = apply(UpstreamGroups, :probe_recovery_arguments, [changed])
    assert returned === changed
    assert returned.completion === replacement
    {second, changed_result} = assert_catalog(:recovery, changed, r)
    assert result === changed_result

    for key <- @containing do
      assert {:ok, row1} = project(:recovery, key, first[key])
      assert {:ok, row2} = project(:recovery, key, second[key])
      assert row1 === row2
      assert_invalid_phase(:recovery, Map.put(first, key, second[key]))
    end
  end

  test "Ancestors outer is_list guard and DS map role exclude interiors without proper-list traversal" do
    opaque = fn -> raise "unmeasured interiors must never execute" end
    args = fixture(:http2)
    r = roles()
    {_, baseline} = assert_catalog(:h2, args, r)

    for ancestors <- [[], [opaque, :binary.copy("a", 100_000)], [opaque | :opaque_tail]],
        ds <- [%{children: %{opaque: opaque}}, struct(DynamicSupervisor)] do
      assert is_list(ancestors)
      {_, result} = assert_catalog(:h2, args, %{r | ancestors: ancestors, ds: ds})
      assert result === baseline
    end

    original = bundle(:h2, args, r)

    for bad <- [nil, :ancestors, %{}, opaque] do
      {:proc_lib, :init_p, [name, _ancestors, gen, init_it, gen_args]} = original.proc_init
      row = {:proc_lib, :init_p, [name, bad, gen, init_it, gen_args]}
      assert_invalid_phase(:h2, %{original | proc_init: row})
    end

    for bad <- [nil, [], :state, opaque] do
      assert_invalid_phase(:h2, %{original | supervisor_return: {:reply, {:ok, r.child}, bad}})
    end
  end

  test "H1 accepted larger URL timing and bignum deadline grow exact catalog formulas" do
    args = fixture(:http1)
    r = roles()
    {_, baseline} = assert_catalog(:h1, args, r)
    large = Integer.pow(256, 255)
    config = %{args.member.config | limits: %{args.member.config.limits | opening_timeout: large}}

    changed = %{
      args
      | member: %{args.member | config: config},
        deadline: large,
        url: :binary.copy("u", 70_000)
    }

    assert_original(:h1, changed)
    {_, increased} = assert_catalog(:h1, changed, r)
    assert increased.projected_etf_bytes > baseline.projected_etf_bytes
    assert increased.safe_catalog_bytes > baseline.safe_catalog_bytes
    assert increased.bound == :per_instance_only
    assert increased.startup_maximum == :unproved
    assert increased.reservation_bytes == nil
  end

  # The original bundle is assembled directly from source DATA shapes and
  # modeled call/entry descriptors. No startup API or callback is executed.
  defp bundle(mode, args, r) do
    state = initial_state(mode, args, r)
    mfa = {Probe, :start_link, [args]}
    normalized = {mfa, :temporary, 5_000, :worker, [Probe]}
    gen_args = [:gen_server, r.supervisor, r.supervisor, Probe, args, []]
    spawn_args = [Gaoxy.Proxy.ProbeSupervisor, r.ancestors, :gen, :init_it, gen_args]
    callback = if mode == :recovery, do: {:ok, state}, else: {:ok, state, {:continue, :open}}
    action = if mode == :recovery, do: :infinity, else: {:continue, :open}

    server_data = {
      :server_data,
      r.supervisor,
      r.private_tag,
      r.child,
      Probe,
      :infinity,
      Function.capture(Probe, :handle_call, 3),
      Function.capture(Probe, :handle_cast, 2),
      Function.capture(Probe, :handle_info, 2),
      Function.capture(Probe, :handle_continue, 2)
    }

    %{
      arguments: args,
      initial_state: state,
      caller: {Probe, args},
      generated_spec: %{id: Probe, start: mfa, restart: :temporary},
      normalized_child: normalized,
      start_call: {:"$gen_call", {args.owner, r.call_ref}, {:start_child, normalized}},
      apply_mfa: mfa,
      gen_start: {:gen, :start, [:gen_server, :link, Probe, args, []]},
      gen_init_args: gen_args,
      proc_start: {:proc_lib, :start_link, [:gen, :init_it, gen_args, :infinity, []]},
      proc_spawn: {:erlang, :spawn_opt, [:proc_lib, :init_p, spawn_args, [:link, :monitor]]},
      proc_init: {:proc_lib, :init_p, spawn_args},
      gen_init_call:
        {:gen_server, :init_it, [r.supervisor, r.supervisor, r.child, Probe, args, []]},
      callback_input: {Probe, :init, [args]},
      callback_return: callback,
      otp_return: {:ok, callback},
      init_ack: {:ack, r.child, {:ok, r.child}},
      child_start_result: {:ok, r.child},
      supervisor_return: {:reply, {:ok, r.child}, r.ds},
      start_reply: {r.call_ref, {:ok, r.child}},
      saved_entry:
        {r.child, {{Probe, :start_link, :undefined}, :temporary, 5_000, :worker, [Probe]}},
      child_loop_call: {:gen_server, :loop, [server_data, state, action, []]}
    }
  end

  # This separately assembled oracle never consumes a projector result. Only
  # the specified payload/opaque/source-private positions differ from originals.
  defp expected_rows(mode, args, r) do
    a = projected_args(mode, args)
    s = projected_state(mode, args, r)
    callback = if mode == :recovery, do: {:ok, s}, else: {:ok, s, {:continue, :open}}
    action = if mode == :recovery, do: :infinity, else: {:continue, :open}
    start = {Probe, :start_link, [a]}
    child = {start, :temporary, 5_000, :worker, [Probe]}
    init_args = [:gen_server, r.supervisor, r.supervisor, Probe, a, []]

    private_args = [
      Gaoxy.Proxy.ProbeSupervisor,
      {:UNMEASURED, :proc_ancestors},
      :gen,
      :init_it,
      init_args
    ]

    %{
      arguments: a,
      initial_state: s,
      caller: {Probe, a},
      generated_spec: %{id: Probe, start: {Probe, :start_link, [a]}, restart: :temporary},
      normalized_child: {{Probe, :start_link, [a]}, :temporary, 5_000, :worker, [Probe]},
      start_call: {:"$gen_call", {args.owner, r.call_ref}, {:start_child, child}},
      apply_mfa: {Probe, :start_link, [a]},
      gen_start: {:gen, :start, [:gen_server, :link, Probe, a, []]},
      gen_init_args: [:gen_server, r.supervisor, r.supervisor, Probe, a, []],
      proc_start: {:proc_lib, :start_link, [:gen, :init_it, init_args, :infinity, []]},
      proc_spawn: {:erlang, :spawn_opt, [:proc_lib, :init_p, private_args, [:link, :monitor]]},
      proc_init: {:proc_lib, :init_p, private_args},
      gen_init_call: {:gen_server, :init_it, [r.supervisor, r.supervisor, r.child, Probe, a, []]},
      callback_input: {Probe, :init, [a]},
      callback_return: callback,
      otp_return: {:ok, callback},
      init_ack: {:ack, r.child, {:ok, r.child}},
      child_start_result: {:ok, r.child},
      supervisor_return: {:reply, {:ok, r.child}, {:UNMEASURED, :dynamic_supervisor_state}},
      start_reply: {r.call_ref, {:ok, r.child}},
      saved_entry:
        {r.child, {{Probe, :start_link, :undefined}, :temporary, 5_000, :worker, [Probe]}},
      child_loop_call:
        {:gen_server, :loop, [{:UNMEASURED, :child_private_runtime}, s, action, []]}
    }
  end

  defp assert_catalog(mode, args, r) do
    assert_original(mode, args)
    originals = bundle(mode, args, r)
    expected = expected_rows(mode, args, r)
    formulas = row_formulas(mode, args, r)
    assert Enum.sort(Map.keys(originals)) == Enum.sort(@kinds)
    assert Enum.sort(Map.keys(expected)) == Enum.sort(@kinds)
    assert Enum.sort(Map.keys(formulas)) == Enum.sort(@kinds)
    assert map_size(originals.initial_state) == %{h1: 18, h2: 23, recovery: 5}[mode]

    # Public child_spec oracles are pure and do not start the child.
    assert apply(Probe, :child_spec, [args]) === originals.generated_spec
    assert Supervisor.child_spec({Probe, args}, []) === originals.generated_spec

    for kind <- @kinds do
      expected_row = %{
        projection: expected[kind],
        projected_etf_bytes: 1 + formulas[kind],
        payload_etf_bytes: row_payloads(mode, kind, args),
        completion_shells: if(mode == :recovery and kind in @containing, do: 1, else: 0),
        unmeasured: row_unmeasured(kind),
        bound: :per_instance_only
      }

      assert {:ok, actual} = project(mode, kind, originals[kind])
      assert actual === expected_row
      assert map_size(actual) == 6
      # Secondary grammar check only. All expected byte counts were computed
      # first by explicit width algebra, never external_size(expected[kind]).
      assert byte_size(:erlang.term_to_binary(expected[kind])) == 1 + formulas[kind]
    end

    projected = Enum.sum(Enum.map(@kinds, &(1 + formulas[&1])))
    payloads = phase_payloads(mode, args)

    payload_sum =
      Enum.sum(payloads.config) + Enum.sum(payloads.url) + Enum.sum(payloads.health_path)

    expected_phase = %{
      disposition: :partial_success_startup_catalog,
      mode: mode,
      representation_count: 22,
      projected_etf_bytes: projected,
      payload_etf_bytes: payloads,
      safe_catalog_bytes: projected + payload_sum,
      completion_shells: if(mode == :recovery, do: 17, else: 0),
      unmeasured: @unmeasured,
      bound: :per_instance_only,
      startup_maximum: :unproved,
      reservation_bytes: nil
    }

    assert {:ok, result} = phase(phase_name(mode), originals)
    assert Enum.sort(Map.keys(result)) == Enum.sort(@phase_keys)
    assert map_size(result) == 11
    assert result === expected_phase
    {originals, result}
  end

  # Explicit ETF grammar over WIDTHS, not an arbitrary-term encoder/walker.
  # E excludes the single top-level ETF version byte. Scalar measurements are
  # restricted to actual atom/PID/reference leaves, with no universal cap claim.
  defp leaf(value) when is_atom(value) or is_pid(value) or is_reference(value),
    do: :erlang.external_size(value) - 1

  defp f_tuple(widths), do: 2 + Enum.sum(widths)
  defp f_list([]), do: 1
  defp f_list(widths), do: 6 + Enum.sum(widths)
  defp f_map(pairs), do: 5 + Enum.sum(Enum.map(pairs, fn {key, value} -> key + value end))
  defp f_binary(value) when is_binary(value), do: 5 + byte_size(value)
  defp f_integer(value) when value in 0..255, do: 2
  defp f_integer(value) when value >= -2_147_483_648 and value <= 2_147_483_647, do: 5

  defp f_integer(value) when is_integer(value) do
    digits = integer_digits(abs(value))
    if digits <= 255, do: 3 + digits, else: 6 + digits
  end

  defp integer_digits(value) when value < 256, do: 1
  defp integer_digits(value), do: 1 + integer_digits(div(value, 256))
  defp marker(name), do: f_tuple([leaf(:payload), leaf(name)])
  defp unmeasured(name), do: f_tuple([leaf(:UNMEASURED), leaf(name)])

  defp f_limits(limits) do
    f_map([
      {leaf(:max_chunk_bytes), f_integer(limits.max_chunk_bytes)},
      {leaf(:opening_timeout), f_integer(limits.opening_timeout)},
      {leaf(:idle_timeout), f_integer(limits.idle_timeout)},
      {leaf(:write_timeout), f_integer(limits.write_timeout)},
      {leaf(:max_lifetime), f_integer(limits.max_lifetime)}
    ])
  end

  defp f_uri(uri) do
    f_map([
      {leaf(:__struct__), leaf(URI)},
      {leaf(:scheme), f_binary(uri.scheme)},
      {leaf(:authority), f_binary(uri.authority)},
      {leaf(:userinfo), leaf(nil)},
      {leaf(:host), f_binary(uri.host)},
      {leaf(:port), f_integer(uri.port)},
      {leaf(:path), leaf(nil)},
      {leaf(:query), leaf(nil)},
      {leaf(:fragment), leaf(nil)}
    ])
  end

  defp f_config(config) do
    transport = if config.transport == nil, do: leaf(nil), else: f_transport(config.transport)

    f_map([
      {leaf(:__struct__), leaf(Gaoxy.Proxy.HTTP)},
      {leaf(:uri), f_uri(config.uri)},
      {leaf(:cacertfile), leaf(nil)},
      {leaf(:connect_address), leaf(nil)},
      {leaf(:transport), transport},
      {leaf(:limits), f_limits(config.limits)},
      {leaf(:upstream_protocol), leaf(config.upstream_protocol)},
      {leaf(:client), leaf(config.client)}
    ])
  end

  defp f_transport(transport) do
    f_map([
      {leaf(:provider), leaf(UpstreamTransports)},
      {leaf(:owner), leaf(transport.owner)},
      {leaf(:owner_epoch), leaf(transport.owner_epoch)},
      {leaf(:resource), leaf(transport.resource)}
    ])
  end

  defp f_group_without_transports_value(group) do
    f_map([
      {leaf(:provider), leaf(UpstreamGroups)},
      {leaf(:owner), leaf(group.owner)},
      {leaf(:owner_epoch), leaf(group.owner_epoch)},
      {leaf(:group), f_binary(group.group)},
      {leaf(:generation), leaf(group.generation)},
      {leaf(:max_url_bytes), f_integer(group.max_url_bytes)},
      {leaf(:execution_profile), leaf(:managed_h2)}
    ]) + leaf(:transports)
  end

  defp f_group(group),
    do:
      f_group_without_transports_value(group) + f_list(Enum.map(group.transports, &f_transport/1))

  defp f_health(health) do
    f_map([
      {leaf(:path), marker(:health_path)},
      {leaf(:interval), f_integer(health.interval)},
      {leaf(:timeout), f_integer(health.timeout)},
      {leaf(:stale_after), f_integer(health.stale_after)},
      {leaf(:failure_threshold), f_integer(health.failure_threshold)},
      {leaf(:recovery_threshold), f_integer(health.recovery_threshold)},
      {leaf(:jitter), f_integer(health.jitter)}
    ])
  end

  defp f_args(:recovery, args) do
    {kind, token} = args.recovery

    f_map([
      {leaf(:owner), leaf(args.owner)},
      {leaf(:recovery), f_tuple([leaf(kind), leaf(token)])},
      {leaf(:completion), f_tuple([leaf(:opaque), leaf(HTTP.RequestCompletion)])},
      {leaf(:deadline), f_integer(args.deadline)}
    ])
  end

  defp f_args(mode, args) do
    selected =
      f_map([
        {leaf(:id), f_binary(args.member.id)},
        {leaf(:config), marker(:config)},
        {leaf(:max_inflight), f_integer(args.member.max_inflight)}
      ])

    normal =
      f_map([
        {leaf(:owner), leaf(args.owner)},
        {leaf(:token), leaf(args.token)},
        {leaf(:member), selected},
        {leaf(:deadline), f_integer(args.deadline)},
        {leaf(:health), f_health(args.health)},
        {leaf(:url), marker(:url)}
      ])

    if mode == :h2, do: normal + leaf(:group) + f_group(args.group), else: normal
  end

  defp f_state(:recovery, args, r),
    do: f_args(:recovery, args) + leaf(:owner_monitor) + leaf(r.owner_monitor)

  defp f_state(mode, args, r) do
    additions = [
      {leaf(:cleanup_deadline), f_integer(args.deadline + 1_000)},
      {leaf(:owner_monitor), leaf(r.owner_monitor)},
      {leaf(:timer), leaf(r.timer)},
      {leaf(:request), leaf(nil)},
      {leaf(:original_request), leaf(nil)},
      {leaf(:managed_transport), leaf(nil)},
      {leaf(:transport_selection), leaf(nil)},
      {leaf(:transport_pins), f_list([])},
      {leaf(:terminal), leaf(false)},
      {leaf(:cancelled), leaf(false)},
      {leaf(:headers), leaf(false)},
      {leaf(:outcome), leaf(:failure)}
    ]

    extra =
      if mode == :h2 do
        [
          {leaf(:client), leaf(ManagedH2Client)},
          {leaf(:limits), f_limits(args.member.config.limits)},
          {leaf(:request_options), leaf(nil)},
          {leaf(:submitted_url), leaf(nil)}
        ]
      else
        []
      end

    f_args(mode, args) +
      Enum.sum(Enum.map(additions ++ extra, fn {key, value} -> key + value end))
  end

  defp row_formulas(mode, args, r) do
    a = f_args(mode, args)
    s = f_state(mode, args, r)
    p = leaf(Probe)
    d = leaf(r.supervisor)
    c = leaf(r.child)
    ref = leaf(r.call_ref)
    empty = f_list([])

    action =
      if mode == :recovery, do: leaf(:infinity), else: f_tuple([leaf(:continue), leaf(:open)])

    callback =
      if mode == :recovery, do: f_tuple([leaf(:ok), s]), else: f_tuple([leaf(:ok), s, action])

    mfa = f_tuple([p, leaf(:start_link), f_list([a])])
    normalized = f_tuple([mfa, leaf(:temporary), f_integer(5_000), leaf(:worker), f_list([p])])
    gen_args = f_list([leaf(:gen_server), d, d, p, a, empty])

    init_args =
      f_list([
        leaf(Gaoxy.Proxy.ProbeSupervisor),
        unmeasured(:proc_ancestors),
        leaf(:gen),
        leaf(:init_it),
        gen_args
      ])

    success = f_tuple([leaf(:ok), c])

    %{
      arguments: a,
      initial_state: s,
      caller: f_tuple([p, a]),
      generated_spec:
        f_map([{leaf(:id), p}, {leaf(:start), mfa}, {leaf(:restart), leaf(:temporary)}]),
      normalized_child: normalized,
      start_call:
        f_tuple([
          leaf(:"$gen_call"),
          f_tuple([leaf(args.owner), ref]),
          f_tuple([leaf(:start_child), normalized])
        ]),
      apply_mfa: mfa,
      gen_start:
        f_tuple([leaf(:gen), leaf(:start), f_list([leaf(:gen_server), leaf(:link), p, a, empty])]),
      gen_init_args: gen_args,
      proc_start:
        f_tuple([
          leaf(:proc_lib),
          leaf(:start_link),
          f_list([leaf(:gen), leaf(:init_it), gen_args, leaf(:infinity), empty])
        ]),
      proc_spawn:
        f_tuple([
          leaf(:erlang),
          leaf(:spawn_opt),
          f_list([
            leaf(:proc_lib),
            leaf(:init_p),
            init_args,
            f_list([leaf(:link), leaf(:monitor)])
          ])
        ]),
      proc_init: f_tuple([leaf(:proc_lib), leaf(:init_p), init_args]),
      gen_init_call: f_tuple([leaf(:gen_server), leaf(:init_it), f_list([d, d, c, p, a, empty])]),
      callback_input: f_tuple([p, leaf(:init), f_list([a])]),
      callback_return: callback,
      otp_return: f_tuple([leaf(:ok), callback]),
      init_ack: f_tuple([leaf(:ack), c, success]),
      child_start_result: success,
      supervisor_return: f_tuple([leaf(:reply), success, unmeasured(:dynamic_supervisor_state)]),
      start_reply: f_tuple([ref, success]),
      saved_entry:
        f_tuple([
          c,
          f_tuple([
            f_tuple([p, leaf(:start_link), leaf(:undefined)]),
            leaf(:temporary),
            f_integer(5_000),
            leaf(:worker),
            f_list([p])
          ])
        ]),
      child_loop_call:
        f_tuple([
          leaf(:gen_server),
          leaf(:loop),
          f_list([unmeasured(:child_private_runtime), s, action, empty])
        ])
    }
  end

  defp row_payloads(:recovery, _, _), do: %{config: [], url: [], health_path: []}

  defp row_payloads(_, kind, args) when kind in @containing,
    do: %{
      config: [1 + f_config(args.member.config)],
      url: [1 + f_binary(args.url)],
      health_path: [1 + f_binary(args.health.path)]
    }

  defp row_payloads(_, _, _), do: %{config: [], url: [], health_path: []}
  defp phase_payloads(:recovery, _), do: %{config: [], url: [], health_path: []}

  defp phase_payloads(_, args),
    do: %{
      config: List.duplicate(1 + f_config(args.member.config), 17),
      url: List.duplicate(1 + f_binary(args.url), 17),
      health_path: List.duplicate(1 + f_binary(args.health.path), 17)
    }

  defp row_unmeasured(:proc_spawn), do: [:proc_ancestors]
  defp row_unmeasured(:proc_init), do: [:proc_ancestors]
  defp row_unmeasured(:supervisor_return), do: [:dynamic_supervisor_state]
  defp row_unmeasured(:child_loop_call), do: [:child_private_runtime]
  defp row_unmeasured(:apply_mfa), do: [:vm_call_stack]
  defp row_unmeasured(_), do: []

  defp projected_args(:recovery, args),
    do: %{args | completion: {:opaque, HTTP.RequestCompletion}}

  defp projected_args(mode, args) when mode in [:h1, :h2],
    do: %{
      args
      | member: %{args.member | config: {:payload, :config}},
        health: %{args.health | path: {:payload, :health_path}},
        url: {:payload, :url}
    }

  defp projected_state(mode, args, r) do
    projected = projected_args(mode, args)

    if mode == :recovery do
      Map.put(projected, :owner_monitor, r.owner_monitor)
    else
      additions = %{
        cleanup_deadline: args.deadline + 1_000,
        owner_monitor: r.owner_monitor,
        timer: r.timer,
        request: nil,
        original_request: nil,
        managed_transport: nil,
        transport_selection: nil,
        transport_pins: [],
        terminal: false,
        cancelled: false,
        headers: false,
        outcome: :failure
      }

      state = Map.merge(projected, additions)

      if mode == :h2 do
        Map.merge(state, %{
          client: ManagedH2Client,
          limits: args.member.config.limits,
          request_options: nil,
          submitted_url: nil
        })
      else
        state
      end
    end
  end

  defp initial_state(:recovery, args, r), do: Map.put(args, :owner_monitor, r.owner_monitor)

  defp initial_state(mode, args, r) do
    state =
      Map.merge(args, %{
        cleanup_deadline: args.deadline + 1_000,
        owner_monitor: r.owner_monitor,
        timer: r.timer,
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
      Map.merge(state, %{
        client: ManagedH2Client,
        limits: args.member.config.limits,
        request_options: nil,
        submitted_url: nil
      })
    else
      state
    end
  end

  defp fixture(protocol, count \\ 1) do
    transports = if protocol == :http1, do: [], else: Enum.map(1..count, fn _ -> transport() end)
    selected = List.last(transports)
    scheme = if protocol == :http2, do: "https", else: "http"

    config = %Gaoxy.Proxy.HTTP{
      uri: compact_uri(scheme <> "://upstream.test"),
      upstream_protocol: protocol,
      client: if(protocol == :http1, do: HTTPFetchClient, else: ManagedH2Client),
      transport: selected,
      limits: limits(),
      cacertfile: nil,
      connect_address: nil
    }

    args = %{
      owner: self(),
      token: make_ref(),
      member: %{id: "member", config: config, max_inflight: 1},
      deadline: 12_000,
      health: health(),
      url: :binary.copy(scheme <> "://upstream.test/health")
    }

    if protocol == :http1 do
      args
    else
      Map.put(args, :group, %{
        provider: UpstreamGroups,
        owner: self(),
        owner_epoch: make_ref(),
        group: "group",
        generation: make_ref(),
        max_url_bytes: 8_192,
        transports: transports,
        execution_profile: :managed_h2
      })
    end
  end

  defp recovery(kind),
    do: %{
      owner: self(),
      recovery: {kind, make_ref()},
      completion: %HTTP.RequestCompletion{tracker: self(), latch: make_ref(), unsupported: nil},
      deadline: -1
    }

  defp roles,
    do: %{
      supervisor: :erlang.list_to_pid(~c"<0.32766.0>"),
      child: :erlang.list_to_pid(~c"<0.32765.0>"),
      call_ref: make_ref(),
      owner_monitor: make_ref(),
      timer: make_ref(),
      private_tag: make_ref(),
      ancestors: [Gaoxy.Proxy.ProbeSupervisor],
      ds: struct(DynamicSupervisor)
    }

  defp other_pid, do: :erlang.list_to_pid(~c"<0.32764.0>")
  defp root(args), do: args.member.config.uri.scheme <> "://" <> args.member.config.uri.authority

  defp compact_uri(value),
    do:
      Map.new(Map.to_list(URI.parse(value)), fn
        {key, value} when is_binary(value) -> {key, :binary.copy(value)}
        pair -> pair
      end)

  defp health,
    do: %{
      path: "/health",
      interval: 5_000,
      timeout: 2_000,
      stale_after: 15_000,
      failure_threshold: 3,
      recovery_threshold: 2,
      jitter: 500
    }

  defp limits,
    do: %{
      max_chunk_bytes: 65_536,
      opening_timeout: 5_000,
      idle_timeout: 60_000,
      write_timeout: 3_000,
      max_lifetime: 30_000
    }

  defp transport,
    do: %{
      provider: UpstreamTransports,
      owner: self(),
      owner_epoch: make_ref(),
      resource: make_ref()
    }

  defp mode_fixture(:h1), do: fixture(:http1)
  defp mode_fixture(:h2), do: fixture(:http2)
  defp mode_fixture(:recovery), do: recovery(:probe)
  defp phase_name(:h1), do: :h1_startup
  defp phase_name(:h2), do: :h2_startup
  defp phase_name(:recovery), do: :recovery_startup

  defp assert_original(:recovery, args) do
    assert {:ok, returned} = apply(UpstreamGroups, :probe_recovery_arguments, [args])
    assert returned === args
  end

  defp assert_original(mode, args) when mode in [:h1, :h2] do
    assert {:ok, returned} = apply(UpstreamGroups, :probe_start_arguments, [args])
    assert returned === args
  end

  defp assert_invalid_phase(mode, bundle),
    do: assert({:error, :invalid_startup_projection} == phase(phase_name(mode), bundle))

  defp contract, do: apply(@projection, :contract, [])
  defp project(mode, kind, original), do: apply(@projection, :project, [{mode, kind}, original])
  defp phase(name, bundle), do: apply(@projection, :phase, [name, bundle])
end
