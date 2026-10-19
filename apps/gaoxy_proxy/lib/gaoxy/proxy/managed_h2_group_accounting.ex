defmodule Gaoxy.Proxy.ManagedH2GroupAccounting do
  @moduledoc false

  alias Gaoxy.HTTP.{Exchange, Request, Resources}
  alias Gaoxy.Proxy.{GroupEndpoint, ManagedH2Client, ManagedH2Envelope, ManagedH2Preparation}
  alias Gaoxy.Proxy.{UpstreamGroups, UpstreamTransports}
  alias Gaoxy.Proxy.HTTP.Session
  alias Gaoxy.Proxy.UpstreamGroups.{Options, Probe}

  @invalid {:error, :invalid_group_accounting}
  @capacity {:error, :group_accounting_capacity}
  @min -9_223_372_036_854_775_808
  @max 9_223_372_036_854_775_807
  @uint 18_446_744_073_709_551_615
  @caps %{
    p: 1_048_576,
    s: 2_359_296,
    l: 196_608,
    n: 205_337,
    k: 1_183_744,
    x: 131_072,
    r: 205_337,
    o: 1_572_864,
    a: 786_432,
    w: 851_968,
    i: 393_216,
    u: 8_192,
    e: 131_072
  }
  @phases %{
    startup: %{roles: [p: 1, a: 1, w: 1, a: 1, s: 1, e: 1], bytes: 5_963_776},
    selected: %{roles: [p: 1, s: 1, l: 1, i: 1, k: 1, e: 1], bytes: 5_312_512},
    boundary: %{roles: [p: 1, s: 1, l: 1, n: 1, k: 1, x: 1, r: 1, o: 1, e: 1], bytes: 7_033_906},
    open: %{roles: [p: 1, s: 1, o: 1, u: 1, i: 1, e: 1], bytes: 5_513_216},
    streaming: %{roles: [p: 1, s: 1, e: 1], bytes: 3_538_944},
    cleanup: %{roles: [p: 1, s: 1, i: 1, e: 1], bytes: 3_932_160}
  }
  @control_caps %{pin: 196_608, selection: 32_768, probe: 32_768}
  @session_args ~w(owner service instance gate started_at deadline config selector transport_handoff request_options)a
  @session_keys @session_args ++
                  ~w(monitors client cleanup_deadline cleanup_requested_deadline cleanup_started
    opening_timer activated_at opening_deadline total_timer selection awaiting_transport transport_pins
    transport_selection managed_transport managed_path submitted_url poll_timer original_request outcome token
    request headers delivery trailers cancelled consumed)a
  @probe_args ~w(owner token member deadline health url group)a
  @probe_keys @probe_args ++
                ~w(cleanup_deadline owner_monitor timer request original_request managed_transport
    transport_selection transport_pins terminal cancelled headers outcome client limits request_options submitted_url)a
  @recovery_args ~w(owner recovery completion deadline)a
  @pump_keys ~w(exchange config client policy response_policy session monitor deadline transport_handoff upload
    ready upload_stopped last_activity)a
  @limits ~w(max_chunk_bytes opening_timeout idle_timeout write_timeout max_lifetime)a
  @health ~w(path interval timeout stale_after failure_threshold recovery_threshold jitter)a
  @g_keys ~w(provider owner owner_epoch group generation max_url_bytes transports execution_profile)a
  @t_keys ~w(provider owner owner_epoch resource)a
  @pin_keys ~w(provider owner owner_epoch ref operation handles kind)a
  @pin_record ~w(keys holder acquirer kind operation deadline monitor timer)a
  @selection_record ~w(key index guardian monitor completion deadline recovery)a
  @probe_record ~w(pid key index bytes completion claimed monitor recovery deadline)a
  @reasons ~w(invalid_request invalid_policy invalid_response upstream_failure upstream_task upstream_delivery_limit
    upstream_delivery_overlap upstream_trailer_limit timeout request_timeout unavailable cancelled cleanup_pending
    cleanup_unconfirmed invalid_resource invalid_resource_pin invalid_transport_endpoint unauthorized retiring
    resource_unavailable)a
  @reason_wrappers ~w(cleanup_failed transport_cleanup_failed pin_release_failed service_cleanup_failed
    selection_cleanup_failed cleanup_unconfirmed)a
  @native_limits ~w(max_request_line max_header_bytes max_headers max_body_bytes max_chunk_line max_trailer_bytes
    max_trailers max_read_chunk max_buffer_bytes request_timeout header_timeout read_timeout write_timeout max_write_chunk)a
  @native_request_keys Map.keys(%Request{})
  @exchange_keys Map.keys(%Exchange{})

  def contract do
    %{
      version: 1,
      unit: :external_term_payload_bytes,
      role_caps: @caps,
      phases: @phases,
      group_bytes: 7_033_906,
      fixed_bytes: 9_444_956,
      reservation_bytes: 16_478_862,
      startup_bytes: 5_963_776,
      config_growth_bytes: 131_072,
      group_record_cap: 12_582_912,
      control_total_cap: 16_777_216,
      control_record_caps: @control_caps
    }
  end

  def reservation_bytes, do: 16_478_862
  def startup_bytes, do: 5_963_776

  def phase(name) do
    case @phases do
      %{^name => value} -> {:ok, value}
      _ -> @invalid
    end
  end

  def project(selector, original) do
    case projection(selector, original) do
      {:ok, role, safe, cap} ->
        # Every path to this call has a closed, bounded original constructor.
        # Recognized opaque interiors have already been replaced; originals
        # are never serialized to discover whether they were safe to traverse.
        bytes = :erlang.external_size(safe)

        if bytes <= cap,
          do: {:ok, %{role: role, projection: safe, bytes: bytes, cap: cap}},
          else: @capacity

      :error ->
        @invalid
    end
  end

  def validate(selector, original) do
    case project(selector, original) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  def startup(module, args) when module in [Session, Probe] do
    case project({:caller, module}, {module, args}) do
      {:ok, %{bytes: bytes}} when bytes + 65_536 <= 851_968 ->
        {:ok, %{argument_bytes: bytes, request_bound_bytes: bytes + 65_536}}

      {:ok, _} ->
        @capacity

      error ->
        error
    end
  end

  def startup(_, _), do: @invalid

  def group_charge(record) do
    if group_record?(record) and is_integer(record.bytes) and record.bytes >= 0 and
         record.bytes <= 12_582_912 do
      bytes = :erlang.external_size(Map.delete(record, :bytes)) + 131_072
      if bytes <= 12_582_912, do: {:ok, bytes}, else: @capacity
    else
      @invalid
    end
  end

  def group_update(record, reserved) do
    cond do
      not is_integer(reserved) or reserved < 1 or reserved > 12_582_912 -> @invalid
      not group_record?(record) or record.bytes !== reserved -> @invalid
      :erlang.external_size(Map.delete(record, :bytes)) > reserved -> @capacity
      true -> :ok
    end
  end

  def control_charge(kind, record) when kind in [:pin, :selection, :probe] do
    if control_record?(kind, record, :complete) do
      bytes =
        record |> Map.delete(:control_bytes) |> control_projection() |> :erlang.external_size()

      if bytes <= @control_caps[kind], do: {:ok, bytes}, else: @capacity
    else
      @invalid
    end
  end

  def control_charge(_, _), do: @invalid

  def control_reserve(kind, record) when kind in [:pin, :selection, :probe] do
    # A whole finite record slot is admitted before identities/effects exist.
    # This returns a charge, not a fabricated runtime record or capability.
    if control_record?(kind, record, :provisional), do: {:ok, @control_caps[kind]}, else: @invalid
  end

  def control_reserve(_, _), do: @invalid

  # These are source bounds for future local runtime identities, not fabricated
  # refs/PIDs. Callers establish local constructors before effects; actual
  # projected envelopes still pass through the unchanged whole-slot gate.
  def preflight_control(:monitor, original_pid) do
    if pid?(original_pid),
      do: monitor_preflight(:erlang.external_size(original_pid)),
      else: @invalid
  end

  def preflight_control(:local_monitor, source_node) do
    if source_node === node(),
      do: monitor_preflight(:erlang.external_size(source_node) + 13),
      else: @invalid
  end

  def preflight_control(:cleanup_cancel, {:token, original_token, deadline}) do
    if ref?(original_token) and time?(deadline),
      do: cleanup_preflight(:erlang.external_size(original_token), deadline),
      else: @invalid
  end

  def preflight_control(:cleanup_cancel, deadline) do
    if time?(deadline), do: cleanup_preflight(local_ref_bound(), deadline), else: @invalid
  end

  def preflight_control({:owner, owner, op}, original) when owner in [:group, :transport] do
    with :ok <- validate({:owner_call, owner, op}, original) do
      # I retains the whole original request. E pays only its scalar public
      # call wrapper, whose future local alias reference is source-bounded.
      call_preflight(:erlang.external_size({:slot, :i}))
    end
  end

  def preflight_control(:admission, original) do
    if admission_request?(original) do
      with {:ok, %{bytes: bytes}} <- project({:control, :admission}, original),
           do: call_preflight(bytes)
    else
      @invalid
    end
  end

  def preflight_control(:task, {original_ref, original_pid}) do
    if ref?(original_ref) and pid?(original_pid) do
      down =
        :erlang.external_size(original_ref) + :erlang.external_size(original_pid) +
          :erlang.external_size(:DOWN) + :erlang.external_size(:process) + finite_reason_bound() +
          16

      response =
        :erlang.external_size(original_ref) +
          :erlang.external_size({:slot, :extra_public_metadata_and_response_heads}) + 16

      control_preflight(max(down, response))
    else
      @invalid
    end
  end

  def preflight_control(_, _), do: @invalid

  # NEWER_REFERENCE_EXT permits at most five ID words. The complete node ETF
  # plus27 covers its tag, count, creation, ID words and external version.
  defp local_ref_bound, do: :erlang.external_size(node()) + 27

  defp finite_reason_bound do
    leaf = @reasons |> Enum.map(&:erlang.external_size/1) |> Enum.max()
    wrapper = @reason_wrappers |> Enum.map(&:erlang.external_size/1) |> Enum.max()
    leaf + 3 * (wrapper + 1)
  end

  defp monitor_preflight(pid_bytes) do
    # NEW_PID_EXT is nodeETF+13. Summing complete scalar ETF lengths is
    # conservative for the containing DOWN tuple, including tuple syntax.
    bytes =
      pid_bytes + local_ref_bound() + :erlang.external_size(:DOWN) +
        :erlang.external_size(:process) + finite_reason_bound()

    control_preflight(bytes)
  end

  defp cleanup_preflight(token_bytes, deadline) do
    bytes =
      token_bytes + :erlang.external_size(deadline) +
        :erlang.external_size(:gaoxy_cleanup_cancel) + finite_reason_bound()

    control_preflight(bytes)
  end

  defp control_preflight(bytes), do: if(bytes <= 2_048, do: :ok, else: @capacity)

  defp call_preflight(payload_bytes) do
    # Finite GenServer.call uses {self(), [:alias | local_ref]}; the local
    # infinity form uses the smaller bare ref. Sixteen bytes conservatively
    # cover the fixed tuple/list syntax; complete scalar ETF sums overcount
    # their version bytes. This creates no future identity or call envelope.
    bytes =
      :erlang.external_size(self()) + local_ref_bound() +
        :erlang.external_size(:alias) + :erlang.external_size(:"$gen_call") + payload_bytes + 16

    if pid?(self()) and bytes <= 24_576, do: :ok, else: @capacity
  end

  defp projection(:selected, v), do: retained(:l, v, selected?(v))

  defp projection(:neutral, v),
    do: retained(:n, v, ManagedH2Envelope.validate_group_source(v) == :ok)

  defp projection(:request, v), do: retained(:r, v, ManagedH2Envelope.validate_request(v) == :ok)
  defp projection(:context, v), do: retained(:x, v, context?(v))
  defp projection(:group_handle, v), do: retained(:x, v, group?(v), 65_536)
  defp projection(:captured_pins, v), do: retained(:i, v, captures?(v), 65_536)
  defp projection(:health, v), do: retained(:x, v, health?(v))
  defp projection(:group_endpoint, v), do: retained(:p, v, endpoint?(v))

  defp projection(:checked, v) do
    if checked?(v), do: shaped(:k, checked_projection(v)), else: :error
  end

  defp projection(:options, v) do
    if options?(v), do: shaped(:o, options_projection(v)), else: :error
  end

  defp projection({:args, :session}, v), do: retained(:a, v, session_args?(v))
  defp projection({:args, :probe}, v), do: retained(:a, v, probe_args?(v))

  defp projection({:args, :recovery}, v) do
    if recovery_args?(v), do: shaped(:a, completion_projection(v)), else: :error
  end

  defp projection({:caller, module}, {module, args}) when module in [Session, Probe] do
    case args_projection(module, args) do
      {:ok, safe} -> shaped(:a, {module, safe})
      :error -> :error
    end
  end

  defp projection(
         {:supervisor, module},
         {:"$gen_call", {caller, ref},
          {:start_child, {{module, :start_link, [args]}, :temporary, 5_000, :worker, [module]}}} =
           original
       )
       when module in [Session, Probe] do
    with true <- pid?(caller) and ref?(ref),
         {:ok, safe} <- args_projection(module, args) do
      {:"$gen_call", from, {:start_child, child}} = original

      shaped(
        :w,
        {:"$gen_call", from, {:start_child, put_elem(child, 0, {module, :start_link, [safe]})}}
      )
    else
      _ -> :error
    end
  end

  defp projection({:state, :session}, v) do
    if session?(v), do: shaped(:s, session_projection(v)), else: :error
  end

  defp projection({:state, :probe}, v) do
    if probe?(v), do: shaped(:s, probe_projection(v)), else: :error
  end

  defp projection({:state, :recovery}, v) do
    if exact?(v, @recovery_args ++ [:owner_monitor]) and ref?(v.owner_monitor) and
         recovery_args?(Map.delete(v, :owner_monitor)),
       do: shaped(:s, completion_projection(v)),
       else: :error
  end

  defp projection(:pump, v) do
    if pump?(v), do: shaped(:p, pump_projection(v)), else: :error
  end

  defp projection(:open_result, {:ok, handle, upload}) do
    if handle?(handle) and optional_pid?(upload),
      do: shaped(:u, {:ok, handle_projection(handle), upload}),
      else: :error
  end

  defp projection(:open_result, {:error, reason} = result),
    do: retained(:u, result, reason?(reason))

  defp projection({:owner_call, owner, op}, value) when owner in [:group, :transport] do
    case owner_call(owner, op, value) do
      {:ok, safe} -> shaped(:i, safe)
      :error -> :error
    end
  end

  defp projection({:owner_reply, owner, op}, value) when owner in [:group, :transport] do
    case owner_reply(owner, op, value) do
      {:ok, safe} -> shaped(:i, safe)
      :error -> :error
    end
  end

  defp projection({:control, family}, value) do
    case control(family, value) do
      {:ok, safe, cap} -> shaped(:e, safe, cap)
      :error -> :error
    end
  end

  defp projection(_, _), do: :error

  defp retained(role, original, valid, cap \\ nil)
  defp retained(role, original, true, cap), do: shaped(role, original, cap)
  defp retained(_, _, _, _), do: :error
  defp shaped(role, safe, cap \\ nil), do: {:ok, role, safe, cap || @caps[role]}

  defp exact?(value, keys) when is_map(value) and map_size(value) == length(keys),
    do: Enum.all?(keys, &Map.has_key?(value, &1))

  defp exact?(_, _), do: false

  defp scalar?(value) when is_pid(value) or is_reference(value),
    do: :erlang.external_size(value) <= 2_048

  defp scalar?(_), do: false
  defp pid?(value), do: is_pid(value) and scalar?(value)
  defp ref?(value), do: is_reference(value) and scalar?(value)
  defp call_tag?([:alias | ref]), do: ref?(ref)
  defp call_tag?(ref), do: ref?(ref)
  defp optional_pid?(nil), do: true
  defp optional_pid?(v), do: pid?(v)
  defp optional_ref?(nil), do: true
  defp optional_ref?(v), do: ref?(v)
  defp time?(v), do: is_integer(v) and v >= @min and v <= @max
  defp optional_time?(nil), do: true
  defp optional_time?(v), do: time?(v)
  defp unsigned?(v), do: is_integer(v) and v >= 0 and v <= @uint
  defp duration?(v), do: is_integer(v) and v in 1..86_400_000

  defp binary?(v, cap, compact \\ false) do
    is_binary(v) and byte_size(v) <= cap and
      :binary.referenced_byte_size(v) <= cap and
      (not compact or :binary.referenced_byte_size(v) == byte_size(v))
  end

  defp id?(v), do: binary?(v, 128, true) and byte_size(v) > 0
  defp list?(v, max, valid), do: list?(v, max, valid, 0)
  defp list?([], _, _, _), do: true

  defp list?([head | tail], max, valid, count) when count < max,
    do: valid.(head) and list?(tail, max, valid, count + 1)

  defp list?(_, _, _, _), do: false
  defp nonempty?([_ | _]), do: true
  defp nonempty?(_), do: false

  defp limits?(v),
    do:
      exact?(v, @limits) and is_integer(v.max_chunk_bytes) and
        v.max_chunk_bytes in 1..65_536 and
        Enum.all?(@limits -- [:max_chunk_bytes], &duration?(v[&1]))

  defp transport?(v),
    do:
      exact?(v, @t_keys) and v.provider == UpstreamTransports and
        pid?(v.owner) and ref?(v.owner_epoch) and ref?(v.resource)

  defp manifest?(v), do: list?(v, 64, &resource?/1) and match?({:ok, _}, Resources.validate(v))

  defp group?(v) do
    exact?(v, @g_keys) and v.provider == UpstreamGroups and pid?(v.owner) and
      ref?(v.owner_epoch) and ref?(v.generation) and id?(v.group) and
      is_integer(v.max_url_bytes) and v.max_url_bytes in 1..8_192 and
      v.execution_profile == :managed_h2 and
      list?(v.transports, 32, &transport?/1) and nonempty?(v.transports) and
      Enum.uniq(v.transports) === v.transports and
      match?({:ok, _}, Resources.validate([v | v.transports]))
  end

  defp resource?(%{provider: UpstreamTransports} = v), do: transport?(v)
  defp resource?(%{execution_profile: :managed_h2} = v), do: group?(v)

  defp resource?(%{provider: UpstreamGroups} = v) do
    base = @g_keys -- [:transports, :execution_profile]
    valid = exact?(v, base) or exact?(v, base ++ [:transports])

    valid and pid?(v.owner) and ref?(v.owner_epoch) and ref?(v.generation) and
      is_binary(v.group) and byte_size(v.group) in 1..128 and
      is_integer(v.max_url_bytes) and v.max_url_bytes in 1..8_192 and
      (not Map.has_key?(v, :transports) or
         (list?(v.transports, 32, &transport?/1) and nonempty?(v.transports) and
            Enum.uniq(v.transports) === v.transports))
  end

  defp resource?(_), do: false

  defp pin?(v) when is_map(v) do
    provider = Map.get(v, :provider)
    keys = if provider == UpstreamTransports, do: @pin_keys ++ [:holder], else: @pin_keys

    exact?(v, keys) and provider in [UpstreamGroups, UpstreamTransports] and
      pid?(v.owner) and ref?(v.owner_epoch) and ref?(v.operation) and ref?(v.ref) and
      v.kind in [:baseline, :preparation, :request] and
      (provider != UpstreamTransports or pid?(v.holder)) and nonempty?(v.handles) and
      manifest?(v.handles) and
      Enum.all?(
        v.handles,
        &(&1.provider === provider and &1.owner === v.owner and &1.owner_epoch === v.owner_epoch)
      )
  end

  defp pin?(_), do: false
  defp captures?(v), do: list?(v, 64, &pin?/1) and :erlang.external_size(v) <= 65_536

  defp captures_for?(pins, handle),
    do:
      captures?(pins) and
        Enum.any?(pins, fn p ->
          p.kind == :request and p.provider === handle.provider and p.owner === handle.owner and
            p.owner_epoch === handle.owner_epoch and handle in p.handles
        end)

  defp config?(v),
    do:
      ManagedH2Envelope.validate_config(v) == :ok and transport?(v.transport) and
        limits?(v.limits)

  defp selected?(v),
    do:
      exact?(v, [:id, :config, :max_inflight]) and id?(v.id) and
        is_integer(v.max_inflight) and v.max_inflight in 1..1_024 and config?(v.config)

  defp checked?(v) do
    exact?(v, [:policy, :transport_scope, :fetch_options]) and
      is_struct(v.policy, ManagedH2Preparation.Policy) and v.policy.protocol in [:http2, :h2c] and
      ManagedH2Envelope.validate_checked_client(v, v.policy.protocol) == :ok
  end

  defp checked_projection(v), do: %{v | transport_scope: {:opaque, HTTP.ManagedTransport}}

  defp options?(v) do
    exact?(
      v,
      ~w(request managed_transport timeout opening_timeout write_timeout deadline opening_deadline)a
    ) and
      duration?(v.timeout) and duration?(v.opening_timeout) and duration?(v.write_timeout) and
      v.opening_timeout <= v.timeout and time?(v.deadline) and time?(v.opening_deadline) and
      v.opening_deadline <= v.deadline and ManagedH2Envelope.validate_request(v.request) == :ok and
      checked?(v.managed_transport) and request_authority?(v.request, v.managed_transport)
  end

  defp request_authority?(request, checked) do
    uri = URI.parse(request.url)
    policy = checked.policy

    {request.protocol, uri.scheme, String.downcase(uri.host), uri.port} ===
      {policy.protocol, Atom.to_string(policy.scheme), policy.host, policy.port}
  end

  defp options_projection(v),
    do: %{v | managed_transport: checked_projection(v.managed_transport)}

  defp context?(v) do
    exact?(v, ~w(group instance limits deadline opening_deadline now)a) and group?(v.group) and
      pid?(v.instance) and limits?(v.limits) and time?(v.now) and time?(v.deadline) and
      v.deadline <= @max - 1_000 and time?(v.opening_deadline) and
      v.now < v.opening_deadline and v.opening_deadline <= v.deadline and
      duration?(v.deadline - v.now) and duration?(v.opening_deadline - v.now)
  end

  defp endpoint?(%GroupEndpoint{} = v),
    do: exact?(v, [:__struct__, :group, :limits]) and group?(v.group) and limits?(v.limits)

  defp endpoint?(_), do: false

  defp health?(v) do
    exact?(v, @health) and binary?(v.path, 8_192, true) and String.starts_with?(v.path, "/") and
      path_text?(v.path) and integer_range?(v.interval, 1, 3_600_000) and
      integer_range?(v.timeout, 1, 5_000) and integer_range?(v.stale_after, v.interval, 3_600_000) and
      integer_range?(v.failure_threshold, 1, 100) and integer_range?(v.recovery_threshold, 1, 100) and
      integer_range?(v.jitter, 0, 3_600_000)
  end

  defp integer_range?(v, low, high), do: is_integer(v) and v >= low and v <= high
  defp path_text?(<<>>), do: true
  defp path_text?(<<?%, a, b, rest::binary>>), do: hex?(a) and hex?(b) and path_text?(rest)

  defp path_text?(<<c, rest::binary>>) when c in 33..126 and c not in [??, ?#, ?\\, ?%],
    do: path_text?(rest)

  defp path_text?(_), do: false
  defp hex?(c), do: c in ?0..?9 or c in ?a..?f or c in ?A..?F

  defp session_args?(v) do
    exact?(v, @session_args) and Enum.all?([v.owner, v.service, v.instance, v.gate], &pid?/1) and
      time?(v.started_at) and time?(v.deadline) and v.deadline <= @max - 1_000 and
      endpoint?(v.config) and group_selector?(v.selector, v.config.group) and
      optional_ref?(v.transport_handoff) and
      ManagedH2Envelope.validate_group_source(v.request_options) == :ok
  end

  defp group_selector?({:group, group, pins}, group),
    do:
      list?(pins, 64, &(is_map(&1) and Map.get(&1, :provider) == UpstreamGroups)) and
        captures_for?(pins, group)

  defp group_selector?(_, _), do: false

  defp probe_args?(v) do
    exact?(v, @probe_args) and pid?(v.owner) and ref?(v.token) and selected?(v.member) and
      health?(v.health) and group?(v.group) and v.owner === v.group.owner and
      time?(v.deadline) and v.deadline <= @max - 1_000 and binary?(v.url, 65_536, true) and
      v.member.config.transport in v.group.transports and
      byte_size(raw_root(v.member.config)) <= v.group.max_url_bytes and
      v.group.max_url_bytes + byte_size(v.health.path) <= 65_536 and
      v.url === raw_root(v.member.config) <> v.health.path
  end

  defp recovery_args?(v),
    do:
      exact?(v, @recovery_args) and pid?(v.owner) and
        recovery_token?(v.recovery) and completion?(v.completion) and time?(v.deadline)

  defp recovery_token?({kind, token}), do: kind in [:selection, :probe] and ref?(token)
  defp recovery_token?(_), do: false
  defp args_projection(Session, args), do: if(session_args?(args), do: {:ok, args}, else: :error)

  defp args_projection(Probe, %{recovery: _} = args),
    do: if(recovery_args?(args), do: {:ok, completion_projection(args)}, else: :error)

  defp args_projection(Probe, args), do: if(probe_args?(args), do: {:ok, args}, else: :error)

  defp completion?(v),
    do:
      is_struct(v, HTTP.RequestCompletion) and
        exact?(v, [:__struct__, :tracker, :latch, :unsupported])

  defp completion_projection(v), do: %{v | completion: {:opaque, HTTP.RequestCompletion}}

  defp handle?(v) do
    exact?(v, [:promise, :completion, :stream, :resolved]) and
      is_struct(v.promise, HTTP.Promise) and exact?(v.promise, [:__struct__, :task, :completion]) and
      is_struct(v.promise.task, Task) and
      exact?(v.promise.task, [:__struct__, :owner, :pid, :ref, :mfa]) and
      pid?(v.promise.task.owner) and pid?(v.promise.task.pid) and ref?(v.promise.task.ref) and
      v.promise.task.mfa in [nil, {:erlang, :apply, 2}] and completion?(v.completion) and
      v.promise.completion === v.completion and optional_pid?(v.stream) and is_boolean(v.resolved) and
      ManagedH2Client.completion(v) === v.completion
  end

  defp optional_handle?(nil), do: true
  defp optional_handle?(v), do: handle?(v)
  defp handle_projection(nil), do: nil

  defp handle_projection(v),
    do: %{
      v
      | completion: {:opaque, HTTP.RequestCompletion},
        promise: %{v.promise | completion: {:opaque, HTTP.RequestCompletion}}
    }

  defp optional_checked?(nil), do: true
  defp optional_checked?(v), do: checked?(v)
  defp optional_checked_projection(nil), do: nil
  defp optional_checked_projection(v), do: checked_projection(v)
  defp reason?(v), do: reason?(v, 0)
  defp reason?(v, _) when v in @reasons, do: true

  defp reason?({kind, inner}, depth) when kind in @reason_wrappers and depth < 3,
    do: reason?(inner, depth + 1)

  defp reason?(_, _), do: false
  defp normalized_reason(v), do: Session.finite_reason(v)

  defp session?(v) do
    exact?(v, @session_keys) and Enum.all?([v.owner, v.service, v.instance, v.gate], &pid?/1) and
      time?(v.started_at) and time?(v.deadline) and
      Enum.all?(
        [v.cleanup_deadline, v.cleanup_requested_deadline, v.activated_at, v.opening_deadline],
        &optional_time?/1
      ) and
      Enum.all?(
        [v.opening_timer, v.total_timer, v.poll_timer, v.transport_handoff, v.delivery, v.token],
        &optional_ref?/1
      ) and
      Enum.all?(
        [v.cleanup_started, v.managed_path, v.headers, v.cancelled, v.consumed],
        &is_boolean/1
      ) and
      v.client == ManagedH2Client and v.managed_path and reason_or_success?(v.outcome) and
      monitors?(v.monitors, [v.owner, v.service, v.instance, v.gate]) and
      session_aliases?(v) and optional_handle?(v.request) and optional_handle?(v.original_request) and
      handle_aliases?(v.request, v.original_request) and url_slot?(v.submitted_url) and
      fields?(v.trailers, 128, 65_536) and optional_checked?(v.managed_transport) and
      request_slot?(v.request_options) and session_staged?(v)
  end

  defp reason_or_success?(:success), do: true
  defp reason_or_success?(v), do: reason?(v)

  defp monitors?(v, owners) when is_map(v) and map_size(v) <= 4,
    do: Enum.all?(v, fn {ref, pid} -> ref?(ref) and pid?(pid) and pid in owners end)

  defp monitors?(_, _), do: false

  defp session_aliases?(v) do
    endpoint_valid = endpoint?(v.config)
    dropped = exact?(v.config, [:limits]) and (v.config.limits == nil or limits?(v.config.limits))

    if endpoint_valid or dropped do
      group = if endpoint_valid, do: v.config.group, else: selected_group(v.selection)

      (group == nil or group?(group)) and group_selection?(v.selection, group) and
        (v.selector == nil or (group != nil and group_selector?(v.selector, group))) and
        (not endpoint_valid or group === v.config.group) and
        awaiting?(v.awaiting_transport, group) and
        transport_selection?(v.transport_selection, group) and
        state_pins?(v.transport_pins, v.transport_selection) and
        checked_alias?(v.managed_transport, v.transport_selection, v.awaiting_transport)
    else
      false
    end
  end

  defp selected_group({group, _}), do: group
  defp selected_group(_), do: nil
  defp group_selection?(nil, _), do: true
  defp group_selection?({group, token}, group), do: group?(group) and ref?(token)
  defp group_selection?(_, _), do: false
  defp awaiting?(nil, _), do: true

  defp awaiting?(%{handle: t, member: member} = v, group),
    do:
      exact?(v, [:handle, :member]) and
        group != nil and selected?(member) and transport?(t) and member.config.transport === t and
        t in group.transports

  defp awaiting?(_, _), do: false
  defp transport_selection?(nil, _), do: true

  defp transport_selection?({t, token}, group),
    do:
      transport?(t) and ref?(token) and
        (group == nil or t in group.transports)

  defp transport_selection?(_, _), do: false

  defp state_pins?(pins, selection) do
    list?(pins, 1, &(pin?(&1) and &1.provider == UpstreamTransports and &1.kind == :request)) and
      case selection do
        nil -> true
        {t, _} -> captures_for?(pins, t) and Enum.all?(pins, &(&1.handles === [t]))
      end
  end

  defp checked_alias?(nil, _, _), do: true
  defp checked_alias?(checked, {_t, token}, nil), do: ref?(token) and checked?(checked)
  defp checked_alias?(_, _, _), do: false
  defp request_slot?(nil), do: true
  defp request_slot?({:group_prepared, options}), do: options?(options)
  defp request_slot?(neutral), do: ManagedH2Envelope.validate_group_source(neutral) == :ok

  defp session_staged?(%{request_options: {:group_prepared, o}} = v) do
    exact?(v.config, [:limits]) and limits?(v.config.limits) and v.selector == nil and
      v.awaiting_transport == nil and v.transport_handoff == nil and v.managed_transport == nil and
      v.request == nil and v.original_request == nil and v.submitted_url == nil and
      v.selection != nil and v.transport_selection != nil and o.deadline === v.deadline and
      o.opening_deadline === v.opening_deadline and o.timeout <= v.config.limits.max_lifetime and
      o.opening_timeout <= v.config.limits.opening_timeout and
      o.write_timeout == v.config.limits.write_timeout and
      o.request.max_upload_bytes <= v.config.limits.max_chunk_bytes and
      byte_size(URI.parse(o.request.url).scheme) + 3 +
        byte_size(URI.parse(o.request.url).authority) <= elem(v.selection, 0).max_url_bytes
  end

  defp session_staged?(_), do: true
  defp handle_aliases?(nil, _), do: true
  defp handle_aliases?(_, nil), do: true

  defp handle_aliases?(a, b),
    do: a.completion === b.completion and a.promise.task.ref === b.promise.task.ref

  defp url_slot?(nil), do: true
  defp url_slot?(v), do: binary?(v, 65_536, true) and byte_size(v) > 0
  defp url_projection(nil), do: nil
  defp url_projection(_), do: {:slot, :session_request_url}
  defp request_projection(nil), do: nil
  defp request_projection({:group_prepared, o}), do: {:group_prepared, options_projection(o)}
  defp request_projection(v), do: v

  defp session_projection(v),
    do: %{
      v
      | managed_transport: optional_checked_projection(v.managed_transport),
        request_options: request_projection(v.request_options),
        request: handle_projection(v.request),
        original_request: handle_projection(v.original_request),
        submitted_url: url_projection(v.submitted_url),
        trailers: {:slot, :terminal_trailer_lists}
    }

  defp probe?(v) do
    exact?(v, @probe_keys) and pid?(v.owner) and ref?(v.token) and time?(v.deadline) and
      time?(v.cleanup_deadline) and v.cleanup_deadline == v.deadline + 1_000 and
      ref?(v.owner_monitor) and ref?(v.timer) and
      Enum.all?([v.terminal, v.cancelled, v.headers], &is_boolean/1) and
      v.outcome in [:failure, :success, :cancelled] and v.client == ManagedH2Client and
      limits?(v.limits) and optional_handle?(v.request) and optional_handle?(v.original_request) and
      handle_aliases?(v.request, v.original_request) and url_slot?(v.submitted_url) and
      optional_checked?(v.managed_transport) and request_slot?(v.request_options) and
      probe_payload?(v) and transport_selection?(v.transport_selection, v.group) and
      state_pins?(v.transport_pins, v.transport_selection)
  end

  defp probe_payload?(%{member: nil, group: nil, health: nil, url: nil} = v) do
    v.managed_transport == nil and
      case v.request_options do
        nil ->
          true

        {:group_prepared, o} ->
          v.submitted_url == nil and o.request.method == :head and o.request.fields == [] and
            o.request.body_mode == :none and o.request.max_upload_bytes == 1 and
            o.deadline === v.deadline and o.opening_deadline === v.deadline and
            o.timeout <= v.limits.max_lifetime and o.opening_timeout <= v.limits.opening_timeout and
            o.write_timeout == v.limits.write_timeout

        _ ->
          false
      end
  end

  defp probe_payload?(v),
    do:
      probe_args?(Map.take(v, @probe_args)) and v.limits === v.member.config.limits and
        checked_alias?(v.managed_transport, v.transport_selection, nil)

  defp probe_projection(v),
    do: %{
      v
      | managed_transport: optional_checked_projection(v.managed_transport),
        request_options: request_projection(v.request_options),
        request: handle_projection(v.request),
        original_request: handle_projection(v.original_request),
        submitted_url: url_projection(v.submitted_url)
    }

  defp fields?(v, max, cap), do: fields?(v, max, cap, 0, 0, 0)
  defp fields?([], _, _, _, _, _), do: true

  defp fields?([{name, value} | rest], max, cap, count, logical, backing)
       when count < max and is_binary(name) and is_binary(value) do
    size = byte_size(name) + byte_size(value)
    retained = :binary.referenced_byte_size(name) + :binary.referenced_byte_size(value)

    size <= cap and retained <= cap and logical + size <= cap and backing + retained <= cap and
      byte_size(name) > 0 and Gaoxy.HTTP.RendererBounds.fields([{name, value}], 1, cap) == :ok and
      fields?(rest, max, cap, count + 1, logical + size, backing + retained)
  end

  defp fields?(_, _, _, _, _, _), do: false

  defp pump?(v) do
    exact?(v, @pump_keys) and endpoint?(v.config) and v.client == ManagedH2Client and
      pump_identities?(v.session, v.monitor) and time?(v.deadline) and time?(v.last_activity) and
      optional_pid?(v.upload) and is_boolean(v.ready) and is_boolean(v.upload_stopped) and
      policy?(v.policy) and policy?(v.response_policy) and exchange?(v.exchange) and
      handoff?(v.transport_handoff, v.config.group, v.exchange.resource_pins)
  end

  defp pump_identities?(nil, nil), do: true
  defp pump_identities?(pid, monitor), do: pid?(pid) and ref?(monitor)
  defp policy?(nil), do: true
  defp policy?(v), do: ManagedH2Envelope.validate_trailer_policy(v) == :ok
  defp policy_projection(nil), do: nil
  defp policy_projection(_), do: {:slot, :trailer_policies}
  defp handoff?(nil, _, _), do: true

  defp handoff?(v, group, pins),
    do:
      exact?(v, [:ref, :handles, :source_pins, :used]) and
        ref?(v.ref) and is_boolean(v.used) and v.handles === group.transports and
        captures?(v.source_pins) and
        v.source_pins === Enum.filter(pins, &(&1.provider == UpstreamTransports))

  defp pump_projection(v),
    do: %{
      v
      | exchange: exchange_projection(v.exchange),
        policy: policy_projection(v.policy),
        response_policy: policy_projection(v.response_policy)
    }

  defp exchange?(v) do
    is_struct(v, Exchange) and exact?(v, @exchange_keys) and native_request?(v.request) and
      native_body?(v.body) and binary?(v.buffer, 65_536) and captures?(v.resource_pins) and
      Enum.all?([v.gate, v.service, v.instance], &pid?/1) and ref?(v.lease) and time?(v.deadline) and
      native_limits?(v.limits) and endpoint_address?(v.peer) and endpoint_address?(v.local) and
      response_state?(v.response) and names?(v.response_trailers, 128, 65_536) and
      is_boolean(v.close) and is_boolean(v.expect_sent) and
      Enum.all?([v.route_bytes, v.protocol_bytes, v.poll_buffer_bytes], &unsigned?/1) and
      v.secure in [nil, true, false] and native_socket?(v.socket) and tls_metadata?(v.ssl) and
      (v.peer_cert == nil or binary?(v.peer_cert, 1_048_576)) and
      native_transport?(v.transport, v.transport_state)
  end

  defp native_request?(v),
    do:
      is_struct(v, Request) and exact?(v, @native_request_keys) and
        binary?(v.method, 16) and byte_size(v.method) > 0 and
        Enum.all?(
          [v.target, v.path, v.query_string, v.host],
          &(is_nil(&1) or binary?(&1, 65_536))
        ) and
        v.target_form in [:origin, :absolute] and
        v.version in [:"HTTP/1.0", :"HTTP/1.1", :"HTTP/2", :"HTTP/3"] and
        (v.port == nil or integer_range?(v.port, 1, 65_535)) and
        v.scheme in [nil, :http, :https, "http", "https"] and
        fields?(v.headers, 512, 131_072) and body_mode?(v.body) and is_boolean(v.keep_alive) and
        is_boolean(v.expect_continue) and unsigned?(v.head_bytes) and
        (v.peer == nil or endpoint_address?(v.peer)) and
        (v.local == nil or endpoint_address?(v.local))

  defp native_body?(%Gaoxy.HTTP.HTTP1.Body{} = v),
    do:
      exact?(v, [:__struct__, :phase, :total, :trailers, :trailer_bytes, :limits]) and
        native_phase?(v.phase) and unsigned?(v.total) and unsigned?(v.trailer_bytes) and
        fields?(v.trailers, 256, 131_072) and native_body_limits?(v.limits)

  defp native_body?(v),
    do:
      exact?(v, [:phase, :total, :trailers, :trailer_bytes]) and
        v.phase in [:done, :data] and unsigned?(v.total) and unsigned?(v.trailer_bytes) and
        fields?(v.trailers, 256, 131_072)

  defp native_body_limits?(v),
    do:
      is_map(v) and map_size(v) <= 14 and
        Enum.all?(v, fn {k, n} -> k in @native_limits and unsigned?(n) end)

  defp native_limits?(v),
    do:
      is_map(v) and map_size(v) in [13, 14] and
        Enum.all?(v, fn {k, n} ->
          k in @native_limits and is_integer(n) and n > 0 and n <= @uint
        end)

  defp native_phase?(v) when v in [:done, :chunk_size, :chunk_crlf, :trailers], do: true
  defp native_phase?({kind, n}), do: kind in [:length, :chunk_data] and unsigned?(n)
  defp native_phase?(_), do: false
  defp body_mode?(v) when v in [:none, :chunked], do: true
  defp body_mode?({:length, n}), do: unsigned?(n)
  defp body_mode?(_), do: false

  defp endpoint_address?({address, port}),
    do: address?(address) and integer_range?(port, 0, 65_535)

  defp endpoint_address?(_), do: false

  defp address?(v) when is_tuple(v) and tuple_size(v) in [4, 8] do
    max = if tuple_size(v) == 4, do: 255, else: 65_535
    Enum.all?(Tuple.to_list(v), &integer_range?(&1, 0, max))
  end

  defp address?(_), do: false

  defp response_state?(v) when v in [:unset, :sent, :chunked, :bodyless_stream, :close_stream],
    do: true

  defp response_state?({:fixed_stream, n}), do: unsigned?(n)
  defp response_state?(_), do: false
  defp names?(v, max, cap), do: names?(v, max, cap, 0, 0, 0)
  defp names?([], _, _, _, _, _), do: true

  defp names?([name | rest], max, cap, count, logical, backing)
       when count < max and is_binary(name) do
    size = byte_size(name)
    retained = :binary.referenced_byte_size(name)

    size > 0 and logical + size <= cap and backing + retained <= cap and
      names?(rest, max, cap, count + 1, logical + size, backing + retained)
  end

  defp names?(_, _, _, _, _, _), do: false
  defp native_socket?(nil), do: true

  defp native_socket?(%Hell.Socket{} = v),
    do: exact?(v, Map.keys(Hell.Socket.__struct__()))

  defp native_socket?(_), do: false
  defp tls_metadata?(nil), do: true
  defp tls_metadata?(v), do: finite_native?(v, 0, 128)
  # Only native Exchange's named, already leased TLS metadata field uses this
  # bounded public scalar grammar. It is not an arbitrary-term projection API.
  defp finite_native?(_, depth, _) when depth > 6, do: false
  defp finite_native?(v, _, _) when is_binary(v), do: binary?(v, 65_536)
  defp finite_native?(v, _, _) when is_integer(v), do: unsigned?(v)

  defp finite_native?(v, _, _) when is_atom(v),
    do:
      v in [
        nil,
        true,
        false,
        :tlsv1,
        :tlsv1_1,
        :tlsv1_2,
        :tlsv1_3,
        :"tlsv1.1",
        :"tlsv1.2",
        :"tlsv1.3",
        :session_resumption,
        :srp_username,
        :protocol,
        :selected_cipher_suite,
        :cipher,
        :key_exchange,
        :mac,
        :prf,
        :aes_128_gcm,
        :aes_256_gcm,
        :chacha20_poly1305,
        :any,
        :aead,
        :sha256,
        :sha384,
        :null,
        :ecdhe_rsa,
        :ecdhe_ecdsa,
        :rsa_pss_rsae_sha256,
        :rsa_pss_rsae_sha384,
        :rsa_pkcs1_sha256,
        :signature_algs,
        :ecc,
        :secp256r1,
        :x25519,
        :session_id,
        :sni_hostname
      ]

  defp finite_native?(v, depth, nodes) when is_list(v),
    do: list?(v, min(nodes, 64), &finite_native?(&1, depth + 1, div(nodes, 2)))

  defp finite_native?(v, depth, nodes) when is_tuple(v) and tuple_size(v) <= 8,
    do: Enum.all?(Tuple.to_list(v), &finite_native?(&1, depth + 1, div(nodes, 2)))

  defp finite_native?(v, depth, nodes) when is_map(v) and map_size(v) <= 8,
    do:
      Enum.all?(v, fn {k, x} ->
        finite_native?(k, depth + 1, div(nodes, 2)) and
          finite_native?(x, depth + 1, div(nodes, 2))
      end)

  defp finite_native?(_, _, _), do: false
  defp native_transport?(nil, nil), do: true

  defp native_transport?(Gaoxy.HTTP.HTTP2.Transport, {pid, id, token}),
    do: pid?(pid) and integer_range?(id, 1, 2_147_483_647) and ref?(token)

  defp native_transport?(_, _), do: false

  defp exchange_projection(v),
    do: %{
      v
      | request: {:slot, :native_request},
        body: body_projection(v.body),
        buffer: {:slot, :native_read_buffer},
        response_trailers: {:slot, :downstream_declaration_names},
        socket: socket_projection(v.socket),
        ssl: tls_projection(v.ssl),
        peer_cert: cert_projection(v.peer_cert)
    }

  defp body_projection(v), do: %{v | trailers: {:slot, :native_request_trailers}}
  defp socket_projection(nil), do: nil
  defp socket_projection(_), do: {:opaque, :native_socket_lease}
  defp tls_projection(nil), do: nil
  defp tls_projection(_), do: {:slot, :native_tls_lease}
  defp cert_projection(nil), do: nil
  defp cert_projection(_), do: {:slot, :native_certificate_lease}

  defp raw_root(c), do: c.uri.scheme <> "://" <> c.uri.authority

  defp group_record?(v) do
    exact?(v, [:compiled, :members, :cursor, :inflight, :lifecycle, :bytes, :handle]) and
      is_struct(v.compiled, Options) and
      exact?(v.compiled, [:__struct__, :id, :members, :health, :max_inflight]) and
      id?(v.compiled.id) and health?(v.compiled.health) and
      integer_range?(v.compiled.max_inflight, 1, 1_024) and
      list?(v.compiled.members, 32, &selected?/1) and nonempty?(v.compiled.members) and
      group?(v.handle) and v.handle.group === v.compiled.id and
      list?(v.members, 32, &runtime_member?(&1, v.compiled.health)) and
      length(v.members) == length(v.compiled.members) and
      Enum.all?(Enum.zip(v.members, v.compiled.members), fn {runtime, compiled} ->
        Map.take(runtime, [:id, :config, :max_inflight]) === compiled
      end) and
      Enum.uniq(Enum.map(v.compiled.members, & &1.id)) == Enum.map(v.compiled.members, & &1.id) and
      length(Enum.uniq(Enum.map(v.compiled.members, & &1.config.upstream_protocol))) == 1 and
      Enum.uniq(Enum.map(v.compiled.members, & &1.config.transport)) === v.handle.transports and
      Enum.all?(v.compiled.members, &(byte_size(raw_root(&1.config)) <= v.handle.max_url_bytes)) and
      integer_range?(v.cursor, 0, length(v.members) - 1) and
      integer_range?(v.inflight, 0, v.compiled.max_inflight) and
      v.inflight == Enum.sum(Enum.map(v.members, & &1.inflight)) and
      v.lifecycle in [:active, :retiring, :failed]
  end

  defp runtime_member?(v, health) do
    exact?(v, [
      :id,
      :config,
      :max_inflight,
      :health,
      :checked,
      :failures,
      :successes,
      :inflight,
      :probe,
      :due
    ]) and
      selected?(Map.take(v, [:id, :config, :max_inflight])) and
      v.health in [:unknown, :healthy, :unhealthy] and
      optional_time?(v.checked) and time?(v.due) and
      integer_range?(v.failures, 0, health.failure_threshold) and
      integer_range?(v.successes, 0, health.recovery_threshold) and
      integer_range?(v.inflight, 0, v.max_inflight) and
      optional_ref?(v.probe)
  end

  defp control_record?(kind, v, mode) when is_map(v) do
    cap = @control_caps[kind]
    self_valid = not Map.has_key?(v, :control_bytes) or integer_range?(v.control_bytes, 0, cap)
    record = Map.delete(v, :control_bytes)
    self_valid and control_body?(kind, record, mode)
  end

  defp control_record?(_, _, _), do: false

  defp group_key?({id, generation}),
    do: is_binary(id) and byte_size(id) in 1..128 and ref?(generation)

  defp group_key?(_), do: false

  defp control_body?(:pin, v, mode) do
    keys = if mode == :complete, do: @pin_record, else: @pin_record -- [:monitor, :timer]

    exact?(v, keys) and list?(v.keys, 64, &group_key?/1) and nonempty?(v.keys) and
      pid?(v.holder) and pid?(v.acquirer) and ref?(v.operation) and
      v.kind in [:baseline, :preparation, :request] and
      if(v.kind == :baseline, do: v.deadline == nil, else: time?(v.deadline)) and
      (mode != :complete or
         (ref?(v.monitor) and
            if v.kind == :baseline, do: v.timer == nil, else: ref?(v.timer)))
  end

  defp control_body?(kind, v, mode) when kind in [:selection, :probe] do
    base = if kind == :selection, do: @selection_record, else: @probe_record
    complete = exact?(v, base) or exact?(v, base ++ [:recovery_monitor])
    normal_pending = if kind == :selection, do: base -- [:monitor], else: base -- [:pid, :monitor]
    recovery_pending = base -- [:recovery]

    shape =
      if mode == :complete,
        do: complete,
        else: exact?(v, normal_pending) or exact?(v, recovery_pending)

    shape and group_key?(v.key) and integer_range?(v.index, 0, 31) and time?(v.deadline) and
      (Map.get(v, :completion) == nil or completion?(v.completion)) and
      (kind != :selection or pid?(v.guardian)) and
      (kind != :probe or
         (v.bytes == reservation_bytes() and is_boolean(v.claimed) and
            (not Map.has_key?(v, :pid) or pid?(v.pid)))) and
      control_identities?(v, mode)
  end

  defp control_identities?(v, :complete) do
    optional_ref?(v.monitor) and
      if Map.has_key?(v, :recovery_monitor),
        do:
          pid?(v.recovery) and ref?(v.recovery_monitor) and v.monitor == nil and
            completion?(v.completion),
        else: Map.get(v, :recovery) == nil
  end

  defp control_identities?(v, :provisional) do
    (not Map.has_key?(v, :monitor) or v.monitor == nil) and
      (not Map.has_key?(v, :recovery) or v.recovery == nil) and
      (not Map.has_key?(v, :claimed) or v.claimed == false or completion?(v.completion))
  end

  defp control_projection(v) do
    if Map.has_key?(v, :completion) and v.completion != nil, do: completion_projection(v), else: v
  end

  defp owner_call(owner, op, {:"$gen_call", {pid, tag}, request}) do
    with true <- pid?(pid) and call_tag?(tag),
         {:ok, safe} <- owner_call(owner, op, request) do
      {:ok, {:"$gen_call", {pid, tag}, safe}}
    else
      _ -> :error
    end
  end

  defp owner_call(owner, :pin, {tag, handles, holder, kind, operation, deadline} = v) do
    expected = if owner == :group, do: :pin, else: :pin_many

    if tag == expected and manifest?(handles) and nonempty?(handles) and pid?(holder) and
         kind in [:baseline, :preparation, :request] and ref?(operation) and time?(deadline) and
         provider_batch?(owner, handles),
       do: {:ok, v},
       else: :error
  end

  defp owner_call(owner, :release, {:release, pin} = v),
    do: if(pin?(pin) and provider?(owner, pin.provider), do: {:ok, v}, else: :error)

  defp owner_call(:group, :checkout, {:checkout, group, pins, guardian, context, deadline} = v),
    do:
      if(
        group?(group) and captures_for?(pins, group) and pid?(guardian) and context == %{} and
          time?(deadline),
        do: {:ok, v},
        else: :error
      )

  defp owner_call(:transport, :checkout, {:checkout, t, pins, guardian, deadline} = v),
    do:
      if(transport?(t) and captures_for?(pins, t) and pid?(guardian) and time?(deadline),
        do: {:ok, v},
        else: :error
      )

  defp owner_call(owner, :bind, {tag, h, token, completion}) do
    expected = if owner == :group, do: :bind, else: :bind_completion

    if tag == expected and owner_handle?(owner, h) and ref?(token) and completion?(completion),
      do: {:ok, {tag, h, token, {:opaque, HTTP.RequestCompletion}}},
      else: :error
  end

  defp owner_call(:group, :finish, {:finish, group, token, outcome} = v),
    do:
      if(group?(group) and ref?(token) and outcome in [:success, :cancelled, :upstream_failure],
        do: {:ok, v},
        else: :error
      )

  defp owner_call(:transport, :finish, {:finish, t, token} = v),
    do: if(transport?(t) and ref?(token), do: {:ok, v}, else: :error)

  defp owner_call(
         :transport,
         :delegate,
         {:delegate_request_pin, t, pin, guardian, authority, instance, operation, deadline} = v
       ),
       do:
         if(
           transport?(t) and pin?(pin) and t in pin.handles and pid?(guardian) and
             authority?(authority) and
             pid?(instance) and ref?(operation) and time?(deadline),
           do: {:ok, v},
           else: :error
         )

  defp owner_call(_, _, _), do: :error

  defp owner_reply(owner, op, {tag, reply}) when is_reference(tag) or is_list(tag) do
    with true <- call_tag?(tag),
         {:ok, safe} <- owner_reply(owner, op, reply) do
      {:ok, {tag, safe}}
    else
      _ -> :error
    end
  end

  defp owner_reply(owner, :pin, {:ok, pins} = v) when is_list(pins),
    do:
      if(captures?(pins) and Enum.all?(pins, &provider?(owner, &1.provider)),
        do: {:ok, v},
        else: :error
      )

  defp owner_reply(owner, :pin, {:ok, pin} = v),
    do: if(pin?(pin) and provider?(owner, pin.provider), do: {:ok, v}, else: :error)

  defp owner_reply(:group, :prepare, {:ok, group, pins} = v),
    do: if(group?(group) and captures?(pins), do: {:ok, v}, else: :error)

  defp owner_reply(_, op, :ok) when op in [:bind, :finish, :release], do: {:ok, :ok}

  defp owner_reply(_, _, {:error, reason} = v),
    do: if(reason?(reason), do: {:ok, v}, else: :error)

  defp owner_reply(_, _, _), do: :error
  defp provider?(:group, UpstreamGroups), do: true
  defp provider?(:transport, UpstreamTransports), do: true
  defp provider?(_, _), do: false
  defp owner_handle?(:group, h), do: group?(h)
  defp owner_handle?(:transport, h), do: transport?(h)

  defp provider_batch?(owner, handles),
    do:
      Enum.all?(handles, &provider?(owner, &1.provider)) and
        length(Enum.uniq(Enum.map(handles, & &1.owner))) == 1

  defp authority?({protocol, scheme, host, port}),
    do:
      protocol in [:http2, :h2c] and
        scheme in [:http, :https] and binary?(host, 253, true) and byte_size(host) > 0 and
        integer_range?(port, 1, 65_535) and
        ((protocol == :http2 and scheme == :https) or (protocol == :h2c and scheme == :http))

  defp authority?(_), do: false

  # The closed envelope family has one current source slot per transition.
  # Unknown mailbox messages are not measured or claimed bounded by this API.
  defp control(:activate, {:gaoxy_cleanup_activate, token} = v),
    do: control_value(v, ref?(token), 2_048)

  defp control(:cleanup_cancel, {:gaoxy_cleanup_cancel, token, reason, deadline}),
    do:
      control_value(
        {:gaoxy_cleanup_cancel, token, normalized_reason(reason), deadline},
        ref?(token) and time?(deadline),
        2_048
      )

  defp control(:handoff, {:gaoxy_transport_handoff, ref, {:ok, pin}, deadline}),
    do:
      control_value(
        {:gaoxy_transport_handoff, ref, {:ok, {:slot, :i}}, deadline},
        ref?(ref) and pin?(pin) and provider?(:transport, pin.provider) and time?(deadline),
        2_048
      )

  defp control(:handoff, {:gaoxy_transport_handoff, ref, {:error, reason}, deadline}),
    do:
      control_value(
        {:gaoxy_transport_handoff, ref, {:error, normalized_reason(reason)}, deadline},
        ref?(ref) and time?(deadline),
        2_048
      )

  defp control(:down, {:DOWN, ref, :process, pid, reason}),
    do:
      control_value(
        {:DOWN, ref, :process, pid, normalized_reason(reason)},
        ref?(ref) and pid?(pid),
        2_048
      )

  defp control(:timer, v) when v in [:opening_expired, :total_expired, :poll, :expired],
    do: {:ok, v, 2_048}

  defp control(:timer, {ref, result} = v),
    do:
      control_value(
        v,
        ref?(ref) and
          (result == false or (is_integer(result) and result >= 0 and result <= @max)),
        2_048
      )

  defp control(:cast, {:"$gen_cast", op} = v) when op in [:cancel, :expire, :consumed],
    do: {:ok, v, 2_048}

  defp control(:acknowledge, {:"$gen_cast", {:acknowledge, ref}} = v),
    do: control_value(v, ref?(ref), 2_048)

  defp control(:acknowledge, {:read_chunk, pid, :ack} = v),
    do: control_value(v, pid?(pid), 2_048)

  defp control(:acknowledge, {:stream_chunk_ack, ref} = v),
    do: control_value(v, ref?(ref), 2_048)

  defp control(:task, {ref, {:error, reason}}),
    do: control_value({ref, {:error, normalized_reason(reason)}}, ref?(ref), 2_048)

  defp control({:task, submitted}, {ref, %HTTP.Response{} = response}) do
    valid =
      ref?(ref) and binary?(submitted, 65_536, true) and
        match?({:ok, _}, ManagedH2Envelope.validate_response(response, submitted))

    control_value({ref, {:slot, :extra_public_metadata_and_response_heads}}, valid, 2_048)
  end

  defp control(:data, {:stream_chunk, pid, bytes, ref}),
    do:
      control_value(
        {:stream_chunk, pid, {:slot, :data_event}, ref},
        pid?(pid) and ref?(ref) and binary?(bytes, 1_048_576),
        2_048
      )

  defp control(:trailers, {:stream_trailers, pid, %HTTP.Headers{} = headers}) do
    valid =
      exact?(headers, [:__struct__, :headers]) and pid?(pid) and
        fields?(headers.headers, 128, 65_536)

    control_value(
      {:stream_trailers, pid, %{headers | headers: {:slot, :terminal_trailer_lists}}},
      valid,
      2_048
    )
  end

  defp control(:stream_end, {:stream_end, pid} = v), do: control_value(v, pid?(pid), 2_048)

  defp control(:stream_error, {:stream_error, pid, reason}),
    do: control_value({:stream_error, pid, normalized_reason(reason)}, pid?(pid), 2_048)

  defp control(:ready, {:gaoxy_proxy_http, pid, {:ready, upload, limits, deadline}} = v),
    do:
      control_value(
        v,
        pid?(pid) and optional_pid?(upload) and limits?(limits) and time?(deadline),
        2_048
      )

  defp control(
         :handoff_request,
         {:gaoxy_proxy_http, pid, {:transport_handoff, ref, t, identity, deadline}}
       ) do
    valid = pid?(pid) and ref?(ref) and transport?(t) and identity?(identity) and time?(deadline)
    safe_identity = if valid, do: %{identity | origin: {:slot, :fixed_configs}}, else: nil

    control_value(
      {:gaoxy_proxy_http, pid, {:transport_handoff, ref, t, safe_identity, deadline}},
      valid,
      2_048
    )
  end

  defp control(:delivery, {:gaoxy_proxy_http, pid, {:headers, status, fields}}),
    do:
      control_value(
        {:gaoxy_proxy_http, pid, {:headers, status, {:slot, :response_heads}}},
        pid?(pid) and integer_range?(status, 200, 599) and fields?(fields, 256, 65_536),
        2_048
      )

  defp control(:delivery, {:gaoxy_proxy_http, pid, {:chunk, bytes, ref}}),
    do:
      control_value(
        {:gaoxy_proxy_http, pid, {:chunk, {:slot, :data_event}, ref}},
        pid?(pid) and ref?(ref) and binary?(bytes, 1_048_576),
        2_048
      )

  defp control(:delivery, {:gaoxy_proxy_http, pid, {:end, fields}}),
    do:
      control_value(
        {:gaoxy_proxy_http, pid, {:end, {:slot, :terminal_trailer_lists}}},
        pid?(pid) and fields?(fields, 128, 65_536),
        2_048
      )

  defp control(:delivery, {:gaoxy_proxy_http, pid, {:error, reason}}),
    do:
      control_value(
        {:gaoxy_proxy_http, pid, {:error, normalized_reason(reason)}},
        pid?(pid),
        2_048
      )

  defp control(:drain, {:gaoxy_drain, gate, lease, deadline} = v),
    do: control_value(v, pid?(gate) and ref?(lease) and time?(deadline), 2_048)

  defp control(
         :identity,
         {:gaoxy_proxy_http, pid, {:transport_handoff, ref, t, identity, deadline}} = v
       ),
       do:
         control_value(
           v,
           pid?(pid) and ref?(ref) and transport?(t) and identity?(identity) and time?(deadline),
           24_576
         )

  defp control(:identity, {:validate_endpoint, t, authority, instance, deadline} = v),
    do:
      control_value(
        v,
        transport?(t) and authority?(authority) and pid?(instance) and time?(deadline),
        24_576
      )

  defp control(:admission, {:"$gen_call", {pid, tag}, request}) do
    with true <- pid?(pid) and call_tag?(tag) and admission_request?(request),
         {:ok, safe, _} <- control(:admission, request) do
      {:ok, {:"$gen_call", {pid, tag}, safe}, 24_576}
    else
      _ -> :error
    end
  end

  defp control(:admission, {tag, reply}) when is_reference(tag) or is_list(tag) do
    with true <- call_tag?(tag),
         true <- reply == :ok or match?({:ok, _}, reply) or match?({:error, _}, reply),
         {:ok, safe, _} <- control(:admission, reply) do
      {:ok, {tag, safe}, 24_576}
    else
      _ -> :error
    end
  end

  defp control(:admission, {:complete_cleanup, token} = v),
    do: control_value(v, ref?(token), 24_576)

  defp control(:admission, {:error, reason}),
    do: {:ok, {:error, normalized_reason(reason)}, 24_576}

  defp control(:admission, {:adjust_bytes, lease, delta} = v),
    do: control_value(v, ref?(lease) and time?(delta), 24_576)

  defp control(:admission, {:attach_cleanup, gate, lease, guardian, bytes, deadline} = v),
    do:
      control_value(
        v,
        pid?(gate) and ref?(lease) and pid?(guardian) and unsigned?(bytes) and time?(deadline),
        24_576
      )

  defp control(:admission, {:attach_cleanup, owner, lease, guardian, bytes, deadline, token} = v),
    do:
      control_value(
        v,
        pid?(owner) and ref?(lease) and pid?(guardian) and unsigned?(bytes) and time?(deadline) and
          ref?(token),
        24_576
      )

  defp control(:admission, {:ok, token} = v), do: control_value(v, ref?(token), 24_576)
  defp control(:admission, :ok), do: {:ok, :ok, 24_576}

  defp control(:admission, {:gaoxy_cleanup_activate, token} = v),
    do: control_value(v, ref?(token), 24_576)

  defp control(:owner, {:cancel_pins, holder, operation} = v),
    do: control_value(v, pid?(holder) and ref?(operation), 24_576)

  defp control(:owner, {:"$gen_cast", {:cancel, operation}} = v),
    do: control_value(v, ref?(operation), 24_576)

  defp control(:owner, {:"$gen_call", {pid, tag}, request}) do
    valid = pid?(pid) and call_tag?(tag) and valid_owner_request?(request)
    control_value({:"$gen_call", {pid, tag}, {:slot, :i}}, valid, 24_576)
  end

  defp control(:owner, {tag, {:ok, selected, token}}) do
    cond do
      call_tag?(tag) and ref?(token) and selected?(selected) ->
        {:ok, {tag, {:ok, {:slot, :l}, token}}, 24_576}

      call_tag?(tag) and ref?(token) and checked?(selected) ->
        {:ok, {tag, {:ok, {:slot, :k}, token}}, 24_576}

      true ->
        :error
    end
  end

  defp control(:owner, {tag, result}) when is_reference(tag) or is_list(tag),
    do:
      control_value(
        {tag, result},
        call_tag?(tag) and
          (result == :ok or (match?({:error, _}, result) and reason?(elem(result, 1)))),
        24_576
      )

  defp control(:probe, {:claim_probe, token, deadline} = v),
    do: control_value(v, ref?(token) and time?(deadline), 24_576)

  defp control(:probe, {:claim_probe, token, group, deadline} = v),
    do: control_value(v, ref?(token) and group?(group) and time?(deadline), 24_576)

  defp control(:probe, {:bind_probe, token, completion}),
    do:
      control_value(
        {:bind_probe, token, {:opaque, HTTP.RequestCompletion}},
        ref?(token) and completion?(completion),
        24_576
      )

  defp control(:probe, {:probe_finished, token, outcome} = v),
    do: control_value(v, ref?(token) and outcome in [:success, :failure, :cancelled], 24_576)

  defp control(:probe, {:recovered, kind, token, pid, result} = v),
    do:
      control_value(
        v,
        kind in [:selection, :probe] and ref?(token) and pid?(pid) and
          (result == :ok or (match?({:error, _}, result) and reason?(elem(result, 1)))),
        24_576
      )

  defp control(:probe, {:ok, pid} = v), do: control_value(v, pid?(pid), 24_576)
  defp control(_, _), do: :error
  defp control_value(safe, true, cap), do: {:ok, safe, cap}
  defp control_value(_, _, _), do: :error

  defp identity?(v),
    do:
      exact?(v, [:origin, :upstream_protocol, :instance]) and
        binary?(v.origin, 8_192, true) and byte_size(v.origin) > 0 and pid?(v.instance) and
        v.upstream_protocol in [:http2, :h2c] and identity_origin?(v.origin, v.upstream_protocol)

  defp identity_origin?(origin, protocol) do
    uri = URI.parse(origin)

    uri.scheme == if(protocol == :http2, do: "https", else: "http") and
      is_binary(uri.host) and byte_size(uri.host) in 1..253 and uri.userinfo == nil and
      uri.path in [nil, "", "/"] and uri.query == nil and uri.fragment == nil and
      integer_range?(uri.port, 1, 65_535)
  end

  defp admission_request?(request)
       when is_tuple(request) and tuple_size(request) > 0 do
    elem(request, 0) in [:adjust_bytes, :attach_cleanup, :complete_cleanup] and
      match?({:ok, _, _}, control(:admission, request))
  end

  defp admission_request?(_), do: false

  defp valid_owner_request?(request) do
    Enum.any?([:group, :transport], fn owner ->
      Enum.any?([:pin, :release, :checkout, :bind, :finish, :delegate], fn op ->
        match?({:ok, _}, owner_call(owner, op, request))
      end)
    end)
  end
end
