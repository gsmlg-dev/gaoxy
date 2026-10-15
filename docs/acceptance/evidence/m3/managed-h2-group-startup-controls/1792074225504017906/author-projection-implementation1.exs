defmodule Gaoxy.Proxy.ManagedH2GroupStartupProjection do
  @moduledoc false

  alias Gaoxy.Proxy.{ManagedH2Client, UpstreamGroups}
  alias Gaoxy.Proxy.UpstreamGroups.Probe

  @invalid {:error, :invalid_startup_projection}
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
  @normal_keys [:owner, :token, :member, :deadline, :health, :url]
  @recovery_keys [:owner, :recovery, :completion, :deadline]

  def contract do
    %{
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
  end

  def project({mode, kind}, original) when mode in [:h1, :h2, :recovery] do
    case row(mode, kind, original) do
      {:ok, result, _bindings} -> {:ok, result}
      @invalid -> @invalid
    end
  end

  def project(_, _), do: @invalid

  def phase(name, bundle)
      when name in [:h1_startup, :h2_startup, :recovery_startup] and is_map(bundle) and
             map_size(bundle) == 22 do
    mode =
      case name do
        :h1_startup -> :h1
        :h2_startup -> :h2
        :recovery_startup -> :recovery
      end

    initial = %{bytes: 0, payloads: empty_payloads(), shells: 0, bindings: %{}}

    Enum.reduce_while(@kinds, {:ok, initial}, fn kind, {:ok, acc} ->
      with {:ok, original} <- Map.fetch(bundle, kind),
           {:ok, result, bindings} <- row(mode, kind, original),
           true <- coherent?(acc.bindings, bindings) do
        {:cont,
         {:ok,
          %{
            bytes: acc.bytes + result.projected_etf_bytes,
            payloads: %{
              config: acc.payloads.config ++ result.payload_etf_bytes.config,
              url: acc.payloads.url ++ result.payload_etf_bytes.url,
              health_path: acc.payloads.health_path ++ result.payload_etf_bytes.health_path
            },
            shells: acc.shells + result.completion_shells,
            bindings: Map.merge(acc.bindings, bindings)
          }}}
      else
        _ -> {:halt, @invalid}
      end
    end)
    |> phase_result(mode)
  end

  def phase(_, _), do: @invalid

  defp phase_result({:ok, acc}, mode) do
    payload_bytes = Enum.sum(acc.payloads.config ++ acc.payloads.url ++ acc.payloads.health_path)

    {:ok,
     %{
       disposition: :partial_success_startup_catalog,
       mode: mode,
       representation_count: 22,
       projected_etf_bytes: acc.bytes,
       payload_etf_bytes: acc.payloads,
       safe_catalog_bytes: acc.bytes + payload_bytes,
       completion_shells: acc.shells,
       unmeasured: [
         :proc_ancestors,
         :dynamic_supervisor_state,
         :child_private_runtime,
         :vm_call_stack
       ],
       bound: :per_instance_only,
       startup_maximum: :unproved,
       reservation_bytes: nil
     }}
  end

  defp phase_result(@invalid, _), do: @invalid

  # These are the fixed original source roles of this closed catalog. Comparing
  # originals retains payload and opaque capability identity across the rows.
  defp coherent?(left, right) do
    Enum.all?([:arguments, :state, :supervisor, :child, :reference, :ancestors], fn role ->
      case {Map.fetch(left, role), Map.fetch(right, role)} do
        {{:ok, a}, {:ok, b}} -> a === b
        _ -> true
      end
    end)
  end

  defp row(mode, :arguments, args),
    do: arguments_row(mode, args, fn safe -> safe end)

  defp row(mode, :initial_state, state),
    do: state_row(mode, state, fn safe -> safe end)

  defp row(mode, :caller, {Probe, args}),
    do: arguments_row(mode, args, fn safe -> {Probe, safe} end)

  defp row(mode, :generated_spec, %{id: Probe, start: {Probe, :start_link, [args]}, restart: :temporary} = spec)
       when map_size(spec) == 3,
       do: arguments_row(mode, args, fn safe -> %{id: Probe, start: {Probe, :start_link, [safe]}, restart: :temporary} end)

  defp row(mode, :normalized_child, {{Probe, :start_link, [args]}, :temporary, 5_000, :worker, [Probe]}),
    do: arguments_row(mode, args, &normalized_child/1)

  defp row(mode, :start_call, {:"$gen_call", {owner, reference}, {:start_child, {{Probe, :start_link, [args]}, :temporary, 5_000, :worker, [Probe]}}})
       when is_pid(owner) and is_reference(reference) do
    with {:ok, safe, payloads, shells, bindings} <- arguments(mode, args),
         true <- owner === args.owner do
      finish({:"$gen_call", {owner, reference}, {:start_child, normalized_child(safe)}}, payloads, shells, [], Map.put(bindings, :reference, reference))
    else
      _ -> @invalid
    end
  end

  defp row(mode, :apply_mfa, {Probe, :start_link, [args]}),
    do: arguments_row(mode, args, fn safe -> {Probe, :start_link, [safe]} end, %{}, [:vm_call_stack])

  defp row(mode, :gen_start, {:gen, :start, [:gen_server, :link, Probe, args, []]}),
    do: arguments_row(mode, args, fn safe -> {:gen, :start, [:gen_server, :link, Probe, safe, []]} end)

  defp row(mode, :gen_init_args, [:gen_server, parent, supervisor, Probe, args, []])
       when is_pid(parent) and parent === supervisor,
       do: arguments_row(mode, args, fn safe -> gen_args(supervisor, safe) end, %{supervisor: supervisor})

  defp row(mode, :proc_start, {:proc_lib, :start_link, [:gen, :init_it, [:gen_server, parent, supervisor, Probe, args, []], :infinity, []]})
       when is_pid(parent) and parent === supervisor,
       do: arguments_row(mode, args, fn safe -> {:proc_lib, :start_link, [:gen, :init_it, gen_args(supervisor, safe), :infinity, []]} end, %{supervisor: supervisor})

  defp row(mode, :proc_spawn, {:erlang, :spawn_opt, [:proc_lib, :init_p, [Gaoxy.Proxy.ProbeSupervisor, ancestors, :gen, :init_it, [:gen_server, parent, supervisor, Probe, args, []]], [:link, :monitor]]})
       when is_list(ancestors) and is_pid(parent) and parent === supervisor do
    arguments_row(mode, args, fn safe ->
      {:erlang, :spawn_opt, [:proc_lib, :init_p, [Gaoxy.Proxy.ProbeSupervisor, {:UNMEASURED, :proc_ancestors}, :gen, :init_it, gen_args(supervisor, safe)], [:link, :monitor]]}
    end, %{supervisor: supervisor, ancestors: ancestors}, [:proc_ancestors])
  end

  defp row(mode, :proc_init, {:proc_lib, :init_p, [Gaoxy.Proxy.ProbeSupervisor, ancestors, :gen, :init_it, [:gen_server, parent, supervisor, Probe, args, []]]})
       when is_list(ancestors) and is_pid(parent) and parent === supervisor do
    arguments_row(mode, args, fn safe ->
      {:proc_lib, :init_p, [Gaoxy.Proxy.ProbeSupervisor, {:UNMEASURED, :proc_ancestors}, :gen, :init_it, gen_args(supervisor, safe)]}
    end, %{supervisor: supervisor, ancestors: ancestors}, [:proc_ancestors])
  end

  defp row(mode, :gen_init_call, {:gen_server, :init_it, [parent, supervisor, child, Probe, args, []]})
       when is_pid(parent) and parent === supervisor and is_pid(child),
       do: arguments_row(mode, args, fn safe -> {:gen_server, :init_it, [supervisor, supervisor, child, Probe, safe, []]} end, %{supervisor: supervisor, child: child})

  defp row(mode, :callback_input, {Probe, :init, [args]}),
    do: arguments_row(mode, args, fn safe -> {Probe, :init, [safe]} end)

  defp row(:recovery, :callback_return, {:ok, state}),
    do: state_row(:recovery, state, fn safe -> {:ok, safe} end)

  defp row(mode, :callback_return, {:ok, state, {:continue, :open}}) when mode in [:h1, :h2],
    do: state_row(mode, state, fn safe -> {:ok, safe, {:continue, :open}} end)

  defp row(:recovery, :otp_return, {:ok, {:ok, state}}),
    do: state_row(:recovery, state, fn safe -> {:ok, {:ok, safe}} end)

  defp row(mode, :otp_return, {:ok, {:ok, state, {:continue, :open}}}) when mode in [:h1, :h2],
    do: state_row(mode, state, fn safe -> {:ok, {:ok, safe, {:continue, :open}}} end)

  defp row(_, :init_ack, {:ack, child, {:ok, acknowledged}} = original)
       when is_pid(child) and child === acknowledged,
       do: finish(original, empty_payloads(), 0, [], %{child: child})

  defp row(_, :child_start_result, {:ok, child} = original) when is_pid(child),
    do: finish(original, empty_payloads(), 0, [], %{child: child})

  defp row(_, :supervisor_return, {:reply, {:ok, child}, supervisor_state})
       when is_pid(child) and is_map(supervisor_state),
       do: finish({:reply, {:ok, child}, {:UNMEASURED, :dynamic_supervisor_state}}, empty_payloads(), 0, [:dynamic_supervisor_state], %{child: child})

  defp row(_, :start_reply, {reference, {:ok, child}} = original)
       when is_reference(reference) and is_pid(child),
       do: finish(original, empty_payloads(), 0, [], %{reference: reference, child: child})

  defp row(_, :saved_entry, {child, {{Probe, :start_link, :undefined}, :temporary, 5_000, :worker, [Probe]}} = original)
       when is_pid(child),
       do: finish(original, empty_payloads(), 0, [], %{child: child})

  defp row(mode, :child_loop_call, {:gen_server, :loop, [{:server_data, supervisor, private_tag, child, Probe, :infinity, call, cast, info, continue}, state, action, []]})
       when is_pid(supervisor) and is_pid(child) and is_reference(private_tag) do
    if action === loop_action(mode) and
         call === Function.capture(Probe, :handle_call, 3) and
         cast === Function.capture(Probe, :handle_cast, 2) and
         info === Function.capture(Probe, :handle_info, 2) and
         continue === Function.capture(Probe, :handle_continue, 2) do
      state_row(mode, state, fn safe ->
        {:gen_server, :loop, [{:UNMEASURED, :child_private_runtime}, safe, action, []]}
      end, %{supervisor: supervisor, child: child}, [:child_private_runtime])
    else
      @invalid
    end
  end

  defp row(_, _, _), do: @invalid

  defp normalized_child(args), do: {{Probe, :start_link, [args]}, :temporary, 5_000, :worker, [Probe]}
  defp gen_args(supervisor, args), do: [:gen_server, supervisor, supervisor, Probe, args, []]
  defp loop_action(:recovery), do: :infinity
  defp loop_action(_), do: {:continue, :open}

  defp arguments_row(mode, original, wrap, extra_bindings \\ %{}, unmeasured \\ []) do
    case arguments(mode, original) do
      {:ok, safe, payloads, shells, bindings} ->
        finish(wrap.(safe), payloads, shells, unmeasured, Map.merge(bindings, extra_bindings))

      @invalid -> @invalid
    end
  end

  defp state_row(mode, original, wrap, extra_bindings \\ %{}, unmeasured \\ []) do
    case state(mode, original) do
      {:ok, safe, payloads, shells, bindings} ->
        finish(wrap.(safe), payloads, shells, unmeasured, Map.merge(bindings, extra_bindings))

      @invalid -> @invalid
    end
  end

  defp arguments(:recovery, original) do
    case UpstreamGroups.probe_recovery_arguments(original) do
      {:ok, ^original} ->
        {:ok, %{original | completion: {:opaque, HTTP.RequestCompletion}}, empty_payloads(), 1, %{arguments: original}}

      _ -> @invalid
    end
  end

  defp arguments(mode, original) when mode in [:h1, :h2] and is_map(original) do
    expected_keys = if mode == :h1, do: 6, else: 7

    if map_size(original) == expected_keys do
      case UpstreamGroups.probe_start_arguments(original) do
        {:ok, ^original} ->
          safe = %{
            original
            | member: %{original.member | config: {:payload, :config}},
              url: {:payload, :url},
              health: %{original.health | path: {:payload, :health_path}}
          }

          payloads = %{
            config: [:erlang.external_size(original.member.config)],
            url: [:erlang.external_size(original.url)],
            health_path: [:erlang.external_size(original.health.path)]
          }

          {:ok, safe, payloads, 0, %{arguments: original}}

        _ -> @invalid
      end
    else
      @invalid
    end
  end

  defp arguments(_, _), do: @invalid

  defp state(:recovery, %{owner_monitor: monitor} = original)
       when map_size(original) == 5 and is_reference(monitor) do
    state_arguments(:recovery, original, Map.take(original, @recovery_keys))
  end

  defp state(mode, %{
         cleanup_deadline: cleanup,
         owner_monitor: monitor,
         timer: timer,
         request: nil,
         original_request: nil,
         managed_transport: nil,
         transport_selection: nil,
         transport_pins: [],
         terminal: false,
         cancelled: false,
         headers: false,
         outcome: :failure
       } = original)
       when mode in [:h1, :h2] and is_reference(monitor) and is_reference(timer) do
    keys = if mode == :h1, do: @normal_keys, else: @normal_keys ++ [:group]
    expected_size = if mode == :h1, do: 18, else: 23
    args = Map.take(original, keys)

    with true <- map_size(original) == expected_size,
         {:ok, safe, payloads, shells, bindings} <- arguments(mode, args),
         true <- cleanup === args.deadline + 1_000,
         true <- initial_h2_fields?(mode, original, args) do
      {:ok, Map.merge(original, safe), payloads, shells, Map.put(bindings, :state, original)}
    else
      _ -> @invalid
    end
  end

  defp state(_, _), do: @invalid

  defp state_arguments(mode, original, args) do
    case arguments(mode, args) do
      {:ok, safe, payloads, shells, bindings} ->
        {:ok, Map.merge(original, safe), payloads, shells, Map.put(bindings, :state, original)}

      @invalid -> @invalid
    end
  end

  defp initial_h2_fields?(:h1, _, _), do: true

  defp initial_h2_fields?(:h2, %{client: ManagedH2Client, limits: limits, request_options: nil, submitted_url: nil}, args),
    do: limits === args.member.config.limits

  defp initial_h2_fields?(_, _, _), do: false

  defp empty_payloads, do: %{config: [], url: [], health_path: []}

  # Only fully validated ordinary payloads above and this final safe projection
  # reach ETF sizing. Opaque completion/private/ancestor originals never do.
  defp finish(safe, payloads, shells, unmeasured, bindings) do
    {:ok,
     %{
       projection: safe,
       projected_etf_bytes: :erlang.external_size(safe),
       payload_etf_bytes: payloads,
       completion_shells: shells,
       unmeasured: unmeasured,
       bound: :per_instance_only
     }, bindings}
  end
end
