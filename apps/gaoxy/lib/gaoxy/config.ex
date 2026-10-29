defmodule Gaoxy.Config do
  @moduledoc "Pure, strict validation of trusted embedded specifications. No sockets are opened."
  @limits %{
    max_active: 64,
    max_bytes: 1_048_576,
    max_connections: 16_384,
    max_requests: 65_536,
    max_streams: 65_536,
    max_packet: 65_507,
    max_output: 65_507,
    max_state: 65_536,
    callback_timeout: 5_000,
    idle_timeout: 30_000,
    drain_timeout: 5_000,
    max_memberships: 64
  }
  @keys [
    :id,
    :transport,
    :handler,
    :handler_mode,
    :handler_options,
    :ip,
    :port,
    :mode,
    :tls,
    :udp,
    :quic,
    :hell_options,
    :abyss_options,
    :dispatcher,
    :limits,
    :budget_policy,
    :capabilities
  ]

  @finite_max 9_223_372_036_854_775_807
  @policy_keys [:max_active, :max_bytes, :max_connections, :max_requests, :max_streams]
  @optional_caps [:max_active, :max_bytes]

  @doc "Independent finite lease bookkeeping guard, separate from administrator caps."
  def lease_safety_limit, do: 262_144

  @doc "Connection quota intersected with an explicit legacy lease cap."
  def connection_capacity(spec) when is_map(spec),
    do: connection_capacity(Map.get(spec, :limits, %{}), Map.get(spec, :budget_policy))

  def connection_capacity(_), do: 0

  def connection_capacity(limits, policy) when is_map(limits) do
    {connections, active} =
      if is_map(policy),
        do: {policy[:max_connections], policy[:max_active]},
        else: {Map.get(limits, :max_connections, @limits.max_connections), limits[:max_active]}

    if finite?(connections) and (is_nil(active) or finite?(active)),
      do: if(is_nil(active), do: connections, else: min(connections, active)),
      else: 0
  end

  def connection_capacity(_, _), do: 0

  @doc "Normalize numeric protocol limits while retaining raw administrator-cap provenance."
  def service_limits(input, defaults \\ %{}, policy \\ nil)

  def service_limits(input, defaults, policy) when is_map(input) and is_map(defaults) do
    limits = Map.merge(@limits, defaults)
    profile = Map.get(input, :protocol_max_bytes, limits.max_bytes)
    limits = limits |> Map.put(:max_bytes, profile) |> Map.merge(input)

    with :ok <- limit_check(%{limits: input}, limits),
         {:ok, sources} <- policy_sources(input, policy) do
      snapshot = Map.take(limits, @policy_keys)
      provenance = Map.put(sources, :normalized_limits, snapshot)

      policy =
        Map.new(@policy_keys, fn key ->
          value =
            if key in @optional_caps and sources[key] == :omitted, do: nil, else: limits[key]

          {key, value}
        end)
        |> Map.put(:provenance, provenance)

      {:ok, limits, policy}
    end
  end

  def service_limits(_, _, _), do: {:error, :invalid_limits}

  defp policy_sources(input, nil),
    do:
      {:ok,
       Map.new(@policy_keys, &{&1, if(Map.has_key?(input, &1), do: :explicit, else: :omitted)})}

  defp policy_sources(input, policy) do
    if valid_policy?(policy) do
      sources =
        Map.new(@policy_keys, fn key ->
          source =
            if Map.get(input, key) == policy.provenance.normalized_limits[key],
              do: policy.provenance[key],
              else: if(Map.has_key?(input, key), do: :explicit, else: :omitted)

          {key, source}
        end)

      {:ok, sources}
    else
      {:error, :invalid_budget_policy}
    end
  end

  defp valid_policy?(policy) when is_map(policy) do
    provenance = policy[:provenance]

    Map.keys(policy) -- [:provenance | @policy_keys] == [] and
      map_size(policy) == length(@policy_keys) + 1 and is_map(provenance) and
      Map.keys(provenance) -- [:normalized_limits | @policy_keys] == [] and
      map_size(provenance) == length(@policy_keys) + 1 and
      is_map(provenance[:normalized_limits]) and
      Enum.sort(Map.keys(provenance.normalized_limits)) == Enum.sort(@policy_keys) and
      Enum.all?(@policy_keys, fn key ->
        previous = provenance.normalized_limits[key]

        expected =
          if key in @optional_caps and provenance[key] == :omitted, do: nil, else: previous

        provenance[key] in [:explicit, :omitted] and finite?(previous) and policy[key] == expected
      end)
  end

  defp valid_policy?(_), do: false
  defp finite?(value), do: is_integer(value) and value in 1..@finite_max

  defp resource_budget(input) when is_map(input) do
    soft = input[:soft_limit]
    hard = input[:hard_limit]
    source = if is_nil(soft) and is_nil(hard), do: :adaptive, else: :explicit
    provenance = %{source: source}

    if Map.keys(input) -- [:soft_limit, :hard_limit, :provenance] == [] and
         Map.has_key?(input, :soft_limit) and Map.has_key?(input, :hard_limit) and
         (source == :adaptive or (finite?(soft) and finite?(hard) and soft <= hard)) and
         Map.get(input, :provenance, provenance) == provenance,
       do: {:ok, %{soft_limit: soft, hard_limit: hard, provenance: provenance}},
       else: {:error, :invalid_resource_budget}
  end

  defp resource_budget(_), do: {:error, :invalid_resource_budget}

  @doc false
  def shutdown_timeout(input) do
    limits = if is_map(input), do: Map.merge(@limits, input), else: @limits

    limits =
      if is_map(input) and limit_check(%{limits: input}, limits) == :ok,
        do: limits,
        else: @limits

    limits.drain_timeout + 2 * Gaoxy.Lifecycle.cleanup_headroom()
  end

  def validate(options) do
    with :ok <- keyword(options),
         :ok <- known(Map.new(options), [:services, :name, :activation, :resource_budget]),
         activation = Keyword.get(options, :activation, :immediate),
         true <- activation in [:immediate, :deferred] || {:error, :invalid_activation},
         true <- is_list(Keyword.get(options, :services, [])) || {:error, :invalid_services},
         {:ok, services} <- services(Keyword.get(options, :services, []), []),
         {:ok, budget} <-
           resource_budget(
             Keyword.get(options, :resource_budget, %{soft_limit: nil, hard_limit: nil})
           ) do
      {:ok,
       %{
         name: Keyword.get(options, :name),
         services: services,
         activation: activation,
         resource_budget: budget
       }}
    end
  end

  def service(input) when is_map(input) do
    normalized_service(input)
  end

  def service(_), do: {:error, :invalid_service}

  defp normalized_service(input) do
    with true <-
           (not Map.has_key?(input, :budget_policy) or is_map(input.budget_policy)) ||
             {:error, :invalid_budget_policy},
         {:ok, limits, policy} <-
           service_limits(Map.get(input, :limits, %{}), %{}, Map.get(input, :budget_policy)) do
      spec =
        Map.merge(
          %{
            ip: {127, 0, 0, 1},
            port: 0,
            mode: :unicast,
            tls: %{},
            udp: %{},
            quic: %{},
            dispatcher: %{},
            handler_options: [],
            handler_mode: :stream,
            capabilities: []
          },
          input
        )
        |> Map.put(:limits, limits)
        |> Map.put(:budget_policy, policy)

      with :ok <- known(input, @keys),
           {:ok, spec} <- Gaoxy.BackendOptions.normalize(spec),
           :ok <- identity(spec),
           :ok <- limit_check(input, limits),
           :ok <- handler_mode(spec),
           {:ok, spec} <- dispatcher(spec),
           :ok <- transport(spec),
           :ok <- handler(spec),
           :ok <- requested(spec),
           {:ok, options} <- handler_options(spec) do
        quic =
          if spec.transport == :quic,
            do: Map.put_new(spec.quic, :poll_interval, 10),
            else: spec.quic

        {:ok, %{spec | handler_options: options, quic: quic}}
      end
    end
  rescue
    BadMapError -> {:error, :invalid_options}
    ArgumentError -> {:error, :invalid_options}
  end

  def conflicts(a, b) do
    family = fn spec -> if spec.transport in [:udp, :quic], do: :udp, else: :tcp end

    a.port != 0 and a.port == b.port and family.(a) == family.(b) and
      tuple_size(a.ip) == tuple_size(b.ip) and
      (a.ip == b.ip or wildcard?(a.ip) or wildcard?(b.ip))
  end

  defp services([], acc), do: {:ok, Enum.reverse(acc)}

  defp services([input | rest], acc) do
    with {:ok, spec} <- service(input), :ok <- unique(spec, acc) do
      services(rest, [spec | acc])
    end
  end

  defp unique(spec, existing) do
    cond do
      Enum.any?(existing, &(&1.id == spec.id)) ->
        {:error, {:duplicate_service, spec.id}}

      conflict = Enum.find(existing, &conflicts(&1, spec)) ->
        {:error, {:binding_conflict, spec.id, conflict.id}}

      true ->
        :ok
    end
  end

  defp keyword(options) do
    if Keyword.keyword?(options) and length(options) == map_size(Map.new(options)),
      do: :ok,
      else: {:error, :invalid_options}
  end

  defp known(options, keys) when is_map(options) do
    case Map.keys(options) -- keys do
      [] -> :ok
      unknown -> {:error, {:unknown_options, Enum.sort(unknown)}}
    end
  end

  defp known(_, _), do: {:error, :invalid_options}

  defp identity(%{id: id, ip: ip, port: port}) do
    if ((is_atom(id) and not is_nil(id)) or (is_binary(id) and byte_size(id) in 1..128)) and
         valid_ip?(ip) and is_integer(port) and port in 0..65_535,
       do: :ok,
       else: {:error, :invalid_identity_or_binding}
  end

  defp identity(_), do: {:error, :missing_identity}

  defp valid_ip?(ip) when is_tuple(ip) and tuple_size(ip) in [4, 8] do
    max = if tuple_size(ip) == 4, do: 255, else: 65_535
    Enum.all?(Tuple.to_list(ip), &(is_integer(&1) and &1 in 0..max))
  end

  defp valid_ip?(_), do: false
  defp wildcard?(ip), do: Enum.all?(Tuple.to_list(ip), &(&1 == 0))

  defp limit_check(input, limits) do
    with :ok <- known(Map.get(input, :limits, %{}), [:protocol_max_bytes | Map.keys(@limits)]),
         true <-
           Enum.all?(limits, fn {_, n} -> finite?(n) end) ||
             {:error, :invalid_limits},
         true <-
           (limits.max_packet <= 65_507 and limits.max_memberships <= 64) ||
             {:error, :invalid_limits} do
      :ok
    end
  end

  defp transport(%{transport: :quic} = spec) do
    with true <- Code.ensure_loaded?(Quic) || {:error, {:unsupported_capability, :quic}},
         :ok <- known(spec.quic, [:alpn, :poll_interval]),
         true <-
           (valid_alpn?(spec.quic[:alpn]) and spec.quic[:alpn] != []) || {:error, :invalid_alpn},
         poll_interval = Map.get(spec.quic, :poll_interval, 10),
         true <-
           (is_integer(poll_interval) and poll_interval in 1..1_000) ||
             {:error, :invalid_quic_poll_interval},
         :ok <- known(spec.tls, [:certfile, :keyfile]),
         true <-
           (is_binary(spec.tls[:certfile]) and is_binary(spec.tls[:keyfile])) ||
             {:error, :missing_credentials},
         true <- tuple_size(spec.ip) == 4 || {:error, {:unsupported_capability, :quic_ipv6}},
         true <- not wildcard?(spec.ip) || {:error, :wildcard_bind_unsupported},
         :ok <- empty(spec.udp),
         :ok <- unicast(spec.mode),
         do: :ok
  end

  defp transport(%{transport: :tls, tls: %{provider: provider}}) when provider != :otp,
    do: {:error, {:unsupported_capability, provider}}

  defp transport(%{transport: :tls} = spec) do
    with :ok <- empty(spec.quic),
         :ok <-
           known(spec.tls, [
             :provider,
             :certfile,
             :keyfile,
             :alpn,
             :versions,
             :verify,
             :cacertfile,
             :fail_if_no_peer_cert
           ]),
         true <-
           (is_binary(spec.tls[:certfile]) and is_binary(spec.tls[:keyfile])) ||
             {:error, :missing_credentials},
         :ok <- tls_verification(spec.tls),
         true <- valid_alpn?(Map.get(spec.tls, :alpn, [])) || {:error, :invalid_alpn},
         true <-
           Map.get(spec.tls, :versions, [:"tlsv1.3"]) in [
             [:"tlsv1.3"],
             [:"tlsv1.2"],
             [:"tlsv1.3", :"tlsv1.2"]
           ] || {:error, :invalid_tls_versions},
         :ok <- empty(spec.udp),
         :ok <- unicast(spec.mode) do
      :ok
    end
  end

  defp transport(%{transport: :tcp} = spec) do
    with :ok <- empty(spec.tls),
         :ok <- empty(spec.udp),
         :ok <- empty(spec.quic),
         do: unicast(spec.mode)
  end

  defp transport(%{transport: :udp, mode: :broadcast, ip: ip}) when tuple_size(ip) == 8,
    do: {:error, {:unsupported_capability, :ipv6_broadcast}}

  defp transport(%{transport: :udp} = spec) do
    with :ok <- empty(spec.quic),
         :ok <- empty(spec.tls),
         true <- spec.mode in [:unicast, :broadcast, :multicast] || {:error, :invalid_udp_mode},
         :ok <-
           known(spec.udp, [
             :memberships,
             :multicast_if,
             :multicast_ttl,
             :multicast_loop,
             :strict_group_filter,
             :inet_backend
           ]),
         :ok <- udp_options(spec) do
      :ok
    end
  end

  defp transport(_), do: {:error, :invalid_transport}

  defp tls_verification(tls) do
    verify = Map.get(tls, :verify, :verify_none)

    valid =
      case verify do
        :verify_peer ->
          is_binary(tls[:cacertfile]) and byte_size(tls.cacertfile) > 0 and
            is_boolean(Map.get(tls, :fail_if_no_peer_cert, false))

        :verify_none ->
          not Map.has_key?(tls, :cacertfile) and not Map.has_key?(tls, :fail_if_no_peer_cert)

        _ ->
          false
      end

    if valid, do: :ok, else: {:error, :invalid_tls_verification}
  end

  defp udp_options(spec) do
    memberships = Map.get(spec.udp, :memberships, [])

    cond do
      Map.get(spec.udp, :inet_backend, :inet) not in [:inet, :socket] ->
        {:error, :invalid_backend}

      not is_list(memberships) ->
        {:error, :invalid_memberships}

      length(memberships) > spec.limits.max_memberships ->
        {:error, :membership_limit}

      spec.mode != :multicast and map_size(Map.delete(spec.udp, :inet_backend)) != 0 ->
        {:error, :multicast_options_require_multicast}

      not Enum.all?(memberships, &valid_membership?(&1, spec.ip)) ->
        {:error, :invalid_membership}

      not is_boolean(Map.get(spec.udp, :multicast_loop, true)) ->
        {:error, :invalid_loopback}

      not is_boolean(Map.get(spec.udp, :strict_group_filter, false)) ->
        {:error, :invalid_filter}

      not (is_integer(Map.get(spec.udp, :multicast_ttl, 1)) and
               Map.get(spec.udp, :multicast_ttl, 1) in 0..255) ->
        {:error, :invalid_ttl}

      tuple_size(spec.ip) == 8 and spec.mode == :multicast and :os.type() != {:unix, :linux} ->
        {:error, {:unsupported_capability, :ipv6_multicast}}

      true ->
        :ok
    end
  end

  def valid_membership?({group, interface}, ip) do
    valid_ip?(group) and tuple_size(group) == tuple_size(ip) and
      Abyss.Transport.UDP.Multicast.multicast_address?(group) and
      if(tuple_size(ip) == 8,
        do:
          (is_integer(interface) and interface > 0) or
            (is_binary(interface) and byte_size(interface) > 0),
        else:
          interface == :any or (is_binary(interface) and byte_size(interface) > 0) or
            (valid_ip?(interface) and tuple_size(interface) == 4)
      )
  end

  def valid_membership?(_, _), do: false

  defp handler_mode(%{handler_mode: :native, transport: type}) when type in [:tcp, :tls],
    do: :ok

  defp handler_mode(%{handler_mode: :native}),
    do: {:error, :native_requires_stream_transport}

  defp handler_mode(%{handler_mode: :stream}), do: :ok

  defp handler_mode(%{handler_mode: :datagram_dispatcher, transport: :udp, mode: :unicast}),
    do: :ok

  defp handler_mode(%{handler_mode: :datagram_dispatcher}),
    do: {:error, :dispatcher_requires_udp_unicast}

  defp handler_mode(_), do: {:error, :invalid_handler_mode}

  defp dispatcher(%{handler_mode: :datagram_dispatcher} = spec) do
    with :ok <- known(spec.dispatcher, [:max_queue, :max_bytes, :handoff_timeout]) do
      options =
        Map.merge(%{max_queue: 32, max_bytes: 262_144, handoff_timeout: 50}, spec.dispatcher)

      if Enum.all?(options, fn {_, n} -> is_integer(n) and n > 0 end) and
           options.max_queue <= 256 and options.max_bytes <= 16_777_216 and
           options.handoff_timeout <= 1000,
         do: {:ok, %{spec | dispatcher: options}},
         else: {:error, :invalid_dispatcher_options}
    end
  end

  defp dispatcher(%{dispatcher: empty} = spec) when empty == %{}, do: {:ok, spec}
  defp dispatcher(_), do: {:error, :inapplicable_options}

  defp handler(%{handler_mode: :datagram_dispatcher, handler: module}) when is_atom(module) do
    if Code.ensure_loaded?(module) and
         Enum.all?(
           [
             validate_options: 1,
             validate_service: 2,
             start_link: 2,
             offer: 2,
             control: 3,
             drain: 2
           ],
           fn {callback, arity} -> function_exported?(module, callback, arity) end
         ),
       do: :ok,
       else: {:error, :invalid_handler}
  end

  defp handler(%{handler_mode: :native, handler: module}) when is_atom(module) do
    if Code.ensure_loaded?(module) and
         Enum.all?(
           [
             start_link: 1,
             handle_connection: 2,
             handle_data: 3,
             handle_close: 2,
             handle_error: 3,
             handle_shutdown: 2,
             handle_timeout: 2,
             validate_options: 1
           ],
           fn {callback, arity} -> function_exported?(module, callback, arity) end
         ),
       do: :ok,
       else: {:error, :invalid_handler}
  end

  defp handler(%{transport: :quic, handler: module}) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :init, 3) and
         function_exported?(module, :handle_event, 2),
       do: :ok,
       else: {:error, :invalid_handler}
  end

  defp handler(%{transport: type, handler: module}) when is_atom(module) do
    callback = if type == :udp, do: {:handle_datagram, 2}, else: {:handle_data, 2}

    if Code.ensure_loaded?(module) and
         function_exported?(module, elem(callback, 0), elem(callback, 1)) and
         (type == :udp or function_exported?(module, :init, 2)),
       do: :ok,
       else: {:error, :invalid_handler}
  end

  defp handler(_), do: {:error, :invalid_handler}

  defp handler_options(%{handler_mode: :native} = spec) do
    case Gaoxy.Lifecycle.protect(fn -> spec.handler.validate_options(spec.handler_options) end) do
      {:ok, normalized} -> {:ok, normalized}
      {:error, reason} -> {:error, {:handler_options, reason}}
      _ -> {:error, :invalid_handler_options}
    end
  end

  defp handler_options(%{handler_mode: :datagram_dispatcher} = spec) do
    case Gaoxy.Lifecycle.protect(fn ->
           with {:ok, options} <- spec.handler.validate_options(spec.handler_options),
                do: spec.handler.validate_service(options, spec)
         end) do
      {:ok, normalized} -> {:ok, normalized}
      {:error, reason} -> {:error, {:handler_options, reason}}
      _ -> {:error, :invalid_handler_options}
    end
  end

  defp handler_options(spec), do: {:ok, spec.handler_options}

  defp requested(spec) do
    supported =
      if spec.transport == :quic do
        [:quic, :local_cleanup]
      else
        [spec.transport, :pause, :drain] ++ if(spec.transport == :udp, do: [spec.mode], else: [])
      end

    supported =
      if spec.transport == :tls and Map.get(spec.tls, :verify) == :verify_peer,
        do: [:mtls | supported],
        else: supported

    if is_list(spec.capabilities) do
      case spec.capabilities -- supported do
        [] -> :ok
        [cap | _] -> {:error, {:unsupported_capability, cap}}
      end
    else
      {:error, :invalid_capabilities}
    end
  end

  defp valid_alpn?(list) when is_list(list),
    do: Enum.all?(list, &(is_binary(&1) and byte_size(&1) in 1..255))

  defp valid_alpn?(_), do: false
  defp empty(map) when map == %{}, do: :ok
  defp empty(_), do: {:error, :inapplicable_options}
  defp unicast(:unicast), do: :ok
  defp unicast(_), do: {:error, :inapplicable_mode}
end
