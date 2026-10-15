defmodule Gaoxy.Proxy.HTTP.Session do
  @moduledoc false
  use GenServer, restart: :temporary
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.HTTP
  alias Gaoxy.Proxy.{ManagedH2Envelope, ManagedH2GroupAccounting, ManagedH2GroupBoundary}
  alias Gaoxy.Proxy.UpstreamGroups
  alias Gaoxy.Proxy.UpstreamTransports
  alias Gaoxy.HTTP.Resources
  @poll_ms 5
  @h2 Gaoxy.Proxy.ManagedH2Client
  @signed_max 9_223_372_036_854_775_807
  @group_flat_reasons ~w(invalid_request invalid_policy invalid_response upstream_failure upstream_task
                        upstream_delivery_limit upstream_delivery_overlap upstream_trailer_limit timeout
                        request_timeout unavailable cancelled cleanup_pending cleanup_unconfirmed
                        invalid_resource invalid_resource_pin invalid_transport_endpoint unauthorized
                        retiring resource_unavailable)a

  def start_link(args), do: GenServer.start_link(__MODULE__, args)
  def cancel(pid), do: GenServer.cast(pid, :cancel)
  def expire(pid), do: GenServer.cast(pid, :expire)
  def consumed(pid), do: GenServer.cast(pid, :consumed)
  def acknowledge(pid, ref), do: GenServer.cast(pid, {:acknowledge, ref})

  @impl true
  def init(args) do
    case validate_group_start(args) do
      :ok -> init_session(args)
      {:error, reason} -> {:stop, reason}
    end
  end

  defp validate_group_start(args) do
    if is_map(args) and group_intent?(args) do
      with {:ok, _} <- ManagedH2GroupAccounting.startup(__MODULE__, args),
           :ok <- preflight_monitors([args.owner, args.service, args.instance, args.gate]),
           :ok <- ManagedH2GroupAccounting.preflight_control(:cleanup_cancel, args.deadline + 1_000) do
        :ok
      end
    else
      :ok
    end
  end

  defp init_session(args) do
    Process.flag(:trap_exit, true)

    monitors =
      for pid <- Enum.uniq([args.owner, args.service, args.instance, args.gate]),
          into: %{},
          do: {Process.monitor(pid), pid}

    state =
      Map.merge(args, %{
        monitors: monitors,
        client: HTTP.selected_client(args.config),
        cleanup_deadline: nil,
        cleanup_requested_deadline: nil,
        cleanup_started: false,
        opening_timer: nil,
        activated_at: nil,
        opening_deadline: nil,
        total_timer: nil,
        selection: nil,
        transport_handoff: Map.get(args, :transport_handoff),
        awaiting_transport: nil,
        transport_pins: [],
        transport_selection: nil,
        managed_transport: nil,
        managed_path: HTTP.selected_client(args.config) == @h2,
        submitted_url: nil,
        poll_timer: nil,
        original_request: nil,
        outcome: :cancelled,
        token: nil,
        request: nil,
        headers: false,
        delivery: nil,
        trailers: [],
        cancelled: false,
        consumed: false
      })

    result =
      if group_intent?(state),
        do: ManagedH2GroupAccounting.validate({:state, :session}, state),
        else: :ok

    case result do
      :ok ->
        {:ok, state}

      {:error, reason} ->
        Enum.each(monitors, fn {ref, _} -> Process.demonitor(ref, [:flush]) end)
        {:stop, reason}
    end
  end

  @impl true
  def handle_cast(:cancel, state), do: settle(mark_cancelled(state))

  def handle_cast(:expire, %{cancelled: true} = state), do: settle(state)
  def handle_cast(:expire, %{consumed: true} = state), do: settle(state)

  def handle_cast(:expire, state) do
    reason =
      if (state.client == Gaoxy.Proxy.HTTP3SessionClient or group_intent?(state)) and
           Lifecycle.remaining(state.deadline) == 0,
         do: :request_timeout,
         else: :timeout

    fail(state, reason)
  end

  def handle_cast(:consumed, %{cancelled: true} = state), do: settle(state)
  def handle_cast(:consumed, state), do: settle(%{state | consumed: true, outcome: :success})

  def handle_cast(
        {:acknowledge, ref},
        %{delivery: ref, cancelled: false, consumed: false} = state
      ) do
    case state.client.acknowledge(state.request, ref) do
      :ok -> {:noreply, %{state | delivery: nil}}
      {:ok, request} -> {:noreply, %{state | request: request, delivery: nil}}
    end
  end

  def handle_cast(_, state), do: {:noreply, state}

  @impl true
  def handle_info({:gaoxy_cleanup_activate, token}, %{token: nil} = state) do
    activated_at = Lifecycle.now()
    opening_deadline = min(state.deadline, activated_at + state.config.limits.opening_timeout)

    state = %{
      state
      | token: token,
        activated_at: activated_at,
        opening_deadline: opening_deadline,
        opening_timer:
          Process.send_after(self(), :opening_expired, Lifecycle.remaining(opening_deadline)),
        total_timer:
          Process.send_after(self(), :total_expired, Lifecycle.remaining(state.deadline))
    }

    cond do
      state.cancelled ->
        settle(state)

      not state.client.host_supported?() ->
        fail(state, :unsupported_http_proxy_host)

      Lifecycle.remaining(state.deadline) <= 0 ->
        fail(state, :timeout)

      true ->
        case select(state) do
          {:ok, state, config} -> open_selected(state, config)
          {:await, state} -> {:noreply, state}
          {:error, reason, state} -> fail(state, reason)
          {:error, reason} -> fail(state, reason)
        end
    end
  end

  def handle_info(
        {:gaoxy_transport_handoff, ref, {:ok, pin}, deadline},
        %{transport_handoff: ref, awaiting_transport: %{handle: handle, member: selected}} = state
      ) do
    with true <- signed_time?(deadline) and deadline <= @signed_max - 1_000,
         :ok <- selected_aliases(state, selected, false),
         true <- HTTP.captured_resources?([pin], [handle]) and Map.get(pin, :handles) == [handle] do
      resumed = %{
        state
        | transport_pins: [pin],
          awaiting_transport: nil,
          deadline: min(state.deadline, deadline),
          opening_deadline: min(state.opening_deadline, deadline)
      }

      with {:ok, limits, total, opening} <- group_timing(resumed, selected, Lifecycle.now()) do
        resumed = %{
          resumed
          | config: %{resumed.config | limits: limits},
            deadline: total,
            opening_deadline: opening
        }

        resumed = apply_group_timers(state, resumed)

        case checkout_group_transport(resumed, selected, [pin], opening) do
          {:ok, resumed, selected} -> open_selected(resumed, selected)
          {:error, reason, resumed} -> local_group_fail(resumed, reason)
        end
      else
        {:error, reason} -> local_group_fail(resumed, reason)
      end
    else
      {:error, reason} -> local_group_fail(state, reason)
      _ -> local_group_fail(state, :invalid_resource_pin)
    end
  end

  def handle_info(
        {:gaoxy_transport_handoff, ref, {:error, reason}, deadline},
        %{transport_handoff: ref, awaiting_transport: %{member: selected}} = state
      ) do
    with true <- signed_time?(deadline) and deadline <= @signed_max - 1_000,
         :ok <- selected_aliases(state, selected, false) do
      state = %{
        state
        | awaiting_transport: nil,
          deadline: min(state.deadline, deadline),
          opening_deadline: min(state.opening_deadline, deadline)
      }

      local_group_fail(state, reason)
    else
      _ -> local_group_fail(state, :invalid_request)
    end
  end

  def handle_info(
        {:gaoxy_transport_handoff, ref, {:ok, pin}, deadline},
        %{transport_handoff: ref, awaiting_transport: %{handle: handle, config: config}} = state
      )
      when is_integer(deadline) do
    if group_intent?(state) do
      local_group_fail(state, :invalid_request)
    else
      if (state.client != @h2 or signed_time?(deadline)) and
           HTTP.captured_resources?([pin], [handle]) and Map.get(pin, :handles) == [handle] do
        state = %{
          state
          | transport_pins: [pin],
            awaiting_transport: nil,
            deadline: min(state.deadline, deadline),
            opening_deadline: min(state.opening_deadline, deadline)
        }

        if state.cancelled or Lifecycle.remaining(state.opening_deadline) <= 0 do
          fail(state, :timeout)
        else
          case checkout_transport(state, config, [pin], state.opening_deadline) do
            {:ok, state, config} -> open_selected(state, config)
            {:error, reason, state} -> fail(state, reason)
          end
        end
      else
        fail(%{state | awaiting_transport: nil}, :invalid_resource_pin)
      end
    end
  end

  def handle_info(
        {:gaoxy_transport_handoff, ref, {:error, reason}, deadline},
        %{transport_handoff: ref, awaiting_transport: awaiting} = state
      )
      when not is_nil(awaiting) and is_integer(deadline) do
    if state.client != @h2 or signed_time?(deadline),
      do:
        fail(%{state | awaiting_transport: nil, deadline: min(state.deadline, deadline)}, reason),
      else: {:noreply, state}
  end

  def handle_info({:gaoxy_transport_handoff, ref, _, _}, %{transport_handoff: ref} = state) do
    if group_intent?(state) and not is_nil(state.awaiting_transport),
      do: local_group_fail(state, :invalid_request),
      else: {:noreply, state}
  end

  def handle_info({:gaoxy_transport_handoff, _, _, _}, state), do: {:noreply, state}

  def handle_info({:gaoxy_cleanup_cancel, token, _reason, deadline}, %{token: token} = state) do
    if state.client != @h2 or signed_time?(deadline) do
      state = %{state | cleanup_requested_deadline: deadline}
      settle(mark_cancelled(state))
    else
      {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, pid, _}, state) when is_map_key(state.monitors, ref) do
    if state.client != @h2 or state.monitors[ref] == pid,
      do: settle(mark_cancelled(state)),
      else: {:noreply, state}
  end

  def handle_info(event, %{cancelled: true} = state)
      when event in [:opening_expired, :total_expired],
      do: settle(state)

  def handle_info(event, %{consumed: true} = state)
      when event in [:opening_expired, :total_expired],
      do: settle(state)

  def handle_info(:opening_expired, %{awaiting_transport: awaiting} = state)
      when not is_nil(awaiting),
      do: fail(state, :timeout)

  def handle_info(:opening_expired, %{headers: false} = state) do
    if group_intent?(state) and is_nil(state.original_request),
      do: local_group_fail(state, :timeout),
      else: upstream_fail(state, :timeout)
  end

  def handle_info(:opening_expired, state), do: {:noreply, state}

  def handle_info(:total_expired, %{client: Gaoxy.Proxy.HTTP3SessionClient} = state),
    do: fail(state, :request_timeout)

  def handle_info(:total_expired, state) do
    if group_intent?(state),
      do: local_group_fail(state, :request_timeout),
      else: fail(state, :timeout)
  end

  def handle_info(:poll, %{request: nil} = state), do: settle(state)
  def handle_info(:poll, %{cancelled: true} = state), do: settle(state)
  def handle_info(:poll, %{consumed: true} = state), do: settle(state)

  def handle_info(:poll, state) do
    state = cancel_poll(state)
    {event, request} = state.client.poll_headers(callback_request(state))
    dispatch(event, %{state | request: request})
  end

  def handle_info(message, %{request: request} = state) when not is_nil(request) do
    {event, request} = state.client.event(callback_request(%{state | request: request}), message)
    dispatch(event, %{state | request: request})
  end

  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def handle_continue(:group_open, state) do
    with :ok <- account_state(state),
         {:ok, options} <- staged_group_options(state),
         :ok <- account(state, :options, options),
         :clear <- queued_group_terminal(state),
         now = Lifecycle.now(),
         :ok <- group_local_status(state, state.deadline, state.opening_deadline, now) do
      options = %{
        options
        | timeout: state.deadline - now,
          opening_timeout: state.opening_deadline - now
      }

      state = %{state | request_options: {:group_prepared, options}}

      # No caller, configuration or pure profile marker can enable this branch.
      # The queued-terminal check above precedes this group open boundary.
      # Keep the staged consumer compilable with the literal denial installed.
      # This public callee and its arguments are fixed, with no override.
      case apply(ManagedH2GroupBoundary, :activation, []) do
        :ok ->
          raw_result = @h2.open(options)

          case group_open_result(state, raw_result, Lifecycle.now()) do
            {:ok, bind_state, {:group_bind, upload}} ->
              {:noreply, bind_state, {:continue, {:group_bind, upload}}}

            {:error, {:cleanup_unconfirmed, _} = reason, dropped} ->
              group_cleanup_unconfirmed(dropped, reason)

            {:error, reason, dropped} ->
              case raw_result do
                {:error, _} -> upstream_fail(dropped, reason)
                _ -> local_group_fail(dropped, reason)
              end
          end

        {:error, :accounting_not_ready} ->
          local_group_fail(drop_group_opening(state), :unavailable)
      end
    else
      {:handled, result} -> result
      {:error, reason} -> local_group_fail(drop_group_opening(state), reason)
    end
  end

  def handle_continue({:group_bind, upload}, state) do
    with :ok <- account_state(state),
         true <- is_pid(upload) or is_nil(upload),
         true <- sanitized_group_controls?(state),
         true <- state.request_options == nil,
         true <- valid_group_handle?(state.original_request),
         true <- state.request === state.original_request,
         true <- is_binary(state.submitted_url) and byte_size(state.submitted_url) in 1..65_536,
         true <-
           :binary.referenced_byte_size(state.submitted_url) == byte_size(state.submitted_url),
         :clear <- queued_group_terminal(state),
         :ok <- group_local_status(state, state.deadline, state.opening_deadline, Lifecycle.now()) do
      # bind/1 preserves the original public completion and binds transport first.
      case bind(state) do
        :ok ->
          notify(state, {:ready, upload, state.config.limits, state.deadline})
          {:noreply, schedule(state)}

        {:error, reason} ->
          fail(drop_group_opening(state), reason)
      end
    else
      {:handled, result} -> result
      {:error, reason} -> local_group_fail(drop_group_opening(state), reason)
      _ -> local_group_fail(drop_group_opening(state), :invalid_request)
    end
  end

  # One pending recognized event wins in mailbox order. Unmatched traffic and
  # later terminal events stay queued; the scan itself has no size/time bound.
  defp queued_group_terminal(state) do
    token = state.token
    monitors = state.monitors

    receive do
      {:"$gen_cast", event} when event in [:cancel, :expire, :consumed] ->
        {:handled, handle_cast(event, drop_group_opening(state))}

      {:gaoxy_cleanup_cancel, ^token, _reason, deadline} = event
      when is_integer(deadline) and deadline >= -9_223_372_036_854_775_808 and
             deadline <= @signed_max ->
        {:handled, handle_info(event, drop_group_opening(state))}

      {:DOWN, ref, :process, pid, _reason} = event
      when is_reference(ref) and is_pid(pid) and is_map_key(monitors, ref) and
             :erlang.map_get(ref, monitors) === pid ->
        {:handled, handle_info(event, drop_group_opening(state))}

      event when event in [:opening_expired, :total_expired] ->
        {:handled, handle_info(event, drop_group_opening(state))}
    after
      0 -> :clear
    end
  end

  @doc false
  def prepare_group_open(state, selected, now) do
    if group_intent?(state) do
      with :ok <- account_state(state),
           :ok <- account(state, :selected, selected),
           :ok <- account(state, :neutral, state.request_options),
           :ok <- account(state, :checked, state.managed_transport),
           :ok <- selected_aliases(state, selected, true),
           {:ok, limits, deadline, opening_deadline} <- group_timing(state, selected, now),
           context = %{group: state.config.group, instance: state.instance, limits: limits,
             deadline: deadline, opening_deadline: opening_deadline, now: now},
           :ok <- account(state, :context, context),
           {:ok, options, effective_limits} <- ManagedH2GroupBoundary.prepare(
             selected, state.request_options, state.managed_transport, context),
           :ok <- account(state, :request, options.request),
           :ok <- account(state, :options, options) do
        staged = %{drop_group_opening(state) | config: %{limits: effective_limits},
          request_options: {:group_prepared, options}, deadline: deadline, opening_deadline: opening_deadline}
        case account_state(staged) do
          :ok -> {:ok, staged, :group_open}
          _ -> {:error, :invalid_request, drop_group_opening(state)}
        end
      else
        {:error, reason} when reason in [:cancelled, :request_timeout, :timeout] ->
          {:error, reason, drop_group_opening(state)}
        _ -> {:error, :invalid_request, drop_group_opening(state)}
      end
    else
      {:error, :invalid_request, drop_group_opening(state)}
    end
  end

  @doc false
  def drop_group_opening(state) do
    if group_intent?(state) do
      limits = Map.get(state.config, :limits)
      limits = if valid_group_limits?(limits), do: limits, else: nil

      %{
        state
        | config: %{limits: limits},
          request_options: nil,
          managed_transport: nil,
          selector: nil,
          awaiting_transport: nil,
          transport_handoff: nil,
          submitted_url: nil,
          client: @h2,
          managed_path: true
      }
    else
      state
    end
  end

  @doc false
  def group_open_result(state, result, now) do
    if group_intent?(state) do
      # Supported original authority is owed cleanup even if another result
      # field or the retained source is invalid. Never replace it with a copy.
      captured = capture_group_result(state, result)
      with :ok <- account_state(state),
           {:ok, options} <- staged_group_options(state),
           :ok <- account(state, :options, options) do
        group_result(captured, options, result, now)
      else
        _ -> {:error, :invalid_request, drop_group_opening(captured)}
      end
    else
      {:error, :invalid_request, drop_group_opening(state)}
    end
  end

  defp capture_group_result(state, result)
       when is_tuple(result) and tuple_size(result) >= 2 and elem(result, 0) == :ok do
    handle = elem(result, 1)
    case ManagedH2GroupAccounting.validate(:open_result, {:ok, handle, nil}) do
      :ok -> %{state | request: handle, original_request: handle}
      _ -> state
    end
  end
  defp capture_group_result(state, _), do: state

  defp group_result(state, options, {:ok, handle, upload}, now) do
    if ManagedH2GroupAccounting.validate(:open_result, {:ok, handle, upload}) == :ok do
      # Capture the original supported completion before any late-open decision.
      state = %{state | request: handle, original_request: handle}

      case group_local_status(state, state.deadline, state.opening_deadline, now) do
        :ok ->
          bound = %{drop_group_opening(state) | submitted_url: options.request.url}
          case account_state(bound) do
            :ok -> {:ok, bound, {:group_bind, upload}}
            _ -> {:error, :invalid_request, drop_group_opening(state)}
          end

        {:error, reason} ->
          {:error, reason, drop_group_opening(state)}
      end
    else
      {:error, {:cleanup_unconfirmed, :invalid_response}, drop_group_opening(state)}
    end
  end

  defp group_result(state, _options, {:error, :cleanup_unconfirmed}, _now),
    do: {:error, {:cleanup_unconfirmed, :cleanup_unconfirmed}, drop_group_opening(state)}

  defp group_result(state, _options, {:error, {:cleanup_unconfirmed, _} = reason}, _now),
    do: {:error, group_open_reason(reason), drop_group_opening(state)}

  defp group_result(state, _options, {:error, reason}, now) do
    case group_local_status(state, state.deadline, state.opening_deadline, now) do
      :ok -> {:error, group_open_reason(reason), drop_group_opening(state)}
      {:error, reason} -> {:error, reason, drop_group_opening(state)}
    end
  end

  defp group_result(state, _options, result, _now)
       when is_tuple(result) and tuple_size(result) > 0 and elem(result, 0) == :ok,
       do: {:error, {:cleanup_unconfirmed, :invalid_response}, drop_group_opening(state)}

  defp group_result(state, _options, _result, _now),
    do: {:error, :invalid_response, drop_group_opening(state)}

  defp group_open_reason(:cleanup_unconfirmed), do: {:cleanup_unconfirmed, :cleanup_unconfirmed}

  defp group_open_reason({:cleanup_unconfirmed, cause}) do
    cause = if cause in @group_flat_reasons, do: cause, else: :cleanup_unconfirmed
    {:cleanup_unconfirmed, cause}
  end

  defp group_open_reason(reason), do: finite_reason(reason)

  defp valid_group_handle?(handle) do
    completion = @h2.completion(handle)

    is_struct(completion, Elixir.HTTP.RequestCompletion) and map_size(completion) == 4 and
      completion === handle.completion
  end

  defp account(state, selector, original) do
    if group_intent?(state), do: ManagedH2GroupAccounting.validate(selector, original), else: :ok
  end
  defp account_state(state), do: account(state, {:state, :session}, state)
  defp preflight_monitors(pids) do
    Enum.reduce_while(pids, :ok, fn pid, :ok ->
      case ManagedH2GroupAccounting.preflight_control(:monitor, pid) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp classify_group(state, selected) do
    if group_intent?(state) or (group_payload?(state) and h2_member?(selected)),
      do: %{state | client: @h2, managed_path: true},
      else: state
  end

  defp group_intent?(state) do
    match?(%{config: %{group: %{execution_profile: :managed_h2}}}, state) or
      profile_group?(selector_group(Map.get(state, :selector))) or
      profile_group?(selection_group(Map.get(state, :selection))) or
      awaiting_h2_member?(Map.get(state, :awaiting_transport)) or
      (Map.get(state, :client) == @h2 and group_payload?(state))
  end

  defp group_payload?(state),
    do:
      match?(%{config: %{group: _}}, state) or
        match?({:group, _, _}, Map.get(state, :selector)) or
        match?({_, _}, Map.get(state, :selection)) or
        match?(%{member: _}, Map.get(state, :awaiting_transport))

  defp profile_group?(%{execution_profile: :managed_h2}), do: true
  defp profile_group?(_), do: false
  defp selector_group({:group, group, _}), do: group
  defp selector_group(_), do: nil
  defp selection_group({group, _}), do: group
  defp selection_group(_), do: nil
  defp awaiting_h2_member?(%{member: member}), do: h2_member?(member)
  defp awaiting_h2_member?(_), do: false

  defp h2_member?(%{config: config}) when is_map(config),
    do: Map.get(config, :upstream_protocol) in [:http2, :h2c] or Map.get(config, :client) == @h2

  defp h2_member?(_), do: false

  defp selected_shape?(%{id: id, config: config, max_inflight: max} = selected)
       when map_size(selected) == 3 and is_binary(id) and byte_size(id) in 1..128 and
              is_integer(max) and max in 1..1024 do
    :binary.referenced_byte_size(id) == byte_size(id) and
      ManagedH2Envelope.validate_config(config) == :ok
  end

  defp selected_shape?(_), do: false

  defp selected_aliases(state, selected, checked?) do
    with true <- selected_shape?(selected),
         %{group: group} <- state.config,
         true <- group_shape?(group),
         {:group, ^group, pins} when is_list(pins) <- state.selector,
         {^group, token} when is_reference(token) <- state.selection,
         transport = selected.config.transport,
         true <- transport in group.transports,
         true <- awaiting_alias?(state.awaiting_transport, transport, selected),
         true <- transport_alias?(state.transport_selection, transport, checked?),
         true <- pin_alias?(state.transport_pins, transport, checked?) do
      :ok
    else
      _ -> {:error, :invalid_request}
    end
  end

  defp awaiting_alias?(nil, _, _), do: true

  defp awaiting_alias?(%{handle: transport, member: selected} = awaiting, transport, selected),
    do: map_size(awaiting) == 2

  defp awaiting_alias?(_, _, _), do: false

  defp transport_alias?(nil, _, false), do: true
  defp transport_alias?({transport, token}, transport, _), do: is_reference(token)
  defp transport_alias?(_, _, _), do: false

  defp pin_alias?([], _, false), do: true

  defp pin_alias?(
         [
           %{
             provider: UpstreamTransports,
             owner: owner,
             owner_epoch: epoch,
             operation: operation,
             ref: ref,
             handles: [transport],
             kind: :request,
             holder: holder
           } = pin
         ],
         %{owner: owner, owner_epoch: epoch} = transport,
         _
       ) do
    map_size(pin) == 8 and is_reference(operation) and is_reference(ref) and is_pid(holder)
  end

  defp pin_alias?(_, _, _), do: false

  defp group_shape?(
         %{
           provider: UpstreamGroups,
           owner: owner,
           owner_epoch: epoch,
           group: id,
           generation: generation,
           max_url_bytes: cap,
           transports: transports,
           execution_profile: :managed_h2
         } = group
       )
       when map_size(group) == 8 and is_pid(owner) and is_reference(epoch) and
              is_reference(generation) and is_binary(id) and byte_size(id) in 1..128 and
              is_integer(cap) and cap in 1..8192 do
    :binary.referenced_byte_size(id) == byte_size(id) and
      group_transports?(transports, [], 0) and
      :erlang.external_size([group | transports]) <= 65_536
  end

  defp group_shape?(_), do: false

  defp group_transports?([], _, count), do: count in 1..32

  defp group_transports?([transport | rest], seen, count) when count < 32 do
    transport_shape?(transport) and transport not in seen and
      group_transports?(rest, [transport | seen], count + 1)
  end

  defp group_transports?(_, _, _), do: false

  defp transport_shape?(
         %{provider: UpstreamTransports, owner: owner, owner_epoch: epoch, resource: resource} =
           transport
       ),
       do:
         map_size(transport) == 4 and is_pid(owner) and is_reference(epoch) and
           is_reference(resource)

  defp transport_shape?(_), do: false

  defp valid_group_limits?(limits) when is_map(limits) and map_size(limits) == 5 do
    case limits do
      %{
        max_chunk_bytes: chunk,
        opening_timeout: opening,
        idle_timeout: idle,
        write_timeout: write,
        max_lifetime: lifetime
      } ->
        is_integer(chunk) and chunk in 1..65_536 and
          Enum.all?([opening, idle, write, lifetime], &(is_integer(&1) and &1 in 1..86_400_000))

      _ ->
        false
    end
  end

  defp valid_group_limits?(_), do: false

  defp group_timing(state, selected, now) do
    with true <- valid_group_limits?(state.config.limits),
         true <-
           Enum.all?(
             [state.started_at, state.activated_at, state.deadline, state.opening_deadline, now],
             &signed_time?/1
           ),
         limits =
           Map.new(state.config.limits, fn {key, n} ->
             {key, min(n, selected.config.limits[key])}
           end),
         anchored_total = state.started_at + limits.max_lifetime,
         anchored_opening = state.activated_at + limits.opening_timeout,
         true <- signed_time?(anchored_total) and signed_time?(anchored_opening),
         deadline = min(state.deadline, anchored_total),
         opening = min(state.opening_deadline, min(deadline, anchored_opening)),
         true <- deadline <= @signed_max - 1_000,
         :ok <- group_local_status(state, deadline, opening, now) do
      {:ok, limits, deadline, opening}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_request}
    end
  end

  defp group_local_status(state, deadline, opening, now) do
    cond do
      not Enum.all?([deadline, opening, now], &signed_time?/1) ->
        {:error, :invalid_request}

      deadline > @signed_max - 1_000 or opening > deadline ->
        {:error, :invalid_request}

      not signed_time?(deadline - now) or not signed_time?(opening - now) ->
        {:error, :invalid_request}

      not is_boolean(state.cancelled) or not is_boolean(state.consumed) ->
        {:error, :invalid_request}

      state.cancelled or state.consumed ->
        {:error, :cancelled}

      deadline <= now ->
        {:error, :request_timeout}

      opening <= now ->
        {:error, :timeout}

      deadline - now > 86_400_000 or opening - now > 86_400_000 ->
        {:error, :invalid_request}

      true ->
        :ok
    end
  end

  defp staged_group_options(%{request_options: {:group_prepared, options}} = state)
       when is_map(options) and map_size(options) == 7 do
    with %{
           request: request,
           managed_transport: checked,
           timeout: timeout,
           opening_timeout: opening_timeout,
           write_timeout: write_timeout,
           deadline: deadline,
           opening_deadline: opening_deadline
         } <- options,
         true <- sanitized_group_controls?(state),
         true <-
           state.request == nil and state.original_request == nil and state.submitted_url == nil,
         :ok <- ManagedH2Envelope.validate_request(request),
         :ok <- ManagedH2Envelope.validate_checked_client(checked, request.protocol),
         uri = URI.parse(request.url),
         true <- checked_origin?(checked, request.protocol, uri),
         group = elem(state.selection, 0),
         true <- byte_size(uri.scheme) + 3 + byte_size(uri.authority) <= group.max_url_bytes,
         true <- group.max_url_bytes + byte_size(request.target) <= 65_536,
         true <- deadline === state.deadline and opening_deadline === state.opening_deadline,
         true <-
           Enum.all?(
             [timeout, opening_timeout, write_timeout],
             &(is_integer(&1) and &1 in 1..86_400_000)
           ),
         true <- opening_timeout <= timeout,
         true <-
           timeout <= state.config.limits.max_lifetime and
             opening_timeout <= state.config.limits.opening_timeout,
         true <- write_timeout == state.config.limits.write_timeout,
         true <- request.max_upload_bytes <= state.config.limits.max_chunk_bytes do
      {:ok, options}
    else
      _ -> {:error, :invalid_request}
    end
  end

  defp staged_group_options(_), do: {:error, :invalid_request}

  defp sanitized_group_controls?(state) do
    with %{limits: limits} when map_size(state.config) == 1 <- state.config,
         true <- valid_group_limits?(limits),
         true <- state.client == @h2 and state.managed_path == true,
         true <-
           state.selector == nil and state.awaiting_transport == nil and
             state.transport_handoff == nil and state.managed_transport == nil,
         {group, token} when is_reference(token) <- state.selection,
         true <- group_shape?(group),
         {transport, transport_token} when is_reference(transport_token) <-
           state.transport_selection,
         true <- transport in group.transports,
         true <- pin_alias?(state.transport_pins, transport, true) do
      true
    else
      _ -> false
    end
  end

  defp checked_origin?(checked, protocol, uri) do
    policy = checked.policy
    scheme = if uri.scheme == "https", do: :https, else: :http

    {protocol, scheme, String.downcase(uri.host), uri.port} ===
      {policy.protocol, policy.scheme, policy.host, policy.port}
  end

  defp apply_group_timers(old_state, state) do
    state =
      if old_state.deadline != state.deadline or is_nil(old_state.total_timer) do
        if old_state.total_timer, do: Process.cancel_timer(old_state.total_timer)

        %{
          state
          | total_timer:
              Process.send_after(self(), :total_expired, Lifecycle.remaining(state.deadline))
        }
      else
        state
      end

    if old_state.opening_deadline != state.opening_deadline or is_nil(old_state.opening_timer) do
      if old_state.opening_timer, do: Process.cancel_timer(old_state.opening_timer)

      %{
        state
        | opening_timer:
            Process.send_after(
              self(),
              :opening_expired,
              Lifecycle.remaining(state.opening_deadline)
            )
      }
    else
      state
    end
  end

  defp local_group_fail(state, reason), do: fail(%{state | outcome: :cancelled}, reason)

  defp group_cleanup_unconfirmed(state, {:cleanup_unconfirmed, _} = reason) do
    state = drop_group_opening(state)
    # The explicit group discriminator is already finite. Legacy normalization
    # intentionally does not accept this tuple; do not pass it through notify.
    send(state.owner, {:gaoxy_proxy_http, self(), {:error, reason}})

    if state.transport_selection == nil,
      do: {:stop, reason, state},
      else: settle(%{state | cancelled: true, consumed: true})
  end

  defp open_selected(state, %{id: _, config: _, max_inflight: _} = selected) do
    case prepare_group_open(state, selected, Lifecycle.now()) do
      {:ok, staged, :group_open} ->
        {:noreply, apply_group_timers(state, staged), {:continue, :group_open}}

      {:error, reason, dropped} ->
        local_group_fail(dropped, reason)
    end
  end

  defp open_selected(state, config) do
    state = apply_limits(state, config.limits)
    state = %{state | client: HTTP.selected_client(config)}

    options = open_options(state, config)

    result =
      cond do
        options.timeout <= 0 -> {:error, :request_timeout}
        options.opening_timeout <= 0 -> {:error, :timeout}
        true -> state.client.open(options)
      end

    case result do
      {:ok, request, upload} ->
        state = %{state | request: request, original_request: request}

        case bind(state) do
          :ok ->
            state = release_opening_payloads(state)
            notify(state, {:ready, upload, state.config.limits, state.deadline})
            {:noreply, schedule(state)}

          {:error, reason} ->
            fail(state, reason)
        end

      {:error, {:cleanup_unconfirmed, _} = reason} ->
        if state.transport_selection == nil do
          notify(state, {:error, reason})
          {:stop, reason, state}
        else
          fail(state, reason)
        end

      {:error, reason} ->
        upstream_fail(state, reason)
    end
  end

  defp dispatch(_event, %{cancelled: true} = state), do: settle(state)
  defp dispatch(_event, %{consumed: true} = state), do: settle(state)

  defp dispatch({:headers, status, fields}, state) do
    Process.cancel_timer(state.opening_timer)
    notify(state, {:headers, status, fields})
    :ok = state.client.subscribe(state.request)
    state = %{cancel_poll(state) | headers: true}
    state = if state.client == @h2, do: %{state | submitted_url: nil}, else: state
    if state.request.stream == nil, do: notify(state, {:end, []})
    {:noreply, state}
  end

  defp dispatch({:chunk, bytes, ref}, %{delivery: nil, cancelled: false} = state) do
    notify(state, {:chunk, bytes, ref})
    {:noreply, %{state | delivery: ref}}
  end

  defp dispatch({:chunk, _, _}, state), do: fail(state, :upstream_delivery_overlap)
  defp dispatch({:trailers, trailers}, state), do: {:noreply, %{state | trailers: trailers}}

  defp dispatch(:end, state) do
    notify(state, {:end, state.trailers})
    {:noreply, if(state.client == @h2, do: %{state | trailers: []}, else: state)}
  end

  defp dispatch({:error, reason}, state), do: upstream_fail(state, reason)

  defp dispatch(:none, state) do
    {:noreply, if(not state.headers, do: schedule(state), else: state)}
  end

  defp fail(state, reason) do
    state = drop_group_opening(state)
    reason = normalize_reason(state, reason)
    notify(state, {:error, reason})
    settle(%{state | cancelled: true, consumed: true})
  end

  defp upstream_fail(%{cancelled: true} = state, _reason), do: settle(state)

  defp upstream_fail(state, reason) do
    outcome =
      if reason == :request_timeout or Lifecycle.remaining(state.deadline) <= 0,
        do: :cancelled,
        else: :upstream_failure

    fail(%{state | outcome: outcome}, reason)
  end

  defp mark_cancelled(%{cancelled: true} = state), do: state
  defp mark_cancelled(state), do: %{state | cancelled: true, consumed: true, outcome: :cancelled}

  defp apply_limits(state, member_limits) do
    limits =
      Map.new(state.config.limits, fn {key, value} -> {key, min(value, member_limits[key])} end)

    deadline = min(state.deadline, state.started_at + limits.max_lifetime)

    opening_deadline =
      min(state.opening_deadline, min(deadline, state.activated_at + limits.opening_timeout))

    Process.cancel_timer(state.opening_timer)
    Process.cancel_timer(state.total_timer)

    %{
      state
      | config: %{state.config | limits: limits},
        deadline: deadline,
        opening_deadline: opening_deadline,
        opening_timer:
          Process.send_after(self(), :opening_expired, Lifecycle.remaining(opening_deadline)),
        total_timer: Process.send_after(self(), :total_expired, Lifecycle.remaining(deadline))
    }
  end

  defp settle(%{token: nil, cancelled: true} = state),
    do: {:stop, :normal, drop_group_opening(state)}

  defp settle(%{token: nil} = state), do: {:noreply, drop_group_opening(state)}

  defp settle(state) do
    state = drop_group_opening(state)
    state = begin_cleanup(state)
    state = if state.client == @h2, do: %{state | submitted_url: nil}, else: state

    request =
      if state.managed_path or state.managed_transport,
        do: state.original_request,
        else: state.request

    result = if request, do: state.client.cleanup(request, state.cancelled), else: :ok

    case result do
      :ok -> cleanup_complete(state)
      {:ok, request} -> cleanup_complete(%{state | request: request})
      {:pending, request} -> cleanup_pending(%{state | request: request})
      {:error, :cleanup_pending} -> cleanup_pending(state)
      {:error, reason, request} -> cleanup_failed(%{state | request: request}, reason)
      {:error, reason} -> cleanup_failed(state, reason)
    end
  end

  defp begin_cleanup(%{cleanup_started: true} = state), do: state

  defp begin_cleanup(state) do
    deadline =
      if state.client == Gaoxy.Proxy.HTTP3SessionClient do
        deadline = min(Lifecycle.now() + 1_000, state.deadline + 1_000)

        if is_integer(state.cleanup_requested_deadline),
          do: min(deadline, state.cleanup_requested_deadline),
          else: deadline
      else
        deadline = state.deadline + 1_000

        if state.client == @h2 and is_integer(state.cleanup_requested_deadline),
          do: min(deadline, state.cleanup_requested_deadline),
          else: deadline
      end

    state = %{state | cleanup_started: true, cleanup_deadline: deadline}

    if state.request && function_exported?(state.client, :begin_cleanup, 3) do
      {:ok, request} = state.client.begin_cleanup(state.request, state.cancelled, deadline)
      %{state | request: request}
    else
      state
    end
  end

  defp cleanup_complete(state) do
    if state.consumed or state.cancelled do
      case finish_transport(state) do
        {:ok, state} ->
          case finish_selection(state) do
            :ok ->
              case complete_service(state) do
                :ok -> {:stop, :normal, state}
                {:error, reason} -> cleanup_failed(state, {:service_cleanup_failed, reason})
              end

            {:error, reason} ->
              {:stop, {:selection_cleanup_failed, reason}, state}
          end

        {:pending, state} ->
          cleanup_pending(state)

        {:error, reason, state} ->
          cleanup_failed(state, {:transport_cleanup_failed, reason})
      end
    else
      {:noreply, state}
    end
  end

  defp cleanup_pending(state) do
    if Lifecycle.remaining(state.cleanup_deadline) > 0 do
      {:noreply, schedule(state)}
    else
      {:stop, :cleanup_unconfirmed, state}
    end
  end

  defp cleanup_failed(state, reason) do
    reason = normalize_reason(state, {:cleanup_failed, reason})
    notify(state, {:error, reason})
    {:stop, reason, state}
  end

  defp select(%{selector: {:fixed, config}} = state), do: select_transport(state, config)

  defp select(%{selector: {:group, handle, pins}} = state) do
    deadline = min(state.deadline, state.opening_deadline)
    with :ok <- account_state(state),
         :ok <- account(state, {:owner_call, :group, :checkout},
           {:checkout, handle, pins, self(), %{}, deadline}) do
    case UpstreamGroups.checkout(
           handle,
           pins,
           self(),
           %{},
           min(state.deadline, state.opening_deadline)
         ) do
      {:ok, member, token} ->
        state = %{state | selection: {handle, token}}

        if group_intent?(state) or h2_member?(member),
          do: select_group_transport(classify_group(state, member), member),
          else: select_transport(state, member.config)

      {:error, reason} ->
        {:error, reason, state}
    end
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp select_group_transport(state, selected) do
    with :ok <- account_state(state),
         :ok <- account(state, :selected, selected),
         :ok <- selected_aliases(state, selected, false),
         {:ok, limits, total, opening} <- group_timing(state, selected, Lifecycle.now()) do
      config = selected.config
      handle = config.transport

      identity = %{
        origin: :binary.copy(config.uri.scheme <> "://" <> config.uri.authority),
        upstream_protocol: config.upstream_protocol,
        instance: state.instance
      }

      if is_reference(state.transport_handoff) do
        timed = %{
          state
          | config: %{state.config | limits: limits},
            deadline: total,
            opening_deadline: opening
        }

        timed = apply_group_timers(state, timed)
        waiting = %{timed | awaiting_transport: %{handle: handle, member: selected}}
        message = {:gaoxy_proxy_http, self(), {:transport_handoff, timed.transport_handoff, handle, identity, opening}}
        with :ok <- account_state(waiting),
             :ok <- account(waiting, {:control, :identity}, message),
             :ok <- account(waiting, {:control, :handoff_request}, message) do
          notify(waiting, {:transport_handoff, waiting.transport_handoff, handle, identity, opening})
          {:await, waiting}
        else
          {:error, reason} -> {:error, reason, drop_group_opening(waiting)}
        end
      else
        with :ok <- account(state, {:control, :identity}, {:validate_endpoint, handle,
               {config.upstream_protocol, if(config.uri.scheme == "https", do: :https, else: :http), config.uri.host, config.uri.port}, state.instance, opening}),
             :ok <- UpstreamTransports.validate_endpoint(handle, identity, opening),
             {:ok, pins} <- Resources.pin_many([handle], self(), :request, opening) do
          checkout_group_transport(%{state | transport_pins: pins}, selected, pins, opening)
        else
          {:error, reason} -> {:error, reason, drop_group_opening(state)}
        end
      end
    else
      {:error, reason} -> {:error, reason, drop_group_opening(state)}
    end
  end

  defp checkout_group_transport(state, selected, pins, deadline) do
    handle = selected.config.transport

    with :ok <- account_state(state),
         :ok <- selected_aliases(state, selected, false),
         true <- HTTP.captured_resources?(pins, [handle]),
         :ok <- account(state, :captured_pins, pins),
         :ok <- account(state, {:owner_call, :transport, :checkout}, {:checkout, handle, pins, self(), deadline}) do
      case UpstreamTransports.checkout(handle, pins, self(), deadline) do
        {:ok, client, token} ->
          state = %{state | transport_selection: {handle, token}, managed_transport: client}

          with :ok <-
                 ManagedH2Envelope.validate_checked_client(
                   client,
                   selected.config.upstream_protocol
                 ),
               true <-
                 checked_origin?(client, selected.config.upstream_protocol, selected.config.uri),
               :ok <- selected_aliases(state, selected, true),
               :ok <- account(state, :checked, client),
               :ok <- account_state(state) do
            # The exact owner Selected and raw member URI survive checkout.
            {:ok, state, selected}
          else
            _ -> {:error, :invalid_request, drop_group_opening(state)}
          end

        {:error, reason} ->
          case Resources.release(pins) do
            :ok ->
              {:error, reason, drop_group_opening(%{state | transport_pins: []})}

            {:error, release_reason} ->
              {:error, {:pin_release_failed, release_reason}, drop_group_opening(state)}
          end
      end
    else
      _ -> {:error, :invalid_resource_pin, drop_group_opening(state)}
    end
  end

  defp select_transport(state, %HTTP{transport: nil} = config), do: {:ok, state, config}

  defp select_transport(%{transport_handoff: ref} = state, %HTTP{transport: handle} = config)
       when is_reference(ref) do
    state = apply_limits(state, config.limits)

    identity = %{
      origin: URI.to_string(config.uri),
      upstream_protocol: config.upstream_protocol,
      instance: state.instance
    }

    notify(state, {:transport_handoff, ref, handle, identity, state.opening_deadline})
    {:await, %{state | awaiting_transport: %{handle: handle, config: config}}}
  end

  defp select_transport(state, %HTTP{transport: handle} = config) do
    deadline = min(state.deadline, state.opening_deadline)

    identity = %{
      origin: URI.to_string(config.uri),
      upstream_protocol: config.upstream_protocol,
      instance: state.instance
    }

    with :ok <- UpstreamTransports.validate_endpoint(handle, identity, deadline),
         {:ok, pins} <- Resources.pin_many([handle], self(), :request, deadline) do
      state = %{state | transport_pins: pins}
      checkout_transport(state, config, pins, deadline)
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp checkout_transport(state, %HTTP{transport: handle} = config, pins, deadline) do
    case UpstreamTransports.checkout(handle, pins, self(), deadline) do
      {:ok, client, token} ->
        state = %{state | transport_selection: {handle, token}, managed_transport: client}

        opening_config =
          if state.client == @h2,
            do: config,
            else: %{config | uri: URI.parse(client.policy.origin)}

        {:ok, state, opening_config}

      {:error, reason} ->
        case Resources.release(pins) do
          :ok ->
            {:error, reason, %{state | transport_pins: []}}

          {:error, release_reason} ->
            {:error, {:transport_pin_release_failed, reason, release_reason}, state}
        end
    end
  end

  defp bind(%{transport_selection: nil} = state), do: bind_selection(state)

  defp bind(%{transport_selection: {handle, token}, original_request: request} = state) do
    completion = state.client.completion(request)
    with :ok <- account_state(state),
         :ok <- account(state, {:owner_call, :transport, :bind}, {:bind_completion, handle, token, completion}),
         :ok <- UpstreamTransports.bind_completion(handle, token, completion),
         do: bind_selection(state)
  end

  defp bind_selection(%{selection: nil}), do: :ok

  defp bind_selection(%{selection: {handle, token}, original_request: request} = state) do
    completion = state.client.completion(request)
    with :ok <- account(state, {:owner_call, :group, :bind}, {:bind, handle, token, completion}),
      do: UpstreamGroups.bind_completion(handle, token, completion)
  end

  defp finish_transport(%{transport_selection: nil} = state), do: release_transport_pins(state)

  defp finish_transport(%{transport_selection: {handle, token}} = state) do
    with :ok <- account_state(state),
         :ok <- account(state, {:owner_call, :transport, :finish}, {:finish, handle, token}) do
    case UpstreamTransports.finish(handle, token) do
      :ok -> release_transport_pins(%{state | transport_selection: nil})
      {:error, :cleanup_pending} -> {:pending, state}
      {:error, reason} -> {:error, reason, state}
    end
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp release_transport_pins(state) do
    case Resources.release(state.transport_pins) do
      :ok -> {:ok, %{state | transport_pins: []}}
      {:error, reason} -> {:error, {:pin_release_failed, reason}, state}
    end
  end

  defp complete_service(%{managed_path: true} = state),
    do: Gaoxy.Service.complete_cleanup(state.service, state.token)

  defp complete_service(%{managed_transport: nil} = state) do
    _ = Gaoxy.Service.complete_cleanup(state.service, state.token)
    :ok
  end

  defp complete_service(state), do: Gaoxy.Service.complete_cleanup(state.service, state.token)

  defp finish_selection(%{selection: nil}), do: :ok

  defp finish_selection(%{selection: {handle, token}} = state) do
    with :ok <- account_state(state),
         :ok <- account(state, {:owner_call, :group, :finish}, {:finish, handle, token, state.outcome}),
      do: UpstreamGroups.finish(handle, token, state.outcome)
  end

  defp open_options(%{client: @h2} = state, _config) do
    %{
      request: state.request_options,
      managed_transport: state.managed_transport,
      timeout: Lifecycle.remaining(state.deadline),
      opening_timeout: Lifecycle.remaining(state.opening_deadline),
      write_timeout: state.config.limits.write_timeout,
      deadline: state.deadline,
      opening_deadline: state.opening_deadline
    }
  end

  defp open_options(state, config) do
    Map.merge(state.request_options, %{
      url:
        URI.to_string(%{
          config.uri
          | path: state.request_options.path,
            query: state.request_options.query
        }),
      deadline: state.deadline,
      opening_deadline: state.opening_deadline,
      timeout: Lifecycle.remaining(state.deadline),
      opening_timeout: Lifecycle.remaining(state.opening_deadline),
      write_timeout: state.config.limits.write_timeout,
      cacertfile: config.cacertfile,
      connect_address: config.connect_address,
      managed_transport: state.managed_transport
    })
  end

  defp release_opening_payloads(%{client: @h2} = state) do
    %{
      state
      | submitted_url: state.request_options.url,
        request_options: nil,
        managed_transport: nil,
        selector: nil,
        awaiting_transport: nil,
        transport_handoff: nil,
        config: %{state.config | uri: nil, transport: nil, cacertfile: nil, connect_address: nil}
    }
  end

  defp release_opening_payloads(state), do: state

  defp callback_request(%{client: @h2} = state), do: {state.request, state.submitted_url}
  defp callback_request(state), do: state.request

  @doc false
  def finite_reason(reason), do: finite_reason(reason, 0)
  defp finite_reason(:not_running, _), do: :unavailable
  defp finite_reason({:deadline_exceeded, :cleanup_pending}, _), do: :timeout

  defp finite_reason(reason, _)
       when reason in [
              :invalid_request,
              :invalid_policy,
              :invalid_response,
              :upstream_failure,
              :upstream_task,
              :upstream_delivery_limit,
              :upstream_delivery_overlap,
              :upstream_trailer_limit,
              :timeout,
              :request_timeout,
              :unavailable,
              :cancelled,
              :cleanup_pending,
              :cleanup_unconfirmed,
              :invalid_resource,
              :invalid_resource_pin,
              :invalid_transport_endpoint,
              :unauthorized,
              :retiring,
              :resource_unavailable
            ],
       do: reason

  defp finite_reason({kind, reason}, depth)
       when depth < 3 and
              kind in [
                :cleanup_failed,
                :transport_cleanup_failed,
                :pin_release_failed,
                :service_cleanup_failed,
                :selection_cleanup_failed
              ],
       do: {kind, finite_reason(reason, depth + 1)}

  defp finite_reason(:transport_endpoint_mismatch, _), do: :unavailable

  defp finite_reason({:capacity, kind}, _)
       when kind in [:request_tokens, :pins, :owned_payload_bytes],
       do: :unavailable

  defp finite_reason(:request_limit, _), do: :unavailable
  defp finite_reason(:resource_admission_closed, _), do: :unavailable
  defp finite_reason(_, _), do: :upstream_failure

  defp normalize_reason(%{client: @h2}, reason), do: finite_reason(reason)
  defp normalize_reason(_, reason), do: reason

  defp signed_time?(value),
    do:
      is_integer(value) and value >= -9_223_372_036_854_775_808 and
        value <= 9_223_372_036_854_775_807

  defp notify(state, {:error, reason}),
    do: send(state.owner, {:gaoxy_proxy_http, self(), {:error, normalize_reason(state, reason)}})

  defp notify(state, event), do: send(state.owner, {:gaoxy_proxy_http, self(), event})

  defp cancel_poll(%{client: @h2, poll_timer: timer} = state) do
    if timer, do: Process.cancel_timer(timer)
    %{state | poll_timer: nil}
  end

  defp cancel_poll(state), do: state

  defp schedule(%{client: Gaoxy.Proxy.HTTP3SessionClient} = state), do: state

  defp schedule(%{client: @h2} = state) do
    state = cancel_poll(state)
    %{state | poll_timer: Process.send_after(self(), :poll, @poll_ms)}
  end

  defp schedule(state) do
    Process.send_after(self(), :poll, @poll_ms)
    state
  end
end
