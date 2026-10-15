defmodule Gaoxy.Proxy.UpstreamGroups do
  @moduledoc """
  Instance-scoped immutable H1 groups with cleanup-held selections.

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
    UpstreamGroups.Options,
    UpstreamGroups.Probe,
    UpstreamTransports
  }

  @signed_min -9_223_372_036_854_775_808
  @signed_max 9_223_372_036_854_775_807

  @doc false
  def probe_start_arguments(
        %{owner: owner, token: token, member: member, deadline: deadline, health: health, url: url} = args
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
        %{owner: owner, recovery: {kind, token}, completion: completion, deadline: deadline} = args
      )
      when map_size(args) == 4 and is_pid(owner) and kind in [:selection, :probe] and
             is_reference(token) and is_integer(deadline) and deadline >= @signed_min and
             deadline <= @signed_max do
    # The public capability is opaque: validate its shell without inspecting,
    # serializing or reconstructing tracker/latch/unsupported interiors.
    case completion do
      %HTTP.RequestCompletion{tracker: _, latch: _, unsupported: _} when map_size(completion) == 4 ->
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
         %{max_chunk_bytes: chunk, opening_timeout: opening, idle_timeout: idle,
           write_timeout: write, max_lifetime: lifetime} = limits
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
         %{path: path, interval: interval, timeout: timeout, stale_after: stale,
           failure_threshold: failure, recovery_threshold: recovery, jitter: jitter} = health,
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
         %{provider: __MODULE__, owner: owner, owner_epoch: epoch, group: id,
           generation: generation, max_url_bytes: bytes, transports: transports,
           execution_profile: :managed_h2} = handle
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
    do: transport_handle?(transport) and transport not in seen and
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
    |> Enum.map(&{&1.config.transport, URI.to_string(&1.config.uri)})
    |> Enum.uniq()
    |> Enum.reduce_while(:ok, fn {transport, origin}, :ok ->
      identity = %{origin: origin, upstream_protocol: :http1, instance: instance}

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
      max_url_bytes: Enum.max(Enum.map(group.members, &byte_size(URI.to_string(&1.config.uri))))
    }

    case member_transports(group) do
      [] -> handle
      transports -> Map.put(handle, :transports, transports)
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
       probe_cursor: 0,
       mode: :ready
     }}
  end

  defp prepare_record(state, compiled, holder, caller, operation, deadline) do
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

        {pin, state} =
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
        {pin, state} = add_pin(state, keys, handles, holder, caller, kind, operation, deadline)
        {:reply, {:ok, pin}, state}
    end
  end

  def handle_call({:release, %{ref: ref, owner_epoch: epoch}}, {caller, _}, state) do
    case state.pins[ref] do
      nil -> {:reply, :ok, state}
      %{holder: ^caller} when epoch == state.epoch -> {:reply, :ok, remove_pin(state, ref)}
      _ -> {:reply, {:error, :unauthorized_pin_release}, state}
    end
  end

  def handle_call({:checkout, handle, pins, guardian, context, deadline}, {caller, _}, state) do
    group = record(state, handle)

    cond do
      caller != guardian or not is_pid(guardian) or not is_map(context) or
          :erlang.external_size(context) > 1024 ->
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
           do: {:reply, :ok, put_in(state.tokens[token], %{held | completion: completion})},
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

        {:reply,
         %{
           lifecycle: group.lifecycle,
           inflight: group.inflight,
           members: members,
           probe_bytes: state.probe_bytes,
           probes: map_size(state.probes),
           pins: map_size(state.pins)
         }, state}
    end
  end

  def handle_call({:claim_probe, token, deadline}, {caller, _}, state) do
    case state.probes[token] do
      %{pid: ^caller, claimed: false, key: group_key, deadline: probe_deadline, monitor: monitor} =
          probe ->
        group = state.groups[group_key]

        if state.mode == :ready and group != nil and group.lifecycle == :active and
             key(group.handle) == group_key and monitor != nil and
             Lifecycle.remaining(deadline) > 0 and Lifecycle.remaining(probe_deadline) > 0 and
             Process.alive?(caller) and Process.alive?(state.instance) do
          {:reply, {:ok, state.instance}, put_in(state.probes[token], %{probe | claimed: true})}
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
      %{pid: ^caller, claimed: false, key: group_key, deadline: probe_deadline, monitor: monitor} = probe ->
        group = state.groups[group_key]

        if state.mode == :ready and group != nil and group.lifecycle == :active and
             is_reference(monitor) and probe_group_handle?(handle) and
             group.handle === handle and handle.owner === self() and
             handle.owner_epoch === state.epoch and key(handle) === group_key and
             deadline === probe_deadline and Lifecycle.remaining(deadline) > 0 and
             Process.alive?(caller) and Process.alive?(state.instance) do
          {:reply, {:ok, state.instance}, put_in(state.probes[token], %{probe | claimed: true})}
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
          do: {:reply, :ok, put_in(state.probes[token], %{probe | completion: completion})},
          else: {:reply, {:error, :invalid_completion}, state}

      _ ->
        {:reply, {:error, :stale_probe}, state}
    end
  end

  def handle_call({:probe_finished, token, outcome}, {caller, _}, state) do
    case state.probes[token] do
      %{pid: ^caller} -> {:reply, :ok, finish_probe(state, token, outcome)}
      _ -> {:reply, {:error, :stale_probe}, state}
    end
  end

  @impl true
  def handle_info(:probes, state) do
    Process.send_after(self(), :probes, 50)
    {:noreply, launch_probes(state)}
  end

  def handle_info(:kick_probes, state), do: {:noreply, launch_probes(state)}
  def handle_info({:pin_expired, ref}, state), do: {:noreply, remove_pin(state, ref)}

  def handle_info({:cancel_pin, caller, operation}, state) do
    refs =
      for {ref, pin} <- state.pins, pin.acquirer == caller and pin.operation == operation, do: ref

    {:noreply, Enum.reduce(refs, state, &remove_pin(&2, &1))}
  end

  def handle_info({:DOWN, monitor, :process, _pid, _reason}, %{instance_monitor: monitor} = state) do
    Enum.each(state.tokens, fn {_, token} -> Gaoxy.Proxy.HTTP.Session.cancel(token.guardian) end)
    Enum.each(state.probes, fn {_, probe} -> Probe.cancel(probe.pid) end)
    {:noreply, %{state | mode: :draining}}
  end

  def handle_info({:DOWN, monitor, :process, _, _}, state) do
    cond do
      pin = Enum.find(state.pins, fn {_, pin} -> pin.monitor == monitor end) ->
        {:noreply, remove_pin(state, elem(pin, 0))}

      token = Enum.find(state.tokens, fn {_, token} -> token.monitor == monitor end) ->
        {ref, held} = token
        state = put_in(state.tokens[ref], %{held | monitor: nil})
        {:noreply, recover(state, :selection, ref, held)}

      probe = Enum.find(state.probes, fn {_, probe} -> probe.monitor == monitor end) ->
        {ref, held} = probe
        state = put_in(state.probes[ref], %{held | monitor: nil})
        {:noreply, recover(state, :probe, ref, held)}

      recovery =
          Enum.find(
            Map.values(state.tokens) ++ Map.values(state.probes),
            &(&1[:recovery_monitor] == monitor)
          ) ->
        {:noreply, put_in(state.groups[recovery.key].lifecycle, :failed)}

      true ->
        {:noreply, state}
    end
  end

  def handle_info({:recovered, kind, ref, recovery, :ok}, state) do
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

  def handle_info({:recovered, kind, ref, recovery, {:error, _}}, state) do
    held = if kind == :selection, do: state.tokens[ref], else: state.probes[ref]

    if held && held[:recovery] == recovery,
      do: {:noreply, put_in(state.groups[held.key].lifecycle, :failed)},
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

    {pin, %{state | pins: Map.put(state.pins, ref, record)}}
  end

  defp remove_pin(state, ref) do
    case Map.pop(state.pins, ref) do
      {nil, _} ->
        state

      {pin, pins} ->
        if pin.timer, do: Process.cancel_timer(pin.timer)
        Process.demonitor(pin.monitor, [:flush])
        Enum.reduce(pin.keys, %{state | pins: pins}, &reconcile(&2, &1))
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
    pins = Enum.filter(Map.values(state.pins), &(group_key in &1.keys))
    retiring = not Enum.any?(pins, &(&1.kind in [:baseline, :preparation]))

    group =
      if retiring and group.lifecycle != :failed, do: %{group | lifecycle: :retiring}, else: group

    if retiring do
      Enum.each(state.probes, fn {_, probe} ->
        if probe.key == group_key, do: Probe.cancel(probe.pid)
      end)
    end

    if pins == [] and group.inflight == 0 and
         not Enum.any?(state.probes, fn {_, p} -> p.key == group_key end) do
      %{state | groups: Map.delete(state.groups, group_key), bytes: state.bytes - group.bytes}
    else
      put_in(state.groups[group_key], group)
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
        do: launch_group_probe(acc, selected, group),
        else: launch_h1_probe(acc, group_key, index, selected, group)
    end)
  end

  defp launch_group_probe(state, selected, group) do
    health = group.compiled.health
    launch_now = Lifecycle.now()

    with true <- probe_selected?(selected, true) and probe_health?(health, true),
         true <- launch_now >= @signed_min and launch_now <= @signed_max,
         budget = min(health.timeout, min(selected.config.limits.opening_timeout,
                                         selected.config.limits.max_lifetime)),
         deadline = launch_now + budget,
         true <- deadline >= @signed_min and deadline <= @signed_max - 1_000,
         args = %{owner: self(), token: make_ref(), member: selected, deadline: deadline,
                  health: health, url: selected.config.uri.scheme <> "://" <>
                    selected.config.uri.authority <> health.path, group: group.handle},
         {:ok, _args} <- probe_start_arguments(args) do
      case apply(Gaoxy.Proxy.ManagedH2GroupBoundary, :activation, []) do
        {:error, :accounting_not_ready} -> state
        # Future activation still requires separately accounted H2 admission;
        # this branch cannot use the H1 reservation or start with zero bytes.
        :ok -> state
      end
    else
      _ -> state
    end
  end

  defp launch_h1_probe(state, group_key, index, selected, group) do
    url = URI.to_string(%{selected.config.uri | path: group.compiled.health.path})
    token = make_ref()
    deadline = Lifecycle.deadline(group.compiled.health.timeout)

    args = %{owner: self(), token: token, member: selected, deadline: deadline,
             health: group.compiled.health, url: url}

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
end
