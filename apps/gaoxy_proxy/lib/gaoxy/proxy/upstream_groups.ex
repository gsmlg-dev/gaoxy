defmodule Gaoxy.Proxy.UpstreamGroups do
  @moduledoc """
  Instance-scoped immutable homogeneous H1/H2 groups with cleanup-held selections.

  Managed members declare their exact transport dependencies in the group handle.
  Preparation acquires dependency pins in the preparer; owners never recursively
  pin providers. Embeddings must acquire a baseline for `resources(handle)` before
  releasing the returned group and transport preparation pins.
  """
  use GenServer
  @behaviour Gaoxy.HTTP.Resources
  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Lifecycle

  alias Gaoxy.Proxy.{
    HTTPFetchClient,
    ManagedH2GroupAccounting,
    UpstreamGroups.Options,
    UpstreamGroups.Probe,
    UpstreamTransports
  }

  @control_limit 16_777_216

  @signed_min -9_223_372_036_854_775_808
  @signed_max 9_223_372_036_854_775_807

  @doc false
  def probe_start_arguments(
        %{
          owner: owner,
          token: token,
          member: member,
          deadline: deadline,
          health: health,
          url: url
        } = args
      )
      when is_pid(owner) and is_reference(token) and is_integer(deadline) and is_binary(url) do
    h2 = probe_group_intent?(member, Map.get(args, :group))

    valid =
      if h2 do
        map_size(args) == 7 and probe_selected?(member, true) and
          probe_health?(health, true) and probe_group_handle?(Map.get(args, :group)) and
          probe_h2_arguments?(args)
      else
        map_size(args) == 6 and probe_selected?(member, false) and probe_health?(health, false)
      end

    if valid, do: {:ok, args}, else: {:error, :invalid_probe_arguments}
  end

  def probe_start_arguments(_), do: {:error, :invalid_probe_arguments}

  @doc false
  def probe_recovery_arguments(
        %{owner: owner, recovery: {kind, token}, completion: completion, deadline: deadline} =
          args
      )
      when map_size(args) == 4 and is_pid(owner) and kind in [:selection, :probe] and
             is_reference(token) and is_integer(deadline) and deadline >= @signed_min and
             deadline <= @signed_max do
    # The public capability is opaque: validate its shell without inspecting,
    # serializing or reconstructing tracker/latch/unsupported interiors.
    case completion do
      %HTTP.RequestCompletion{tracker: _, latch: _, unsupported: _}
      when map_size(completion) == 4 ->
        {:ok, args}

      _ ->
        {:error, :invalid_probe_arguments}
    end
  end

  def probe_recovery_arguments(_), do: {:error, :invalid_probe_arguments}

  defp probe_group_intent?(member, group) do
    match?(%{execution_profile: :managed_h2}, group) or
      match?(%{config: %{upstream_protocol: protocol}} when protocol in [:http2, :h2c], member) or
      match?(%{config: %{client: Gaoxy.Proxy.ManagedH2Client}}, member)
  end

  defp probe_selected?(%{id: id, config: config, max_inflight: max} = member, h2)
       when map_size(member) == 3 and is_binary(id) and byte_size(id) in 1..128 and
              is_integer(max) and max in 1..1_024 do
    if h2,
      do: probe_compact?(id) and Gaoxy.Proxy.ManagedH2Envelope.validate_config(config) == :ok,
      else: probe_h1_config?(config)
  end

  defp probe_selected?(_, _), do: false

  defp probe_h1_config?(
         %Gaoxy.Proxy.HTTP{
           uri: %URI{} = uri,
           upstream_protocol: :http1,
           client: HTTPFetchClient,
           transport: transport,
           limits: limits,
           cacertfile: cert,
           connect_address: address
         } = config
       )
       when map_size(config) == 8 and map_size(uri) == 9 do
    # These are already compiled owner configs. Keep H1's existing structural
    # rules without repeating filesystem/host checks or adding H2 backing caps.
    uri.scheme in ["http", "https"] and is_binary(uri.authority) and
      is_binary(uri.host) and uri.host != "" and
      is_integer(uri.port) and uri.port in 1..65_535 and uri.userinfo == nil and
      uri.path == nil and uri.query == nil and uri.fragment == nil and
      probe_h1_limits?(limits) and (cert == nil or is_binary(cert)) and
      probe_address?(address) and
      (transport == nil or (transport_handle?(transport) and cert == nil and address == nil))
  end

  defp probe_h1_config?(_), do: false

  defp probe_h1_limits?(
         %{
           max_chunk_bytes: chunk,
           opening_timeout: opening,
           idle_timeout: idle,
           write_timeout: write,
           max_lifetime: lifetime
         } = limits
       )
       when map_size(limits) == 5 and is_integer(chunk) and chunk in 1..65_536 and
              is_integer(opening) and opening > 0 and is_integer(idle) and idle > 0 and
              is_integer(write) and write > 0 and is_integer(lifetime) and lifetime > 0,
       do: true

  defp probe_h1_limits?(_), do: false
  defp probe_address?(nil), do: true

  defp probe_address?(address),
    do: Gaoxy.Proxy.DestinationPolicy.normalize_address(address) === {:ok, address}

  defp probe_health?(
         %{
           path: path,
           interval: interval,
           timeout: timeout,
           stale_after: stale,
           failure_threshold: failure,
           recovery_threshold: recovery,
           jitter: jitter
         } = health,
         h2
       )
       when map_size(health) == 7 and is_integer(interval) and interval in 1..3_600_000 and
              is_integer(timeout) and timeout in 1..5_000 and is_integer(stale) and
              stale in 1..3_600_000 and stale >= interval and is_integer(failure) and
              failure in 1..100 and is_integer(recovery) and recovery in 1..100 and
              is_integer(jitter) and jitter in 0..3_600_000 do
    probe_health_path?(path, h2)
  end

  defp probe_health?(_, _), do: false

  defp probe_health_path?("/" <> _ = path, h2) when byte_size(path) <= 8_192 do
    (not h2 or probe_compact?(path)) and
      Enum.all?(:binary.bin_to_list(path), fn char ->
        char in 33..126 and char not in [?#, ?\\] and (not h2 or char != ??)
      end) and not Regex.match?(~r/%(?![0-9a-fA-F]{2})/, path)
  end

  defp probe_health_path?(_, _), do: false

  defp probe_h2_arguments?(args) do
    group = args.group
    config = args.member.config
    root = config.uri.scheme <> "://" <> config.uri.authority
    path = args.health.path

    group.owner === args.owner and config.transport in group.transports and
      args.deadline >= @signed_min and args.deadline <= @signed_max - 1_000 and
      probe_compact?(args.url) and byte_size(root) <= group.max_url_bytes and
      byte_size(root) <= 8_192 and byte_size(root) + byte_size(path) <= 65_536 and
      group.max_url_bytes + byte_size(path) <= 65_536 and args.url === root <> path
  end

  defp probe_compact?(value) when is_binary(value),
    do: :binary.referenced_byte_size(value) == byte_size(value)

  defp probe_group_handle?(
         %{
           provider: __MODULE__,
           owner: owner,
           owner_epoch: epoch,
           group: id,
           generation: generation,
           max_url_bytes: bytes,
           transports: transports,
           execution_profile: :managed_h2
         } = handle
       )
       when map_size(handle) == 8 and is_pid(owner) and is_reference(epoch) and
              is_reference(generation) and is_binary(id) and byte_size(id) in 1..128 and
              is_integer(bytes) and bytes in 1..8_192 do
    probe_compact?(id) and probe_transports?(transports, [], 0) and
      match?({:ok, _}, Resources.validate([handle | transports]))
  end

  defp probe_group_handle?(_), do: false
  defp probe_transports?([], _, count), do: count > 0

  defp probe_transports?([transport | rest], seen, count) when count < 32,
    do:
      transport_handle?(transport) and transport not in seen and
        probe_transports?(rest, [transport | seen], count + 1)

  defp probe_transports?(_, _, _), do: false

  def child_spec(options),
    do: %{id: __MODULE__, start: {__MODULE__, :start_link, [options]}, restart: :temporary}

  def start_link(options) do
    with {:ok, limits} <- Options.owner(options),
         do:
           GenServer.start_link(
             __MODULE__,
             {options[:instance], limits},
             Keyword.take(options, [:name])
           )
  end

  def compile(options), do: Options.compile(options)

  def prepare(owner, %Options{} = group, preparer, deadline) do
    operation = make_ref()

    with {:ok, group} <- compile(group) do
      case member_transports(group) do
        [] -> prepare_group(owner, group, preparer, operation, deadline, [])
        transports -> prepare_managed(owner, group, transports, preparer, operation, deadline)
      end
    end
  end

  def prepare(_, _, _, _), do: {:error, :invalid_upstream_group}

  def instance(owner, deadline) when is_integer(deadline),
    do: Lifecycle.call(owner, {:instance, deadline}, deadline)

  def instance(_, _), do: {:error, :preparation_expired}

  def claim_probe(owner, token, deadline) when is_reference(token) and is_integer(deadline),
    do: Lifecycle.call(owner, {:claim_probe, token, deadline}, deadline)

  def claim_probe(_, _, _), do: {:error, :stale_probe}

  def claim_probe(owner, token, group, deadline)
      when is_reference(token) and is_integer(deadline),
      do: Lifecycle.call(owner, {:claim_probe, token, group, deadline}, deadline)

  def claim_probe(_, _, _, _), do: {:error, :stale_probe}

  defp prepare_managed(owner, group, transports, preparer, operation, deadline) do
    provisional = group_handle(group, self(), make_ref(), make_ref())

    with true <- preparer == self() || {:error, :unauthorized},
         true <-
           (is_integer(deadline) and Lifecycle.remaining(deadline) > 0) ||
             {:error, {:deadline_exceeded, :cleanup_pending}},
         {:ok, _} <- Resources.validate(resources(provisional)),
         {:ok, instance} <- instance(owner, deadline),
         :ok <- validate_members(group, instance, deadline),
         {:ok, pins} <- Resources.pin_many(transports, preparer, :preparation, deadline) do
      prepare_group(owner, group, preparer, operation, deadline, pins)
    else
      {:error, _} = error ->
        cancel(owner, operation)
        error
    end
  end

  defp prepare_group(owner, group, preparer, operation, deadline, transport_pins) do
    result = Lifecycle.call(owner, {:prepare, group, preparer, operation, deadline}, deadline)

    case result do
      {:ok, handle, pins} ->
        if Lifecycle.remaining(deadline) > 0 and Process.alive?(preparer) do
          {:ok, handle, pins ++ transport_pins}
        else
          cancel(owner, operation)
          cancel_transport_pins(transport_pins)
          {:error, {:deadline_exceeded, :cleanup_pending}}
        end

      {:error, _} = error ->
        cancel(owner, operation)
        cancel_transport_pins(transport_pins)
        error
    end
  end

  defp cancel_transport_pins(pins) do
    Enum.each(pins, fn pin ->
      Lifecycle.protect(fn -> pin.provider.cancel(pin.owner, pin.operation) end)
    end)
  end

  defp validate_members(group, instance, deadline) do
    group.members
    |> Enum.reject(&is_nil(&1.config.transport))
    |> Enum.map(&{&1.config.transport, member_origin(&1.config), &1.config.upstream_protocol})
    |> Enum.uniq()
    |> Enum.reduce_while(:ok, fn {transport, origin, protocol}, :ok ->
      identity = %{origin: origin, upstream_protocol: protocol, instance: instance}

      case UpstreamTransports.validate_endpoint(transport, identity, deadline) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp member_transports(group) do
    group.members
    |> Enum.map(& &1.config.transport)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp group_handle(group, owner, epoch, generation) do
    handle = %{
      provider: __MODULE__,
      owner: owner,
      owner_epoch: epoch,
      group: group.id,
      generation: generation,
      max_url_bytes: Enum.max(Enum.map(group.members, &byte_size(member_origin(&1.config))))
    }

    case member_transports(group) do
      [] ->
        handle

      transports ->
        handle = Map.put(handle, :transports, transports)
        if h2_compiled?(group), do: Map.put(handle, :execution_profile, :managed_h2), else: handle
    end
  end

  @impl Gaoxy.HTTP.Resources
  def pin_many([%{owner: owner} | _] = handles, holder, kind, operation, deadline)
      when length(handles) <= 64 and is_pid(holder) and is_reference(operation) and
             is_integer(deadline) do
    if Enum.all?(handles, &(valid_handle?(&1) and &1.owner == owner)),
      do: Lifecycle.call(owner, {:pin, handles, holder, kind, operation, deadline}, deadline),
      else: {:error, :invalid_resource_pin}
  end

  def pin_many(_, _, _, _, _), do: {:error, :invalid_resource_pin}
  @impl Gaoxy.HTTP.Resources
  def release(%{owner: owner} = pin),
    do: Lifecycle.call(owner, {:release, pin}, Lifecycle.deadline(100))

  def release(%{owner: owner} = pin, deadline) when is_pid(owner) and is_integer(deadline) do
    if Lifecycle.remaining(deadline) > 0,
      do: Lifecycle.call(owner, {:release, pin}, deadline),
      else: {:error, :deadline_exceeded}
  end

  def release(_, _), do: {:error, :invalid_resource_pin}

  @impl Gaoxy.HTTP.Resources
  def cancel(owner, operation) do
    send(owner, {:cancel_pin, self(), operation})
    :ok
  end

  def checkout(handle, pins, guardian, context, deadline),
    do:
      Lifecycle.call(
        handle.owner,
        {:checkout, handle, pins, guardian, context, deadline},
        deadline
      )

  def bind_completion(handle, token, completion),
    do: Lifecycle.call(handle.owner, {:bind, handle, token, completion}, Lifecycle.deadline(100))

  def finish(handle, token, outcome),
    do: Lifecycle.call(handle.owner, {:finish, handle, token, outcome}, Lifecycle.deadline(100))

  def status(handle), do: Lifecycle.call(handle.owner, {:status, handle}, Lifecycle.deadline(100))

  def bind_probe(owner, token, completion),
    do: Lifecycle.call(owner, {:bind_probe, token, completion}, Lifecycle.deadline(100))

  def probe_finished(owner, token, outcome),
    do: Lifecycle.call(owner, {:probe_finished, token, outcome}, Lifecycle.deadline(100))

  def resources(handle) do
    if valid_handle?(handle),
      do: [handle | Map.get(handle, :transports, [])],
      else: {:error, :invalid_endpoint_resources}
  end

  def valid_handle?(%{execution_profile: :managed_h2} = handle) when map_size(handle) == 8,
    do: probe_group_handle?(handle)

  def valid_handle?(%{transports: transports} = handle) when map_size(handle) == 7 do
    valid_handle?(Map.delete(handle, :transports)) and is_list(transports) and
      length(transports) in 1..32 and Enum.uniq(transports) == transports and
      Enum.all?(transports, &transport_handle?/1) and
      match?({:ok, _}, Resources.validate([handle | transports]))
  end

  def valid_handle?(
        %{
          provider: __MODULE__,
          owner: owner,
          owner_epoch: epoch,
          group: group,
          generation: generation,
          max_url_bytes: size
        } = handle
      )
      when map_size(handle) == 6,
      do:
        is_pid(owner) and is_reference(epoch) and is_reference(generation) and
          is_binary(group) and byte_size(group) in 1..128 and is_integer(size) and size in 1..8192

  def valid_handle?(_), do: false

  defp transport_handle?(
         %{
           provider: Gaoxy.Proxy.UpstreamTransports,
           owner: owner,
           owner_epoch: epoch,
           resource: resource
         } = handle
       )
       when map_size(handle) == 4,
       do: is_pid(owner) and is_reference(epoch) and is_reference(resource)

  defp transport_handle?(_), do: false

  @impl true
  def init({instance, limits}) do
    Process.send_after(self(), :probes, 0)

    {:ok,
     %{
       epoch: make_ref(),
       instance: instance,
       instance_monitor: Process.monitor(instance),
       limits: limits,
       groups: %{},
       pins: %{},
       tokens: %{},
       probes: %{},
       bytes: 0,
       probe_bytes: 0,
       control_bytes: 0,
       probe_cursor: 0,
       mode: :ready
     }}
  end

  defp prepare_record(state, compiled, holder, caller, operation, deadline) do
    if h2_compiled?(compiled),
      do: prepare_h2_record(state, compiled, holder, caller, operation, deadline),
      else: prepare_h1_record(state, compiled, holder, caller, operation, deadline)
  end

  defp prepare_h1_record(state, compiled, holder, caller, operation, deadline) do
    generation = make_ref()
    handle = group_handle(compiled, self(), state.epoch, generation)
    transports = Map.get(handle, :transports, [])

    bytes =
      :erlang.external_size(compiled) +
        if(transports == [], do: 0, else: :erlang.external_size(transports))

    cond do
      transports != [] and caller != holder ->
        {:reply, {:error, :unauthorized}, state}

      state.mode != :ready or not is_integer(deadline) or Lifecycle.remaining(deadline) == 0 or
        not is_pid(holder) or
          not Process.alive?(holder) ->
        {:reply, {:error, :preparation_expired}, state}

      not is_reference(operation) or not valid_handle?(handle) or
          not match?({:ok, _}, Resources.validate(resources(handle))) ->
        {:reply, {:error, :invalid_endpoint_resources}, state}

      map_size(state.groups) >= state.limits.max_groups or
        state.bytes + bytes > state.limits.max_config_bytes or
          map_size(state.pins) >= state.limits.max_pins ->
        {:reply, {:error, :group_capacity}, state}

      true ->
        key = {compiled.id, generation}

        members =
          Enum.map(
            compiled.members,
            &Map.merge(&1, %{
              health: :unknown,
              checked: nil,
              failures: 0,
              successes: 0,
              inflight: 0,
              probe: nil,
              due: Lifecycle.now()
            })
          )

        group = %{
          compiled: compiled,
          members: members,
          cursor: 0,
          inflight: 0,
          lifecycle: :active,
          bytes: bytes,
          handle: handle
        }

        state = %{state | groups: Map.put(state.groups, key, group), bytes: state.bytes + bytes}

        {:ok, pin, state} =
          add_pin(state, [key], [handle], holder, caller, :preparation, operation, deadline)

        send(self(), :kick_probes)
        {:reply, {:ok, handle, [pin]}, state}
    end
  end

  @impl true
  def handle_call({:instance, deadline}, _, state) do
    if state.mode == :ready and Lifecycle.remaining(deadline) > 0 and
         Process.alive?(state.instance),
       do: {:reply, {:ok, state.instance}, state},
       else: {:reply, {:error, :preparation_expired}, state}
  end

  def handle_call({:prepare, compiled, holder, operation, deadline}, {caller, _}, state) do
    case compile(compiled) do
      {:ok, compiled} -> prepare_record(state, compiled, holder, caller, operation, deadline)
      {:error, _} = error -> {:reply, error, state}
    end
  end

  def handle_call({:pin, handles, holder, kind, operation, deadline}, {caller, _}, state) do
    keys = Enum.map(handles, &key/1) |> Enum.uniq()

    valid =
      Enum.all?(handles, &(record(state, &1) != nil)) and
        Enum.all?(keys, &(state.groups[&1].lifecycle == :active))

    cond do
      state.mode != :ready or Lifecycle.remaining(deadline) == 0 or not is_pid(holder) or
          not Process.alive?(holder) ->
        {:reply, {:error, :pin_expired}, state}

      kind not in [:baseline, :preparation, :request] or not is_reference(operation) or not valid ->
        {:reply, {:error, :stale_group}, state}

      map_size(state.pins) >= state.limits.max_pins ->
        {:reply, {:error, :group_capacity}, state}

      true ->
        case add_pin(state, keys, handles, holder, caller, kind, operation, deadline) do
          {:ok, pin, next} -> {:reply, {:ok, pin}, next}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:release, %{ref: ref, owner_epoch: epoch} = public}, {caller, _}, state) do
    case state.pins[ref] do
      nil ->
        {:reply, :ok, state}

      %{holder: ^caller, control_bytes: _} = held when epoch == state.epoch ->
        if authentic_h2_pin?(state, public, held),
          do: {:reply, :ok, remove_pin(state, ref)},
          else: {:reply, {:error, :unauthorized_pin_release}, state}

      %{holder: ^caller} when epoch == state.epoch ->
        {:reply, :ok, remove_pin(state, ref)}

      _ ->
        {:reply, {:error, :unauthorized_pin_release}, state}
    end
  end

  def handle_call({:checkout, handle, pins, guardian, context, deadline}, {caller, _}, state) do
    group = record(state, handle)

    cond do
      caller != guardian or not is_pid(guardian) or not is_map(context) or
          :erlang.external_size(context) > 1024 ->
        {:reply, {:error, :invalid_checkout}, state}

      group != nil and h2_group?(group) and
          (map_size(context) != 0 or not h2_request_pin?(state, pins, handle)) ->
        {:reply, {:error, :invalid_checkout}, state}

      state.mode != :ready or group == nil or group.lifecycle == :failed or
        Lifecycle.remaining(deadline) == 0 or not request_pin?(state, pins, key(handle)) ->
        {:reply, {:error, :unavailable}, state}

      group.inflight >= group.compiled.max_inflight or
          map_size(state.tokens) >= state.limits.max_tokens ->
        {:reply, {:error, :unavailable}, state}

      true ->
        select(state, group, key(handle), guardian, deadline)
    end
  end

  def handle_call({:bind, handle, token, completion}, {caller, _}, state) do
    case state.tokens[token] do
      %{guardian: ^caller, key: group_key, completion: nil} = held ->
        if record(state, handle) != nil and group_key == key(handle) and
             match?(%HTTP.RequestCompletion{}, completion),
           do:
             control_reply(
               state,
               :selection,
               token,
               %{held | completion: completion},
               :invalid_completion
             ),
           else: {:reply, {:error, :invalid_completion}, state}

      _ ->
        {:reply, {:error, :invalid_selection_token}, state}
    end
  end

  def handle_call({:finish, handle, token, outcome}, {caller, _}, state) do
    case state.tokens[token] do
      %{guardian: ^caller, key: group_key} ->
        if record(state, handle) != nil and group_key == key(handle) and
             outcome in [:success, :cancelled, :upstream_failure],
           do: {:reply, :ok, finish_token(state, token, outcome)},
           else: {:reply, {:error, :invalid_selection_token}, state}

      nil ->
        {:reply, :ok, state}

      _ ->
        {:reply, {:error, :invalid_selection_token}, state}
    end
  end

  def handle_call({:status, handle}, _, state) do
    case record(state, handle) do
      nil ->
        {:reply, {:error, :stale_group}, state}

      group ->
        members =
          Enum.map(group.members, fn member ->
            %{
              id: member.id,
              health: member.health,
              inflight: member.inflight,
              stale: stale?(member, group.compiled.health),
              probe: member.probe != nil,
              scheduling_lag: max(0, Lifecycle.now() - member.due)
            }
          end)

        status = %{
          lifecycle: group.lifecycle,
          inflight: group.inflight,
          members: members,
          probe_bytes: state.probe_bytes,
          probes: map_size(state.probes),
          pins: map_size(state.pins)
        }

        status =
          if h2_group?(group),
            do:
              Map.merge(status, %{
                config_bytes: state.bytes,
                control_bytes: state.control_bytes,
                control_limit: @control_limit
              }),
            else: status

        {:reply, status, state}
    end
  end

  def handle_call({:claim_probe, token, deadline}, {caller, _}, state) do
    case state.probes[token] do
      %{pid: ^caller, claimed: false, key: group_key, deadline: probe_deadline, monitor: monitor} =
          probe ->
        group = state.groups[group_key]

        if state.mode == :ready and group != nil and group.lifecycle == :active and
             not h2_group?(group) and key(group.handle) == group_key and monitor != nil and
             Lifecycle.remaining(deadline) > 0 and Lifecycle.remaining(probe_deadline) > 0 and
             Process.alive?(caller) and Process.alive?(state.instance) do
          claim_reply(state, token, probe)
        else
          {:reply, {:error, :stale_probe}, state}
        end

      _ ->
        {:reply, {:error, :stale_probe}, state}
    end
  end

  def handle_call({:claim_probe, token, handle, deadline}, {caller, _}, state)
      when is_reference(token) and is_integer(deadline) do
    case state.probes[token] do
      %{pid: ^caller, claimed: false, key: group_key, deadline: probe_deadline, monitor: monitor} =
          probe ->
        group = state.groups[group_key]

        if state.mode == :ready and group != nil and group.lifecycle == :active and
             is_reference(monitor) and probe_group_handle?(handle) and
             group.handle === handle and handle.owner === self() and
             handle.owner_epoch === state.epoch and key(handle) === group_key and
             deadline === probe_deadline and Lifecycle.remaining(deadline) > 0 and
             Process.alive?(caller) and Process.alive?(state.instance) do
          claim_reply(state, token, probe)
        else
          {:reply, {:error, :stale_probe}, state}
        end

      _ ->
        {:reply, {:error, :stale_probe}, state}
    end
  end

  def handle_call({:claim_probe, _, _, _}, _, state),
    do: {:reply, {:error, :stale_probe}, state}

  def handle_call({:bind_probe, token, completion}, {caller, _}, state) do
    case state.probes[token] do
      %{pid: ^caller, completion: nil} = probe ->
        if match?(%HTTP.RequestCompletion{}, completion),
          do:
            control_reply(
              state,
              :probe,
              token,
              %{probe | completion: completion},
              :invalid_completion
            ),
          else: {:reply, {:error, :invalid_completion}, state}

      _ ->
        {:reply, {:error, :stale_probe}, state}
    end
  end

  def handle_call({:probe_finished, token, outcome}, {caller, _}, state) do
    case state.probes[token] do
      %{pid: ^caller} = probe ->
        if not Map.has_key?(probe, :control_bytes) or outcome in [:success, :failure, :cancelled],
          do: {:reply, :ok, finish_probe(state, token, outcome)},
          else: {:reply, {:error, :stale_probe}, state}

      _ ->
        {:reply, {:error, :stale_probe}, state}
    end
  end

  @impl true
  def handle_info(:probes, state) do
    Process.send_after(self(), :probes, 50)
    {:noreply, launch_probes(state)}
  end

  def handle_info(:kick_probes, state), do: {:noreply, launch_probes(state)}

  def handle_info({:pin_expired, ref}, state) do
    case state.pins[ref] do
      %{control_bytes: _, deadline: deadline} when is_integer(deadline) ->
        if Lifecycle.remaining(deadline) == 0,
          do: {:noreply, remove_pin(state, ref)},
          else: {:noreply, state}

      %{control_bytes: _} ->
        {:noreply, state}

      _ ->
        {:noreply, remove_pin(state, ref)}
    end
  end

  def handle_info({:cancel_pin, caller, operation}, state) do
    refs =
      for {ref, pin} <- state.pins, pin.acquirer == caller and pin.operation == operation, do: ref

    {:noreply, Enum.reduce(refs, state, &remove_pin(&2, &1))}
  end

  def handle_info(
        {:DOWN, monitor, :process, pid, _reason},
        %{instance_monitor: monitor, instance: pid} = state
      ) do
    Enum.each(state.tokens, fn {_, token} -> Gaoxy.Proxy.HTTP.Session.cancel(token.guardian) end)

    Enum.each(state.probes, fn {_, probe} ->
      if is_pid(probe[:pid]), do: Probe.cancel(probe.pid)
    end)

    {:noreply, %{state | mode: :draining}}
  end

  def handle_info({:DOWN, monitor, :process, pid, _}, state)
      when is_reference(monitor) and is_pid(pid) do
    cond do
      pin =
          Enum.find(state.pins, fn {_, pin} ->
            pin.monitor == monitor and
                (not Map.has_key?(pin, :control_bytes) or pin.holder == pid)
          end) ->
        {:noreply, remove_pin(state, elem(pin, 0))}

      token =
          Enum.find(state.tokens, fn {_, token} ->
            token.monitor == monitor and
                (not Map.has_key?(token, :control_bytes) or token.guardian == pid)
          end) ->
        {ref, held} = token
        {:noreply, guardian_down(state, :selection, ref, held)}

      probe =
          Enum.find(state.probes, fn {_, probe} ->
            probe[:monitor] == monitor and
                (not Map.has_key?(probe, :control_bytes) or probe.pid == pid)
          end) ->
        {ref, held} = probe
        {:noreply, guardian_down(state, :probe, ref, held)}

      recovery =
          Enum.find(
            Map.values(state.tokens) ++ Map.values(state.probes),
            &(&1[:recovery_monitor] == monitor and
                  (not Map.has_key?(&1, :control_bytes) or &1.recovery == pid))
          ) ->
        {:noreply, fail_group(state, recovery.key)}

      true ->
        {:noreply, state}
    end
  end

  def handle_info({:recovered, kind, ref, recovery, :ok}, state)
      when kind in [:selection, :probe] do
    held = if kind == :selection, do: state.tokens[ref], else: state.probes[ref]

    if held && held[:recovery] == recovery do
      Process.demonitor(held.recovery_monitor, [:flush])

      state =
        if kind == :selection,
          do: finish_token(state, ref, :cancelled),
          else: finish_probe(state, ref, :failure)

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:recovered, kind, ref, recovery, {:error, _}}, state)
      when kind in [:selection, :probe] do
    held = if kind == :selection, do: state.tokens[ref], else: state.probes[ref]

    if held && held[:recovery] == recovery,
      do: {:noreply, fail_group(state, held.key)},
      else: {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp key(handle), do: {handle.group, handle.generation}

  defp record(state, handle) do
    if valid_handle?(handle) and handle.owner == self() and handle.owner_epoch == state.epoch do
      case state.groups[key(handle)] do
        %{handle: ^handle} = group -> group
        _ -> nil
      end
    end
  end

  defp add_pin(state, keys, handles, holder, caller, kind, operation, deadline) do
    if Enum.any?(keys, &h2_group?(state.groups[&1])),
      do: add_h2_pin(state, keys, handles, holder, caller, kind, operation, deadline),
      else: add_h1_pin(state, keys, handles, holder, caller, kind, operation, deadline)
  end

  defp add_h1_pin(state, keys, handles, holder, caller, kind, operation, deadline) do
    ref = make_ref()

    timer =
      if kind != :baseline,
        do: Process.send_after(self(), {:pin_expired, ref}, Lifecycle.remaining(deadline))

    record = %{
      keys: keys,
      holder: holder,
      acquirer: caller,
      kind: kind,
      operation: operation,
      deadline: if(kind == :baseline, do: nil, else: deadline),
      monitor: Process.monitor(holder),
      timer: timer
    }

    pin = %{
      provider: __MODULE__,
      owner: self(),
      owner_epoch: state.epoch,
      ref: ref,
      operation: operation,
      handles: handles,
      kind: kind
    }

    {:ok, pin, %{state | pins: Map.put(state.pins, ref, record)}}
  end

  defp remove_pin(state, ref) do
    case Map.pop(state.pins, ref) do
      {nil, _} ->
        state

      {pin, pins} ->
        if pin.timer, do: Process.cancel_timer(pin.timer)
        Process.demonitor(pin.monitor, [:flush])
        Enum.reduce(pin.keys, refund_control(%{state | pins: pins}, pin), &reconcile(&2, &1))
    end
  end

  defp request_pin?(state, pins, group_key) when is_list(pins),
    do: Enum.any?(pins, &request_pin?(state, &1, group_key))

  defp request_pin?(state, %{owner_epoch: epoch, ref: ref}, group_key)
       when epoch == state.epoch do
    case state.pins[ref] do
      %{kind: :request, holder: holder, keys: keys, deadline: deadline} ->
        group_key in keys and Process.alive?(holder) and Lifecycle.remaining(deadline) > 0

      _ ->
        false
    end
  end

  defp request_pin?(_, _, _), do: false

  defp select(state, group, group_key, guardian, deadline) do
    if h2_group?(group),
      do: select_h2(state, group, group_key, guardian, deadline),
      else: select_h1(state, group, group_key, guardian, deadline)
  end

  defp select_h1(state, group, group_key, guardian, deadline) do
    size = length(group.members)

    index =
      Enum.find(0..(size - 1), fn offset ->
        member = Enum.at(group.members, rem(group.cursor + offset, size))

        member.health == :healthy and not stale?(member, group.compiled.health) and
          member.inflight < member.max_inflight
      end)

    if index == nil do
      {:reply, {:error, :unavailable}, state}
    else
      index = rem(group.cursor + index, size)
      member = Enum.at(group.members, index)
      token = make_ref()

      held = %{
        key: group_key,
        index: index,
        guardian: guardian,
        monitor: Process.monitor(guardian),
        completion: nil,
        deadline: deadline,
        recovery: nil
      }

      group = %{
        group
        | cursor: rem(index + 1, size),
          inflight: group.inflight + 1,
          members: List.update_at(group.members, index, &%{&1 | inflight: &1.inflight + 1})
      }

      state = %{
        state
        | groups: Map.put(state.groups, group_key, group),
          tokens: Map.put(state.tokens, token, held)
      }

      {:reply, {:ok, Map.take(member, [:id, :config, :max_inflight]), token}, state}
    end
  end

  defp finish_token(state, token, outcome) do
    case state.tokens[token] do
      nil -> state
      %{control_bytes: _} -> finish_h2_token(state, token, outcome)
      _ -> finish_h1_token(state, token, outcome)
    end
  end

  defp finish_h1_token(state, token, outcome) do
    {held, tokens} = Map.pop(state.tokens, token)
    if held.monitor, do: Process.demonitor(held.monitor, [:flush])
    group = state.groups[held.key]
    member = Enum.at(group.members, held.index)
    member = %{member | inflight: member.inflight - 1}
    member = passive(member, outcome, group.compiled.health)

    group = %{
      group
      | inflight: group.inflight - 1,
        members: List.replace_at(group.members, held.index, member)
    }

    reconcile(%{state | tokens: tokens, groups: Map.put(state.groups, held.key, group)}, held.key)
  end

  defp passive(member, :upstream_failure, health), do: failed_health(member, health)
  defp passive(member, :success, _), do: %{member | failures: 0}
  defp passive(member, _, _), do: member
  defp stale?(%{checked: nil}, _), do: true
  defp stale?(member, health), do: Lifecycle.now() - member.checked >= health.stale_after

  defp reconcile(state, group_key) do
    group = state.groups[group_key]

    if h2_group?(group) and
         Enum.any?(state.pins, fn {_, pin} ->
           pin.kind in [:baseline, :preparation] and group_key in pin.keys
         end) do
      # A real remaining anchor leaves the stored group unchanged. Avoid
      # rescanning every pin and revalidating it once per multi-group key.
      state
    else
      reconcile_unanchored(state, group_key, group)
    end
  end

  defp reconcile_unanchored(state, group_key, group) do
    pins = Enum.filter(Map.values(state.pins), &(group_key in &1.keys))
    retiring = not Enum.any?(pins, &(&1.kind in [:baseline, :preparation]))

    group =
      if retiring and group.lifecycle != :failed, do: %{group | lifecycle: :retiring}, else: group

    if retiring do
      Enum.each(state.probes, fn {_, probe} ->
        if probe.key == group_key and is_pid(probe[:pid]), do: Probe.cancel(probe.pid)
      end)
    end

    if pins == [] and group.inflight == 0 and
         not Enum.any?(state.probes, fn {_, p} -> p.key == group_key end) do
      %{state | groups: Map.delete(state.groups, group_key), bytes: state.bytes - group.bytes}
    else
      case put_group(state, group_key, group) do
        {:ok, next} -> next
        {:error, _} -> fail_group(state, group_key)
      end
    end
  end

  defp launch_probes(%{mode: mode} = state) when mode != :ready, do: state

  defp launch_probes(state) do
    candidates =
      for {group_key, group} <- state.groups,
          group.lifecycle == :active,
          {member, index} <- Enum.with_index(group.members),
          member.probe == nil and member.due <= Lifecycle.now(),
          do: {group_key, index, member, group}

    count = length(candidates)

    candidates =
      if count == 0,
        do: [],
        else:
          Enum.drop(candidates, rem(state.probe_cursor, count)) ++
            Enum.take(candidates, rem(state.probe_cursor, count))

    Enum.reduce(candidates, state, fn {group_key, index, member, group}, acc ->
      selected = Map.take(member, [:id, :config, :max_inflight])

      if probe_group_intent?(selected, group.handle),
        do: launch_group_probe(acc, group_key, index, selected, group),
        else: launch_h1_probe(acc, group_key, index, selected, group)
    end)
  end

  defp launch_group_probe(state, group_key, index, selected, group) do
    health = group.compiled.health
    launch_now = Lifecycle.now()

    budget =
      min(
        health.timeout,
        min(
          selected.config.limits.opening_timeout,
          selected.config.limits.max_lifetime
        )
      )

    deadline = launch_now + budget
    token = make_ref()

    args = %{
      owner: self(),
      token: token,
      member: selected,
      deadline: deadline,
      health: health,
      url: :binary.copy(member_origin(selected.config) <> health.path),
      group: group.handle
    }

    with :ok <- Gaoxy.Proxy.ManagedH2GroupBoundary.activation(),
         true <- launch_now >= @signed_min and launch_now <= @signed_max,
         true <- deadline >= @signed_min and deadline <= @signed_max - 1_000,
         {:ok, args} <- probe_start_arguments(args),
         {:ok, _startup} <- ManagedH2GroupAccounting.startup(Probe, args) do
      admit_group_probe(state, group_key, index, token, deadline, args)
    else
      _ -> state
    end
  end

  defp launch_h1_probe(state, group_key, index, selected, group) do
    url = URI.to_string(%{selected.config.uri | path: group.compiled.health.path})
    token = make_ref()
    deadline = Lifecycle.deadline(group.compiled.health.timeout)

    args = %{
      owner: self(),
      token: token,
      member: selected,
      deadline: deadline,
      health: group.compiled.health,
      url: url
    }

    with {:ok, args} <- probe_start_arguments(args) do
      reserve = HTTPFetchClient.reservation([], url, selected.config.limits.max_chunk_bytes)

      if map_size(state.probes) < state.limits.max_probes and
           state.probe_bytes + reserve <= state.limits.probe_bytes do
        case DynamicSupervisor.start_child(Gaoxy.Proxy.ProbeSupervisor, {Probe, args}) do
          {:ok, pid} ->
            probe = %{
              pid: pid,
              key: group_key,
              index: index,
              bytes: reserve,
              completion: nil,
              claimed: false,
              monitor: Process.monitor(pid),
              recovery: nil,
              deadline: deadline
            }

            state =
              put_in(
                state.groups[group_key].members,
                List.update_at(state.groups[group_key].members, index, &%{&1 | probe: token})
              )

            %{
              state
              | probes: Map.put(state.probes, token, probe),
                probe_bytes: state.probe_bytes + reserve,
                probe_cursor: state.probe_cursor + 1
            }

          {:error, _} ->
            state
        end
      else
        state
      end
    else
      {:error, :invalid_probe_arguments} -> state
    end
  end

  defp finish_probe(state, token, outcome) do
    case state.probes[token] do
      nil -> state
      %{control_bytes: _} -> finish_h2_probe(state, token, outcome)
      _ -> finish_h1_probe(state, token, outcome)
    end
  end

  defp finish_h1_probe(state, token, outcome) do
    {probe, probes} = Map.pop(state.probes, token)
    if probe.monitor, do: Process.demonitor(probe.monitor, [:flush])
    group = state.groups[probe.key]
    health = group.compiled.health
    member = Enum.at(group.members, probe.index)

    member =
      case outcome do
        :cancelled ->
          member

        :success ->
          successes = member.successes + 1
          healthy = member.health != :unhealthy or successes >= health.recovery_threshold

          %{
            member
            | health: if(healthy, do: :healthy, else: :unhealthy),
              successes: successes,
              failures: 0
          }

        _ ->
          failed_health(member, health)
      end

    jitter =
      if health.jitter == 0,
        do: 0,
        else: :erlang.phash2({probe.key, member.id}, health.jitter + 1)

    member = %{
      member
      | checked: if(outcome == :cancelled, do: member.checked, else: Lifecycle.now()),
        probe: nil,
        due: Lifecycle.now() + health.interval + jitter
    }

    group = %{group | members: List.replace_at(group.members, probe.index, member)}

    reconcile(
      %{
        state
        | probes: probes,
          probe_bytes: state.probe_bytes - probe.bytes,
          groups: Map.put(state.groups, probe.key, group)
      },
      probe.key
    )
  end

  defp failed_health(member, health) do
    failures = member.failures + 1

    %{
      member
      | failures: failures,
        successes: 0,
        health: if(failures >= health.failure_threshold, do: :unhealthy, else: member.health)
    }
  end

  defp recover(state, kind, token, held) do
    if Map.has_key?(held, :control_bytes),
      do: recover_h2(state, kind, token, held),
      else: recover_h1(state, kind, token, held)
  end

  defp recover_h1(state, kind, token, held) do
    if held.completion != nil do
      args = %{
        owner: self(),
        recovery: {kind, token},
        completion: held.completion,
        deadline: max(held.deadline, Lifecycle.deadline(1_000))
      }

      with {:ok, args} <- probe_recovery_arguments(args),
           {:ok, pid} <- DynamicSupervisor.start_child(Gaoxy.Proxy.ProbeSupervisor, {Probe, args}) do
        recovered =
          Map.merge(held, %{recovery: pid, recovery_monitor: Process.monitor(pid), monitor: nil})

        if kind == :selection,
          do: put_in(state.tokens[token], recovered),
          else: put_in(state.probes[token], recovered)
      else
        {:error, _} ->
          put_in(state.groups[held.key].lifecycle, :failed)
      end
    else
      put_in(state.groups[held.key].lifecycle, :failed)
    end
  end

  defp h2_compiled?(group), do: hd(group.members).config.upstream_protocol in [:http2, :h2c]
  defp h2_group?(%{handle: %{execution_profile: :managed_h2}}), do: true
  defp h2_group?(_), do: false

  defp member_origin(%{upstream_protocol: protocol, uri: uri}) when protocol in [:http2, :h2c],
    do: uri.scheme <> "://" <> uri.authority

  defp member_origin(config), do: URI.to_string(config.uri)

  defp prepare_h2_record(state, compiled, holder, caller, operation, deadline) do
    handle = group_handle(compiled, self(), state.epoch, make_ref())
    group_key = key(handle)

    group = %{
      compiled: compiled,
      members:
        Enum.map(
          compiled.members,
          &Map.merge(&1, %{
            health: :unknown,
            checked: nil,
            failures: 0,
            successes: 0,
            inflight: 0,
            probe: nil,
            due: Lifecycle.now()
          })
        ),
      cursor: 0,
      inflight: 0,
      lifecycle: :active,
      bytes: 0,
      handle: handle
    }

    cond do
      caller != holder ->
        {:reply, {:error, :unauthorized}, state}

      state.mode != :ready or not is_integer(deadline) or Lifecycle.remaining(deadline) == 0 or
        not is_pid(holder) or not Process.alive?(holder) ->
        {:reply, {:error, :preparation_expired}, state}

      not is_reference(operation) or not valid_handle?(handle) ->
        {:reply, {:error, :invalid_endpoint_resources}, state}

      map_size(state.groups) >= state.limits.max_groups or
          map_size(state.pins) >= state.limits.max_pins ->
        {:reply, {:error, :group_capacity}, state}

      true ->
        with :ok <- ManagedH2GroupAccounting.preflight_control(:monitor, state.instance),
             {:ok, bytes} <- ManagedH2GroupAccounting.group_charge(group),
             true <- state.bytes + bytes <= state.limits.max_config_bytes,
             group = %{group | bytes: bytes},
             candidate = %{
               state
               | groups: Map.put(state.groups, group_key, group),
                 bytes: state.bytes + bytes
             },
             {:ok, pin, next} <-
               add_h2_pin(
                 candidate,
                 [group_key],
                 [handle],
                 holder,
                 caller,
                 :preparation,
                 operation,
                 deadline
               ) do
          send(self(), :kick_probes)
          {:reply, {:ok, handle, [pin]}, next}
        else
          _ -> {:reply, {:error, :group_capacity}, state}
        end
    end
  end

  defp add_h2_pin(state, keys, handles, holder, caller, kind, operation, deadline) do
    ref = make_ref()

    pin = %{
      provider: __MODULE__,
      owner: self(),
      owner_epoch: state.epoch,
      ref: ref,
      operation: operation,
      handles: handles,
      kind: kind
    }

    partial = %{
      keys: keys,
      holder: holder,
      acquirer: caller,
      kind: kind,
      operation: operation,
      deadline: if(kind == :baseline, do: nil, else: deadline)
    }

    with :ok <- ManagedH2GroupAccounting.preflight_control(:monitor, holder),
         :ok <- ManagedH2GroupAccounting.validate(:captured_pins, [pin]),
         {:ok, reserved, pending} <- reserve_control(state, :pin, partial) do
      monitor = Process.monitor(holder)

      timer =
        if kind == :baseline,
          do: nil,
          else: Process.send_after(self(), {:pin_expired, ref}, Lifecycle.remaining(deadline))

      record = Map.merge(reserved, %{monitor: monitor, timer: timer})

      case reconcile_control(pending, :pin, record) do
        {:ok, record, next} ->
          {:ok, pin, put_in(next.pins[ref], record)}

        {:error, _} ->
          if timer, do: Process.cancel_timer(timer)
          Process.demonitor(monitor, [:flush])
          {:error, :group_capacity}
      end
    else
      _ -> {:error, :group_capacity}
    end
  end

  # A provisional charge is installed before effects; no future PID/ref is invented.
  defp reserve_control(state, kind, partial) do
    old = Map.get(partial, :control_bytes, 0)

    with {:ok, cap} <- ManagedH2GroupAccounting.control_reserve(kind, partial),
         total = state.control_bytes - old + cap,
         true <- total <= @control_limit do
      {:ok, Map.put(partial, :control_bytes, cap), %{state | control_bytes: total}}
    else
      _ -> {:error, :group_capacity}
    end
  end

  defp reconcile_control(state, kind, record) do
    if Map.has_key?(record, :control_bytes) do
      with {:ok, bytes} <- ManagedH2GroupAccounting.control_charge(kind, record),
           total = state.control_bytes - record.control_bytes + bytes,
           true <- total <= @control_limit do
        {:ok, %{record | control_bytes: bytes}, %{state | control_bytes: total}}
      else
        _ -> {:error, :group_capacity}
      end
    else
      {:ok, record, state}
    end
  end

  defp control_table(:selection), do: :tokens
  defp control_table(:probe), do: :probes

  defp control_reply(state, kind, token, candidate, reason) do
    case replace_control(state, kind, token, candidate) do
      {:ok, next} -> {:reply, :ok, next}
      {:error, _} -> {:reply, {:error, reason}, state}
    end
  end

  defp replace_control(state, kind, token, candidate) do
    with {:ok, held, next} <- reconcile_control(state, kind, candidate) do
      {:ok, Map.update!(next, control_table(kind), &Map.put(&1, token, held))}
    end
  end

  defp claim_reply(state, token, probe) do
    case replace_control(state, :probe, token, %{probe | claimed: true}) do
      {:ok, next} -> {:reply, {:ok, state.instance}, next}
      {:error, _} -> {:reply, {:error, :stale_probe}, state}
    end
  end

  defp refund_control(state, record),
    do: %{state | control_bytes: state.control_bytes - Map.get(record, :control_bytes, 0)}

  defp put_group(state, group_key, group) do
    if not h2_group?(group) or
         ManagedH2GroupAccounting.group_update(group, group.bytes) == :ok,
       do: {:ok, put_in(state.groups[group_key], group)},
       else: {:error, :group_capacity}
  end

  defp fail_group(state, group_key) do
    group = state.groups[group_key]

    case put_group(state, group_key, %{group | lifecycle: :failed}) do
      {:ok, next} -> next
      {:error, _} -> %{state | mode: :draining}
    end
  end

  defp authentic_h2_pin?(state, public, held) do
    ManagedH2GroupAccounting.validate(:captured_pins, [public]) == :ok and
      public.provider == __MODULE__ and public.owner == self() and
      public.operation == held.operation and public.kind == held.kind and
      Enum.map(public.handles, &key/1) == held.keys and
      Enum.all?(public.handles, &(record(state, &1) != nil))
  end

  defp h2_request_pin?(state, pins, handle) do
    ManagedH2GroupAccounting.validate(:captured_pins, pins) == :ok and
      Enum.any?(pins, fn pin ->
        case pin do
          %{
            provider: __MODULE__,
            owner: owner,
            owner_epoch: epoch,
            ref: ref,
            operation: operation,
            handles: handles,
            kind: :request
          }
          when owner == self() and epoch == state.epoch ->
            case state.pins[ref] do
              %{kind: :request, operation: ^operation, keys: keys} ->
                key(handle) in keys and Enum.map(handles, &key/1) == keys and
                  Enum.all?(handles, &(record(state, &1) != nil))

              _ ->
                false
            end

          _ ->
            false
        end
      end)
  end

  defp select_h2(state, group, group_key, guardian, deadline) do
    size = length(group.members)

    offset =
      Enum.find(0..(size - 1), fn offset ->
        member = Enum.at(group.members, rem(group.cursor + offset, size))

        member.health == :healthy and not stale?(member, group.compiled.health) and
          member.inflight < member.max_inflight
      end)

    if offset == nil do
      {:reply, {:error, :unavailable}, state}
    else
      index = rem(group.cursor + offset, size)
      member = Enum.at(group.members, index)
      selected = Map.take(member, [:id, :config, :max_inflight])
      token = make_ref()

      partial = %{
        key: group_key,
        index: index,
        guardian: guardian,
        completion: nil,
        deadline: deadline,
        recovery: nil
      }

      updated = %{
        group
        | cursor: rem(index + 1, size),
          inflight: group.inflight + 1,
          members: List.update_at(group.members, index, &%{&1 | inflight: &1.inflight + 1})
      }

      with :ok <- ManagedH2GroupAccounting.preflight_control(:monitor, guardian),
           :ok <- ManagedH2GroupAccounting.validate(:selected, selected),
           {:ok, next} <- put_group(state, group_key, updated),
           {:ok, reserved, pending} <- reserve_control(next, :selection, partial) do
        monitor = Process.monitor(guardian)

        case reconcile_control(pending, :selection, Map.put(reserved, :monitor, monitor)) do
          {:ok, held, admitted} ->
            {:reply, {:ok, selected, token}, put_in(admitted.tokens[token], held)}

          {:error, _} ->
            Process.demonitor(monitor, [:flush])
            {:reply, {:error, :unavailable}, state}
        end
      else
        _ -> {:reply, {:error, :unavailable}, state}
      end
    end
  end

  defp finish_h2_token(state, token, outcome) do
    held = state.tokens[token]
    group = state.groups[held.key]
    member = Enum.at(group.members, held.index)
    member = %{member | inflight: member.inflight - 1}

    member =
      case outcome do
        :upstream_failure -> failed_h2_health(member, group.compiled.health)
        :success -> %{member | failures: 0}
        _ -> member
      end

    updated = %{
      group
      | inflight: group.inflight - 1,
        members: List.replace_at(group.members, held.index, member)
    }

    case put_group(state, held.key, updated) do
      {:ok, next} ->
        if held.monitor, do: Process.demonitor(held.monitor, [:flush])
        next = refund_control(%{next | tokens: Map.delete(next.tokens, token)}, held)
        reconcile(next, held.key)

      {:error, _} ->
        fail_group(state, held.key)
    end
  end

  defp admit_group_probe(state, group_key, index, token, deadline, args) do
    reserve = ManagedH2GroupAccounting.reservation_bytes()

    partial = %{
      key: group_key,
      index: index,
      bytes: reserve,
      completion: nil,
      claimed: false,
      recovery: nil,
      deadline: deadline
    }

    group = state.groups[group_key]
    updated = %{group | members: List.update_at(group.members, index, &%{&1 | probe: token})}

    with :ok <- ManagedH2GroupAccounting.preflight_control(:local_monitor, node()),
         true <- map_size(state.probes) < state.limits.max_probes,
         true <- state.probe_bytes + reserve <= state.limits.probe_bytes,
         {:ok, candidate} <- put_group(state, group_key, updated),
         {:ok, reserved, pending} <- reserve_control(candidate, :probe, partial) do
      # Both ledgers and the real key/index are owned before the child starts.
      pending = %{
        pending
        | probes: Map.put(pending.probes, token, reserved),
          probe_bytes: pending.probe_bytes + reserve
      }

      case start_h2_probe(args) do
        {:ok, pid} ->
          case monitor_h2_child(pid) do
            {:ok, monitor} ->
              record = Map.merge(reserved, %{pid: pid, monitor: monitor})

              case reconcile_control(pending, :probe, record) do
                {:ok, record, admitted} ->
                  %{
                    admitted
                    | probes: Map.put(admitted.probes, token, record),
                      probe_cursor: rem(admitted.probe_cursor + 1, 32_768)
                  }

                {:error, _} ->
                  rollback_probe_child(state, pending, record, token, pid, monitor)
              end

            {:error, _} ->
              rollback_probe_child(state, pending, reserved, token, pid, nil)
          end

        {:error, :start_unconfirmed} ->
          fail_group(pending, group_key)

        {:error, _} ->
          state
      end
    else
      _ -> state
    end
  end

  defp rollback_probe_child(original, pending, record, token, pid, monitor) do
    case stop_h2_probe(pid) do
      :ok ->
        if monitor, do: Process.demonitor(monitor, [:flush])
        original

      {:error, :not_found} ->
        if not Process.alive?(pid) do
          if monitor, do: Process.demonitor(monitor, [:flush])
          original
        else
          fail_group(put_in(pending.probes[token], record), record.key)
        end

      {:error, _} ->
        fail_group(put_in(pending.probes[token], record), record.key)
    end
  end

  defp finish_h2_probe(state, token, outcome) do
    probe = state.probes[token]
    group = state.groups[probe.key]
    health = group.compiled.health
    member = Enum.at(group.members, probe.index)

    member =
      case outcome do
        :cancelled ->
          member

        :success ->
          successes = min(member.successes + 1, health.recovery_threshold)
          healthy = member.health != :unhealthy or successes >= health.recovery_threshold

          %{
            member
            | health: if(healthy, do: :healthy, else: :unhealthy),
              successes: successes,
              failures: 0
          }

        _ ->
          failed_h2_health(member, health)
      end

    now = Lifecycle.now()

    jitter =
      if health.jitter == 0,
        do: 0,
        else: :erlang.phash2({probe.key, member.id}, health.jitter + 1)

    member = %{
      member
      | checked: if(outcome == :cancelled, do: member.checked, else: now),
        probe: nil,
        due: now + health.interval + jitter
    }

    updated = %{group | members: List.replace_at(group.members, probe.index, member)}

    case put_group(state, probe.key, updated) do
      {:ok, next} ->
        if probe.monitor, do: Process.demonitor(probe.monitor, [:flush])

        next =
          refund_control(
            %{
              next
              | probes: Map.delete(next.probes, token),
                probe_bytes: next.probe_bytes - probe.bytes
            },
            probe
          )

        reconcile(next, probe.key)

      {:error, _} ->
        fail_group(state, probe.key)
    end
  end

  defp failed_h2_health(member, health) do
    failures = min(member.failures + 1, health.failure_threshold)

    %{
      member
      | failures: failures,
        successes: 0,
        health: if(failures >= health.failure_threshold, do: :unhealthy, else: member.health)
    }
  end

  defp guardian_down(state, kind, token, held) do
    case replace_control(state, kind, token, %{held | monitor: nil}) do
      {:ok, next} ->
        recover(next, kind, token, Map.fetch!(Map.fetch!(next, control_table(kind)), token))

      {:error, _} ->
        fail_group(state, held.key)
    end
  end

  defp recover_h2(state, kind, token, held) do
    if held.completion == nil do
      fail_group(state, held.key)
    else
      args = %{
        owner: self(),
        recovery: {kind, token},
        completion: held.completion,
        deadline: max(held.deadline, Lifecycle.deadline(1_000))
      }

      partial = Map.drop(held, [:recovery, :recovery_monitor])

      with {:ok, args} <- probe_recovery_arguments(args),
           {:ok, _startup} <- ManagedH2GroupAccounting.startup(Probe, args),
           :ok <- ManagedH2GroupAccounting.preflight_control(:local_monitor, node()),
           {:ok, reserved, pending} <- reserve_control(state, kind, partial) do
        case start_h2_probe(args) do
          {:ok, pid} ->
            case monitor_h2_child(pid) do
              {:ok, monitor} ->
                record = Map.merge(reserved, %{recovery: pid, recovery_monitor: monitor})

                case reconcile_control(pending, kind, record) do
                  {:ok, record, next} ->
                    Map.update!(next, control_table(kind), &Map.put(&1, token, record))

                  {:error, _} ->
                    rollback_h2_recovery(state, pending, kind, token, record, pid, monitor)
                end

              {:error, _} ->
                rollback_h2_recovery(state, pending, kind, token, reserved, pid, nil)
            end

          {:error, :start_unconfirmed} ->
            pending = Map.update!(pending, control_table(kind), &Map.put(&1, token, reserved))
            fail_group(pending, held.key)

          {:error, _} ->
            fail_group(state, held.key)
        end
      else
        _ -> fail_group(state, held.key)
      end
    end
  end

  defp monitor_h2_child(pid) do
    with :ok <- ManagedH2GroupAccounting.preflight_control(:monitor, pid),
         do: {:ok, Process.monitor(pid)}
  end

  defp rollback_h2_recovery(original, pending, kind, token, record, pid, monitor) do
    case stop_h2_probe(pid) do
      :ok ->
        if monitor, do: Process.demonitor(monitor, [:flush])
        fail_group(original, record.key)

      {:error, :not_found} ->
        if not Process.alive?(pid) do
          if monitor, do: Process.demonitor(monitor, [:flush])
          fail_group(original, record.key)
        else
          pending = Map.update!(pending, control_table(kind), &Map.put(&1, token, record))
          fail_group(pending, record.key)
        end

      {:error, _} ->
        pending = Map.update!(pending, control_table(kind), &Map.put(&1, token, record))
        fail_group(pending, record.key)
    end
  end

  defp start_h2_probe(args) do
    DynamicSupervisor.start_child(Gaoxy.Proxy.ProbeSupervisor, {Probe, args})
  catch
    :exit, _ -> {:error, :start_unconfirmed}
  end

  defp stop_h2_probe(pid) do
    DynamicSupervisor.terminate_child(Gaoxy.Proxy.ProbeSupervisor, pid)
  catch
    :exit, _ -> {:error, :cleanup_unconfirmed}
  end
end
